class_name StreetProp
extends Node2D

## One upright thing on the street, its base at the origin and drawn at its near-edge size from the street's atlas
## (StreetArt): the map scales it by depth. A house carries its door: its number, and whether it is far off, locked,
## open but not yet solved (one a player skipped), the one to play next or solved.

enum Door { FAR, LOCKED, OPEN, CURRENT, SOLVED }

const HOUSE: int = -1
const INK: Color = Color("fff3df")
## A house's size beside its painting (StreetArt), and its number's height as a share of its door's radius. Two or
## three houses show on a phone with the road between them (Shravan, 20 November), a little smaller than the first
## 1.12 so the doors breathe (21 November).
const HOUSE_SCALE: float = 0.98
const NUMBER_HEIGHT: float = 0.95
## A neighbour's house at the street's edges, at this size beside its painting.
const SIDE_HOUSE_SCALE: float = 0.79
## Scenery's size beside the houses, as Codex painted each at its own canvas.
const SCENERY_SCALE: Dictionary = {
	StreetPath.Kind.TREE: 0.95,
	StreetPath.Kind.BUSH: 0.85,
	StreetPath.Kind.LAMP: 0.95,
	StreetPath.Kind.FENCE: 0.85,
	StreetPath.Kind.FLOWERS: 0.85,
	StreetPath.Kind.BUNTING: 0.9,
	StreetPath.Kind.SIDE_HOUSE: SIDE_HOUSE_SCALE,
}
## The dressing at a door's house's feet: a flowerbed or a bush at each corner, as in the concepts.
const FOOT_SCALE: float = 0.8
## And the trees and big bushes behind it.
const BEHIND_TREE: float = 1.0
const BEHIND_BUSH: float = 0.85
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
## The finish ribbon before a milestone's plot, which the map places as a piece of its own.
const RIBBON: int = -2
## Its width, as a share of the plot's.
const RIBBON_SPAN: float = 0.86
## A milestone door (StreetRewards): before its family moves in, an empty plot with a sign carrying its number; after,
## the family's house (StreetFamilies), drawn this size beside a door's house, its "sold" sign beside it and the family
## in front, this size beside the cast.
const MILESTONE_SCALE: float = 0.88
const PLOT_SCALE: float = 0.9
const SIGN_SCALE: float = 1.25
const FOLK_SCALE: float = 0.72
## The plot sign's board: its middle above the sign's foot, and the number's height on it, in the sign's pixels.
const SIGN_BOARD: Vector2 = Vector2(0.0, -158.0)
const SIGN_NUMBER: float = 54.0
## A family's house stands on its plot's stone platform, this far above the plot's foot, in the plot's pixels.
const PLATFORM: float = 152.0
## The windmill's sails turn this fast, in radians a second.
const SAIL_SPIN: float = 0.6
## The golden knocker on a door won at par: its width and its drop below the door's middle, as shares of the door's
## radius, and how far the number above it shrinks and rises.
const KNOCKER_WIDTH: float = 0.52
const KNOCKER_DROP: float = 0.3
const KNOCKER_NUMBER: float = 0.8
const KNOCKER_LIFT: float = 0.3

var kind: int = StreetPath.Kind.NONE
## A house's number, or a scenery piece's variety.
var door: int = 0
var state: Door = Door.FAR
var stars: int = 0
var pulse: float = 0.0
## Whether its door wears the golden knocker, and, for a milestone, whether its family has moved in.
var knocker: bool = false
var settled: bool = false
## Its tap wobble (Jiggle), made on its first tap and kept while it is recycled.
var jiggle: Jiggle
## A family's house's moving parts: the windmill's sails and the family itself.
var sails: StreetPiece
var folk: StreetFolk

func dress_house(number: int, door_state: Door, earned: int, has_knocker: bool = false,
		has_settled: bool = false) -> void:
	kind = HOUSE
	door = number
	state = door_state
	stars = earned
	knocker = has_knocker
	settled = has_settled
	_still()
	_dress_family()
	queue_redraw()

func dress_scenery(scenery_kind: int, variety: int) -> void:
	kind = scenery_kind
	door = variety
	_still()
	_dress_family()
	queue_redraw()

## Whether it is a milestone door, plot or house.
func milestone() -> bool:
	return kind == HOUSE and StreetRewards.is_milestone(door)

## A settled family's house gets its family in front and, for the windmill, its sails. Anything else has neither.
func _dress_family() -> void:
	var home: bool = milestone() and settled
	var house: String = _piece() if home else ""
	if home and StreetArt.has(house) and StreetArt.meta(house, "hub").size() == 2:
		if sails == null:
			sails = StreetPiece.new("milestone_windmill_sails")
			add_child(sails)
		sails.k = HOUSE_SCALE * MILESTONE_SCALE
		sails.position = StreetArt.point(house, "hub") * HOUSE_SCALE * MILESTONE_SCALE + Vector2(0.0, -platform())
		sails.visible = true
		sails.queue_redraw()
	elif sails != null:
		sails.visible = false
	if home:
		if folk == null:
			folk = StreetFolk.new()
			add_child(folk)
		var f: int = StreetRewards.family_of(door)
		if folk.family != f:
			folk.queue_free()
			folk = StreetFolk.new()
			folk.family = f
			add_child(folk)
		folk.size_k = FOLK_SCALE
		# On the plot's steps in front of their door, a little toward the road, in front of the sails.
		var toward: float = -float(StreetPath.door_side(door))
		folk.position = Vector2(toward * StreetArt.size(house).x * HOUSE_SCALE * MILESTONE_SCALE * 0.16, 12.0)
		folk.visible = true
		move_child(folk, -1)
	elif folk != null:
		folk.visible = false
	set_process(sails != null and sails.visible and not Save.reduce_motion)

func _process(delta: float) -> void:
	sails.rotation += SAIL_SPIN * delta

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

## Its idle lean in the breeze at time `t`: trees, bushes and flowers sway, each in its own time, and nothing else.
func sway(t: float) -> float:
	var reach: float = SWAY.get(kind, 0.0)
	if reach == 0.0:
		return 0.0
	var phase: float = float(StreetPath.mix(door * 17 + kind) % 1000) / 1000.0 * TAU
	return reach * sin(t * SWAY_SPEED * (0.85 + 0.3 * phase / TAU) + phase)

## The piece's outline on screen at near-edge size, for taps. A plot's reaches up to its sign's top.
func bounds() -> Rect2:
	var piece: String = _piece()
	var k: float = _scale_k()
	var s: Vector2 = StreetArt.size(piece) * k
	if milestone() and not settled:
		var sign_h: float = StreetArt.size("milestone_plot_sign").y * k * SIGN_SCALE / PLOT_SCALE
		s.y = maxf(s.y, s.y * 0.5 + sign_h)
	elif milestone():
		s.y += platform()
	return Rect2(Vector2(-s.x * 0.5, -s.y), s)

## How far a family's house stands above the street, on its plot's platform.
static func platform() -> float:
	return PLATFORM * StreetArt.DESIGN_PER_PIXEL * HOUSE_SCALE * PLOT_SCALE

## Its size beside its painting.
func _scale_k() -> float:
	if kind == RIBBON:
		return ribbon_k()
	if kind != HOUSE:
		return SCENERY_SCALE.get(kind, 0.7)
	if milestone():
		return HOUSE_SCALE * (MILESTONE_SCALE if settled else PLOT_SCALE)
	return HOUSE_SCALE

## The finish ribbon's size beside its painting, so it spans the plot.
static func ribbon_k() -> float:
	return StreetArt.size("milestone_plot").x * HOUSE_SCALE * PLOT_SCALE * RIBBON_SPAN / StreetArt.size("ribbon_finish").x

## Dresses it as the finish ribbon before milestone door `n`.
func dress_ribbon(n: int) -> void:
	kind = RIBBON
	door = n
	_still()
	_dress_family()
	queue_redraw()

func _piece() -> String:
	if kind == RIBBON:
		return "ribbon_finish"
	if kind == HOUSE:
		if milestone():
			return StreetFamilies.house(StreetRewards.family_of(door)) if settled else "milestone_plot"
		return StreetArt.house_of(door)
	return piece_for(kind, door)

## The painted piece a scenery kind of this variety is drawn with.
static func piece_for(scenery_kind: int, variety: int) -> String:
	match scenery_kind:
		StreetPath.Kind.TREE:
			return "tree_%d" % (1 + variety % 3)
		StreetPath.Kind.BUSH:
			return ("bush_%d" % (1 + variety % 3)) if variety % 5 < 3 else ("bush_big_%d" % (1 + variety % 2))
		StreetPath.Kind.LAMP:
			return "lamp_post"
		StreetPath.Kind.FENCE:
			return "fence_long" if variety % 3 != 0 else "fence"
		StreetPath.Kind.FLOWERS:
			return "flowerbed_%d" % (1 + variety % 3)
		StreetPath.Kind.BUNTING:
			return "bunting_posts"
		StreetPath.Kind.SIDE_HOUSE:
			return "house_%s_%d" % [StreetArt.COLOURS[variety % 4], 1 + (variety >> 2) % StreetArt.SHAPES]
	return "planter"

func _draw() -> void:
	if kind == StreetPath.Kind.NONE:
		return
	if kind == RIBBON:
		StreetArt.draw(self, "ribbon_finish", Vector2.ZERO, ribbon_k())
		return
	if kind == StreetPath.Kind.SIDE_HOUSE:
		_side_house()
		return
	if milestone() and not settled:
		_plot()
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
	var behind: Dictionary = _behind_of(door, StreetArt.size(house) * k, k)
	if not behind.is_empty():
		StreetArt.draw(self, str(behind["piece"]), behind["at"], float(behind["scale"]))

## The greenery behind house number `n` of `size`: one tree or big bush at one back corner, on about half the
## houses, a touch of green and not a wall of it. Its piece, base point and scale, or nothing.
static func _behind_of(n: int, size: Vector2, k: float) -> Dictionary:
	var pick: int = StreetPath.mix(n * 5 + 23) % 6
	if pick >= 3:
		return {}
	var side: float = -1.0 if StreetPath.mix(n * 3 + 7) % 2 == 0 else 1.0
	var piece: String = ("tree_%d" % (1 + pick)) if pick < 2 else "bush_big_%d" % (1 + n % 2)
	var reach: float = BEHIND_TREE if pick < 2 else BEHIND_BUSH
	return {"piece": piece, "at": Vector2(side * size.x * 0.42, -size.y * 0.1), "scale": reach * k / HOUSE_SCALE}

## A flowerbed at one front corner of a house, chosen by its number.
func _feet(house: String, k: float) -> void:
	var half: float = StreetArt.size(house).x * k * 0.42
	var side: float = -1.0 if StreetPath.mix(door * 7 + 11) % 2 == 0 else 1.0
	var piece: String = "flowerbed_%d" % (1 + StreetPath.mix(door * 7 + 13) % 3)
	StreetArt.draw(self, piece, Vector2(side * half, 6.0), FOOT_SCALE * k / HOUSE_SCALE)

## Everything, the number's digits too, comes from the atlas, so a whole street of houses batches into a few runs.
func _house() -> void:
	var house: String = _piece()
	var colour: String = StreetArt.COLOURS[StreetArt.colour_of(door)]
	var family: bool = milestone()
	var k: float = _scale_k()
	var d: Vector3 = StreetArt.door(house) * k
	var centre: Vector2 = Vector2(d.x, d.y)
	var door_k: float = k * StreetArt.door_scale(house)
	if family:
		# A family's house stands on its plot, the plot's steps in front of its door.
		_behind(house, k)
		StreetArt.draw(self, "milestone_plot", Vector2.ZERO, HOUSE_SCALE * PLOT_SCALE)
		draw_set_transform(Vector2(0.0, -platform()))
	else:
		_behind(house, k)
	StreetArt.draw(self, "shadow", Vector2.ZERO, StreetArt.size(house).x * k * SHADOW_SHARE / StreetArt.size("shadow").x)
	StreetArt.draw(self, house, Vector2.ZERO, k)
	if not family:
		_feet(house, k)
	if family:
		# The family's "sold" sign stands at the house's corner away from the road.
		var away: float = float(StreetPath.door_side(door))
		StreetArt.draw(self, "plot_sign_sold", Vector2(away * StreetArt.size(house).x * k * 0.44, 4.0),
			k * SIGN_SCALE * 0.7)
	if state == Door.CURRENT:
		StreetArt.draw(self, "glow", centre, door_k * (1.0 + PULSE * sin(pulse * PULSE_SPEED)))
	# The door to play next wears a gold ring, whatever its house's colour, as door 12 in the concept.
	StreetArt.draw(self, "door_yellow" if state == Door.CURRENT else "door_" + colour, centre, door_k)
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
		StreetArt.draw(self, "padlock", centre + Vector2(0, 4), door_k * 0.9)
		draw_set_transform(Vector2.ZERO)
		return
	# A door with a parcel waiting (every 5th) shows it under its number until it is solved, as door 15 in the concept.
	var gift: bool = StreetRewards.has_parcel(door) and state != Door.SOLVED
	var ring: bool = knocker and state == Door.SOLVED
	var lift: float = -d.z * (0.32 if gift else 0.2) if state == Door.SOLVED or gift else 0.0
	var digits: int = str(door).length()
	var height: float = d.z * NUMBER_HEIGHT * (1.0 if digits < 3 else 0.78) * (0.74 if gift else 1.0)
	if ring:
		lift = -d.z * KNOCKER_LIFT
		height *= KNOCKER_NUMBER
		StreetArt.draw(self, "knocker", centre + Vector2(0.0, d.z * KNOCKER_DROP),
			d.z * KNOCKER_WIDTH / StreetArt.size("knocker").x)
	StreetArt.draw_number(self, door, centre + Vector2(0.0, lift), height)
	if gift:
		var box: float = d.z * 0.8 / StreetArt.size("parcel_body").x
		StreetArt.draw(self, "parcel_body", centre + Vector2(0.0, d.z * 0.62), box)
		StreetArt.draw(self, "parcel_lid", centre + Vector2(0.0, d.z * 0.12), box)
		StreetArt.draw(self, "parcel_bow", centre + Vector2(0.0, d.z * 0.02), box)
	draw_set_transform(Vector2.ZERO)

## A milestone door before its family arrives: the empty plot, waiting, and on it a sign with the door's number, which
## glows when it is the door to play next and wears a padlock while it is far off.
func _plot() -> void:
	var k: float = _scale_k()
	_behind("milestone_plot", k)
	StreetArt.draw(self, "milestone_plot", Vector2.ZERO, k)
	var sign_k: float = k * SIGN_SCALE / PLOT_SCALE
	var foot: Vector2 = Vector2(0.0, -StreetArt.size("milestone_plot").y * k * 0.45)
	var board: Vector2 = foot + SIGN_BOARD * StreetArt.DESIGN_PER_PIXEL * sign_k
	if state == Door.CURRENT:
		StreetArt.draw(self, "glow", board, sign_k * 0.95 * (1.0 + PULSE * sin(pulse * PULSE_SPEED)))
	StreetArt.draw(self, "milestone_plot_sign", foot, sign_k)
	if state == Door.FAR:
		StreetArt.draw(self, "padlock", board, sign_k * 0.6)
		return
	StreetArt.draw_number(self, door, board, SIGN_NUMBER * StreetArt.DESIGN_PER_PIXEL * sign_k,
		Color("2f8f80") if state != Door.CURRENT else Color("e0901a"))
