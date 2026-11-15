class_name PlayGames
extends RefCounted

## Google Play Games: sign-in, the leaderboards, achievements and Game Stats in catalog.json, and progress kept
## in the player's Google account, so a new phone picks up where the old one stopped. Off everywhere but an
## Android build of a game that has its Play Games project, and nothing waits on it.
##
## The kit expects from the game:
## - play_games.json at the project's root, written by kit/tools/play_games_ids.py once the game has its
##   Play Games project: {"app": the project id, "leaderboards": {key: id}, "achievements": {key: id}}.
##   Without it the Android build leaves the plugin out (addons/play_games).
## - Save._ready calling `PlayGames.start()` after `Ads.start()`.
## - `EventBus.level_started` and `EventBus.level_won` around every level played.

const CATALOG: String = "res://kit/play_games/catalog.json"
const IDS: String = "res://play_games.json"
## Play Games' time spans for a leaderboard.
const TODAY: int = 0
const WEEK: int = 1
const ALL_TIME: int = 2
## The most one solve adds to the time spent solving, so a level left open overnight counts as an hour.
const SOLVE_SECONDS_CAP: float = 3600.0

static var _backend: Node
static var _catalog: Dictionary = {}
static var _ids: Dictionary = {}
static var _hints: int = 0
static var _started_at: int = 0

static func start() -> void:
	if is_instance_valid(_backend) or not OS.has_feature("android") or app_id() == "" \
			or not Engine.has_singleton("GodotPlayGameServices"):
		return
	var backend: GDScript = load("res://kit/monetize/android/play_games.gd")
	_backend = backend.new()
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_backend)
	EventBus.level_started.connect(func(_level: int) -> void:
		_hints = 0
		_started_at = Time.get_ticks_msec())
	EventBus.level_won.connect(func(level: int, _count: int, stars: int) -> void:
		solved(Shown.stat(level), stars, (Time.get_ticks_msec() - _started_at) / 1000.0, false)
		progressed())

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = _read(CATALOG)
	return _catalog

static func ids() -> Dictionary:
	if _ids.is_empty():
		_ids = _read(IDS)
	return _ids

static func app_id() -> String:
	return String(ids().get("app", ""))

static func id_of(kind: String, key: StringName) -> String:
	var table: Dictionary = ids().get(kind, {})
	return String(table.get(String(key), ""))

static func ready() -> bool:
	return is_instance_valid(_backend)

## The capture and film tools stage the signed-in screens with a stand-in that records nothing. Null takes
## it away again.
static func use(backend: Node) -> void:
	if is_instance_valid(_backend) and _backend != backend:
		_backend.queue_free()
	_backend = backend

static func signed_in() -> bool:
	return ready() and bool(_backend.get("signed_in"))

static func submit(key: StringName, score: int) -> void:
	if ready() and id_of("leaderboards", key) != "":
		_backend.call("submit", id_of("leaderboards", key), score)

static func show_board(key: StringName, span: int) -> void:
	if ready() and id_of("leaderboards", key) != "":
		_backend.call("show_board", id_of("leaderboards", key), span)

static func show_boards() -> void:
	if ready():
		_backend.call("show_boards")

static func show_achievements() -> void:
	if ready():
		_backend.call("show_achievements")

## After any solve: achievements, the all-time boards, and the cloud save a little later.
static func progressed() -> void:
	if ready():
		_backend.call("progressed")

static func three_star_levels() -> int:
	var n: int = 0
	for i: int in range(Pack.count()):
		if Save.best(i) >= 3:
			n += 1
	return n

## The steps an achievement takes: its threshold. One with more than one step is incremental in Play Games,
## so a player sees how far along it is.
static func goal(achievement: Dictionary) -> int:
	for measure: String in ["solved", "three", "dailies", "streak"]:
		if achievement.has(measure):
			return int(achievement[measure])
	return 1

## Each achievement's steps done, by key, up to its goal.
static func progress(solved_levels: int, three: int, dailies: int, best_streak: int) -> Dictionary:
	var have: Dictionary = {"solved": solved_levels, "three": three, "dailies": dailies, "streak": best_streak}
	var out: Dictionary = {}
	for entry: Variant in catalog().get("achievements", []):
		var a: Dictionary = entry
		for measure: String in have:
			if a.has(measure):
				out[String(a["key"])] = mini(int(have[measure]), goal(a))
	return out

## The achievements this progress has earned, by key.
static func earned(solved_levels: int, three: int, dailies: int, best_streak: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var steps: Dictionary = progress(solved_levels, three, dailies, best_streak)
	for entry: Variant in catalog().get("achievements", []):
		var a: Dictionary = entry
		if int(steps.get(String(a["key"]), 0)) >= goal(a):
			out.append(String(a["key"]))
	return out

## Game Stats: one solve as a levelCompleted event. A daily puzzle is level 0 with no stars or hints. The plugin
## sends {"seconds": n} as a duration.
static func solve_event(level: int, stars: int, hints: int, seconds: float, daily: bool) -> Dictionary:
	return {"level": level, "stars": stars, "hints": hints, "daily": daily,
		"time": {"seconds": snappedf(minf(seconds, SOLVE_SECONDS_CAP), 0.1)}}

## A solve, from the level's win or the daily puzzle's.
static func solved(level: int, stars: int, seconds: float, daily: bool) -> void:
	if ready():
		_backend.call("record_event", "levelCompleted", solve_event(level, stars, 0 if daily else _hints, seconds, daily))

## HintGate's word that a hint was given on the level being played.
static func hinted() -> void:
	_hints += 1

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}
