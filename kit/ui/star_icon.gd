class_name StarIcon
extends Control

var filled: bool = false:
	set(value):
		filled = value
		queue_redraw()
var fill_colour: Color = Brand.GOLD
var empty_colour: Color = Color(Brand.MUTED, 0.45)

func _init(size_px: float = 36.0, on: bool = false) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	filled = on
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = Vector2(size_px, size_px) * 0.5

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var outer: float = minf(size.x, size.y) * 0.5
	var inner: float = outer * 0.45
	var points: PackedVector2Array = PackedVector2Array()
	for k: int in range(10):
		var r: float = outer if k % 2 == 0 else inner
		var a: float = -PI * 0.5 + k * PI / 5.0
		points.append(c + Vector2(cos(a), sin(a)) * r)
	var loop: PackedVector2Array = points.duplicate()
	loop.append(points[0])
	if filled:
		# A filled polygon has no anti-aliasing, so an antialiased line in the same colour traces its edge.
		draw_colored_polygon(points, fill_colour)
		draw_polyline(loop, fill_colour, 1.5, true)
	else:
		draw_polyline(loop, empty_colour, maxf(2.0, outer * 0.12), true)
