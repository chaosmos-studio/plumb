class_name Loaf
extends Node2D

## With faces on, every wall is an animal asleep in a loaf, a cat or a dog, filling its cell as the plain
## block did (MATH.md section 20). Each is its own node, so only one that wakes is drawn again. It keeps the
## wall's lip along its bottom and a coat in the wall's own tones, so it still reads as a wall first.

const NOSE: Color = Color("e58a9a")
## Below this luminance a coat is dark enough for its face to be drawn in a lighter line.
const INK_TURN: float = 0.42
## How long a woken animal stays awake, and how long an ear flick or a wag takes.
const AWAKE_TIME: float = 0.8
const FLICK_TIME: float = 0.32
const WAG_TIME: float = 0.7
const WAGS: float = 3.0
## A trill and a huff measure about 6 dB apart, so they are played that far apart to sound alike.
const MRRP_DB: float = -15.0
const HUFF_DB: float = -10.0

var family: Litter.Family = Litter.Family.CAT
var coat: Litter.Coat = Litter.Coat.GREY
## Half the drawn block's side, in pixels.
var half: float = 36.0
## The wall's colours for the theme now: the coat is worked out from them.
var wall: Color = Color("4f586a")
var lip: Color = Color("363c49")
var floor: Color = Color("fbf7f0")

var _box: StyleBoxFlat = StyleBoxFlat.new()
var _fur: Color
var _ink: Color
var _awake: float = 0.0
var _awake_left: float = 0.0
var _flick: float = 0.0
var _wag: float = 0.0
var _buf: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	set_process(false)
	_dress()

func _dress() -> void:
	_fur = Litter.fur(coat, family, wall, floor)
	# Shut eyes and a mouth in a lighter line on a dark coat and a darker one on a light coat, so they read on both.
	_ink = _fur.lightened(0.42) if _fur.get_luminance() < INK_TURN else _fur.darkened(0.55)
	_box.bg_color = _fur
	_box.border_color = _fur.darkened(0.3) if coat != Litter.Coat.GREY else lip
	_box.border_width_bottom = int(half * 0.2)
	_box.set_corner_radius_all(int(half * (0.42 if family == Litter.Family.CAT else 0.34)))
	_box.anti_aliasing = true
	queue_redraw()

## A marble stopped against it: eyes open, an ear flicks or the tail wags, a small sound, and back to sleep.
func wake() -> void:
	_awake_left = AWAKE_TIME
	if family == Litter.Family.CAT:
		_flick = FLICK_TIME
		Audio.play(&"mrrp", MRRP_DB, randf_range(0.94, 1.06))
	else:
		_wag = WAG_TIME
		Audio.play(&"huff", HUFF_DB, randf_range(0.94, 1.06))
	set_process(true)

## The board tilted its way: it stirs in its sleep, an ear or the tail, and does not wake.
func stir() -> void:
	if family == Litter.Family.CAT:
		_flick = FLICK_TIME * 0.7
	else:
		_wag = WAG_TIME * 0.4
	set_process(true)

func _process(delta: float) -> void:
	_awake_left = maxf(_awake_left - delta, 0.0)
	_flick = maxf(_flick - delta, 0.0)
	_wag = maxf(_wag - delta, 0.0)
	_awake = lerpf(_awake, 1.0 if _awake_left > 0.0 else 0.0, 1.0 - exp(-(30.0 if _awake_left > 0.0 else 9.0) * delta))
	if _awake_left <= 0.0 and _flick <= 0.0 and _wag <= 0.0 and _awake < 0.02:
		_awake = 0.0
		set_process(false)
	queue_redraw()

func _draw() -> void:
	var h: float = half
	if family == Litter.Family.CAT:
		var tip: float = sin(PI * (1.0 - _flick / FLICK_TIME)) * 0.45 if _flick > 0.0 else 0.0
		_ear(-1.0, -tip)
		_ear(1.0, 0.0)
		draw_style_box(_box, Rect2(-h, -h * 0.7, h * 2.0, h * 1.7))
	else:
		draw_style_box(_box, Rect2(-h, -h, h * 2.0, h * 2.0))
	_patches(h)
	if family == Litter.Family.CAT:
		_cat_face(h)
	else:
		_dog_face(h)

## A cat's ear on `side`, turned by `turn` radians about its base for a flick.
func _ear(side: float, turn: float) -> void:
	var h: float = half
	var base: Vector2 = Vector2(side * h * 0.58, -h * 0.6)
	var a: Vector2 = Vector2(-h * 0.3, 0.0)
	var b: Vector2 = Vector2(h * 0.3, 0.0)
	var top: Vector2 = Vector2(side * h * 0.12, -h * 0.4)
	_buf.resize(3)
	_buf[0] = base + a.rotated(turn * side)
	_buf[1] = base + b.rotated(turn * side)
	_buf[2] = base + top.rotated(turn * side)
	draw_colored_polygon(_buf, _fur)
	var lift: Vector2 = Vector2(0.0, -h * 0.02)
	_buf[0] = base + (a * 0.55 + lift).rotated(turn * side)
	_buf[1] = base + (b * 0.55 + lift).rotated(turn * side)
	_buf[2] = base + (top * 0.55 + lift).rotated(turn * side)
	draw_colored_polygon(_buf, Color(_fur.lerp(NOSE, 0.35), 0.9))

func _patches(h: float) -> void:
	if coat != Litter.Coat.PATCHED:
		return
	var dark: Color = Litter.fur(Litter.Coat.DARK, family, wall, floor)
	if family == Litter.Family.CAT:
		_oval(Vector2(-h * 0.5, -h * 0.3), Vector2(h * 0.34, h * 0.26), Litter.fur(Litter.Coat.WARM, family, wall, floor))
		_oval(Vector2(h * 0.52, h * 0.38), Vector2(h * 0.3, h * 0.22), dark)
	else:
		for spot: Vector3 in [Vector3(-0.55, -0.45, 0.16), Vector3(0.6, 0.05, 0.13), Vector3(-0.2, 0.62, 0.11)]:
			_oval(Vector2(spot.x, spot.y) * h, Vector2(spot.z, spot.z * 0.85) * h, dark)

func _cat_face(h: float) -> void:
	var line: float = maxf(1.5, h * 0.09)
	_eyes(Vector2(h * 0.36, 0.02 * h), h * 0.17, line)
	var nose: Vector2 = Vector2(0.0, h * 0.24)
	_buf.resize(3)
	_buf[0] = nose + Vector2(-h * 0.09, -h * 0.05)
	_buf[1] = nose + Vector2(h * 0.09, -h * 0.05)
	_buf[2] = nose + Vector2(0.0, h * 0.05)
	draw_colored_polygon(_buf, _fur.lerp(NOSE, 0.6))
	for side: float in [-1.0, 1.0]:
		draw_arc(nose + Vector2(side * h * 0.08, h * 0.06), h * 0.08, 0.1, PI - 0.1, 8, _ink, line * 0.7, true)
	# The tail curls round the front of the loaf, along the bottom.
	draw_arc(Vector2(h * 0.3, h * 0.5), h * 0.36, -0.15, PI * 0.92, 14, _fur.darkened(0.14), h * 0.17, true)

func _dog_face(h: float) -> void:
	var line: float = maxf(1.5, h * 0.09)
	var lift: float = _awake * 0.25
	for side: float in [-1.0, 1.0]:
		draw_set_transform(Vector2(side * h * 0.74, -h * 0.34), side * (0.22 + lift), Vector2(1.0, 1.9))
		draw_circle(Vector2.ZERO, h * 0.22, _fur.darkened(0.22), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	_eyes(Vector2(h * 0.33, -h * 0.1), h * 0.15, line)
	_oval(Vector2(0.0, h * 0.42), Vector2(h * 0.42, h * 0.3), _fur.lightened(0.18))
	_oval(Vector2(0.0, h * 0.26), Vector2(h * 0.13, h * 0.09), _ink)
	draw_line(Vector2(0.0, h * 0.3), Vector2(0.0, h * 0.48), _ink, line * 0.7, true)
	# The tail stays tucked away and only shows over the back while it wags.
	if _wag > 0.0:
		var wag: float = sin((1.0 - _wag / WAG_TIME) * TAU * WAGS) * 0.7
		var root: Vector2 = Vector2(h * 0.62, -h * 0.92)
		draw_line(root, root + Vector2.from_angle(-PI * 0.32 + wag) * h * 0.32, _fur.darkened(0.22), h * 0.16, true)

## Shut and sleeping, or open while it is awake.
func _eyes(at: Vector2, size: float, line: float) -> void:
	for side: float in [-1.0, 1.0]:
		var c: Vector2 = Vector2(side * at.x, at.y)
		if _awake > 0.5:
			_oval(c, Vector2(size * 0.42, size * 0.62 * _awake), _ink)
			draw_circle(c + Vector2(-size * 0.12, -size * 0.2), size * 0.14, Color(1, 1, 1, 0.85), true, -1.0, true)
		else:
			draw_arc(c + Vector2(0.0, -size * 0.45), size * 0.75, PI * 0.18, PI * 0.82, 10, _ink, line, true)

func _oval(c: Vector2, radii: Vector2, colour: Color) -> void:
	draw_set_transform(c, 0.0, Vector2(1.0, radii.y / radii.x))
	draw_circle(Vector2.ZERO, radii.x, colour, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
