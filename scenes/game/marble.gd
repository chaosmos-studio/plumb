class_name Marble
extends Node2D

## One marble, drawn as layered circles: a soft shadow, a darker rim, the body, and a gloss highlight, or
## finished as the marble set in use asks (GameLooks.finish): glass, a cut gem, a ringed planet or a
## peppermint swirl. Squash and fades are done on the node's scale and modulate, so the drawing never
## changes.

var radius: float = 30.0:
	set(value):
		radius = value
		queue_redraw()
var colour: Color = Color.WHITE:
	set(value):
		colour = value
		queue_redraw()
## A stone, drawn as a rounded grey rock in every marble set, so it never passes for a marble.
var stone: bool = false:
	set(value):
		stone = value
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
	if stone:
		_stone(r)
		return
	match GameLooks.finish:
		GameLooks.Finish.GLASS:
			_glass(r)
		GameLooks.Finish.GEM:
			_gem(r)
		GameLooks.Finish.PLANET:
			_planet(r)
		GameLooks.Finish.CANDY:
			_candy(r)
		_:
			draw_circle(Vector2.ZERO, r, colour.darkened(0.22), true, -1.0, true)
			draw_circle(Vector2(-r * 0.06, -r * 0.08), r * 0.88, colour, true, -1.0, true)
			_gloss(r)

## A rock: a lumpy outline, a darker underside and a few flecks, matte where a marble shines.
func _stone(r: float) -> void:
	var lumps: PackedVector2Array = PackedVector2Array()
	var shape: Array[float] = [1.0, 0.9, 0.97, 0.86, 0.95, 0.88, 1.0, 0.92, 0.85, 0.96]
	for k: int in range(shape.size()):
		lumps.append(Vector2.from_angle(TAU * k / shape.size() + 0.2) * r * 1.02 * shape[k])
	draw_colored_polygon(lumps, colour.darkened(0.25))
	var top: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in lumps:
		top.append(p * 0.84 + Vector2(-r * 0.05, -r * 0.08))
	draw_colored_polygon(top, colour)
	for fleck: Vector3 in [Vector3(-0.3, -0.25, 0.09), Vector3(0.28, 0.1, 0.07), Vector3(-0.05, 0.35, 0.06), Vector3(0.12, -0.4, 0.05)]:
		draw_circle(Vector2(fleck.x, fleck.y) * r, fleck.z * r, colour.darkened(0.35), true, -1.0, true)

func _gloss(r: float) -> void:
	draw_circle(Vector2(-r * 0.3, -r * 0.34), r * 0.3, Color(1, 1, 1, 0.5), true, -1.0, true)
	draw_circle(Vector2(-r * 0.36, -r * 0.4), r * 0.13, Color(1, 1, 1, 0.85), true, -1.0, true)

## Clear tinted glass: a see-through body with a bright rim, a deeper core and a long highlight.
func _glass(r: float) -> void:
	draw_circle(Vector2.ZERO, r, Color(colour, 0.5), true, -1.0, true)
	draw_circle(Vector2(r * 0.12, r * 0.16), r * 0.5, Color(colour.darkened(0.25), 0.55), true, -1.0, true)
	draw_arc(Vector2.ZERO, r * 0.93, 0.0, TAU, 40, colour.lightened(0.25), r * 0.13, true)
	draw_arc(Vector2.ZERO, r * 0.7, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.75), r * 0.12, true)
	draw_circle(Vector2(r * 0.38, r * 0.4), r * 0.08, Color(1, 1, 1, 0.6), true, -1.0, true)

## A cut stone: an octagon with a lighter table in the middle and facets running out to its corners.
func _gem(r: float) -> void:
	var outer: PackedVector2Array = _ring(r, 8, PI / 8.0)
	var table: PackedVector2Array = _ring(r * 0.56, 8, PI / 8.0)
	draw_colored_polygon(outer, colour.darkened(0.28))
	for k: int in range(8):
		var facet: PackedVector2Array = PackedVector2Array([outer[k], outer[(k + 1) % 8], table[(k + 1) % 8], table[k]])
		draw_colored_polygon(facet, colour.lightened(0.08) if k % 2 == 0 else colour.darkened(0.08))
	draw_colored_polygon(table, colour.lightened(0.18))
	draw_colored_polygon(PackedVector2Array([table[4], table[5], table[6]]), Color(1, 1, 1, 0.45))

## A small planet: bands across the body and a tilted ring, its back half behind and its front half over.
func _planet(r: float) -> void:
	_tilted_ring(r, PI, TAU)
	draw_circle(Vector2.ZERO, r * 0.86, colour.darkened(0.12), true, -1.0, true)
	draw_circle(Vector2(-r * 0.05, -r * 0.06), r * 0.78, colour, true, -1.0, true)
	for band: Vector2 in [Vector2(-0.34, 0.12), Vector2(0.18, 0.16)]:
		_band(r * 0.86, band.x * r, band.y * r, Color(colour.darkened(0.2), 0.7))
	_tilted_ring(r, 0.0, PI)
	draw_circle(Vector2(-r * 0.3, -r * 0.36), r * 0.12, Color(1, 1, 1, 0.6), true, -1.0, true)

## A peppermint: a bright body with three white swirls turning out from the middle.
func _candy(r: float) -> void:
	draw_circle(Vector2.ZERO, r, colour.darkened(0.15), true, -1.0, true)
	draw_circle(Vector2.ZERO, r * 0.9, colour, true, -1.0, true)
	for k: int in range(3):
		var start: float = k * TAU / 3.0
		var swirl: PackedVector2Array = PackedVector2Array()
		for s: int in range(1, 11):
			var t: float = s / 10.0
			swirl.append(Vector2.from_angle(start + t * 1.3) * r * 0.8 * t)
		draw_polyline(swirl, Color(1, 1, 1, 0.8), r * 0.2, true)
	_gloss(r)

static func _ring(r: float, sides: int, turn: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for k: int in range(sides):
		points.append(Vector2.from_angle(turn + TAU * k / sides) * r)
	return points

## Half of a planet's ring, from angle `from` to `to` around a flattened ellipse.
func _tilted_ring(r: float, from: float, to: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for s: int in range(17):
		var a: float = lerpf(from, to, s / 16.0)
		points.append(Vector2(cos(a) * r * 1.32, sin(a) * r * 0.36).rotated(-0.35))
	draw_polyline(points, colour.lightened(0.3), r * 0.12, true)

## A band across a disc of radius `r`, centred at height `y` and `h` tall, as the chord strip between.
func _band(r: float, y: float, h: float, ink: Color) -> void:
	var top: float = clampf(y - h * 0.5, -r, r)
	var bottom: float = clampf(y + h * 0.5, -r, r)
	var strip: PackedVector2Array = PackedVector2Array()
	for s: int in range(7):
		var yy: float = lerpf(top, bottom, s / 6.0)
		strip.append(Vector2(sqrt(maxf(r * r - yy * yy, 0.0)), yy))
	for s: int in range(6, -1, -1):
		var yy: float = lerpf(top, bottom, s / 6.0)
		strip.append(Vector2(-sqrt(maxf(r * r - yy * yy, 0.0)), yy))
	draw_colored_polygon(strip, ink)
