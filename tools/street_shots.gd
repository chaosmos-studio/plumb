extends Node

## Pictures of Street at full size on every screen shape it must compose for (REVAMP_PLAN.md section 16): a portrait
## and a landscape phone, a 16:9 and a 21:9 desktop and a turned tablet. They render offscreen in one run, so only one
## window opens on the display. Each scene runs in a SubViewport at the screen's pixels showing the design size the
## game's stretch gives that screen (StreetLayout), on a save of its own (user://street_shots.cfg) where doors 1 to 11
## are solved. They land in build/review/street/<width>x<height>/.
##
## Run: DISPLAY=:0 godot --path . res://tools/street_shots.tscn [-- name ... size ...], such as `-- map 2400x1080`.

const OUT: String = "res://build/review/street/"
const SIZES: Array[Vector2i] = [Vector2i(1080, 2400), Vector2i(2400, 1080), Vector2i(1920, 1080), Vector2i(2560, 1080),
	Vector2i(2048, 1536)]
const SOLVED: int = 11
var _pixels: Vector2i = SIZES[0]
var _folder: String = OUT
const STARS: PackedByteArray = [3, 3, 2, 3, 1, 3, 2, 3, 3, 2, 3]

func _ready() -> void:
	Intro.enabled = false
	Save.path = "user://street_shots.cfg"
	_street(STARS.size())
	Save.app_look = AppLook.STREET
	Save.look_chosen = true
	Save.tutorial_seen = true
	# The glossy marbles a new player starts with, whatever this desktop's own save has chosen.
	Save.look = ""
	GameLooks.use("classic")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var names: PackedStringArray = []
	var sizes: Array[Vector2i] = []
	for arg: String in args:
		var parts: PackedStringArray = arg.split("x")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			sizes.append(Vector2i(parts[0].to_int(), parts[1].to_int()))
		else:
			names.append(arg)
	if sizes.is_empty():
		sizes = SIZES.duplicate()
	var shots: Array[Callable] = [_chooser, _map, _card, _play, _win, _walk, _plot, _family, _gift, _milestone, _helpers,
		_shop, _settings, _colour]
	for pixels: Vector2i in sizes:
		_pixels = pixels
		_folder = OUT + "%dx%d/" % [pixels.x, pixels.y]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_folder))
		for shot: Callable in shots:
			if names.is_empty() or names.has(shot.get_method().trim_prefix("_")):
				await shot.call()
	print("STREET_SHOTS_DONE")
	get_tree().quit()

func _stage(scene: String) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = _pixels
	view.size_2d_override = Vector2i(StreetLayout.design_size(Vector2(_pixels)).round())
	view.size_2d_override_stretch = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	view.add_child((load(scene) as PackedScene).instantiate())
	return view

func _frames(n: int) -> void:
	for i: int in range(n):
		await get_tree().process_frame

func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _save(view: SubViewport, name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(_folder + name + ".png")
	view.get_texture().get_image().save_png(path)
	print("STREET_SHOT ", path)

func _chooser() -> void:
	var view: SubViewport = _stage(LookChooser.SCENE)
	await _seconds(1.5)
	await _save(view, "1-chooser")
	view.queue_free()

func _map() -> void:
	var view: SubViewport = _stage(StreetMap.SCENE)
	await _seconds(1.2)
	await _save(view, "2-map")
	view.queue_free()

func _card() -> void:
	var view: SubViewport = _stage(StreetMap.SCENE)
	await _seconds(0.6)
	(view.get_child(0) as StreetMap).call("_open_card", SOLVED + 1)
	await _seconds(1.6)
	await _save(view, "3-card")
	view.queue_free()

func _play() -> void:
	Pack.use(Pack.Section.MAIN)
	Pack.current = SOLVED
	var view: SubViewport = _stage(StreetPlay.SCENE)
	await _seconds(1.4)
	await _save(view, "4-play")
	view.queue_free()

## Plays the level through by the solver's route, then pictures the homecoming as the marbles roll in and as the stars
## land, and leaves before the screen goes back to the street.
func _win() -> void:
	Pack.use(Pack.Section.MAIN)
	Pack.current = SOLVED
	var view: SubViewport = _stage(StreetPlay.SCENE)
	await _seconds(1.0)
	var play: StreetPlay = view.get_child(0)
	for dir: int in TiltSolver.new().solve(play.board, 30000):
		await play.call("_tilt", dir)
	await _seconds(1.75)
	await _save(view, "5-win-home")
	await _seconds(2.9)
	await _save(view, "6-win-stars")
	view.queue_free()
	Save.stars = STARS.duplicate()

## The street after a win: the cast walks on to the next door, then its card drops in.
func _walk() -> void:
	StreetMap.arrival = SOLVED
	var view: SubViewport = _stage(StreetMap.SCENE)
	await _seconds(1.05)
	await _save(view, "7-walk")
	await _seconds(1.9)
	await _save(view, "8-next-card")
	view.queue_free()
	_street(STARS.size())

## A save with doors 1 to `solved` won (the stars repeating STARS), their parcels and milestones opened, some coins
## and helpers, and a golden knocker on every third door.
func _street(solved: int) -> void:
	var stars: PackedByteArray = PackedByteArray()
	Save.gifts = PackedInt32Array()
	Save.knockers = PackedInt32Array()
	for i: int in range(solved):
		stars.append(STARS[i % STARS.size()])
		if StreetRewards.has_parcel(i + 1) or StreetRewards.is_milestone(i + 1):
			Save.gifts.append(i + 1)
		if (i + 1) % 3 == 0:
			Save.knockers.append(i + 1)
	Save.stars = stars
	Save.coins = 245
	Save.boosters = {"footprints": 2, "ghosts": 3, "spare_step": 1}
	Save.worn = PackedInt32Array([0, 2, 0, 0])

## The street before a milestone: its plot and sign at the door to play next, the finish ribbon just past it.
func _plot() -> void:
	_street(19)
	var view: SubViewport = _stage(StreetMap.SCENE)
	await _seconds(1.2)
	await _save(view, "9-plot")
	view.queue_free()

## The street after one: the family's house on its plot, the family in front, the windmill turning.
func _family() -> void:
	_street(41)
	var view: SubViewport = _stage(StreetMap.SCENE)
	await _seconds(0.8)
	var map: StreetMap = view.get_child(0)
	map.set("_scroll", map.call("_scroll_for", 40))
	await _seconds(1.0)
	await _save(view, "10-family")
	view.queue_free()

## The parcel at door 25: waiting, opened with what it holds rising, and done with "x2" offered.
func _gift() -> void:
	_street(25)
	Save.gifts.erase(25)
	var view: SubViewport = _stage(StreetMap.SCENE)
	await _seconds(0.7)
	var moment: StreetGift = view.get_child(0).get_children().filter(func(n: Node) -> bool:
		return n is StreetGift).front()
	await _seconds(0.8)
	await _save(view, "11-gift")
	moment.call("_open")
	await _seconds(1.0)
	await _save(view, "12-gift-open")
	await _seconds(2.0)
	await _save(view, "13-gift-done")
	view.queue_free()
	_street(STARS.size())

## The start card at door 26 with two helpers picked, then the board they open on.
func _helpers() -> void:
	_street(25)
	var view: SubViewport = _stage(StreetMap.SCENE)
	await _seconds(0.6)
	var map: StreetMap = view.get_child(0)
	map.call("_open_card", 26)
	await _seconds(0.9)
	var card: StreetDoorCard = map.get("_card")
	card.call("_toggle", 0)
	card.call("_toggle", 2)
	await _seconds(0.8)
	await _save(view, "17-card-helpers")
	view.queue_free()
	StreetPlay.helpers = PackedInt32Array([0, 2])
	Pack.use(Pack.Section.MAIN)
	Pack.current = 25
	view = _stage(StreetPlay.SCENE)
	await _seconds(1.6)
	await _save(view, "18-play-helpers")
	view.queue_free()
	_street(STARS.size())

## The shop, entered, with a hat worn and a set chosen.
func _shop() -> void:
	var view: SubViewport = _stage(StreetMap.SCENE)
	await _seconds(0.5)
	view.get_child(0).call("_open_shop")
	await _seconds(1.5)
	await _save(view, "19-shop")
	view.queue_free()

## Settings on each tab, Colour help on in the second.
func _settings() -> void:
	Save.colour_help = true
	ColourHelp.on = true
	var view: SubViewport = _stage(StreetMap.SCENE)
	await _seconds(0.5)
	view.get_child(0).call("_open_settings")
	await _seconds(1.0)
	await _save(view, "20-settings")
	var settings: StreetSettings = view.get_child(0).get_children().filter(func(n: Node) -> bool:
		return n is StreetSettings).front()
	settings.call("_choose_tab", 1)
	await _seconds(0.7)
	await _save(view, "21-settings-access")
	view.queue_free()
	Save.colour_help = false
	ColourHelp.on = false

## A board with Colour help on: each colour's shape on its marbles and in its holes.
func _colour() -> void:
	ColourHelp.on = true
	Pack.use(Pack.Section.MAIN)
	Pack.current = SOLVED
	var view: SubViewport = _stage(StreetPlay.SCENE)
	await _seconds(1.4)
	await _save(view, "22-colour-help")
	view.queue_free()
	ColourHelp.on = false

## The milestone at door 40: the house rising under fireworks, then the family out and waving.
func _milestone() -> void:
	_street(40)
	Save.gifts.erase(40)
	var view: SubViewport = _stage(StreetMap.SCENE)
	await _seconds(1.3)
	await _save(view, "14-milestone-rise")
	await _seconds(1.4)
	await _save(view, "15-milestone-family")
	await _seconds(2.0)
	await _save(view, "16-milestone-done")
	view.queue_free()
	_street(STARS.size())
