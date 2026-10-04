class_name VolumeSlider
extends Range

## A loudness from 0 to 1, drawn to match the kit: a rounded track, the part up to the knob in the accent,
## and a round knob. A touch anywhere on it moves the knob to the finger, a drag carries it, and `released`
## says where it came to rest, for the setting to be saved once rather than on every step. It is a Range, so
## a sheet leaves a drag that starts on it alone.

signal released(value: float)

const HEIGHT: float = 56.0
const TRACK: float = 10.0
const KNOB: float = 17.0

var _dragging: bool = false

func _init(start: float) -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.01
	value = start
	custom_minimum_size = Vector2(280.0, HEIGHT)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	value_changed.connect(func(_v: float) -> void: queue_redraw())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button: InputEventMouseButton = event
		if button.pressed:
			_dragging = true
			_follow(button.position.x)
		elif _dragging:
			_dragging = false
			released.emit(value)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_follow((event as InputEventMouseMotion).position.x)
		accept_event()

func _follow(x: float) -> void:
	value = clampf((x - KNOB) / maxf(1.0, size.x - KNOB * 2.0), 0.0, 1.0)

func _draw() -> void:
	var y: float = size.y * 0.5
	var left: Vector2 = Vector2(KNOB, y)
	var right: Vector2 = Vector2(size.x - KNOB, y)
	var at: Vector2 = left.lerp(right, ratio)
	_bar(left, right, Color(Brand.INK, 0.14))
	_bar(left, at, Brand.ACCENT)
	draw_circle(at + Vector2(0, 3), KNOB, Brand.SHADOW, true, -1.0, true)
	draw_circle(at, KNOB, Brand.SURFACE, true, -1.0, true)
	draw_arc(at, KNOB - 1.5, 0.0, TAU, 32, Brand.ACCENT, 3.0, true)

func _bar(from: Vector2, to: Vector2, colour: Color) -> void:
	draw_line(from, to, colour, TRACK, true)
	draw_circle(from, TRACK * 0.5, colour, true, -1.0, true)
	draw_circle(to, TRACK * 0.5, colour, true, -1.0, true)
