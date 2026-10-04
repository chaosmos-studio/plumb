class_name Sheet
extends Control

## A bottom sheet: the screen dims, a rounded panel rises from the bottom, and whatever the caller puts
## in `content` sits in it. Results, failures and settings all use it, so every modal moves the same way.
## A dismissable sheet closes on a tap on the dimmed area or a drag down on its panel. The banner steps
## aside while any sheet is open.

signal closed
signal rising

const RISE_TIME: float = 0.34
## The longest a held sheet waits for `rise()` before it rises anyway, so a sheet is never lost.
const HOLD_MAX: float = 2.0
const FALL_TIME: float = 0.22
const SETTLE_TIME: float = 0.2
const RADIUS: int = 52
const SCRIM_ALPHA: float = 0.42
const LAYER: int = 60
## A drag down past this share of the panel's height closes the sheet on release, as does a flick faster
## than FLICK pixels a second. Less than SLOP pixels of movement is still a tap, so a button pressed with a
## shaky finger still works.
const DRAG_CLOSE: float = 0.3
const FLICK: float = 1400.0
const SLOP: float = 14.0

## Open sheets, newest last: only the top one follows a drag.
static var _open: Array[Sheet] = []

var content: VBoxContainer
var dismissable: bool = true
## Kept below the screen until `rise()`, for a sheet that something else comes before.
var held: bool = false
var _risen: bool = false
var _touch_from: float = -1.0
var _dragging: bool = false
var _flick: bool = false
var _scrim: ColorRect
## The panel stays where its anchors put it; this full-screen holder is what slides, by `_drop` of the
## panel's current height. On a frame with no physics step Godot lays the panel out only after the next
## process_frame, so its height is not known when the sheet opens: it is measured on every step instead.
var _slide: Control
var _panel: PanelContainer
var _drop: float = 1.0
var _motion: Tween
var _closing: bool = false

## Opens a sheet over `host`, and over the layer `host` is drawn on if that is higher, as for the ending.
## With `dismissable`, tapping the dimmed area closes it. With `hold`, it waits below the screen for
## `rise()`.
static func open(host: Node, can_dismiss: bool = true, hold: bool = false) -> Sheet:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = LAYER
	var above: Node = host
	while above != null and not above is CanvasLayer:
		above = above.get_parent()
	if above != null:
		canvas.layer = maxi(LAYER, (above as CanvasLayer).layer + 1)
	host.add_child(canvas)
	var sheet: Sheet = Sheet.new()
	sheet.dismissable = can_dismiss
	sheet.held = hold
	canvas.add_child(sheet)
	return sheet

static func any_open() -> bool:
	return not _open.is_empty()

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	_scrim = ColorRect.new()
	_scrim.color = Color(Brand.SCRIM, 0.0)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)
	_slide = Control.new()
	_slide.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slide)
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
	_slide.add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	_panel.add_child(column)
	var grip: Control = _Grip.new()
	column.add_child(grip)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(content)

func _enter_tree() -> void:
	_open.append(self)
	Ads.cover(true)

func _exit_tree() -> void:
	_open.erase(self)
	Ads.cover(false)

func _ready() -> void:
	# Below the screen whatever the panel's height turns out to be, until the first step measures it.
	_slide.position.y = get_viewport_rect().size.y
	if held:
		get_tree().create_timer(HOLD_MAX).timeout.connect(rise)
		return
	rise()

## Brings the sheet up and the screen behind it down: at once for most sheets, on cue for a held one.
func rise() -> void:
	if _risen or _closing:
		return
	_risen = true
	rising.emit()
	_motion = create_tween().set_parallel(true)
	_motion.tween_method(_set_drop, 1.0, 0.0, RISE_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_scrim, "color:a", SCRIM_ALPHA, RISE_TIME)

func _set_drop(drop: float) -> void:
	_drop = drop
	_slide.position.y = drop * (_panel.size.y + 40.0)

func close() -> void:
	if _closing:
		return
	_closing = true
	if _motion != null:
		_motion.kill()
	_motion = create_tween().set_parallel(true)
	_motion.tween_method(_set_drop, _drop, 1.0, FALL_TIME).set_ease(Tween.EASE_IN)
	_motion.tween_property(_scrim, "color:a", 0.0, FALL_TIME)
	await _motion.finished
	closed.emit()
	get_parent().queue_free()

func _on_scrim_input(event: InputEvent) -> void:
	if not dismissable:
		return
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or \
			(event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		close()

## The drag is read before the GUI, so it works wherever on the panel the finger lands, buttons and labels
## included, except inside a list that scrolls, where a drag scrolls the list, and on a slider.
func _input(event: InputEvent) -> void:
	if not dismissable or _closing or _open.back() != self:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).index == 0:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_touch_from = touch.position.y if _grabs(touch.position) else -1.0
			_dragging = false
			_flick = false
		elif _touch_from >= 0.0:
			_touch_from = -1.0
			if _dragging:
				_dragging = false
				if _drop > DRAG_CLOSE or _flick:
					close()
				else:
					_settle()
	elif event is InputEventScreenDrag and _touch_from >= 0.0 and (event as InputEventScreenDrag).index == 0:
		var drag: InputEventScreenDrag = event
		var down: float = drag.position.y - _touch_from
		if not _dragging and down > SLOP:
			_dragging = true
			if _motion != null:
				_motion.kill()
		if _dragging:
			_set_drop(maxf(0.0, down - SLOP) / (_panel.size.y + 40.0))
			_scrim.color.a = SCRIM_ALPHA * (1.0 - _drop)
			_flick = drag.velocity.y > FLICK

func _grabs(at: Vector2) -> bool:
	if not _panel.get_global_rect().has_point(at):
		return false
	for kind: String in ["ScrollContainer", "Range"]:
		for keep: Node in _panel.find_children("*", kind, true, false):
			if (keep as Control).get_global_rect().has_point(at):
				return false
	return true

## Where the panel's top edge is on screen once it has risen, for anything that sits above the sheet.
func top() -> float:
	return _panel.get_global_rect().position.y - _slide.position.y

## Back up into place after a drag that did not go far enough.
func _settle() -> void:
	_motion = create_tween().set_parallel(true)
	_motion.tween_method(_set_drop, _drop, 0.0, SETTLE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_scrim, "color:a", SCRIM_ALPHA, SETTLE_TIME)

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
