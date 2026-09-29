class_name Marble
extends Node2D

## One marble, drawn as layered circles: a soft shadow, a darker rim, the body, and a gloss highlight.
## Squash and fades are done on the node's scale and modulate, so the drawing never changes.

var radius: float = 30.0:
	set(value):
		radius = value
		queue_redraw()
var colour: Color = Color.WHITE:
	set(value):
		colour = value
		queue_redraw()

## The tail is worked out from how far the marble moved since last frame, so anything that moves it
## (a roll, an undo, the title toy) gets one without asking.
const TAIL_PER_SPEED: float = 0.045
var _last: Vector2 = Vector2.ZERO
var _tail: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var step: Vector2 = position - _last
	_last = position
	# A jump of more than a couple of radii in one frame is a placement (first frame, undo), not a roll.
	var velocity: Vector2 = Vector2.ZERO if step.length() > radius * 2.5 else step / delta
	var target: Vector2 = -velocity * TAIL_PER_SPEED
	if target.length() > radius * 1.6:
		target = target.normalized() * radius * 1.6
	_tail = _tail.lerp(target, 0.5)
	if _tail.length() > 0.5 or target.length() > 0.5:
		queue_redraw()

func _draw() -> void:
	var r: float = radius
	if _tail.length() > 2.0:
		var side: Vector2 = _tail.orthogonal().normalized() * r * 0.8
		var tail: PackedVector2Array = PackedVector2Array([side, _tail, -side])
		draw_colored_polygon(tail, Color(colour, 0.28))
	draw_circle(Vector2(r * 0.08, r * 0.22), r * 0.98, Color(0.2, 0.16, 0.1, 0.18), true, -1.0, true)
	draw_circle(Vector2.ZERO, r, colour.darkened(0.22), true, -1.0, true)
	draw_circle(Vector2(-r * 0.06, -r * 0.08), r * 0.88, colour, true, -1.0, true)
	draw_circle(Vector2(-r * 0.3, -r * 0.34), r * 0.3, Color(1, 1, 1, 0.5), true, -1.0, true)
	draw_circle(Vector2(-r * 0.36, -r * 0.4), r * 0.13, Color(1, 1, 1, 0.85), true, -1.0, true)
