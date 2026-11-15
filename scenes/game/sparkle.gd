class_name Sparkle
extends Node2D

## A small burst drawn in code, as Ripple is: a few sparkles where a marble goes home, or confetti for a
## party. A handful of shapes needs no particle system, and nothing has to compile the first time it shows.

const SPARKS: int = 9
const CONFETTI: int = 16
const LIFE: float = 0.6
const CONFETTI_LIFE: float = 1.2
## Pixels a second per cell of board, and the pull down on confetti.
const SPEED: float = 2.6
const FALL: float = 5.0

var colours: Array[Color] = [Color.WHITE]
var cell: float = 80.0
var confetti: bool = false
var _t: float = 0.0
var _at: PackedVector2Array = PackedVector2Array()
var _v: PackedVector2Array = PackedVector2Array()
var _spin: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	var dice: RandomNumberGenerator = RandomNumberGenerator.new()
	dice.seed = get_instance_id()
	var count: int = CONFETTI if confetti else SPARKS
	for k: int in range(count):
		var a: float = TAU * k / count + dice.randf_range(-0.3, 0.3)
		if confetti:
			a = -PI * 0.5 + dice.randf_range(-1.1, 1.1)
		var speed: float = cell * SPEED * dice.randf_range(0.6, 1.1) * (1.6 if confetti else 1.0)
		_at.append(Vector2.ZERO)
		_v.append(Vector2.from_angle(a) * speed)
		_spin.append(dice.randf_range(-9.0, 9.0))

func _process(delta: float) -> void:
	var life: float = CONFETTI_LIFE if confetti else LIFE
	_t += delta / life
	if _t >= 1.0:
		queue_free()
		return
	for k: int in range(_at.size()):
		var v: Vector2 = _v[k] * exp(-(2.2 if confetti else 4.0) * delta)
		if confetti:
			v.y += cell * FALL * delta
		_v[k] = v
		_at[k] += v * delta
	queue_redraw()

func _draw() -> void:
	var fade: float = 1.0 - _t * _t
	for k: int in range(_at.size()):
		var ink: Color = colours[k % colours.size()]
		if confetti:
			draw_set_transform(_at[k], _spin[k] * _t * 4.0, Vector2(1.0, absf(cos(_spin[k] * _t * 3.0)) * 0.8 + 0.2))
			draw_rect(Rect2(-cell * 0.05, -cell * 0.03, cell * 0.1, cell * 0.06), Color(ink, fade))
			continue
		# A four-point sparkle: two thin diamonds crossed.
		var s: float = cell * 0.09 * (1.0 - _t * 0.6)
		draw_set_transform(_at[k], 0.0, Vector2.ONE)
		draw_line(Vector2(-s, 0.0), Vector2(s, 0.0), Color(ink, fade), maxf(1.5, s * 0.35), true)
		draw_line(Vector2(0.0, -s), Vector2(0.0, s), Color(ink, fade), maxf(1.5, s * 0.35), true)
		draw_circle(Vector2.ZERO, s * 0.32, Color(1, 1, 1, fade), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
