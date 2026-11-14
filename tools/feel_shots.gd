extends Node

## Pictures of the marbles' faces, the wall animals and the win, light and dark, for reviewing how alive the
## board feels. Uses a throwaway save file. Shots are drawn in a 1080 by 1920 viewport of their own, so they come
## out phone-shaped whatever the screen.
## Run: DISPLAY=:0 godot --path . --fixed-fps 60 --disable-vsync res://tools/feel_shots.tscn
##   [-- only=name,name]   saves user://feel/<name>.png and prints each path.
## With Movie Maker, `clip=win`, `clip=fall`, `clip=walls` or `clip=title` plays that one scene through in the window
## and quits. The window is the project's 405 by 720 (window_width_override), which --resolution does not change:
##   godot --path . --fixed-fps 60 --write-movie out.avi res://tools/feel_shots.tscn -- clip=win

const OUT: String = "user://feel"
const SHOT_SIZE: Vector2i = Vector2i(1080, 1920)
const DESIGN_WIDTH: int = 720

var _only: PackedStringArray = PackedStringArray()
## Where scenes go: the shots' own viewport, or this node for a clip.
var _stage: Node = self

func _ready() -> void:
	Save.path = "user://feel.cfg"
	var stars: PackedByteArray = PackedByteArray()
	stars.resize(30)
	stars.fill(3)
	Save.stars = stars
	Save.faces = true
	Coach.enabled = false
	Intro.enabled = false
	ChapterCard.enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var clip: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			_only = arg.substr(5).split(",")
		elif arg.begins_with("clip="):
			clip = arg.substr(5)
	if clip != "":
		await _clip(clip)
	else:
		var sub: SubViewport = SubViewport.new()
		sub.size = SHOT_SIZE
		sub.size_2d_override = Vector2i(DESIGN_WIDTH, DESIGN_WIDTH * SHOT_SIZE.y / SHOT_SIZE.x)
		sub.size_2d_override_stretch = true
		sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sub)
		_stage = sub
		await _shots()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://feel.cfg"))
	get_tree().quit()

func _shots() -> void:
	var cats: int = _wall_level(0)
	var dogs: int = _wall_level(1)
	for dark: bool in [false, true]:
		var look: String = "dark" if dark else "light"
		_theme(dark)
		await _rest(cats, "cats_%s" % look)
		await _rest(dogs, "dogs_%s" % look)
		Save.faces = false
		await _rest(cats, "faces_off_%s" % look)
		Save.faces = true
	_theme(false)
	await _rolling(cats)
	await _bump(cats, "bump_cat")
	await _bump(dogs, "bump_dog")
	await _fall()
	await _home_and_party()
	# One level in from each chapter's start, odd chapters on an odd level, so cats and dogs both meet the tiles.
	for dark: bool in [false, true]:
		_theme(dark)
		for c: int in [4, 5, 8, 9]:
			if c < Pack.chapters.size():
				await _rest(Pack.chapter_first(c) + 2 + c % 2, "tiles_ch%02d%s" % [c + 1, "_dark" if dark else ""])
	_theme(false)
	if Pack.chapters.size() > 20:
		await _rest(Pack.chapter_first(20) + 1, "numbered")
	for set_id: String in ["glass", "gems", "planets", "candy", "pearls", "yarn"]:
		GameLooks.use(set_id)
		Appearance.apply(Appearance.Choice.LIGHT)
		await _rest(cats, "set_%s" % set_id)
	GameLooks.use("classic")
	Appearance.apply(Appearance.Choice.LIGHT)
	await _scene("res://scenes/shell/title.tscn", "title", 90)
	_theme(true)
	await _scene("res://scenes/shell/title.tscn", "title_dark", 90)
	_theme(false)
	await _settings()

func _wants(name: String) -> bool:
	return _only.is_empty() or _only.has(name)

func _theme(dark: bool) -> void:
	Save.theme = Appearance.Choice.DARK if dark else Appearance.Choice.LIGHT
	Appearance.apply(Save.theme)

## The level among the first 200 with the most walls, of the parity that gives cats (0) or dogs (1).
func _wall_level(parity: int) -> int:
	var best: int = parity
	var most: int = -1
	for i: int in range(parity, mini(Pack.count(), 200), 2):
		var b: TiltBoard = Pack.board(i)
		var walls: int = b.cells.count(TiltBoard.Cell.WALL)
		if walls > most and b.marble_cell.size() >= 3:
			most = walls
			best = i
	return best

func _game(level: int) -> Node:
	Pack.current = level
	var game: Node = load(Brand.GAME_SCENE).instantiate()
	_stage.add_child(game)
	await _wait(1.3)
	return game

func _drop_game(game: Node) -> void:
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _rest(level: int, name: String) -> void:
	if not _wants(name):
		return
	var game: Node = await _game(level)
	await _save(name)
	await _drop_game(game)

## A long roll, caught a few cells in.
func _rolling(level: int) -> void:
	if not _wants("rolling"):
		return
	var game: Node = await _game(level)
	var board: TiltBoard = game.get("board")
	var best: int = 0
	var longest: int = -1
	for dir: int in range(4):
		var move: TiltMove = board.copy().tilt(dir)
		if move.changed() and move.steps.size() > longest:
			longest = move.steps.size()
			best = dir
	game.call("_tilt", best)
	await _frames(9)
	await _save("rolling")
	await _drop_game(game)

## A tilt that leaves a marble resting against a wall, a few frames after it lands: the marble squints and
## the animal it hit wakes.
func _bump(level: int, name: String) -> void:
	if not _wants(name):
		return
	var game: Node = await _game(level)
	var board: TiltBoard = game.get("board")
	for dir: int in range(4):
		var next: TiltBoard = board.copy()
		var move: TiltMove = next.tilt(dir)
		var hits: bool = false
		for id: int in move.stopped:
			var ahead: Vector2i = next.coords(next.marble_cell[id]) + TiltBoard.DIRS[dir]
			hits = hits or (next.inside(ahead) and next.cells[next.index(ahead)] == TiltBoard.Cell.WALL)
		if hits and not next.lost:
			game.call("_tilt", dir)
			break
	var view: BoardView = game.get("_view")
	while view.busy:
		await get_tree().process_frame
	await _frames(6)
	await _save(name)
	await _drop_game(game)

func _fall() -> void:
	var level: int = _pit_level()
	if level < 0:
		return
	var game: Node = await _game(level)
	var path: PackedInt32Array = _losing_line(game.get("board"), 4)
	var view: BoardView = game.get("_view")
	for k: int in range(path.size()):
		game.call("_tilt", path[k])
		if k < path.size() - 1:
			while view.busy:
				await get_tree().process_frame
			await _frames(12)
	var worried: bool = false
	for i: int in range(90):
		await get_tree().process_frame
		if not worried and _any_feel(view, Mood.Feel.WORRY):
			worried = true
			await _frames(3)
			if _wants("worry"):
				await _save("worry")
		if view.fallen() >= 0:
			break
	await _frames(7)
	if _wants("fall"):
		await _save("fall")
	await _wait(1.0)
	if _wants("memorial"):
		await _save("memorial")
	await _wait(1.0)
	if _wants("pit_banner"):
		await _save("pit_banner")
	await _drop_game(game)

func _home_and_party() -> void:
	var level: int = 24
	var game: Node = await _game(level)
	var view: BoardView = game.get("_view")
	var path: PackedInt32Array = TiltSolver.new().solve(game.get("board"))
	var caught: bool = false
	for dir: int in path:
		game.call("_tilt", dir)
		while view.busy:
			await get_tree().process_frame
			if not caught and _any_feel(view, Mood.Feel.HOME):
				caught = true
				await _frames(4)
				if _wants("home"):
					await _save("home")
		await _frames(10)
	await _frames(14)
	if _wants("last_drop"):
		await _save("last_drop")
	# The party pops 0.7 s after the last tilt and the sheet rises 0.9 s later (game.gd).
	await _wait(1.05)
	if _wants("party"):
		await _save("party")
	await _drop_game(game)

func _any_feel(view: BoardView, feel: Mood.Feel) -> bool:
	for child: Node in view.get_children():
		if child is Marble and (child as Marble).visible and (child as Marble).mood.feel == feel:
			return true
	return false

func _pit_level() -> int:
	for i: int in range(40, mini(Pack.count(), 120)):
		var b: TiltBoard = Pack.board(i)
		if b.cells.has(TiltBoard.Cell.PIT) and not _losing_line(b, 3).is_empty():
			return i
	return -1

func _losing_line(start: TiltBoard, depth: int) -> PackedInt32Array:
	var frontier: Array[TiltBoard] = [start]
	var paths: Array[PackedInt32Array] = [PackedInt32Array()]
	for d: int in range(depth):
		var next_frontier: Array[TiltBoard] = []
		var next_paths: Array[PackedInt32Array] = []
		for k: int in range(frontier.size()):
			for dir: int in range(4):
				var b: TiltBoard = frontier[k].copy()
				var move: TiltMove = b.tilt(dir)
				if not move.changed():
					continue
				var p: PackedInt32Array = paths[k].duplicate()
				p.append(dir)
				# A fall at the end of a roll of at least two cells, so there is time to worry.
				if b.lost and move.steps.size() >= 3:
					return p
				if b.lost:
					continue
				next_frontier.append(b)
				next_paths.append(p)
		frontier = next_frontier
		paths = next_paths
	return PackedInt32Array()

func _scene(path: String, name: String, frames: int) -> void:
	if not _wants(name):
		return
	var node: Node = load(path).instantiate()
	_stage.add_child(node)
	await _frames(frames)
	await _save(name)
	node.queue_free()
	await get_tree().process_frame

func _settings() -> void:
	if not _wants("settings"):
		return
	var host: Node = load("res://scenes/shell/title.tscn").instantiate()
	_stage.add_child(host)
	await _frames(10)
	Settings.open(host)
	await _wait(0.8)
	await _save("settings")
	host.queue_free()
	await get_tree().process_frame

## One scene start to end, for Movie Maker.
func _clip(which: String) -> void:
	match which:
		"win":
			var game: Node = await _game(24)
			var view: BoardView = game.get("_view")
			await _wait(0.4)
			for dir: int in TiltSolver.new().solve(game.get("board")):
				game.call("_tilt", dir)
				while view.busy:
					await get_tree().process_frame
				await _wait(0.35)
			await _wait(3.2)
		"fall":
			var level: int = _pit_level()
			var game: Node = await _game(level)
			var view: BoardView = game.get("_view")
			for dir: int in _losing_line(game.get("board"), 4):
				game.call("_tilt", dir)
				while view.busy:
					await get_tree().process_frame
				await _wait(0.35)
			await _wait(2.4)
			game.call("_on_undo")
			await _wait(1.2)
		"walls":
			for level: int in [_wall_level(0), _wall_level(1)]:
				var game: Node = await _game(level)
				var view: BoardView = game.get("_view")
				for k: int in range(4):
					var path: PackedInt32Array = TiltSolver.new().solve(game.get("board"))
					if path.is_empty():
						break
					game.call("_tilt", path[0])
					while view.busy:
						await get_tree().process_frame
					await _wait(0.9)
				await _drop_game(game)
		"title":
			var title: Node = load("res://scenes/shell/title.tscn").instantiate()
			add_child(title)
			await _wait(6.0)

func _frames(n: int) -> void:
	for i: int in range(n):
		await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s.png" % [OUT, name]
	var view: Viewport = _stage as Viewport if _stage is Viewport else get_viewport()
	view.get_texture().get_image().save_png(path)
	print("SHOT ", ProjectSettings.globalize_path(path))
