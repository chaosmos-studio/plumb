extends Node2D

## The front door: the name, a toy that shows what the game is before any words do, one primary way in,
## and settings tucked in a corner.

const PILL_WIDTH: float = 460.0

var _seesaw: Seesaw
var _stage: Control

func _ready() -> void:
	var ui: Control = UI.root(self)
	var safe: Dictionary = UI.safe_margins(get_viewport())

	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(column)
	column.add_child(UI.title(Brand.WORDMARK, 200))
	column.add_child(UI.caption(Brand.TAGLINE, 22))
	# Room for the seesaw, which is drawn in the world behind the UI.
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(0, 270)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_stage)

	var frontier: int = Save.frontier(Pack.count())
	var play: Button = UI.button("Play", UI.Style.PRIMARY)
	play.custom_minimum_size.x = PILL_WIDTH
	play.pressed.connect(func() -> void:
		Pack.current = frontier
		Screens.go(Brand.GAME_SCENE))
	column.add_child(UI.centred(play))
	if Save.total_stars() > 0:
		column.add_child(UI.spacer(8))
		column.add_child(UI.caption("Level %d" % (frontier + 1), 20))
	var levels: Button = UI.button("Levels", UI.Style.GHOST)
	levels.custom_minimum_size.x = PILL_WIDTH
	levels.pressed.connect(func() -> void: Screens.go(Brand.LEVELS_SCENE))
	column.add_child(UI.centred(levels))

	var gear: IconButton = UI.icon_button(&"settings", "Settings")
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -32.0 - IconButton.SIZE
	gear.offset_right = -32.0
	gear.offset_top = 40.0 + float(safe["top"])
	gear.offset_bottom = gear.offset_top + IconButton.SIZE
	gear.pressed.connect(func() -> void: Settings.open(self))
	ui.add_child(gear)
	Supporter.add_title_button(self, ui, gear)

	var tally: HBoxContainer = HBoxContainer.new()
	tally.name = "Tally"
	tally.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tally.offset_bottom = -64.0 - float(safe["bottom"])
	tally.offset_top = tally.offset_bottom - 48.0
	tally.alignment = BoxContainer.ALIGNMENT_CENTER
	tally.add_theme_constant_override("separation", 10)
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally.add_child(StarIcon.new(30.0, true))
	tally.add_child(UI.label("%d / %d" % [Save.total_stars(), Pack.count() * 3], 28, Brand.MUTED))
	ui.add_child(tally)

	_seesaw = Seesaw.new()
	add_child(_seesaw)
	_stage.resized.connect(_place)
	_place()
	# Last, so the seesaw is there for the intro to drop its marbles onto.
	Intro.play(self)

## Centred in the space the column left for it, wherever the layout put that on this screen shape.
func _place() -> void:
	_seesaw.position = _stage.get_global_rect().get_center() + Vector2(0, 16)

## The seesaw's marbles of these colours, kept off the bar until the intro drops them in (intro.gd).
func hold_marbles(colours: Array[int]) -> void:
	_seesaw.hold(colours)

## Those marbles falling onto the bar from `from`, points on the screen, one for each colour.
func drop_marbles(colours: Array[int], from: Array[Vector2]) -> void:
	_seesaw.drop(colours, from)
