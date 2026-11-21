class_name StreetPlay
extends Node2D

## Street's play screen (REVAMP_PLAN.md section 3, build/review/revamp2/3-play.png): the board, as BoardView draws it
## in Street's colours, under a hanging street sign with the door's number, the moves against par, and a row of the
## level's faces that turn happy as each colour gets home. Round Undo, Restart and Hint buttons sit below. A win has
## nothing to press: the marbles roll into their houses, the windows light, the stars land, and the street takes the
## player on to the next door.

const SCENE: String = "res://scenes/street/play.tscn"
## A drag this long, in design pixels, is a swipe.
const SWIPE_MIN: float = 36.0
## The top bar (the sign, the moves and the faces) starts this far below the safe area: a little on a short screen,
## more on a tall one, which has sky to spare. The board starts BOARD_TOP below it.
const TOP_SHORT: float = 24.0
const TOP_TALL: float = 60.0
const BOARD_TOP: float = 437.0
## Room between the board and the buttons, and the buttons' distance from the bottom.
const ROW_GAP: float = 36.0
const ROW_BOTTOM: float = 64.0
const SIDE_MARGIN: float = 22.0
const HINT_SEARCH: int = 30000
## With faces on, a fall takes this long before its memorial.
const FALL_TIME: float = 0.5
## From the winning tilt to the homecoming: the last marble's slow drop and its chord.
const WIN_PAUSE: float = 0.7
## The bottom row's buttons.
const BUTTON: float = 168.0
## The wide layout: the room kept free either side of the board for the rails, the board's margin top and bottom,
## and the right rail's column of buttons, their gap and their distance from the edge.
const WIDE_RAIL: float = 360.0
const WIDE_MARGIN: float = 36.0
const WIDE_BUTTON: float = 140.0
const WIDE_BUTTON_GAP: float = 28.0
const WIDE_EDGE: float = 30.0
const DIRECTION_NAMES: PackedStringArray = ["left", "right", "up", "down"]
## Ghost marbles show once a drag has gone this far, in design pixels, toward a tilt.
const GHOST_FROM: float = 14.0

## The helpers picked on the start card for the next board (StreetRewards.Booster values), used up as it opens.
static var helpers: PackedInt32Array = PackedInt32Array()
## The door to play, set by the map: its board comes from the street (Street.board).
static var door: int = 1

## The door's index from 0, as the kit's level signals and the hint gate count.
var level: int = 0
var par: int = 0
var start: TiltBoard
var board: TiltBoard
var history: Array[TiltBoard] = []
var route: PackedInt32Array = PackedInt32Array()
var finished: bool = false

var _view: BoardView
var _queued: int = -1
var _touch_from: Vector2 = Vector2.ZERO
var _touching: bool = false
var _swiped: bool = false
var _phone: PhoneTilt = PhoneTilt.new()
var _hud: _Hud
var _undo: StreetUI.RoundButton
var _restart: StreetUI.RoundButton
var _hint: StreetUI.RoundButton
var _home: StreetUI.RoundButton
var _prompt: Sheet
var _memorial: Memorial
var _hint_board: TiltBoard
var _hint_route: PackedInt32Array = PackedInt32Array()
var _hinted: TiltBoard
var _retried: bool = false
## Whether the board was started over, which the golden knocker never allows (an undo it does).
var _restarted: bool = false
## The helpers in use on this board (REVAMP_PLAN.md section 4.7): Footprints shows the solver's first two tilts, one
## at a time, while the player follows them; Ghost marbles shows where one drag's tilt would leave every marble; Spare
## step gives one move of leeway for the stars. Footprints and ghosts count as help, so the knocker waits for a board
## won without them.
var _footprints: PackedInt32Array = PackedInt32Array()
var _ghosts: bool = false
var _spare: bool = false
var _helped: bool = false
var _ghost_dir: int = -1
## How the board went, for the rating (StreetRating.outcome) and analytics.
var _hints: int = 0
var _restarts: int = 0
var _undos: int = 0
var _helpers_used: int = 0
var _celebrating: bool = false
var _hurry: bool = false
var _finger: _Finger
var _homecoming: StreetHomecoming
var _started_us: int = 0

func _ready() -> void:
	Palette.use_street()
	level = door - 1
	par = Street.par(door)
	start = Street.board(door)
	board = start.copy()
	_started_us = Time.get_ticks_usec()
	var backdrop: TextureRect = TextureRect.new()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.z_index = -10
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_view = BoardView.new()
	_view.family = Litter.family_for(level)
	_view.litter = level
	add_child(_view)
	_build_ui()
	var lay: Callable = func() -> void:
		backdrop.size = get_viewport_rect().size
		backdrop.texture = StreetArt.backdrop(StreetArt.PLAY_BACKDROP, wide())
		_layout()
	get_viewport().size_changed.connect(lay)
	lay.call()
	_view.show_board(board, _fit())
	_view.intro()
	Celebration.install(get_tree())
	if Save.faces:
		Memorial.warm(self)
	_refresh()
	Analytics.level_context = Street.analytics(door)
	EventBus.level_started.emit(level)
	if level == 0 and not Save.tutorial_seen:
		_teach()
	_use_helpers()
	# The win's backdrop loads on a thread while the board is played, so the homecoming opens without reading it.
	StreetArt.prefetch_backdrop(StreetArt.WIN_BACKDROP, wide())

## Takes the picked helpers from the purse and sets them going.
func _use_helpers() -> void:
	var picked: PackedInt32Array = helpers
	helpers = PackedInt32Array()
	for b: int in picked:
		var id: String = StreetRewards.BOOSTER_IDS[b]
		if Save.booster_count(id) <= 0:
			continue
		Save.add_booster(id, -1)
		_helpers_used += 1
		Analytics.event(&"booster_use", {"booster": id, "level": door, "board": Street.id_of(door)})
		match b:
			StreetRewards.Booster.FOOTPRINTS:
				_footprints = TiltSolver.new().solve(board, HINT_SEARCH).slice(0, 2)
				_helped = true
			StreetRewards.Booster.GHOSTS:
				_ghosts = true
			StreetRewards.Booster.SPARE_STEP:
				_spare = true
	if not _footprints.is_empty():
		await get_tree().create_timer(0.6).timeout
		_step_footprints()

## Shows the next footprint, while the player has followed the ones before.
func _step_footprints() -> void:
	if _footprints.is_empty() or finished or not is_inside_tree():
		return
	_view.show_hint(_footprints[0], board)

## A drag's direction as a tilt.
static func _drag_dir(delta: Vector2) -> int:
	if absf(delta.x) > absf(delta.y):
		return TiltBoard.RIGHT if delta.x > 0.0 else TiltBoard.LEFT
	return TiltBoard.DOWN if delta.y > 0.0 else TiltBoard.UP

## Shows where tilt `dir` would leave every marble, faint, or hides them for -1.
func _show_ghosts(dir: int) -> void:
	if dir == _ghost_dir:
		return
	_ghost_dir = dir
	var ghosts: _Ghosts = _view.get_node_or_null("Ghosts")
	if ghosts == null:
		ghosts = _Ghosts.new()
		ghosts.name = "Ghosts"
		ghosts.view = _view
		_view.add_child(ghosts)
	ghosts.after = null
	if dir >= 0:
		var after: TiltBoard = board.copy()
		if after.tilt(dir).changed():
			ghosts.after = after
		Audio.play(&"clink", -18.0, 1.4)
	ghosts.queue_redraw()

## Where the top bar starts.
func top_y() -> float:
	var size: Vector2 = get_viewport_rect().size
	var tall: float = clampf((size.y - 1280.0) / 322.0, 0.0, 1.0)
	return float(UI.safe_margins(get_viewport())["top"]) + lerpf(TOP_SHORT, TOP_TALL, tall)

## The bottom row's top edge.
func _row_y() -> float:
	return get_viewport_rect().size.y - float(UI.safe_margins(get_viewport())["bottom"]) - ROW_BOTTOM - BUTTON

## Whether the screen gets the wide layout: the board in the middle, the sign and the moves on the left rail, the
## faces and the buttons on the right one (StreetLayout).
func wide() -> bool:
	return StreetLayout.wide(get_viewport_rect().size)

## The board's room. Portrait: from under the top bar to above the buttons. Wide: a square in the middle, as large as
## the screen's height allows with a rail left either side.
func room() -> Rect2:
	var size: Vector2 = get_viewport_rect().size
	var safe: Dictionary = UI.safe_margins(get_viewport())
	if wide():
		var side: float = minf(size.y - float(safe["top"]) - float(safe["bottom"]) - WIDE_MARGIN * 2.0,
			size.x - WIDE_RAIL * 2.0)
		var middle: Vector2 = Vector2(size.x * 0.5, (float(safe["top"]) + size.y - float(safe["bottom"])) * 0.5)
		return Rect2(middle - Vector2(side, side) * 0.5, Vector2(side, side))
	var top: float = top_y() + BOARD_TOP
	return Rect2(SIDE_MARGIN, top, size.x - SIDE_MARGIN * 2.0, _row_y() - ROW_GAP - top)

func _fit() -> Vector2:
	return room().size

func _layout() -> void:
	var size: Vector2 = get_viewport_rect().size
	var safe: Dictionary = UI.safe_margins(get_viewport())
	var area: Rect2 = room()
	_view.home = area.get_center()
	if _view.board != null:
		_view.show_board(board, _fit())
	var buttons: Array[StreetUI.RoundButton] = [_undo, _restart, _hint]
	if wide():
		# A column down the right edge, centred on the board.
		var column: float = WIDE_BUTTON * 3.0 + WIDE_BUTTON_GAP * 2.0
		for i: int in range(3):
			buttons[i].custom_minimum_size = Vector2.ONE * WIDE_BUTTON
			buttons[i].size = Vector2.ONE * WIDE_BUTTON
			buttons[i].position = Vector2(size.x - float(safe["right"]) - WIDE_EDGE - WIDE_BUTTON,
				area.get_center().y - column * 0.5 + i * (WIDE_BUTTON + WIDE_BUTTON_GAP))
		_home.position = Vector2(float(safe["left"]) + 18.0, size.y - float(safe["bottom"]) - 18.0 - _home.size.y)
		_hud.queue_redraw()
		return
	var row_y: float = _row_y()
	var gap: float = (size.x - BUTTON * 3.0) / 4.0
	for i: int in range(3):
		buttons[i].custom_minimum_size = Vector2.ONE * BUTTON
		buttons[i].size = Vector2.ONE * BUTTON
		buttons[i].position = Vector2(gap + i * (BUTTON + gap), row_y)
	_home.position = Vector2(18.0, top_y())
	_hud.queue_redraw()

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_hud = _Hud.new()
	_hud.play = self
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud)
	_undo = StreetUI.RoundButton.new(StreetUI.RED, &"undo", BUTTON)
	_undo.pressed.connect(_on_undo)
	_restart = StreetUI.RoundButton.new(StreetUI.TEAL, &"restart", BUTTON)
	_restart.pressed.connect(_on_restart)
	_hint = StreetUI.RoundButton.new(StreetUI.YELLOW, &"hint", BUTTON)
	_hint.pressed.connect(_on_hint)
	_home = StreetUI.RoundButton.new(StreetUI.PURPLE, &"home", 92.0)
	_home.pressed.connect(_to_street)
	for b: StreetUI.RoundButton in [_undo, _restart, _hint, _home]:
		root.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_prompt):
		return
	if _celebrating:
		if event.is_pressed() and not event.is_echo() and not event is InputEventMouseMotion:
			# A tap on a house or a marble wobbles it, and anywhere else hurries the homecoming along.
			var at: Vector2 = (event as InputEventScreenTouch).position if event is InputEventScreenTouch else Vector2(-1, -1)
			if not (is_instance_valid(_homecoming) and _homecoming.poke(at)):
				_hurry = true
		return
	if is_instance_valid(_memorial):
		if event.is_pressed() and not event.is_echo() and not event is InputEventMouseMotion:
			_memorial.skip()
			if event.is_action_pressed("undo"):
				_on_undo()
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		# With ghost marbles out, the tilt waits for the finger to lift, and lifting short of a swipe cancels.
		if not touch.pressed and _ghost_dir >= 0:
			var dir: int = _ghost_dir
			_show_ghosts(-1)
			if touch.position.distance_to(_touch_from) >= SWIPE_MIN:
				_ghosts = false
				_helped = true
				_swiped = true
				_tilt(dir)
		# A touch that lifts without swiping is a tap: the sign, the moves or the faces under it wobble.
		if not touch.pressed and _touching and not _swiped and touch.position.distance_to(_touch_from) < SWIPE_MIN:
			_hud.poke(touch.position)
		_touching = touch.pressed
		_swiped = false
		_touch_from = touch.position
	elif event is InputEventScreenDrag and _touching and not _swiped:
		var drag: InputEventScreenDrag = event
		var delta: Vector2 = drag.position - _touch_from
		if Save.faces and not finished and not board.lost:
			_view.glance(delta / SWIPE_MIN)
		if _ghosts and not finished and not board.lost and not _view.busy:
			if delta.length() >= GHOST_FROM:
				_show_ghosts(_drag_dir(delta))
			return
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
		_to_street()

func _process(_delta: float) -> void:
	if not Save.phone_tilt or finished or is_instance_valid(_prompt) or Sheet.any_open():
		_phone.reset()
		return
	var dir: int = _phone.feed(Input.get_gravity())
	if dir >= 0:
		_tilt(dir)

func _tilt(dir: int) -> void:
	if finished or board.lost:
		return
	if _view.busy:
		_queued = dir
		return
	var next: TiltBoard = board.copy()
	var move: TiltMove = next.tilt(dir)
	if not move.changed():
		_view.refuse(dir)
		return
	if is_instance_valid(_finger):
		_finger.done()
		Save.set_tutorial_seen(true)
	history.append(board)
	route.append(dir)
	board = next
	_refresh()
	# Footprints last while the player follows them: one taken shows the next, a step elsewhere ends them.
	var followed: bool = not _footprints.is_empty() and _footprints[0] == dir
	if not _footprints.is_empty():
		_footprints = _footprints.slice(1) if followed else PackedInt32Array()
	await _view.play(move, next)
	_hud.queue_redraw()
	if followed:
		_step_footprints()
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
	if history.is_empty() or _view.busy or finished:
		return
	board = history.pop_back()
	route.resize(history.size())
	_retried = true
	_undos += 1
	_view.sync(board)
	Audio.play(&"undo", -4.0)
	_refresh()

func _on_restart() -> void:
	if _view.busy or finished:
		return
	history.clear()
	route.clear()
	_retried = true
	_restarted = true
	_restarts += 1
	board = start.copy()
	_view.sync(board)
	Audio.play(&"undo", -4.0, 0.8)
	_refresh()

## A hint the board cannot give costs nothing, so the path is found before the hint gate.
func _on_hint() -> void:
	if finished or is_instance_valid(_prompt):
		return
	while _view.busy:
		await get_tree().process_frame
	if _hint_path().is_empty():
		return
	if _hinted == board:
		_reveal_hint()
		return
	_prompt = HintGate.request(self, level, _reveal_hint)

func _reveal_hint() -> void:
	if finished:
		return
	var path: PackedInt32Array = _hint_path()
	if path.is_empty():
		return
	_view.show_hint(path[0], board)
	if _hinted != board:
		_hints += 1
	_hinted = board
	Audio.play(&"hint", -4.0)

func _hint_path() -> PackedInt32Array:
	if board.lost:
		_nudge(_undo)
		return PackedInt32Array()
	if _hint_board != board:
		_hint_board = board
		_hint_route = TiltSolver.new().solve(board, HINT_SEARCH)
	if _hint_route.is_empty() and not _walk_back():
		_nudge(_restart)
	return _hint_route

## A dead end, with no marble down a pit: take back the tilts since the last position that had a way home, so the hint
## is for there (MATH.md section 24). Free, like an undo.
func _walk_back() -> bool:
	var solver: TiltSolver = TiltSolver.new()
	var back: int = solver.way_back(history, HINT_SEARCH)
	if back < 0:
		return false
	board = history[history.size() - back]
	history.resize(history.size() - back)
	route.resize(history.size())
	_retried = true
	_hint_board = board
	_hint_route = solver.route
	_view.sync(board)
	Audio.play(&"undo", -4.0)
	_refresh()
	return true

## Points at the button that helps, with no words: a little bounce.
func _nudge(button: Control) -> void:
	var t: Tween = button.create_tween()
	t.tween_property(button, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _refresh() -> void:
	_undo.disabled = history.is_empty()
	_hud.queue_redraw()

## Door 1 teaches by doing: a finger shows the swipe the solver would make, with the one word, until the first tilt.
func _teach() -> void:
	await get_tree().create_timer(0.8).timeout
	var path: PackedInt32Array = TiltSolver.new().solve(board, HINT_SEARCH)
	if path.is_empty() or finished:
		return
	_finger = _Finger.new()
	var tray: Rect2 = _view.bounds()
	var xf: Transform2D = _view.get_global_transform_with_canvas()
	var centre: Vector2 = xf * tray.get_center()
	var reach: float = minf(tray.size.x, tray.size.y) * 0.3 * xf.get_scale().x
	var d: Vector2 = Vector2(TiltBoard.DIRS[path[0]])
	_finger.from = centre - d * reach
	_finger.to = centre + d * reach
	_finger.word_at = Vector2(centre.x, (xf * tray.position).y - 60.0)
	_hud.add_child(_finger)

func _show_won() -> void:
	finished = true
	# The street comes next: its scene loads on a thread under the homecoming.
	Screens.prefetch(StreetMap.SCENE)
	var moves: int = history.size()
	var earned: int = StreetRewards.stars(moves, par, _spare)
	var first: bool = Street.won(level + 1, earned, moves, _hints, _helpers_used, _restarts, _seconds())
	# Every win pays (REVAMP_PLAN.md section 4.7), more for stars and a clean solve, and par with no hint and no
	# restart puts the golden knocker on the door for good.
	var hinted: bool = _hinted != null or _helped
	var coins: int = StreetRewards.win_coins(earned, not _retried and not hinted)
	var knocker: bool = StreetRewards.knocker(moves, par, hinted, _restarted)
	Analytics.solve_measures = {"moves": moves, "par": par, "hints": _hints, "undos": _undos, "restarts": _restarts,
		"boosters": _helpers_used, "coins": coins}
	EventBus.level_won.emit(level, moves, earned)
	if first:
		Street.tell_analytics()
	Save.add_coins(coins)
	if knocker:
		Save.set_knocker(level + 1)
	_celebrating = true
	_hurry = false
	await _pause(WIN_PAUSE)
	var colours: PackedInt32Array = PackedInt32Array()
	for c: int in start.marble_colour:
		if c != TiltBoard.STONE and not colours.has(c):
			colours.append(c)
	var home: StreetHomecoming = StreetHomecoming.new()
	_homecoming = home
	home.colours = colours
	home.earned = earned
	home.coins = coins
	home.knocker = knocker
	home.from = _view.get_global_transform_with_canvas() * _view.bounds().get_center()
	add_child(home)
	var t: Tween = create_tween().set_parallel()
	t.tween_property(_view, "modulate:a", 0.0, 0.35)
	t.tween_property(_view, "position:y", _view.position.y + 120.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for b: CanvasItem in [_undo, _restart, _hint, _home, _hud]:
		t.tween_property(b, "modulate:a", 0.0, 0.25)
	await _pause(home.play())
	if not is_inside_tree():
		return
	# The street walks on from here only when this win opened the next door.
	StreetMap.arrival = level + 1 if first else 0
	var won_door: int = level + 1
	if (StreetRewards.has_parcel(won_door) or StreetRewards.is_milestone(won_door)) and not Save.gifts.has(won_door):
		StreetMap.gift_door = won_door
	_celebrating = false
	_to_street()

func _pause(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0 and is_inside_tree() and not _hurry:
		await get_tree().process_frame
		left -= get_process_delta_time()

func _show_lost() -> void:
	var fell: int = _view.fallen()
	if Save.faces and fell >= 0:
		await get_tree().create_timer(FALL_TIME).timeout
		if not board.lost:
			return
		var xf: Transform2D = _view.get_global_transform_with_canvas()
		_memorial = Memorial.open(self, board.marble_colour[fell], _view.marble(fell).colour, xf * _view.bounds().get_center())
		await _memorial.done
	_nudge(_undo)

func _to_street() -> void:
	if not finished:
		var seconds: float = _seconds()
		if StreetRating.counts_as_quit(history.size(), seconds):
			Analytics.event(&"level_quit", Analytics.in_level({"level": level + 1, "seconds": int(seconds),
				"moves": history.size(), "hints": _hints, "undos": _undos}))
		Street.quit(level + 1, history.size(), seconds)
		Street.tell_analytics()
	Screens.go(StreetMap.SCENE)

## Seconds since the board opened.
func _seconds() -> float:
	return float(Time.get_ticks_usec() - _started_us) / 1000000.0


## The hanging sign with the door's number, the moves against par, and the level's faces. Measures are the concept's,
## in design pixels from the top bar's start.
class _Hud extends Control:
	const POLE_X: float = 175.0
	const MOVES_RECT: Rect2 = Rect2(-282.0, 31.0, 196.0, 85.0)
	const FACES_Y: float = 306.0
	const FACES_HEIGHT: float = 114.0
	const FACE: float = 84.0
	const FACE_GAP: float = 106.0
	const BAR: Color = Color("fff6e3")
	## The wide layout's rails: the sign's top and its pole from the left edge, the moves pill under the sign, and the
	## faces' gap from the board.
	const WIDE_TOP: float = 30.0
	const WIDE_POLE_X: float = 60.0
	const WIDE_MOVES_Y: float = 300.0
	const WIDE_FACES_GAP: float = 30.0

	## A tapped sign swings on its chains this many times further than a squash rocks.
	const SIGN_SWING: float = 4.0

	var play: StreetPlay
	## The sign, the moves and the faces: each one's tap wobble, where it was last drawn, and the point it wobbles about.
	var _springs: Array[Jiggle] = [Jiggle.new(), Jiggle.new(), Jiggle.new()]
	var _rects: Array[Rect2] = [Rect2(), Rect2(), Rect2()]

	## A tap at `at`: the part under it wobbles, with a sound and a tick.
	func poke(at: Vector2) -> void:
		for i: int in range(_rects.size()):
			if _rects[i].has_point(at):
				if not Save.reduce_motion:
					_springs[i].kick(1.2 if i == 0 else 1.0)
				Audio.play([&"knock", &"pop", &"boing"][i], StreetWobbler.VOICE_DB, randf_range(0.95, 1.2))
				Audio.buzz(StreetWobbler.BUZZ_MS, StreetWobbler.BUZZ)
				set_process(true)
				return

	func _process(delta: float) -> void:
		var moving: bool = false
		for spring: Jiggle in _springs:
			moving = spring.step(delta) or moving
		queue_redraw()
		if not moving:
			set_process(false)

	## Draws what follows wobbling by spring `i` about `pivot`, the sign swinging from its chains' tops.
	func _wobble(i: int, pivot: Vector2) -> void:
		var spring: Jiggle = _springs[i]
		var turn: float = spring.tilt() * (SIGN_SWING if i == 0 else 1.0)
		var squash: Vector2 = Vector2.ONE if i == 0 else spring.squash()
		draw_set_transform_matrix(Transform2D(turn, squash, 0.0, pivot) * Transform2D(0.0, -pivot))

	func _draw() -> void:
		if play == null or play.board == null:
			return
		var w: float = size.x
		var wide: bool = play.wide()
		var safe: Dictionary = UI.safe_margins(get_viewport())
		var area: Rect2 = play.room()
		# Portrait: the top bar. Wide: the left rail holds the sign and the moves, the right one the faces.
		var top: float = float(safe["top"]) + WIDE_TOP if wide else play.top_y()
		var pole_x: float = float(safe["left"]) + WIDE_POLE_X if wide else POLE_X
		var font: Font = StreetArt.font()
		# The post, its top at the bar's start, and the sign hung from its hooks by its chains.
		var post_at: Vector2 = Vector2(pole_x, top) - Vector2(58.0, 14.0) * StreetArt.DESIGN_PER_PIXEL
		StreetArt.draw_at(self, "sign_post", post_at)
		var hooks: Array = StreetArt.meta("sign_post", "hooks")
		var hang: Array = StreetArt.meta("sign_board", "hang")
		var hook_a: Vector2 = post_at + Vector2(float(hooks[0][0]), float(hooks[0][1])) * StreetArt.DESIGN_PER_PIXEL
		var hook_b: Vector2 = post_at + Vector2(float(hooks[1][0]), float(hooks[1][1])) * StreetArt.DESIGN_PER_PIXEL
		var hang_a: Vector2 = Vector2(float(hang[0][0]), float(hang[0][1]))
		var hang_b: Vector2 = Vector2(float(hang[1][0]), float(hang[1][1]))
		var sign_k: float = hook_a.distance_to(hook_b) / (hang_a.distance_to(hang_b) * StreetArt.DESIGN_PER_PIXEL)
		var sign_at: Vector2 = hook_a - hang_a * StreetArt.DESIGN_PER_PIXEL * sign_k
		_rects[0] = Rect2(sign_at, StreetArt.size("sign_board") * sign_k)
		_wobble(0, (hook_a + hook_b) * 0.5)
		StreetArt.draw_at(self, "sign_board", sign_at, sign_k)
		var face: Rect2 = StreetArt.meta_rect("sign_board", "face")
		face = Rect2(sign_at + face.position * StreetArt.DESIGN_PER_PIXEL * sign_k,
			face.size * StreetArt.DESIGN_PER_PIXEL * sign_k)
		var number_size: int = roundi(face.size.y * 1.45)
		draw_string(font, Vector2(face.position.x, face.get_center().y + number_size * 0.36), str(play.level + 1),
			HORIZONTAL_ALIGNMENT_CENTER, face.size.x, number_size, StreetUI.INK)
		# The moves against par: the count on the red end, par on the cream.
		var pill: Rect2 = Rect2(Vector2(w + MOVES_RECT.position.x, top + MOVES_RECT.position.y), MOVES_RECT.size)
		if wide:
			pill.position = Vector2(area.position.x * 0.5 + float(safe["left"]) * 0.5 - MOVES_RECT.size.x * 0.5,
				top + WIDE_MOVES_Y)
		var k: float = pill.size.y / StreetArt.size("pill_cream").y
		_rects[1] = pill
		_wobble(1, pill.get_center())
		StreetArt.draw_nine(self, "pill_cream", pill, k)
		var red: float = float(StreetArt.meta("pill_cream", "nine")[0]) * StreetArt.DESIGN_PER_PIXEL * k * 0.86
		var moves: int = play.history.size()
		var over: bool = moves > play.par
		draw_string(font, Vector2(pill.position.x + 6.0, pill.get_center().y + 24.0), str(moves),
			HORIZONTAL_ALIGNMENT_CENTER, red, 66, StreetUI.CREAM if not over else Color("ffe08a"))
		draw_string(font, Vector2(pill.position.x + red, pill.get_center().y + 24.0), "/" + str(play.par),
			HORIZONTAL_ALIGNMENT_CENTER, pill.size.x - red - 8.0, 62, StreetUI.INK)
		# The spare step in use: its glyph on a yellow badge at the pill's corner.
		if play._spare:
			var badge: Vector2 = pill.position + Vector2(pill.size.x - 6.0, 4.0)
			StreetUI.gloss_circle(self, badge, 26.0, Color("ffc23d"))
			StreetArt.draw(self, "icon_spare_step", badge, 40.0 / StreetArt.size("icon_spare_step").x)
		# A face for each colour on the board, happy once all its marbles are home.
		var colours: PackedInt32Array = PackedInt32Array()
		var home: Dictionary = {}
		for m: int in range(play.board.marble_colour.size()):
			var c: int = play.start.marble_colour[m]
			if c == TiltBoard.STONE:
				continue
			if not colours.has(c):
				colours.append(c)
				home[c] = true
			if play.board.marble_cell[m] != TiltBoard.GONE:
				home[c] = false
		var n: int = colours.size()
		var bar_length: float = n * FACE_GAP + 56.0
		var bar: Rect2 = Rect2(w * 0.5 - bar_length * 0.5, top + FACES_Y, bar_length, FACES_HEIGHT)
		if wide:
			# Standing up beside the board, centred on it.
			bar = Rect2(area.end.x + WIDE_FACES_GAP, area.get_center().y - bar_length * 0.5, FACES_HEIGHT, bar_length)
		_rects[2] = bar
		_wobble(2, bar.get_center())
		if not wide:
			StreetUI.sparks(self, bar, 40.0)
		var bar_box: StyleBoxFlat = StyleBoxFlat.new()
		bar_box.bg_color = BAR
		bar_box.border_color = BAR.darkened(0.12)
		bar_box.border_width_bottom = 6
		bar_box.set_corner_radius_all(int(FACES_HEIGHT * 0.5))
		bar_box.corner_detail = 12
		bar_box.shadow_color = Color(0.1, 0.25, 0.05, 0.2)
		bar_box.shadow_size = 10
		bar_box.shadow_offset = Vector2(0, 6)
		draw_style_box(bar_box, bar)
		var body: float = FACE
		k = body / StreetArt.size("marble_red").x
		for i: int in range(n):
			var c: int = colours[i]
			var along: float = (float(i) - float(n - 1) * 0.5) * FACE_GAP
			var centre: Vector2 = bar.get_center() + (Vector2(0.0, along - 2.0) if wide else Vector2(along, -2.0))
			var happy: bool = bool(home[c])
			StreetArt.draw(self, "marble_" + StreetArt.COLOURS[c % 4], centre, k)
			var eye: String = "eye_happy" if happy else "eye"
			StreetArt.draw(self, eye, centre + Vector2(-0.17, -0.04) * body, k)
			StreetArt.draw(self, eye, centre + Vector2(0.17, -0.04) * body, k)
			StreetArt.draw(self, "mouth_grin" if happy else "mouth_smile", centre + Vector2(0.0, 0.16) * body, k)
		draw_set_transform(Vector2.ZERO)


## Door 1's teacher: a finger that swipes the solver's first tilt, again and again, with one word.
## Ghost marbles: faint copies of every marble where the dragged tilt would leave it, drawn over the board in its own
## space. A marble the tilt sends home or into a pit shows no ghost.
class _Ghosts extends Node2D:
	var view: BoardView
	var after: TiltBoard

	func _draw() -> void:
		if after == null:
			return
		for m: int in range(after.marble_cell.size()):
			var cell: int = after.marble_cell[m]
			if cell == TiltBoard.GONE:
				continue
			var c: Vector2 = view.centre(cell)
			var colour: Color = Palette.marble(after.marble_colour[m]) if after.marble_colour[m] != TiltBoard.STONE \
				else Color(0.55, 0.55, 0.6)
			draw_circle(c, view.cell * 0.36, Color(colour, 0.42), true, -1.0, true)
			draw_circle(c, view.cell * 0.36, Color(1, 1, 1, 0.75), false, view.cell * 0.04, true)


class _Finger extends Node2D:
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var word_at: Vector2 = Vector2.ZERO
	var _t: float = 0.0
	var _leaving: bool = false

	func done() -> void:
		if _leaving:
			return
		_leaving = true
		var t: Tween = create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.25)
		t.tween_callback(queue_free)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var phase: float = fmod(_t, 1.6) / 1.6
		var along: float = clampf((phase - 0.15) / 0.55, 0.0, 1.0)
		along = along * along * (3.0 - 2.0 * along)
		var fade: float = clampf(1.0 - absf(phase - 0.45) * 2.4, 0.0, 1.0)
		var at: Vector2 = from.lerp(to, along)
		draw_circle(at + Vector2(4, 8), 34.0, Color(0, 0, 0, 0.18 * fade), true, -1.0, true)
		draw_circle(at, 32.0, Color(1, 1, 1, 0.92 * fade), true, -1.0, true)
		draw_circle(at, 32.0, Color(0.2, 0.25, 0.35, 0.4 * fade), false, 4.0, true)
		var font: Font = StreetArt.font()
		draw_string_outline(font, word_at - Vector2(200, 0), "Swipe", HORIZONTAL_ALIGNMENT_CENTER, 400.0, 64, 12,
			Color("2c6fa8"))
		draw_string(font, word_at - Vector2(200, 0), "Swipe", HORIZONTAL_ALIGNMENT_CENTER, 400.0, 64, StreetUI.CREAM)


