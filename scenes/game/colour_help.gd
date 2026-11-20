class_name ColourHelp
extends RefCounted

## Colour help (Settings, Accessibility): each marble colour has its own shape, drawn on its marbles and in its holes,
## so a board reads without telling colours apart. Red a triangle, teal a square, yellow a star, purple a diamond, as
## the Settings concept shows them; any further colour a circle.

const INK: Color = Color("fff6e3")

## Whether it is on: Save keeps it, and sets it here as it loads and changes, so the board's scripts need no autoload.
static var on: bool = false

## Draws colour `colour`'s shape centred at `c`, `size` across, on `ci`.
static func draw(ci: CanvasItem, colour: int, c: Vector2, size: float, ink: Color = INK) -> void:
	var r: float = size * 0.5
	match colour:
		0:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r * 0.95, r * 0.72),
				c + Vector2(-r * 0.95, r * 0.72)]), ink)
		1:
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.78, Vector2(r, r) * 1.56), ink)
		2:
			var points: PackedVector2Array = PackedVector2Array()
			for i: int in range(10):
				var a: float = -PI * 0.5 + i * PI / 5.0
				var rr: float = r * (1.05 if i % 2 == 0 else 0.46)
				points.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(points, ink)
		3:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r * 0.75, 0.0),
				c + Vector2(0.0, r), c + Vector2(-r * 0.75, 0.0)]), ink)
		_:
			ci.draw_circle(c, r * 0.8, ink, true, -1.0, true)
