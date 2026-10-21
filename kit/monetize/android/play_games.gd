extends Node

## Talks to the GodotPlayGameServices Android plugin directly, rather than through its GDScript wrappers,
## whose autoload the web build could not carry. Play Games signs a player in on its own at launch, and
## nothing here asks again unless the player taps something that needs it.

const SAVE_NAME: String = "progress"
## A burst of solves becomes one cloud save.
const SAVE_DELAY: float = 15.0

var signed_in: bool = false

var _plugin: Object
## Scores made before sign-in, by leaderboard id, sent once it comes.
var _pending: Dictionary = {}
## Achievements already sent this session, by key.
var _sent: Dictionary = {}
var _last_stars: int = -1
var _last_streak: int = -1
## The cloud copy is read and folded in once a session, before anything is written over it.
var _synced: bool = false
var _after_sign_in: Callable = Callable()
var _save_timer: Timer

func _ready() -> void:
	_plugin = Engine.get_singleton("GodotPlayGameServices")
	_plugin.call("initialize")
	_plugin.connect("userAuthenticated", _on_authenticated)
	_plugin.connect("gameLoaded", _on_loaded)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(_save)
	add_child(_save_timer)
	_plugin.call("isAuthenticated")

func sign_in(then: Callable = Callable()) -> void:
	_after_sign_in = then
	_plugin.call("signIn")

func submit(id: String, score: int) -> void:
	if signed_in:
		_plugin.call("submitScore", id, score)
	else:
		_pending[id] = score

func show_board(id: String, span: int) -> void:
	if signed_in:
		_plugin.call("showLeaderboardForTimeSpan", id, span)
	else:
		sign_in(func() -> void: _plugin.call("showLeaderboardForTimeSpan", id, span))

func show_boards() -> void:
	if signed_in:
		_plugin.call("showAllLeaderboards")
	else:
		sign_in(func() -> void: _plugin.call("showAllLeaderboards"))

func show_achievements() -> void:
	if signed_in:
		_plugin.call("showAchievements")
	else:
		sign_in(func() -> void: _plugin.call("showAchievements"))

func progressed() -> void:
	if not signed_in:
		return
	for key: String in PlayGames.earned(Ads.solved(), PlayGames.three_star_levels(), Daily.solves(), Daily.best()):
		var id: String = PlayGames.id_of("achievements", StringName(key))
		if id != "" and not _sent.has(key):
			_sent[key] = true
			_plugin.call("unlockAchievement", id)
	var stars: int = Save.total_stars()
	if stars > 0 and stars != _last_stars and PlayGames.id_of("leaderboards", &"stars") != "":
		_last_stars = stars
		_plugin.call("submitScore", PlayGames.id_of("leaderboards", &"stars"), stars)
	var streak: int = Daily.best()
	if streak > 0 and streak != _last_streak and PlayGames.id_of("leaderboards", &"streak") != "":
		_last_streak = streak
		_plugin.call("submitScore", PlayGames.id_of("leaderboards", &"streak"), streak)
	if _synced:
		_save_timer.start()

func _on_authenticated(ok: bool) -> void:
	signed_in = ok
	if not ok:
		_after_sign_in = Callable()
		return
	for id: String in _pending:
		_plugin.call("submitScore", id, int(_pending[id]))
	_pending.clear()
	if not _synced:
		_plugin.call("loadGame", SAVE_NAME, false)
	progressed()
	if _after_sign_in.is_valid():
		var then: Callable = _after_sign_in
		_after_sign_in = Callable()
		then.call()

## The plugin sends the snapshot through Gson, whose bytes are signed, so each is masked back to 0 to 255.
func _on_loaded(json: String) -> void:
	_synced = true
	var data: Variant = JSON.parse_string(json)
	if data is Dictionary and (data as Dictionary).get("content") is Array:
		var bytes: PackedByteArray = PackedByteArray()
		for v: Variant in (data as Dictionary)["content"]:
			bytes.append(int(v) & 0xFF)
		CloudSave.absorb(bytes.get_string_from_utf8())
	_save()

func _save() -> void:
	if not signed_in or not _synced:
		return
	_plugin.call("saveGame", SAVE_NAME, "%s progress" % Brand.NAME, CloudSave.pack().to_utf8_buffer(), 0,
		CloudSave.progress())

## Whatever waits for the timer is saved before the app goes to the background, where it may be closed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and _save_timer != null and not _save_timer.is_stopped():
		_save_timer.stop()
		_save()
