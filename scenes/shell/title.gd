extends Node2D

const PILL_WIDTH: float = 460.0

var _seesaw: Seesaw
var _stage: Control
var _level_gap: Control
var _level_line: Label
var _tally_count: Label

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

	var play: Button = UI.button("Play", UI.Style.PRIMARY)
	play.custom_minimum_size.x = PILL_WIDTH
	# Play goes on along the main path, whichever set the Levels screen last showed.
	play.pressed.connect(func() -> void:
		Pack.use(Pack.Section.MAIN)
		Pack.current = Save.main_frontier()
		Screens.go(Brand.GAME_SCENE))
	column.add_child(UI.centred(play))
	_level_gap = UI.spacer(8)
	column.add_child(_level_gap)
	_level_line = UI.caption("", 20)
	column.add_child(_level_line)
	var levels: Button = UI.button("Levels", UI.Style.GHOST)
	levels.custom_minimum_size.x = PILL_WIDTH
	levels.pressed.connect(func() -> void: Screens.go(Brand.LEVELS_SCENE))
	column.add_child(UI.centred(levels))
	if Daily.available():
		column.add_child(Daily.title_button(self, PILL_WIDTH))

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
	_tally_count = UI.label("", 28, Brand.MUTED)
	tally.add_child(_tally_count)
	ui.add_child(tally)
	Hud.title_banner(self, column, tally)
	_show_progress()
	# A cloud save restored a moment after launch announces itself this way, often while the title is open.
	EventBus.settings_changed.connect(_show_progress)

	_seesaw = Seesaw.new()
	add_child(_seesaw)
	# item_rect_changed, not resized: a banner arriving after launch re-centres the column and moves the stage without resizing it.
	_stage.item_rect_changed.connect(_place)
	_place()
	# Last, so the seesaw is there for the intro to drop its marbles onto.
	Intro.play(self)

func _show_progress() -> void:
	var stars: int = Save.total_stars()
	_level_gap.visible = stars > 0
	_level_line.visible = stars > 0
	_level_line.text = "Level %d" % (Save.main_frontier() + 1)
	_tally_count.text = "%d / %d" % [stars, Pack.total() * 3]

func _place() -> void:
	_seesaw.position = _stage.get_global_rect().get_center() + Vector2(0, 16)

## intro.gd calls this and drop_marbles by name.
func hold_marbles(colours: Array[int]) -> void:
	_seesaw.hold(colours)

## `from` holds screen points, one for each colour.
func drop_marbles(colours: Array[int], from: Array[Vector2]) -> void:
	_seesaw.drop(colours, from)
