class_name Gaze
extends RefCounted

## Where a pupil sits inside its eye, and how a look moves (MATH.md section 16). Everything is in the face's
## own units, the marble's radius being 1.

## How far a target must be before the pupil reaches most of the way to the rim: a target this far off moves
## it halfway, so near things draw a small glance and far ones a full one.
const SOFT: float = 0.8
## The look's spring, in radians a second. Eyes jump fast: 30 settles a glance in about a sixth of a second
## without overshooting.
const SNAP: float = 30.0

## The look now, as a direction and a reach of up to 1, and how fast it is moving.
var at: Vector2 = Vector2.ZERO
var speed: Vector2 = Vector2.ZERO

## Moves the look toward `target` by a critically damped spring, solved exactly, so a long frame on a slow
## phone cannot make it overshoot or blow up.
func step(target: Vector2, dt: float, omega: float = SNAP) -> void:
	var y: Vector2 = at - target
	var c: Vector2 = speed + y * omega
	var e: float = exp(-omega * dt)
	at = target + (y + c * dt) * e
	speed = (c - (y + c * dt) * omega) * e

## A look at a point `d` away from the face, as a direction and a reach that grows with distance and never
## quite reaches 1.
static func toward(d: Vector2) -> Vector2:
	var far: float = d.length()
	if far < 0.0001:
		return Vector2.ZERO
	return d / far * (far / (far + SOFT))

## The pupil's centre for an eye at `eye` with white radii `white` and a pupil of radius `pupil`, looking at a
## point `target` on the face's plane: each eye aims from where it is, so a near target draws the pupils
## together. `reach` is how far the look goes, 0 straight ahead and 1 to the rim.
static func pupil_for_point(eye: Vector2, white: Vector2, pupil: float, target: Vector2) -> Vector2:
	return eye + inside(white, pupil, toward(target - eye))

## The pupil's offset from the eye's centre for a look `look` (a direction with a reach up to 1): the pupil
## travels toward the rim of the white, an ellipse, and stops a pupil's radius short of it.
static func inside(white: Vector2, pupil: float, look: Vector2) -> Vector2:
	var reach: float = minf(look.length(), 1.0)
	if reach < 0.0001:
		return Vector2.ZERO
	var u: Vector2 = look / look.length()
	var room: Vector2 = Vector2(maxf(white.x - pupil, 0.0), maxf(white.y - pupil, 0.0))
	if room.x <= 0.0 or room.y <= 0.0:
		return Vector2.ZERO
	# Along u, an ellipse with semi-axes room meets its rim at 1 / sqrt((ux / a)² + (uy / b)²).
	var rim: float = 1.0 / sqrt(pow(u.x / room.x, 2.0) + pow(u.y / room.y, 2.0))
	return u * rim * reach
