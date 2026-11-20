class_name StreetProp
extends Node2D

## One upright thing on the street, its base at the origin and drawn at its near-edge size from the street's atlas
## (StreetArt): the map scales it by depth. A house carries its door: its number, and whether it is far off, locked,
## open but not yet solved (one a player skipped), the one to play next or solved.

enum Door { FAR, LOCKED, OPEN, CURRENT, SOLVED }

const HOUSE: int = -1
const INK: Color = Color("fff3df")
## A house's size at the near edge beside its painting (StreetArt), and its number's height as a share of its door's
## radius. The houses are as big as Codex's street paste-up, so the current door nearly fills the screen's width.
const HOUSE_SCALE: float = 1.3
const NUMBER_HEIGHT: float = 0.95
## A side house, filling the screen's edges, at this size beside a door's house.
const SIDE_HOUSE_SCALE: float = 1.15
## Scenery's size beside the houses, as Codex painted each at its own canvas.
const SCENERY_SCALE: Dictionary = {
	StreetPath.Kind.TREE: 1.15,
	StreetPath.Kind.BUSH: 1.15,
	StreetPath.Kind.LAMP: 1.2,
	StreetPath.Kind.FENCE: 1.05,
	StreetPath.Kind.FLOWERS: 1.1,
	StreetPath.Kind.BUNTING: 1.15,
	StreetPath.Kind.SIDE_HOUSE: SIDE_HOUSE_SCALE,
}
## The dressing at a door's house's feet: a flowerbed or a bush at each corner, as in the concepts.
const FOOT_SCALE: float = 0.95
## And the trees and big bushes behind it.
const BEHIND_TREE: float = 1.25
const BEHIND_BUSH: float = 1.0
## The breeze: how far each kind leans, in radians, and how fast it sways.
const SWAY: Dictionary = {
	StreetPath.Kind.TREE: 0.03,
	StreetPath.Kind.BUSH: 0.02,
	StreetPath.Kind.FLOWERS: 0.045,
}
const SWAY_SPEED: float = 1.2
## A solved door's plaque, as a multiple of the door's radius.
const PLAQUE_WIDTH: float = 1.6
## The current door's glow breathes this much, this fast.
const PULSE: float = 0.06
const PULSE_SPEED: float = 3.6
## A contact shadow's width as a share of what stands on it.
const SHADOW_SHARE: float = 1.05

var kind: int = StreetPath.Kind.NONE
## A house's number, or a scenery piece's variety.
var door: int = 0
var state: Door = Door.FAR
var stars: int = 0
var pulse: float = 0.0
## Its tap wobble (Jiggle), made on its first tap and kept while it is recycled.
var jiggle: Jiggle

func dress_house(number: int, door_state: Door, earned: int) -> void:
	kind = HOUSE
	door = number
	state = door_state
	stars = earned
	_still()
	queue_redraw()

func dress_scenery(scenery_kind: int, variety: int) -> void:
	kind = scenery_kind
	door = variety
	_still()
	queue_redraw()

func _still() -> void:
	rotation = 0.0
	if jiggle != null:
		jiggle.s = 0.0
		jiggle.v = 0.0

## A tap: it wobbles. Answers whether it is now moving, so the map can step it.
func kick(strength: float = 1.0) -> bool:
	if Save.reduce_motion:
		return false
	if jiggle == null:
		jiggle = Jiggle.new()
	jiggle.kick(strength)
	return true

## The wobble's scale and rock, to multiply into the depth scale the map sets.
func wobble_scale() -> Vector2:
	return jiggle.squash() if jiggle != null else Vector2.ONE

func wobble_turn() -> float:
	return jiggle.tilt() if jiggle != null else 0.0

## Whether it is tall enough to hide the road and the cast when it stands near the screen's foot.
func tall() -> bool:
	return kind == HOUSE or kind == StreetPath.Kind.SIDE_HOUSE

## Its idle lean in the breeze at time `t`: trees, bushes and flowers sway, each in its own time, and nothing else.
func sway(t: float) -> float:
	var reach: float = SWAY.get(kind, 0.0)
	if reach == 0.0:
		return 0.0
	var phase: float = float(StreetPath.mix(door * 17 + kind) % 1000) / 1000.0 * TAU
	return reach * sin(t * SWAY_SPEED * (0.85 + 0.3 * phase / TAU) + phase)

## The piece's outline on screen at near-edge size, for taps.
func bounds() -> Rect2:
	var piece: String = _piece()
	var k: float = HOUSE_SCALE if kind == HOUSE else SCENERY_SCALE.get(kind, 0.7)
	var s: Vector2 = StreetArt.size(piece) * k
	return Rect2(Vector2(-s.x * 0.5, -s.y), s)

func _piece() -> String:
	if kind == HOUSE:
		return StreetArt.house_of(door)
	match kind:
		StreetPath.Kind.TREE:
			return "tree_%d" % (1 + door % 3)
		StreetPath.Kind.BUSH:
			return ("bush_%d" % (1 + door % 3)) if door % 5 < 3 else ("bush_big_%d" % (1 + door % 2))
		StreetPath.Kind.LAMP:
			return "lamp_post"
		StreetPath.Kind.FENCE:
			return "fence_long" if door % 3 != 0 else "fence"
		StreetPath.Kind.FLOWERS:
			return "flowerbed_%d" % (1 + door % 3)
		StreetPath.Kind.BUNTING:
			return "bunting_posts"
		StreetPath.Kind.SIDE_HOUSE:
			return "house_%s_%d" % [StreetArt.COLOURS[door % 4], 1 + (door >> 2) % StreetArt.SHAPES]
	return "planter"

func _draw() -> void:
	if kind == StreetPath.Kind.NONE:
		return
	if kind == StreetPath.Kind.SIDE_HOUSE:
		_side_house()
		return
	if kind != HOUSE:
		var scale_k: float = SCENERY_SCALE.get(kind, 0.7)
		var width: float = StreetArt.size(_piece()).x * scale_k
		StreetArt.draw(self, "shadow", Vector2.ZERO, width * SHADOW_SHARE / StreetArt.size("shadow").x)
		StreetArt.draw(self, _piece(), Vector2.ZERO, scale_k)
		return
	_house()

## A house with no door to play: it fills the street's edges, its door shut, flowers at its feet.
func _side_house() -> void:
	var house: String = _piece()
	var k: float = SIDE_HOUSE_SCALE
	var d: Vector3 = StreetArt.door(house) * k
	_behind(house, k)
	StreetArt.draw(self, "shadow", Vector2.ZERO, StreetArt.size(house).x * k * SHADOW_SHARE / StreetArt.size("shadow").x)
	StreetArt.draw(self, house, Vector2.ZERO, k)
	StreetArt.draw(self, "door_" + StreetArt.COLOURS[door % 4], Vector2(d.x, d.y), k)
	_feet(house, k)

## Greenery growing up behind a house, as in every concept: a tree or a big bush at one or both back corners.
func _behind(house: String, k: float) -> void:
	var size: Vector2 = StreetArt.size(house) * k
	for side: int in [-1, 1]:
		var pick: int = StreetPath.mix(door * 5 + side + 23) % 6
		if pick == 5:
			continue
		var piece: String = ("tree_%d" % (1 + pick % 3)) if pick < 3 else ("bush_big_%d" % (1 + pick % 2))
		var reach: float = BEHIND_TREE if pick < 3 else BEHIND_BUSH
		StreetArt.draw(self, piece, Vector2(side * size.x * 0.4, -size.y * 0.12), reach * k / HOUSE_SCALE)

## A flowerbed or a bush at each front corner of a house, chosen by its number.
func _feet(house: String, k: float) -> void:
	var half: float = StreetArt.size(house).x * k * 0.42
	for side: int in [-1, 1]:
		var pick: int = StreetPath.mix(door * 7 + side + 11) % 5
		var piece: String = ("flowerbed_%d" % (1 + pick % 3)) if pick < 3 else ("bush_%d" % (1 + pick % 3))
		StreetArt.draw(self, piece, Vector2(side * half, 6.0), FOOT_SCALE * k / HOUSE_SCALE)

## Everything, the number's digits too, comes from the atlas, so a whole street of houses batches into a few runs.
func _house() -> void:
	var house: String = _piece()
	var colour: String = StreetArt.COLOURS[StreetArt.colour_of(door)]
	var k: float = HOUSE_SCALE
	var d: Vector3 = StreetArt.door(house) * k
	var centre: Vector2 = Vector2(d.x, d.y)
	_behind(house, k)
	StreetArt.draw(self, "shadow", Vector2.ZERO, StreetArt.size(house).x * k * SHADOW_SHARE / StreetArt.size("shadow").x)
	StreetArt.draw(self, house, Vector2.ZERO, k)
	_feet(house, k)
	if state == Door.CURRENT:
		StreetArt.draw(self, "glow", centre, k * (1.0 + PULSE * sin(pulse * PULSE_SPEED)))
	# The door to play next wears a gold ring, whatever its house's colour, as door 12 in the concept.
	StreetArt.draw(self, "door_yellow" if state == Door.CURRENT else "door_" + colour, centre, k)
	if state == Door.SOLVED:
		for w: Rect2 in StreetArt.windows(house):
			StreetArt.draw(self, "window_lit", w.get_center() * k, k)
		var plaque: Vector2 = centre + Vector2(0, d.z * 0.78)
		var plaque_w: float = d.z * PLAQUE_WIDTH
		StreetArt.draw(self, "plaque", plaque, plaque_w / StreetArt.size("plaque").x)
		var star_w: float = plaque_w * 0.25
		for i: int in range(3):
			StreetArt.draw(self, "star" if i < stars else "star_dim", plaque + Vector2((i - 1) * star_w * 1.02, -1.0),
				star_w / StreetArt.size("star").x)
	if state == Door.FAR:
		StreetArt.draw(self, "padlock", centre + Vector2(0, 4), k * 0.9)
		return
	# A door with a parcel waiting (every 5th) shows it under its number until it is solved, as door 15 in the concept.
	var gift: bool = door % 5 == 0 and state != Door.SOLVED
	var lift: float = -d.z * (0.32 if gift else 0.2) if state == Door.SOLVED or gift else 0.0
	var digits: int = str(door).length()
	var height: float = d.z * NUMBER_HEIGHT * (1.0 if digits < 3 else 0.78) * (0.74 if gift else 1.0)
	StreetArt.draw_number(self, door, centre + Vector2(0.0, lift), height)
	if gift:
		var box: float = d.z * 0.8 / StreetArt.size("parcel_body").x
		StreetArt.draw(self, "parcel_body", centre + Vector2(0.0, d.z * 0.62), box)
		StreetArt.draw(self, "parcel_lid", centre + Vector2(0.0, d.z * 0.12), box)
		StreetArt.draw(self, "parcel_bow", centre + Vector2(0.0, d.z * 0.02), box)
