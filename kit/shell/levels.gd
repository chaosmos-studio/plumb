extends Node2D

## The level grid, shared by every game in the kit: twenty tiles to a page, swipe or tap the chevrons
## to turn pages, and the page holding the next level to play opens first.

const PER_PAGE: int = 20
const COLUMNS: int = 4
const SWIPE: float = 70.0

var _page: int = 0
var _grid: GridContainer
var _dots: _PageDots
var _prev: IconButton
var _next: IconButton
var _drag_from: float = -1.0

func _ready() -> void:
	var ui: Control = UI.root(self)
	var safe: Dictionary = UI.safe_margins(get_viewport())
	var top: HBoxContainer = HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 32.0
	top.offset_right = -32.0
	top.offset_top = 40.0 + float(safe["top"])
	top.offset_bottom = top.offset_top + IconButton.SIZE
	ui.add_child(top)
	var back: IconButton = UI.icon_button(&"back", "Back")
	back.pressed.connect(func() -> void: Screens.go(Brand.TITLE_SCENE))
	top.add_child(back)
	var title: Label = UI.title("Levels", 58)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(Hud.settings(self))
	var chip: Control = UI.centred(_star_chip())
	chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	chip.offset_top = top.offset_bottom + 6.0
	chip.offset_bottom = chip.offset_top + 44.0
	ui.add_child(chip)

	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_top = 200.0 + float(safe["top"])
	centre.offset_bottom = -170.0
	centre.mouse_filter = Control.MOUSE_FILTER_PASS
	centre.gui_input.connect(_on_grid_input)
	ui.add_child(centre)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 20)
	centre.add_child(_grid)

	var pager: HBoxContainer = HBoxContainer.new()
	pager.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pager.offset_top = -150.0 - float(safe["bottom"])
	pager.offset_bottom = pager.offset_top + IconButton.SIZE
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 36)
	ui.add_child(pager)
	_prev = UI.icon_button(&"back", "Previous page")
	_prev.pressed.connect(func() -> void: _show(_page - 1, -1))
	pager.add_child(_prev)
	_dots = _PageDots.new()
	_dots.count = _pages()
	pager.add_child(_dots)
	_next = UI.icon_button(&"next", "Next page")
	_next.pressed.connect(func() -> void: _show(_page + 1, 1))
	pager.add_child(_next)

	_show(Save.frontier(Pack.count()) / PER_PAGE, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		Screens.go(Brand.TITLE_SCENE)

func _star_chip() -> Control:
	var chip: HBoxContainer = HBoxContainer.new()
	chip.add_theme_constant_override("separation", 8)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(StarIcon.new(30.0, true))
	chip.add_child(UI.label(str(Save.total_stars()), 30, Brand.MUTED))
	return chip

func _pages() -> int:
	return int(ceil(Pack.count() / float(PER_PAGE)))

func _on_grid_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_drag_from = touch.position.x
		elif _drag_from >= 0.0:
			var dx: float = touch.position.x - _drag_from
			_drag_from = -1.0
			if absf(dx) >= SWIPE:
				_show(_page + (1 if dx < 0.0 else -1), 1 if dx < 0.0 else -1)

## Shows a page; `from` slides the grid in from the right (1), the left (-1) or not at all (0).
func _show(page: int, from: int) -> void:
	var target: int = clampi(page, 0, _pages() - 1)
	if target == _page and _grid.get_child_count() > 0:
		return
	_page = target
	for child: Node in _grid.get_children():
		child.queue_free()
	var frontier: int = Save.frontier(Pack.count())
	for i: int in range(_page * PER_PAGE, mini(Pack.count(), (_page + 1) * PER_PAGE)):
		var tile: LevelTile = LevelTile.new(i, Save.best(i), Save.unlocked(i), i == frontier and Save.best(i) == 0)
		tile.pressed.connect(func() -> void:
			Pack.current = i
			Screens.go(Brand.GAME_SCENE))
		_grid.add_child(tile)
	_dots.current = _page
	_prev.disabled = _page == 0
	_next.disabled = _page >= _pages() - 1
	if from != 0:
		_grid.modulate.a = 0.0
		_grid.position.x += 60.0 * from
		var t: Tween = create_tween().set_parallel(true)
		t.tween_property(_grid, "modulate:a", 1.0, 0.2)
		t.tween_property(_grid, "position:x", _grid.position.x - 60.0 * from, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Dots under the grid, one per page, the current one filled.
class _PageDots extends Control:
	var count: int = 1:
		set(value):
			count = value
			custom_minimum_size = Vector2(maxf(40.0, count * 26.0), 40.0)
			queue_redraw()
	var current: int = 0:
		set(value):
			current = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var start: float = (size.x - (count - 1) * 26.0) * 0.5
		for k: int in range(count):
			var at: Vector2 = Vector2(start + k * 26.0, size.y * 0.5)
			if k == current:
				draw_circle(at, 7.0, Brand.INK, true, -1.0, true)
			else:
				draw_circle(at, 5.0, Color(Brand.MUTED, 0.45), true, -1.0, true)
