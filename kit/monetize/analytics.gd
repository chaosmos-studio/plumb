class_name Analytics
extends RefCounted

## Counting waits for UMP to say no consent is needed here, so the EEA, the UK and Switzerland are never
## counted. Nothing counted serves ads: every advertising signal stays denied and addons/firebase_build
## keeps the advertising id out of the build.
##
## The kit expects from the game:
## - `Save._ready` calling `Analytics.start()` after `Ads.start()`.
## - `EventBus.level_started(index)`, `EventBus.level_won(index, count, stars)` and, in a game that can be
##   lost, `EventBus.level_failed(index)`.
## - On Android: the godotx_firebase and firebase_build plugins enabled, Firebase Core and Analytics on in
##   both Android presets, and the Firebase app's google-services.json at res://.

const FIREBASE_CORE: String = "GodotxFirebaseCore"
const FIREBASE: String = "GodotxFirebaseAnalytics"
## Read from the AdMob plugin's singleton rather than its classes, which the web build leaves out.
const CONSENT: String = "PoingGodotAdMobConsentInformation"
## UMP's ConsentStatus.NOT_REQUIRED.
const CONSENT_NOT_REQUIRED: int = 1

## For the robots: hears every event as (name, params), counted or not.
static var sink: Callable = Callable()

static var _firebase: Object
static var _counting: bool = false
static var _started_at: int = 0

static func start() -> void:
	_listen()
	if _firebase != null or not OS.has_feature("android") or not Engine.has_singleton(FIREBASE):
		return
	if Engine.has_singleton(FIREBASE_CORE):
		Engine.get_singleton(FIREBASE_CORE).call("initialize")
	_firebase = Engine.get_singleton(FIREBASE)
	_firebase.call("initialize")
	refresh()

## Firebase keeps the choice across launches, so it is set either way.
static func refresh() -> void:
	if _firebase == null:
		return
	var status: int = 0
	if Engine.has_singleton(CONSENT):
		status = int(Engine.get_singleton(CONSENT).call("get_consent_status"))
	_counting = counts(status, OS.is_debug_build())
	_firebase.call("set_consent", {"analytics_storage": "granted" if _counting else "denied"})
	_firebase.call("set_analytics_collection_enabled", _counting)

static func counts(consent_status: int, debug: bool) -> bool:
	return consent_status == CONSENT_NOT_REQUIRED and not debug

static func counting() -> bool:
	return _counting

## GA4 limits: a short snake_case name and a few numbers or short strings.
static func event(name: StringName, params: Dictionary = {}) -> void:
	if sink.is_valid():
		sink.call(name, params)
	if _counting:
		_firebase.call("log_event", String(name), params)

static func _listen() -> void:
	if EventBus.level_started.is_connected(_on_started):
		return
	EventBus.level_started.connect(_on_started)
	EventBus.level_won.connect(_on_won)
	if EventBus.has_signal(&"level_failed"):
		EventBus.connect(&"level_failed", _on_failed)
	(Engine.get_main_loop() as SceneTree).scene_changed.connect(_on_scene)

static func _on_started(index: int) -> void:
	_started_at = Time.get_ticks_msec()
	event(&"level_start", {"level": index + 1})

static func _on_won(index: int, _count: int, stars: int) -> void:
	event(&"level_end", {"level": index + 1, "success": 1, "stars": stars, "seconds": _seconds()})

static func _on_failed(index: int) -> void:
	event(&"level_end", {"level": index + 1, "success": 0, "stars": 0, "seconds": _seconds()})

static func _seconds() -> int:
	@warning_ignore("integer_division")
	return (Time.get_ticks_msec() - _started_at) / 1000

static func _on_scene() -> void:
	var scene: Node = (Engine.get_main_loop() as SceneTree).current_scene
	if scene == null or scene.scene_file_path == "":
		return
	var screen: String = scene.scene_file_path.get_file().get_basename()
	event(&"screen_view", {"screen_name": screen, "screen_class": screen})
