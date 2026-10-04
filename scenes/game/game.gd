extends Node2D

## The play screen: one level, swipes or arrow keys to tilt, undo, restart, a hint from the solver, and
## the result. All the rules live in TiltBoard; this only routes input, keeps history, and presents.

## A drag this long, in viewport pixels, is a swipe.
const SWIPE_MIN: float = 36.0
const TOP_SPACE: float = 300.0
const BOTTOM_SPACE: float = 260.0
const SIDE_MARGIN: float = 30.0
const HINT_SEARCH: int = 30000
const DIRECTION_NAMES: PackedStringArray = ["left", "right", "up", "down"]

var level: int = 0
var par: int = 0
var start: TiltBoard
var board: TiltBoard
var history: Array[TiltBoard] = []
## The tilt that led from each board in `history` to the next, for the replay.
var route: PackedInt32Array = PackedInt32Array()
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
var _restart: IconButton
var _hint: IconButton
var _sheet: Sheet
var _prompt: Sheet
var _coach: Coach
var _guided: bool = false
var _leaving: bool = false
var _banner_room: float = 0.0
var _hint_board: TiltBoard
var _hint_route: PackedInt32Array = PackedInt32Array()
## The board the last hint was given for, so asking again on it costs nothing.
var _hinted: TiltBoard
## Set by an undo or a restart, so a win after one is not a first try.
var _retried: bool = false
var _won: Result.Moment
var _earned: int = 0
var _ending: bool = false
var _replay: Replay

func _ready() -> void:
	level = Pack.current
	par = Pack.par(level)
	start = Pack.board(level)
	board = start.copy()
	var kept: Variant = Appearance.take()
	if kept is Dictionary:
		var state: Dictionary = kept
		var kept_level: int = state.get("level", -1)
		if kept_level == level:
			history.assign(state["history"])
			route = state["route"]
			board = state["board"]
	_view = BoardView.new()
	add_child(_view)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_view.show_board(board, _fit())
	_view.intro()
	_refresh()
	EventBus.settings_changed.connect(_dress_hint)
	EventBus.level_started.emit(level)
	if Coach.due(level):
		_guide()
	elif not kept is Dictionary and _opens_chapter() > 0:
		ChapterCard.show_for(self, _opens_chapter())

## The chapter this level is the first of, or -1.
func _opens_chapter() -> int:
	var chapter: int = Pack.chapter_of(level)
	return chapter if chapter >= 0 and Pack.chapter_first(chapter) == level else -1

## What a rebuild for a new theme carries over: the level as far as it has been played.
func keep() -> Dictionary:
	return {} if finished else {"level": level, "history": history.duplicate(), "route": route.duplicate(), "board": board}

func _fit() -> Vector2:
	var size: Vector2 = get_viewport_rect().size
	return Vector2(size.x - SIDE_MARGIN * 2.0, size.y - TOP_SPACE - BOTTOM_SPACE - _banner_room)

func _layout() -> void:
	var size: Vector2 = get_viewport_rect().size
	_view.home = Vector2(size.x * 0.5, TOP_SPACE + (size.y - TOP_SPACE - BOTTOM_SPACE - _banner_room) * 0.5)
	if _view.board != null:
		_view.show_board(board, _fit())

# --- Input --------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if (is_instance_valid(_coach) and _coach.blocks_input) or is_instance_valid(_prompt) or is_instance_valid(_replay):
		return
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
	route.append(dir)
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
	else:
		_coach_next()

func _on_undo() -> void:
	if history.is_empty() or _view.busy:
		return
	board = history.pop_back()
	route.resize(history.size())
	_retried = true
	finished = false
	_close_sheet()
	_view.sync(board)
	Audio.play(&"undo", -4.0)
	_refresh()
	_coach_next()

func _on_restart() -> void:
	if _view.busy:
		return
	history.clear()
	route.clear()
	_retried = true
	board = start.copy()
	finished = false
	_close_sheet()
	_view.sync(board)
	Audio.play(&"undo", -4.0, 0.8)
	_refresh()
	_coach_next()

## Shows where every marble would go on the solver's next tilt. Waits out a roll in progress rather than
## ignoring the tap, and always answers: a preview, or a short note saying why there is none. A hint the
## board cannot give costs nothing; one it can goes through the hint gate, which may offer a video.
func _on_hint() -> void:
	if finished or is_instance_valid(_prompt):
		return
	while _view.busy:
		await get_tree().process_frame
	if _hint_path().is_empty():
		return
	# The hint already given for this very board is shown again without asking twice.
	if _hinted == board:
		_reveal_hint()
		return
	_prompt = HintGate.request(self, level, _reveal_hint)

## After the gate, or a video, the board is read again: it is the board now that the hint is for.
func _reveal_hint() -> void:
	if finished:
		return
	var path: PackedInt32Array = _hint_path()
	if path.is_empty():
		return
	_view.show_hint(path[0], board)
	_hinted = board
	Audio.play(&"hint", -4.0)
	_dress_hint()

## The solver's route from here, or empty with a note saying why there is none. Solved once per board.
func _hint_path() -> PackedInt32Array:
	if board.lost:
		Toast.say(self, "Undo first: a marble fell in")
		return PackedInt32Array()
	if _hint_board != board:
		_hint_board = board
		_hint_route = TiltSolver.new().solve(board, HINT_SEARCH)
	if _hint_route.is_empty():
		Toast.say(self, "No way home from here. Undo or restart")
	return _hint_route

func _dress_hint() -> void:
	HintGate.dress(_hint, level)

func _refresh() -> void:
	_moves.set_value(str(history.size()))
	_undo.disabled = history.is_empty()
	_caption.text = "" if Coach.due(level) or finished else _tutorial()

## A line of guidance on the levels that introduce something, and nothing after.
func _tutorial() -> String:
	if level == 0:
		return "Swipe to tilt the board"
	if level == 1:
		return "Every marble rolls until it hits something"
	if level == 2:
		return "Par is the fewest moves possible"
	if _opens_chapter() > 0:
		return Pack.chapter_line(_opens_chapter())
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

# --- Guide --------------------------------------------------------------------------------------------

## Level 1's guide: the goal, where help lives, then the swipe itself on the real board. Each move is
## shown from the solver, so the guide keeps up with whatever the player tries.
func _guide() -> void:
	await get_tree().create_timer(0.7).timeout
	if finished:
		return
	_coach = Coach.open(self)
	_coach.closed.connect(func(_completed: bool) -> void: _refresh())
	_guided = true
	await _coach.step("Roll each marble into the hole of its own colour.", [_board_light()], &"", Vector2.ZERO,
		Vector2.ZERO, true)
	await _coach.step("Stuck on a level? The bulb shows your next tilt. Undo takes one back, and restart begins again.",
		[_button_light(_hint), _button_light(_undo), _button_light(_restart)], &"", Vector2.ZERO, Vector2.ZERO, true)
	_coach_next()

func _coach_next() -> void:
	if not is_instance_valid(_coach) or _coach.done or _coach.waiting or finished or board.lost:
		return
	var path: PackedInt32Array = TiltSolver.new().solve(board, HINT_SEARCH)
	if path.is_empty():
		return
	var xf: Transform2D = _view.get_global_transform_with_canvas()
	var tray: Rect2 = _view.bounds()
	var d: Vector2 = Vector2(TiltBoard.DIRS[path[0]])
	var reach: float = minf(tray.size.x, tray.size.y) * 0.3
	var from: Vector2 = xf * (tray.get_center() - d * reach)
	var to: Vector2 = xf * (tray.get_center() + d * reach)
	var text: String = "Swipe %s to tilt the board. Every marble rolls until it hits something." % DIRECTION_NAMES[path[0]] \
		if history.is_empty() else "Now swipe %s." % DIRECTION_NAMES[path[0]]
	_coach.step(text, [_board_light()], &"swipe", from, to)

func _board_light() -> Vector3:
	var xf: Transform2D = _view.get_global_transform_with_canvas()
	var tray: Rect2 = _view.bounds()
	var a: Vector2 = xf * tray.position
	var b: Vector2 = xf * tray.end
	return Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, maxf(absf(b.x - a.x), absf(b.y - a.y)) * 0.5)

static func _button_light(button: Control) -> Vector3:
	var r: Rect2 = button.get_global_rect()
	return Vector3(r.get_center().x, r.get_center().y, r.size.x * 0.62)

# --- Results ------------------------------------------------------------------------------------------

func _show_won() -> void:
	finished = true
	if is_instance_valid(_coach):
		_coach.finish()
	var moves: int = history.size()
	_earned = Stars.earned(moves, par)
	_ending = Finale.due(level)
	_won = Result.Moment.new()
	_won.level = level
	_won.summary = _score()
	_won.before = Save.best(level)
	_won.clean = not _retried
	_won.watch = _watch
	Save.record(level, _earned)
	EventBus.level_won.emit(level, moves, _earned)
	await get_tree().create_timer(0.3).timeout
	Audio.play(&"win", -3.0)
	_show_result()

func _score() -> String:
	var moves: int = history.size()
	return "%d %s, par %d" % [moves, "move" if moves == 1 else "moves", par]

func _show_result() -> void:
	var last: bool = level + 1 >= Pack.count()
	var detail: PackedStringArray = PackedStringArray([_score()])
	if _earned < 3:
		detail.append("Solve it in %d for three stars" % par)
	var next_text: String = "Continue" if _ending else ("Back to levels" if last else "Next level")
	_sheet = Result.won(self, "Every level solved" if last else "", _earned, detail, next_text,
		_on_finale if _ending else _on_next, _on_restart, _to_levels, _won)

## The solve again from the start, at speed, then the result once more. A tap skips to the end.
func _watch() -> void:
	if _view.busy or not finished:
		return
	_close_sheet()
	var solved: TiltBoard = board
	var replay: Replay = Replay.begin(self)
	_replay = replay
	board = start.copy()
	_view.sync(board)
	await get_tree().create_timer(0.45).timeout
	for dir: int in route:
		if replay.skipping or not is_inside_tree():
			break
		var next: TiltBoard = board.copy()
		var move: TiltMove = next.tilt(dir)
		board = next
		await _view.play(move)
		await get_tree().create_timer(0.1).timeout
	if not is_inside_tree():
		return
	board = solved
	_view.sync(board, false)
	replay.finish()
	_show_result()

func _show_lost() -> void:
	await get_tree().create_timer(0.35).timeout
	_sheet = Result.failed(self, "Down the pit", "Undo that tilt and try another way", "Restart",
		_on_restart, _to_levels, _on_undo)

func _close_sheet() -> void:
	if is_instance_valid(_sheet):
		_sheet.close()
	_sheet = null

func _on_finale() -> void:
	_close_sheet()
	Finale.open(self, _to_levels)

## The one place an ad between levels may come, and only when the pacing allows one.
func _on_next() -> void:
	if level + 1 >= Pack.count():
		_to_levels()
		return
	if _leaving:
		return
	_leaving = true
	Ads.maybe_interstitial(_advance, _guided)

func _advance() -> void:
	Pack.current = level + 1
	Screens.go(Brand.GAME_SCENE)

func _to_levels() -> void:
	Screens.go(Brand.LEVELS_SCENE)

# --- UI -----------------------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = UI.root(self)
	var back: IconButton = UI.icon_button(&"back", "Levels")
	back.pressed.connect(_to_levels)
	_hint = UI.icon_button(&"hint", "Hint")
	_hint.pressed.connect(_on_hint)
	_dress_hint()
	Hud.top(_ui, back, Hud.level_heading(level), _hint)

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
	_restart = UI.icon_button(&"restart", "Restart")
	_restart.pressed.connect(_on_restart)
	var row: Array[Control] = [_undo, _restart, Hud.settings(self)]
	var bar: HBoxContainer = Hud.bottom(_ui, row)
	if not Coach.due(level):
		Hud.banner(self, bar, _caption, _on_lift)

## The banner's room under the bottom row: the board fits what is left. During _ready the first layout,
## which comes after the UI is built, picks it up.
func _on_lift(lift: float) -> void:
	_banner_room = lift
	if is_node_ready():
		_layout()
