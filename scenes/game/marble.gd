class_name Marble
extends Node2D

## Squash and fades are done on the node's scale and modulate, so the drawing never changes. The node itself
## never turns as a marble rolls, so a face stays upright: the roll shows in a pattern that turns under it
## (MATH.md section 18).

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
var number: int = 0:
	set(value):
		number = value
		queue_redraw()
## The finish to draw in (GameLooks.Finish), or -1 for the marble set in use: the Looks cards show each
## set in its own.
var finish: int = -1:
	set(value):
		finish = value
		queue_redraw()
## Whose face it wears, a colour index as the board keeps them (Cast.of), or -1 for none.
var who: int = -1:
	set(value):
		who = value
		var cast: Cast.Who = Cast.of(who)
		mood.set_rest(cast.lids, cast.smile, cast.brow)
		queue_redraw()
## Seen from the side, as on the title's seesaw, a ball turns in the screen's plane.
var side_view: bool = false
## A party hat, 0 to 1 as it pops on.
var hat: float = 0.0:
	set(value):
		hat = value
		queue_redraw()
var mood: Mood
## How fast it moved last frame, in pixels a second.
var speed: float = 0.0

## The tail is worked out from how far the marble moved since last frame, so anything that moves it
## (a roll, an undo, the title toy) gets one without asking.
const TAIL_PER_SPEED: float = 0.045
## The rolling pattern shows from this speed, in radii a second, and is fully there at ROLL_FULL.
const ROLL_FULL: float = 10.0
const ROLL_EASE: float = 12.0
const LIGHT_SIZE: int = 128
## The least change in a face worth drawing again, so a face at rest costs nothing.
const STILL: float = 0.004

static var _light: Texture2D
static var _corners: PackedVector3Array = Spin.corners()
static var _ring_a: PackedVector3Array = Spin.ring(Vector3(1.0, 0.35, 0.2), 24)
static var _ring_b: PackedVector3Array = Spin.ring(Vector3(-0.25, 1.0, -0.3), 24)
static var _born: int = 0

var _last: Vector2 = Vector2.ZERO
var _tail: Vector2 = Vector2.ZERO
var _turn: Basis = Basis.IDENTITY
var _rolling: float = 0.0
var _buf: PackedVector2Array = PackedVector2Array()
var _drawn: PackedFloat32Array = PackedFloat32Array()
var _drawn_face: bool = false

func _init() -> void:
	mood = Mood.new(_born)
	_born += 1
	_drawn.resize(9)

## Whether this marble shows a face: the setting is on and it is someone.
func faced() -> bool:
	return Cast.showing and (who >= 0 or stone)

## Back to rest, as a marble is put back by an undo or a restart.
func calm() -> void:
	mood.reset()
	hat = 0.0
	_turn = Basis.IDENTITY
	_rolling = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var step: Vector2 = position - _last
	_last = position
	# A jump of more than a couple of radii in one frame is a placement (first frame, undo), not a roll.
	var placed: bool = step.length() > radius * 2.5
	var velocity: Vector2 = Vector2.ZERO if placed else step / delta
	speed = velocity.length()
	var target: Vector2 = -velocity * TAIL_PER_SPEED
	if target.length() > radius * 1.6:
		target = target.normalized() * radius * 1.6
	_tail = _tail.lerp(target, 0.5)
	var dirty: bool = _tail.length() > 0.5 or target.length() > 0.5
	if not placed and step.length() > 0.01:
		if side_view:
			_turn = Spin.roll_side(_turn, step.length() * signf(step.x), radius)
		else:
			_turn = Spin.roll(_turn, step, radius)
	var was: float = _rolling
	_rolling = lerpf(_rolling, clampf(velocity.length() / (radius * ROLL_FULL), 0.0, 1.0), 1.0 - exp(-ROLL_EASE * delta))
	dirty = dirty or _rolling > 0.01 or was > 0.01 or faced() != _drawn_face
	if faced():
		mood.moving(velocity / radius, delta)
		mood.step(delta)
		dirty = dirty or _face_moved()
	if dirty:
		queue_redraw()

func _face_moved() -> bool:
	return absf(mood.open - _drawn[0]) > STILL or absf(mood.wide - _drawn[1]) > STILL \
		or absf(mood.pupil - _drawn[2]) > STILL or absf(mood.brow - _drawn[3]) > STILL \
		or absf(mood.smile - _drawn[4]) > STILL or absf(mood.gape - _drawn[5]) > STILL \
		or absf(mood.happy - _drawn[6]) > STILL or absf(mood.look.x - _drawn[7]) > STILL \
		or absf(mood.look.y - _drawn[8]) > STILL

func _draw() -> void:
	var r: float = radius
	if _tail.length() > 2.0:
		var side: Vector2 = _tail.orthogonal().normalized() * r * 0.8
		var tail: PackedVector2Array = PackedVector2Array([side, _tail, -side])
		draw_colored_polygon(tail, Color(colour, 0.28))
	draw_circle(Vector2(r * 0.08, r * 0.22), r * 0.98, Color(0.2, 0.16, 0.1, 0.18), true, -1.0, true)
	if stone:
		_stone(r)
	else:
		match finish if finish >= 0 else GameLooks.finish:
			GameLooks.Finish.GLASS:
				_glass(r)
			GameLooks.Finish.GEM:
				_gem(r)
			GameLooks.Finish.PLANET:
				_planet(r)
			GameLooks.Finish.CANDY:
				_candy(r)
			GameLooks.Finish.PEARL:
				_pearl(r)
			GameLooks.Finish.YARN:
				_yarn(r)
			_:
				draw_circle(Vector2.ZERO, r, colour.darkened(0.22), true, -1.0, true)
				draw_circle(Vector2(-r * 0.06, -r * 0.08), r * 0.88, colour, true, -1.0, true)
				_dots(r * 0.9, colour.lightened(0.4), 0.55, 0.09)
				_light_over(r)
				_gloss(r)
	var faces: bool = faced()
	_drawn_face = faces
	if faces:
		Face.draw(self, Cast.of(TiltBoard.STONE if stone else who), mood, r, colour, number > 0, _buf)
		_remember_face()
	if number > 0:
		_number(r, faces)
	elif ColourHelp.on and not stone and who >= 0:
		# Colour help: the colour's shape in cream on a rim of its own deep tone, low on the marble under the face, as
		# the Settings concept draws it, or in the middle without a face.
		var at: Vector2 = Vector2(0.0, r * 0.7) if faces else Vector2.ZERO
		var size: float = r * (0.4 if faces else 0.8)
		ColourHelp.draw(self, who, at, size * 1.35, colour.darkened(0.5))
		ColourHelp.draw(self, who, at, size)
	if hat > 0.0 and faces:
		var main: Color = Palette.marble(posmod(who + 2, 4))
		Face.hat(self, r, hat, main, Color(1, 1, 1, 0.92), _buf)

func _remember_face() -> void:
	_drawn[0] = mood.open
	_drawn[1] = mood.wide
	_drawn[2] = mood.pupil
	_drawn[3] = mood.brow
	_drawn[4] = mood.smile
	_drawn[5] = mood.gape
	_drawn[6] = mood.happy
	_drawn[7] = mood.look.x
	_drawn[8] = mood.look.y

## A number in a dark disc on the marble's face, so it reads on every colour and finish. With a face, the disc
## moves down to where a mouth would be, under the eyes.
func _number(r: float, low: bool) -> void:
	var at: Vector2 = Vector2(r * 0.02, r * 0.4) if low else Vector2(r * 0.04, r * 0.06)
	var disc: float = r * (0.4 if low else 0.5)
	draw_circle(at, disc, Color(0.08, 0.08, 0.1, 0.72), true, -1.0, true)
	var font: Font = load(Brand.FONT_UI)
	var size: int = int(r * (0.64 if low else 0.78))
	var text: String = str(number)
	var w: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(font, Vector2(at.x - w.x * 0.5, at.y + size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color.WHITE)

## The light on a ball, from one shared texture (Spin.light): its far side darker and its near side lighter
## than its own colour, and the tray's light thrown back up under it.
func _light_over(body: float) -> void:
	if _light == null:
		_light = ImageTexture.create_from_image(Spin.light(LIGHT_SIZE))
	draw_texture_rect(_light, Rect2(-body, -body, body * 2.0, body * 2.0), false)

## Spots on the ball that turn as it rolls and show only while it does, so a marble at rest looks as its set
## draws it.
func _dots(body: float, ink: Color, alpha: float, size: float) -> void:
	if _rolling <= 0.01:
		return
	for p: Vector3 in _corners:
		var q: Vector3 = _turn * p
		if q.z <= 0.0:
			continue
		var fade: float = smoothstep(0.0, 0.35, q.z) * _rolling * alpha
		draw_circle(Vector2(q.x, q.y) * body, body * size * (0.45 + 0.55 * q.z), Color(ink, ink.a * fade), true, -1.0, true)

## Glints that sweep across a cut stone as it turns.
func _glints(body: float) -> void:
	if _rolling <= 0.01:
		return
	for p: Vector3 in _corners:
		var q: Vector3 = _turn * p
		if q.z <= 0.0:
			continue
		var at: Vector2 = Vector2(q.x, q.y) * body
		var arm: float = body * 0.14 * q.z
		var ink: Color = Color(1, 1, 1, 0.85 * smoothstep(0.0, 0.4, q.z) * _rolling)
		draw_line(at - Vector2(arm, 0.0), at + Vector2(arm, 0.0), ink, maxf(1.0, body * 0.04), true)
		draw_line(at - Vector2(0.0, arm), at + Vector2(0.0, arm), ink, maxf(1.0, body * 0.04), true)

## Short sprinkles that roll round with a candy ball.
func _sprinkles(body: float) -> void:
	if _rolling <= 0.01:
		return
	var inks: Array[Color] = [Color(1, 1, 1, 0.9), Color(1.0, 0.86, 0.45, 0.9), Color(0.55, 0.85, 1.0, 0.9)]
	for k: int in range(_corners.size()):
		var p: Vector3 = _corners[k]
		var q: Vector3 = _turn * p
		if q.z <= 0.1:
			continue
		var along: Vector3 = _turn * p.cross(Vector3(0.0, 0.0, 1.0) if k % 2 == 0 else Vector3(1.0, 0.0, 0.0)).normalized()
		var at: Vector2 = Vector2(q.x, q.y) * body
		var d: Vector2 = Vector2(along.x, along.y) * body * 0.11
		var ink: Color = inks[k % inks.size()]
		draw_line(at - d, at + d, Color(ink, ink.a * smoothstep(0.1, 0.45, q.z) * _rolling), maxf(1.5, body * 0.07), true)

## A great circle on the ball, drawn where it faces the player. `depth` scales it inside the ball, and `back`
## is the opacity of its far half, seen through glass.
func _ring(points: PackedVector3Array, body: float, ink: Color, width: float, depth: float, back: float) -> void:
	if _rolling <= 0.01:
		return
	var n: int = points.size()
	for k: int in range(n):
		var a: Vector3 = _turn * points[k]
		var b: Vector3 = _turn * points[(k + 1) % n]
		var face: float = smoothstep(-0.1, 0.25, minf(a.z, b.z))
		var alpha: float = lerpf(back, 1.0, face) * _rolling
		if alpha <= 0.01:
			continue
		draw_line(Vector2(a.x, a.y) * body * depth, Vector2(b.x, b.y) * body * depth, Color(ink, ink.a * alpha), width, true)

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
	_dots(r * 0.8, colour.darkened(0.4), 0.8, 0.07)

func _gloss(r: float) -> void:
	draw_circle(Vector2(-r * 0.3, -r * 0.34), r * 0.3, Color(1, 1, 1, 0.42), true, -1.0, true)
	draw_set_transform(Vector2(-r * 0.34, -r * 0.4), -0.7, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, r * 0.16, Color(1, 1, 1, 0.9), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(r * 0.4, r * 0.44), r * 0.05, Color(1, 1, 1, 0.35), true, -1.0, true)

func _glass(r: float) -> void:
	draw_circle(Vector2.ZERO, r, Color(colour, 0.5), true, -1.0, true)
	draw_circle(Vector2(r * 0.12, r * 0.16), r * 0.5, Color(colour.darkened(0.25), 0.55), true, -1.0, true)
	_ring(_ring_a, r, Color(colour.darkened(0.35), 0.7), maxf(1.5, r * 0.1), 0.6, 0.3)
	_ring(_ring_b, r, Color(colour.darkened(0.35), 0.7), maxf(1.5, r * 0.1), 0.6, 0.3)
	_light_over(r)
	draw_arc(Vector2.ZERO, r * 0.93, 0.0, TAU, 40, colour.lightened(0.25), r * 0.13, true)
	draw_arc(Vector2.ZERO, r * 0.7, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.75), r * 0.12, true)
	draw_circle(Vector2(r * 0.38, r * 0.4), r * 0.08, Color(1, 1, 1, 0.6), true, -1.0, true)

func _gem(r: float) -> void:
	var outer: PackedVector2Array = _ring_points(r, 8, PI / 8.0)
	var table: PackedVector2Array = _ring_points(r * 0.56, 8, PI / 8.0)
	draw_colored_polygon(outer, colour.darkened(0.28))
	for k: int in range(8):
		var facet: PackedVector2Array = PackedVector2Array([outer[k], outer[(k + 1) % 8], table[(k + 1) % 8], table[k]])
		draw_colored_polygon(facet, colour.lightened(0.08) if k % 2 == 0 else colour.darkened(0.08))
	draw_colored_polygon(table, colour.lightened(0.18))
	_light_over(r * 0.93)
	_glints(r * 0.85)
	draw_colored_polygon(PackedVector2Array([table[4], table[5], table[6]]), Color(1, 1, 1, 0.45))

## The ring's back half is drawn before the body and its front half after.
func _planet(r: float) -> void:
	_tilted_ring(r, PI, TAU)
	draw_circle(Vector2.ZERO, r * 0.86, colour.darkened(0.12), true, -1.0, true)
	draw_circle(Vector2(-r * 0.05, -r * 0.06), r * 0.78, colour, true, -1.0, true)
	for band: Vector2 in [Vector2(-0.34, 0.12), Vector2(0.18, 0.16)]:
		_band(r * 0.86, band.x * r, band.y * r, Color(colour.darkened(0.2), 0.7))
	_dots(r * 0.78, Color(colour.darkened(0.3), 0.75), 1.0, 0.13)
	_light_over(r * 0.86)
	_tilted_ring(r, 0.0, PI)
	draw_circle(Vector2(-r * 0.3, -r * 0.36), r * 0.12, Color(1, 1, 1, 0.6), true, -1.0, true)

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
	_sprinkles(r * 0.9)
	_light_over(r)
	_gloss(r)

## Nacre has no hard spot of light: the sheen rises in soft steps, and the shaded side catches a second hue.
func _pearl(r: float) -> void:
	draw_circle(Vector2.ZERO, r, colour.darkened(0.2), true, -1.0, true)
	draw_circle(Vector2(-r * 0.03, -r * 0.04), r * 0.92, colour, true, -1.0, true)
	var overtone: Color = Color.from_hsv(fposmod(colour.h - 0.09, 1.0), 0.4, 1.0, 0.7)
	draw_arc(Vector2(-r * 0.03, -r * 0.04), r * 0.8, PI * 0.02, PI * 0.7, 18, overtone, r * 0.12, true)
	_dots(r * 0.9, colour.lightened(0.5), 0.35, 0.16)
	_light_over(r)
	for k: int in range(1, 13):
		var t: float = k / 12.0
		draw_circle(Vector2(-r * 0.2, -r * 0.24) * t, r * lerpf(0.76, 0.18, t), Color(colour.lightened(0.1 + 0.8 * t), 0.24),
			true, -1.0, true)

## Two bands of wound strands, the second wound over the first, so it hides what lies under it.
func _yarn(r: float) -> void:
	var c: Vector2 = Vector2(-r * 0.03, -r * 0.04)
	var ball: float = r * 0.92
	var ink: Color = colour.darkened(0.28)
	var width: float = r * 0.075
	draw_circle(Vector2.ZERO, r, colour.darkened(0.22), true, -1.0, true)
	draw_circle(c, ball, colour, true, -1.0, true)
	draw_circle(c + Vector2(-r * 0.22, -r * 0.26), r * 0.46, Color(colour.lightened(0.3), 0.35), true, -1.0, true)
	var first: float = 0.55
	var second: float = first + 1.75
	for lean: float in [-0.7, -0.3, 0.1, 0.5]:
		draw_polyline(_strand(c, ball, first, lean), ink, width, true)
	var over: PackedVector2Array = _strand(c, ball, second, 0.98)
	var under: PackedVector2Array = _strand(c, ball, second, -0.1)
	for s: int in range(under.size() - 2, 0, -1):
		over.append(under[s])
	draw_colored_polygon(over, colour)
	for lean: float in [-0.1, 0.25, 0.6]:
		draw_polyline(_strand(c, ball, second, lean), ink, width, true)
	_ring(_ring_a, ball, ink, width, 1.0, 0.0)
	_ring(_ring_b, ball, ink, width, 1.0, 0.0)
	_light_over(r)

## Half a great circle on a ball of radius `r` about `c`: its ends sit on the rim at `axis` and opposite, and
## `lean` tips it from edge on (0) to the outline itself (1 or -1), as wound strands look from the front.
static func _strand(c: Vector2, r: float, axis: float, lean: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for s: int in range(17):
		var a: float = PI * s / 16.0
		points.append(c + Vector2(cos(a) * r, sin(a) * r * lean).rotated(axis))
	return points

static func _ring_points(r: float, sides: int, turn: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for k: int in range(sides):
		points.append(Vector2.from_angle(turn + TAU * k / sides) * r)
	return points

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
