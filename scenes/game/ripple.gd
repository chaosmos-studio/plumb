class_name Ripple
extends Node2D

const LIFE: float = 0.45

var colour: Color = Color.WHITE
var start_radius: float = 20.0
var end_radius: float = 60.0
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta / LIFE
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k: float = ease(_t, 0.4)
	var r: float = lerpf(start_radius, end_radius, k)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(colour, 1.0 - _t), lerpf(8.0, 1.5, _t), true)
