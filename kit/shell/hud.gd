class_name Hud
extends RefCounted

const SIDE: float = 32.0
const TOP: float = 40.0
const BOTTOM_LIFT: float = 64.0
## The least room between the bottom row and a banner under it, so a tap meant for undo, the hint or
## restart never lands on the ad: about Android's 48 dp touch target, since Google asks for a buffer but
## names no size, and accidental clicks are what it disables ad serving for.
const BANNER_GAP: float = 90.0
## The title's star tally, which takes no taps, sits this far above the banner.
const TALLY_GAP: float = 24.0

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

static func banner_lift(height: float) -> float:
	return maxf(0.0, height + BANNER_GAP - BOTTOM_LIFT) if height > 0.0 else 0.0

## `on_lift` hears the lift so the board can fit the room left. The room is held from the first frame, so
## the board does not move when the ad loads.
static func banner(host: Node, row: Control, caption: Control, on_lift: Callable) -> void:
	var rest: PackedFloat32Array = PackedFloat32Array([row.offset_top, row.offset_bottom, caption.offset_top,
		caption.offset_bottom])
	var apply: Callable = func(height: float) -> void:
		var lift: float = banner_lift(height)
		row.offset_top = rest[0] - lift
		row.offset_bottom = rest[1] - lift
		caption.offset_top = rest[2] - lift
		caption.offset_bottom = rest[3] - lift
		on_lift.call(lift)
	var expected: float = Ads.expected_banner_height(host)
	if expected > 0.0:
		apply.call(expected)
	Ads.show_banner(host, apply)

## The title's banner, under its star tally. The title is a playable toy and not a bare menu, which is what
## lets it carry an ad. `column` is the full-screen column of name, toy and buttons, and shrinks to the room
## above the banner and its gap, so no button sits next to the ad.
static func title_banner(host: Node, column: Control, tally: Control) -> void:
	var safe: Dictionary = UI.safe_margins(host.get_viewport())
	var rest: PackedFloat32Array = PackedFloat32Array([column.offset_bottom, tally.offset_top, tally.offset_bottom])
	var apply: Callable = func(height: float) -> void:
		var room: float = height + float(safe["bottom"]) if height > 0.0 else 0.0
		var tally_lift: float = maxf(0.0, room + TALLY_GAP + rest[2]) if height > 0.0 else 0.0
		tally.offset_top = rest[1] - tally_lift
		tally.offset_bottom = rest[2] - tally_lift
		column.offset_bottom = minf(rest[0], -(room + BANNER_GAP)) if height > 0.0 else rest[0]
	var expected: float = Ads.expected_banner_height(host)
	if expected > 0.0:
		apply.call(expected)
	Ads.show_banner(host, apply)

static func settings(host: Node) -> IconButton:
	var gear: IconButton = UI.icon_button(&"settings", "Settings")
	gear.pressed.connect(func() -> void: Settings.open(host))
	return gear

## The hint's place in the top bar, kept empty where there is no hint (Daily), so the heading stays centred.
static func no_hint() -> Control:
	var room: Control = Control.new()
	room.custom_minimum_size = Vector2(IconButton.SIZE, IconButton.SIZE)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return room

static func level_heading(level: int) -> Stat:
	return Stat.new(Shown.word(level).capitalize(), str(Shown.level(level)), 60)

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
