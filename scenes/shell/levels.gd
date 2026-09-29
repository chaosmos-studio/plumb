extends Node2D

## Every level as a numbered tile with the stars it has earned, twenty to a page. The next unsolved
## level is picked out in the accent colour; anything past it is locked.

const PER_PAGE: int = 20
const COLUMNS: int = 4
const TILE: float = 136.0

var _page: int = 0
var _grid: GridContainer
var _page_label: Label
var _prev: Button
var _next: Button

func _ready() -> void:
	var ui: Control = UI.root(self)
	var top: HBoxContainer = HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 26.0
	top.offset_right = -26.0
	top.offset_top = 40.0
	top.offset_bottom = 130.0
	ui.add_child(top)
	var back: Button = UI.button("Back")
	back.pressed.connect(func() -> void: Screens.go("res://scenes/shell/title.tscn"))
	top.add_child(back)
	var title: Label = UI.label("Levels", 56)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var stars: HBoxContainer = HBoxContainer.new()
	stars.add_theme_constant_override("separation", 8)
	stars.add_child(StarIcon.new(36.0, true))
	stars.add_child(UI.label(str(Save.total_stars()), 34, Palette.MUTED))
	top.add_child(stars)

	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_top = 150.0
	centre.offset_bottom = -150.0
	ui.add_child(centre)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 22)
	_grid.add_theme_constant_override("v_separation", 22)
	centre.add_child(_grid)

	var pager: HBoxContainer = HBoxContainer.new()
	pager.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pager.offset_top = -140.0
	pager.offset_bottom = -50.0
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 30)
	ui.add_child(pager)
	_prev = UI.button("<")
	_prev.pressed.connect(func() -> void: _show(_page - 1))
	pager.add_child(_prev)
	_page_label = UI.label("", 32, Palette.MUTED)
	_page_label.custom_minimum_size = Vector2(200, 0)
	pager.add_child(_page_label)
	_next = UI.button(">")
	_next.pressed.connect(func() -> void: _show(_page + 1))
	pager.add_child(_next)

	_show(Save.frontier(Pack.count()) / PER_PAGE)

func _pages() -> int:
	return int(ceil(Pack.count() / float(PER_PAGE)))

func _show(page: int) -> void:
	_page = clampi(page, 0, _pages() - 1)
	for child: Node in _grid.get_children():
		child.queue_free()
	var frontier: int = Save.frontier(Pack.count())
	for i: int in range(_page * PER_PAGE, mini(Pack.count(), (_page + 1) * PER_PAGE)):
		_grid.add_child(_tile(i, i == frontier and Save.best(i) == 0))
	_page_label.text = "%d / %d" % [_page + 1, _pages()]
	_prev.disabled = _page == 0
	_next.disabled = _page >= _pages() - 1

func _tile(level: int, is_next: bool) -> Button:
	var open: bool = Save.unlocked(level)
	var tile: Button = UI.button(str(level + 1), is_next)
	tile.custom_minimum_size = Vector2(TILE, TILE)
	tile.add_theme_font_size_override("font_size", 46)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = (tile.get_theme_stylebox(state) as StyleBoxFlat).duplicate()
		box.set_corner_radius_all(30)
		box.content_margin_bottom = 46
		tile.add_theme_stylebox_override(state, box)
	tile.disabled = not open
	if open:
		tile.pressed.connect(func() -> void:
			Pack.current = level
			Screens.go("res://scenes/game/game.tscn"))
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 2)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		row.offset_top = -48.0
		row.offset_bottom = -16.0
		var earned: int = Save.best(level)
		for k: int in range(3):
			var star: StarIcon = StarIcon.new(28.0, k < earned)
			if is_next:
				star.empty_colour = Color(1, 1, 1, 0.6)
			row.add_child(star)
		tile.add_child(row)
	return tile
