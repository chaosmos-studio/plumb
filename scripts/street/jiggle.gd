class_name Jiggle
extends RefCounted

## The wobble a tap gives anything in Street, as Candy Crush's pieces wobble (MATH.md section 27): a squash and
## stretch on a damped spring. `s` is the squash: positive is wider and shorter. The width is 1 + s and the height
## 1 / (1 + s), so the area stays the same through the whole wobble. A small tilt follows the squash's speed, a
## quarter turn out of step with it, so the piece rocks as it bounces. Pure arithmetic: a thing that wobbles keeps
## one of these and calls `step` each frame until it rests.

## The spring: how hard it pulls back, and how quickly it calms. Stiffer is quicker and snappier, more damping
## settles sooner with less overshoot. These two give about 2.8 wobbles a second, settled in about half a second,
## each bounce a fifth of the one before.
const STIFFNESS: float = 400.0
const DAMPING: float = 18.0
## A tap's push: the squash's speed at the start, in widths a second. Its first squash is about an eighth.
const KICK: float = 4.0
## Radians of tilt for each unit of squash speed: about 3 degrees at the most.
const TILT: float = 0.015
## Below these it is at rest.
const REST_S: float = 0.003
const REST_V: float = 0.05
## Frames are stepped in slices no longer than this, so a slow frame never throws the spring off.
const MAX_STEP: float = 1.0 / 120.0

var s: float = 0.0
var v: float = 0.0

## A tap: `strength` 1 is the usual push, and a direction sign (-1) stretches first instead of squashing.
func kick(strength: float = 1.0) -> void:
	v += KICK * strength

func moving() -> bool:
	return absf(s) > REST_S or absf(v) > REST_V

## Advances the spring by `dt` seconds and answers whether it is still moving. At rest it settles exactly to zero.
func step(dt: float) -> bool:
	var left: float = dt
	while left > 0.0:
		var h: float = minf(left, MAX_STEP)
		v += (-STIFFNESS * s - DAMPING * v) * h
		s += v * h
		left -= h
	if not moving():
		s = 0.0
		v = 0.0
		return false
	return true

## The scale to draw with: wider and shorter, or narrower and taller, the area unchanged.
func squash() -> Vector2:
	var w: float = maxf(1.0 + s, 0.2)
	return Vector2(w, 1.0 / w)

func tilt() -> float:
	return v * TILT
