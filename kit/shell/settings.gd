class_name Settings
extends RefCounted

## The settings sheet, reachable from every screen: switches for sound, music and haptics, the theme,
## the first level's guide again, the colour themes, the game's looks and the shop, the About and Credits
## sheets, the consent choices where the law asks for them, a guarded reset, and the version line.

const RESET_ARM_TIME: float = 3.0
## The two quiet buttons at the foot sit closer when there are two, so the sheet still fits a 16:9 phone.
const FOOT_PAIR_HEIGHT: float = 76.0
const FOOT_PAIR_FONT: int = 30

static func open(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Settings", 56))
	c.add_child(UI.spacer(4))
	c.add_child(_row(&"sound", "Sound", _switch(Save.sound_on, func(on: bool) -> void: Save.set_sound(on))))
	if Brand.HAS_MUSIC:
		c.add_child(_row(&"music", "Music", _switch(Save.music_on, func(on: bool) -> void: Save.set_music(on))))
	c.add_child(_row(&"haptics", "Vibration", _switch(Save.haptics_on, func(on: bool) -> void: Save.set_haptics(on))))
	var looks: Segmented = Segmented.new(Appearance.NAMES, Save.theme)
	looks.chosen.connect(func(choice: int) -> void:
		Appearance.choose(choice, host.get_tree(), func(scene: Node) -> void: Settings.open(scene)))
	c.add_child(_row(&"theme", "Theme", looks))
	c.add_child(UI.spacer(6))
	# The guide and the colour themes share a row, as the looks and the shop share the next.
	var help: HBoxContainer = HBoxContainer.new()
	help.alignment = BoxContainer.ALIGNMENT_CENTER
	help.add_theme_constant_override("separation", 20)
	var guide: Button = UI.button("How to play", UI.Style.SECONDARY)
	guide.pressed.connect(func() -> void:
		sheet.close()
		Coach.replay())
	help.add_child(guide)
	var colours: Button = UI.button("Colours", UI.Style.SECONDARY)
	colours.pressed.connect(func() -> void: Themes.open(host))
	help.add_child(colours)
	c.add_child(help)
	# Looks and the shop share a row, so the sheet still fits a 16:9 phone. Off Google Play the shop is the
	# way to support the game.
	var extras: HBoxContainer = HBoxContainer.new()
	extras.alignment = BoxContainer.ALIGNMENT_CENTER
	extras.add_theme_constant_override("separation", 20)
	var looks_button: Button = UI.button(GameLooks.TITLE, UI.Style.SECONDARY)
	looks_button.pressed.connect(func() -> void: Looks.open(host))
	extras.add_child(looks_button)
	var support: Button = UI.button("Shop" if Supporter.on_play else "Support", UI.Style.SECONDARY)
	support.pressed.connect(func() -> void: Shop.open(host))
	extras.add_child(support)
	c.add_child(extras)
	var more: HBoxContainer = HBoxContainer.new()
	more.alignment = BoxContainer.ALIGNMENT_CENTER
	more.add_theme_constant_override("separation", 20)
	var about: Button = UI.button("About", UI.Style.SECONDARY)
	about.pressed.connect(func() -> void: About.open(host))
	more.add_child(about)
	var credits: Button = UI.button("Credits", UI.Style.SECONDARY)
	credits.pressed.connect(func() -> void: Credits.open(host))
	more.add_child(credits)
	c.add_child(more)
	var reset: Button = UI.button("Reset progress", UI.Style.GHOST)
	if Ads.privacy_options_required():
		var privacy: Button = UI.button("Privacy choices", UI.Style.GHOST)
		privacy.pressed.connect(Ads.open_privacy_options)
		for quiet: Button in [privacy, reset]:
			quiet.custom_minimum_size.y = FOOT_PAIR_HEIGHT
			quiet.add_theme_font_size_override("font_size", FOOT_PAIR_FONT)
		c.add_child(privacy)
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
	c.add_child(reset)
	var version: String = Changelog.version()
	var named: String = "%s %s" % [Brand.NAME, version] if version != "" else Brand.NAME
	c.add_child(UI.caption(named + "   made with godot", 20))
	return sheet

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

static func _switch(on: bool, apply: Callable) -> Switch:
	var toggle: Switch = Switch.new(on)
	toggle.toggled.connect(apply)
	return toggle

class _Glyph extends Control:
	var icon: StringName = &"sound"

	func _init() -> void:
		custom_minimum_size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Icons.draw(self, icon, size * 0.5, 50.0, Brand.MUTED)
