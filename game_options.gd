extends RefCounted

static func rows() -> Array[Control]:
	var lines: Array[Control] = []
	# The new street look or today's (REVAMP_PLAN.md section 3.3). Switching keeps all progress and goes to that look's
	# Home at once.
	var street: Switch = Switch.new(Save.app_look == AppLook.STREET)
	street.toggled.connect(func(on: bool) -> void:
		Save.set_app_look(AppLook.STREET if on else AppLook.CLASSIC)
		if not on:
			Appearance.apply(Save.theme)
		AppLook.use(Save.app_look)
		Screens.go(AppLook.home_scene(Save.app_look)))
	lines.append(_drawn_row("Street look", street, _House.new()))
	var faces: Switch = Switch.new(Save.faces)
	faces.toggled.connect(func(on: bool) -> void: Save.set_faces(on))
	lines.append(_drawn_row("Faces", faces, _Smile.new()))
	var pets: Switch = Switch.new(Save.pets)
	pets.toggled.connect(func(on: bool) -> void: Save.set_pets(on))
	lines.append(_drawn_row("Pets", pets, _Loaf.new()))
	if not PhoneTilt.can_feel():
		return lines
	var tip: Switch = Switch.new(Save.phone_tilt)
	tip.toggled.connect(func(on: bool) -> void: Save.set_phone_tilt(on))
	lines.append(Settings.setting_row(&"tilt", "Tilt your phone", tip))
	return lines

## The kit's icons have no face or pet, so these rows draw their own in the same line style.
static func _drawn_row(text: String, control: Control, glyph: Control) -> Control:
	var row: Control = Settings.setting_row(&"", text, control)
	var blank: Control = row.get_child(0)
	row.remove_child(blank)
	blank.queue_free()
	row.add_child(glyph)
	row.move_child(glyph, 0)
	return row

class _Glyph extends Control:
	const S: float = 50.0

	func _init() -> void:
		custom_minimum_size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _width() -> float:
		return maxf(2.0, S * 0.085)

## A marble's face, drawn as the kit draws its icons: one muted line weight, no fill.
class _Smile extends _Glyph:
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		draw_arc(c, S * 0.36, 0.0, TAU, 40, Brand.MUTED, _width(), true)
		for side: float in [-1.0, 1.0]:
			draw_circle(c + Vector2(side * 0.13, -0.07) * S, S * 0.05, Brand.MUTED, true, -1.0, true)
		draw_arc(c + Vector2(0.0, 0.02) * S, S * 0.17, PI * 0.2, PI * 0.8, 14, Brand.MUTED, _width(), true)

## A little house, for the street look.
class _House extends _Glyph:
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var w: float = _width()
		draw_polyline(PackedVector2Array([c + Vector2(-0.36, -0.02) * S, c + Vector2(0.0, -0.36) * S,
			c + Vector2(0.36, -0.02) * S]), Brand.MUTED, w, true)
		draw_polyline(PackedVector2Array([c + Vector2(-0.27, -0.08) * S, c + Vector2(-0.27, 0.32) * S,
			c + Vector2(0.27, 0.32) * S, c + Vector2(0.27, -0.08) * S]), Brand.MUTED, w, true)
		draw_arc(c + Vector2(0.0, 0.2) * S, S * 0.1, PI, TAU, 10, Brand.MUTED, w, true)

## A cat asleep in a loaf, as the walls are drawn with Pets on.
class _Loaf extends _Glyph:
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var w: float = _width()
		var outline: PackedVector2Array = PackedVector2Array([
			c + Vector2(-0.34, 0.3) * S, c + Vector2(-0.34, -0.2) * S, c + Vector2(-0.28, -0.38) * S,
			c + Vector2(-0.14, -0.24) * S, c + Vector2(0.14, -0.24) * S, c + Vector2(0.28, -0.38) * S,
			c + Vector2(0.34, -0.2) * S, c + Vector2(0.34, 0.3) * S, c + Vector2(-0.34, 0.3) * S])
		draw_polyline(outline, Brand.MUTED, w, true)
		for side: float in [-1.0, 1.0]:
			draw_arc(c + Vector2(side * 0.13, -0.06) * S, S * 0.06, PI * 0.15, PI * 0.85, 8, Brand.MUTED, w * 0.8, true)
		draw_circle(c + Vector2(0.0, 0.06) * S, S * 0.035, Brand.MUTED, true, -1.0, true)
