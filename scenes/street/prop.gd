class_name StreetProp
extends Node2D

## One upright thing on the street, its base at the origin and drawn at its near-edge size from the street's atlas
## (StreetAtlas): the map scales it by depth. A house carries its door: its number, and whether it is far off, locked,
## the one to play next or solved.

enum Door { FAR, LOCKED, CURRENT, SOLVED }

const INK: Color = Color("fff6e8")
## The door number's size, and the font it is drawn in: one drawn as a signed distance field, so it stays sharp at
## every scale the map draws it at.
const NUMBER_SIZE: int = 54
const HOUSE: int = -1

static var _font: FontFile

var kind: int = StreetPath.Kind.NONE
## A house's number, or a scenery piece's variety.
var door: int = 0
var state: Door = Door.FAR
var stars: int = 0

static func number_font() -> FontFile:
	if _font == null:
		_font = (load(Brand.FONT_UI) as FontFile).duplicate() as FontFile
		_font.multichannel_signed_distance_field = true
		_font.msdf_pixel_range = 14
		_font.msdf_size = 64
	return _font

func dress_house(number: int, door_state: Door, earned: int) -> void:
	kind = HOUSE
	door = number
	state = door_state
	stars = earned
	queue_redraw()

func dress_scenery(scenery_kind: int, variety: int) -> void:
	kind = scenery_kind
	door = variety
	queue_redraw()

func _draw() -> void:
	if kind == HOUSE:
		_house()
		return
	match kind:
		StreetPath.Kind.TREE:
			StreetAtlas.draw(self, "tree_%d" % (door % 2), Vector2.ZERO)
		StreetPath.Kind.BUSH:
			StreetAtlas.draw(self, "bush_%d" % (door % 2), Vector2.ZERO)
		StreetPath.Kind.LAMP:
			StreetAtlas.draw(self, "lamp", Vector2.ZERO)
		StreetPath.Kind.FENCE:
			StreetAtlas.draw(self, "fence", Vector2.ZERO)
		StreetPath.Kind.FLOWERS:
			StreetAtlas.draw(self, "flowers_%d" % (door % 2), Vector2.ZERO)

## Every atlas piece first and the number last, so a house costs the renderer two runs, not one per piece.
func _house() -> void:
	if state == Door.CURRENT:
		StreetAtlas.draw(self, "glow", StreetPieces.DOOR_CENTRE)
	StreetAtlas.draw(self, "house_%d" % (door % StreetPieces.ROOFS.size()), Vector2.ZERO)
	if state == Door.SOLVED:
		for i: int in range(mini(stars, StreetPieces.WINDOWS.size())):
			StreetAtlas.draw(self, "window_lit", StreetPieces.WINDOWS[i])
		for i: int in range(3):
			StreetAtlas.draw(self, "star_on" if i < stars else "star_off",
				StreetPieces.DOOR_CENTRE + Vector2((i - 1) * 24.0, 36.0))
	if state == Door.FAR:
		StreetAtlas.draw(self, "padlock", StreetPieces.DOOR_CENTRE + Vector2(0, 4))
		return
	var r: float = StreetPieces.DOOR_R
	draw_string(number_font(), StreetPieces.DOOR_CENTRE + Vector2(-r, NUMBER_SIZE * 0.36), str(door),
		HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, NUMBER_SIZE, INK)
