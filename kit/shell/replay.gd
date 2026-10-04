class_name Replay
extends CanvasLayer

## Watching a solve again, at speed. The game plays its own moves back while this holds the game clock at
## SPEED, puts the screen's controls away so only the board and a small Replay mark show, and takes a tap
## anywhere as a wish to skip to the end, which the game reads from `skipping` between moves. The clock
## and the controls come back when it is done or the screen goes.

const SPEED: float = 2.2
const LAYER: int = 50

var skipping: bool = false
var _hidden: Array[CanvasLayer] = []

## Starts a replay over `host`. The game calls `finish` when its last move has played.
static func begin(host: Node) -> Replay:
	var replay: Replay = Replay.new()
	host.add_child(replay)
	return replay

func _ready() -> void:
	layer = LAYER
	Engine.time_scale = SPEED
	# Controls sit on layers from 1 up; a backdrop under the board, on a lower layer, stays.
	for child: Node in get_parent().get_children():
		if child is CanvasLayer and child != self and (child as CanvasLayer).visible and (child as CanvasLayer).layer >= 1:
			(child as CanvasLayer).visible = false
			_hidden.append(child)
	var root: Control = Control.new()
	root.theme = UI.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
				or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
			skipping = true)
	add_child(root)
	var mark: VBoxContainer = VBoxContainer.new()
	mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mark.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mark.offset_top = Hud.TOP + float(UI.safe_margins(get_viewport())["top"]) + 6.0
	mark.add_theme_constant_override("separation", 4)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_child(UI.centred(_Pill.new()))
	mark.add_child(UI.caption("Tap to skip", 18))
	root.add_child(mark)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_show_controls()

func finish() -> void:
	Engine.time_scale = 1.0
	_show_controls()
	queue_free()

func _show_controls() -> void:
	for hidden: CanvasLayer in _hidden:
		if is_instance_valid(hidden):
			hidden.visible = true
	_hidden.clear()

## The Replay mark: the fast-forward sign and the word, on a pill in the accent colour.
class _Pill extends Control:
	const HEIGHT: float = 64.0

	func _init() -> void:
		custom_minimum_size = Vector2(212.0, HEIGHT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Brand.ACCENT
		box.set_corner_radius_all(int(HEIGHT * 0.5))
		box.anti_aliasing = true
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		Icons.draw(self, &"watch", Vector2(44.0, size.y * 0.5), 40.0, Brand.ACCENT_INK)
		var font: Font = UI.ui_font()
		draw_string(font, Vector2(76.0, size.y * 0.5 + 11.0), "Replay", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Brand.ACCENT_INK)
