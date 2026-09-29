extends Node2D

## The front door: the name, a toy that shows what the game is before any words do, and two ways in.

var _sound: Button
var _music: Button
var _seesaw: Seesaw
var _stage: Control

func _ready() -> void:
	var ui: Control = UI.root(self)
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	ui.add_child(column)

	var logo: Label = UI.label("plumb", 190)
	column.add_child(logo)
	var tagline: Label = UI.label("Roll every marble home", 36, Palette.MUTED)
	column.add_child(tagline)

	# Room for the seesaw, which is drawn in the world behind the UI.
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(0, 250)
	column.add_child(_stage)

	var play_text: String = "Play"
	var frontier: int = Save.frontier(Pack.count())
	if Save.total_stars() > 0:
		play_text = "Continue: level %d" % (frontier + 1)
	var play: Button = UI.button(play_text, true)
	play.custom_minimum_size = Vector2(420, 0)
	play.pressed.connect(func() -> void:
		Pack.current = frontier
		Screens.go("res://scenes/game/game.tscn"))
	_centred(column, play)
	var levels: Button = UI.button("Levels")
	levels.custom_minimum_size = Vector2(420, 0)
	levels.pressed.connect(func() -> void: Screens.go("res://scenes/shell/levels.tscn"))
	_centred(column, levels)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -120.0
	footer.offset_bottom = -40.0
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 30)
	ui.add_child(footer)
	_sound = UI.button("")
	_sound.pressed.connect(func() -> void:
		Save.set_sound(not Save.sound_on)
		_label_sound())
	footer.add_child(_sound)
	_music = UI.button("")
	_music.pressed.connect(func() -> void:
		Save.set_music(not Save.music_on)
		_label_sound())
	footer.add_child(_music)
	_label_sound()
	var stars: HBoxContainer = HBoxContainer.new()
	stars.add_theme_constant_override("separation", 10)
	stars.add_child(StarIcon.new(40.0, true))
	stars.add_child(UI.label("%d / %d" % [Save.total_stars(), Pack.count() * 3], 32, Palette.MUTED))
	footer.add_child(stars)

	_seesaw = Seesaw.new()
	add_child(_seesaw)
	_stage.resized.connect(_place)
	_place()

## Centred in the space the column left for it, wherever the layout put that on this screen shape.
func _place() -> void:
	_seesaw.position = _stage.get_global_rect().get_center() + Vector2(0, 10)

func _centred(column: VBoxContainer, control: Control) -> void:
	var row: CenterContainer = CenterContainer.new()
	row.add_child(control)
	column.add_child(row)

func _label_sound() -> void:
	_sound.text = "Sound: on" if Save.sound_on else "Sound: off"
	_music.text = "Music: on" if Save.music_on else "Music: off"
