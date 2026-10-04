class_name Settings
extends RefCounted

## The settings sheet, reachable from every screen, in four calm groups: sound, music and vibration as
## three tiles that light up when on; the theme; the colours and the game's looks as two cards that show
## what is picked; and a row of round buttons for the guide, the shop, About and Credits. The consent
## choices, where the law asks for them, a guarded reset and the version line sit quietly at the foot.

const RESET_ARM_TIME: float = 3.0
const TOGGLE_SIZE: Vector2 = Vector2(184, 128)
const CARD_SIZE: Vector2 = Vector2(296, 112)
const FOOT_HEIGHT: float = 76.0
const FOOT_FONT: int = 28

static func open(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Settings", 56))
	var toggles: HBoxContainer = _row_of(16)
	toggles.add_child(_Toggle.new(&"sound", &"sound_off", "Sound", Save.sound_on, func(on: bool) -> void: Save.set_sound(on)))
	if Brand.HAS_MUSIC:
		toggles.add_child(_Toggle.new(&"music", &"music_off", "Music", Save.music_on, func(on: bool) -> void: Save.set_music(on)))
	toggles.add_child(_Toggle.new(&"haptics", &"haptics_off", "Vibration", Save.haptics_on,
		func(on: bool) -> void: Save.set_haptics(on)))
	c.add_child(toggles)
	var looks: Segmented = Segmented.new(Appearance.NAMES, Save.theme)
	looks.chosen.connect(func(choice: int) -> void:
		Appearance.choose(choice, host.get_tree(), func(scene: Node) -> void: Settings.open(scene)))
	c.add_child(_row(&"theme", "Theme", looks))
	var cards: HBoxContainer = _row_of(16)
	cards.add_child(_card(&"palette", "Colours", Themes.name_of(Themes.current()), func() -> void: Themes.open(host)))
	cards.add_child(_card(&"looks", GameLooks.TITLE, Looks.name_of(Looks.current()), func() -> void: Looks.open(host)))
	c.add_child(cards)
	var more: HBoxContainer = _row_of(44)
	more.add_child(UI.action(&"help", "How to play", func() -> void:
		sheet.close()
		Coach.replay()))
	more.add_child(UI.action(&"shop" if Supporter.on_play else &"heart", "Shop" if Supporter.on_play else "Support",
		func() -> void: Shop.open(host)))
	more.add_child(UI.action(&"info", "About", func() -> void: About.open(host)))
	more.add_child(UI.action(&"people", "Credits", func() -> void: Credits.open(host)))
	c.add_child(more)
	var foot: HBoxContainer = _row_of(8)
	if Ads.privacy_options_required():
		var privacy: Button = _quiet("Privacy choices")
		privacy.pressed.connect(Ads.open_privacy_options)
		foot.add_child(privacy)
	var reset: Button = _quiet("Reset progress")
	var armed: Array[bool] = [false]
	reset.pressed.connect(func() -> void:
		if armed[0]:
			Save.reset()
			reset.text = "Progress reset"
			reset.disabled = true
			return
		armed[0] = true
		reset.text = "Tap again to erase every star"
		reset.add_theme_color_override("font_color", Brand.DANGER)
		await host.get_tree().create_timer(RESET_ARM_TIME).timeout
		if is_instance_valid(reset) and not reset.disabled:
			armed[0] = false
			reset.text = "Reset progress"
			reset.remove_theme_color_override("font_color"))
	foot.add_child(reset)
	c.add_child(foot)
	var version: String = Changelog.version()
	var named: String = "%s %s" % [Brand.NAME, version] if version != "" else Brand.NAME
	c.add_child(UI.caption(named + "   made with godot", 20))
	return sheet

static func _row_of(gap: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", gap)
	return row

static func _row(icon: StringName, text: String, control: Control) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var glyph: _Glyph = _Glyph.new()
	glyph.icon = icon
	row.add_child(glyph)
	var l: Label = UI.label(text, 34)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return row

## A card that opens a picker: an icon in an accent disc, what it picks, and what is picked now.
static func _card(icon: StringName, title: String, value: String, pick: Callable) -> Button:
	var card: Button = Button.new()
	card.theme_type_variation = "SecondaryButton"
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", _card_box(Brand.SURFACE))
	card.add_theme_stylebox_override("hover", _card_box(Brand.SURFACE.lightened(0.04)))
	card.add_theme_stylebox_override("pressed", _card_box(Brand.SURFACE.darkened(0.05)))
	UI.press_feedback(card)
	card.pressed.connect(func() -> void: Audio.play(&"tap", -8.0))
	card.pressed.connect(pick)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18.0
	row.offset_right = -14.0
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var glyph: _Glyph = _Glyph.new()
	glyph.icon = icon
	glyph.disc = true
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var words: VBoxContainer = VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading: Label = UI.label(title, 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.add_child(heading)
	var now: Label = UI.label(value, 22, Brand.MUTED)
	now.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	now.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	now.clip_text = true
	words.add_child(now)
	row.add_child(words)
	return card

static func _card_box(fill: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Brand.LINE
	box.set_border_width_all(2)
	box.set_corner_radius_all(30)
	box.shadow_color = Brand.SHADOW
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	box.anti_aliasing = true
	return box

static func _quiet(text: String) -> Button:
	var b: Button = UI.button(text, UI.Style.GHOST)
	b.custom_minimum_size.y = FOOT_HEIGHT
	b.add_theme_font_size_override("font_size", FOOT_FONT)
	return b

## A switch as a tile: its icon over its name, lit in the accent while on, its off icon when off.
class _Toggle extends Button:
	var on: bool = true
	var _on_icon: StringName
	var _off_icon: StringName
	var _glyph: _Glyph
	var _label: Label

	func _init(on_icon: StringName, off_icon: StringName, text_shown: String, start_on: bool, apply: Callable) -> void:
		on = start_on
		_on_icon = on_icon
		_off_icon = off_icon
		custom_minimum_size = Settings.TOGGLE_SIZE
		focus_mode = Control.FOCUS_NONE
		var column: VBoxContainer = VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 2)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		_glyph = _Glyph.new()
		_glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(_glyph)
		_label = UI.label(text_shown, 26)
		column.add_child(_label)
		UI.press_feedback(self)
		pressed.connect(func() -> void:
			Audio.play(&"tap", -8.0)
			on = not on
			apply.call(on)
			_dress())
		_dress()

	func _dress() -> void:
		var fill: Color = Color(Brand.ACCENT, 0.16) if on else Brand.SURFACE
		for state: String in ["normal", "hover", "pressed"]:
			var box: StyleBoxFlat = Settings._card_box(fill if state != "pressed" else fill.darkened(0.05))
			box.border_color = Color(Brand.ACCENT, 0.5) if on else Brand.LINE
			box.shadow_size = 0 if on else 10
			add_theme_stylebox_override(state, box)
		_glyph.icon = _on_icon if on else _off_icon
		_glyph.colour = Brand.ACCENT if on else Brand.MUTED
		_glyph.queue_redraw()
		_label.add_theme_color_override("font_color", Brand.INK if on else Brand.MUTED)

class _Glyph extends Control:
	var icon: StringName = &"sound"
	var colour: Color = Brand.MUTED
	## Drawn on a soft disc of the accent, in the accent.
	var disc: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if disc:
			draw_circle(size * 0.5, size.x * 0.5, Color(Brand.ACCENT, 0.14), true, -1.0, true)
			Icons.draw(self, icon, size * 0.5, 40.0, Brand.ACCENT)
			return
		Icons.draw(self, icon, size * 0.5, 50.0, colour)
