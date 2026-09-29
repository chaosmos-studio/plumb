extends Node

## A robot that plays: opens levels, feeds the solver's solution through the game's own input path,
## and checks the result screen and the saved stars. Then boots every other screen once.
## Run: godot --headless --path . res://tools/smoke.tscn     Prints SMOKE_OK on success.

const LEVELS: Array[int] = [0, 3, 12, 44, 90, 119]

func _ready() -> void:
	Save.path = "user://smoke.cfg"
	Save.stars = PackedByteArray()
	var failures: int = 0
	for level: int in LEVELS:
		Pack.current = level
		var game: Node = load("res://scenes/game/game.tscn").instantiate()
		add_child(game)
		await get_tree().process_frame
		var path: PackedInt32Array = TiltSolver.new().solve(game.board)
		for dir: int in path:
			game.call("_tilt", dir)
			while game.get("_view").busy:
				await get_tree().process_frame
		await get_tree().create_timer(0.6).timeout
		var ok: bool = game.get("finished") and game.get("board").is_won() and Save.best(level) == 3
		print("%s level %d: %d moves, par %d, stars %d" % ["PASS" if ok else "FAIL", level + 1, path.size(), Pack.par(level), Save.best(level)])
		if not ok:
			failures += 1
		game.queue_free()
		await get_tree().process_frame
	for scene: String in ["res://scenes/shell/title.tscn", "res://scenes/shell/levels.tscn"]:
		var node: Node = load(scene).instantiate()
		add_child(node)
		for i: int in range(30):
			await get_tree().process_frame
		node.queue_free()
		await get_tree().process_frame
		print("PASS %s boots" % scene)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke.cfg"))
	print("SMOKE_OK" if failures == 0 else "SMOKE_FAILED %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
