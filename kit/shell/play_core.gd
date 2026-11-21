class_name PlayCore
extends RefCounted

## Google Play's in-app review card and in-app updates, through the Java helper that the play_core plugin
## builds into the Android app. Without it (the web, the desktop, a robot) every call does nothing, and
## `review` goes straight on.
##
## Updates (REVAMP_PLAN.md section 7): every launch asks Play whether a newer version is out, with no stale wait.
## The game offers it with its own card in its own look (UpdatePolicy says when and how), flexible by default, so it
## downloads while the player plays, and immediate when a version must go out. Once downloaded, a restart finishes
## it. Never mid-level. Classic's screens get the kit's card here; Street's map shows its own and reads the same state.
##
## The kit expects from the game: `Save._ready` calling `PlayCore.start()`, the play_core plugin enabled, and Save's
## `update_shown`, `update_started` and `last_code` with `note_update(...)`.

const HELPER: String = "studio.chaosmos.kit.PlayCore"
## Seconds after launch before asking Play, so nothing lands on the splash.
const UPDATE_AFTER: float = 2.0
## How long Next level waits for Play to start the review card before it goes on without it. The game is
## paused while the card is up, so this only counts Play's answer.
const REVIEW_WAIT: float = 3.0
const POLL: float = 0.1
## The screens the kit's own card and restart sheet may show on: Classic's places between levels.
const QUIET_SCENES: PackedStringArray = [Brand.TITLE_SCENE, Brand.LEVELS_SCENE]

## A stand-in for Play, for tests, robots and laptop screenshots: when set ({"code", "priority", "flexible",
## "immediate"}, with "state" optional), updates come from it, and starting one walks it through downloading to
## downloaded on its own.
static var fake: Dictionary = {}
## Where the update's line and picture come from: the game's level feed (Feed.app_note), or nothing.
static var note_source: Callable = Callable()

static var _helper: Object
static var _watch: _Watch
static var _offered: bool = false
static var _carded: bool = false
static var _told_download: bool = false

## A debug build reads its stand-in from this file (the JSON of `fake`), so a phone can show the card without Play.
const FAKE_FILE: String = "user://update_fake.json"

static func start() -> void:
	if is_instance_valid(_watch):
		return
	if OS.is_debug_build() and FileAccess.file_exists(FAKE_FILE):
		var stand_in: Variant = JSON.parse_string(FileAccess.get_file_as_string(FAKE_FILE))
		if stand_in is Dictionary:
			fake = stand_in
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

## What Play says of an update: idle (not asked yet), none, available, asking, downloading, downloaded, installing,
## installed or failed.
static func update_state() -> String:
	if not fake.is_empty():
		return str(fake.get("state", "available"))
	return String(_helper.call("updateState")) if available() else "idle"

## The offered update: {"code", "priority", "staleness", "bytes", "downloaded", "flexible", "immediate"}.
static func update_info() -> Dictionary:
	if not fake.is_empty():
		return fake
	if not available():
		return {}
	var parsed: Variant = JSON.parse_string(String(_helper.call("updateInfo")))
	return parsed if parsed is Dictionary else {}

static func update_ready() -> bool:
	return update_state() == "downloaded"

## The version code running now, 0 off Android.
static func running_code() -> int:
	if not fake.is_empty():
		return int(fake.get("running", 0))
	return int(_helper.call("versionCode", _activity())) if available() else 0

## The note the feed carries for the update ({"line", "latest", "urgent_below", "picture"}), or {}.
static func note() -> Dictionary:
	if note_source.is_valid():
		var got: Variant = note_source.call()
		if got is Dictionary:
			return got
	return {}

## How the update on offer installs ("flexible", "immediate", or "" with none to offer).
static func update_mode() -> String:
	var state: String = update_state()
	if state != "available":
		return ""
	return UpdatePolicy.mode(update_info(), running_code(), int(note().get("urgent_below", 0)))

## Whether the card should show now, on a screen that may carry it.
static func card_due() -> bool:
	return UpdatePolicy.due(Save.update_shown, int(update_info().get("code", 0)), _today(), update_mode(), _carded)

## The card is up: remembered for the day, and counted. `from` is what opened it: "auto" when a screen offered it,
## "badge" when the player tapped the badge, so a card opened again from the badge never counts as a fresh offer.
static func card_shown(from: String = "auto") -> void:
	_carded = true
	var code: int = int(update_info().get("code", 0))
	Save.note_update_shown(code, _today())
	_tell("shown", "", "offer", from)

## The restart card (or Classic's restart sheet) is up: counted like the offer, at the restart stage.
static func restart_shown(from: String = "auto") -> void:
	_tell("shown", "", "restart", from)

## Update was pressed on the card.
static func start_update(from: String = "auto") -> void:
	var how: String = update_mode()
	var code: int = int(update_info().get("code", 0))
	Save.note_update_started(code)
	_tell("start", how, "offer", from)
	if not fake.is_empty():
		fake["state"] = "installing" if how == "immediate" else "downloading"
		fake["downloaded"] = 0
		return
	if available():
		_helper.call("startUpdate", _activity(), how == "immediate")

## A card was put away without going on: the offer ("offer") or the restart ("restart").
static func later(stage: String = "offer", from: String = "auto") -> void:
	_tell("later", "", stage, from)

## Installs a downloaded update: Play's own screen, then the game opens again on the new version. Counted as the
## restart card's start.
static func complete_update(from: String = "auto") -> void:
	_tell("start", "", "restart", from)
	if not fake.is_empty():
		fake["state"] = "installing"
		return
	if available():
		_helper.call("completeUpdate")

## The sheet a downloaded update is offered with on Classic's screens, once a session.
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
	var went: Array[bool] = [false]
	var restart: Button = UI.button("Restart", UI.Style.PRIMARY)
	restart.pressed.connect(func() -> void:
		went[0] = true
		complete_update()
		sheet.close())
	c.add_child(restart)
	var later_button: Button = UI.button("Later", UI.Style.GHOST)
	later_button.pressed.connect(sheet.close)
	c.add_child(later_button)
	# However it is put away (Later, a tap beside it, a drag), it is counted once.
	sheet.closed.connect(func() -> void:
		if not went[0]:
			later("restart"), CONNECT_ONE_SHOT)
	restart_shown()
	return sheet

## Classic's update card: the picture, the line of what is new, Update, and a quiet Later unless it must go out.
static func offer_card(host: Node) -> Sheet:
	var how: String = update_mode()
	var sheet: Sheet = Sheet.open(host, how != "immediate")
	var c: VBoxContainer = sheet.content
	var picture: Texture2D = picture_of(note())
	if picture != null:
		var art: TextureRect = TextureRect.new()
		art.texture = picture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(0, 260)
		c.add_child(art)
	else:
		c.add_child(UI.centred(UI.app_icon(120)))
	var what: Label = UI.title(UpdatePolicy.line(note(), int(update_info().get("code", 0))), 44)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(what)
	c.add_child(UI.spacer(6))
	var went: Array[bool] = [false]
	var go: Button = UI.button("Update", UI.Style.PRIMARY)
	go.pressed.connect(func() -> void:
		went[0] = true
		start_update()
		sheet.close())
	c.add_child(go)
	if how != "immediate":
		var later_button: Button = UI.button("Later", UI.Style.GHOST)
		later_button.pressed.connect(sheet.close)
		c.add_child(later_button)
	# However it is put away (Later, a tap beside it, a drag), it is counted once.
	sheet.closed.connect(func() -> void:
		if not went[0]:
			later("offer"), CONNECT_ONE_SHOT)
	card_shown()
	return sheet

## The note's picture, read from the file the feed checked, or null.
static func picture_of(the_note: Dictionary) -> Texture2D:
	var path: String = str(the_note.get("picture", ""))
	if path == "" or not FileAccess.file_exists(path):
		return null
	var image: Image = Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	# Shown smaller than it is, it needs its mipmaps: sampled with mipmaps that are not there, it draws nothing.
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

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

static func _today() -> String:
	return Time.get_date_string_from_system()

## update_card for analytics (REVAMP_PLAN.md section 5.2): what happened (shown, start, later, downloaded, installed),
## the version on offer and how it installs, and for a card's own events its stage ("offer" or "restart") and what
## opened it ("auto" or "badge").
static func _tell(what: String, how: String = "", stage: String = "", from: String = "") -> void:
	var params: Dictionary = {"update": what, "version": str(int(update_info().get("code", 0))),
		"mode": how if how != "" else update_mode()}
	if stage != "":
		params["stage"] = stage
		params["from"] = from
	Analytics.event(&"update_card", params)

## Each launch: asks Play, and counts an update the player started from the card that is now running.
static func _launch() -> void:
	var running: int = running_code()
	if UpdatePolicy.installed(running, Save.last_code, Save.update_started):
		Analytics.event(&"update_card", {"update": "installed", "version": str(running), "mode": ""})
		Save.note_update_started(0)
	if running > 0:
		Save.note_running(running)
	if available():
		_helper.call("checkUpdate", _activity())

## Each second: a finished download is counted once, and Classic's quiet screens get the card or the restart.
static func _tick(delta: float) -> void:
	if not fake.is_empty() and str(fake.get("state", "")) == "downloading":
		fake["downloaded"] = int(fake.get("downloaded", 0)) + int(float(fake.get("bytes", 4000000)) * delta / 6.0)
		if int(fake["downloaded"]) >= int(fake.get("bytes", 4000000)):
			fake["state"] = "downloaded"
	if update_ready() and not _told_download:
		_told_download = true
		_tell("downloaded", "flexible")
	if Sheet.any_open():
		return
	var scene: Node = (Engine.get_main_loop() as SceneTree).current_scene
	if scene == null or not QUIET_SCENES.has(scene.scene_file_path):
		return
	if update_ready() and not _offered:
		offer_update(scene)
	elif card_due():
		offer_card(scene)


class _Watch extends Node:
	func _ready() -> void:
		get_tree().create_timer(PlayCore.UPDATE_AFTER).timeout.connect(PlayCore._launch)
		var timer: Timer = Timer.new()
		timer.wait_time = 1.0
		timer.timeout.connect(func() -> void: PlayCore._tick(timer.wait_time))
		add_child(timer)
		timer.start()
