extends Node

## Street's smoke robot (REVAMP_PLAN.md section 13): plays doors 1 to 25 through the real scenes on a fresh save of its
## own (user://street_smoke.cfg), as a player would. On the map it opens the door's card, picks helpers once they
## arrive, plays the board by the solver's route, sits through the win and the walk, opens each parcel (doubling one)
## and the milestone, and on the way visits the shop (buying a helper) and Settings (both tabs). Then it checks the
## save and prints STREET_SMOKE_OK, or a STREET_SMOKE_FAIL line for each thing wrong. Grep its log for SCRIPT ERROR too.
##
## Run: godot --headless --path . res://tools/street_smoke.tscn

const DOORS: int = 25
const SPEED: float = 4.0
const PATIENCE: float = 40.0

var _fails: PackedStringArray = PackedStringArray()

func _ready() -> void:
	Intro.enabled = false
	Save.path = "user://street_smoke.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path))
	Save.stars = PackedByteArray()
	Save.hard_stars = PackedByteArray()
	Save.gifts = PackedInt32Array()
	Save.knockers = PackedInt32Array()
	Save.boosters = {}
	Save.coins = 0
	Save.street_owned = PackedStringArray()
	Save.worn = PackedInt32Array([0, 0, 0, 0])
	Save.app_look = AppLook.STREET
	Save.look_chosen = true
	Save.tutorial_seen = true
	AppLook.use(AppLook.STREET)
	Engine.time_scale = SPEED
	_run.call_deferred()

func _run() -> void:
	# The robot is the main scene, so a stand-in takes that place for the game's scene changes to replace.
	var stand_in: Node = Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	get_tree().change_scene_to_file(StreetMap.SCENE)
	for door: int in range(1, DOORS + 1):
		var found: Node = await _scene(StreetMap)
		var map: StreetMap = found as StreetMap
		if map == null:
			_finish()
			return
		await _moments(map)
		var card: StreetDoorCard = map.get("_card")
		if door == 7:
			# A player puts the card back up before going to the shop or Settings.
			await _until(func() -> bool: return bool(card.get("_open")))
			card.close()
			await _until(func() -> bool: return not bool(map.get("_busy")))
			await _visit_shop(map)
			await _visit_settings(map)
		if door == 21:
			var home: StreetProp = (map.get("_houses") as Dictionary).get(20, null)
			if home == null or not home.settled or home.folk == null:
				_fail("door 20's family did not move in on the street")
		# After a walk the card drops in by itself; on a fresh street the robot taps the lit door.
		await _until(func() -> bool: return bool(card.get("_open")) or not bool(map.get("_busy")))
		if not bool(card.get("_open")):
			map.call("_open_card", door)
		await _until(func() -> bool: return bool(card.get("_open")))
		await _wait(0.6)
		if door > 15:
			card.call("_toggle", door % 3)
		card.call("_on_play")
		found = await _scene(StreetPlay)
		var play: StreetPlay = found as StreetPlay
		if play == null:
			_finish()
			return
		await _wait(0.8)
		var route: PackedInt32Array = TiltSolver.new().solve(play.board, 30000)
		if route.is_empty():
			_fail("door %d has no route" % door)
			_finish()
			return
		for dir: int in route:
			await play.call("_tilt", dir)
		if not play.board.is_won():
			_fail("door %d was not won by its route" % door)
		print("STREET_SMOKE door %d won, coins %d" % [door, Save.coins])
	var last: Node = await _scene(StreetMap)
	if last != null:
		await _moments(last as StreetMap)
	_finish()

## Opens whatever parcel or milestone is up on the map, doubling a parcel's contents once, and waits for it to close.
func _moments(map: StreetMap) -> void:
	await _wait(1.5)
	for round: int in range(3):
		var moment: StreetMoment = null
		for child: Node in map.get_children():
			if child is StreetMoment:
				moment = child
		if moment == null:
			await _wait(0.5)
			continue
		if moment is StreetGift:
			moment.call("_open")
			await _until(func() -> bool: return moment.finished)
			var double: Button = moment.get("_double")
			if moment.door == 10 and is_instance_valid(double):
				var before: int = Save.booster_count("ghosts")
				double.pressed.emit()
				await _wait(0.4)
				await _until(func() -> bool: return moment.finished)
				# With no video ready the reward doubles anyway (decision 7).
				if Save.booster_count("ghosts") != before + StreetRewards.BOOSTER_FIRST:
					_fail("x2 did not double the parcel")
		else:
			moment.hurry()
			await _until(func() -> bool: return moment.finished)
		print("STREET_SMOKE opened the %s at door %d" % ["parcel" if moment is StreetGift else "milestone", moment.door])
		moment.close()
		await _wait(1.0)
		return

func _visit_shop(map: StreetMap) -> void:
	await _until(func() -> bool: return not bool(map.get("_busy")))
	map.call("_open_shop")
	await _wait(1.2)
	var shop: StreetShop = _child(map, StreetShop)
	if shop == null:
		_fail("the shop did not open")
		return
	var before: int = Save.booster_count("footprints")
	var ghosts: int = Save.booster_count("ghosts")
	Save.add_coins(100)
	shop.call("_pick", StreetShop.Tray.HELPERS, 0)
	shop.call("_pick", StreetShop.Tray.HELPERS, 1)
	shop.call("_pick", StreetShop.Tray.HATS, 1)
	if Save.booster_count("footprints") != before + 1:
		_fail("buying a helper did not add one")
	if Save.booster_count("ghosts") != ghosts:
		_fail("a helper not yet opened was sold")
	# The video pill: with no video to show here, the helpers come free (decision 7).
	shop.call("_video")
	await _wait(0.3)
	if Save.booster_count("footprints") != before + 2:
		_fail("the helpers' video gave nothing")
	if Save.worn[1] != 2:
		_fail("a bought hat was not worn")
	shop.close()
	await _wait(0.6)
	print("STREET_SMOKE shop visited, coins %d" % Save.coins)

func _visit_settings(map: StreetMap) -> void:
	await _until(func() -> bool: return not bool(map.get("_busy")))
	map.call("_open_settings")
	await _wait(1.0)
	var settings: StreetSettings = _child(map, StreetSettings)
	if settings == null:
		_fail("Settings did not open")
		return
	settings.call("_choose_tab", 1)
	await _wait(0.5)
	settings.call("_flip", StreetSettings.Row.COLOUR, 1)
	if not Save.colour_help:
		_fail("Colour help did not turn on")
	settings.call("_flip", StreetSettings.Row.COLOUR, 1)
	settings.close()
	await _wait(0.6)
	print("STREET_SMOKE Settings visited")

func _child(parent: Node, type: Variant) -> Variant:
	for child: Node in parent.get_children():
		if is_instance_of(child, type):
			return child
	return null

## Waits for the current scene to be of `type`, answering it, or null after PATIENCE seconds.
func _scene(type: Variant) -> Node:
	var ok: bool = await _until(func() -> bool:
		var scene: Node = get_tree().current_scene
		return scene != null and is_instance_of(scene, type) and scene.is_node_ready())
	if not ok:
		_fail("no %s scene came up" % str(type))
		return null
	return get_tree().current_scene

## Waits until `check` holds, answering false after PATIENCE seconds of game time.
func _until(check: Callable) -> bool:
	var left: float = PATIENCE
	while not check.call():
		await get_tree().process_frame
		left -= get_process_delta_time()
		if left <= 0.0:
			return false
	return true

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _fail(text: String) -> void:
	_fails.append(text)
	print("STREET_SMOKE_FAIL ", text)

func _finish() -> void:
	for n: int in [5, 10, 15, 20, 25]:
		if not Save.gifts.has(n):
			_fail("door %d's reward was never opened" % n)
	if Save.coins <= 0:
		_fail("no coins after %d doors" % DOORS)
	for id: String in StreetRewards.BOOSTER_IDS:
		if Save.booster_count(id) <= 0 and id != "footprints":
			_fail("no %s after its parcel" % id)
	if Save.main_frontier() < DOORS:
		_fail("only %d doors won" % Save.main_frontier())
	if _fails.is_empty():
		print("STREET_SMOKE_OK coins %d boosters %s gifts %s knockers %d" % [Save.coins, Save.boosters, Save.gifts,
			Save.knockers.size()])
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path))
	get_tree().quit()
