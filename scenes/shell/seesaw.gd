class_name Seesaw
extends Node2D

## The title's toy: a bar that rocks slowly while four marbles roll along it under gravity, knocking
## into each other and the ends. One dimension of physics along the bar is all it needs. At launch the
## intro can `hold` some of them back and then `drop` them in from the icon's holes.

const LENGTH: float = 440.0
const THICKNESS: float = 26.0
const ROCK: float = 0.11
const ROCK_SPEED: float = 0.85
const GRAVITY: float = 1500.0
const DAMPING: float = 0.35
const RADIUS: float = 26.0
## How long a marble dropped in from the intro takes to land.
const DROP_TIME: float = 0.5

var _t: float = 0.0
var _marbles: Array[Marble] = []
var _s: PackedFloat32Array = PackedFloat32Array()
var _v: PackedFloat32Array = PackedFloat32Array()
## Per marble: -1 rolling on the bar, -2 held out of sight, or how far through its drop it is.
var _drop: PackedFloat32Array = PackedFloat32Array()
var _from: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	for k: int in range(4):
		var m: Marble = Marble.new()
		m.radius = RADIUS
		m.colour = Palette.marble(k)
		add_child(m)
		_marbles.append(m)
		_s.append(-LENGTH * 0.3 + k * RADIUS * 2.4)
		_v.append(0.0)
		_drop.append(-1.0)
		_from.append(Vector2.ZERO)

## Keeps the marbles of these colours off the bar and out of sight until they are dropped in.
func hold(colours: Array[int]) -> void:
	for k: int in colours:
		_drop[k] = -2.0
		_marbles[k].visible = false

## The marbles of these colours fall from `from` (screen points, one each) onto their places on the bar,
## growing as they come, and land with a clack.
func drop(colours: Array[int], from: Array[Vector2]) -> void:
	for i: int in range(colours.size()):
		var k: int = colours[i]
		_from[k] = get_global_transform_with_canvas().affine_inverse() * from[i]
		_drop[k] = 0.0
		_v[k] = 0.0
		_marbles[k].visible = true

func _process(delta: float) -> void:
	_t += delta
	var angle: float = ROCK * sin(_t * ROCK_SPEED)
	var half: float = LENGTH * 0.5 - RADIUS
	for k: int in range(_s.size()):
		if _drop[k] != -1.0:
			continue
		_v[k] += GRAVITY * sin(angle) * delta
		_v[k] -= _v[k] * DAMPING * delta
		_s[k] += _v[k] * delta
	# Keep them in order along the bar and apart, trading speeds on contact like equal balls do.
	for k: int in range(_s.size()):
		if _s[k] < -half:
			_s[k] = -half
			_v[k] = absf(_v[k]) * 0.4
		if _s[k] > half:
			_s[k] = half
			_v[k] = -absf(_v[k]) * 0.4
	for k: int in range(_s.size() - 1):
		if _drop[k] != -1.0 or _drop[k + 1] != -1.0:
			continue
		var gap: float = _s[k + 1] - _s[k]
		if gap < RADIUS * 2.0:
			var push: float = (RADIUS * 2.0 - gap) * 0.5
			_s[k] -= push
			_s[k + 1] += push
			var a: float = _v[k]
			_v[k] = _v[k + 1] * 0.9
			_v[k + 1] = a * 0.9
	var along: Vector2 = Vector2(cos(angle), sin(angle))
	var up: Vector2 = Vector2(sin(angle), -cos(angle))
	for k: int in range(_marbles.size()):
		var rest: Vector2 = along * _s[k] + up * (RADIUS + THICKNESS * 0.5)
		if _drop[k] >= 0.0:
			_drop[k] = minf(_drop[k] + delta / DROP_TIME, 1.0)
			var t: float = _drop[k]
			_marbles[k].position = _from[k].lerp(rest, t * t)
			_marbles[k].scale = Vector2.ONE * lerpf(0.45, 1.0, minf(t * 1.6, 1.0))
			if t >= 1.0:
				_drop[k] = -1.0
				_marbles[k].scale = Vector2.ONE
				_v[k] = -60.0
				Audio.play(&"clack", -4.0, 0.9 + 0.08 * k)
			continue
		_marbles[k].position = rest
		_marbles[k].rotation = _s[k] / RADIUS
	rotation = 0.0
	_angle = angle
	queue_redraw()

var _angle: float = 0.0

func _draw() -> void:
	var along: Vector2 = Vector2(cos(_angle), sin(_angle))
	var up: Vector2 = Vector2(sin(_angle), -cos(_angle))
	var a: Vector2 = -along * LENGTH * 0.5
	var b: Vector2 = along * LENGTH * 0.5
	# The plank and the darker lip under it are both capsules, so the lip shows as an even rim round the
	# rounded ends too, not as square corners poking out beneath them.
	_capsule(a - up * 2.0, b - up * 2.0, THICKNESS * 0.5, Palette.WALL_LIP)
	_capsule(a + up * 4.0, b + up * 4.0, THICKNESS * 0.5, Palette.WALL)
	var foot: PackedVector2Array = PackedVector2Array([Vector2(0, 14), Vector2(-46, 90), Vector2(46, 90)])
	draw_colored_polygon(foot, Palette.TRAY)
	draw_circle(Vector2(0, 14), 12.0, Palette.WALL_LIP, true, -1.0, true)

func _capsule(from: Vector2, to: Vector2, r: float, colour: Color) -> void:
	draw_line(from, to, colour, r * 2.0, true)
	draw_circle(from, r, colour, true, -1.0, true)
	draw_circle(to, r, colour, true, -1.0, true)
