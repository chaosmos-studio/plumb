class_name StreetCast
extends Node2D

## Rosie, Steve, Pip and Lulu standing together on the street, drawn from the atlas in one canvas item: a painted body
## each and face parts on top (REVAMP_PLAN.md section 10). The faces stay live, unlike a painting: they blink, follow
## the finger, bob, and change when the cast walks or cheers. The base point is the ground under the row's middle.

enum Pose { CALM, HAPPY, LAUGH, WONDER }

## The bodies' size at the near edge, as a share of the painted body.
const SCALE: float = 0.62
## Their spacing, as a share of a body's width.
const SPREAD: float = 1.04
## Bobbing on the spot: how high, in body widths, and how fast.
const BOB: float = 0.035
const BOB_SPEED: float = 2.6
## Hopping along: how high and how often a second.
const HOP: float = 0.22
const HOP_RATE: float = 2.6
## Between blinks, in seconds, and how long one lasts.
const BLINK_GAP: Vector2 = Vector2(2.2, 5.5)
const BLINK_TIME: float = 0.13
## How far the eyes can look, as a share of a body's width.
const GAZE: float = 0.045
## A cheer: a jump this high, in body widths, over this long.
const CHEER_JUMP: float = 0.45
const CHEER_TIME: float = 0.55

## Which of the four stand here, by colour (0 red, 1 teal, 2 yellow, 3 purple).
var members: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
var face: Pose = Pose.CALM
var hopping: bool = false
var _t: float = 0.0
var _blink_at: PackedFloat32Array = PackedFloat32Array()
var _look: Vector2 = Vector2.ZERO
var _look_until: float = 0.0
var _cheer: float = -1.0

func _ready() -> void:
	for i: int in range(4):
		_blink_at.append(randf_range(BLINK_GAP.x, BLINK_GAP.y))

## The body's width at the near edge, in design pixels.
static func body_width() -> float:
	return StreetArt.size("marble_red").x * SCALE

## Turns the eyes toward a point on screen for a little while.
func look_toward(screen_point: Vector2) -> void:
	_look = (get_global_transform_with_canvas().affine_inverse() * screen_point).normalized()
	_look_until = _t + 2.5

func cheer() -> void:
	_cheer = 0.0
	face = Pose.LAUGH

func _process(delta: float) -> void:
	_t += delta
	if _cheer >= 0.0:
		_cheer += delta
		if _cheer > CHEER_TIME * 1.6:
			_cheer = -1.0
			face = Pose.CALM
	queue_redraw()

func _draw() -> void:
	var w: float = body_width()
	var n: int = members.size()
	for i: int in range(n):
		var x: float = (float(i) - float(n - 1) * 0.5) * w * SPREAD
		var lift: float = BOB * w * (0.5 + 0.5 * sin(_t * BOB_SPEED + float(i) * 1.3))
		if hopping:
			lift = HOP * w * absf(sin((_t * HOP_RATE + float(i) * 0.25) * PI))
		if _cheer >= 0.0:
			var c: float = clampf((_cheer - float(i) * 0.06) / CHEER_TIME, 0.0, 1.0)
			lift += CHEER_JUMP * w * sin(c * PI)
		var shadow_k: float = 1.0 - clampf(lift / w, 0.0, 0.6) * 0.5
		StreetArt.draw(self, "shadow", Vector2(x, 0.0), w * 1.0 * shadow_k / StreetArt.size("shadow").x)
		var centre: Vector2 = Vector2(x, -w * 0.5 - lift)
		_member(members[i], i, centre, w)

func _member(colour: int, index: int, centre: Vector2, w: float) -> void:
	StreetArt.draw(self, "marble_" + StreetArt.COLOURS[colour], centre, SCALE)
	var gaze: Vector2 = (_look if _t < _look_until else Vector2(sin(_t * 0.4 + index), 0.3) * 0.4) * GAZE * w
	var eye: String = "eye"
	var mouth: String = "mouth_smile"
	match face:
		Pose.HAPPY:
			eye = "eye_happy"
			mouth = "mouth_grin"
		Pose.LAUGH:
			eye = "eye_happy"
			mouth = "mouth_laugh"
		Pose.WONDER:
			mouth = "mouth_o"
	if eye == "eye" and _blinking(index):
		eye = "eye_closed"
	var eye_at: Vector2 = centre + Vector2(0.0, -0.04 * w) + (gaze if eye == "eye" else Vector2.ZERO)
	StreetArt.draw(self, eye, eye_at + Vector2(-0.17 * w, 0.0), SCALE)
	StreetArt.draw(self, eye, eye_at + Vector2(0.17 * w, 0.0), SCALE)
	StreetArt.draw(self, "blush", centre + Vector2(-0.27 * w, 0.1 * w), SCALE)
	StreetArt.draw(self, "blush", centre + Vector2(0.27 * w, 0.1 * w), SCALE)
	StreetArt.draw(self, mouth, centre + Vector2(0.0, 0.16 * w) + gaze * 0.4, SCALE)

func _blinking(index: int) -> bool:
	if _t >= _blink_at[index] + BLINK_TIME:
		_blink_at[index] = _t + randf_range(BLINK_GAP.x, BLINK_GAP.y)
	return _t >= _blink_at[index]
