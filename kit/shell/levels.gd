extends Node2D

## The level grid, shared by every game in the kit: twenty tiles to a page, swipe or tap the chevrons
## to turn pages, and the page holding the next level to play opens first. On Android, once a few levels
## are solved, a banner sits at the foot of this screen, as it does under the play screen, and the pager
## lifts clear of it.

const PER_PAGE: int = 20
const COLUMNS: int = 4
const SWIPE: float = 70.0
## Room under the pager with no banner, and the least room between the pager and a banner, so no tap
## meant for a chevron lands on the ad.
const PAGER_FLOOR: float = 54.0
const BANNER_GAP: float = 32.0
const GRID_GAP: float = 20.0
const LIFT_TIME: float = 0.28

var _page: int = 0
var _grid: GridContainer
var _dots: _PageDots
var _prev: IconButton
var _next: IconButton
var _drag_from: Vector2 = Vector2(-1.0, -1.0)
## Set when a swipe turns the page, so the tile the finger lifted on is not opened as well.
var _swiped: bool = false
var _pager: HBoxContainer
var _centre: CenterContainer
var _floor: float = PAGER_FLOOR
var _safe_bottom: float = 0.0
var _settled: bool = false

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
	back.pressed.connect(func() -> void: _leave(Brand.TITLE_SCENE))
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
	_centre = centre
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_top = 200.0 + float(safe["top"])
	centre.mouse_filter = Control.MOUSE_FILTER_PASS
	ui.add_child(centre)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 20)
	centre.add_child(_grid)

	var pager: HBoxContainer = HBoxContainer.new()
	_pager = pager
	_safe_bottom = float(safe["bottom"])
	_floor = PAGER_FLOOR + _safe_bottom
	pager.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
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

	_place(_floor)
	_show(Save.frontier(Pack.count()) / PER_PAGE, 0)
	Ads.show_banner(self, _lift)
	_settled = true

func _exit_tree() -> void:
	Ads.hide_banner()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		_leave(Brand.TITLE_SCENE)

## The banner goes the moment the player leaves, not once the fade is over.
func _leave(path: String) -> void:
	Ads.hide_banner()
	Screens.go(path)

## Sets the pager `from_bottom` above the foot of the screen, and the grid centred in the room above it.
func _place(from_bottom: float) -> void:
	_pager.offset_bottom = -from_bottom
	_pager.offset_top = _pager.offset_bottom - IconButton.SIZE
	_centre.offset_bottom = _pager.offset_top - GRID_GAP

## The banner's height in design pixels, 0 when it goes: the pager and grid move up clear of it, or back.
## A banner already loaded when the screen opens is in place from the first frame.
func _lift(height: float) -> void:
	var target: float = maxf(_floor, _safe_bottom + height + BANNER_GAP) if height > 0.0 else _floor
	var from: float = -_pager.offset_bottom
	if not _settled or is_equal_approx(from, target):
		_place(target)
		return
	create_tween().tween_method(_place, from, target, LIFT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _star_chip() -> Control:
	var chip: HBoxContainer = HBoxContainer.new()
	chip.add_theme_constant_override("separation", 8)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(StarIcon.new(30.0, true))
	chip.add_child(UI.label(str(Save.total_stars()), 30, Brand.MUTED))
	return chip

func _pages() -> int:
	return int(ceil(Pack.count() / float(PER_PAGE)))

## Swipes are read before the GUI, since nearly all of the grid is tiles, which would keep the touch for
## themselves. A sideways swipe anywhere on the grid turns the page.
func _input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch or (event as InputEventScreenTouch).index != 0 or Sheet.any_open():
		return
	var touch: InputEventScreenTouch = event
	if touch.pressed:
		_swiped = false
		_drag_from = touch.position if _centre.get_global_rect().has_point(touch.position) else Vector2(-1.0, -1.0)
		return
	if _drag_from.x < 0.0:
		return
	var moved: Vector2 = touch.position - _drag_from
	_drag_from = Vector2(-1.0, -1.0)
	if absf(moved.x) >= SWIPE and absf(moved.x) > absf(moved.y):
		_swiped = true
		_show(_page + (1 if moved.x < 0.0 else -1), 1 if moved.x < 0.0 else -1)

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
			if _swiped:
				return
			Pack.current = i
			_leave(Brand.GAME_SCENE))
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
