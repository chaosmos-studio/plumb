class_name Sheet
extends Control

## A bottom sheet: the screen dims, a rounded panel rises from the bottom, and whatever the caller puts
## in `content` sits in it. Results, failures and settings all use it, so every modal moves the same way.

signal closed

const RISE_TIME: float = 0.34
const FALL_TIME: float = 0.22
const RADIUS: int = 52
const SCRIM_ALPHA: float = 0.42

var content: VBoxContainer
var dismissable: bool = true
var _scrim: ColorRect
var _panel: PanelContainer
var _closing: bool = false

## Opens a sheet over `host`. With `dismissable`, tapping the dimmed area closes it.
static func open(host: Node, can_dismiss: bool = true) -> Sheet:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 60
	host.add_child(canvas)
	var sheet: Sheet = Sheet.new()
	sheet.dismissable = can_dismiss
	canvas.add_child(sheet)
	return sheet

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	_scrim = ColorRect.new()
	_scrim.color = Color(Brand.SCRIM, 0.0)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Brand.SURFACE
	style.corner_radius_top_left = RADIUS
	style.corner_radius_top_right = RADIUS
	style.shadow_color = Color(0, 0, 0, 0.16)
	style.shadow_size = 30
	style.content_margin_left = 56
	style.content_margin_right = 56
	style.content_margin_top = 30
	style.content_margin_bottom = 64
	style.anti_aliasing = true
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	_panel.add_child(column)
	var grip: Control = _Grip.new()
	column.add_child(grip)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(content)

func _ready() -> void:
	_rise()

func _rise() -> void:
	await get_tree().process_frame
	var rest: float = _panel.position.y
	_panel.position.y = rest + _panel.size.y + 40.0
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_panel, "position:y", rest, RISE_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(_scrim, "color:a", SCRIM_ALPHA, RISE_TIME)

func close() -> void:
	if _closing:
		return
	_closing = true
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_panel, "position:y", _panel.position.y + _panel.size.y + 40.0, FALL_TIME).set_ease(Tween.EASE_IN)
	t.tween_property(_scrim, "color:a", 0.0, FALL_TIME)
	await t.finished
	closed.emit()
	get_parent().queue_free()

func _on_scrim_input(event: InputEvent) -> void:
	if not dismissable:
		return
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or \
			(event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		close()

## The small bar at the top of a sheet that says "this slides".
class _Grip extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = 64.0
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Brand.LINE
		box.set_corner_radius_all(4)
		draw_style_box(box, Rect2(Vector2((size.x - w) * 0.5, 2.0), Vector2(w, 8.0)))
