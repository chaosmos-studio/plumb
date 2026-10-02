class_name LevelTile
extends BaseButton

## One level in the grid: its number and the stars it has earned. The next level to play is ringed in
## the accent colour, finished ones sit on a surface, and locked ones are only an outline and a lock.

const SIZE: float = 132.0

var level: int = 0
var stars: int = 0
var locked: bool = false
var is_next: bool = false

## A locked tile still takes a tap when `offers` is set, on Google Play, where it offers Every level.
func _init(index: int, earned: int, open: bool, next: bool, offers: bool = false) -> void:
	level = index
	stars = earned
	locked = not open
	is_next = next
	disabled = locked and not offers
	custom_minimum_size = Vector2(SIZE, SIZE)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_ARROW
	UI.press_feedback(self)
	pressed.connect(func() -> void: Audio.play(&"tap", -8.0))

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.set_corner_radius_all(34)
	box.anti_aliasing = true
	if locked:
		box.bg_color = Color(0, 0, 0, 0)
		box.border_color = Brand.LINE
		box.set_border_width_all(2)
		draw_style_box(box, rect)
		Icons.draw(self, &"lock", rect.get_center(), 54.0, Color(Brand.MUTED, 0.6))
		return
	box.bg_color = Brand.SURFACE
	box.shadow_color = Brand.SHADOW
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	if is_next:
		box.border_color = Brand.ACCENT
		box.set_border_width_all(4)
	else:
		box.border_color = Brand.LINE
		box.set_border_width_all(2)
	draw_style_box(box, rect)
	var font: Font = UI.display_font()
	var text: String = str(level + 1)
	var font_size: int = 50
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ink: Color = Brand.ACCENT if is_next else Brand.INK
	var baseline: float = rect.position.y + rect.size.y * 0.5 + font_size * 0.32 - (8.0 if stars > 0 else 0.0)
	draw_string(font, Vector2(rect.get_center().x - ts.x * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	if stars > 0:
		for k: int in range(3):
			var at: Vector2 = Vector2(rect.get_center().x + (k - 1) * 22.0, rect.end.y - 26.0)
			_star(at, 9.0, Brand.GOLD if k < stars else Color(Brand.MUTED, 0.35))

func _star(c: Vector2, r: float, colour: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for k: int in range(10):
		var radius: float = r if k % 2 == 0 else r * 0.45
		var a: float = -PI * 0.5 + k * PI / 5.0
		points.append(c + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(points, colour)
	var loop: PackedVector2Array = points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, colour, 1.2, true)
