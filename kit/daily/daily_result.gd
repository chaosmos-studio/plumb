class_name DailyResult
extends RefCounted

## The sheet after a daily solve: the time, where it stands, the streak, and the way to the leaderboard.

static func open(host: Node, d: int, result: Dictionary) -> Sheet:
	var sheet: Sheet = Sheet.open(host, false, false, true)
	sheet.on_back = Daily.leave
	var c: VBoxContainer = sheet.content
	var today: bool = d == Daily.today()
	c.add_child(UI.caption("Today's puzzle" if today else DailyDays.long(d), 24))
	c.add_child(UI.title(DailyDays.clock(int(result["ms"])), 104))
	var said: Label = UI.label(line(result, PlayGames.ready(), PlayGames.signed_in()), 30, Brand.MUTED)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(said)
	if Daily.streak() > 0:
		c.add_child(UI.centred(_StreakLine.new(Daily.streak())))
	c.add_child(UI.spacer(4))
	var board: bool = PlayGames.ready() and today
	var main: Button = UI.button("See today's leaderboard" if board else "Done", UI.Style.PRIMARY)
	main.pressed.connect(func() -> void:
		if board:
			PlayGames.show_board(&"daily", PlayGames.TODAY)
		else:
			Daily.leave())
	c.add_child(main)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	row.add_child(UI.action(&"share", "Share", func() -> void:
		ShareCard.send_daily(host, d, int(result["ms"]), share_text(d, int(result["ms"])))))
	row.add_child(UI.action(&"restart", "Again", func() -> void: Daily.play(d)))
	row.add_child(UI.action(&"calendar", "Daily", Daily.leave))
	c.add_child(row)
	return sheet

## What the time means, in one line.
static func line(result: Dictionary, games: bool, signed_in: bool) -> String:
	if not bool(result["first"]):
		return "Your first time was %s. Only that one counts." % DailyDays.clock(int(result["best_ms"]))
	if not bool(result["on_time"]):
		return "Played late, so it is not on the leaderboard or the streak."
	if games and signed_in:
		return "Your time is on today's leaderboard."
	if games:
		return "Sign in to Play Games to see where you rank."
	return "Come back tomorrow for the next one."

static func share_text(d: int, ms: int) -> String:
	var streak: int = Daily.streak()
	var run: String = " Streak: %d %s." % [streak, "day" if streak == 1 else "days"] if streak > 1 else ""
	return "%s daily puzzle, %s: solved in %s.%s Can you beat it? %s?from=daily" % [Brand.NAME, DailyDays.short(d),
		DailyDays.clock(ms), run, GameShare.GET]

class _StreakLine extends HBoxContainer:
	func _init(n: int) -> void:
		add_theme_constant_override("separation", 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon: _Flame = _Flame.new()
		add_child(icon)
		add_child(UI.label("%d day streak" % n, 32, Brand.ACCENT))

class _Flame extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(44, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Icons.draw(self, &"flame", size * 0.5, 44.0, Brand.ACCENT)
