class_name Wipe
extends Control

## Transitions between beats. The beat change happens while the frame is covered, so no hard cut is
## ever seen. Each film picks one style and keeps it, so a video has one visual language:
##   circle  a disc of the accent grows from a corner, then a hole opens from the same point
##   bars    four slanted bars sweep across in a stagger and carry on out the far side
##   slide   a panel slides in from one edge and away past the other
##   iris    the frame closes to a point on the centre, then opens again
##   flash   a quick bright flash, with the next beat punching in (the film scales it)

const COVER: float = 0.34
const REVEAL: float = 0.3
const MODES: Array[String] = ["circle", "bars", "slide", "iris", "flash"]

var mode: String = "circle"
var colour: Color = Brand.ACCENT
var origin: Vector2 = Vector2.ZERO
var _in: float = 0.0
var _out: float = 0.0

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func cover(from: Vector2) -> void:
	origin = from
	_out = 0.0
	var time: float = 0.12 if mode == "flash" else COVER
	var t: Tween = create_tween()
	t.tween_method(_set_in, 0.0, 1.0, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished

func reveal() -> void:
	var time: float = 0.22 if mode == "flash" else REVEAL
	var t: Tween = create_tween()
	t.tween_method(_set_out, 0.0, 1.0, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished
	_in = 0.0
	_out = 0.0
	queue_redraw()

func _set_in(v: float) -> void:
	_in = v
	queue_redraw()

func _set_out(v: float) -> void:
	_out = v
	queue_redraw()

func _far(from: Vector2) -> float:
	var far: float = 0.0
	for c: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		far = maxf(far, from.distance_to(c))
	return far + 8.0

func _draw() -> void:
	if _in <= 0.0:
		return
	match mode:
		"bars":
			_draw_bars()
		"slide":
			var x0: float = lerpf(-size.x, 0.0, _in) + size.x * _out
			draw_rect(Rect2(x0, 0.0, size.x, size.y), colour)
			draw_rect(Rect2(x0 - size.x * 0.06, 0.0, size.x * 0.06, size.y), colour.lightened(0.25))
		"iris":
			var far: float = _far(size * 0.5)
			var hole: float = far * (1.0 - _in) if _out <= 0.0 else far * _out
			_draw_ring(size * 0.5, hole, far)
		"flash":
			var a: float = _in if _out <= 0.0 else 1.0 - _out
			draw_rect(Rect2(Vector2.ZERO, size), Color(colour.lerp(Color.WHITE, 0.6), a))
		_:
			var far2: float = _far(origin)
			if _out <= 0.0:
				draw_circle(origin, far2 * _in, colour, true, -1.0, true)
			else:
				_draw_ring(origin, far2 * _out, far2)

## Everything outside a circle of radius `hole` is covered.
func _draw_ring(at: Vector2, hole: float, far: float) -> void:
	var width: float = far - hole
	if width > 0.0:
		draw_arc(at, hole + width * 0.5, 0.0, TAU, 128, colour, width, true)

func _draw_bars() -> void:
	var count: int = 4
	var slant: float = size.y * 0.35
	var band: float = size.y / count
	for k: int in range(count):
		var delay: float = float(k) / count * 0.45
		var p_in: float = clampf((_in - delay) / (1.0 - delay * 0.9), 0.0, 1.0)
		var p_out: float = clampf((_out - delay) / (1.0 - delay * 0.9), 0.0, 1.0)
		var width: float = size.x + slant
		# Fully in, a bar spans the frame at both its slanted edges; fully out, it has left past the right.
		var left: float = lerpf(-width - slant, -slant, p_in) + (size.x + slant * 2.0) * p_out
		var y0: float = band * k
		var y1: float = y0 + band + 1.0
		var shade: Color = colour if k % 2 == 0 else colour.lightened(0.12)
		draw_colored_polygon(PackedVector2Array([
			Vector2(left + slant, y0), Vector2(left + width + slant, y0),
			Vector2(left + width, y1), Vector2(left, y1)]), shade)
