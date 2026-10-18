class_name PlayCore
extends RefCounted

## Google Play's in-app review card and in-app updates, through the Java helper that the play_core plugin
## builds into the Android app. Without it (the web, the desktop, a robot) every call does nothing, and
## `review` goes straight on.
##
## Updates are flexible: Play asks once whether to download, the game goes on meanwhile, and once the update is
## in, the title or the level grid offers to restart into it. Never mid-level.
##
## The kit expects from the game: `Save._ready` calling `PlayCore.start()`, and the play_core plugin enabled.

const HELPER: String = "studio.chaosmos.kit.PlayCore"
## Play's own auto-update reaches most phones within a day or two of a release, so the game offers an update
## only once it has been out this long, and after one offer stays quiet for QUIET_DAYS whatever the answer.
const STALE_DAYS: int = 2
const QUIET_DAYS: int = 7
## Seconds after launch before looking for an update, so Play's dialog never lands on the splash.
const UPDATE_AFTER: float = 2.0
## How long Next level waits for Play to start the review card before it goes on without it. The game is
## paused while the card is up, so this only counts Play's answer.
const REVIEW_WAIT: float = 3.0
const POLL: float = 0.1
## The screens a downloaded update may be offered on: places between levels.
const QUIET_SCENES: PackedStringArray = [Brand.TITLE_SCENE, Brand.LEVELS_SCENE]

static var _helper: Object
static var _watch: _Watch
static var _offered: bool = false

static func start() -> void:
	if is_instance_valid(_watch) or not available():
		return
	_watch = _Watch.new()
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_watch)

static func available() -> bool:
	if _helper == null and Supporter.on_play and Engine.has_singleton("AndroidRuntime"):
		_helper = JavaClassWrapper.wrap(HELPER)
	return _helper != null

## Play's review card, then `then`. Play decides whether the card shows at all, and never says whether the
## player rated, so the game goes on the same either way.
static func review(then: Callable = Callable()) -> void:
	if not available():
		_go(then)
		return
	_helper.call("requestReview", _activity())
	_await_review(then, REVIEW_WAIT)

static func update_ready() -> bool:
	return available() and String(_helper.call("updateState")) == "downloaded"

## The sheet a downloaded update is offered with, once a session.
static func offer_update(host: Node) -> Sheet:
	_offered = true
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.centred(UI.app_icon(120)))
	c.add_child(UI.title("An update is ready", 52))
	var why: Label = UI.label("Restart %s to finish updating. Your levels and stars stay as they are." % Brand.NAME,
		28, Brand.MUTED)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(why)
	c.add_child(UI.spacer(6))
	var restart: Button = UI.button("Restart", UI.Style.PRIMARY)
	restart.pressed.connect(func() -> void:
		if available():
			_helper.call("completeUpdate")
		sheet.close())
	c.add_child(restart)
	var later: Button = UI.button("Later", UI.Style.GHOST)
	later.pressed.connect(sheet.close)
	c.add_child(later)
	return sheet

static func _activity() -> Object:
	return Engine.get_singleton("AndroidRuntime").call("getActivity")

static func _await_review(then: Callable, left: float) -> void:
	if String(_helper.call("reviewState")) != "asking" or left <= 0.0:
		_go(then)
		return
	(Engine.get_main_loop() as SceneTree).create_timer(POLL).timeout.connect(
		func() -> void: _await_review(then, left - POLL))

static func _go(then: Callable) -> void:
	if then.is_valid():
		then.call()

static func _check_update() -> void:
	if available():
		_helper.call("checkForUpdate", _activity(), STALE_DAYS, QUIET_DAYS)

## Offers a downloaded update once the player is on a quiet screen with nothing open over it.
static func _maybe_offer() -> void:
	if _offered or Sheet.any_open() or not update_ready():
		return
	var scene: Node = (Engine.get_main_loop() as SceneTree).current_scene
	if scene != null and QUIET_SCENES.has(scene.scene_file_path):
		offer_update(scene)


class _Watch extends Node:
	func _ready() -> void:
		get_tree().create_timer(PlayCore.UPDATE_AFTER).timeout.connect(PlayCore._check_update)
		var timer: Timer = Timer.new()
		timer.wait_time = 1.0
		timer.timeout.connect(PlayCore._maybe_offer)
		add_child(timer)
		timer.start()
