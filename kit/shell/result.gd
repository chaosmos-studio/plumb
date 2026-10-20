class_name Result
extends RefCounted

const STAR_SIZE: float = 92.0
const STAR_GAP: float = 0.2

class Moment extends RefCounted:
	var level: int = 0
	## The game's word for one move, for the lines that count them.
	var unit: String = "move"
	## The score in a few words, as the share card and its message give it: "4 moves, goal 4".
	var summary: String = ""
	## The level's best stars before this win: 0 the first time it is solved.
	var before: int = 0
	## Set by the win sheet.
	var stars: int = 0
	## No undo, restart or extra on the way.
	var clean: bool = false
	## Replays the solve at speed and then shows the sheet again. Invalid where the game has no replay.
	var watch: Callable = Callable()
	## The heading and line Cheers chose, kept so the sheet says the same after a replay.
	var words: PackedStringArray = PackedStringArray()
	## The share card, made once, so the sheet shows the same print after a replay.
	var card: Image = null

## With a `moment`, an empty `heading` is chosen by Cheers.
static func won(host: Node, heading: String, earned: int, detail: PackedStringArray, next_text: String,
		on_next: Callable, on_replay: Callable, on_levels: Callable, moment: Moment = null) -> Sheet:
	# The first time, the snapshot is caught before the sheet, which rises as the print flies above it.
	var caught: bool = moment != null and moment.card == null and Snapshot.can_take()
	var sheet: Sheet = Sheet.open(host, false, caught, true)
	sheet.on_back = on_levels
	var c: VBoxContainer = sheet.content
	if moment != null:
		moment.stars = earned
	if moment != null and moment.words.is_empty():
		moment.words = Cheers.pick(moment, earned)
	var title: String = heading if heading != "" or moment == null else moment.words[0]
	c.add_child(UI.title(title, 68))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	c.add_child(row)
	var icons: Array[StarIcon] = []
	for k: int in range(3):
		var star: StarIcon = StarIcon.new(STAR_SIZE, false)
		row.add_child(star)
		icons.append(star)
	if moment != null:
		var said: Label = UI.label(moment.words[1], 32)
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(said)
	for line: String in detail:
		c.add_child(UI.label(line, 28, Brand.MUTED))
	c.add_child(UI.spacer(4))
	var next: Button = UI.button(next_text, UI.Style.PRIMARY)
	next.pressed.connect(on_next)
	c.add_child(next)
	if moment != null:
		c.add_child(_actions(moment, on_replay, on_levels))
		Snapshot.take(host, sheet, moment, earned, title)
	else:
		c.add_child(_quiet_row(on_replay, on_levels))
	_awards(host, sheet, icons, earned)
	return sheet

static func _awards(host: Node, sheet: Sheet, icons: Array[StarIcon], earned: int) -> void:
	if sheet.held:
		await sheet.rising
	for k: int in range(earned):
		_award(host, icons[k], 0.4 + k * STAR_GAP, earned == 3 and k == 2)

static func failed(host: Node, heading: String, line: String, retry_text: String, on_retry: Callable,
		on_levels: Callable, on_undo: Callable = Callable(), more_text: String = "",
		on_more: Callable = Callable()) -> Sheet:
	var sheet: Sheet = Sheet.open(host, false, false, true)
	sheet.on_back = on_levels
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title(heading, 64))
	c.add_child(UI.label(line, 30, Brand.MUTED))
	c.add_child(UI.spacer(6))
	var lead: Callable = on_undo if on_undo.is_valid() else on_more
	var primary: Button = UI.button(retry_text, UI.Style.PRIMARY)
	if on_undo.is_valid():
		primary.text = "Undo"
	elif on_more.is_valid():
		primary.text = more_text
	primary.pressed.connect(lead if lead.is_valid() else on_retry)
	c.add_child(primary)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	if lead.is_valid():
		var again: Button = UI.button(retry_text, UI.Style.GHOST)
		again.pressed.connect(on_retry)
		row.add_child(again)
	var levels: Button = UI.button("Levels", UI.Style.GHOST)
	levels.pressed.connect(on_levels)
	row.add_child(levels)
	c.add_child(row)
	return sheet

static func _actions(moment: Moment, on_replay: Callable, on_levels: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	if moment.watch.is_valid():
		row.add_child(UI.action(&"watch", "Watch", func() -> void: moment.watch.call()))
	row.add_child(UI.action(&"restart", "Again", on_replay))
	row.add_child(UI.action(&"levels", "Levels", on_levels))
	return row

static func _quiet_row(on_replay: Callable, on_levels: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var replay: Button = UI.button("Replay", UI.Style.GHOST)
	replay.pressed.connect(on_replay)
	row.add_child(replay)
	var levels: Button = UI.button("Levels", UI.Style.GHOST)
	levels.pressed.connect(on_levels)
	row.add_child(levels)
	return row

static func _award(host: Node, star: StarIcon, delay: float, burst: bool) -> void:
	await host.get_tree().create_timer(delay).timeout
	if not is_instance_valid(star):
		return
	star.filled = true
	star.scale = Vector2(0.3, 0.3)
	star.create_tween().tween_property(star, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play(&"star", -6.0, 1.0 + 0.08 * star.get_index())
	Audio.buzz(10)
	if burst:
		var sparks: _Sparks = _Sparks.new()
		sparks.position = star.size * 0.5
		star.add_child(sparks)

class _Sparks extends Node2D:
	const COUNT: int = 12
	const REACH: float = 120.0
	const LIFE: float = 0.6

	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta / LIFE
		if _t >= 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var out: float = 1.0 - pow(1.0 - _t, 3.0)
		for k: int in range(COUNT):
			var a: float = TAU * k / COUNT + 0.3
			var at: Vector2 = Vector2(cos(a), sin(a)) * (30.0 + REACH * out)
			var colour: Color = Brand.GOLD if k % 2 == 0 else Brand.ACCENT
			draw_circle(at, 7.0 * (1.0 - _t), Color(colour, 1.0 - _t), true, -1.0, true)
