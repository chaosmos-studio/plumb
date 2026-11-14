class_name Spin
extends RefCounted

## A flat disc drawn to read as a ball: how it turns as it rolls, and the light on it (MATH.md section 17).
## Seen from above the board: x to the right, y down the screen, z out of the screen toward the player.

## The share of a true roll the pattern turns. A marble rolls a cell in 52 ms, which is about 2.8 radians of
## true roll in three frames: faster than an eye can follow, so the pattern would only flicker.
const SHARE: float = 0.4
## The light comes from the upper left and a little in front, and the tray throws a soft light back up from
## the lower right.
const LIGHT: Vector3 = Vector3(-0.5, -0.62, 0.6)
const BOUNCE: Vector2 = Vector2(0.55, 0.83)
## How dark the far side gets and how light the near one, as overlay opacity, and the light the tray throws.
const SHADE: float = 0.5
const GLOW: float = 0.28
const BOUNCE_LIGHT: float = 0.32
## The brightness, from 0 to 1, at which a ball shows its own colour untouched.
const TRUE_AT: float = 0.72

## The ball's turn after rolling `travel` (in the same units as `radius`) across the board.
static func roll(turn: Basis, travel: Vector2, radius: float, share: float = SHARE) -> Basis:
	var d: float = travel.length()
	if d < 0.0001 or radius <= 0.0:
		return turn
	# Rolling right turns the top of the ball right, about the axis at right angles to the travel in the board.
	var axis: Vector3 = Vector3(-travel.y, travel.x, 0.0) / d
	return (Basis(axis, d / radius * share) * turn).orthonormalized()

## The ball's turn after rolling `along` a bar seen from the side, as on the title: it turns in the screen's
## plane, clockwise when rolling right.
static func roll_side(turn: Basis, along: float, radius: float, share: float = 1.0) -> Basis:
	if absf(along) < 0.0001 or radius <= 0.0:
		return turn
	return (Basis(Vector3(0.0, 0.0, 1.0), along / radius * share) * turn).orthonormalized()

## The eight corners of a cube on the unit sphere, turned off the axes so none faces the player straight on.
static func corners() -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	var tilt: Basis = Basis(Vector3(1.0, 0.0, 0.0), 0.5) * Basis(Vector3(0.0, 1.0, 0.0), 0.35)
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				points.append(tilt * Vector3(x, y, z).normalized())
	return points

## A great circle of `count` points about `normal`.
static func ring(normal: Vector3, count: int) -> PackedVector3Array:
	var n: Vector3 = normal.normalized()
	var a: Vector3 = n.cross(Vector3(0.0, 0.0, 1.0) if absf(n.z) < 0.9 else Vector3(1.0, 0.0, 0.0)).normalized()
	var b: Vector3 = n.cross(a)
	var points: PackedVector3Array = PackedVector3Array()
	for k: int in range(count):
		var t: float = TAU * k / count
		points.append(a * cos(t) + b * sin(t))
	return points

## How bright a point of the ball at `p` (in the unit disc) is, from 0 to a little over 1: the light's
## cosine on the surface, a floor of ambient light, and the tray's bounce near the lower right rim.
static func brightness(p: Vector2) -> float:
	var rr: float = p.length_squared()
	if rr >= 1.0:
		return TRUE_AT
	var n: Vector3 = Vector3(p.x, p.y, sqrt(1.0 - rr))
	var lit: float = maxf(n.dot(LIGHT.normalized()), 0.0)
	var b: float = 0.25 + 0.75 * lit
	var rim: float = pow(1.0 - n.z, 2.0) * maxf(Vector2(p.x, p.y).normalized().dot(BOUNCE), 0.0)
	return b + rim * BOUNCE_LIGHT

## The light over a ball as a `size` pixel image: black where the ball is darker than its own colour and white
## where it is lighter, each at the opacity that makes it so. Drawn once over every marble in every set.
static func light(size: int) -> Image:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size * size * 4)
	var half: float = size * 0.5
	for y: int in range(size):
		for x: int in range(size):
			var p: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(half, half)) / half
			var edge: float = clampf((1.0 - p.length()) * half, 0.0, 1.0)
			var at: int = (y * size + x) * 4
			if edge <= 0.0:
				continue
			var k: float = brightness(p)
			var white: bool = k >= TRUE_AT
			var alpha: float = clampf((k - TRUE_AT) / (1.0 - TRUE_AT) * GLOW, 0.0, GLOW) if white \
				else clampf((TRUE_AT - k) / TRUE_AT * SHADE * 1.6, 0.0, SHADE)
			var v: int = 255 if white else 0
			bytes[at] = v
			bytes[at + 1] = v
			bytes[at + 2] = v
			bytes[at + 3] = int(round(alpha * edge * 255.0))
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)
