extends Node

## The dev package's own screenshots, for device checks that must never catch anything but the game. When
## user://shot_request appears holding a name, the next frame the game draws is saved from its own viewport to
## user://shots/<name>.png, with <name>.json beside it, and the request is removed. The viewport holds only what the
## game draws, so a notification, another app or the system bars can never be in a shot. "<name> <frames>" takes a
## burst instead (MAX_BURST).
##
## A native banner is not drawn by the game either, so each shot's .json and log line carry the kit's banner state
## (Ads.banner_state), and every change to it is logged as it happens ("DEV_BANNER", for logcat).
##
## Only a debug build with the dev_build feature (the Android Dev preset, the dev package) starts this, from
## Save._ready, and every other export preset leaves kit/debug/ out (tests/run_tests.gd,
## _test_dev_shots_stay_out_of_release). Nothing may preload this file: a release build does not have it.

const REQUEST: String = "user://shot_request"
const FOLDER: String = "user://shots"
## "in" while the game has the screen's focus, "out" once anything takes it (the shade, a call, another app), so a
## device check knows whether the game is in front without asking the system about any other app.
const FOCUS: String = "user://dev_focus"
## A shot's name, which becomes its file name: nothing that could climb out of the folder.
const NAME_PATTERN: String = "^[a-z0-9][a-z0-9-]{0,47}$"
## How often the request file is looked for, in seconds.
const POLL: float = 0.2
## "<name> <frames>" asks for a burst of that many frames in a row, <name>-01 and on, at half size, to see motion
## (a card popping or fading in). At most this many.
const MAX_BURST: int = 16

var _busy: bool = false
var _since: float = 0.0
var _banner: String = ""

static func valid_name(text: String) -> bool:
	return RegEx.create_from_string(NAME_PATTERN).search(text) != null

## A request's name and frame count, {} when it is not one.
static func parse(request: String) -> Dictionary:
	var parts: PackedStringArray = request.strip_edges().split(" ", false)
	if parts.is_empty() or parts.size() > 2 or not valid_name(parts[0]):
		return {}
	if parts.size() == 2 and not parts[1].is_valid_int():
		return {}
	var frames: int = clampi(int(parts[1]), 1, MAX_BURST) if parts.size() == 2 else 1
	return {"name": parts[0], "frames": frames}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(FOLDER)
	_focus(get_window().has_focus())
	print("DEV_SHOTS ready")

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_focus(true)
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_focus(false)

func _focus(on: bool) -> void:
	var file: FileAccess = FileAccess.open(FOCUS, FileAccess.WRITE)
	if file != null:
		file.store_string("in" if on else "out")
		file.close()
	print("DEV_FOCUS ", "in" if on else "out")

func _process(delta: float) -> void:
	_watch_banner()
	_since += delta
	if _busy or _since < POLL:
		return
	_since = 0.0
	if FileAccess.file_exists(REQUEST):
		_take(FileAccess.get_file_as_string(REQUEST))

func _take(request: String) -> void:
	# Removed first, so a shot that fails is never tried again on every poll.
	DirAccess.remove_absolute(REQUEST)
	var asked: Dictionary = parse(request)
	if asked.is_empty():
		print("DEV_SHOT refused ", request.strip_edges().c_escape())
		return
	_busy = true
	var frames: int = int(asked["frames"])
	var images: Array[Image] = []
	var states: Array[Dictionary] = []
	# Every frame is grabbed first and saved after, so a burst sees frames in a row.
	for i: int in range(frames):
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		if frames > 1 and image != null and not image.is_empty():
			image.resize(roundi(image.get_width() * 0.5), roundi(image.get_height() * 0.5), Image.INTERPOLATE_BILINEAR)
		images.append(image)
		states.append(state())
	for i: int in range(frames):
		var shot: String = str(asked["name"]) if frames == 1 else "%s-%02d" % [asked["name"], i + 1]
		_save(shot, images[i], states[i])
	_busy = false

func _save(shot: String, image: Image, info: Dictionary) -> void:
	var status: int = ERR_UNAVAILABLE
	var part: String = FOLDER + "/" + shot + ".part"
	if image != null and not image.is_empty():
		status = image.save_png(part)
	info["saved"] = status == OK
	var file: FileAccess = FileAccess.open(FOLDER + "/" + shot + ".json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info))
		file.close()
	# The picture appears under its own name only once it is whole, so a pull never gets half of one.
	if status == OK:
		DirAccess.rename_absolute(part, FOLDER + "/" + shot + ".png")
	print("DEV_SHOT ", shot, " ", JSON.stringify(info))

## What a shot cannot show: the scene, the size drawn, the banner as the kit has it, and every layer open over the
## screen (a card, a sheet), by its script's name.
func state() -> Dictionary:
	var tree: SceneTree = get_tree()
	var scene: Node = tree.current_scene
	var view: Vector2 = get_viewport().get_visible_rect().size
	var layers: Array[String] = []
	_layers_in(tree.root, layers)
	return {"scene": "" if scene == null else scene.scene_file_path.get_file().get_basename(),
		"size": [roundi(view.x), roundi(view.y)], "banner": Ads.banner_state(), "layers": layers,
		"msec": Time.get_ticks_msec()}

func _layers_in(node: Node, into: Array[String]) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer and (child as CanvasLayer).visible:
			into.append("%s@%d" % [_named(child), (child as CanvasLayer).layer])
		_layers_in(child, into)

## A layer's script name, or that of the first child with a script (a Sheet makes a plain CanvasLayer for itself).
func _named(layer: Node) -> String:
	var script: Script = layer.get_script() as Script
	if script != null and script.resource_path != "":
		return script.resource_path.get_file().get_basename()
	for child: Node in layer.get_children():
		var inner: Script = child.get_script() as Script
		if inner != null and inner.resource_path != "":
			return inner.resource_path.get_file().get_basename()
	return String(layer.name)

func _watch_banner() -> void:
	var now: String = JSON.stringify(Ads.banner_state())
	if now != _banner:
		_banner = now
		print("DEV_BANNER ", now)
