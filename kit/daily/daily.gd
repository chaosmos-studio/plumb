class_name Daily
extends RefCounted

## One puzzle a day, the same for every player, timed, with Play Games' daily leaderboard for the fastest.
## Today's is free, and a past day plays after a video, or free with the Supporter pack. The streak counts days
## solved on the day, and a missed day of the last week can be kept for it with a video or a Streak keeper.
##
## The kit expects from the game:
## - levels/daily.json, written by the game's tools/generate_daily.gd: {"first": "YYYY-MM-DD", "opens_after":
##   levels solved before the daily opens, "levels": [...]}, each level in levels.json's form, with its "par".
## - In `Save`: `daily` and `set_daily(record)`.
## - In `GameMonetize`: STREAK_ID, a one-time product in Play Console that is consumed: each keeps one day.
## - A play screen that, while `playing()`, builds its board from `entry()`, shows `heading()` and `clock()`
##   in place of the level and its stars, offers no hint, calls `solved(self)` instead of recording stars on
##   a win, and leaves through `leave()`.

const BANK: String = "res://levels/daily.json"
const SCENE: String = "res://kit/daily/daily.tscn"
## How many days back a missed day can still be kept.
const KEEP_DAYS: int = 7

## Lets tests and captures move the clock.
static var skew: int = 0
## The day being played, or -1.
static var day: int = -1

static var _levels: Array = []
static var _first: int = 0
static var _opens_after: int = 0
static var _loaded: bool = false
static var _clock: DailyClock
## The day a Streak keeper being bought is for, kept once Play confirms the purchase.
static var _keeping: int = -1

static func now() -> int:
	return int(Time.get_unix_time_from_system()) + skew

static func today() -> int:
	return DailyDays.index(now())

static func available() -> bool:
	_load()
	return not _levels.is_empty()

static func first() -> int:
	_load()
	return _first

static func opens_after() -> int:
	_load()
	return _opens_after

static func is_open() -> bool:
	return available() and Ads.solved() >= opens_after()

## The bank repeats once it runs out, so an update that brings more days is never urgent.
static func entry_for(d: int) -> Dictionary:
	_load()
	return _levels[posmod(d - _first, _levels.size())]

static func entry() -> Dictionary:
	return entry_for(day)

static func par() -> int:
	return int(entry().get("par", 0))

static func playing() -> bool:
	return day >= 0

static func time_of(d: int) -> int:
	var times: Dictionary = Save.daily.get("times", {})
	return int(times.get(d, 0))

static func solved(d: int) -> bool:
	return time_of(d) > 0

static func late(d: int) -> bool:
	return _days("late").has(d)

static func opened(d: int) -> bool:
	return _days("open").has(d)

static func kept(d: int) -> bool:
	return _days("kept").has(d)

## Streak keepers bought and not used yet.
static func keepers() -> int:
	return int(Save.daily.get("keepers", 0))

## The days that count for the streak: solved on the day, or kept.
static func counted() -> Dictionary:
	var out: Dictionary = {}
	var times: Dictionary = Save.daily.get("times", {})
	var lates: PackedInt32Array = _days("late")
	for d: Variant in times:
		if not lates.has(int(d)):
			out[int(d)] = true
	for d: int in _days("kept"):
		out[d] = true
	return out

## The missed days that can still be kept, newest first: within KEEP_DAYS, and after a day that counts, so
## there is a streak to keep.
static func keepable() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var counts: Dictionary = counted()
	var earliest: int = today()
	for d: Variant in counts:
		earliest = mini(earliest, int(d))
	var t: int = today()
	for d: int in range(t - 1, maxi(first(), t - KEEP_DAYS) - 1, -1):
		if d > earliest and not counts.has(d):
			out.append(d)
	return out

## Neither a video nor Play to pay through, as on the web, where keeping a day is a tap.
static func keeps_free() -> bool:
	return not Ads.rewards() and not Supporter.on_play

static func keep_day(d: int, how: String) -> void:
	var record: Dictionary = Save.daily.duplicate(true)
	var days: Array = record.get("kept", [])
	if not days.has(d):
		days.append(d)
	record["kept"] = days
	if how == "keeper":
		record["keepers"] = maxi(int(record.get("keepers", 0)) - 1, 0)
	Save.set_daily(record)
	Analytics.event(&"streak_kept", {"how": how, "days_ago": today() - d})
	PlayGames.progressed()
	Supporter.say("%s is kept. Your streak is %d %s" % [DailyDays.short(d), streak(), "day" if streak() == 1 else "days"])
	EventBus.settings_changed.emit()

## Keeps day `d` with a video, a keeper already bought, or a new one bought, whichever `how` says.
static func keep(d: int, how: String) -> void:
	match how:
		"video":
			Ads.rewarded(func() -> void: keep_day(d, "video"),
				func() -> void: Supporter.say("No video right now. Try again in a moment"))
		"keeper":
			if keepers() > 0:
				keep_day(d, "keeper")
		"buy":
			_keeping = d
			Shop.buy(GameMonetize.STREAK_ID)
		_:
			keep_day(d, how)

## Shop calls this once Play confirms a Streak keeper. It keeps the day it was bought for, or waits for one.
static func bought_keeper() -> void:
	var record: Dictionary = Save.daily.duplicate(true)
	record["keepers"] = int(record.get("keepers", 0)) + 1
	Save.set_daily(record)
	if _keeping >= 0 and keepable().has(_keeping):
		keep_day(_keeping, "keeper")
	else:
		Supporter.say("A Streak keeper is yours. Use it on a missed day")
	_keeping = -1
	EventBus.settings_changed.emit()

static func streak() -> int:
	return DailyDays.streak(counted(), today())

static func best() -> int:
	return DailyDays.longest(counted())

static func solves() -> int:
	return (Save.daily.get("times", {}) as Dictionary).size()

## Whether day `d` plays without a video first.
static func plays_free(d: int) -> bool:
	return d >= today() or solved(d) or opened(d) or not Ads.rewards()

static func play(d: int) -> void:
	day = d
	Analytics.event(&"daily_start", {"days_ago": today() - d})
	Screens.go(Brand.GAME_SCENE)

static func leave() -> void:
	day = -1
	Screens.go(SCENE)

## A past day the player watched a video for stays open.
static func open_day(d: int) -> void:
	var record: Dictionary = Save.daily.duplicate(true)
	var days: PackedInt32Array = _days("open")
	if not days.has(d):
		days.append(d)
	record["open"] = Array(days)
	Save.set_daily(record)

## Time already spent on an unsolved day, so leaving and coming back does not start its clock again.
static func spent(d: int) -> int:
	var clocks: Dictionary = Save.daily.get("clock", {})
	return int(clocks.get(d, 0))

static func keep_time(d: int, ms: int) -> void:
	if solved(d):
		return
	var record: Dictionary = Save.daily.duplicate(true)
	var clocks: Dictionary = record.get("clock", {})
	clocks[d] = ms
	record["clock"] = clocks
	Save.set_daily(record)

## Records a solve and says what it was: {"first", "on_time", "ms", "best_ms"}. Only the first solve of a day
## is kept, and only a first solve on its own day is on time.
static func record(d: int, ms: int) -> Dictionary:
	var first_solve: bool = not solved(d)
	var on_time: bool = d >= today()
	if first_solve:
		var rec: Dictionary = Save.daily.duplicate(true)
		var times: Dictionary = rec.get("times", {})
		times[d] = maxi(ms, 1)
		rec["times"] = times
		if not on_time:
			var lates: Array = rec.get("late", [])
			lates.append(d)
			rec["late"] = lates
		var clocks: Dictionary = rec.get("clock", {})
		clocks.erase(d)
		rec["clock"] = clocks
		Save.set_daily(rec)
	return {"first": first_solve, "on_time": on_time, "ms": ms, "best_ms": time_of(d)}

## The play screen's heading in place of the level number.
static func heading() -> Stat:
	return Stat.new("Daily" if day == today() else "Past day", DailyDays.short(day), 44)

## The play screen's clock in place of its stars. A day not solved yet carries on from the time already spent.
static func clock() -> VBoxContainer:
	_clock = DailyClock.new(day, 0 if solved(day) else spent(day))
	return Stat.titled("Time", _clock)

## The play screen calls this on a win, once, and gets the sheet it opens.
static func solved_now(host: Node) -> Sheet:
	var ms: int = _clock.stop() if is_instance_valid(_clock) else 0
	var result: Dictionary = record(day, ms)
	Analytics.event(&"daily_end", {"seconds": floori(ms / 1000.0), "first": result["first"],
		"late": not bool(result["on_time"])})
	if bool(result["first"]) and bool(result["on_time"]):
		PlayGames.submit(&"daily", ms)
	PlayGames.progressed()
	await host.get_tree().create_timer(0.3).timeout
	if not is_instance_valid(host) or not host.is_inside_tree():
		return null
	Audio.play(&"win", -3.0)
	return DailyResult.open(host, day, result)

## The title screen's way in, under its other buttons.
static func title_button(host: Node, width: float) -> Control:
	var button: Button = UI.button("Daily puzzle", UI.Style.GHOST)
	button.custom_minimum_size.x = width
	button.add_child(_Badge.new())
	button.pressed.connect(func() -> void:
		if is_open():
			Screens.go(SCENE)
		else:
			Toast.say(host, "The daily puzzle opens after level %d" % opens_after()))
	return UI.centred(button)

static func _days(key: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for d: Variant in Save.daily.get(key, []):
		out.append(int(d))
	return out

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(BANK):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BANK))
	if not data is Dictionary:
		push_error("daily: cannot read %s" % BANK)
		return
	_levels = (data as Dictionary).get("levels", [])
	_first = DailyDays.from_date(String((data as Dictionary).get("first", "")))
	_opens_after = int((data as Dictionary).get("opens_after", 0))

## Today's state at the button's right end: a dot while today's puzzle waits, the streak once it is solved,
## a lock before the daily opens.
class _Badge extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		offset_left = -96.0
		offset_right = -24.0

	func _draw() -> void:
		var c: Vector2 = Vector2(size.x - 24.0, size.y * 0.5)
		if not Daily.is_open():
			Icons.draw(self, &"lock", c, 40.0, Color(Brand.MUTED, 0.8))
		elif not Daily.solved(Daily.today()):
			draw_circle(c, 9.0, Brand.ACCENT, true, -1.0, true)
		elif Daily.streak() > 0:
			var font: Font = UI.ui_font()
			var text: String = str(Daily.streak())
			var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			Icons.draw(self, &"flame", c + Vector2(-w * 0.5 - 6.0, 0.0), 40.0, Brand.ACCENT)
			draw_string(font, c + Vector2(-w * 0.5 + 14.0, 9.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Brand.ACCENT)
