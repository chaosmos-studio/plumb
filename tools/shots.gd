extends Node

## Screenshots of every screen and state worth looking at, in one run, for reviewing the look.
## Run: DISPLAY=:0 godot --path . --resolution 720x1280 res://tools/shots.tscn
## Saves user://shots/<name>.png and prints each path. Uses a throwaway save file.

func _ready() -> void:
	Save.path = "user://shots.cfg"
	Save.stars = PackedByteArray([3, 3, 2, 1, 3])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	await _shoot_scene("res://scenes/shell/title.tscn", "title", 70)
	await _shoot_scene("res://scenes/shell/levels.tscn", "levels", 20)
	await _shoot_level(0, "level_001", false, false)
	await _shoot_level(_first_pit_level(), "level_pits", false, false)
	await _shoot_level(110, "level_111_hint", true, false)
	await _shoot_level(20, "level_021_won", false, true)
	await _shoot_lost()
	await _shoot_rolling(60, "level_061_rolling")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shots.cfg"))
	get_tree().quit()

func _first_pit_level() -> int:
	for i: int in range(Pack.count()):
		if Pack.board(i).cells.has(TiltBoard.Cell.PIT):
			return i
	return 0

func _shoot_scene(path: String, name: String, frames: int) -> void:
	var node: Node = load(path).instantiate()
	add_child(node)
	for i: int in range(frames):
		await get_tree().process_frame
	await _save(name)
	node.queue_free()
	await get_tree().process_frame

func _shoot_level(level: int, name: String, hint: bool, solve: bool) -> void:
	Pack.current = level
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(game)
	for i: int in range(10):
		await get_tree().process_frame
	if hint:
		game.call("_on_hint")
		for i: int in range(12):
			await get_tree().process_frame
	if solve:
		for dir: int in TiltSolver.new().solve(game.board):
			game.call("_tilt", dir)
			while game.get("_view").busy:
				await get_tree().process_frame
		await get_tree().create_timer(1.6).timeout
	await _save(name)
	game.queue_free()
	await get_tree().process_frame

## Tilts the first pit level the way that loses a marble, then shoots the banner.
func _shoot_lost() -> void:
	Pack.current = _first_pit_level()
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(game)
	for i: int in range(10):
		await get_tree().process_frame
	for dir: int in _losing_line(game.board, 4):
		game.call("_tilt", dir)
		while game.get("_view").busy:
			await get_tree().process_frame
	await get_tree().create_timer(1.4).timeout
	await _save("level_pits_lost")
	game.queue_free()
	await get_tree().process_frame

## The shortest run of tilts, up to `depth`, that drops a marble down a pit.
func _losing_line(start: TiltBoard, depth: int) -> PackedInt32Array:
	var frontier: Array[TiltBoard] = [start]
	var paths: Array[PackedInt32Array] = [PackedInt32Array()]
	for d: int in range(depth):
		var next_frontier: Array[TiltBoard] = []
		var next_paths: Array[PackedInt32Array] = []
		for k: int in range(frontier.size()):
			for dir: int in range(4):
				var b: TiltBoard = frontier[k].copy()
				if not b.tilt(dir).changed():
					continue
				var p: PackedInt32Array = paths[k].duplicate()
				p.append(dir)
				if b.lost:
					return p
				next_frontier.append(b)
				next_paths.append(p)
		frontier = next_frontier
		paths = next_paths
	return PackedInt32Array()

## Catches marbles mid-roll and the tray mid-tip.
func _shoot_rolling(level: int, name: String) -> void:
	Pack.current = level
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(game)
	for i: int in range(10):
		await get_tree().process_frame
	var path: PackedInt32Array = TiltSolver.new().solve(game.board)
	game.call("_tilt", path[0])
	for i: int in range(5):
		await get_tree().process_frame
	await _save(name)
	game.queue_free()
	await get_tree().process_frame

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path: String = "user://shots/%s.png" % name
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", ProjectSettings.globalize_path(path))
