class_name Face
extends RefCounted

## Draws a character's face on a marble from its Mood, in flat shapes, upright whatever the marble does.
## Every size is a share of the marble's radius `r`. `buf` is the caller's scratch array, so a face drawn every
## frame allocates nothing.

const INK: Color = Color(0.13, 0.14, 0.19)
const WHITE: Color = Color(0.995, 0.985, 0.965)
const BLUSH: Color = Color(1.0, 0.42, 0.5, 0.42)
const TONGUE: Color = Color(1.0, 0.5, 0.55)
## How far the whole face slides toward where it looks, which reads as the head turning.
const TURN: float = 0.1
## With a number on the marble, the eyes sit this much higher and this much smaller, and the mouth gives way
## to the number.
const NUMBERED_LIFT: float = 0.14
const NUMBERED_SCALE: float = 0.8
const ARC_POINTS: int = 12

static func draw(ci: CanvasItem, who: Cast.Who, m: Mood, r: float, body: Color, numbered: bool,
		buf: PackedVector2Array) -> void:
	var lift: float = NUMBERED_LIFT if numbered else 0.0
	var size: float = NUMBERED_SCALE if numbered else 1.0
	var origin: Vector2 = m.look * TURN * r + Vector2(0.0, -lift * r)
	if who.mark == Cast.Mark.ROCK:
		_rock(ci, who, m, r, origin, buf)
		return
	var line: float = maxf(1.2, r * 0.065)
	for side: float in [-1.0, 1.0]:
		var c: Vector2 = origin + Vector2(side * who.eyes.x * size, who.eyes.y) * r
		var radii: Vector2 = who.white * r * m.wide * size * (who.odd if side > 0.0 else 1.0)
		if m.happy > 0.5:
			# Content, shut eyes: a raised arc each.
			ci.draw_arc(c + Vector2(0.0, radii.y * 0.45), radii.x * 0.95, PI * 1.12, PI * 1.88, ARC_POINTS, INK, line, true)
			continue
		if m.open < 0.1:
			ci.draw_arc(c + Vector2(0.0, -radii.y * 0.25), radii.x * 0.9, PI * 0.15, PI * 0.85, ARC_POINTS, INK, line, true)
			continue
		_ellipse(ci, c, radii, WHITE)
		var p: float = who.pupil * r * size * m.pupil
		var at: Vector2 = c + Gaze.inside(radii, p, m.look)
		ci.draw_circle(at, p, INK, true, -1.0, true)
		ci.draw_circle(at + Vector2(-0.38, -0.38) * p, p * 0.32, Color(1, 1, 1, 0.9), true, -1.0, true)
		if m.open < 0.97:
			_lid(ci, c, radii, m.open, body.darkened(0.08), line * 0.8, buf)
		_ring(ci, c, radii, Color(INK, 0.85), maxf(1.0, r * 0.035))
		if who.mark == Cast.Mark.LASHES and m.open > 0.1:
			var top: float = c.y - radii.y + 2.0 * radii.y * (1.0 - m.open)
			var outer: Vector2 = Vector2(c.x + side * radii.x * 0.86, top + radii.y * 0.18)
			for k: int in range(2):
				var a: float = -PI * 0.5 + side * (0.75 + 0.4 * k)
				ci.draw_line(outer, outer + Vector2.from_angle(a) * r * 0.12, INK, line * 0.7, true)
	_brows(ci, who, m, r, origin, size, line)
	if numbered:
		return
	_mouth(ci, who, m, r, origin, line, buf)
	match who.mark:
		Cast.Mark.FRECKLES:
			var freckle: Color = Color(body.darkened(0.4), 0.6)
			for side: float in [-1.0, 1.0]:
				for dot: Vector2 in [Vector2(0.4, 0.1), Vector2(0.49, 0.06), Vector2(0.46, 0.17)]:
					ci.draw_circle(origin + Vector2(side * dot.x, dot.y) * r, r * 0.028, freckle, true, -1.0, true)
		Cast.Mark.BLUSH:
			for side: float in [-1.0, 1.0]:
				_ellipse(ci, origin + Vector2(side * 0.43, 0.15) * r, Vector2(0.1, 0.055) * r, BLUSH)

static func _brows(ci: CanvasItem, who: Cast.Who, m: Mood, r: float, origin: Vector2, size: float, line: float) -> void:
	var show: float = 1.0 if who.brows else clampf(absf(m.brow) * 2.0 - 0.3, 0.0, 1.0)
	if show <= 0.0 or m.happy > 0.5:
		return
	for side: float in [-1.0, 1.0]:
		var radii: Vector2 = who.white * r * m.wide * size * (who.odd if side > 0.0 else 1.0)
		var mid: Vector2 = origin + Vector2(side * who.eyes.x * size * r, who.eyes.y * r - radii.y - r * 0.1)
		var half: float = r * 0.14
		# Worried brows lift at the middle of the face, bold ones dip there.
		var inner: Vector2 = mid + Vector2(-side * half, -m.brow * r * 0.11)
		var outer: Vector2 = mid + Vector2(side * half, m.brow * r * 0.04)
		ci.draw_line(outer, inner, Color(INK, show), line * 1.1, true)

static func _mouth(ci: CanvasItem, who: Cast.Who, m: Mood, r: float, origin: Vector2, line: float,
		buf: PackedVector2Array) -> void:
	var c: Vector2 = origin + Vector2(0.0, who.mouth.y * r)
	var w: float = who.mouth.x * r
	if m.gape > 0.12:
		if m.smile > 0.6:
			# A laugh: the lower half of an ellipse, with a tongue.
			var depth: float = r * (0.06 + 0.2 * m.gape)
			buf.resize(ARC_POINTS + 1)
			for k: int in range(ARC_POINTS + 1):
				var t: float = PI * k / ARC_POINTS
				buf[k] = c + Vector2(cos(t) * w * 1.05, sin(t) * depth)
			ci.draw_colored_polygon(buf, INK)
			ci.draw_circle(c + Vector2(0.0, depth * 0.62), minf(w * 0.4, depth * 0.45), TONGUE, true, -1.0, true)
			return
		var radii: Vector2 = Vector2(w * (0.42 + 0.22 * m.gape), r * (0.05 + 0.17 * m.gape))
		_ellipse(ci, c + Vector2(0.0, radii.y * 0.4), radii, INK)
		if m.gape > 0.6:
			ci.draw_circle(c + Vector2(0.0, radii.y * 1.0), radii.x * 0.5, TONGUE, true, -1.0, true)
		return
	# A line that sags into a smile or lifts into a frown, a quadratic curve through its ends.
	var sag: float = m.smile * r * 0.14
	var a: Vector2 = c + Vector2(-w, 0.0)
	var b: Vector2 = c + Vector2(w, -r * 0.035 if who.mark == Cast.Mark.GOOGLY else 0.0)
	var mid: Vector2 = c + Vector2(0.0, sag * 2.0)
	buf.resize(ARC_POINTS + 1)
	for k: int in range(ARC_POINTS + 1):
		var t: float = float(k) / ARC_POINTS
		buf[k] = a * (1.0 - t) * (1.0 - t) + mid * 2.0 * (1.0 - t) * t + b * t * t
	ci.draw_polyline(buf, INK, line, true)

## A stone sleeps: shut eyes and a small flat mouth, and it opens its eyes only while it rolls.
static func _rock(ci: CanvasItem, who: Cast.Who, m: Mood, r: float, origin: Vector2, buf: PackedVector2Array) -> void:
	var line: float = maxf(1.2, r * 0.06)
	var ink: Color = Color(INK, 0.8)
	for side: float in [-1.0, 1.0]:
		var c: Vector2 = origin + Vector2(side * who.eyes.x, who.eyes.y) * r
		if m.open > 0.35:
			ci.draw_circle(c, who.pupil * r * m.wide, ink, true, -1.0, true)
		elif m.feel == Mood.Feel.BUMP:
			ci.draw_line(c + Vector2(-who.white.x, -0.04) * r, c + Vector2(who.white.x, 0.04 * side) * r, ink, line, true)
		else:
			ci.draw_arc(c + Vector2(0.0, -who.white.y * r), who.white.x * r, PI * 0.2, PI * 0.8, ARC_POINTS, ink, line, true)
	var mouth: Vector2 = origin + Vector2(0.0, who.mouth.y * r)
	if m.gape > 0.2:
		_ellipse(ci, mouth, Vector2(0.06, 0.04 + 0.06 * m.gape) * r, ink)
	else:
		ci.draw_line(mouth - Vector2(who.mouth.x * r, 0.0), mouth + Vector2(who.mouth.x * r, 0.0), ink, line, true)

## A party hat, a striped cone leaning a little to the right with a pompom. `grow` runs 0 to 1 as it pops on.
static func hat(ci: CanvasItem, r: float, grow: float, main: Color, stripe: Color, buf: PackedVector2Array) -> void:
	if grow <= 0.01:
		return
	var base: Vector2 = Vector2(0.06, -0.8) * r
	ci.draw_set_transform(base, 0.18, Vector2(grow, grow))
	var half: float = 0.36 * r
	var tall: float = 0.82 * r
	buf.resize(3)
	buf[0] = Vector2(-half, 0.0)
	buf[1] = Vector2(half, 0.0)
	buf[2] = Vector2(0.0, -tall)
	ci.draw_colored_polygon(buf, main)
	buf.resize(4)
	for band: Vector2 in [Vector2(0.22, 0.36), Vector2(0.56, 0.68)]:
		buf[0] = Vector2(-half * (1.0 - band.x), -tall * band.x)
		buf[1] = Vector2(half * (1.0 - band.x), -tall * band.x)
		buf[2] = Vector2(half * (1.0 - band.y), -tall * band.y)
		buf[3] = Vector2(-half * (1.0 - band.y), -tall * band.y)
		ci.draw_colored_polygon(buf, stripe)
	ci.draw_line(Vector2(-half * 1.05, 0.0), Vector2(half * 1.05, 0.0), WHITE, r * 0.1, true)
	ci.draw_circle(Vector2(0.0, -tall), r * 0.12, WHITE, true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO)

static func _ellipse(ci: CanvasItem, c: Vector2, radii: Vector2, colour: Color) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0:
		return
	ci.draw_set_transform(c, 0.0, Vector2(1.0, radii.y / radii.x))
	ci.draw_circle(Vector2.ZERO, radii.x, colour, true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO)

static func _ring(ci: CanvasItem, c: Vector2, radii: Vector2, colour: Color, width: float) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0:
		return
	ci.draw_set_transform(c, 0.0, Vector2(1.0, radii.y / radii.x))
	ci.draw_arc(Vector2.ZERO, radii.x, 0.0, TAU, 28, colour, width, true)
	ci.draw_set_transform(Vector2.ZERO)

## The upper lid over an eye, closed down to `open` (1 open, 0 shut): the part of the ellipse above the lid's
## edge, filled in the skin's colour, with the edge drawn in ink.
static func _lid(ci: CanvasItem, c: Vector2, radii: Vector2, open: float, skin: Color, width: float,
		buf: PackedVector2Array) -> void:
	var edge: float = clampf(1.0 - 2.0 * open, -1.0, 1.0)
	# With y down the screen, the points of the ellipse at or above the edge have sin(t) <= edge: they run from
	# pi - asin(edge) round over the top to 2 pi + asin(edge).
	var s: float = asin(edge)
	buf.resize(ARC_POINTS + 1)
	for k: int in range(ARC_POINTS + 1):
		var t: float = lerpf(PI - s, TAU + s, float(k) / ARC_POINTS)
		buf[k] = c + Vector2(cos(t) * radii.x, sin(t) * radii.y)
	ci.draw_colored_polygon(buf, skin)
	ci.draw_line(buf[0], buf[ARC_POINTS], INK, width, true)
