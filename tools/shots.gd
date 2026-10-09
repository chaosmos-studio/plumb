extends Node

## Screenshots of every screen and state worth looking at, in one run, for reviewing the look.
## Run: DISPLAY=:0 godot --path . --resolution 720x1280 res://tools/shots.tscn
## Saves user://shots/<name>.png and prints each path. Uses a throwaway save file.

func _ready() -> void:
	Save.path = "user://shots.cfg"
	Save.stars = PackedByteArray([3, 3, 2, 1, 3])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	await _shoot_scene("res://scenes/shell/title.tscn", "title", 70)
	await _shoot_scene("res://kit/shell/levels.tscn", "levels", 20)
	await _shoot_settings()
	await _shoot_level(0, "level_001", false, false)
	await _shoot_level(_first_pit_level(), "level_pits", false, false)
	await _shoot_level(110, "level_111_hint", true, false)
	await _shoot_level(20, "level_021_won", false, true)
	await _shoot_lost()
	await _shoot_rolling(60, "level_061_rolling")
	# A board from each chapter that brings a tile, one level in so the chapter card is not over it.
	for c: int in range(4, Pack.chapters.size()):
		await _shoot_level(Pack.chapter_first(c) + 1, "chapter_%02d" % (c + 1), false, false)
	await _shoot_card(Pack.chapter_first(4))
	await _shoot_shop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shots.cfg"))
	get_tree().quit()

func _shoot_shop() -> void:
	Supporter.on_play = true
	var staged: Dictionary = {GameMonetize.COMPLETE_ID: "$4.99", GameMonetize.LEVELS_ID: "$1.99", GameMonetize.LOOKS_ID: "$1.99",
		"tip_1": "$0.99", "tip_2": "$1.99", "tip_5": "$4.99", "tip_10": "$9.99", "tip_20": "$19.99", "tip_50": "$49.99"}
	Shop.prices = staged
	Supporter.price = "$2.99"
	await _shoot_sheet(func(host: Node) -> void: Shop.open(host), "shop")
	await _shoot_sheet(func(host: Node) -> void: Shop.tips(host), "tip_jar")
	await _shoot_sheet(func(host: Node) -> void: Shop.offer(host, GameMonetize.LEVELS_ID), "offer_levels")
	await _shoot_sheet(func(host: Node) -> void: Looks.open(host), "looks")
	for look: String in ["glass", "gems", "planets", "candy"]:
		GameLooks.use(look)
		Appearance.apply(Save.theme)
		await _shoot_level(110, "look_%s" % look, false, false)
	GameLooks.use("classic")
	Appearance.apply(Save.theme)
	Supporter.on_play = false

func _shoot_sheet(open: Callable, name: String) -> void:
	var node: Node = load("res://scenes/shell/title.tscn").instantiate()
	add_child(node)
	for i: int in range(10):
		await get_tree().process_frame
	open.call(node)
	for i: int in range(40):
		await get_tree().process_frame
	await _save(name)
	node.queue_free()
	await get_tree().process_frame

func _shoot_card(level: int) -> void:
	Pack.current = level
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.8).timeout
	await _save("chapter_card")
	game.queue_free()
	await get_tree().process_frame

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
	# Long enough for every marble to have popped in.
	for i: int in range(50):
		await get_tree().process_frame
	if hint:
		for i: int in range(40):
			await get_tree().process_frame
		game.call("_on_hint")
		for i: int in range(24):
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

func _shoot_settings() -> void:
	var node: Node = load("res://scenes/shell/title.tscn").instantiate()
	add_child(node)
	for i: int in range(10):
		await get_tree().process_frame
	Settings.open(node)
	for i: int in range(40):
		await get_tree().process_frame
	await _save("settings")
	node.queue_free()
	await get_tree().process_frame

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
