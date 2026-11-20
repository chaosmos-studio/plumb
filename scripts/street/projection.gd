class_name StreetProjection
extends RefCounted

## The rolling street (MATH.md section 25). The street is a strip on the ground: `s` runs along it away from the
## player and `x` across it from the middle of the screen, both in design pixels. The strip lies over a drum of radius
## `radius`, so scrolling turns the drum toward the player. Everything here takes `s_rel`, a point's `s` less the
## scroll: 0 is the near edge.
##
## A point at angle t = s_rel / R over the drum shows at height near_y - R sin t, at depth R (1 - cos t) + tilt s_rel,
## where it is drawn at scale k = gain F / (F + depth), across at mid_x + x k, sinking by bow (x k)² toward the sides.
## The horizon is t = π/2, R pixels above the near edge. A very large R and no tilt flatten it all into a plain scroll.

## How far past the horizon a prop is still placed, as an angle: a tall one rises over the crest before its base shows.
const BEYOND: float = 0.4
## The steepest angle a finger can hold: past it the drum turns too fast under the finger.
const GRAB_LIMIT: float = 1.25
## Room below the screen's foot and above its top, in pixels, so tall props near the edges never pop.
const MARGIN: float = 360.0

var radius: float
var focal: float
var near_y: float
var mid_x: float
var bow: float
## A camera tilted down at the street adds depth in step with the distance along it, so things shrink steadily up the
## screen as in the concepts, not only near the horizon: depth gains `tilt` pixels for each pixel along. 0 is the bare
## drum.
var tilt: float = 0.0
## Every scale is multiplied by this, so a chosen point (the door at rest) can be drawn at its painted size.
var gain: float = 1.0

func _init(radius_px: float, focal_px: float, near_edge_y: float, middle_x: float, bow_per_px: float) -> void:
	radius = radius_px
	focal = focal_px
	near_y = near_edge_y
	mid_x = middle_x
	bow = bow_per_px

func angle(s_rel: float) -> float:
	return s_rel / radius

func scale_at(t: float) -> float:
	return gain * focal / (focal + radius * (1.0 - cos(t)) + tilt * radius * maxf(t, 0.0))

## Sets `gain` so the point `s_rel` along is drawn at scale 1.
func normalise_at(s_rel: float) -> void:
	gain = 1.0
	gain = 1.0 / scale_at(s_rel / radius)

func horizon_y() -> float:
	return near_y - radius

## Screen x, screen y and scale of the strip's point `s_rel` along and `x` across.
func place(s_rel: float, x: float) -> Vector3:
	var t: float = s_rel / radius
	var k: float = scale_at(t)
	var across: float = x * k
	return Vector3(mid_x + across, near_y - radius * sin(t) + bow * across * across, k)

## Whether a point at `s_rel` is past the crest, where the ground hides its foot.
func behind_crest(s_rel: float) -> bool:
	return s_rel / radius > PI * 0.5

## The `s_rel` on the centre line at screen height `y`, held at GRAB_LIMIT near the horizon.
func s_rel_at(y: float) -> float:
	var v: float = clampf((near_y - y) / radius, -1.0, sin(GRAB_LIMIT))
	return radius * asin(v)

## The nearest `s_rel` worth placing anything at, for a screen whose foot is at `bottom`.
func near_s_rel(bottom: float) -> float:
	return radius * asin(clampf((near_y - bottom - MARGIN) / radius, -1.0, 1.0))

## The farthest: just past the horizon, or the top of the screen when the drum is so flat its horizon is above it.
func far_s_rel(top: float) -> float:
	var reach: float = (near_y - top + MARGIN) / radius
	if reach >= 1.0:
		return radius * (PI * 0.5 + BEYOND)
	return radius * asin(maxf(reach, -1.0))
