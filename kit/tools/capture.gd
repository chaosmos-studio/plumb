extends Node

## Each shot's 2D size is the design width stretched to the requested pixels, so it has the layout a phone
## of that shape would show.
## Run: DISPLAY=:0 godot --path . res://kit/tools/capture.tscn [-- only=name,name spec=res://... out=res://...]

const SPEC: String = "res://store/shots.json"
const OUT: String = "res://build/store/raw"
const DESIGN_WIDTH: float = 720.0
const SETTLE_FRAMES: int = 6

func _ready() -> void:
	var only: PackedStringArray = PackedStringArray()
	var spec_path: String = SPEC
	var out: String = OUT
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5).split(",")
		elif arg.begins_with("spec="):
			spec_path = arg.substr(5)
		elif arg.begins_with("out="):
			out = arg.substr(4)
	Save.path = "user://capture.cfg"
	# Every capture shows the game in its own look, whatever this machine's player last picked.
	Coach.enabled = false
	Intro.enabled = false
	ChapterCard.enabled = false
	Appearance.apply(Appearance.native())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	# Raw captures are build products: without this Godot imports every one, and a local export packs them.
	var ignore: String = ProjectSettings.globalize_path("res://build/.gdignore")
	DirAccess.make_dir_recursive_absolute(ignore.get_base_dir())
	if not FileAccess.file_exists(ignore):
		FileAccess.open(ignore, FileAccess.WRITE).close()
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	var director: Object = load("res://tools/director.gd").new()
	var made: int = 0
	for entry: Variant in spec["shots"]:
		var shot: Dictionary = entry
		var shot_name: String = shot["name"]
		if not only.is_empty() and not only.has(shot_name):
			continue
		var size: Array = shot["size"]
		var w: int = int(size[0])
		var h: int = int(size[1])
		var sub: SubViewport = SubViewport.new()
		sub.size = Vector2i(w, h)
		sub.size_2d_override = Vector2i(int(DESIGN_WIDTH), int(round(DESIGN_WIDTH * h / w))) if h >= w \
			else Vector2i(int(round(DESIGN_WIDTH * w / h)), int(DESIGN_WIDTH))
		sub.size_2d_override_stretch = true
		sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sub.transparent_bg = false
		add_child(sub)
		# Every shot starts from the same random state, so a capture run again gives the same pictures, and
		# two shots of one win (its sheet and its share card) say the same words.
		seed(1)
		Cheers.forget()
		await director.call("stage", String(shot["action"]), sub)
		for i: int in range(SETTLE_FRAMES):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = sub.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var path: String = "%s/%s.png" % [out, shot_name]
		img.save_png(path)
		print("CAPTURED %s %dx%d" % [ProjectSettings.globalize_path(path), w, h])
		made += 1
		sub.queue_free()
		await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture.cfg"))
	print("CAPTURE_DONE %d" % made)
	get_tree().quit()
