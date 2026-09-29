class_name HintArrow
extends Node2D

## A chevron that bobs in the direction to tilt.

var dir: int = 0
var size_px: float = 40.0
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var d: Vector2 = Vector2(TiltBoard.DIRS[dir])
	var side: Vector2 = Vector2(-d.y, d.x)
	var bob: Vector2 = d * sin(_t * 7.0) * size_px * 0.18
	var alpha: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 7.0))
	var tip: Vector2 = bob + d * size_px * 0.45
	var points: PackedVector2Array = PackedVector2Array([
		tip,
		bob - d * size_px * 0.15 + side * size_px * 0.55,
		bob - d * size_px * 0.35 + side * size_px * 0.35,
		bob + d * size_px * 0.05,
		bob - d * size_px * 0.35 - side * size_px * 0.35,
		bob - d * size_px * 0.15 - side * size_px * 0.55,
	])
	draw_colored_polygon(points, Color(Palette.INK, alpha))
