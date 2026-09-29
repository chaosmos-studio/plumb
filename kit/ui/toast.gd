class_name Toast
extends PanelContainer

## A short message in a pill near the bottom that fades away on its own: for "no hint from here" and
## similar, where a modal would be too much and silence would feel broken.

const HOLD: float = 2.2
const FROM_BOTTOM: float = 300.0
const FONT_SIZE: int = 28
const SIDE_ROOM: float = 80.0

static var _current: Toast

var _label: Label

static func say(host: Node, text: String) -> void:
	if is_instance_valid(_current):
		_current.get_parent().queue_free()
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 70
	host.add_child(canvas)
	var toast: Toast = Toast.new()
	toast._build(text)
	canvas.add_child(toast)
	_current = toast

func _build(text: String) -> void:
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Brand.INK
	style.set_corner_radius_all(40)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 18
	style.content_margin_bottom = 20
	style.anti_aliasing = true
	add_theme_stylebox_override("panel", style)
	_label = UI.label(text, FONT_SIZE, Brand.BG)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
	modulate.a = 0.0

func _ready() -> void:
	# A wrapping label asks for no width of its own, which would leave one letter per line: give it the
	# text's width, and wrap only what a narrow screen cannot fit.
	var margins: float = get_theme_stylebox("panel").get_minimum_size().x
	var text_width: float = UI.ui_font().get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_label.custom_minimum_size.x = minf(ceilf(text_width) + 2.0, get_viewport_rect().size.x - SIDE_ROOM - margins)
	await get_tree().process_frame
	var view: Vector2 = get_viewport_rect().size
	size.x = minf(size.x, view.x - SIDE_ROOM)
	position = Vector2((view.x - size.x) * 0.5, view.y - FROM_BOTTOM)
	var t: Tween = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.18)
	t.parallel().tween_property(self, "position:y", position.y - 16.0, 0.24).set_ease(Tween.EASE_OUT)
	t.tween_interval(HOLD)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func() -> void: get_parent().queue_free())
