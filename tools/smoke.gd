extends Node

## A robot that plays: opens levels, feeds the solver's solution through the game's own input path,
## and checks the result screen and the saved stars. Then boots every other screen once, and plays the
## ads and the Supporter pack against a stand-in ad network: the hint gate, the banner on the level grid,
## and the pacing of ads between levels through the real Next level path.
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
	failures += await _hint_gate()
	failures += await _banner()
	failures += await _supporter()
	failures += await _interstitials()
	Ads.use(null)
	Ads.skew = 0.0
	# The last win's bells ring out before quitting, so no sound is cut off mid-play.
	await _wait(1.5)
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

# --- Ads and the Supporter pack -----------------------------------------------------------------------

func _report(ok: bool, what: String) -> int:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	return 0 if ok else 1

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _open_game(level: int) -> Node:
	Pack.current = level
	var game: Node = load(Brand.GAME_SCENE).instantiate()
	add_child(game)
	await _wait(0.3)
	return game

func _press(host: Node, text: String) -> bool:
	for node: Node in host.find_children("*", "Button", true, false):
		var b: Button = node as Button
		if b.text == text:
			b.pressed.emit()
			return true
	return false

## Taps the hint and says what came of it: "hint" (shown at once), "asked" (the video prompt is up) or
## "nothing".
func _tap_hint(game: Node, fresh: bool = true) -> String:
	var view: Node = game.get("_view")
	view.call("_clear_hint")
	# A fresh ask, unless the robot is checking that asking again on the same board is free.
	if fresh:
		game.set("_hinted", null)
	game.call("_on_hint")
	await _wait(0.1)
	if is_instance_valid(game.get("_prompt")):
		return "asked"
	return "hint" if int(view.get("_hint_dir")) >= 0 else "nothing"

## The prompt's answer, then whether a hint showed.
func _answer(game: Node, button: String) -> bool:
	var prompt: Sheet = game.get("_prompt")
	_press(prompt, button)
	await _wait(0.5)
	return int(game.get("_view").get("_hint_dir")) >= 0

func _hint_gate() -> int:
	var fake: _FakeAds = _FakeAds.new()
	Ads.use(fake)
	Save.supporter = false
	Save.stars = PackedByteArray()
	var failures: int = 0
	Save.set_hints(HintGate.today(), AdPacing.DAILY_HINTS)
	var early: Node = await _open_game(5)
	var hint: IconButton = early.get("_hint")
	failures += _report(await _tap_hint(early) == "hint" and Save.hints_used == AdPacing.DAILY_HINTS and hint.badge == ""
		and hint.badge_icon == &"", "a learning level's hint is free, with the day's allowance used up")
	early.queue_free()
	Save.set_hints("2000-01-01", AdPacing.DAILY_HINTS)
	var game: Node = await _open_game(30)
	hint = game.get("_hint")
	failures += _report(hint.badge == "3", "yesterday's hints are forgotten: the badge says 3 free today")
	var free: bool = true
	for k: int in range(AdPacing.DAILY_HINTS):
		free = free and await _tap_hint(game) == "hint"
	failures += _report(free and Save.hints_used == AdPacing.DAILY_HINTS and Save.hint_day == HintGate.today()
		and hint.badge_icon == &"play", "three free hints a day, then the badge shows a play mark")
	failures += _report(await _tap_hint(game, false) == "hint" and Save.hints_used == AdPacing.DAILY_HINTS,
		"asking again on the board a hint was given for shows it again for nothing")
	failures += _report(await _tap_hint(game) == "asked" and not await _answer(game, "Not now")
		and int(fake.shown.get(AdBackend.REWARDED, 0)) == 0, "the fourth asks for a video, and Not now gives nothing")
	failures += _report(await _tap_hint(game) == "asked" and await _answer(game, "Watch")
		and int(fake.shown.get(AdBackend.REWARDED, 0)) == 1, "a video watched through gives the hint")
	fake.watch_through = false
	failures += _report(await _tap_hint(game) == "asked" and not await _answer(game, "Watch")
		and int(fake.shown.get(AdBackend.REWARDED, 0)) == 2, "a video closed early gives nothing")
	fake.watch_through = true
	fake.has_video = false
	failures += _report(await _tap_hint(game) == "asked" and await _answer(game, "Watch")
		and int(fake.shown.get(AdBackend.REWARDED, 0)) == 2, "with no video to show, the hint comes anyway")
	failures += _report(Ads.interstitial_due() == false and int(fake.shown.get(AdBackend.INTERSTITIAL, 0)) == 0,
		"nothing between levels while playing one")
	game.queue_free()
	await get_tree().process_frame
	return failures

func _banner() -> int:
	var fake: _FakeAds = _FakeAds.new()
	Ads.use(fake)
	Save.supporter = false
	var failures: int = 0
	Save.stars = PackedByteArray([3, 3])
	var levels: Node = load(Brand.LEVELS_SCENE).instantiate()
	add_child(levels)
	await _wait(0.5)
	var pager: Control = levels.get("_pager")
	failures += _report(not fake.banner_on and is_equal_approx(-pager.offset_bottom, float(levels.get("_floor"))),
		"no banner with two levels solved")
	levels.queue_free()
	await get_tree().process_frame
	Save.stars = PackedByteArray([3, 3, 2])
	levels = load(Brand.LEVELS_SCENE).instantiate()
	add_child(levels)
	await _wait(0.6)
	pager = levels.get("_pager")
	var clear: float = -pager.offset_bottom - _FakeAds.BANNER
	failures += _report(fake.banner_on and clear >= 24.0,
		"the banner comes with the third solve, and the pager sits %d px above it" % int(clear))
	var sheet: Sheet = Settings.open(levels)
	await _wait(0.4)
	var hidden: bool = not fake.banner_on
	sheet.close()
	await _wait(0.5)
	failures += _report(hidden and fake.banner_on, "the banner steps aside while a sheet is open")
	levels.queue_free()
	await get_tree().process_frame
	failures += _report(not fake.banner_on, "and goes with the level grid")
	return failures

func _supporter() -> int:
	var fake: _FakeAds = _FakeAds.new()
	Ads.use(fake)
	Ads.skew = 100000.0
	Save.supporter = false
	var failures: int = 0
	var stars: PackedByteArray = PackedByteArray()
	stars.resize(40)
	stars.fill(3)
	Save.stars = stars
	Save.set_hints(HintGate.today(), AdPacing.DAILY_HINTS)
	for k: int in range(AdPacing.INTERSTITIAL_EVERY):
		EventBus.level_won.emit(k, 1, 3)
	var due: bool = Ads.interstitial_due() and HintGate.cost(30) == AdPacing.Hint.VIDEO
	Supporter.grant(true)
	var levels: Node = load(Brand.LEVELS_SCENE).instantiate()
	add_child(levels)
	await _wait(0.4)
	var no_banner: bool = not fake.banner_on
	levels.queue_free()
	var went_on: Array[bool] = [false]
	Ads.maybe_interstitial(func() -> void: went_on[0] = true)
	var game: Node = await _open_game(30)
	var hint: IconButton = game.get("_hint")
	var free_hint: bool = await _tap_hint(game) == "hint" and hint.badge == "" and hint.badge_icon == &""
	failures += _report(due and fake.stopped and no_banner and went_on[0] and free_hint and not Ads.rewards()
		and fake.shown.is_empty(), "a Supporter gets no banner, no ad between levels and every hint free")
	game.queue_free()
	Supporter.grant(false)
	failures += _report(Ads.live() and not Save.supporter and not fake.stopped, "a refunded pack brings the ads back")
	await get_tree().process_frame
	return failures

## Plays `level` as the current scene, the way Screens would, so its Next level path runs for real.
func _play_scene(level: int) -> Node:
	Pack.current = level
	get_tree().change_scene_to_file(Brand.GAME_SCENE)
	return await _next_scene(level)

func _next_scene(level: int) -> Node:
	for k: int in range(200):
		await get_tree().process_frame
		var scene: Node = get_tree().current_scene
		if scene != null and scene.scene_file_path == Brand.GAME_SCENE and int(scene.get("level")) == level:
			await _wait(0.3)
			return scene
	return null

func _solve(game: Node) -> void:
	for dir: int in TiltSolver.new().solve(game.get("board")):
		game.call("_tilt", dir)
		while game.get("_view").busy:
			await get_tree().process_frame
	await _wait(0.6)

## Solves `level` and takes Next level. Returns the interstitials shown while playing it and on Next,
## or -1 if the next level did not open.
func _through(fake: _FakeAds, level: int, guided: bool = false) -> Vector2i:
	var game: Node = await _play_scene(level)
	if game == null:
		return Vector2i(-1, -1)
	if guided:
		# The guide opens a moment after the level does, so wait for it before tapping through.
		var coach: Coach = null
		for tries: int in range(40):
			coach = game.get("_coach")
			if is_instance_valid(coach):
				break
			await _wait(0.05)
		for k: int in range(2):
			await _wait(0.6)
			if is_instance_valid(coach):
				coach.advanced.emit()
		await _wait(0.4)
	var before: int = int(fake.shown.get(AdBackend.INTERSTITIAL, 0))
	await _solve(game)
	var during: int = int(fake.shown.get(AdBackend.INTERSTITIAL, 0)) - before
	game.call("_on_next")
	var next: Node = await _next_scene(level + 1)
	if next == null:
		return Vector2i(-1, -1)
	return Vector2i(during, int(fake.shown.get(AdBackend.INTERSTITIAL, 0)) - before - during)

func _interstitials() -> int:
	var fake: _FakeAds = _FakeAds.new()
	Ads.use(fake)
	Ads.skew = 100000.0
	Save.supporter = false
	Save.tutorial_seen = true
	Save.stars = PackedByteArray()
	# The robot keeps running while scenes change under it, the way an autoload does.
	var stage: Node = Node.new()
	get_tree().root.add_child(stage)
	get_tree().current_scene = stage
	var failures: int = 0
	var early: Vector2i = Vector2i.ZERO
	for level: int in range(6):
		early += await _through(fake, level)
	failures += _report(early == Vector2i.ZERO, "no ad between levels in the first 6 solves, however long the session")
	var stars: PackedByteArray = Save.stars
	stars.resize(11)
	stars.fill(3)
	Save.stars = stars
	failures += _report(await _through(fake, 11) == Vector2i(0, 1), "the 12th solve's Next level shows one, never mid-level")
	var soon: Vector2i = Vector2i.ZERO
	for level: int in range(12, 16):
		soon += await _through(fake, level)
	failures += _report(soon == Vector2i.ZERO, "none again within 4 minutes, even 4 solves later")
	Ads.skew += AdPacing.FULLSCREEN_GAP
	failures += _report(await _through(fake, 16) == Vector2i(0, 1), "one again once 4 minutes have passed")
	Ads.skew += AdPacing.FULLSCREEN_GAP
	for level: int in range(17, 20):
		await _through(fake, level)
	Coach.enabled = true
	Save.tutorial_seen = false
	failures += _report(await _through(fake, 0, true) == Vector2i.ZERO and Ads.interstitial_due(),
		"never after level 1's guide, though one was due")
	Save.tutorial_seen = true
	var last: Node = get_tree().current_scene
	if last != null and last != stage:
		last.queue_free()
	get_tree().current_scene = self
	await get_tree().process_frame
	return failures

## An ad network with every ad loaded, or none, that counts what it shows.
class _FakeAds extends AdBackend:
	const BANNER: float = 112.0

	var has_video: bool = true
	var has_interstitial: bool = true
	var watch_through: bool = true
	var banner_on: bool = false
	var stopped: bool = false
	var shown: Dictionary = {}
	var _loaded_banner: bool = false

	func ready_to_show(kind: StringName) -> bool:
		return not stopped and (has_video if kind == REWARDED else has_interstitial)

	func present(kind: StringName) -> void:
		shown[kind] = int(shown.get(kind, 0)) + 1
		finished.emit.call_deferred(kind, true, kind == REWARDED and watch_through)

	func set_banner(on: bool) -> void:
		banner_on = on and not stopped
		if banner_on and not _loaded_banner:
			_loaded_banner = true
			banner_changed.emit.call_deferred(BANNER)

	func stop() -> void:
		stopped = true
		banner_on = false

	func resume() -> void:
		stopped = false
