class_name Settings
extends RefCounted

## The settings sheet, reachable from every screen, in calm groups: how loud the sounds and the music are,
## each a slider whose icon mutes it at a tap, and vibration; the theme; the colours and the game's looks
## as two cards that show what is picked; and a row of round buttons for the guide, the shop, About and
## Credits. The consent choices, where the law asks for them, a guarded reset and the version line sit
## quietly at the foot.

const RESET_ARM_TIME: float = 3.0
const CARD_SIZE: Vector2 = Vector2(296, 112)
const FOOT_HEIGHT: float = 76.0
const FOOT_FONT: int = 28
## The least time between the ticks the sound slider plays, so a drag sounds like a few taps, not a buzz.
const TICK_GAP: int = 140

static func open(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Settings", 56))
	c.add_child(_volume(&"sound", &"sound_off", "Sound", Save.sound_volume, Save.hear_sound_volume, Save.set_sound_volume,
		true))
	if Brand.HAS_MUSIC:
		c.add_child(_volume(&"music", &"music_off", "Music", Save.music_volume, Save.hear_music_volume,
			Save.set_music_volume, false))
	var buzz: Switch = Switch.new(Save.haptics_on)
	buzz.toggled.connect(func(on: bool) -> void: Save.set_haptics(on))
	c.add_child(_row(&"haptics", "Vibration", buzz))
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

## A volume: its icon, which mutes it at a tap and brings it back at the next, its name, and its slider.
## `hear` takes each step of a drag and `keep` the place it rests at; the sound slider ticks as it moves.
static func _volume(icon: StringName, muted_icon: StringName, text: String, start: float, hear: Callable, keep: Callable,
		ticks: bool) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var mute: _Mute = _Mute.new(icon, muted_icon, start <= 0.0)
	row.add_child(mute)
	var l: Label = UI.label(text, 34)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var slider: VolumeSlider = VolumeSlider.new(start)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	# The level to come back to after a mute, and the time of the last tick.
	var back: Array[float] = [start if start > 0.0 else 1.0]
	var ticked: Array[int] = [0]
	slider.value_changed.connect(func(v: float) -> void:
		hear.call(v)
		Audio.hear()
		mute.muted = v <= 0.0
		if ticks and v > 0.0 and Time.get_ticks_msec() - ticked[0] >= TICK_GAP:
			ticked[0] = Time.get_ticks_msec()
			Audio.play(&"tap", -4.0))
	slider.released.connect(func(v: float) -> void:
		if v > 0.0:
			back[0] = v
		keep.call(v))
	mute.pressed.connect(func() -> void:
		if slider.value > 0.0:
			back[0] = slider.value
			slider.value = 0.0
		else:
			slider.value = back[0]
		keep.call(slider.value))
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
	var card: Button = UI.card(CARD_SIZE)
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

static func _quiet(text: String) -> Button:
	var b: Button = UI.button(text, UI.Style.GHOST)
	b.custom_minimum_size.y = FOOT_HEIGHT
	b.add_theme_font_size_override("font_size", FOOT_FONT)
	return b

## A volume's icon as a button: the sound or the music sign, and its crossed-out sign while muted.
class _Mute extends BaseButton:
	var muted: bool = false:
		set(value):
			muted = value
			queue_redraw()
	var _icon: StringName
	var _muted_icon: StringName

	func _init(icon: StringName, muted_icon: StringName, start_muted: bool) -> void:
		_icon = icon
		_muted_icon = muted_icon
		muted = start_muted
		custom_minimum_size = Vector2(56, 56)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UI.press_feedback(self)

	func _draw() -> void:
		Icons.draw(self, _muted_icon if muted else _icon, size * 0.5, 50.0, Brand.MUTED if muted else Brand.ACCENT)

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
