extends Node2D

## Today's puzzle, the streak, and a month's calendar of past days to play.

const WIDTH: float = 640.0
const CELL: float = 82.0
const GAP: float = 6.0
const BANNER_GAP: float = Hud.BANNER_GAP
const LETTERS: PackedStringArray = ["S", "M", "T", "W", "T", "F", "S"]
## How far a finger may scroll the page during a tap on a day before the tap is taken for a scroll.
const SLOP: float = 12.0

var _today: int
var _month: int
var _scroll: ScrollContainer
var _calendar: VBoxContainer
var _wait: Label
var _safe_bottom: float = 0.0

func _ready() -> void:
	_today = Daily.today()
	_month = DailyDays.month_start(_today)
	var ui: Control = UI.root(self)
	var safe: Dictionary = UI.safe_margins(get_viewport())
	_safe_bottom = float(safe["bottom"])
	var top: HBoxContainer = HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = Hud.SIDE
	top.offset_right = -Hud.SIDE
	top.offset_top = Hud.TOP + float(safe["top"])
	top.offset_bottom = top.offset_top + IconButton.SIZE
	ui.add_child(top)
	var back: IconButton = UI.icon_button(&"back", "Back")
	back.pressed.connect(_leave)
	top.add_child(back)
	var title: Label = UI.title("Daily puzzle", 58)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(Hud.settings(self))

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = top.offset_bottom + 20.0
	_scroll.offset_bottom = -_safe_bottom
	ui.add_child(_scroll)
	var page: VBoxContainer = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 24)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(page)
	page.add_child(_centred(_today_card()))
	page.add_child(_centred(_stats()))
	_calendar = VBoxContainer.new()
	_calendar.add_theme_constant_override("separation", GAP)
	_calendar.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(_centred(_calendar))
	_fill_calendar()
	page.add_child(_centred(_footer()))
	page.add_child(UI.spacer(24))

	var tick: Timer = Timer.new()
	tick.wait_time = 20.0
	tick.timeout.connect(_on_tick)
	add_child(tick)
	tick.start()
	Ads.show_banner(self, _lift)
	EventBus.settings_changed.connect(func() -> void:
		if is_inside_tree():
			_fill_calendar())

func _exit_tree() -> void:
	Ads.hide_banner()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		_leave()

func _leave() -> void:
	Ads.hide_banner()
	Daily.day = -1
	Screens.go(Brand.TITLE_SCENE)

func _lift(height: float) -> void:
	_scroll.offset_bottom = -(_safe_bottom + height + BANNER_GAP) if height > 0.0 else -_safe_bottom

## A new day while the screen is open brings the new puzzle in.
func _on_tick() -> void:
	if Daily.today() != _today:
		Screens.go(Daily.SCENE)
		return
	_wait.text = "Next puzzle in %s" % DailyDays.wait(DailyDays.left(Daily.now()))

func _today_card() -> PanelContainer:
	var card: PanelContainer = _panel(Brand.SURFACE)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(box)
	box.add_child(UI.caption(DailyDays.long(_today), 24))
	var done: bool = Daily.solved(_today)
	box.add_child(UI.title("Solved in %s" % DailyDays.clock(Daily.time_of(_today)) if done else "Today's puzzle", 54))
	var play: Button = UI.button("Play again" if done else "Play", UI.Style.SECONDARY if done else UI.Style.PRIMARY)
	play.mouse_filter = Control.MOUSE_FILTER_PASS
	play.pressed.connect(func() -> void: Daily.play(_today))
	box.add_child(play)
	if PlayGames.ready():
		var board: Button = UI.button("Today's leaderboard", UI.Style.PRIMARY if done else UI.Style.GHOST)
		board.mouse_filter = Control.MOUSE_FILTER_PASS
		board.pressed.connect(func() -> void: PlayGames.show_board(&"daily", PlayGames.TODAY))
		box.add_child(board)
	_wait = UI.caption("Next puzzle in %s" % DailyDays.wait(DailyDays.left(Daily.now())), 22)
	box.add_child(_wait)
	return card

func _stats() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 72)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(Stat.new("Streak", str(Daily.streak()), 52))
	row.add_child(Stat.new("Best", str(Daily.best()), 52))
	row.add_child(Stat.new("Solved", str(Daily.solves()), 52))
	return row

func _fill_calendar() -> void:
	for child: Node in _calendar.get_children():
		child.queue_free()
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	var prev: IconButton = UI.icon_button(&"back", "Previous month")
	prev.disabled = _month <= DailyDays.month_start(Daily.first())
	prev.pressed.connect(func() -> void: _turn(-1))
	head.add_child(prev)
	var month: Label = UI.label(DailyDays.month_name(_month), 34)
	month.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(month)
	var next: IconButton = UI.icon_button(&"next", "Next month")
	next.disabled = _month >= DailyDays.month_start(_today)
	next.pressed.connect(func() -> void: _turn(1))
	head.add_child(next)
	_calendar.add_child(head)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	for letter: String in LETTERS:
		var l: Label = UI.caption(letter, 20)
		l.custom_minimum_size = Vector2(CELL, 30)
		grid.add_child(l)
	var lead: int = int(DailyDays.date(_month)["weekday"])
	for k: int in range(lead):
		var gap: Control = Control.new()
		gap.custom_minimum_size = Vector2(CELL, CELL)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(gap)
	var counted: Dictionary = Daily.counted()
	for k: int in range(DailyDays.month_length(_month)):
		var d: int = _month + k
		var cell: _DayCell = _DayCell.new(d, (lead + k) % 7, _today, Daily.first(), counted)
		cell.chosen.connect(_on_day)
		cell.scroll = _scroll
		grid.add_child(cell)
	_calendar.add_child(grid)

func _turn(by: int) -> void:
	_month = DailyDays.month_start(_month + (31 if by > 0 else -1))
	_fill_calendar()

func _on_day(d: int) -> void:
	if d > _today or d < Daily.first():
		return
	if Daily.plays_free(d):
		Daily.play(d)
	else:
		_offer(d)

## A past day not yet played, which a video opens for good.
func _offer(d: int) -> void:
	var sheet: Sheet = Sheet.open(self)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title(DailyDays.long(d), 48))
	var said: Label = UI.label("Play this day's puzzle %s. Its time is yours to keep, and the leaderboard is for each day's own puzzle." % Ads.with_one(),
		28, Brand.MUTED)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(said)
	c.add_child(UI.spacer(6))
	var watch: Button = UI.button(Ads.watch(), UI.Style.PRIMARY)
	watch.pressed.connect(func() -> void:
		sheet.close()
		Ads.rewarded(func() -> void:
			Daily.open_day(d)
			Daily.play(d),
			func() -> void: Toast.say(self, "No video right now. Try again in a moment")))
	c.add_child(watch)
	if Supporter.on_play and not Daily.keeper():
		var keep: Button = UI.button("Get the Streak keeper", UI.Style.GHOST)
		keep.pressed.connect(func() -> void:
			sheet.close()
			Shop.offer(self, GameMonetize.STREAK_ID))
		c.add_child(keep)

func _footer() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size.x = WIDTH
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var how: Label = UI.label("Tap a past day to play it. A day counts for your streak when it is solved on the day.",
		24, Brand.MUTED)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(how)
	if Supporter.on_play and not Daily.keeper():
		var keep: Button = UI.button("Missed a day? See the Streak keeper", UI.Style.GHOST)
		keep.mouse_filter = Control.MOUSE_FILTER_PASS
		keep.pressed.connect(func() -> void: Shop.offer(self, GameMonetize.STREAK_ID))
		box.add_child(keep)
	if PlayGames.ready():
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 56)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(UI.action(&"trophy", "Leaderboards", PlayGames.show_boards))
		row.add_child(UI.action(&"check", "Achievements", PlayGames.show_achievements))
		box.add_child(row)
	return box

func _panel(fill: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = WIDTH
	# A panel stops the mouse by default, and then a drag that starts on it never scrolls the page.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style: StyleBoxFlat = UI.card_box(fill)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 30
	style.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func _centred(child: Control) -> CenterContainer:
	var c: CenterContainer = UI.centred(child)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c

## One day of the month. A day that counts for the streak is filled, and runs of them are joined across the
## week, so the streak reads at a glance.
class _DayCell extends Button:
	signal chosen(d: int)

	var scroll: ScrollContainer
	var _d: int
	var _column: int
	var _today: int
	var _first: int
	var _counted: Dictionary
	var _from: float = 0.0

	func _init(d: int, column: int, today: int, first: int, counted: Dictionary) -> void:
		_d = d
		_column = column
		_today = today
		_first = first
		_counted = counted
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(CELL, CELL)
		mouse_filter = Control.MOUSE_FILTER_PASS
		disabled = d > today or d < first
		button_down.connect(func() -> void: _from = scroll.scroll_vertical if is_instance_valid(scroll) else 0.0)
		pressed.connect(func() -> void:
			var now: float = scroll.scroll_vertical if is_instance_valid(scroll) else 0.0
			if absf(now - _from) <= SLOP:
				chosen.emit(_d))

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.42
		var counts: bool = _counted.has(_d)
		if counts:
			var band: Color = Color(Brand.ACCENT, 0.22)
			if _column > 0 and _counted.has(_d - 1):
				draw_rect(Rect2(Vector2(-GAP, c.y - r * 0.62), Vector2(c.x + GAP, r * 1.24)), band)
			if _column < 6 and _counted.has(_d + 1):
				draw_rect(Rect2(Vector2(c.x, c.y - r * 0.62), Vector2(size.x - c.x, r * 1.24)), band)
			draw_circle(c, r, Brand.ACCENT, true, -1.0, true)
		elif Daily.solved(_d):
			draw_circle(c, r, Color(Brand.ACCENT, 0.14), true, -1.0, true)
		if _d == _today and not counts:
			draw_arc(c, r - 2.0, 0.0, TAU, 48, Brand.ACCENT, 4.0, true)
		var ink: Color = Brand.ACCENT_INK if counts else Brand.INK
		if disabled:
			ink = Color(Brand.MUTED, 0.4)
		var font: Font = UI.ui_font()
		var text: String = str(int(DailyDays.date(_d)["day"]))
		var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		draw_string(font, Vector2(c.x - ts.x * 0.5, c.y + 10.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink)
