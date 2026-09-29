extends Node2D

## The play screen: one level, swipes or arrow keys to tilt, undo, restart, a hint from the solver, and
## the result. All the rules live in TiltBoard; this only routes input, keeps history, and presents.

## A drag this long, in viewport pixels, is a swipe.
const SWIPE_MIN: float = 36.0
const TOP_SPACE: float = 300.0
const BOTTOM_SPACE: float = 260.0
const SIDE_MARGIN: float = 30.0
const HINT_SEARCH: int = 30000

var level: int = 0
var par: int = 0
var start: TiltBoard
var board: TiltBoard
var history: Array[TiltBoard] = []
var finished: bool = false

var _view: BoardView
var _queued: int = -1
var _touch_from: Vector2 = Vector2.ZERO
var _touching: bool = false
var _swiped: bool = false

var _ui: Control
var _moves: Stat
var _caption: Label
var _undo: IconButton
var _sheet: Sheet

func _ready() -> void:
	level = Pack.current
	par = Pack.par(level)
	start = Pack.board(level)
	board = start.copy()
	_view = BoardView.new()
	add_child(_view)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_view.show_board(board, _fit())
	_view.intro()
	_refresh()
	EventBus.level_started.emit(level)

func _fit() -> Vector2:
	var size: Vector2 = get_viewport_rect().size
	return Vector2(size.x - SIDE_MARGIN * 2.0, size.y - TOP_SPACE - BOTTOM_SPACE)

func _layout() -> void:
	var size: Vector2 = get_viewport_rect().size
	_view.home = Vector2(size.x * 0.5, TOP_SPACE + (size.y - TOP_SPACE - BOTTOM_SPACE) * 0.5)
	if _view.board != null:
		_view.show_board(board, _fit())

# --- Input --------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_sheet):
		if event.is_action_pressed("retry"):
			_on_restart()
		elif event.is_action_pressed("undo") and board.lost:
			_on_undo()
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		_touching = touch.pressed
		_swiped = false
		_touch_from = touch.position
	elif event is InputEventScreenDrag and _touching and not _swiped:
		var drag: InputEventScreenDrag = event
		var delta: Vector2 = drag.position - _touch_from
		if delta.length() >= SWIPE_MIN:
			_swiped = true
			if absf(delta.x) > absf(delta.y):
				_tilt(TiltBoard.RIGHT if delta.x > 0.0 else TiltBoard.LEFT)
			else:
				_tilt(TiltBoard.DOWN if delta.y > 0.0 else TiltBoard.UP)
	elif event.is_action_pressed("tilt_left"):
		_tilt(TiltBoard.LEFT)
	elif event.is_action_pressed("tilt_right"):
		_tilt(TiltBoard.RIGHT)
	elif event.is_action_pressed("tilt_up"):
		_tilt(TiltBoard.UP)
	elif event.is_action_pressed("tilt_down"):
		_tilt(TiltBoard.DOWN)
	elif event.is_action_pressed("undo"):
		_on_undo()
	elif event.is_action_pressed("retry"):
		_on_restart()
	elif event.is_action_pressed("hint"):
		_on_hint()
	elif event.is_action_pressed("back"):
		Screens.go(Brand.LEVELS_SCENE)

# --- Play ---------------------------------------------------------------------------------------------

func _tilt(dir: int) -> void:
	if finished or board.lost:
		return
	# One move can wait while the last one rolls, so quick swipes are never swallowed.
	if _view.busy:
		_queued = dir
		return
	var next: TiltBoard = board.copy()
	var move: TiltMove = next.tilt(dir)
	if not move.changed():
		_view.refuse(dir)
		return
	history.append(board)
	board = next
	_refresh()
	await _view.play(move)
	if board.lost:
		_queued = -1
		_show_lost()
	elif board.is_won():
		_queued = -1
		_show_won()
	elif _queued >= 0:
		var d: int = _queued
		_queued = -1
		_tilt(d)

func _on_undo() -> void:
	if history.is_empty() or _view.busy:
		return
	board = history.pop_back()
	finished = false
	_close_sheet()
	_view.sync(board)
	Audio.play(&"undo", -4.0)
	_refresh()

func _on_restart() -> void:
	if _view.busy:
		return
	history.clear()
	board = start.copy()
	finished = false
	_close_sheet()
	_view.sync(board)
	Audio.play(&"undo", -4.0, 0.8)
	_refresh()

## Shows where every marble would go on the solver's next tilt. Waits out a roll in progress rather than
## ignoring the tap, and always answers: a preview, or a short note saying why there is none.
func _on_hint() -> void:
	if finished:
		return
	while _view.busy:
		await get_tree().process_frame
	if board.lost:
		Toast.say(self, "Undo first: a marble fell in")
		return
	var path: PackedInt32Array = TiltSolver.new().solve(board, HINT_SEARCH)
	if path.is_empty():
		Toast.say(self, "No way home from here. Undo or restart")
		return
	_view.show_hint(path[0], board)
	Audio.play(&"hint", -4.0)

func _refresh() -> void:
	_moves.set_value(str(history.size()))
	_undo.disabled = history.is_empty()
	_caption.text = _tutorial()

## A line of guidance on the levels that introduce something, and nothing after.
func _tutorial() -> String:
	if level == 0:
		return "Swipe to tilt the board"
	if level == 1:
		return "Every marble rolls until it hits something"
	if level == 3:
		return "Par is the fewest moves possible"
	if _first_sharing_a_hole():
		return "One hole takes every marble of its colour"
	if _first_with_pits():
		return "Square pits swallow any marble"
	if _first_with_colours(2):
		return "Each marble only drops into its own colour"
	return ""

func _first_with_pits() -> bool:
	if not start.cells.has(TiltBoard.Cell.PIT):
		return false
	for i: int in range(level):
		if Pack.board(i).cells.has(TiltBoard.Cell.PIT):
			return false
	return true

func _first_sharing_a_hole() -> bool:
	if not _shares_a_hole(start):
		return false
	for i: int in range(level):
		if _shares_a_hole(Pack.board(i)):
			return false
	return true

func _first_with_colours(n: int) -> bool:
	if _colours(start) < n:
		return false
	for i: int in range(level):
		if _colours(Pack.board(i)) >= n:
			return false
	return true

static func _colours(b: TiltBoard) -> int:
	var seen: Dictionary = {}
	for c: int in b.marble_colour:
		seen[c] = true
	return seen.size()

static func _shares_a_hole(b: TiltBoard) -> bool:
	return b.marble_cell.size() > _colours(b)

# --- Results ------------------------------------------------------------------------------------------

func _show_won() -> void:
	finished = true
	var moves: int = history.size()
	var earned: int = Stars.earned(moves, par)
	Save.record(level, earned)
	EventBus.level_won.emit(level, moves, earned)
	await get_tree().create_timer(0.3).timeout
	Audio.play(&"win", -3.0)
	var last: bool = level + 1 >= Pack.count()
	var detail: PackedStringArray = PackedStringArray(["%d %s, par %d" % [moves, "move" if moves == 1 else "moves", par]])
	if earned < 3:
		detail.append("Solve it in %d for three stars" % par)
	_sheet = Result.won(self, "Every level solved" if last else "Solved", earned, detail,
		"Back to levels" if last else "Next level", _on_next, _on_restart, _to_levels)

func _show_lost() -> void:
	await get_tree().create_timer(0.35).timeout
	_sheet = Result.failed(self, "Down the pit", "Undo that tilt and try another way", "Restart",
		_on_restart, _to_levels, _on_undo)

func _close_sheet() -> void:
	if is_instance_valid(_sheet):
		_sheet.close()
	_sheet = null

func _on_next() -> void:
	if level + 1 >= Pack.count():
		_to_levels()
		return
	Pack.current = level + 1
	Screens.go(Brand.GAME_SCENE)

func _to_levels() -> void:
	Screens.go(Brand.LEVELS_SCENE)

# --- UI -----------------------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = UI.root(self)
	var back: IconButton = UI.icon_button(&"back", "Levels")
	back.pressed.connect(_to_levels)
	var hint: IconButton = UI.icon_button(&"hint", "Hint")
	hint.pressed.connect(_on_hint)
	Hud.top(_ui, back, Hud.level_heading(level), hint)

	var stats: HBoxContainer = HBoxContainer.new()
	stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stats.offset_top = Hud.TOP + IconButton.SIZE + 34.0 + float(UI.safe_margins(get_viewport())["top"])
	stats.offset_bottom = stats.offset_top + 80.0
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 64)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(stats)
	_moves = Stat.new("Moves", "0")
	stats.add_child(_moves)
	stats.add_child(Stat.new("Par", str(par)))

	_caption = Hud.caption_line(_ui)
	_undo = UI.icon_button(&"undo", "Undo")
	_undo.pressed.connect(_on_undo)
	var restart: IconButton = UI.icon_button(&"restart", "Restart")
	restart.pressed.connect(_on_restart)
	var row: Array[Control] = [_undo, restart]
	Hud.bottom(_ui, row)
