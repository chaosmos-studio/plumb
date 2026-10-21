class_name PlayGames
extends RefCounted

## Google Play Games: sign-in, the leaderboards and achievements in catalog.json, and progress kept in the
## player's Google account, so a new phone picks up where the old one stopped. Off everywhere but an Android
## build of a game that has its Play Games project, and nothing waits on it.
##
## The kit expects from the game:
## - play_games.json at the project's root, written by kit/tools/play_games_ids.py once the game has its
##   Play Games project: {"app": the project id, "leaderboards": {key: id}, "achievements": {key: id}}.
##   Without it the Android build leaves the plugin out (addons/play_games).
## - Save._ready calling `PlayGames.start()` after `Ads.start()`.

const CATALOG: String = "res://kit/play_games/catalog.json"
const IDS: String = "res://play_games.json"
## Play Games' time spans for a leaderboard.
const TODAY: int = 0
const WEEK: int = 1
const ALL_TIME: int = 2

static var _backend: Node
static var _catalog: Dictionary = {}
static var _ids: Dictionary = {}

static func start() -> void:
	if is_instance_valid(_backend) or not OS.has_feature("android") or app_id() == "" \
			or not Engine.has_singleton("GodotPlayGameServices"):
		return
	var backend: GDScript = load("res://kit/monetize/android/play_games.gd")
	_backend = backend.new()
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_backend)
	EventBus.level_won.connect(func(_level: int, _count: int, _stars: int) -> void: progressed())

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

## The achievements this progress has earned, by key.
static func earned(solved: int, three: int, dailies: int, best_streak: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var have: Dictionary = {"solved": solved, "three": three, "dailies": dailies, "streak": best_streak}
	for entry: Variant in catalog().get("achievements", []):
		var a: Dictionary = entry
		for measure: String in have:
			if a.has(measure) and int(have[measure]) >= int(a[measure]):
				out.append(String(a["key"]))
	return out

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}
