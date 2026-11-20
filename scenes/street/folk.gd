class_name StreetFolk
extends Node2D

## A family of marble folk standing in a row (StreetFamilies), drawn as the cast is: a painted body each, the cast's
## live face parts, and the family's props on top. They breathe, blink and bob each in their own time, wave by
## hopping when they arrive, and wobble and laugh when tapped. The base point is the ground under the row's middle.
## Reduce motion holds them still.

## A full-size member's body width, as a share of the painted body, and the gap between members, in body widths.
const SCALE: float = 0.52
const SPREAD: float = 0.98
const BREATHE: float = 0.03
const BREATHE_SPEED: float = 1.6
const BOB: float = 0.03
const BOB_SPEED: float = 2.2
const BLINK_GAP: Vector2 = Vector2(2.0, 5.0)
const BLINK_TIME: float = 0.13
## A wave: hops this high, in body widths, this many times a second.
const WAVE_HOP: float = 0.3
const WAVE_RATE: float = 2.2
const POKE_LAUGH: float = 0.9

var family: int = 0
## Their size, against a full-size cast member at SCALE.
var size_k: float = 1.0
## Whether they hop and wave, as they do when they first arrive.
var waving: bool = false
var _t: float = 0.0
var _springs: Array[Jiggle] = []
var _blink_at: PackedFloat32Array = PackedFloat32Array()
var _laugh_until: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	for i: int in range(StreetFamilies.members(family).size()):
		_springs.append(Jiggle.new())
		_blink_at.append(randf_range(BLINK_GAP.x, BLINK_GAP.y))
		_laugh_until.append(-1.0)

## A full-size member's body width, in design pixels at this node's scale 1.
func body_width() -> float:
	return StreetArt.size("marble_red").x * SCALE * size_k

## Each member's foot along the row, their sizes considered, centred on the base point.
func _feet() -> PackedFloat32Array:
	var members: Array = StreetFamilies.members(family)
	var w: float = body_width()
	var total: float = 0.0
	for m: Dictionary in members:
		total += float(m["size"]) * w * SPREAD
	var out: PackedFloat32Array = PackedFloat32Array()
	var x: float = -total * 0.5
	for m: Dictionary in members:
		var span: float = float(m["size"]) * w * SPREAD
		out.append(x + span * 0.5)
		x += span
	return out

## The row's width.
func width() -> float:
	var members: Array = StreetFamilies.members(family)
	var total: float = 0.0
	for m: Dictionary in members:
		total += float(m["size"]) * body_width() * SPREAD
	return total

## The member under a point in this node's space, or -1.
func member_at(local: Vector2) -> int:
	var feet: PackedFloat32Array = _feet()
	var members: Array = StreetFamilies.members(family)
	for i: int in range(members.size()):
		var w: float = body_width() * float((members[i] as Dictionary)["size"])
		if local.distance_to(Vector2(feet[i], -w * 0.5)) < w * 0.6:
			return i
	return -1

## A tap on member `i`: it wobbles and laughs, or under Reduce motion only laughs.
func poke(i: int) -> void:
	if i < 0 or i >= _springs.size():
		return
	if not Save.reduce_motion:
		_springs[i].kick()
	_laugh_until[i] = _t + POKE_LAUGH
	Audio.play(&"boing", -10.0, randf_range(1.05, 1.35))
	Audio.buzz(StreetWobbler.BUZZ_MS, StreetWobbler.BUZZ)

func _process(delta: float) -> void:
	_t += delta
	for spring: Jiggle in _springs:
		spring.step(delta)
	queue_redraw()

func _draw() -> void:
	var members: Array = StreetFamilies.members(family)
	var feet: PackedFloat32Array = _feet()
	var still: bool = Save.reduce_motion
	for i: int in range(members.size()):
		var m: Dictionary = members[i]
		var k: float = SCALE * size_k * float(m["size"])
		var w: float = StreetArt.size("marble_red").x * k
		var lift: float = 0.0 if still else BOB * w * (0.5 + 0.5 * sin(_t * BOB_SPEED + float(i) * 1.7))
		if waving and not still:
			lift = WAVE_HOP * w * absf(sin((_t * WAVE_RATE + float(i) * 0.3) * PI))
		StreetArt.draw(self, "shadow", Vector2(feet[i], 0.0), w * (1.0 - clampf(lift / w, 0.0, 0.6) * 0.5)
			/ StreetArt.size("shadow").x)
		var breath: float = 0.0 if still else BREATHE * sin(_t * BREATHE_SPEED + float(i) * 2.3)
		var squash: Vector2 = _springs[i].squash() * Vector2(1.0 + breath, 1.0 / (1.0 + breath))
		draw_set_transform(Vector2(feet[i], -lift), _springs[i].tilt(), squash)
		draw_member(self, m, Vector2(0.0, -w * 0.5), k, _t < _laugh_until[i] or waving, _blinking(i))
	draw_set_transform(Vector2.ZERO)

func _blinking(i: int) -> bool:
	if _t >= _blink_at[i] + BLINK_TIME:
		_blink_at[i] = _t + randf_range(BLINK_GAP.x, BLINK_GAP.y)
	return _t >= _blink_at[i]

## Draws one member (a StreetFamilies record) about its body's centre, `k` times the painted body's near-edge size:
## its body, the cast's face parts and its props. `laughing` opens its mouth, `blinking` shuts plain eyes.
static func draw_member(ci: CanvasItem, m: Dictionary, centre: Vector2, k: float, laughing: bool = false,
		blinking: bool = false) -> void:
	var w: float = StreetArt.size("marble_red").x * k
	StreetArt.draw(ci, "folk_" + str(m["body"]), centre, k)
	var grin: bool = bool(m["grin"])
	var eye: String = "eye_happy" if grin or laughing else ("eye_closed" if blinking else "eye")
	var mouth: String = "mouth_laugh" if laughing else ("mouth_grin" if grin else "mouth_smile")
	for side: float in [-1.0, 1.0]:
		StreetArt.draw(ci, eye, centre + Vector2(side * 0.17 * w, -0.04 * w), k)
		StreetArt.draw(ci, "blush", centre + Vector2(side * 0.27 * w, 0.1 * w), k)
	StreetArt.draw(ci, mouth, centre + Vector2(0.0, 0.16 * w), k)
	for prop: String in m["props"]:
		var piece: String = "prop_" + prop
		StreetArt.draw(ci, piece, centre + StreetArt.point(piece, "offset") * k, k)
