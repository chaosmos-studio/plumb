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

func _draw() -> void:
	var r: float = radius
	draw_circle(Vector2(r * 0.08, r * 0.22), r * 0.98, Color(0.2, 0.16, 0.1, 0.18), true, -1.0, true)
	draw_circle(Vector2.ZERO, r, colour.darkened(0.22), true, -1.0, true)
	draw_circle(Vector2(-r * 0.06, -r * 0.08), r * 0.88, colour, true, -1.0, true)
	draw_circle(Vector2(-r * 0.3, -r * 0.34), r * 0.3, Color(1, 1, 1, 0.5), true, -1.0, true)
	draw_circle(Vector2(-r * 0.36, -r * 0.4), r * 0.13, Color(1, 1, 1, 0.85), true, -1.0, true)
