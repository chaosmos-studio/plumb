class_name Analytics
extends RefCounted

## Counting follows the consent sheet (Consent): where no consent is needed, and in the EEA, the UK and
## Switzerland only once the player allowed it there. Nothing counted serves ads: every advertising signal
## stays denied and addons/firebase_build keeps the advertising id out of Firebase.
##
## The kit expects from the game:
## - `Save._ready` calling `Analytics.start()` after `Ads.start()`.
## - `EventBus.level_started(index)`, `EventBus.level_won(index, count, stars)` and, in a game that can be
##   lost, `EventBus.level_failed(index)`.
## - On Android: the godotx_firebase and firebase_build plugins enabled, Firebase Core and Analytics on in
##   both Android presets, and the Firebase app's google-services.json at res://.

const FIREBASE_CORE: String = "GodotxFirebaseCore"
const FIREBASE: String = "GodotxFirebaseAnalytics"

## Totals of solved levels that each send one event (solved_100 and so on), and solved_all once every level
## is solved. A custom insight in Google Analytics turns them into an email, so the studio hears when players
## near the end in time to make more levels.
const MILESTONES: Array[int] = [100, 200, 300, 400]

## For the robots: hears every event as (name, params), counted or not.
static var sink: Callable = Callable()

static var _firebase: Object
static var _counting: bool = false
static var _started_at: int = 0
## Solved levels when the level now played began, so a replay never repeats a milestone. -1 before any level
## has begun, when no milestone is judged.
static var _solved_at_start: int = -1

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
	_counting = counts(Consent.status(), OS.is_debug_build())
	_firebase.call("set_consent", {"analytics_storage": "granted" if _counting else "denied"})
	_firebase.call("set_analytics_collection_enabled", _counting)

static func counts(consent: Consent.Status, debug: bool) -> bool:
	return Consent.counts(consent) and not debug

static func counting() -> bool:
	return _counting

## GA4 limits: a short snake_case name and a few numbers or short strings.
static func event(name: StringName, params: Dictionary = {}) -> void:
	var sent: Dictionary = tagged(params)
	if sink.is_valid():
		sink.call(name, sent)
	if _counting:
		_firebase.call("log_event", String(name), for_ga(sent))

## A game with a second set of levels names a level of that set its own way (Pack.level_tag, such as "h181" for
## Hard), so two levels that share a number never count as one.
static func tagged(params: Dictionary) -> Dictionary:
	if not params.has("level") or not Pack.has_method("level_tag"):
		return params
	var tag: String = Pack.call("level_tag", int(params["level"]))
	if tag == "":
		return params
	var out: Dictionary = params.duplicate()
	out["level"] = tag
	return out

## Parameters GA4 reports as custom dimensions, which it fills only from text: sent as numbers they arrive as
## "(not set)". Stars and seconds stay numbers, for their metrics.
const AS_TEXT: Array[String] = ["level", "success", "room"]

static func for_ga(params: Dictionary) -> Dictionary:
	var sent: Dictionary = params.duplicate()
	for key: String in AS_TEXT:
		if sent.has(key):
			sent[key] = str(sent[key])
	return sent

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
	_solved_at_start = Ads.solved()
	event(&"level_start", {"level": index + 1})

## The game records a solve before it says so, so the total here already counts this level.
static func _on_won(index: int, _count: int, stars: int) -> void:
	event(&"level_end", {"level": index + 1, "success": 1, "stars": stars, "seconds": _seconds()})
	if _solved_at_start < 0:
		return
	var solved: int = Ads.solved()
	for m: int in MILESTONES:
		if _solved_at_start < m and solved >= m and m < Pack.count():
			event(StringName("solved_%d" % m), {"level": index + 1})
	if _solved_at_start < Pack.count() and solved >= Pack.count():
		event(&"solved_all", {"level": index + 1})
	_solved_at_start = solved

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
