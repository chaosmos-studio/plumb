extends Node2D

## The level grid, shared by every game in the kit: a page per chapter, named above the grid with how far
## along it is, for a game whose level file has chapters, otherwise twenty tiles to a page. Each page wears
## its chapter's colour and pattern (ChapterStyle). Swipe or tap the chevrons to turn pages, and the page
## holding the next level to play opens first. A locked tile says how it opens, and on Google Play offers
## to open it now (Unlocks). On Android, once a few levels are solved, a banner sits at the foot of this
## screen, as it does under the play screen, and the pager lifts clear of it.

const PER_PAGE: int = 20
const COLUMNS: int = 4
const SWIPE: float = 70.0
## Room under the pager with no banner, and the least room between the pager and a banner, so no tap
## meant for a chevron lands on the ad.
const PAGER_FLOOR: float = 54.0
const HEADING_HEIGHT: float = 72.0
const BANNER_GAP: float = 32.0
const GRID_GAP: float = 20.0
const LIFT_TIME: float = 0.28

var _page: int = 0
var _backdrop: ChapterStyle.Backdrop
var _grid: GridContainer
var _dots: _PageDots
var _prev: IconButton
var _next: IconButton
var _drag_from: Vector2 = Vector2(-1.0, -1.0)
## Set when a swipe turns the page, so the tile the finger lifted on is not opened as well.
var _swiped: bool = false
## The page's chapter, shown above the grid when the game has chapters.
var _chapter_number: Label
var _chapter_name: Label
var _pager: HBoxContainer
var _centre: CenterContainer
var _floor: float = PAGER_FLOOR
var _safe_bottom: float = 0.0
var _settled: bool = false

func _ready() -> void:
	var ui: Control = UI.root(self)
	_backdrop = ChapterStyle.Backdrop.new()
	ui.add_child(_backdrop)
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

	var grid_top: float = 200.0 + float(safe["top"])
	if not Pack.chapters.is_empty():
		var heading: VBoxContainer = VBoxContainer.new()
		heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		heading.offset_top = chip.offset_bottom + 14.0
		heading.offset_bottom = heading.offset_top + HEADING_HEIGHT
		heading.alignment = BoxContainer.ALIGNMENT_CENTER
		heading.add_theme_constant_override("separation", 2)
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chapter_number = UI.caption("", 20)
		heading.add_child(_chapter_number)
		_chapter_name = UI.label("", 36)
		heading.add_child(_chapter_name)
		ui.add_child(heading)
		grid_top = heading.offset_bottom + 12.0
	var centre: CenterContainer = CenterContainer.new()
	_centre = centre
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_top = grid_top
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
	_show(_page_of(Save.frontier(Pack.count())), 0)
	Ads.show_banner(self, _lift)
	# A level opened from a locked tile, or Every level, opens the grid where it stands.
	EventBus.settings_changed.connect(func() -> void: _show(_page, 0, true))
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

## A game with chapters (Pack.chapters) gets a page per chapter, named; one without, pages of PER_PAGE.
func _pages() -> int:
	if not Pack.chapters.is_empty():
		return Pack.chapters.size()
	return int(ceil(Pack.count() / float(PER_PAGE)))

func _page_first(page: int) -> int:
	return Pack.chapter_first(page) if not Pack.chapters.is_empty() else page * PER_PAGE

func _page_end(page: int) -> int:
	if not Pack.chapters.is_empty():
		return mini(Pack.count(), _page_first(page) + int(Pack.chapters[page]["count"]))
	return mini(Pack.count(), (page + 1) * PER_PAGE)

## The page holding `level`, the last page for a level past the end.
func _page_of(level: int) -> int:
	if Pack.chapters.is_empty():
		@warning_ignore("integer_division")
		return level / PER_PAGE
	var chapter: int = Pack.chapter_of(level)
	return chapter if chapter >= 0 else Pack.chapters.size() - 1

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

## Shows a page; `from` slides the grid in from the right (1), the left (-1) or not at all (0). `again`
## rebuilds the page in place.
func _show(page: int, from: int, again: bool = false) -> void:
	var target: int = clampi(page, 0, _pages() - 1)
	if target == _page and _grid.get_child_count() > 0 and not again:
		return
	_page = target
	for child: Node in _grid.get_children():
		child.queue_free()
	var tint: Color = ChapterStyle.tint(_page)
	_backdrop.chapter = _page
	if _chapter_name != null:
		_chapter_number.text = _standing(_page).to_upper()
		_chapter_number.add_theme_color_override("font_color", tint)
		_chapter_name.text = Pack.chapter_name(_page)
	for i: int in range(_page_first(_page), _page_end(_page)):
		var open: bool = Save.unlocked(i)
		var tile: LevelTile = LevelTile.new(i, Save.best(i), open, open and Save.best(i) == 0, tint)
		tile.pressed.connect(func() -> void:
			if _swiped:
				return
			if not open:
				Unlocks.offer(self, i)
				return
			Pack.current = i
			_leave(Brand.GAME_SCENE))
		_grid.add_child(tile)
	_dots.tint = tint
	_dots.current = _page
	_prev.disabled = _page == 0
	_next.disabled = _page >= _pages() - 1
	if from != 0:
		_grid.modulate.a = 0.0
		_grid.position.x += 60.0 * from
		var t: Tween = create_tween().set_parallel(true)
		t.tween_property(_grid, "modulate:a", 1.0, 0.2)
		t.tween_property(_grid, "position:x", _grid.position.x - 60.0 * from, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## The line over a chapter's name: its number, then how many of its levels are solved, or while its first
## level is still shut, what opens it.
func _standing(chapter: int) -> String:
	var number: String = "Chapter %d" % (chapter + 1)
	var first: int = _page_first(chapter)
	if not Save.unlocked(first) and chapter > 0:
		if not Save.unlocked(_page_first(chapter - 1)):
			return "%s   opens after chapter %d" % [number, chapter]
		var more: int = Unlocks.gate(chapter - 1) - Unlocks.solved_in(chapter - 1)
		return "%s   %d more in chapter %d opens it" % [number, more, chapter]
	var solved: int = 0
	for i: int in range(first, _page_end(chapter)):
		solved += 1 if Save.best(i) > 0 else 0
	return "%s   %d of %d solved" % [number, solved, _page_end(chapter) - first]

## Dots under the grid, one per page, the current one filled in its chapter's colour. With more pages than
## fit, a window of them slides along with the current page, and a smaller dot at either end says there are
## more beyond.
class _PageDots extends Control:
	const SHOWN: int = 9
	const GAP: float = 26.0

	var count: int = 1:
		set(value):
			count = value
			custom_minimum_size = Vector2(maxf(40.0, mini(count, SHOWN) * GAP), 40.0)
			queue_redraw()
	var current: int = 0:
		set(value):
			current = value
			queue_redraw()
	var tint: Color = Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var shown: int = mini(count, SHOWN)
		@warning_ignore("integer_division")
		var first: int = clampi(current - shown / 2, 0, count - shown)
		var left: float = (size.x - (shown - 1) * GAP) * 0.5
		for k: int in range(shown):
			var page: int = first + k
			var at: Vector2 = Vector2(left + k * GAP, size.y * 0.5)
			var more: bool = (k == 0 and first > 0) or (k == shown - 1 and first + shown < count)
			if page == current:
				draw_circle(at, 7.0, tint, true, -1.0, true)
			else:
				draw_circle(at, 3.0 if more else 5.0, Color(Brand.MUTED, 0.45), true, -1.0, true)
