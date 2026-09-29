class_name Switch
extends BaseButton

## An on/off switch: a pill track with a knob that slides across. Settings use these instead of buttons
## that say "Sound: on", because a switch shows its state without being read.

const TRACK: Vector2 = Vector2(96, 56)

var _k: float = 0.0

func _init(on: bool = false) -> void:
	toggle_mode = true
	custom_minimum_size = TRACK
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_pressed_no_signal(on)
	_k = 1.0 if on else 0.0
	toggled.connect(_on_toggled)

func _on_toggled(on: bool) -> void:
	Audio.play(&"tap", -10.0)
	Audio.buzz(6)
	var t: Tween = create_tween()
	t.tween_method(func(v: float) -> void:
		_k = v
		queue_redraw(), _k, 1.0 if on else 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var track: Rect2 = Rect2((size - TRACK) * 0.5, TRACK)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(Brand.MUTED, 0.3).lerp(Brand.ACCENT, _k)
	box.set_corner_radius_all(int(TRACK.y * 0.5))
	box.anti_aliasing = true
	draw_style_box(box, track)
	var r: float = TRACK.y * 0.5 - 5.0
	var x: float = lerpf(track.position.x + TRACK.y * 0.5, track.end.x - TRACK.y * 0.5, _k)
	var y: float = track.position.y + TRACK.y * 0.5
	draw_circle(Vector2(x, y + 2.0), r, Color(0, 0, 0, 0.12), true, -1.0, true)
	draw_circle(Vector2(x, y), r, Color.WHITE, true, -1.0, true)
