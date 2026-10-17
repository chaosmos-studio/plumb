extends CanvasLayer

# A short fade, so a scene change never flashes a half-built frame.

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
	_veil.color = Brand.BG
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

## Android's back button and gesture, which would otherwise close the app.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _busy:
		GoBack.request(get_tree())
