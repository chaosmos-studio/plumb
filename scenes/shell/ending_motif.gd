extends Control

## The ending's motif (Finale.MOTIF): one last tilt, and the four marbles roll down into their holes one
## after another, each sounding its own sink, until the bottom row glows full.

const COLS: int = 4
const ROWS: int = 4
## The row each column's marble starts on: different heights, so they land one by one.
const STARTS: Array[int] = [1, 0, 2, 0]
const TILT_TIME: float = 0.35
## Seconds for a marble to fall the board's full height, speeding up as a roll downhill does.
const FALL: float = 1.1
const TILT_DEG: float = 3.5
const SINK_TIME: float = 0.2

var _t: float = -1.0
var _sunk: Array[float] = [-1.0, -1.0, -1.0, -1.0]

func play() -> void:
	_t = 0.0

func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	for i: int in range(COLS):
		if _sunk[i] < 0.0 and _t >= _arrive(i):
			_sunk[i] = _t
			Audio.sink(i)
	queue_redraw()

func _arrive(i: int) -> float:
	return TILT_TIME + FALL * sqrt(float(ROWS - 1 - STARTS[i]) / float(ROWS - 1))

func _row(i: int) -> float:
	if _t <= TILT_TIME:
		return float(STARTS[i])
	var k: float = (_t - TILT_TIME) / FALL
	return minf(float(STARTS[i]) + float(ROWS - 1) * k * k, float(ROWS - 1))

func _draw() -> void:
	var last: float = _arrive(0)
	for i: int in range(COLS):
		last = maxf(last, _arrive(i))
	# The board tips forward for the roll and settles back once the last marble is home.
	var tip: float = 0.0
	if _t > 0.0:
		tip = minf(_t / TILT_TIME, 1.0) * clampf(1.0 - (_t - last - 0.2) / 0.4, 0.0, 1.0)
	var centre: Vector2 = size * 0.5
	draw_set_transform(centre, deg_to_rad(-TILT_DEG) * ease(tip, -2.0), Vector2.ONE)
	var cell: float = minf(size.x, size.y) * 0.8 / COLS
	var board: Vector2 = Vector2(COLS, ROWS) * cell
	var origin: Vector2 = -board * 0.5
	var tray: StyleBoxFlat = StyleBoxFlat.new()
	tray.bg_color = Palette.TRAY
	tray.set_corner_radius_all(int(cell * 0.32))
	tray.anti_aliasing = true
	draw_style_box(tray, Rect2(origin - Vector2(cell, cell) * 0.18, board + Vector2(cell, cell) * 0.36))
	for y: int in range(ROWS):
		for x: int in range(COLS):
			var tile: StyleBoxFlat = StyleBoxFlat.new()
			tile.bg_color = Palette.TILE
			tile.set_corner_radius_all(int(cell * 0.2))
			tile.anti_aliasing = true
			draw_style_box(tile, Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)).grow(-cell * 0.06))
	for i: int in range(COLS):
		var hole: Vector2 = origin + (Vector2(i, ROWS - 1) + Vector2(0.5, 0.5)) * cell
		var full: float = clampf((_t - _sunk[i]) / 0.35, 0.0, 1.0) if _sunk[i] >= 0.0 else 0.0
		draw_circle(hole, cell * 0.34, Palette.marble(i), true, -1.0, true)
		draw_circle(hole, cell * 0.26, Palette.HOLE.lerp(Palette.marble(i), full * 0.85), true, -1.0, true)
		if _sunk[i] >= 0.0:
			var ring: float = clampf((_t - _sunk[i]) / 0.6, 0.0, 1.0)
			draw_arc(hole, cell * (0.36 + 0.4 * ring), 0.0, TAU, 48, Color(Palette.marble(i), 0.5 * (1.0 - ring)),
				cell * 0.06, true)
	for i: int in range(COLS):
		var gone: float = clampf((_t - _sunk[i]) / SINK_TIME, 0.0, 1.0) if _sunk[i] >= 0.0 else 0.0
		if gone >= 1.0:
			continue
		var at: Vector2 = origin + (Vector2(float(i), _row(i)) + Vector2(0.5, 0.5)) * cell
		var r: float = cell * 0.3 * (1.0 - 0.55 * gone)
		draw_circle(at + Vector2(0, cell * 0.06), r, Color(0, 0, 0, 0.12 * (1.0 - gone)), true, -1.0, true)
		draw_circle(at, r, Color(Palette.marble(i), 1.0 - gone), true, -1.0, true)
		draw_circle(at + Vector2(-r * 0.3, -r * 0.34), r * 0.26, Color(1, 1, 1, 0.55 * (1.0 - gone)), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
