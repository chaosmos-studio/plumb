extends Node

## Pictures of Street at a phone's full size (1084 x 2412, the A142's screen), rendered offscreen in one run, so only
## one window opens on the display. Each scene runs in a SubViewport that shows the 720-wide design at that size, on a
## save of its own (user://street_shots.cfg) where doors 1 to 11 are solved. They land in build/review/street/.
##
## Run: DISPLAY=:0 godot --path . res://tools/street_shots.tscn [-- name ...]

const OUT: String = "res://build/review/street/"
const PHONE: Vector2i = Vector2i(1084, 2412)
const DESIGN: Vector2i = Vector2i(720, 1602)
const SOLVED: int = 11
const STARS: PackedByteArray = [3, 3, 2, 3, 1, 3, 2, 3, 3, 2, 3]

func _ready() -> void:
	Intro.enabled = false
	Save.path = "user://street_shots.cfg"
	Save.stars = STARS.duplicate()
	Save.app_look = AppLook.STREET
	Save.look_chosen = true
	Save.tutorial_seen = true
	# The glossy marbles a new player starts with, whatever this desktop's own save has chosen.
	Save.look = ""
	GameLooks.use("classic")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only: PackedStringArray = OS.get_cmdline_user_args()
	var shots: Array[Callable] = [_chooser, _map, _card, _play, _win, _walk]
	for shot: Callable in shots:
		if only.is_empty() or only.has(shot.get_method().trim_prefix("_")):
			await shot.call()
	print("STREET_SHOTS_DONE")
	get_tree().quit()

func _stage(scene: String) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = PHONE
	view.size_2d_override = DESIGN
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
	var path: String = ProjectSettings.globalize_path(OUT + name + ".png")
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
	Save.stars = STARS.duplicate()
