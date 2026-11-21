class_name StreetUI
extends RefCounted

## Street's controls, drawn as the round 2 concepts draw them (build/review/revamp2/): glossy round buttons with a
## darker rim and a white glyph, soft pills, and the chunky Baloo 2 type. Glyphs are drawn on a 1 by 1 box.

const RED: Color = Color("f2554f")
const TEAL: Color = Color("20b3a3")
const YELLOW: Color = Color("ffb21f")
const ORANGE: Color = Color("ff9d2e")
const PURPLE: Color = Color("8a63e8")
const CREAM: Color = Color("fff6e8")
const INK: Color = Color("3d2c2a")
const SHADOW: Color = Color(0.1, 0.2, 0.05, 0.22)

static func label(text: String, size: int, colour: Color = CREAM, outline: Color = Color.TRANSPARENT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", StreetArt.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if outline.a > 0.0:
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", maxi(4, size / 10))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A glossy ball of colour, as the concepts' buttons and slots: a soft drop shadow, a darker rim, the fill, and a
## highlight across its top.
static func gloss_circle(ci: CanvasItem, c: Vector2, r: float, fill: Color) -> void:
	ci.draw_circle(c + Vector2(0, r * 0.1), r * 1.02, SHADOW, true, -1.0, true)
	ci.draw_circle(c, r, fill.darkened(0.22), true, -1.0, true)
	ci.draw_circle(c + Vector2(0, -r * 0.05), r * 0.9, fill, true, -1.0, true)
	ci.draw_set_transform(c + Vector2(0, -r * 0.5), 0.0, Vector2(1.0, 0.5))
	ci.draw_circle(Vector2.ZERO, r * 0.56, Color(1, 1, 1, 0.24), true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO)

## A glossy pill: a soft shadow, a darker rim along its foot, the fill, and a highlight across its top.
static func gloss_pill(ci: CanvasItem, rect: Rect2, fill: Color) -> void:
	_capsule(ci, Rect2(rect.position + Vector2(0, rect.size.y * 0.08), rect.size), SHADOW)
	_capsule(ci, rect, fill.darkened(0.22))
	_capsule(ci, Rect2(rect.position, rect.size - Vector2(0, rect.size.y * 0.1)), fill)
	var inset: float = rect.size.y * 0.32
	_capsule(ci, Rect2(rect.position + Vector2(inset, rect.size.y * 0.1), Vector2(rect.size.x - inset * 2.0,
		rect.size.y * 0.28)), Color(1, 1, 1, 0.28))

## A capsule as one rounded box, so a translucent one never doubles up where its ends meet its middle. The boxes are
## kept by colour and radius, since pills redraw every frame (the coin pill's glint) and a new box each time is
## garbage the phone feels.
static var _capsules: Dictionary = {}

static func _capsule(ci: CanvasItem, rect: Rect2, colour: Color) -> void:
	var radius: int = int(rect.size.y * 0.5)
	var key: String = "%s/%d" % [colour.to_html(), radius]
	var box: StyleBoxFlat = _capsules.get(key, null)
	if box == null:
		# A fade makes a colour a frame, so the keep is kept small.
		if _capsules.size() > 48:
			_capsules.clear()
		box = StyleBoxFlat.new()
		box.bg_color = colour
		box.set_corner_radius_all(radius)
		box.corner_detail = 12
		box.anti_aliasing = true
		_capsules[key] = box
	ci.draw_style_box(box, rect)

## The painted icon for each glyph name, where one differs from the name.
const ICONS: Dictionary = {&"stall": "shop", &"gear": "settings"}
## The painted round buttons, by fill colour.
const BUTTONS: Dictionary = {RED: "red", TEAL: "teal", YELLOW: "yellow", ORANGE: "orange", PURPLE: "purple"}
## A painted button's ball fills this share of its canvas.
const BUTTON_FILL: float = 232.0 / 256.0

## A round button of radius `r` at `c`: the painted base in its colour where there is one, else a drawn glossy ball.
static func button(ci: CanvasItem, c: Vector2, r: float, fill: Color, tint: Color = Color.WHITE) -> void:
	if BUTTONS.has(fill):
		var piece: String = "button_" + str(BUTTONS[fill])
		StreetArt.draw(ci, piece, c, 2.0 * r / BUTTON_FILL / StreetArt.size(piece).x, tint)
	else:
		gloss_circle(ci, c, r, fill * tint)

## The concepts' short yellow dashes fanned out from either end of the pill `r`, three a side, radiating from the
## middle of its rounded end, the middle one `reach` long.
static func sparks(ci: CanvasItem, r: Rect2, reach: float, colour: Color = Color("ffc928")) -> void:
	var half: float = r.size.y * 0.5
	for side: float in [-1.0, 1.0]:
		var hub: Vector2 = r.get_center() + Vector2(side * (r.size.x * 0.5 - half), 0.0)
		for k: int in range(3):
			var a: float = (float(k) - 1.0) * 0.62
			var dir: Vector2 = Vector2(side * cos(a), sin(a))
			var from: Vector2 = hub + dir * (half + 20.0)
			var to: Vector2 = from + dir * reach * (0.75 if k != 1 else 1.0)
			ci.draw_line(from, to, colour, 10.0, true)
			ci.draw_circle(from, 5.0, colour, true, -1.0, true)
			ci.draw_circle(to, 5.0, colour, true, -1.0, true)

## A cream glyph centred at `c`, `s` pixels across: the painted icon where there is one, else drawn in code.
static func glyph(ci: CanvasItem, name: StringName, c: Vector2, s: float, colour: Color = CREAM) -> void:
	var icon: String = "icon_" + str(ICONS.get(name, name))
	if StreetArt.has(icon):
		StreetArt.draw(ci, icon, c, s / StreetArt.size(icon).x, colour if colour != CREAM else Color.WHITE)
		return
	var w: float = s * 0.11
	match name:
		&"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.26, -0.36) * s, c + Vector2(0.38, 0.0) * s,
				c + Vector2(-0.26, 0.36) * s]), colour)
		&"close":
			ci.draw_line(c + Vector2(-0.28, -0.28) * s, c + Vector2(0.28, 0.28) * s, colour, w * 1.4, true)
			ci.draw_line(c + Vector2(0.28, -0.28) * s, c + Vector2(-0.28, 0.28) * s, colour, w * 1.4, true)
		&"undo":
			ci.draw_arc(c + Vector2(0.04, 0.04) * s, s * 0.3, -PI * 0.5, PI * 0.75, 24, colour, w * 1.3, true)
			ci.draw_line(c + Vector2(0.04, -0.26) * s, c + Vector2(-0.3, -0.26) * s, colour, w * 1.3, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.42, -0.26) * s, c + Vector2(-0.16, -0.46) * s,
				c + Vector2(-0.16, -0.06) * s]), colour)
		&"restart":
			ci.draw_arc(c, s * 0.3, -PI * 0.2, PI * 1.45, 28, colour, w * 1.3, true)
			var tip: Vector2 = c + Vector2(cos(-PI * 0.2), sin(-PI * 0.2)) * s * 0.3
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(0.14, -0.06) * s, tip + Vector2(-0.12, -0.16) * s,
				tip + Vector2(-0.02, 0.14) * s]), colour)
		&"hint":
			ci.draw_circle(c + Vector2(0, -0.06) * s, s * 0.22, colour, true, -1.0, true)
			ci.draw_rect(Rect2(c + Vector2(-0.11, 0.12) * s, Vector2(0.22, 0.16) * s), colour)
			for k: int in range(5):
				var a: float = -PI * 0.5 + (k - 2) * 0.55
				ci.draw_line(c + Vector2(0, -0.06) * s + Vector2(cos(a), sin(a)) * s * 0.32,
					c + Vector2(0, -0.06) * s + Vector2(cos(a), sin(a)) * s * 0.44, colour, w, true)
		&"calendar":
			ci.draw_rect(Rect2(c + Vector2(-0.34, -0.26) * s, Vector2(0.68, 0.6) * s), colour, false, w, true)
			ci.draw_rect(Rect2(c + Vector2(-0.34, -0.26) * s, Vector2(0.68, 0.16) * s), colour)
			for k: int in range(2):
				ci.draw_line(c + Vector2(-0.16 + k * 0.32, -0.38) * s, c + Vector2(-0.16 + k * 0.32, -0.18) * s, colour,
					w, true)
			for i: int in range(3):
				for j: int in range(2):
					ci.draw_circle(c + Vector2(-0.18 + i * 0.18, 0.04 + j * 0.15) * s, s * 0.045, colour, true, -1.0, true)
		&"stall":
			for k: int in range(4):
				ci.draw_circle(c + Vector2(-0.27 + k * 0.18, -0.12) * s, s * 0.09, colour, true, -1.0, true)
			ci.draw_rect(Rect2(c + Vector2(-0.36, -0.36) * s, Vector2(0.72, 0.24) * s), colour)
			ci.draw_rect(Rect2(c + Vector2(-0.3, 0.06) * s, Vector2(0.6, 0.3) * s), colour, false, w, true)
		&"gear":
			for k: int in range(8):
				var a: float = TAU * k / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.2, c + Vector2(cos(a), sin(a)) * s * 0.4, colour, s * 0.16)
			ci.draw_circle(c, s * 0.3, colour, true, -1.0, true)
			ci.draw_circle(c, s * 0.12, Color(0, 0, 0, 0.2), true, -1.0, true)
		&"lock":
			ci.draw_arc(c + Vector2(0, -0.08) * s, s * 0.17, PI, TAU, 16, colour, w * 1.2, true)
			ci.draw_rect(Rect2(c + Vector2(-0.24, -0.08) * s, Vector2(0.48, 0.38) * s), colour)
		&"footprints":
			for k: int in range(2):
				var o: Vector2 = Vector2(-0.14 + k * 0.28, 0.06 - k * 0.14) * s
				ci.draw_set_transform(c + o, -0.2 + k * 0.4, Vector2(0.7, 1.0))
				ci.draw_circle(Vector2(0, 0.06 * s), s * 0.13, colour, true, -1.0, true)
				ci.draw_set_transform(Vector2.ZERO)
				for t: int in range(3):
					ci.draw_circle(c + o + Vector2((t - 1) * 0.07, -0.16) * s, s * 0.035, colour, true, -1.0, true)
		&"ghosts":
			for k: int in range(3):
				var at: Vector2 = c + Vector2(-0.2 + k * 0.2, 0.1 - (0.22 if k == 1 else 0.0)) * s
				ci.draw_circle(at, s * (0.17 if k == 1 else 0.14), colour, true, -1.0, true)
				ci.draw_circle(at + Vector2(-0.05, -0.02) * s, s * 0.025, StreetUI.INK, true, -1.0, true)
				ci.draw_circle(at + Vector2(0.05, -0.02) * s, s * 0.025, StreetUI.INK, true, -1.0, true)
		&"home":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.36, -0.02) * s, c + Vector2(0, -0.36) * s,
				c + Vector2(0.36, -0.02) * s]), colour)
			ci.draw_rect(Rect2(c + Vector2(-0.26, -0.04) * s, Vector2(0.52, 0.36) * s), colour)


## A round, glossy button with a glyph, which squashes when pressed and springs back.
class RoundButton extends Button:
	## Breathing at rest: this deep, this fast. Each button starts at its own point in the breath.
	const BREATHE: float = 0.025
	const BREATHE_SPEED: float = 1.9

	var fill: Color = StreetUI.RED
	var symbol: StringName = &"play"
	var _spring: Jiggle = Jiggle.new()
	var _t: float = randf() * TAU

	func _init(colour: Color, glyph_name: StringName, diameter: float) -> void:
		fill = colour
		symbol = glyph_name
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(diameter, diameter)
		size = custom_minimum_size
		button_down.connect(_press)
		resized.connect(func() -> void: pivot_offset = size * 0.5)

	func _ready() -> void:
		pivot_offset = size * 0.5

	## A press squashes it on the tap wobble's spring, with a tap and a tick, or dims it under Reduce motion.
	func _press() -> void:
		Audio.play(&"tap", -10.0)
		Audio.buzz(10, 0.3)
		if Save.reduce_motion:
			var t: Tween = create_tween()
			t.tween_property(self, "modulate:a", StreetWobbler.FADE_TO, StreetWobbler.FADE_TIME * 0.4)
			t.tween_property(self, "modulate:a", 1.0, StreetWobbler.FADE_TIME * 0.6)
			return
		_spring.kick(1.4)

	func _process(delta: float) -> void:
		_t += delta
		_spring.step(delta)
		var breath: float = 0.0 if Save.reduce_motion or disabled else BREATHE * sin(_t * BREATHE_SPEED)
		scale = _spring.squash() * (1.0 + breath)
		rotation = _spring.tilt()

	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.5
		StreetUI.button(self, size * 0.5, r, fill, Color(0.7, 0.7, 0.7) if disabled else Color.WHITE)
		StreetUI.glyph(self, symbol, size * 0.5 + Vector2(0, -r * 0.03), r * 1.25)
