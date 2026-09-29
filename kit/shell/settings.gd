class_name Settings
extends RefCounted

## The settings sheet: switches for sound, music and haptics, a guarded reset, and the version line.

const RESET_ARM_TIME: float = 3.0

## `music` false leaves out the music switch, for a game with no music to turn off.
static func open(host: Node, music: bool = true) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Settings", 56))
	c.add_child(UI.spacer(4))
	c.add_child(_row(&"sound", "Sound", Save.sound_on, func(on: bool) -> void: Save.set_sound(on)))
	if music:
		c.add_child(_row(&"music", "Music", Save.music_on, func(on: bool) -> void: Save.set_music(on)))
	c.add_child(_row(&"haptics", "Vibration", Save.haptics_on, func(on: bool) -> void: Save.set_haptics(on)))
	c.add_child(UI.spacer(6))
	var reset: Button = UI.button("Reset progress", UI.Style.GHOST)
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
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	c.add_child(UI.caption("%s %s   made with godot" % [Brand.NAME, version], 20))
	return sheet

static func _row(icon: StringName, text: String, on: bool, apply: Callable) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var glyph: _Glyph = _Glyph.new()
	glyph.icon = icon
	row.add_child(glyph)
	var l: Label = UI.label(text, 34)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var toggle: Switch = Switch.new(on)
	toggle.toggled.connect(apply)
	row.add_child(toggle)
	return row

class _Glyph extends Control:
	var icon: StringName = &"sound"

	func _init() -> void:
		custom_minimum_size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Icons.draw(self, icon, size * 0.5, 50.0, Brand.MUTED)
