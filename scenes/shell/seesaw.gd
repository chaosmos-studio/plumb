class_name Seesaw
extends Node2D

## One dimension of physics along the bar (MATH.md section 11).

const LENGTH: float = 440.0
const THICKNESS: float = 26.0
const ROCK: float = 0.11
const ROCK_SPEED: float = 0.85
const GRAVITY: float = 1500.0
const DAMPING: float = 0.35
const RADIUS: float = 26.0
const DROP_TIME: float = 0.5
## Marbles that meet faster than this, in pixels a second, squint.
const SQUINT_SPEED: float = 160.0

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
		m.who = k
		m.side_view = true
		add_child(m)
		_marbles.append(m)
		_s.append(-LENGTH * 0.3 + k * RADIUS * 2.4)
		_v.append(0.0)
		_drop.append(-1.0)
		_from.append(Vector2.ZERO)

func hold(colours: Array[int]) -> void:
	for k: int in colours:
		_drop[k] = -2.0
		_marbles[k].visible = false

## `from` holds screen points, one for each colour.
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
			# A knock hard enough to hear makes both squint.
			if absf(a - _v[k + 1]) > SQUINT_SPEED:
				_marbles[k].mood.bump()
				_marbles[k + 1].mood.bump()
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
		# The marble turns as it rolls (Marble.side_view), and its face looks down the slope.
		_marbles[k].position = rest
		_marbles[k].mood.glance(Vector2(signf(angle) * clampf(absf(angle) / ROCK, 0.0, 1.0) * 0.7, 0.15), 0.2)
	rotation = 0.0
	_angle = angle
	queue_redraw()

var _angle: float = 0.0

func _draw() -> void:
	var along: Vector2 = Vector2(cos(_angle), sin(_angle))
	var up: Vector2 = Vector2(sin(_angle), -cos(_angle))
	var a: Vector2 = -along * LENGTH * 0.5
	var b: Vector2 = along * LENGTH * 0.5
	# The lip is a capsule too, so it shows as an even rim round the rounded ends, not as square corners.
	_capsule(a - up * 2.0, b - up * 2.0, THICKNESS * 0.5, Palette.WALL_LIP)
	_capsule(a + up * 4.0, b + up * 4.0, THICKNESS * 0.5, Palette.WALL)
	var foot: PackedVector2Array = PackedVector2Array([Vector2(0, 14), Vector2(-46, 90), Vector2(46, 90)])
	draw_colored_polygon(foot, Palette.TRAY)
	draw_circle(Vector2(0, 14), 12.0, Palette.WALL_LIP, true, -1.0, true)

func _capsule(from: Vector2, to: Vector2, r: float, colour: Color) -> void:
	draw_line(from, to, colour, r * 2.0, true)
	draw_circle(from, r, colour, true, -1.0, true)
	draw_circle(to, r, colour, true, -1.0, true)
