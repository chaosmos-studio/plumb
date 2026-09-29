class_name BoardView
extends Node2D

## Draws a TiltBoard and animates tilts. The view never decides anything: the game applies a tilt to
## the board, gets back a TiltMove, and hands it here to be played step by step, one cell per step,
## exactly as the rules computed it.

## Seconds for a marble to roll one cell.
const STEP_TIME: float = 0.052
const MAX_CELL: float = 116.0
## How far the tray tips toward a swipe, which is most of what makes a move feel physical.
const TIP_DEGREES: float = 2.4
const TIP_SHIFT: float = 12.0
const TRAY_PAD: float = 0.32
const TILE_GAP: float = 0.06

var board: TiltBoard
var cell: float = 80.0
var busy: bool = false
## Where the tray rests. Tips and shakes always return here, so overlapping ones cannot make it drift.
var home: Vector2 = Vector2.ZERO:
	set(value):
		home = value
		position = value

var _origin: Vector2 = Vector2.ZERO
var _marbles: Array[Marble] = []
## Where each marble is drawn, which lags the board during an animation.
var _shown: PackedInt32Array = PackedInt32Array()
var _hint: Node2D

func show_board(b: TiltBoard, fit: Vector2) -> void:
	board = b
	var c: float = minf(fit.x / (b.width + TRAY_PAD * 2.0), fit.y / (b.height + TRAY_PAD * 2.0))
	cell = floorf(minf(c, MAX_CELL))
	_origin = -Vector2(b.width, b.height) * cell * 0.5
	for m: Marble in _marbles:
		m.queue_free()
	_marbles.clear()
	for i: int in range(b.marble_cell.size()):
		var marble: Marble = Marble.new()
		marble.radius = cell * 0.36
		marble.colour = Palette.marble(b.marble_colour[i])
		add_child(marble)
		_marbles.append(marble)
	sync(b, false)
	queue_redraw()

## Puts every marble where the board says, at once: after an undo or a restart.
func sync(b: TiltBoard, pop_in: bool = true) -> void:
	board = b
	_shown = b.marble_cell.duplicate()
	for i: int in range(_marbles.size()):
		var marble: Marble = _marbles[i]
		var gone: bool = b.marble_cell[i] == TiltBoard.GONE
		var was_hidden: bool = not marble.visible or marble.scale.x < 0.5
		marble.visible = not gone
		marble.modulate = Color.WHITE
		marble.rotation = 0.0
		if gone:
			continue
		marble.position = centre(b.marble_cell[i])
		if pop_in and was_hidden:
			marble.scale = Vector2(0.2, 0.2)
			create_tween().tween_property(marble, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			marble.scale = Vector2.ONE

func centre(i: int) -> Vector2:
	var at: Vector2i = board.coords(i)
	return _origin + (Vector2(at) + Vector2(0.5, 0.5)) * cell

func bounds() -> Rect2:
	var pad: float = cell * TRAY_PAD
	return Rect2(_origin - Vector2(pad, pad), Vector2(board.width, board.height) * cell + Vector2(pad, pad) * 2.0)

# --- Drawing ------------------------------------------------------------------------------------------

func _draw() -> void:
	if board == null:
		return
	var tray: StyleBoxFlat = StyleBoxFlat.new()
	tray.bg_color = Palette.TRAY
	tray.set_corner_radius_all(int(cell * 0.34))
	tray.shadow_color = Palette.TRAY_SHADOW
	tray.shadow_size = int(cell * 0.28)
	tray.shadow_offset = Vector2(0, cell * 0.12)
	tray.anti_aliasing = true
	draw_style_box(tray, bounds())
	var gap: float = cell * TILE_GAP
	var tile: StyleBoxFlat = StyleBoxFlat.new()
	tile.bg_color = Palette.TILE
	tile.set_corner_radius_all(int(cell * 0.16))
	tile.anti_aliasing = true
	var wall: StyleBoxFlat = tile.duplicate()
	wall.bg_color = Palette.WALL
	wall.border_color = Palette.WALL_LIP
	wall.border_width_bottom = int(cell * 0.1)
	for i: int in range(board.width * board.height):
		var at: Vector2i = board.coords(i)
		var rect: Rect2 = Rect2(_origin + Vector2(at) * cell + Vector2(gap, gap), Vector2(cell, cell) - Vector2(gap, gap) * 2.0)
		var c: Vector2 = rect.get_center()
		match board.cells[i]:
			TiltBoard.Cell.WALL:
				draw_style_box(wall, rect)
			TiltBoard.Cell.PIT:
				draw_style_box(tile, rect)
				draw_circle(c, cell * 0.4, Color(Palette.DANGER, 0.22), true, -1.0, true)
				draw_circle(c, cell * 0.34, Palette.PIT, true, -1.0, true)
				draw_circle(c + Vector2(0, cell * 0.05), cell * 0.26, Palette.PIT.darkened(0.5), true, -1.0, true)
			_:
				draw_style_box(tile, rect)
				var hole: int = board.holes[i]
				if hole != TiltBoard.NO_HOLE:
					var ring: Color = Palette.marble(hole)
					draw_circle(c, cell * 0.41, ring, true, -1.0, true)
					draw_circle(c, cell * 0.33, Palette.HOLE, true, -1.0, true)
					draw_circle(c + Vector2(0, cell * 0.06), cell * 0.25, Palette.HOLE.darkened(0.45), true, -1.0, true)

# --- Animation ----------------------------------------------------------------------------------------

## Plays one tilt. Returns when every marble has come to rest.
func play(move: TiltMove) -> void:
	busy = true
	_clear_hint()
	_tip(move.dir)
	Audio.play(&"roll", -9.0, randf_range(0.95, 1.05))
	var d: Vector2i = TiltBoard.DIRS[move.dir]
	for step: int in range(move.steps.size()):
		var tween: Tween = create_tween().set_parallel(true)
		for m: Variant in move.steps[step]:
			var id: int = int(m)
			var at: Vector2i = board.coords(_shown[id]) + d
			_shown[id] = board.index(at)
			tween.tween_property(_marbles[id], "position", centre(_shown[id]), STEP_TIME)
		await tween.finished
		for event: Dictionary in move.events:
			if int(event["step"]) == step:
				_drop(int(event["marble"]), event["kind"])
	if not move.stopped.is_empty():
		_bump(move.stopped, d)
		Audio.play(&"clack", -4.0, randf_range(0.94, 1.06))
		Audio.buzz(8)
	busy = false

## A swipe that moves nothing still answers: the tray twitches and settles.
func refuse(dir: int) -> void:
	var d: Vector2 = Vector2(TiltBoard.DIRS[dir])
	var t: Tween = create_tween()
	t.tween_property(self, "position", home + d * 5.0, 0.05)
	t.tween_property(self, "position", home, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _tip(dir: int) -> void:
	var t: Tween = create_tween().set_parallel(true)
	var base: Vector2 = home
	match dir:
		TiltBoard.LEFT, TiltBoard.RIGHT:
			var angle: float = deg_to_rad(TIP_DEGREES) * (-1.0 if dir == TiltBoard.LEFT else 1.0)
			t.tween_property(self, "rotation", angle, 0.08)
			t.chain().tween_property(self, "rotation", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_:
			var shift: float = TIP_SHIFT * (-1.0 if dir == TiltBoard.UP else 1.0)
			t.tween_property(self, "position:y", base.y + shift, 0.08)
			t.tween_property(self, "scale", Vector2(1.0, 0.985), 0.08)
			t.chain().tween_property(self, "position:y", base.y, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(self, "scale", Vector2.ONE, 0.34)

func _bump(ids: Array[int], d: Vector2i) -> void:
	var squash: Vector2 = Vector2(0.84, 1.14) if d.x != 0 else Vector2(1.14, 0.84)
	for id: int in ids:
		var marble: Marble = _marbles[id]
		var t: Tween = create_tween()
		t.tween_property(marble, "scale", squash, 0.05)
		t.tween_property(marble, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _drop(id: int, kind: StringName) -> void:
	var marble: Marble = _marbles[id]
	var t: Tween = create_tween().set_parallel(true)
	if kind == &"sink":
		t.tween_property(marble, "scale", Vector2(0.15, 0.15), 0.18).set_ease(Tween.EASE_IN)
		t.tween_property(marble, "modulate", Color(0.5, 0.5, 0.5, 0.0), 0.18)
		var ring: Ripple = Ripple.new()
		ring.colour = marble.colour
		ring.start_radius = cell * 0.3
		ring.end_radius = cell * 0.78
		ring.position = marble.position
		add_child(ring)
		Audio.sink(board.marble_colour[id])
		Audio.buzz(14)
	else:
		t.tween_property(marble, "scale", Vector2(0.05, 0.05), 0.42).set_ease(Tween.EASE_IN)
		t.tween_property(marble, "rotation", TAU * 1.5, 0.42)
		t.tween_property(marble, "modulate", Color(0.1, 0.1, 0.1, 0.0), 0.42)
		Audio.play(&"pit", -3.0)
		Audio.buzz(70)
		_shake()
	t.chain().tween_callback(func() -> void: marble.visible = false)

func _shake() -> void:
	var base: Vector2 = home
	var t: Tween = create_tween()
	for k: int in range(6):
		var amp: float = 9.0 * (1.0 - k / 6.0)
		t.tween_property(self, "position", base + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.035)
	t.tween_property(self, "position", base, 0.05)

# --- Hints --------------------------------------------------------------------------------------------

## A chevron just outside the tray, pointing the way to tilt, pulsing until the next move.
func show_hint(dir: int) -> void:
	_clear_hint()
	var arrow: HintArrow = HintArrow.new()
	arrow.size_px = cell * 0.55
	arrow.dir = dir
	var r: Rect2 = bounds()
	var d: Vector2 = Vector2(TiltBoard.DIRS[dir])
	arrow.position = r.get_center() + d * (Vector2(r.size.x, r.size.y) * 0.5 + Vector2(cell, cell) * 0.55)
	add_child(arrow)
	_hint = arrow

func _clear_hint() -> void:
	if is_instance_valid(_hint):
		_hint.queue_free()
	_hint = null
