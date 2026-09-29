extends CanvasLayer

# Scene changes with a short fade, so moving between the title, the level grid and a board never
# flashes a half-built frame.

const OUT_TIME: float = 0.14
const IN_TIME: float = 0.2

var _veil: ColorRect
var _busy: bool = false

func _ready() -> void:
	layer = 100
	_veil = ColorRect.new()
	_veil.color = Brand.BG
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	add_child(_veil)

func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var out: Tween = create_tween()
	out.tween_property(_veil, "modulate:a", 1.0, OUT_TIME)
	await out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var back: Tween = create_tween()
	back.tween_property(_veil, "modulate:a", 0.0, IN_TIME)
	await back.finished
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
