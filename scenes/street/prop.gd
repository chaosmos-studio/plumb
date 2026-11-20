class_name StreetProp
extends Node2D

## One upright thing on the street, its base at the origin and drawn at its near-edge size from the street's atlas
## (StreetArt): the map scales it by depth. A house carries its door: its number, and whether it is far off, locked,
## open but not yet solved (one a player skipped), the one to play next or solved.

enum Door { FAR, LOCKED, OPEN, CURRENT, SOLVED }

const HOUSE: int = -1
const INK: Color = Color("fff3df")
## A house's size at the near edge beside its painting (StreetArt), and its number's size there.
const HOUSE_SCALE: float = 1.12
const NUMBER_SIZE: int = 112
## Scenery's size beside the houses, as Codex painted each at its own canvas.
const SCENERY_SCALE: Dictionary = {
	StreetPath.Kind.TREE: 1.05,
	StreetPath.Kind.BUSH: 0.78,
	StreetPath.Kind.LAMP: 0.86,
	StreetPath.Kind.FENCE: 0.8,
	StreetPath.Kind.FLOWERS: 0.72,
}
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

func dress_house(number: int, door_state: Door, earned: int) -> void:
	kind = HOUSE
	door = number
	state = door_state
	stars = earned
	rotation = 0.0
	queue_redraw()

func dress_scenery(scenery_kind: int, variety: int) -> void:
	kind = scenery_kind
	door = variety
	rotation = 0.0
	queue_redraw()

## The piece's outline on screen at near-edge size, for taps.
func bounds() -> Rect2:
	var piece: String = _piece()
	var s: Vector2 = StreetArt.size(piece) * (HOUSE_SCALE if kind == HOUSE else SCENERY_SCALE.get(kind, 0.7))
	return Rect2(Vector2(-s.x * 0.5, -s.y), s)

func _piece() -> String:
	if kind == HOUSE:
		return StreetArt.house_of(door)
	match kind:
		StreetPath.Kind.TREE:
			return "tree_%d" % (1 + door % 3)
		StreetPath.Kind.BUSH:
			return "bush_%d" % (1 + door % 3)
		StreetPath.Kind.LAMP:
			return "lamp_post"
		StreetPath.Kind.FENCE:
			return "fence"
	return "planter"

func _draw() -> void:
	if kind == StreetPath.Kind.NONE:
		return
	if kind != HOUSE:
		var scale_k: float = SCENERY_SCALE.get(kind, 0.7)
		var width: float = StreetArt.size(_piece()).x * scale_k
		StreetArt.draw(self, "shadow", Vector2.ZERO, width * SHADOW_SHARE / StreetArt.size("shadow").x)
		StreetArt.draw(self, _piece(), Vector2.ZERO, scale_k)
		return
	_house()

## Every atlas piece first and the number last, so a house costs the renderer two runs, not one per piece.
func _house() -> void:
	var house: String = _piece()
	var colour: String = StreetArt.COLOURS[StreetArt.colour_of(door)]
	var k: float = HOUSE_SCALE
	var d: Vector3 = StreetArt.door(house) * k
	var centre: Vector2 = Vector2(d.x, d.y)
	StreetArt.draw(self, "shadow", Vector2.ZERO, StreetArt.size(house).x * k * SHADOW_SHARE / StreetArt.size("shadow").x)
	StreetArt.draw(self, house, Vector2.ZERO, k)
	if state == Door.CURRENT:
		StreetArt.draw(self, "glow", centre, k * (1.0 + PULSE * sin(pulse * PULSE_SPEED)))
	StreetArt.draw(self, "door_" + colour, centre, k)
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
	var font: Font = StreetArt.number_font()
	var text: String = str(door)
	var size: int = NUMBER_SIZE if text.length() < 3 else roundi(NUMBER_SIZE * 0.8)
	var lift: float = -d.z * 0.16 if state == Door.SOLVED else 0.0
	draw_string(font, centre + Vector2(-d.z, size * 0.36 + lift), text, HORIZONTAL_ALIGNMENT_CENTER, d.z * 2.0, size, INK)
