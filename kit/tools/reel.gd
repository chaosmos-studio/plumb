extends Node

## Records a level's reel, the one a player opens from a win's snapshot, as a film for the game's own
## channels. The game's Director stages the level solved, quickly and under a cover, the play screen plays
## its solve as a reel (Replay), and this quits when the reel closes, so Movie Maker's file holds the reel,
## sound and all. `kit/tools/reel.py` runs it at 1080 by 1920 and makes the MP4.

## How much faster than life the staging runs, under the cover.
const RUSH: float = 20.0

func _ready() -> void:
	var level: int = 1
	var look: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("level="):
			level = int(arg.substr(6))
		elif arg == "dark" or arg == "light":
			look = arg + "/"
	Save.path = "user://reel.cfg"
	Coach.enabled = false
	Intro.enabled = false
	ChapterCard.enabled = false
	var cover: CanvasLayer = CanvasLayer.new()
	cover.layer = 120
	var blank: ColorRect = ColorRect.new()
	blank.color = Brand.BG
	blank.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(blank)
	add_child(cover)
	Engine.time_scale = RUSH
	var director: Object = load("res://tools/director.gd").new()
	await director.call("stage", "%swon:%d" % [look, level], self)
	Engine.time_scale = 1.0
	blank.color = Brand.BG
	var game: Node = null
	for child: Node in get_children():
		if child.has_method("_watch"):
			game = child
	if game == null:
		push_error("reel: no play screen to watch")
		get_tree().quit(1)
		return
	game.call("_watch", true)
	await get_tree().process_frame
	cover.queue_free()
	while _replaying(game):
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://reel.cfg"))
	get_tree().quit()

## Whether the play screen still has a reel running; a Replay is a CanvasLayer the screen holds.
func _replaying(game: Node) -> bool:
	for child: Node in game.get_children():
		if child is Replay:
			return true
	return false
