class_name Hud
extends RefCounted

## The play screen's frame, the same in every game: a top bar (left action, the level, right action)
## and a bottom row of actions, both kept clear of notches.

const SIDE: float = 32.0
const TOP: float = 40.0
const BOTTOM_LIFT: float = 64.0

static func top(ui: Control, left: Control, centre: Control, right: Control) -> HBoxContainer:
	var safe: Dictionary = UI.safe_margins(ui.get_viewport())
	var bar: HBoxContainer = HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = SIDE
	bar.offset_right = -SIDE
	bar.offset_top = TOP + float(safe["top"])
	bar.offset_bottom = bar.offset_top + IconButton.SIZE + 20.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bar)
	bar.add_child(left)
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(centre)
	bar.add_child(right)
	return bar

static func bottom(ui: Control, controls: Array[Control], separation: int = 44) -> HBoxContainer:
	var safe: Dictionary = UI.safe_margins(ui.get_viewport())
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_bottom = -BOTTOM_LIFT - float(safe["bottom"])
	row.offset_top = row.offset_bottom - IconButton.SIZE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(row)
	for c: Control in controls:
		row.add_child(c)
	return row

## The settings button every play screen carries, so sound and music are one tap away mid-level.
static func settings(host: Node) -> IconButton:
	var gear: IconButton = UI.icon_button(&"settings", "Settings")
	gear.pressed.connect(func() -> void: Settings.open(host))
	return gear

## LEVEL over the number, centred: the heading of every play screen.
static func level_heading(level: int) -> Stat:
	return Stat.new("Level", str(level + 1), 60)

## A line of guidance just above the bottom row.
static func caption_line(ui: Control) -> Label:
	var safe: Dictionary = UI.safe_margins(ui.get_viewport())
	var l: Label = UI.label("", 28, Brand.MUTED)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_bottom = -BOTTOM_LIFT - IconButton.SIZE - 28.0 - float(safe["bottom"])
	l.offset_top = l.offset_bottom - 50.0
	l.offset_left = 40.0
	l.offset_right = -40.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(l)
	return l
