extends RefCounted

## Stages Plumb for stills and films: the kit's capture tool and promo recorder ask for an action by
## name and get the real game, driven through its own code paths, in the viewport they pass.
##
## Actions: title, levels, settings, play:N, moves:N:K (after K solver moves), hint:N:K, rolling:N:K,
## won:N, hero:N (the board with the HUD hidden). Levels are 1-based here, as a player counts them.
##
## Films also call perform(game, verb, arg) on a staged game: solve (arg = most moves), hint, tilt
## (arg = L, R, U or D), fail (tilts into a pit), undo, wait (arg = seconds).

const SETTLE: float = 0.9

var _settle: float = SETTLE
## Set by the film runner, which draws the finger for each move; null for stills.
var film: Object = null

## `settle` waits for the level's opening animation, which stills want and films do not: a film reveals
## the level while its marbles pop in.
func stage(action: String, host: Node, settle: bool = true) -> void:
	_settle = SETTLE if settle else 0.02
	var parts: PackedStringArray = action.split(":")
	var verb: String = parts[0]
	var n: int = int(parts[1]) - 1 if parts.size() > 1 else 0
	var k: int = int(parts[2]) if parts.size() > 2 else 0
	_seed_progress()
	match verb:
		"title":
			host.add_child(load(Brand.TITLE_SCENE).instantiate())
			await _wait(host, 1.2)
		"levels":
			host.add_child(load(Brand.LEVELS_SCENE).instantiate())
			await _wait(host, 0.5)
		"settings":
			var title: Node = load(Brand.TITLE_SCENE).instantiate()
			host.add_child(title)
			await _wait(host, 0.3)
			Settings.open(title)
			await _wait(host, 0.6)
		"play":
			await _game(host, n)
		"moves":
			var game: Node = await _game(host, n)
			await _solve(game, k)
		"hint":
			var game2: Node = await _game(host, n)
			await _solve(game2, k)
			game2.call("_on_hint")
			await _wait(host, 1.0)
		"rolling":
			var game3: Node = await _game(host, n)
			await _solve(game3, k)
			var path: PackedInt32Array = TiltSolver.new().solve(game3.get("board"))
			game3.call("_tilt", path[0])
			await _wait(host, 0.09)
		"won":
			var game4: Node = await _game(host, n)
			await _solve(game4, 999)
			await _wait(host, 1.9)
		"hero":
			var game5: Node = await _game(host, n)
			for child: Node in game5.get_children():
				if child is CanvasLayer:
					(child as CanvasLayer).visible = false
			await _wait(host, 0.2)
		_:
			push_error("director: unknown action %s" % action)

## Something happening in an already staged game, paced for the camera.
func perform(game: Node, verb: String, arg: Variant) -> void:
	match verb:
		"solve":
			var path: PackedInt32Array = TiltSolver.new().solve(game.get("board"))
			var most: int = int(arg) if int(arg) > 0 else path.size()
			for i: int in range(mini(most, path.size())):
				_swipe(game, path[i])
				while game.get("_view").busy:
					await game.get_tree().process_frame
				await game.get_tree().create_timer(0.42).timeout
		"hint":
			game.call("_on_hint")
			await game.get_tree().create_timer(1.2).timeout
		"tilt":
			var dirs: Dictionary = {"L": TiltBoard.LEFT, "R": TiltBoard.RIGHT, "U": TiltBoard.UP, "D": TiltBoard.DOWN}
			_swipe(game, int(dirs.get(String(arg), TiltBoard.DOWN)))
		"fail":
			for dir: int in _losing_line(game.get("board"), 4):
				_swipe(game, dir)
				while game.get("_view").busy:
					await game.get_tree().process_frame
				await game.get_tree().create_timer(0.3).timeout
		"undo":
			game.call("_on_undo")
		"wait":
			await game.get_tree().create_timer(float(arg)).timeout

## Tilts the board the way a player would: a swipe across the middle of the board in that direction,
## drawn by the film when there is one.
func _swipe(game: Node, dir: int) -> void:
	if film != null:
		var view: Node2D = game.get("_view")
		var centre: Vector2 = view.get_global_transform_with_canvas().origin
		var reach: float = float(view.get("cell")) * 1.6
		var d: Vector2 = Vector2(TiltBoard.DIRS[dir])
		film.call("touch", "swipe", centre - d * reach, centre + d * reach)
	game.call("_tilt", dir)

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

func _game(host: Node, level: int) -> Node:
	Pack.current = level
	var game: Node = load(Brand.GAME_SCENE).instantiate()
	host.add_child(game)
	await _wait(host, _settle)
	return game

## Plays the first `count` moves of the solver's route, each one allowed to finish rolling.
func _solve(game: Node, count: int) -> void:
	var path: PackedInt32Array = TiltSolver.new().solve(game.get("board"))
	for i: int in range(mini(count, path.size())):
		game.call("_tilt", path[i])
		while game.get("_view").busy:
			await game.get_tree().process_frame
		await game.get_tree().create_timer(0.05).timeout

## Some progress, so the title and level grid look like a game someone is playing.
func _seed_progress() -> void:
	var stars: PackedByteArray = PackedByteArray()
	for i: int in range(14):
		stars.append(3 if i % 5 != 3 else 2)
	Save.stars = stars

func _wait(host: Node, seconds: float) -> void:
	await host.get_tree().create_timer(seconds).timeout
