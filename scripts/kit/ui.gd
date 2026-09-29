class_name UI
extends RefCounted

## The look of every screen, built in code: one rounded face at a few sizes, soft pill buttons, and a
## primary variation for the one action a screen wants you to take.

const FONT_PATH: String = "res://assets/fonts/Baloo2.ttf"

static var _theme: Theme

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	var font: FontFile = load(FONT_PATH)
	t.default_font = font
	t.default_font_size = 34
	t.set_color("font_color", "Label", Palette.INK)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", _pill(state, Palette.PANEL, Palette.TRAY))
		t.set_stylebox(state, "PrimaryButton", _pill(state, Palette.marble(0), Palette.marble(0).darkened(0.25)))
	t.set_type_variation("PrimaryButton", "Button")
	for kind: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(kind, "Button", Palette.INK)
		t.set_color(kind, "PrimaryButton", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Palette.MUTED)
	t.set_font_size("font_size", "Button", 36)
	_theme = t
	return t

static func _pill(state: String, fill: Color, lip: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	if state == "hover":
		box.bg_color = fill.lightened(0.06)
	elif state == "pressed":
		box.bg_color = fill.darkened(0.08)
	elif state == "disabled":
		box.bg_color = fill.lerp(Palette.BG, 0.6)
	elif state == "focus":
		box.draw_center = false
	box.set_corner_radius_all(30)
	box.content_margin_left = 34
	box.content_margin_right = 34
	box.content_margin_top = 12
	box.content_margin_bottom = 16
	# A darker lip under the button, taller at rest and pressed flat, is the whole of the tactile feel.
	if state != "focus":
		box.border_color = lip
		box.border_width_bottom = 2 if state == "pressed" else 7
	box.anti_aliasing = true
	return box

static func label(text: String, size: int, colour: Color = Palette.INK) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

static func button(text: String, primary: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = text
	if primary:
		b.theme_type_variation = "PrimaryButton"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: Audio.play(&"tap", -6.0))
	return b

## A screen-sized root Control with the theme applied. Screens build their layout inside it.
static func root(owner: Node) -> Control:
	var layer: CanvasLayer = CanvasLayer.new()
	owner.add_child(layer)
	var r: Control = Control.new()
	r.theme = theme()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	return r
