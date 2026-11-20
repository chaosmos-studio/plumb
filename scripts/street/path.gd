class_name StreetPath
extends RefCounted

## Where the road runs and where everything stands beside it, as pure functions of `s`, so the map, the ground shader
## and the tests agree (MATH.md section 25). `s` runs along the street from its start and `x` across it from the middle
## of the screen, in design pixels. The ground shader takes the same sway constants as uniforms.

## Doors, one a level, alternating sides of the road.
const FIRST_DOOR: float = 300.0
const DOOR_GAP: float = 230.0
const ROAD_HALF: float = 64.0
## How far a house's middle stands from the road's edge.
const HOUSE_SET: float = 128.0
## The road's sway: two sines of different lengths, so the bends never repeat in a way the eye catches.
const SWAY_A: float = 115.0
const SWAY_A_LENGTH: float = 1730.0
const SWAY_B: float = 40.0
const SWAY_B_LENGTH: float = 610.0
const SWAY_B_PHASE: float = 1.3

## Scenery stands in slots this far apart along each side, and keeps this far along from a door on its side.
const SLOT_GAP: float = 88.0
const DOOR_CLEAR: float = 120.0
## Lamps stand at the road's edge, everything else this far out from the road's middle.
const LAMP_SET: float = 26.0
const SCENERY_SET: Vector2 = Vector2(250.0, 470.0)

enum Kind { NONE, TREE, BUSH, LAMP, FENCE, FLOWERS }
## Out of 100: how often a slot holds each kind, in Kind's order after NONE. The rest stay empty.
const SHARE: PackedInt32Array = [22, 20, 9, 10, 16]

static func road_x(s: float) -> float:
	return SWAY_A * sin(TAU * s / SWAY_A_LENGTH) + SWAY_B * sin(TAU * s / SWAY_B_LENGTH + SWAY_B_PHASE)

## Door `n` counts from 1.
static func door_s(n: int) -> float:
	return FIRST_DOOR + float(n - 1) * DOOR_GAP

static func door_side(n: int) -> int:
	return 1 if n % 2 == 1 else -1

static func door_x(n: int) -> float:
	return road_x(door_s(n)) + float(door_side(n)) * (ROAD_HALF + HOUSE_SET)

## The door nearest `s`, never before door 1.
static func door_near(s: float) -> int:
	return maxi(1, roundi((s - FIRST_DOOR) / DOOR_GAP) + 1)

static func slot_s(slot: int) -> float:
	return float(slot) * SLOT_GAP

## Scenery slot `slot` on `side` (-1 or 1): its kind, and its x. Fixed for the slot, from a small integer hash, so the
## street looks the same each time it scrolls past.
static func scenery(slot: int, side: int) -> Vector2:
	var s: float = slot_s(slot)
	var door: int = door_near(s)
	if door_side(door) == side and absf(door_s(door) - s) < DOOR_CLEAR:
		return Vector2(Kind.NONE, 0.0)
	var h: int = mix(slot * 2 + (1 if side > 0 else 0))
	var roll: int = h % 100
	var kind: int = Kind.NONE
	var upto: int = 0
	for k: int in range(SHARE.size()):
		upto += SHARE[k]
		if roll < upto:
			kind = k + 1
			break
	if kind == Kind.NONE:
		return Vector2(Kind.NONE, 0.0)
	var out: float = ROAD_HALF + LAMP_SET if kind == Kind.LAMP else \
		lerpf(SCENERY_SET.x, SCENERY_SET.y, float((h >> 8) % 1000) / 1000.0)
	return Vector2(kind, road_x(s) + float(side) * out)

## A 32-bit integer hash (the "lowbias32" mix): close inputs give unrelated outputs.
static func mix(value: int) -> int:
	var h: int = value & 0xFFFFFFFF
	h ^= h >> 16
	h = (h * 0x7feb352d) & 0xFFFFFFFF
	h ^= h >> 15
	h = (h * 0x846ca68b) & 0xFFFFFFFF
	h ^= h >> 16
	return h
