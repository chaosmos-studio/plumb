extends Node

## Measures what each look holds in memory on one build, so Street's budget is set against Classic's (REVAMP_PLAN.md
## section 11). Each screen is opened as the game opens it, given time to settle, then the engine's own counters are
## read: video memory (textures, buffers and render targets), texture memory, the script heap and the node count.
## Desktop drivers use the same compressed formats at the same bits a pixel as the phone (BPTC or S3TC here, ETC2
## there), so the video figures carry over. The phone's own PSS adds the engine's code and its libraries on top.
##
## Each screen gets a run of its own, so nothing one look loaded is counted against the other.
##
## Run: DISPLAY=:0 godot --path . --resolution 360x800 res://tools/look_memory.tscn -- <0 to 3>

const SCREENS: Array = [
	["classic title", "classic", "res://scenes/shell/title.tscn"],
	["classic play", "classic", "res://scenes/game/game.tscn"],
	["street map", "street", "res://scenes/street/map.tscn"],
	["street play", "street", "res://scenes/street/play.tscn"],
]
const SETTLE: float = 2.5

func _ready() -> void:
	Intro.enabled = false
	Save.path = "user://look_memory.cfg"
	Save.look_chosen = true
	Save.tutorial_seen = true
	Pack.use(Pack.Section.MAIN)
	Pack.current = 11
	await get_tree().create_timer(0.5).timeout
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var screen: Array = SCREENS[int(args[0]) if not args.is_empty() else 0]
	# A second argument wins that many doors first, so the street opens further along (19 puts a milestone in view).
	if args.size() > 1:
		var stars: PackedByteArray = PackedByteArray()
		for i: int in range(int(args[1])):
			stars.append(3)
		Save.stars = stars
		Save.gifts = PackedInt32Array([5, 10, 15, 20, 25, 30, 35, 40].filter(func(n: int) -> bool:
			return n <= int(args[1])))
		Pack.current = int(args[1])
	_read("empty")
	var look: String = screen[1]
	Save.app_look = look
	if look == AppLook.CLASSIC:
		Appearance.apply(Save.theme)
	add_child((load(str(screen[2])) as PackedScene).instantiate())
	await get_tree().create_timer(SETTLE).timeout
	_read(str(screen[0]))
	print("LOOK_MEMORY_DONE")
	get_tree().quit()

func _read(label: String) -> void:
	var mb: float = 1024.0 * 1024.0
	print("LOOK_MEMORY %s" % JSON.stringify({
		"screen": label,
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / mb, 0.1),
		"texture_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / mb, 0.1),
		"buffer_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / mb, 0.1),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / mb, 0.1),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}))
