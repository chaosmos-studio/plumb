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

## For the robots: hears every event as (name, params), counted or not, and every user property as
## (&"user_property", {name: value}).
static var sink: Callable = Callable()

## What the game says about the level in play, set before it emits level_started and sent with every level event
## until the next (in Plumb: the board's id, its path, its difficulty, the player's rating, how it was picked, whether
## it is a replay).
static var level_context: Dictionary = {}
## How the solve went (moves, par, hints, undos and so on), set just before level_won and sent with that level_end.
static var solve_measures: Dictionary = {}

static var _firebase: Object
## Firebase's user properties, which the vendored Firebase plugin cannot set: the kit's own Java helper sets them
## (addons/analytics_user/AnalyticsUser.java), only while counting.
static var _user: Object
## Each user property's latest value, sent again whenever counting starts.
static var _properties: Dictionary = {}
static var _counting: bool = false
static var _started_at: int = 0
## Solved levels when the level now played began, so a replay never repeats a milestone. -1 before any level
## has begun, when no milestone is judged.
static var _solved_at_start: int = -1
## The same for the section in play alone, for solved_all.
static var _here_at_start: int = -1

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
	for name: String in _properties:
		_send_property(name, str(_properties[name]))

## A user property (REVAMP_PLAN.md section 5.1): GA4 takes names of 24 characters and values of 36. Sent only on a
## change, and again each launch once counting starts.
static func user_property(name: String, value: String) -> void:
	var cut: String = value.left(36)
	if _properties.get(name, null) == cut:
		return
	_properties[name] = cut
	if sink.is_valid():
		sink.call(&"user_property", {name: cut})
	_send_property(name, cut)

static func _send_property(name: String, value: String) -> void:
	if not _counting:
		return
	if _user == null and Engine.has_singleton("AndroidRuntime"):
		_user = JavaClassWrapper.wrap("studio.chaosmos.kit.AnalyticsUser")
	if _user != null:
		_user.call("set", Engine.get_singleton("AndroidRuntime").call("getActivity"), name, value)

## `params` with the level in play's context, for a level event the game sends itself (level_quit, hint).
static func in_level(params: Dictionary) -> Dictionary:
	var out: Dictionary = level_context.duplicate()
	out.merge(params, true)
	return out

static func counts(consent: Consent.Status, debug: bool) -> bool:
	return Consent.counts(consent) and not debug

static func counting() -> bool:
	return _counting

## GA4 limits: a short snake_case name and a few numbers or short strings.
static func event(name: StringName, params: Dictionary = {}) -> void:
	var sent: Dictionary = tagged(params)
	if sink.is_valid():
		sink.call(name, sent)
	# A debug build on a phone never counts, so it says each event in the log instead, for a check with logcat.
	if OS.is_debug_build() and OS.has_feature("android"):
		print("ANALYTICS %s %s" % [name, JSON.stringify(for_ga(sent))])
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
## "(not set)". Stars, seconds and the other measures stay numbers, for their metrics.
const AS_TEXT: Array[String] = ["level", "success", "room", "board", "path", "pick", "replay", "look", "from", "how",
	"booster", "gift", "family", "setting", "value", "update", "mode", "version", "feed", "paid_with", "item", "kind",
	"format", "network"]
## Measures sent as fractions, rounded so a report reads them: a board's difficulty to hundredths, a rating whole.
const ROUNDED: Dictionary = {"difficulty": 100.0, "rating": 1.0}

static func for_ga(params: Dictionary) -> Dictionary:
	var sent: Dictionary = params.duplicate()
	for key: String in AS_TEXT:
		if sent.has(key):
			sent[key] = str(sent[key])
	for key: String in ROUNDED:
		if sent.has(key):
			var unit: float = ROUNDED[key]
			sent[key] = roundf(float(sent[key]) * unit) / unit if unit > 1.0 else int(roundf(float(sent[key])))
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
	_here_at_start = Ads.solved_here()
	event(&"level_start", in_level({"level": index + 1}))

## The game records a solve before it says so, so the totals here already count this level.
static func _on_won(index: int, _count: int, stars: int) -> void:
	var params: Dictionary = in_level({"level": index + 1, "success": 1, "stars": stars, "seconds": _seconds()})
	params.merge(solve_measures, true)
	solve_measures = {}
	params.erase("pick")
	params.erase("replay")
	event(&"level_end", params)
	if _solved_at_start < 0:
		return
	var solved: int = Ads.solved()
	for m: int in MILESTONES:
		if _solved_at_start < m and solved >= m and m < Pack.count():
			event(StringName("solved_%d" % m), {"level": index + 1})
	var here: int = Ads.solved_here()
	if _here_at_start < Pack.count() and here >= Pack.count():
		event(&"solved_all", {"level": index + 1})
	_solved_at_start = solved
	_here_at_start = here

static func _on_failed(index: int) -> void:
	event(&"level_end", in_level({"level": index + 1, "success": 0, "stars": 0, "seconds": _seconds()}))

static func _seconds() -> int:
	@warning_ignore("integer_division")
	return (Time.get_ticks_msec() - _started_at) / 1000

static func _on_scene() -> void:
	var scene: Node = (Engine.get_main_loop() as SceneTree).current_scene
	if scene == null or scene.scene_file_path == "":
		return
	var screen: String = scene.scene_file_path.get_file().get_basename()
	event(&"screen_view", {"screen_name": screen, "screen_class": screen})
