class_name UI
extends RefCounted

## The shared look: two weights of one geometric face, flat pills with soft shadows, and helpers that
## every screen builds from. Colours and fonts come from the game's `Brand`, so the same kit dresses a
## warm paper game and a night-sky one.
##
## The kit expects the game to provide: a `Brand` class (names, colours, fonts and scene paths, as in
## any game's brand.gd), and the autoloads `Save`, `Pack`, `Screens` and `Audio`.

enum Style { PRIMARY, SECONDARY, GHOST }

## Press feedback: how far a pill sinks and how long it takes to come back.
const PRESS_SCALE: float = 0.965
const PRESS_TIME: float = 0.08
const RELEASE_TIME: float = 0.22
const PILL_HEIGHT: float = 104.0

static var _theme: Theme
static var _display: Font
static var _ui: Font
static var _caption: FontVariation

static func display_font() -> Font:
	if _display == null:
		_display = load(Brand.FONT_DISPLAY)
	return _display

static func ui_font() -> Font:
	if _ui == null:
		_ui = load(Brand.FONT_UI)
	return _ui

## The UI face with extra tracking, for small upper-case labels.
static func caption_font() -> FontVariation:
	if _caption == null:
		_caption = FontVariation.new()
		_caption.base_font = ui_font()
		_caption.spacing_glyph = 3
	return _caption

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = ui_font()
	t.default_font_size = 32
	t.set_color("font_color", "Label", Brand.INK)
	t.set_type_variation("PrimaryButton", "Button")
	t.set_type_variation("SecondaryButton", "Button")
	t.set_type_variation("GhostButton", "Button")
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", _pill(state, Style.SECONDARY))
		t.set_stylebox(state, "SecondaryButton", _pill(state, Style.SECONDARY))
		t.set_stylebox(state, "PrimaryButton", _pill(state, Style.PRIMARY))
		t.set_stylebox(state, "GhostButton", _pill(state, Style.GHOST))
	for kind: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(kind, "Button", Brand.INK)
		t.set_color(kind, "SecondaryButton", Brand.INK)
		t.set_color(kind, "PrimaryButton", Brand.ACCENT_INK)
		t.set_color(kind, "GhostButton", Brand.MUTED)
	t.set_color("font_hover_color", "GhostButton", Brand.INK)
	for kind: String in ["Button", "SecondaryButton", "PrimaryButton", "GhostButton"]:
		t.set_color("font_disabled_color", kind, Color(Brand.MUTED, 0.5))
		t.set_font_size("font_size", kind, 34)
	_theme = t
	return t

static func _pill(state: String, style: Style) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.set_corner_radius_all(int(PILL_HEIGHT * 0.5))
	box.content_margin_left = 44
	box.content_margin_right = 44
	box.content_margin_top = 20
	box.content_margin_bottom = 22
	box.anti_aliasing = true
	if state == "focus":
		box.draw_center = false
		return box
	match style:
		Style.PRIMARY:
			box.bg_color = Brand.ACCENT
			box.shadow_color = Color(Brand.ACCENT.darkened(0.5), 0.28)
			box.shadow_size = 22
			box.shadow_offset = Vector2(0, 10)
		Style.SECONDARY:
			box.bg_color = Brand.SURFACE
			box.border_color = Brand.LINE
			box.set_border_width_all(2)
			box.shadow_color = Brand.SHADOW
			box.shadow_size = 12
			box.shadow_offset = Vector2(0, 5)
		Style.GHOST:
			box.bg_color = Color(0, 0, 0, 0)
	match state:
		"hover":
			box.bg_color = box.bg_color.lightened(0.04) if style != Style.GHOST else Color(Brand.INK, 0.05)
		"pressed":
			box.bg_color = box.bg_color.darkened(0.05) if style != Style.GHOST else Color(Brand.INK, 0.08)
			box.shadow_size = int(box.shadow_size * 0.5)
			box.shadow_offset *= 0.4
		"disabled":
			box.bg_color = Color(box.bg_color, box.bg_color.a * 0.45)
			box.shadow_size = 0
	return box

# --- Text ---------------------------------------------------------------------------------------------

static func label(text: String, size: int = 32, colour: Color = Brand.INK) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Large text in the light display weight: wordmarks, screen titles, results.
static func title(text: String, size: int, colour: Color = Brand.INK) -> Label:
	var l: Label = label(text, size, colour)
	l.add_theme_font_override("font", display_font())
	return l

## Small, spaced, upper-case: section names and labels above numbers.
static func caption(text: String, size: int = 22, colour: Color = Brand.MUTED) -> Label:
	var l: Label = label(text.to_upper(), size, colour)
	l.add_theme_font_override("font", caption_font())
	return l

# --- Buttons ------------------------------------------------------------------------------------------

static func button(text: String, style: Style = Style.SECONDARY) -> Button:
	var b: Button = Button.new()
	b.text = text
	match style:
		Style.PRIMARY:
			b.theme_type_variation = "PrimaryButton"
		Style.GHOST:
			b.theme_type_variation = "GhostButton"
		_:
			b.theme_type_variation = "SecondaryButton"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = PILL_HEIGHT
	press_feedback(b)
	b.pressed.connect(func() -> void: Audio.play(&"tap", -8.0))
	return b

static func icon_button(icon: StringName, label_text: String = "") -> IconButton:
	var b: IconButton = IconButton.new()
	b.icon_name = icon
	b.tooltip_text = label_text
	return b

## A small sink on press and a spring back, plus a haptic tick. What makes a flat button feel physical.
static func press_feedback(control: Control) -> void:
	control.resized.connect(func() -> void: control.pivot_offset = control.size * 0.5)
	var base: BaseButton = control as BaseButton
	if base == null:
		return
	base.button_down.connect(func() -> void:
		control.create_tween().tween_property(control, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), PRESS_TIME)
		Audio.buzz(6))
	base.button_up.connect(func() -> void:
		control.create_tween().tween_property(control, "scale", Vector2.ONE, RELEASE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

# --- Layout -------------------------------------------------------------------------------------------

## A screen-sized root Control with the theme applied, inside its own CanvasLayer.
static func root(owner: Node, layer: int = 1) -> Control:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = layer
	owner.add_child(canvas)
	var r: Control = Control.new()
	r.theme = theme()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(r)
	return r

## Margins that keep controls clear of notches and rounded corners, in viewport units. Only phones
## report a meaningful safe area; on desktop and web the screen's safe area is not the window's.
static func safe_margins(viewport: Viewport) -> Dictionary:
	var out: Dictionary = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if not OS.has_feature("mobile"):
		return out
	var screen: Vector2 = Vector2(DisplayServer.screen_get_size())
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	var view: Vector2 = viewport.get_visible_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0:
		return out
	var k: Vector2 = view / screen
	out["top"] = safe.position.y * k.y
	out["left"] = safe.position.x * k.x
	out["bottom"] = (screen.y - safe.end.y) * k.y
	out["right"] = (screen.x - safe.end.x) * k.x
	return out

static func spacer(height: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func centred(child: Control) -> CenterContainer:
	var c: CenterContainer = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(child)
	return c
