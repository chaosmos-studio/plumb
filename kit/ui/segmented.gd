class_name Segmented
extends Control

## A few options in one pill, the chosen one raised on a card that slides between them: for a setting
## with more than two values, where a switch cannot say which one is on.

signal chosen(index: int)

const HEIGHT: float = 72.0
const PAD: float = 6.0
const FONT_SIZE: int = 26

var options: PackedStringArray
var current: int = 0
var _at: float = 0.0

func _init(choices: PackedStringArray, selected: int = 0, width: float = 330.0) -> void:
	options = choices
	current = clampi(selected, 0, choices.size() - 1)
	_at = float(current)
	custom_minimum_size = Vector2(width, HEIGHT)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not press:
		return
	accept_event()
	var x: float = (event as InputEventMouseButton).position.x if event is InputEventMouseButton \
		else (event as InputEventScreenTouch).position.x
	var index: int = clampi(int(x / (size.x / options.size())), 0, options.size() - 1)
	if index == current:
		return
	current = index
	Audio.play(&"tap", -10.0)
	Audio.buzz(6)
	create_tween().tween_method(func(v: float) -> void:
		_at = v
		queue_redraw(), _at, float(index), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	chosen.emit(index)

func _draw() -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(Brand.MUTED, 0.16)
	track.set_corner_radius_all(int(size.y * 0.5))
	track.anti_aliasing = true
	draw_style_box(track, Rect2(Vector2.ZERO, size))
	var w: float = size.x / options.size()
	var knob: StyleBoxFlat = StyleBoxFlat.new()
	knob.bg_color = Brand.SURFACE
	knob.set_corner_radius_all(int((size.y - PAD * 2.0) * 0.5))
	knob.shadow_color = Brand.SHADOW
	knob.shadow_size = 8
	knob.shadow_offset = Vector2(0, 3)
	knob.anti_aliasing = true
	draw_style_box(knob, Rect2(Vector2(_at * w + PAD, PAD), Vector2(w - PAD * 2.0, size.y - PAD * 2.0)))
	var font: Font = UI.ui_font()
	for k: int in range(options.size()):
		var text_size: Vector2 = font.get_string_size(options[k], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var near: float = clampf(1.0 - absf(_at - k), 0.0, 1.0)
		var at: Vector2 = Vector2(k * w + (w - text_size.x) * 0.5, (size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5)
		draw_string(font, at, options[k], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Brand.MUTED.lerp(Brand.INK, near))
