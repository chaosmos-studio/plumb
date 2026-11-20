class_name StreetPath
extends RefCounted

## Where the road runs and where everything stands beside it, as pure functions of `s`, so the map, the ground shader
## and the tests agree (MATH.md section 25). `s` runs along the street from its start and `x` across it from the middle
## of the screen, in design pixels. The ground shader takes the same sway constants as uniforms.

## Doors, one a level, as in the concept (build/review/revamp2/1-map.png): houses left and right of the screen's
## middle in turn, two or three on a phone at once, and a road that winds from door to door, passing just in front of
## each one where the cast waits.
const FIRST_DOOR: float = 360.0
const DOOR_GAP: float = 310.0
const ROAD_HALF: float = 100.0
## How far a door's house stands from the street's middle, left and right in turn.
const DOOR_X: float = 150.0
## The road reaches its widest swing this far in front of each door, toward that door's side.
const FRONT: float = 120.0
## The road's sway: the big swing, one bend each door so it passes before every one, and a slow drift of a second
## sine of another length, so the bends never repeat in a way the eye catches.
const SWAY_A: float = 140.0
const SWAY_A_LENGTH: float = DOOR_GAP * 2.0
const SWAY_A_PHASE: float = PI * (FRONT - FIRST_DOOR) / DOOR_GAP + PI * 0.5
const SWAY_B: float = 26.0
const SWAY_B_LENGTH: float = 1900.0
const SWAY_B_PHASE: float = 1.3

## Scenery stands in slots this far apart along each side, and keeps this far along from a door on its side (side
## houses, being big, keep further).
const SLOT_GAP: float = 120.0
const DOOR_CLEAR: float = 170.0
const SIDE_HOUSE_CLEAR: float = 300.0
## Lamps stand at the road's edge, everything else this far out from the road's middle.
const LAMP_SET: float = 30.0
const SCENERY_SET: Vector2 = Vector2(340.0, 620.0)

enum Kind { NONE, TREE, BUSH, LAMP, FENCE, FLOWERS, BUNTING, SIDE_HOUSE }
## Out of 100: how often a slot holds each kind, in Kind's order after NONE. The rest stay empty, so clear grass shows
## between things (Shravan, 20 November: the path and the houses lead, dressing sits sparsely in the gaps). Each slot
## has two rows: the road's edge (flowers, bushes, lamps, bunting) and behind it (trees, big bushes, fences,
## neighbours' houses at the screen's edges).
const SHARE: PackedInt32Array = [0, 9, 6, 0, 14, 3, 0]
const BACK_SHARE: PackedInt32Array = [16, 8, 0, 4, 0, 0, 8]
## How far out from the road's middle each kind stands, as a range: lamps, bunting and flowerbeds line the road's
## edge, trees, bushes and fences stand back, and side houses fill the far edges of the screen.
const SET: Dictionary = {
	Kind.TREE: Vector2(300.0, 480.0),
	Kind.BUSH: Vector2(160.0, 250.0),
	Kind.LAMP: Vector2(140.0, 150.0),
	Kind.FENCE: Vector2(280.0, 400.0),
	Kind.FLOWERS: Vector2(150.0, 250.0),
	Kind.BUNTING: Vector2(190.0, 220.0),
	Kind.SIDE_HOUSE: Vector2(420.0, 470.0),
}
## A bush in the back row stands this much further out than one at the road's edge.
const BACK_BUSH: float = 160.0
## The clear ground in front of a door's house: this far before it along the street, this far behind, and this far
## either side of its middle.
const DOOR_FRONT: float = 240.0
const DOOR_BEHIND: float = 10.0
const DOOR_HALF: float = 170.0

## The road's middle at `s`. Its big swing is a cosine one door long each way, peaking FRONT before each door on
## that door's side.
static func road_x(s: float) -> float:
	return SWAY_A * sin(TAU * s / SWAY_A_LENGTH + SWAY_A_PHASE) + SWAY_B * sin(TAU * s / SWAY_B_LENGTH + SWAY_B_PHASE)

## How steeply the road runs across at `s`, x per s, so its width can be measured square to it.
static func road_slope(s: float) -> float:
	return SWAY_A * TAU / SWAY_A_LENGTH * cos(TAU * s / SWAY_A_LENGTH + SWAY_A_PHASE) \
		+ SWAY_B * TAU / SWAY_B_LENGTH * cos(TAU * s / SWAY_B_LENGTH + SWAY_B_PHASE)

## Door `n` counts from 1.
static func door_s(n: int) -> float:
	return FIRST_DOOR + float(n - 1) * DOOR_GAP

static func door_side(n: int) -> int:
	return 1 if n % 2 == 1 else -1

static func door_x(n: int) -> float:
	return float(door_side(n)) * DOOR_X

## The door nearest `s`, never before door 1.
static func door_near(s: float) -> int:
	return maxi(1, roundi((s - FIRST_DOOR) / DOOR_GAP) + 1)

static func slot_s(slot: int) -> float:
	return float(slot) * SLOT_GAP

## Scenery slot `slot` on `side` (-1 or 1): its kind, and its x. Fixed for the slot, from a small integer hash, so the
## street looks the same each time it scrolls past.
static func scenery(slot: int, side: int, back: bool = false) -> Vector2:
	var s: float = slot_s(slot)
	var door: int = door_near(s)
	if door_side(door) == side and absf(door_s(door) - s) < DOOR_CLEAR:
		return Vector2(Kind.NONE, 0.0)
	var h: int = mix(slot * 2 + (1 if side > 0 else 0) + (7919 if back else 0))
	var roll: int = h % 100
	var kind: int = Kind.NONE
	var upto: int = 0
	var shares: PackedInt32Array = BACK_SHARE if back else SHARE
	for k: int in range(shares.size()):
		upto += shares[k]
		if roll < upto:
			kind = k + 1
			break
	if kind == Kind.NONE:
		return Vector2(Kind.NONE, 0.0)
	if kind == Kind.SIDE_HOUSE:
		for n: int in [door - 1, door, door + 1]:
			if n >= 1 and door_side(n) == side and absf(door_s(n) - s) < SIDE_HOUSE_CLEAR:
				return Vector2(Kind.NONE, 0.0)
	var band: Vector2 = SET[kind]
	var out: float = lerpf(band.x, band.y, float((h >> 8) % 1000) / 1000.0) + (BACK_BUSH if back and kind == Kind.BUSH else 0.0)
	var x: float = road_x(s) + float(side) * out
	# Nothing taller than a flowerbed stands in front of a door's house, where the road swings close and the cast
	# waits, so the door and its number always show.
	if kind != Kind.FLOWERS:
		for n: int in [door, door + 1]:
			var ahead: float = door_s(n) - s
			if ahead > -DOOR_BEHIND and ahead < DOOR_FRONT and absf(x - door_x(n)) < DOOR_HALF:
				return Vector2(Kind.NONE, 0.0)
	return Vector2(kind, x)

## The meadow a wide screen shows beyond SCENERY_SET: in band `band` (1, 2, ...) a slot may hold a tree or a bush,
## FAR_BAND further out each band, so a wide street fills to its edges. Its kind (Kind.NONE for an empty spot) and x.
const FAR_BAND: float = 300.0
const FAR_SHARE: int = 20

static func far_scenery(slot: int, side: int, band: int) -> Vector2:
	var h: int = mix(slot * 31 + band * 7 + (1 if side > 0 else 0) + 5)
	if h % 100 >= FAR_SHARE:
		return Vector2(Kind.NONE, 0.0)
	var kind: int = Kind.TREE if (h >> 4) % 2 == 0 else Kind.BUSH
	var inner: float = SCENERY_SET.y + FAR_BAND * float(band - 1) + 60.0
	var out: float = inner + float((h >> 9) % 1000) / 1000.0 * (FAR_BAND - 60.0)
	return Vector2(kind, road_x(slot_s(slot)) + float(side) * out)

## A 32-bit integer hash (the "lowbias32" mix): close inputs give unrelated outputs.
static func mix(value: int) -> int:
	var h: int = value & 0xFFFFFFFF
	h ^= h >> 16
	h = (h * 0x7feb352d) & 0xFFFFFFFF
	h ^= h >> 15
	h = (h * 0x846ca68b) & 0xFFFFFFFF
	h ^= h >> 16
	return h
