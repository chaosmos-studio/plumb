extends RefCounted

## Stages Plumb for stills and films: the kit's capture tool and promo recorder ask for an action by
## name and get the real game, driven through its own code paths, in the viewport they pass.
##
## Actions: title, levels, settings, play:N, moves:N:K (after K solver moves), hint:N:K, rolling:N:K,
## won:N, hero:N (the board with the HUD hidden). Levels are 1-based here, as a player counts them.

const SETTLE: float = 0.9

func stage(action: String, host: Node) -> void:
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

func _game(host: Node, level: int) -> Node:
	Pack.current = level
	var game: Node = load(Brand.GAME_SCENE).instantiate()
	host.add_child(game)
	await _wait(host, SETTLE)
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
