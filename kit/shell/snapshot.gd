class_name Snapshot
extends Control

## The share card, caught like a screenshot. A flash and a shutter, then the card shrinks from the whole
## screen to a tilted print over the top of the win sheet, with Share, Save and Reel beside it and a close
## mark on its corner. Share and Save send or keep the card (ShareCard); Reel plays the solve as a reel
## (Replay). It lives on the win sheet, so it goes when the sheet does.

const WIDTH: float = 300.0
const FRAME: float = 12.0
const TILT: float = -4.0
const LAND: float = 0.55
const ACTION: float = 76.0

var image: Image
var moment: Result.Moment
var _print: _Print
var _actions: PanelContainer

## Makes the card for the win and catches it over `sheet`. One at a time: a second tap waits on the first.
static func take(host: Node, sheet: Sheet, won: Result.Moment, stars: int, heading: String) -> void:
	if not is_instance_valid(sheet) or sheet.has_meta(&"snapshot"):
		return
	sheet.set_meta(&"snapshot", true)
	var made: Image = await ShareCard.render(host, won, stars, heading)
	if not is_instance_valid(sheet):
		return
	sheet.remove_meta(&"snapshot")
	if made == null or made.is_empty():
		Toast.say(host, "Could not make the card here")
		return
	for old: Node in sheet.get_children():
		if old is Snapshot:
			old.queue_free()
	var shot: Snapshot = Snapshot.new()
	shot.image = made
	shot.moment = won
	sheet.add_child(shot)
	shot.land(sheet.top())

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The flash, then the print flying from full screen to its place above `sheet_top`, then its buttons.
func land(sheet_top: float) -> void:
	var view: Vector2 = get_viewport_rect().size
	var top: float = Hud.TOP + float(UI.safe_margins(get_viewport())["top"]) + IconButton.SIZE + 12.0
	# It may lie over the top of the sheet, the heading and stars, which the card repeats anyway.
	var bottom: float = sheet_top + 150.0
	var ratio: float = float(image.get_height()) / float(image.get_width())
	var width: float = minf(WIDTH, (bottom - top) / ratio - FRAME * 2.0)
	var print_size: Vector2 = Vector2(width, width * ratio) + Vector2(FRAME, FRAME) * 2.0
	var group: float = print_size.x + 24.0 + ACTION + 56.0
	var at: Vector2 = Vector2((view.x - group) * 0.5, (top + bottom - print_size.y) * 0.5)
	_print = _Print.new(ImageTexture.create_from_image(image))
	_print.size = print_size
	_print.pivot_offset = print_size * 0.5
	_print.position = view * 0.5 - print_size * 0.5
	_print.scale = Vector2.ONE * (view.x * 0.94 / print_size.x)
	add_child(_print)
	var close: IconButton = UI.icon_button(&"close", "Close")
	close.custom_minimum_size = Vector2(56.0, 56.0)
	close.size = Vector2(56.0, 56.0)
	close.position = Vector2(-22.0, -22.0)
	close.pressed.connect(_dismiss)
	_print.add_child(close)
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	Audio.play(&"tap", -2.0, 1.7)
	Audio.buzz(25)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(flash, "color:a", 0.0, 0.35)
	t.tween_property(_print, "position", at, LAND).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_print, "scale", Vector2.ONE, LAND).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_print, "rotation_degrees", TILT, LAND).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(flash.queue_free)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.add_child(UI.action(&"share", "Share", func() -> void: ShareCard.send(self, image, moment), ACTION))
	column.add_child(UI.action(&"save", "Save", func() -> void: ShareCard.save(self, image, moment), ACTION))
	if moment.watch.is_valid():
		column.add_child(UI.action(&"reel", "Reel", _reel, ACTION))
	_actions = PanelContainer.new()
	var tray: StyleBoxFlat = StyleBoxFlat.new()
	tray.bg_color = Brand.SURFACE
	tray.set_corner_radius_all(48)
	tray.set_content_margin_all(14.0)
	tray.shadow_color = Color(0, 0, 0, 0.22)
	tray.shadow_size = 18
	tray.shadow_offset = Vector2(0, 6)
	tray.anti_aliasing = true
	_actions.add_theme_stylebox_override("panel", tray)
	_actions.add_child(column)
	_actions.position = Vector2(at.x + print_size.x + 24.0, at.y + (print_size.y - _height()) * 0.5)
	_actions.modulate.a = 0.0
	add_child(_actions)
	var shown: Tween = create_tween()
	shown.tween_interval(0.15 + LAND * 0.7)
	shown.tween_property(_actions, "modulate:a", 1.0, 0.2)

## The tray's height before layout: each action is its button and its name, inside the tray's margins.
func _height() -> float:
	var n: int = 3 if moment.watch.is_valid() else 2
	return n * (ACTION + 28.0) + (n - 1) * 14.0 + 28.0

func _reel() -> void:
	var watch: Callable = moment.watch
	queue_free()
	watch.call(true)

func _dismiss() -> void:
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_property(_print, "scale", Vector2(0.85, 0.85), 0.18)
	t.chain().tween_callback(queue_free)

## The card as a print: a white border, a soft shadow, and the card inside.
class _Print extends Control:
	var _texture: Texture2D

	func _init(card: Texture2D) -> void:
		_texture = card
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var paper: StyleBoxFlat = StyleBoxFlat.new()
		paper.bg_color = Color.WHITE
		paper.set_corner_radius_all(18)
		paper.shadow_color = Color(0, 0, 0, 0.3)
		paper.shadow_size = 26
		paper.shadow_offset = Vector2(0, 10)
		paper.anti_aliasing = true
		draw_style_box(paper, Rect2(Vector2.ZERO, size))
		var inner: Rect2 = Rect2(Vector2(Snapshot.FRAME, Snapshot.FRAME), size - Vector2(Snapshot.FRAME, Snapshot.FRAME) * 2.0)
		draw_texture_rect(_texture, inner, false)
