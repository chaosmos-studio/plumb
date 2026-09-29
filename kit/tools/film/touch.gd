class_name Touch
extends Node2D

## A finger on the glass, so a viewer sees what the player did. A tap is a soft dot that presses in and
## sends out a ring; a swipe drags the dot along and leaves a fading trail behind it.

const PRESS: float = 0.1
const RIPPLE: float = 0.55
const SWIPE: float = 0.26
const TRAIL: int = 18

var radius: float = 34.0
var colour: Color = Color.WHITE
var _dot: float = 0.0
var _ring: float = 0.0
var _press: float = 1.0
var _trail: PackedVector2Array = PackedVector2Array()
var _swiping: bool = false

static func tap(parent: Node, at: Vector2, size: float, tint: Color) -> void:
	var t: Touch = Touch.new()
	t.radius = size
	t.colour = tint
	t.position = at
	parent.add_child(t)
	t._tap()

static func swipe(parent: Node, from: Vector2, to: Vector2, size: float, tint: Color) -> void:
	var t: Touch = Touch.new()
	t.radius = size
	t.colour = tint
	t.position = from
	parent.add_child(t)
	t._swipe(to)

func _tap() -> void:
	var t: Tween = create_tween()
	t.tween_property(self, "_dot", 1.0, PRESS)
	t.parallel().tween_property(self, "_press", 0.82, PRESS)
	t.tween_property(self, "_press", 1.0, PRESS)
	t.parallel().tween_property(self, "_ring", 1.0, RIPPLE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(self, "_dot", 0.0, RIPPLE * 0.8).set_delay(0.12)
	t.tween_callback(queue_free)

func _swipe(to: Vector2) -> void:
	_swiping = true
	var t: Tween = create_tween()
	t.tween_property(self, "_dot", 1.0, PRESS * 0.6)
	t.tween_property(self, "position", to, SWIPE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "_dot", 0.0, 0.22)
	t.tween_callback(queue_free)

func _process(_delta: float) -> void:
	if _swiping:
		_trail.append(global_position)
		if _trail.size() > TRAIL:
			_trail.remove_at(0)
	queue_redraw()

func _draw() -> void:
	if _trail.size() > 1:
		for k: int in range(_trail.size() - 1):
			var a: float = float(k + 1) / _trail.size()
			draw_line(to_local(_trail[k]), to_local(_trail[k + 1]), Color(colour, 0.35 * a * _dot), radius * 1.1 * a, true)
	if _ring > 0.0 and _ring < 1.0:
		draw_arc(Vector2.ZERO, radius * (1.0 + _ring * 1.6), 0.0, TAU, 64, Color(colour, 0.7 * (1.0 - _ring)), 4.0, true)
	if _dot > 0.0:
		draw_circle(Vector2.ZERO, radius * _press, Color(colour, 0.4 * _dot), true, -1.0, true)
		draw_arc(Vector2.ZERO, radius * _press, 0.0, TAU, 64, Color(colour, 0.85 * _dot), 3.0, true)
