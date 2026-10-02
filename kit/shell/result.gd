class_name Result
extends RefCounted

## The end-of-level sheets. A win shows the stars arriving one by one, a line or two of detail, the next
## step as the primary action, and replay and levels as quiet ones. A failure leads with trying again.

const STAR_SIZE: float = 92.0
const STAR_GAP: float = 0.2

## Opens the win sheet. `detail` lines are shown muted under the stars.
static func won(host: Node, heading: String, earned: int, detail: PackedStringArray, next_text: String,
		on_next: Callable, on_replay: Callable, on_levels: Callable) -> Sheet:
	var sheet: Sheet = Sheet.open(host, false)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title(heading, 68))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	c.add_child(row)
	var icons: Array[StarIcon] = []
	for k: int in range(3):
		var star: StarIcon = StarIcon.new(STAR_SIZE, false)
		row.add_child(star)
		icons.append(star)
	for line: String in detail:
		c.add_child(UI.label(line, 30, Brand.MUTED))
	c.add_child(UI.spacer(6))
	var next: Button = UI.button(next_text, UI.Style.PRIMARY)
	next.pressed.connect(on_next)
	c.add_child(next)
	c.add_child(_quiet_row(on_replay, on_levels))
	for k: int in range(earned):
		_award(host, icons[k], 0.4 + k * STAR_GAP)
	return sheet

## Opens the failure sheet. It leads with Undo when `on_undo` is given, or else with `more_text` when
## `on_more` is given (Revive's one more heart or tap), with retry then a quiet choice beside Levels.
static func failed(host: Node, heading: String, line: String, retry_text: String, on_retry: Callable,
		on_levels: Callable, on_undo: Callable = Callable(), more_text: String = "",
		on_more: Callable = Callable()) -> Sheet:
	var sheet: Sheet = Sheet.open(host, false)
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

static func _award(host: Node, star: StarIcon, delay: float) -> void:
	await host.get_tree().create_timer(delay).timeout
	if not is_instance_valid(star):
		return
	star.filled = true
	star.scale = Vector2(0.3, 0.3)
	star.create_tween().tween_property(star, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play(&"star", -6.0, 1.0 + 0.08 * star.get_index())
	Audio.buzz(10)
