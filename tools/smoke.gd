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
	failures += await _guide()
	failures += await _ending()
	for dark: bool in [false, true]:
		Appearance.apply(Appearance.Choice.DARK if dark else Appearance.Choice.LIGHT)
		for scene: String in ["res://scenes/shell/title.tscn", "res://kit/shell/levels.tscn", "res://scenes/game/game.tscn"]:
			Pack.current = 5
			var node: Node = load(scene).instantiate()
			add_child(node)
			for i: int in range(20):
				await get_tree().process_frame
			Settings.open(node)
			for i: int in range(20):
				await get_tree().process_frame
			node.queue_free()
			await get_tree().process_frame
			print("PASS %s boots with settings open, %s" % [scene, "dark" if dark else "light"])
	Appearance.apply(Appearance.native())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke.cfg"))
	print("SMOKE_OK" if failures == 0 else "SMOKE_FAILED %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

## Level 1's guide from start to end: two explaining steps, then the swipe it shows is the one that wins.
func _guide() -> int:
	Save.tutorial_seen = false
	Save.stars = PackedByteArray()
	Pack.current = 0
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(1.1).timeout
	var coach: Coach = game.get("_coach")
	var ok: bool = is_instance_valid(coach) and coach.waiting
	# A tap counts once a step has finished fading in, as it would for a player.
	for k: int in range(2):
		await get_tree().create_timer(0.6).timeout
		coach.advanced.emit()
	await get_tree().create_timer(0.5).timeout
	ok = ok and not coach.waiting and not coach.done
	var path: PackedInt32Array = TiltSolver.new().solve(game.get("board"))
	game.call("_tilt", path[0])
	await get_tree().create_timer(1.0).timeout
	ok = ok and game.get("finished") and not is_instance_valid(coach) and Save.tutorial_seen
	print("%s the guide walks level 1 through" % ("PASS" if ok else "FAIL"))
	game.queue_free()
	await get_tree().process_frame
	return 0 if ok else 1

## Solving the last level for the first time offers the ending, and the ending opens.
func _ending() -> int:
	Save.stars = PackedByteArray()
	Pack.current = Pack.count() - 1
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	for dir: int in TiltSolver.new().solve(game.get("board")):
		game.call("_tilt", dir)
		while game.get("_view").busy:
			await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	game.call("_on_finale")
	await get_tree().create_timer(0.3).timeout
	var shown: bool = not game.find_children("*", "Finale", true, false).is_empty()
	print("%s the last level ends on the note" % ("PASS" if shown else "FAIL"))
	game.queue_free()
	await get_tree().process_frame
	return 0 if shown else 1
