extends Node

## Clips of the party (Celebration), recorded by Movie Maker.
## Run: godot --path . --fixed-fps 60 --write-movie out.avi res://tools/celebrate_shots.tscn -- clip=CLIP
##   CLIP: win (a three-star win, its sheet, then Levels), chapter (the win that finishes chapter 1), hard (the win
##   that finishes Hard's first chapter), skip (a win tapped through to the sheet) or home.
## Uses a throwaway save file. The window is the project's 405 by 720 unless an override.cfg sets another.

const WIN_LEVEL: int = 24

func _ready() -> void:
	Save.path = "user://celebrate.cfg"
	Save.faces = true
	Save.pets = false
	Save.daily = {}
	Coach.enabled = false
	Intro.enabled = false
	ChapterCard.enabled = false
	var clip: String = "win"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("clip="):
			clip = arg.substr(5)
	# The driver sits on the root, not in the scene, so it lives through the screen changes it records.
	var driver: _Driver = _Driver.new()
	driver.clip = clip
	get_tree().root.add_child.call_deferred(driver)

class _Driver extends Node:
	var clip: String = "win"

	func _ready() -> void:
		match clip:
			"home":
				_progress(WIN_LEVEL)
				get_tree().change_scene_to_file(Brand.TITLE_SCENE)
				await _wait(6.0)
			"chapter":
				var last: int = int(Pack.chapters[0]["count"]) - 1
				_progress(last)
				await _play(last, 7.2)
			"hard":
				Pack.use(Pack.Section.HARD)
				var c: int = Pack.chapter_of(Pack.hard_from)
				var last: int = Pack.chapter_first(c) + int(Pack.chapters[c]["count"]) - 1
				var stars: PackedByteArray = PackedByteArray()
				stars.resize(last)
				for i: int in range(Pack.hard_from, last):
					stars[i] = 3
				Save.hard_stars = stars
				_progress(Pack.hard_from)
				await _play(last, 7.2)
			"skip":
				_progress(WIN_LEVEL)
				await _play(WIN_LEVEL, 3.0, true)
			_:
				_progress(WIN_LEVEL)
				await _play(WIN_LEVEL, 5.2)
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://celebrate.cfg"))
		get_tree().quit()

	## Every level of the main path before `level` solved with three stars.
	func _progress(level: int) -> void:
		var stars: PackedByteArray = PackedByteArray()
		stars.resize(level)
		stars.fill(3)
		Save.stars = stars

	## The level solved in par, then `settle` seconds for its party and sheet, then on to Levels, where the level it
	## opened pops. With `tap`, a tap half a second into the party skips it.
	func _play(level: int, settle: float, tap: bool = false) -> void:
		Pack.current = level
		get_tree().change_scene_to_file(Brand.GAME_SCENE)
		await _wait(1.1)
		var game: Node = get_tree().current_scene
		for dir: int in TiltSolver.new().solve(game.get("board")):
			game.call("_tilt", dir)
			while game.get("_view").busy:
				await get_tree().process_frame
			await _wait(0.4)
		if tap:
			await _wait(1.0)
			var press: InputEventScreenTouch = InputEventScreenTouch.new()
			press.pressed = true
			press.position = Vector2(360, 640)
			Input.parse_input_event(press)
		await _wait(settle)
		game.call("_to_levels")
		await _wait(3.4)

	func _wait(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout
