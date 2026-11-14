extends RefCounted

static func rows() -> Array[Control]:
	var lines: Array[Control] = []
	var faces: Switch = Switch.new(Save.faces)
	faces.toggled.connect(func(on: bool) -> void: Save.set_faces(on))
	var row: Control = Settings.setting_row(&"", "Faces", faces)
	# The kit's icons have no face, so this row draws its own in the same line style.
	var glyph: Control = row.get_child(0)
	row.remove_child(glyph)
	glyph.queue_free()
	var smile: _Smile = _Smile.new()
	row.add_child(smile)
	row.move_child(smile, 0)
	lines.append(row)
	if not PhoneTilt.can_feel():
		return lines
	var tip: Switch = Switch.new(Save.phone_tilt)
	tip.toggled.connect(func(on: bool) -> void: Save.set_phone_tilt(on))
	lines.append(Settings.setting_row(&"tilt", "Tilt your phone", tip))
	return lines

## A marble's face drawn as the kit draws its icons: one muted line weight, no fill.
class _Smile extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var s: float = 50.0
		var w: float = maxf(2.0, s * 0.085)
		draw_arc(c, s * 0.36, 0.0, TAU, 40, Brand.MUTED, w, true)
		for side: float in [-1.0, 1.0]:
			draw_circle(c + Vector2(side * 0.13, -0.07) * s, s * 0.05, Brand.MUTED, true, -1.0, true)
		draw_arc(c + Vector2(0.0, 0.02) * s, s * 0.17, PI * 0.2, PI * 0.8, 14, Brand.MUTED, w, true)
