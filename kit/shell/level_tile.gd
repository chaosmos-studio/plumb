class_name LevelTile
extends BaseButton

const SIZE: float = 132.0
## A special level, one the game's Pack marks with special(i) (Pyxis's constellations), is a patch of night.
const NIGHT: Color = Color("141a3a")
const STARLIGHT: Color = Color("fff3cf")

var level: int = 0
var stars: int = 0
var locked: bool = false
var is_next: bool = false
var tint: Color = Color.WHITE
var special: bool = false

func _init(index: int, earned: int, open: bool, next: bool, colour: Color) -> void:
	level = index
	stars = earned
	locked = not open
	is_next = next
	tint = colour
	custom_minimum_size = Vector2(SIZE, SIZE)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UI.press_feedback(self)
	pressed.connect(func() -> void: Audio.play(&"tap", -8.0))

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.set_corner_radius_all(34)
	box.anti_aliasing = true
	if special:
		_night(rect, box)
		return
	if locked:
		box.bg_color = Color(Brand.SURFACE, 0.45)
		box.border_color = Color(tint, 0.3)
		box.set_border_width_all(2)
		draw_style_box(box, rect)
		_number(rect, Color(tint, 0.45), false)
		return
	box.bg_color = Brand.SURFACE
	box.shadow_color = Brand.SHADOW
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	if is_next:
		box.border_color = tint
		box.set_border_width_all(4)
	else:
		box.border_color = Color(tint, 0.4)
		box.set_border_width_all(2)
	draw_style_box(box, rect)
	_number(rect, tint if is_next else Brand.INK, stars > 0)
	if stars > 0:
		for k: int in range(3):
			var at: Vector2 = Vector2(rect.get_center().x + (k - 1) * 22.0, rect.end.y - 26.0)
			_star(at, 9.0, Brand.GOLD if k < stars else Color(Brand.MUTED, 0.35))

## A special level's tile: the night sky with a few stars, the same on every visit, and its number in starlight.
func _night(rect: Rect2, box: StyleBoxFlat) -> void:
	var dim: float = 0.55 if locked else 1.0
	box.bg_color = Color(NIGHT, 0.8 if locked else 1.0)
	if not locked:
		box.shadow_color = Brand.SHADOW
		box.shadow_size = 10
		box.shadow_offset = Vector2(0, 4)
	box.border_color = Color(tint if is_next else STARLIGHT, 1.0 if is_next else 0.35 * dim)
	box.set_border_width_all(4 if is_next else 2)
	draw_style_box(box, rect)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = level * 7919 + 17
	var inner: Rect2 = rect.grow(-16.0)
	var centre: Vector2 = rect.get_center()
	var drawn: int = 0
	while drawn < 7:
		var at: Vector2 = inner.position + Vector2(rng.randf(), rng.randf()) * inner.size
		# Clear of the number and the row of stars under it.
		if absf(at.x - centre.x) < 34.0 and at.y > centre.y - 38.0:
			continue
		drawn += 1
		var r: float = rng.randf_range(1.2, 2.6)
		draw_circle(at, r * 2.4, Color(STARLIGHT, 0.12 * dim), true, -1.0, true)
		draw_circle(at, r, Color(STARLIGHT, 0.85 * dim), true, -1.0, true)
	_number(rect, Color(STARLIGHT, dim), stars > 0)
	if stars > 0:
		for k: int in range(3):
			var at: Vector2 = Vector2(rect.get_center().x + (k - 1) * 22.0, rect.end.y - 26.0)
			_star(at, 9.0, Brand.GOLD if k < stars else Color(STARLIGHT, 0.3))

func _number(rect: Rect2, ink: Color, raised: bool) -> void:
	var font: Font = UI.display_font()
	var text: String = str(Shown.level(level))
	var font_size: int = 50
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline: float = rect.position.y + rect.size.y * 0.5 + font_size * 0.32 - (8.0 if raised else 0.0)
	draw_string(font, Vector2(rect.get_center().x - ts.x * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

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
