class_name Wipe
extends Control

## A transition: a disc of the accent colour grows from a point until it covers the frame, then shrinks
## away from the far side. The beat change happens while it is covered, so no cut is ever seen.

const COVER: float = 0.34
const REVEAL: float = 0.3

var colour: Color = Brand.ACCENT
var origin: Vector2 = Vector2.ZERO
var radius: float = 0.0
var hole: float = 0.0

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func cover(from: Vector2) -> void:
	origin = from
	hole = 0.0
	var far: float = _far(from)
	var t: Tween = create_tween()
	t.tween_method(func(r: float) -> void:
		radius = r
		queue_redraw(), 0.0, far, COVER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished

func reveal() -> void:
	var far: float = _far(origin)
	var t: Tween = create_tween()
	t.tween_method(func(r: float) -> void:
		hole = r
		queue_redraw(), 0.0, far, REVEAL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished
	radius = 0.0
	hole = 0.0
	queue_redraw()

func _far(from: Vector2) -> float:
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]
	var far: float = 0.0
	for c: Vector2 in corners:
		far = maxf(far, from.distance_to(c))
	return far + 8.0

func _draw() -> void:
	if radius <= 0.0:
		return
	if hole <= 0.0:
		draw_circle(origin, radius, colour, true, -1.0, true)
		return
	# Reveal: a ring whose inner edge grows out from the same point, uncovering the next beat.
	var width: float = radius - hole
	if width > 0.0:
		draw_arc(origin, hole + width * 0.5, 0.0, TAU, 96, colour, width, true)
