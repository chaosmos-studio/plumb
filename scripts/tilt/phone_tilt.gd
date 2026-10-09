class_name PhoneTilt
extends RefCounted

## Reads the phone's lean into Plumb's four tilts, for players who would rather tip the phone than swipe.
## It learns how the phone is held at rest and measures every lean from there, as two angles: the roll to
## one side, and the pitch back from upright. So it works sitting up, lying down or with the phone flat on
## a table. A lean past FIRE degrees is one tilt, and the phone must come back within REARM degrees of rest
## before the next, so holding it tipped never fires twice. While it rests, the rest follows it slowly, so
## a player who settles into a new way of holding it is not pushed off.
##
## Gravity comes as Godot gives it on Android: in the screen's own axes, x to the right and y up, pointing
## at the ground. Lowering the right edge pulls gravity right, so the marbles roll right. Lowering the top
## edge tips the phone further back, so the marbles roll up.

## Degrees of lean, from rest, that make a tilt.
const FIRE: float = 16.0
## Degrees from rest the phone must come back within before the next lean counts.
const REARM: float = 7.0
## How quickly the rest drifts toward the phone's pose while it rests, per reading.
const SETTLE: float = 0.02
## Below this, in m/s², the reading is not gravity at all: no sensor, or the phone in free fall.
const WEAK: float = 2.0

var _rest: Vector3 = Vector3.ZERO
var _armed: bool = false

## Whether this device reports gravity at all: an Android phone does, a desktop or the web build does not.
static func can_feel() -> bool:
	return OS.has_feature("android") and Input.get_gravity().length() >= WEAK

## Forgets the rest, so the next reading becomes it. Call when play starts again after a pause.
func reset() -> void:
	_rest = Vector3.ZERO
	_armed = false

## Takes one gravity reading and returns the tilt it makes (TiltBoard.LEFT, RIGHT, UP or DOWN), or -1.
func feed(gravity: Vector3) -> int:
	if gravity.length() < WEAK:
		return -1
	var now: Vector3 = gravity.normalized()
	if _rest == Vector3.ZERO:
		_rest = now
		_armed = true
		return -1
	var side: float = _roll(now) - _roll(_rest)
	var ahead: float = wrapf(_pitch(now) - _pitch(_rest), -180.0, 180.0)
	var reach: float = maxf(absf(side), absf(ahead))
	if not _armed:
		if reach < REARM:
			_armed = true
		return -1
	if reach < REARM:
		_rest = _rest.lerp(now, SETTLE).normalized()
		return -1
	if reach < FIRE:
		return -1
	_armed = false
	if absf(side) > absf(ahead):
		return TiltBoard.RIGHT if side > 0.0 else TiltBoard.LEFT
	return TiltBoard.UP if ahead > 0.0 else TiltBoard.DOWN

## How far the right edge is below the left, in degrees.
static func _roll(g: Vector3) -> float:
	return rad_to_deg(asin(clampf(g.x, -1.0, 1.0)))

## How far back from upright the phone is held, in degrees: 0 upright, 90 lying on its back.
static func _pitch(g: Vector3) -> float:
	return rad_to_deg(atan2(-g.z, -g.y))
