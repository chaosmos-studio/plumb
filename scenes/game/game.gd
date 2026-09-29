extends Node2D

## The play screen: one level, swipes or arrow keys to tilt, undo, restart, a hint from the solver, and
## the result. All the rules live in TiltBoard; this only routes input, keeps history, and presents.

## A drag this long, in viewport pixels, is a swipe.
const SWIPE_MIN: float = 36.0
const TOP_SPACE: float = 250.0
const BOTTOM_SPACE: float = 230.0
const SIDE_MARGIN: float = 34.0
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

var _level_label: Label
var _moves_label: Label
var _caption: Label
var _undo: Button
var _panel: Control
var _banner: Control

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
		Screens.go("res://scenes/shell/levels.tscn")

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
	_hide_overlays()
	_view.sync(board)
	Audio.play(&"undo", -4.0)
	_refresh()

func _on_restart() -> void:
	if _view.busy:
		return
	history.clear()
	board = start.copy()
	finished = false
	_hide_overlays()
	_view.sync(board)
	Audio.play(&"undo", -4.0, 0.8)
	_refresh()

func _on_hint() -> void:
	if finished or _view.busy:
		return
	if board.lost:
		_flash_caption("Undo first: that marble is gone")
		return
	var path: PackedInt32Array = TiltSolver.new().solve(board, HINT_SEARCH)
	if path.is_empty():
		_flash_caption("No way home from here. Try undo or restart")
		return
	_view.show_hint(path[0])
	Audio.play(&"hint", -4.0)

func _refresh() -> void:
	_level_label.text = "Level %d" % (level + 1)
	var n: int = history.size()
	_moves_label.text = "%d %s      par %d" % [n, "move" if n == 1 else "moves", par]
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
	if _first_with_pits():
		return "Watch the pits: they swallow any marble"
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

func _flash_caption(text: String) -> void:
	_caption.text = text
	_caption.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.2)

# --- Results ------------------------------------------------------------------------------------------

func _show_won() -> void:
	finished = true
	var moves: int = history.size()
	var earned: int = Stars.earned(moves, par)
	var improved: bool = Save.record(level, earned)
	EventBus.level_won.emit(level, moves, earned)
	await get_tree().create_timer(0.25).timeout
	Audio.play(&"win", -3.0)
	_panel = _result_panel(moves, earned, improved)

func _show_lost() -> void:
	await get_tree().create_timer(0.35).timeout
	_banner = _lost_banner()

func _hide_overlays() -> void:
	for overlay: Control in [_panel, _banner]:
		if is_instance_valid(overlay):
			overlay.queue_free()
	_panel = null
	_banner = null

# --- UI -----------------------------------------------------------------------------------------------

var _ui: Control

func _build_ui() -> void:
	_ui = UI.root(self)
	var top: HBoxContainer = HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 26.0
	top.offset_right = -26.0
	top.offset_top = 40.0
	top.offset_bottom = 130.0
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	_ui.add_child(top)
	var back: Button = UI.button("Levels")
	back.pressed.connect(func() -> void: Screens.go("res://scenes/shell/levels.tscn"))
	top.add_child(back)
	_level_label = UI.label("", 50)
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_level_label)
	var hint: Button = UI.button("Hint")
	hint.pressed.connect(_on_hint)
	top.add_child(hint)

	_moves_label = UI.label("", 30, Palette.MUTED)
	_moves_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_moves_label.offset_top = 140.0
	_moves_label.offset_bottom = 190.0
	_ui.add_child(_moves_label)

	_caption = UI.label("", 30, Palette.INK)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -225.0
	_caption.offset_bottom = -170.0
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui.add_child(_caption)

	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -150.0
	bottom.offset_bottom = -50.0
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 28)
	_ui.add_child(bottom)
	_undo = UI.button("Undo")
	_undo.pressed.connect(_on_undo)
	bottom.add_child(_undo)
	var restart: Button = UI.button("Restart")
	restart.pressed.connect(_on_restart)
	bottom.add_child(restart)

func _veil() -> ColorRect:
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(Palette.INK, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(veil)
	create_tween().tween_property(veil, "color:a", 0.35, 0.25)
	return veil

func _card(parent: Control, height: float) -> VBoxContainer:
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(centre)
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.set_corner_radius_all(44)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 10)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 40
	style.content_margin_bottom = 44
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(560, height)
	card.modulate.a = 0.0
	centre.add_child(card)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	card.add_child(box)
	_pop(card)
	return box

## Scales a card up from its centre once the container has given it a size.
func _pop(card: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.85, 0.85)
	var pop: Tween = create_tween().set_parallel(true)
	pop.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(card, "modulate:a", 1.0, 0.2)

func _result_panel(moves: int, earned: int, improved: bool) -> Control:
	var veil: ColorRect = _veil()
	var box: VBoxContainer = _card(veil, 620)
	var last: bool = level + 1 >= Pack.count()
	box.add_child(UI.label("Solved!" if not last else "Every level solved!", 64))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var icons: Array[StarIcon] = []
	for k: int in range(3):
		var star: StarIcon = StarIcon.new(96.0, false)
		row.add_child(star)
		icons.append(star)
	var detail: String = "%d %s, par %d" % [moves, "move" if moves == 1 else "moves", par]
	if earned < 3:
		detail += "\nSolve it in %d for three stars" % par
	elif improved:
		detail += "\nPerfect route"
	var info: Label = UI.label(detail, 30, Palette.MUTED)
	box.add_child(info)
	var next: Button = UI.button("Next level" if not last else "Back to levels", true)
	next.pressed.connect(_on_next)
	box.add_child(next)
	var again: Button = UI.button("Replay")
	again.pressed.connect(_on_restart)
	box.add_child(again)
	for k: int in range(earned):
		_award(icons[k], 0.35 + k * 0.22)
	return veil

func _award(star: StarIcon, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(star):
		return
	star.filled = true
	star.scale = Vector2(0.3, 0.3)
	create_tween().tween_property(star, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play(&"star", -6.0, 1.0 + 0.08 * star.get_index())
	Audio.buzz(10)

func _lost_banner() -> Control:
	var veil: ColorRect = _veil()
	var box: VBoxContainer = _card(veil, 420)
	box.add_child(UI.label("Down the pit!", 60))
	box.add_child(UI.label("Undo the move and try another way", 30, Palette.MUTED))
	var undo: Button = UI.button("Undo", true)
	undo.pressed.connect(_on_undo)
	box.add_child(undo)
	var restart: Button = UI.button("Restart")
	restart.pressed.connect(_on_restart)
	box.add_child(restart)
	return veil

func _on_next() -> void:
	if level + 1 >= Pack.count():
		Screens.go("res://scenes/shell/levels.tscn")
		return
	Pack.current = level + 1
	Screens.go("res://scenes/game/game.tscn")
