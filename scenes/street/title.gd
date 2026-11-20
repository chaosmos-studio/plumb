class_name StreetTitle
extends Node2D

## The PLUMB title art in the sky, as every concept opens (build/review/revamp2/1-map.png). Drawn about its middle so
## a tap wobbles it, and it bobs gently at rest.

## Its bob at rest: how far, in design pixels, and how fast.
const BOB: float = 5.0
const BOB_SPEED: float = 1.3

var _rest: Vector2 = Vector2.ZERO
var _k: float = 1.0
var _t: float = 0.0

## Puts it with its top at `top`, centred on a screen of `size`, at most `width` wide.
func place(size: Vector2, top: float, width: float) -> void:
	var w: float = minf(width, size.x * 0.84)
	_k = w / StreetArt.size("title_plumb").x
	_rest = Vector2(size.x * 0.5, top + StreetArt.size("title_plumb").y * _k * 0.5)
	position = _rest
	queue_redraw()

## Whether a screen point is on it.
func hit(at: Vector2) -> bool:
	var half: Vector2 = StreetArt.size("title_plumb") * _k * 0.5
	return Rect2(_rest - half, half * 2.0).has_point(at)

func _process(delta: float) -> void:
	if Save.reduce_motion:
		position = _rest
		return
	_t += delta
	position = _rest + Vector2(0.0, sin(_t * BOB_SPEED) * BOB)

func _draw() -> void:
	StreetArt.draw(self, "title_plumb", Vector2.ZERO, _k)
