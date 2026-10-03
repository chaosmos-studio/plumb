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
var _hint_dir: int = -1
## [route (_route), kind, colour] for each marble the hinted tilt would move.
var _hint_paths: Array[Array] = []
var _hint_t: float = 0.0
var _hint_nudge: Tween
## Cells a tilt being played changes partway through, drawn as they were until their step comes: the
## board already holds the outcome. Cell to [kind, value]: &"crack"; &"plug" with the plug's colour;
## &"fill", a pit a stone will fill; &"key" and &"lock" with their colour.
var _pending: Dictionary = {}
## Which hatches are drawn open: those held for the tilt being played, which the rules fix as it starts.
var _hatches: PackedByteArray = PackedByteArray()
## Which blinking walls are drawn up: those up for the tilt being played, or for the next one at rest.
var _up: PackedByteArray = PackedByteArray()

func _ready() -> void:
	set_process(false)

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
		marble.radius = cell * (0.38 if b.is_stone(i) else 0.36)
		marble.stone = b.is_stone(i)
		marble.colour = Palette.marble(b.marble_colour[i])
		add_child(marble)
		_marbles.append(marble)
	sync(b, false)
	queue_redraw()

## Marbles arrive one after another when a level opens, which shows how many there are before play.
func intro() -> void:
	for i: int in range(_marbles.size()):
		var marble: Marble = _marbles[i]
		if not marble.visible:
			continue
		marble.scale = Vector2.ZERO
		var t: Tween = create_tween()
		t.tween_interval(0.12 + i * 0.07)
		t.tween_property(marble, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Puts every marble where the board says, at once: after an undo or a restart.
func sync(b: TiltBoard, pop_in: bool = true) -> void:
	_clear_hint()
	_pending.clear()
	board = b
	_shown = b.marble_cell.duplicate()
	_hatches = b.held_open()
	_up = b.raised()
	for i: int in range(_marbles.size()):
		var marble: Marble = _marbles[i]
		marble.colour = Palette.marble(b.marble_colour[i])
		marble.number = b.marble_number[i]
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
	var pit_face: StyleBoxFlat = tile.duplicate()
	pit_face.bg_color = Palette.PIT
	var pit_depth: StyleBoxFlat = tile.duplicate()
	pit_depth.bg_color = Palette.PIT.darkened(0.6)
	pit_depth.set_corner_radius_all(int(cell * 0.1))
	var wall: StyleBoxFlat = tile.duplicate()
	wall.bg_color = Palette.WALL
	wall.border_color = Palette.WALL_LIP
	wall.border_width_bottom = int(cell * 0.1)
	for i: int in range(board.width * board.height):
		var at: Vector2i = board.coords(i)
		var rect: Rect2 = Rect2(_origin + Vector2(at) * cell + Vector2(gap, gap), Vector2(cell, cell) - Vector2(gap, gap) * 2.0)
		var c: Vector2 = rect.get_center()
		var pending: Array = _pending.get(i, [])
		if not pending.is_empty():
			match pending[0]:
				&"crack":
					draw_style_box(tile, rect)
					_draw_crack(c)
					continue
				&"fill":
					draw_style_box(pit_face, rect)
					draw_style_box(pit_depth, rect.grow_individual(-cell * 0.1, -cell * 0.16, -cell * 0.1, -cell * 0.06))
					continue
				&"key", &"lock":
					draw_style_box(tile, rect)
					_draw_tile_as(TiltBoard.Tile.KEY if pending[0] == &"key" else TiltBoard.Tile.LOCK, int(pending[1]), rect, c)
					continue
				&"glass":
					draw_style_box(tile, rect)
					_draw_tile_as(TiltBoard.Tile.GLASS, 0, rect, c)
					continue
		match board.cells[i]:
			TiltBoard.Cell.WALL:
				draw_style_box(wall, rect)
			TiltBoard.Cell.PIT:
				# A square void where the tile should be. Holes are round and pits are square, so the two
				# never read alike, whatever colours a player can tell apart.
				draw_style_box(pit_face, rect)
				draw_style_box(pit_depth, rect.grow_individual(-cell * 0.1, -cell * 0.16, -cell * 0.1, -cell * 0.06))
			_:
				draw_style_box(tile, rect)
				_draw_tile_as(board.tiles[i], board.tile_value[i], rect, c)
				var hole: int = board.holes[i]
				var plug: bool = board.plugs[i] == 1
				if not pending.is_empty() and pending[0] == &"plug":
					hole = int(pending[1])
					plug = true
				if hole != TiltBoard.NO_HOLE:
					var ring: Color = Palette.marble(hole)
					draw_circle(c, cell * 0.41, ring, true, -1.0, true)
					draw_circle(c, cell * 0.33, Palette.HOLE, true, -1.0, true)
					draw_circle(c + Vector2(0, cell * 0.06), cell * 0.25, Palette.HOLE.darkened(0.45), true, -1.0, true)
					if plug:
						# A plug's dashed outer ring: it is good for one marble.
						for k: int in range(8):
							var a: float = TAU * k / 8.0
							draw_arc(c, cell * 0.47, a, a + TAU / 16.0, 6, Color(Palette.WALL, 0.75), cell * 0.045, true)
					if board.ice[i] == 1:
						# Frost: a pale skin over the hole and a six-armed star, so a marble can roll across.
						draw_circle(c, cell * 0.33, Color(0.86, 0.95, 1.0, 0.42), true, -1.0, true)
						for k: int in range(3):
							var d: Vector2 = Vector2.from_angle(PI * k / 3.0) * cell * 0.2
							draw_line(c - d, c + d, Color(1, 1, 1, 0.9), maxf(2.0, cell * 0.035), true)
	_draw_edges()
	_draw_hint()

## The tray's edges where the rules change them: wrapping edges get a ring at the end of every row or
## column they join, and the locked side carries a bar and a padlock.
func _draw_edges() -> void:
	var r: Rect2 = Rect2(_origin, Vector2(board.width, board.height) * cell)
	var ink: Color = Color(Palette.WALL, 0.55)
	var w: float = maxf(3.0, cell * 0.06)
	if board.wrap & TiltBoard.WRAP_X:
		for y: int in range(board.height):
			var mid: float = r.position.y + (y + 0.5) * cell
			for x: float in [r.position.x - cell * 0.16, r.end.x + cell * 0.16]:
				draw_arc(Vector2(x, mid), cell * 0.12, 0.0, TAU, 20, ink, w * 0.7, true)
	if board.wrap & TiltBoard.WRAP_Y:
		for x: int in range(board.width):
			var mid: float = r.position.x + (x + 0.5) * cell
			for y: float in [r.position.y - cell * 0.16, r.end.y + cell * 0.16]:
				draw_arc(Vector2(mid, y), cell * 0.12, 0.0, TAU, 20, ink, w * 0.7, true)
	if board.locked >= 0:
		var d: Vector2 = Vector2(TiltBoard.DIRS[board.locked])
		var side: Vector2 = d.orthogonal().abs()
		var mid: Vector2 = r.get_center() + d * ((r.size * 0.5).dot(d.abs()) + cell * 0.16)
		var half: float = (r.size * 0.5).dot(side) - cell * 0.3
		draw_line(mid - side * half, mid + side * half, Color(Palette.DANGER, 0.8), w, true)
		draw_circle(mid, cell * 0.24, Palette.TRAY, true, -1.0, true)
		Icons.draw(self, &"lock", mid, cell * 0.36, Palette.DANGER)

## A tile drawn on a floor cell. Each reads by shape before colour: a mat, chevrons, a coloured frame, a
## splash, cracks, a whirl, a slanted bar, a round plate, a barred hatch, a key, a padlock, a wall up or
## sunk, a belt, a coil, a horseshoe, a pane. Portals, switches and hatches carry one dot or two, so the
## pairs read without colours of their own.
func _draw_tile_as(tile: int, value: int, rect: Rect2, c: Vector2) -> void:
	match tile:
		TiltBoard.Tile.STOP:
			var pad: StyleBoxFlat = StyleBoxFlat.new()
			pad.bg_color = Color(Palette.WALL, 0.2)
			pad.border_color = Color(Palette.WALL, 0.6)
			pad.set_border_width_all(int(maxf(2.0, cell * 0.05)))
			pad.set_corner_radius_all(int(cell * 0.14))
			pad.anti_aliasing = true
			draw_style_box(pad, rect.grow(-cell * 0.12))
			draw_circle(c, cell * 0.1, Color(Palette.WALL, 0.6), false, maxf(2.0, cell * 0.045), true)
		TiltBoard.Tile.GATE:
			var d: Vector2 = Vector2(TiltBoard.DIRS[value])
			var side: Vector2 = d.orthogonal()
			var ink: Color = Color(Palette.WALL, 0.7)
			var w: float = cell * 0.07
			for along: float in [-0.12, 0.1]:
				var tip: Vector2 = c + d * cell * (along + 0.08)
				var arm_a: Vector2 = tip - (d * 0.15 + side * 0.17) * cell
				var arm_b: Vector2 = tip - (d * 0.15 - side * 0.17) * cell
				draw_polyline(PackedVector2Array([arm_a, tip, arm_b]), ink, w, true)
				for p: Vector2 in [arm_a, tip, arm_b]:
					draw_circle(p, w * 0.5, ink, true, -1.0, true)
		TiltBoard.Tile.DOOR:
			var colour: Color = Palette.marble(value)
			var frame: StyleBoxFlat = StyleBoxFlat.new()
			frame.bg_color = Color(colour, 0.16)
			frame.border_color = colour
			frame.set_border_width_all(int(maxf(3.0, cell * 0.08)))
			frame.set_corner_radius_all(int(cell * 0.14))
			frame.anti_aliasing = true
			draw_style_box(frame, rect.grow(-cell * 0.05))
		TiltBoard.Tile.PAINT:
			var colour: Color = Palette.marble(value)
			draw_circle(c, cell * 0.2, colour, true, -1.0, true)
			draw_circle(c + Vector2(0.21, -0.17) * cell, cell * 0.07, colour, true, -1.0, true)
			draw_circle(c + Vector2(-0.22, 0.12) * cell, cell * 0.055, colour, true, -1.0, true)
			draw_circle(c + Vector2(0.14, 0.22) * cell, cell * 0.045, colour, true, -1.0, true)
		TiltBoard.Tile.CRACK:
			_draw_crack(c)
		TiltBoard.Tile.PORTAL:
			var ink: Color = Color(Palette.WALL, 0.75)
			draw_circle(c, cell * 0.36, Color(Palette.WALL, 0.12), true, -1.0, true)
			for k: int in range(3):
				var a: float = TAU * k / 3.0
				draw_arc(c, cell * 0.3, a, a + TAU / 4.0, 10, ink, cell * 0.06, true)
				draw_arc(c, cell * 0.18, a + 0.6, a + 0.6 + TAU / 5.0, 8, ink, cell * 0.05, true)
			_draw_pair(value, c, ink)
		TiltBoard.Tile.BUMPER:
			var ink: Color = Palette.WALL
			var reach: float = cell * 0.32
			var a: Vector2 = c + (Vector2(-reach, reach) if value == TiltBoard.SLASH else Vector2(-reach, -reach))
			var b: Vector2 = c + (Vector2(reach, -reach) if value == TiltBoard.SLASH else Vector2(reach, reach))
			draw_line(a, b, Palette.WALL_LIP, cell * 0.16, true)
			draw_line(a, b, ink, cell * 0.11, true)
			for p: Vector2 in [a, b]:
				draw_circle(p, cell * 0.08, Palette.WALL_LIP, true, -1.0, true)
		TiltBoard.Tile.SWITCH:
			var ink: Color = Color(Palette.WALL, 0.7)
			draw_circle(c, cell * 0.33, Color(Palette.WALL, 0.14), true, -1.0, true)
			draw_arc(c, cell * 0.33, 0.0, TAU, 36, ink, cell * 0.05, true)
			draw_arc(c, cell * 0.22, 0.0, TAU, 28, Color(ink, 0.5), cell * 0.03, true)
			_draw_pair(value, c, ink)
		TiltBoard.Tile.HATCH:
			var open: bool = value < _hatches.size() and _hatches[value] == 1
			var ink: Color = Palette.WALL
			if open:
				var frame: StyleBoxFlat = StyleBoxFlat.new()
				frame.bg_color = Color(0, 0, 0, 0)
				frame.border_color = Color(ink, 0.45)
				frame.set_border_width_all(int(maxf(2.0, cell * 0.04)))
				frame.set_corner_radius_all(int(cell * 0.12))
				frame.anti_aliasing = true
				draw_style_box(frame, rect.grow(-cell * 0.06))
			else:
				var plate: StyleBoxFlat = StyleBoxFlat.new()
				plate.bg_color = Color(ink, 0.85)
				plate.set_corner_radius_all(int(cell * 0.12))
				plate.anti_aliasing = true
				draw_style_box(plate, rect.grow(-cell * 0.06))
				for k: int in range(3):
					var x: float = (k - 1) * cell * 0.22
					draw_line(c + Vector2(x, -cell * 0.3), c + Vector2(x, cell * 0.3), Palette.WALL_LIP, cell * 0.07, true)
			_draw_pair(value, c + Vector2(0, cell * 0.26), Palette.TILE if not open else Color(ink, 0.6))
		TiltBoard.Tile.KEY:
			var colour: Color = Palette.marble(value)
			draw_circle(c + Vector2(-cell * 0.13, 0), cell * 0.15, colour, false, cell * 0.07, true)
			draw_line(c + Vector2(cell * 0.02, 0), c + Vector2(cell * 0.32, 0), colour, cell * 0.08, true)
			draw_line(c + Vector2(cell * 0.24, 0), c + Vector2(cell * 0.24, cell * 0.12), colour, cell * 0.07, true)
			draw_line(c + Vector2(cell * 0.14, 0), c + Vector2(cell * 0.14, cell * 0.09), colour, cell * 0.07, true)
		TiltBoard.Tile.LOCK:
			var colour: Color = Palette.marble(value)
			var block: StyleBoxFlat = StyleBoxFlat.new()
			block.bg_color = colour.lerp(Palette.WALL, 0.45)
			block.border_color = colour
			block.set_border_width_all(int(maxf(3.0, cell * 0.07)))
			block.set_corner_radius_all(int(cell * 0.14))
			block.anti_aliasing = true
			draw_style_box(block, rect.grow(-cell * 0.04))
			draw_arc(c + Vector2(0, -cell * 0.06), cell * 0.12, PI, TAU, 12, Palette.TILE, cell * 0.06, true)
			draw_rect(Rect2(c + Vector2(-cell * 0.16, -cell * 0.06), Vector2(cell * 0.32, cell * 0.24)), Palette.TILE, true)
			draw_circle(c + Vector2(0, cell * 0.05), cell * 0.04, block.bg_color, true, -1.0, true)
		TiltBoard.Tile.BLINK:
			# Up, a wall with a lit seam; down, the same wall's outline sunk into the floor, dashed.
			var i: int = _cell_at(c)
			if i < _up.size() and _up[i] == 1:
				var raised: StyleBoxFlat = StyleBoxFlat.new()
				raised.bg_color = Palette.WALL
				raised.border_color = Palette.WALL_LIP
				raised.border_width_bottom = int(cell * 0.1)
				raised.set_corner_radius_all(int(cell * 0.16))
				raised.anti_aliasing = true
				draw_style_box(raised, rect)
				draw_line(c + Vector2(-cell * 0.26, -cell * 0.04), c + Vector2(cell * 0.26, -cell * 0.04), Palette.TILE, cell * 0.06, true)
			else:
				var sunk: Rect2 = rect.grow(-cell * 0.1)
				var ink: Color = Color(Palette.WALL, 0.55)
				var corners: PackedVector2Array = PackedVector2Array([sunk.position, Vector2(sunk.end.x, sunk.position.y), sunk.end,
					Vector2(sunk.position.x, sunk.end.y)])
				for k: int in range(4):
					var a: Vector2 = corners[k]
					var b: Vector2 = corners[(k + 1) % 4]
					for s: int in range(3):
						draw_line(a.lerp(b, s / 3.0 + 0.04), a.lerp(b, s / 3.0 + 0.22), ink, maxf(2.0, cell * 0.045), true)
				draw_line(c + Vector2(-cell * 0.2, 0), c + Vector2(cell * 0.2, 0), Color(ink, 0.4), cell * 0.05, true)
		TiltBoard.Tile.CONVEYOR:
			# A belt between two rails with three solid chevrons, bolder than a gate's open ones.
			var d: Vector2 = Vector2(TiltBoard.DIRS[value])
			var side: Vector2 = d.orthogonal()
			var belt: StyleBoxFlat = StyleBoxFlat.new()
			belt.bg_color = Color(Palette.WALL, 0.22)
			belt.set_corner_radius_all(int(cell * 0.12))
			belt.anti_aliasing = true
			draw_style_box(belt, rect.grow(-cell * 0.07))
			for s: float in [-1.0, 1.0]:
				draw_line(c + side * s * cell * 0.36 - d * cell * 0.36, c + side * s * cell * 0.36 + d * cell * 0.36,
					Color(Palette.WALL, 0.6), cell * 0.05, true)
			for along: float in [-0.2, 0.0, 0.2]:
				var tip: Vector2 = c + d * cell * (along + 0.09)
				draw_colored_polygon(PackedVector2Array([tip, tip - (d * 0.14 + side * 0.16) * cell,
					tip - d * 0.07 * cell, tip - (d * 0.14 - side * 0.16) * cell]), Color(Palette.WALL, 0.8))
		TiltBoard.Tile.SPRING:
			# A coil seen from the side under a round plate.
			var ink: Color = Palette.WALL
			var coil: PackedVector2Array = PackedVector2Array()
			for k: int in range(9):
				coil.append(c + Vector2((-1.0 if k % 2 == 0 else 1.0) * cell * 0.2, cell * (0.3 - k * 0.06)))
			draw_polyline(coil, ink, maxf(2.0, cell * 0.06), true)
			draw_line(c + Vector2(-cell * 0.28, -cell * 0.22), c + Vector2(cell * 0.28, -cell * 0.22), Palette.WALL_LIP, cell * 0.1, true)
			draw_line(c + Vector2(-cell * 0.24, cell * 0.33), c + Vector2(cell * 0.24, cell * 0.33), Color(ink, 0.6), cell * 0.06, true)
		TiltBoard.Tile.MAGNET:
			# A horseshoe magnet, its poles pale, standing on a dark plate: nothing rolls onto it.
			var plate: StyleBoxFlat = StyleBoxFlat.new()
			plate.bg_color = Palette.WALL_LIP
			plate.set_corner_radius_all(int(cell * 0.16))
			plate.anti_aliasing = true
			draw_style_box(plate, rect)
			var red: Color = Palette.DANGER
			draw_arc(c + Vector2(0, cell * 0.04), cell * 0.2, 0.0, PI, 16, red, cell * 0.14, true)
			for s: float in [-1.0, 1.0]:
				draw_line(c + Vector2(s * cell * 0.2, cell * 0.05), c + Vector2(s * cell * 0.2, -cell * 0.16), red, cell * 0.14, true)
				draw_line(c + Vector2(s * cell * 0.2, -cell * 0.16), c + Vector2(s * cell * 0.2, -cell * 0.3), Palette.TILE, cell * 0.14, true)
		TiltBoard.Tile.GLASS:
			# A clear block: a pale fill, a bright rim and two diagonal glints.
			var pane: StyleBoxFlat = StyleBoxFlat.new()
			pane.bg_color = Color(0.82, 0.93, 1.0, 0.55)
			pane.border_color = Color(1, 1, 1, 0.95)
			pane.set_border_width_all(int(maxf(2.0, cell * 0.05)))
			pane.set_corner_radius_all(int(cell * 0.14))
			pane.shadow_color = Color(Palette.WALL, 0.35)
			pane.shadow_size = int(cell * 0.05)
			pane.anti_aliasing = true
			draw_style_box(pane, rect.grow(-cell * 0.05))
			draw_line(c + Vector2(-cell * 0.24, cell * 0.04), c + Vector2(cell * 0.04, -cell * 0.24), Color(1, 1, 1, 0.95), cell * 0.06, true)
			draw_line(c + Vector2(-cell * 0.06, cell * 0.22), c + Vector2(cell * 0.2, -cell * 0.04), Color(1, 1, 1, 0.7), cell * 0.04, true)

## The cell whose centre is `c`.
func _cell_at(c: Vector2) -> int:
	var at: Vector2 = ((c - _origin) / cell).floor()
	return board.index(Vector2i(at))

## One dot or two, for the first or second portal, switch or hatch pair on a board.
func _draw_pair(pair: int, at: Vector2, ink: Color) -> void:
	if pair == 0:
		draw_circle(at, cell * 0.05, ink, true, -1.0, true)
	else:
		for side: float in [-1.0, 1.0]:
			draw_circle(at + Vector2(side * cell * 0.06, 0), cell * 0.045, ink, true, -1.0, true)

func _draw_crack(c: Vector2) -> void:
	var ink: Color = Color(Palette.HOLE, 0.65)
	var w: float = maxf(2.0, cell * 0.045)
	var main: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in [Vector2(-0.3, -0.24), Vector2(-0.08, -0.05), Vector2(-0.16, 0.12), Vector2(0.06, 0.3)]:
		main.append(c + p * cell)
	draw_polyline(main, ink, w, true)
	var branch: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in [Vector2(-0.08, -0.05), Vector2(0.17, -0.11), Vector2(0.3, 0.05)]:
		branch.append(c + p * cell)
	draw_polyline(branch, ink, w, true)

# --- Animation ----------------------------------------------------------------------------------------

## Plays one tilt. Returns when every marble has come to rest.
func play(move: TiltMove) -> void:
	busy = true
	_clear_hint()
	for event: Dictionary in move.events:
		match event["kind"]:
			&"crack":
				_pending[int(event["cell"])] = [&"crack", 0]
			&"plug":
				_pending[int(event["cell"])] = [&"plug", board.marble_colour[int(event["marble"])]]
			&"fill":
				_pending[int(event["cell"])] = [&"fill", 0]
			&"key":
				_pending[int(event["cell"])] = [&"key", int(event["colour"])]
				for lock: int in event["opened"]:
					_pending[lock] = [&"lock", int(event["colour"])]
			&"shatter":
				_pending[int(event["cell"])] = [&"glass", 0]
	if not _pending.is_empty():
		queue_redraw()
	_tip(move.dir)
	if move.length() > 0:
		Audio.play(&"roll", -9.0, randf_range(0.95, 1.05))
	for step: int in range(move.steps.size() + 1):
		if step < move.steps.size():
			await _roll(move, step)
		for event: Dictionary in move.events:
			if int(event["step"]) != step:
				continue
			match event["kind"]:
				&"shatter":
					_pending.erase(int(event["cell"]))
					queue_redraw()
					var burst: Ripple = Ripple.new()
					burst.colour = Color(0.82, 0.93, 1.0)
					burst.start_radius = cell * 0.2
					burst.end_radius = cell * 0.7
					burst.position = centre(int(event["cell"]))
					add_child(burst)
					Audio.play(&"clack", -4.0, 2.2)
					Audio.buzz(18)
				&"jump":
					Audio.play(&"tap", -8.0, 0.8)
				&"sink", &"pit", &"fill":
					_drop(int(event["marble"]), event["kind"])
					if event["kind"] == &"fill":
						_pending.erase(int(event["cell"]))
						queue_redraw()
				&"paint":
					_repaint(int(event["marble"]), int(event["colour"]))
				&"bounce":
					_bump([int(event["marble"])] as Array[int], Vector2i(1, 1))
					Audio.play(&"clack", -12.0, 1.4)
				&"portal":
					Audio.play(&"tap", -8.0, 1.6)
				&"key":
					_pending.erase(int(event["cell"]))
					for lock: int in event["opened"]:
						_pending.erase(lock)
					queue_redraw()
					Audio.play(&"clack", -6.0, 1.8)
				&"crack", &"plug":
					_pending.erase(int(event["cell"]))
					queue_redraw()
					if event["kind"] == &"crack":
						Audio.play(&"pit", -14.0, 1.35)
	if not move.stopped.is_empty():
		_bump(move.stopped, TiltBoard.DIRS[move.dir])
		Audio.play(&"clack", -4.0, randf_range(0.94, 1.06))
		Audio.buzz(8)
	_hatches = board.held_open()
	_up = board.raised()
	queue_redraw()
	busy = false

## One step of a tilt: every marble that moved goes one cell, through a portal to its twin, over a square
## off a spring, or out of a wrapping edge and in at the far one.
func _roll(move: TiltMove, step: int) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	var through: Dictionary = {}
	for event: Dictionary in move.events:
		if int(event["step"]) == step and event["kind"] in [&"portal", &"jump", &"wrap"]:
			through[int(event["marble"])] = event
	for k: int in range(move.steps[step].size()):
		var id: int = int(move.steps[step][k])
		var marble: Marble = _marbles[id]
		var from: Vector2 = centre(_shown[id])
		_shown[id] = move.cells[step][k]
		var to: Vector2 = centre(_shown[id])
		var event: Dictionary = through.get(id, {})
		match event.get("kind", &""):
			&"portal":
				# Into the portal, then out of its twin at once.
				tween.tween_property(marble, "position", centre(int(event["cell"])), STEP_TIME)
				tween.chain().tween_callback(func() -> void:
					marble.position = to
					marble.scale = Vector2(0.6, 0.6))
				tween.parallel().tween_property(marble, "scale", Vector2.ONE, STEP_TIME * 2.0).set_delay(STEP_TIME)
			&"jump":
				# Up and over: the marble swells at the top of the arc.
				tween.tween_property(marble, "position", to, STEP_TIME * 2.0)
				tween.tween_property(marble, "scale", Vector2(1.35, 1.35), STEP_TIME).set_ease(Tween.EASE_OUT)
				tween.chain().tween_property(marble, "scale", Vector2.ONE, STEP_TIME).set_ease(Tween.EASE_IN)
			&"wrap":
				# Out over the edge, then in from the far side.
				var d: Vector2 = Vector2(TiltBoard.DIRS[_heading(from, to)])
				tween.tween_property(marble, "position", from + d * cell * 0.6, STEP_TIME * 0.5)
				tween.chain().tween_callback(func() -> void: marble.position = to - d * cell * 0.6)
				tween.chain().tween_property(marble, "position", to, STEP_TIME * 0.5)
			_:
				tween.tween_property(marble, "position", to, STEP_TIME)
	await tween.finished

## The direction a wrapping step went: the opposite of the long way across the board.
static func _heading(from: Vector2, to: Vector2) -> int:
	var d: Vector2 = from - to
	if absf(d.x) > absf(d.y):
		return TiltBoard.RIGHT if d.x > 0.0 else TiltBoard.LEFT
	return TiltBoard.DOWN if d.y > 0.0 else TiltBoard.UP

## A swipe that moves nothing still answers: the tray twitches and settles.
func refuse(dir: int) -> void:
	var d: Vector2 = Vector2(TiltBoard.DIRS[dir])
	var t: Tween = create_tween()
	t.tween_property(self, "position", home + d * 5.0, 0.05)
	t.tween_property(self, "position", home, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _tip(dir: int, amount: float = 1.0) -> void:
	var t: Tween = create_tween().set_parallel(true)
	var base: Vector2 = home
	match dir:
		TiltBoard.LEFT, TiltBoard.RIGHT:
			var angle: float = deg_to_rad(TIP_DEGREES) * amount * (-1.0 if dir == TiltBoard.LEFT else 1.0)
			t.tween_property(self, "rotation", angle, 0.08)
			t.chain().tween_property(self, "rotation", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_:
			var shift: float = TIP_SHIFT * amount * (-1.0 if dir == TiltBoard.UP else 1.0)
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
	if kind == &"fill":
		# A stone settles into the pit and becomes the floor: no shake, nothing lost.
		t.tween_property(marble, "scale", Vector2(0.8, 0.8), 0.2).set_ease(Tween.EASE_IN)
		t.tween_property(marble, "modulate", Color(1, 1, 1, 0.0), 0.2).set_delay(0.06)
		Audio.play(&"pit", -10.0, 0.7)
		Audio.buzz(20)
	elif kind == &"sink":
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

## A marble rolling over paint takes the new colour with a ring of it.
func _repaint(id: int, colour: int) -> void:
	var marble: Marble = _marbles[id]
	marble.colour = Palette.marble(colour)
	var ring: Ripple = Ripple.new()
	ring.colour = marble.colour
	ring.start_radius = cell * 0.2
	ring.end_radius = cell * 0.55
	ring.position = marble.position
	add_child(ring)

func _shake() -> void:
	var base: Vector2 = home
	var t: Tween = create_tween()
	for k: int in range(6):
		var amp: float = 9.0 * (1.0 - k / 6.0)
		t.tween_property(self, "position", base + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.035)
	t.tween_property(self, "position", base, 0.05)

# --- Hints --------------------------------------------------------------------------------------------

## Previews the solver's next tilt on the board itself: a dotted trail from every marble that would move
## to where it would stop, a ghost of it there, a glowing ring on any hole it would drop into, and the
## tray leaning that way now and then. Drawn inside the tray, so it is on screen at every aspect ratio.
func show_hint(dir: int, from: TiltBoard) -> void:
	_clear_hint()
	var probe: TiltBoard = from.copy()
	var move: TiltMove = probe.tilt(dir)
	for m: int in range(from.marble_cell.size()):
		var start_cell: int = from.marble_cell[m]
		if start_cell == TiltBoard.GONE or not move.moved(m):
			continue
		var kind: StringName = &"roll"
		var jumps: Dictionary = {}
		for event: Dictionary in move.events:
			if int(event["marble"]) != m:
				continue
			if event["kind"] == &"sink" or event["kind"] == &"pit":
				kind = event["kind"]
			elif event["kind"] == &"portal" or event["kind"] == &"wrap":
				jumps[int(event["step"])] = int(event["cell"])
		_hint_paths.append([_route(move, m, start_cell, jumps), kind, from.marble_colour[m]])
	_hint_dir = dir
	_hint_t = 0.0
	set_process(true)
	_hint_nudge = create_tween().set_loops()
	_hint_nudge.tween_interval(0.5)
	_hint_nudge.tween_callback(func() -> void: _tip(dir, 0.55))
	_hint_nudge.tween_interval(0.9)
	queue_redraw()

## The cells marble `m` passes through on `move`, from `start`, so a trail can turn where a bumper turns it.
## A portal's cell comes before its twin, with -1 between, where the trail breaks for the jump.
static func _route(move: TiltMove, m: int, start: int, jumps: Dictionary) -> PackedInt32Array:
	var route: PackedInt32Array = PackedInt32Array([start])
	for step: int in range(move.steps.size()):
		var k: int = move.steps[step].find(m)
		if k < 0:
			continue
		if jumps.has(step):
			route.append(int(jumps[step]))
			route.append(-1)
		route.append(move.cells[step][k])
	return route

func _clear_hint() -> void:
	if _hint_nudge != null and _hint_nudge.is_valid():
		_hint_nudge.kill()
	_hint_nudge = null
	_hint_dir = -1
	_hint_paths.clear()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	_hint_t += delta
	queue_redraw()

func _draw_hint() -> void:
	if _hint_dir < 0:
		return
	var pulse: float = 0.5 + 0.5 * sin(_hint_t * 5.0)
	for path: Array in _hint_paths:
		var route: PackedInt32Array = path[0]
		var colour: Color = Palette.marble(int(path[2]))
		var b: Vector2 = centre(route[route.size() - 1])
		var step: float = cell * 0.22
		for s: int in range(route.size() - 1):
			if route[s] < 0 or route[s + 1] < 0:
				continue
			var from: Vector2 = centre(route[s])
			var to: Vector2 = centre(route[s + 1])
			var n: int = maxi(int(from.distance_to(to) / step), 1)
			for k: int in range(1 if s == 0 else 0, n):
				var t: float = float(k) / float(n)
				# Dots travel along the trail, so the direction reads even in a still frame.
				var phase: float = fmod(float(s) * 0.25 + t * 0.25 - _hint_t * 0.8, 1.0)
				var alpha: float = 0.35 + 0.6 * (1.0 - absf(phase * 2.0 - 1.0))
				draw_circle(from.lerp(to, t), cell * 0.058, Color(colour, alpha), true, -1.0, true)
		match path[1]:
			&"sink":
				# Outside the hole's own ring, which sits at 0.41 and would hide a hint drawn on it.
				draw_arc(b, cell * (0.52 + 0.05 * pulse), 0.0, TAU, 40, Color(colour, 0.9), cell * 0.06, true)
			&"pit":
				draw_arc(b, cell * (0.4 + 0.06 * pulse), 0.0, TAU, 40, Color(Palette.DANGER, 0.9), cell * 0.06, true)
			_:
				draw_circle(b, cell * 0.36, Color(colour, 0.24 + 0.12 * pulse), true, -1.0, true)
				draw_arc(b, cell * 0.36, 0.0, TAU, 40, Color(colour, 0.9), cell * 0.05, true)
