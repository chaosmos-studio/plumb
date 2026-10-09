class_name IconButton
extends BaseButton

## Drawn entirely here, so it looks the same on every game's palette with no textures.

const SIZE: float = 96.0

var icon_name: StringName = &"back":
	set(value):
		icon_name = value
		queue_redraw()
## For the one icon action a screen wants noticed.
var accent: bool = false:
	set(value):
		accent = value
		queue_redraw()
var badge: String = "":
	set(value):
		badge = value
		queue_redraw()
var badge_icon: StringName = &"":
	set(value):
		badge_icon = value
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UI.press_feedback(self)
	pressed.connect(func() -> void: Audio.play(&"tap", -8.0))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		_paint()

func _paint() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 4.0
	var fill: Color = Brand.ACCENT if accent else Brand.SURFACE
	var ink: Color = Brand.ACCENT_INK if accent else Brand.INK
	if is_hovered() and not disabled:
		fill = fill.lightened(0.04)
	if disabled:
		fill = Color(fill, fill.a * 0.45)
		ink = Color(ink, 0.35)
	draw_circle(c + Vector2(0, 4), r, Brand.SHADOW, true, -1.0, true)
	draw_circle(c, r, fill, true, -1.0, true)
	if not accent:
		draw_arc(c, r, 0.0, TAU, 48, Brand.LINE, 2.0, true)
	Icons.draw(self, icon_name, c, r * 1.3, ink)
	if badge != "" or badge_icon != &"":
		var at: Vector2 = c + Vector2(r * 0.72, -r * 0.72)
		draw_circle(at, 20.0, Brand.ACCENT, true, -1.0, true)
		if badge_icon != &"":
			Icons.draw(self, badge_icon, at + Vector2(1.5, 0.0), 30.0, Brand.ACCENT_INK)
			return
		var font: Font = UI.ui_font()
		var text_size: Vector2 = font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(font, at + Vector2(-text_size.x * 0.5, 8.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Brand.ACCENT_INK)
