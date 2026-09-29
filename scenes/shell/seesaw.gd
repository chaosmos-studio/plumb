class_name Seesaw
extends Node2D

## The title's toy: a bar that rocks slowly while four marbles roll along it under gravity, knocking
## into each other and the ends. One dimension of physics along the bar is all it needs.

const LENGTH: float = 440.0
const THICKNESS: float = 26.0
const ROCK: float = 0.11
const ROCK_SPEED: float = 0.85
const GRAVITY: float = 1500.0
const DAMPING: float = 0.35
const RADIUS: float = 26.0

var _t: float = 0.0
var _marbles: Array[Marble] = []
var _s: PackedFloat32Array = PackedFloat32Array()
var _v: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	for k: int in range(4):
		var m: Marble = Marble.new()
		m.radius = RADIUS
		m.colour = Palette.marble(k)
		add_child(m)
		_marbles.append(m)
		_s.append(-LENGTH * 0.3 + k * RADIUS * 2.4)
		_v.append(0.0)

func _process(delta: float) -> void:
	_t += delta
	var angle: float = ROCK * sin(_t * ROCK_SPEED)
	var half: float = LENGTH * 0.5 - RADIUS
	for k: int in range(_s.size()):
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
		_marbles[k].position = along * _s[k] + up * (RADIUS + THICKNESS * 0.5)
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
	draw_line(a + up * 4.0, b + up * 4.0, Palette.WALL, THICKNESS, true)
	draw_line(a - up * 6.0, b - up * 6.0, Palette.WALL_LIP, THICKNESS * 0.5, true)
	draw_circle(a, THICKNESS * 0.5, Palette.WALL, true, -1.0, true)
	draw_circle(b, THICKNESS * 0.5, Palette.WALL, true, -1.0, true)
	var foot: PackedVector2Array = PackedVector2Array([Vector2(0, 14), Vector2(-46, 90), Vector2(46, 90)])
	draw_colored_polygon(foot, Palette.TRAY)
	draw_circle(Vector2(0, 14), 12.0, Palette.WALL_LIP, true, -1.0, true)
