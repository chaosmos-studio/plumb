class_name Snapshot
extends Control

## The share card, caught like a screenshot the moment a level is won: a flash and a shutter, the card
## filling the screen for a beat, then the win sheet rising as the card shrinks to a tilted print above it,
## with Share and Save beside it and a close mark on its corner. Share and Save send or keep the card
## (ShareCard). It lives on the win sheet, so it goes when the sheet does. When the sheet comes back after a
## replay, the same print is simply there again. Nothing is written to the phone unless the player shares
## or saves.

const WIDTH: float = 300.0
const FRAME: float = 12.0
const TILT: float = -4.0
const LAND: float = 0.55
## How long the caught card fills the screen before the sheet comes up under it.
const CATCH: float = 0.45
const ACTION: float = 76.0
## How far the print may come down over the sheet's top edge: its grip and margin, never its heading.
const OVERLAP: float = 36.0

var image: Image
var moment: Result.Moment
var _print: _Print
var _actions: PanelContainer

## Whether a card can be drawn here: not in a headless run.
static func can_take() -> bool:
	return DisplayServer.get_name() != "headless"

## Makes the card for the win, once, and catches it over `sheet`, which the first time waits held for it.
## Without a card (a headless run) the sheet simply rises.
static func take(host: Node, sheet: Sheet, won: Result.Moment, stars: int, heading: String) -> void:
	var first: bool = won.card == null
	if first:
		won.card = await ShareCard.render(host, won, stars, heading)
	if not is_instance_valid(sheet) or sheet.is_queued_for_deletion():
		return
	if won.card == null or won.card.is_empty():
		sheet.rise()
		return
	if not first:
		await sheet.get_tree().create_timer(Sheet.RISE_TIME).timeout
		if not is_instance_valid(sheet) or sheet.is_queued_for_deletion():
			return
	var shot: Snapshot = Snapshot.new()
	shot.image = won.card
	shot.moment = won
	sheet.add_child(shot)
	shot.land(sheet, first)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The print in its place above `sheet`, then its buttons. When `caught`, a flash and the card filling the
## screen, then the sheet rising as the card flies to its place; otherwise the print just settles in.
func land(sheet: Sheet, caught: bool = true) -> void:
	var view: Vector2 = get_viewport_rect().size
	var top: float = Hud.TOP + float(UI.safe_margins(get_viewport())["top"]) + IconButton.SIZE + 12.0
	var bottom: float = sheet.top() + OVERLAP
	var ratio: float = float(image.get_height()) / float(image.get_width())
	var width: float = minf(WIDTH, (bottom - top) / ratio - FRAME * 2.0)
	var print_size: Vector2 = Vector2(width, width * ratio) + Vector2(FRAME, FRAME) * 2.0
	var group: float = print_size.x + 24.0 + ACTION + 56.0
	var at: Vector2 = Vector2((view.x - group) * 0.5, (top + bottom - print_size.y) * 0.5)
	_print = _Print.new(ImageTexture.create_from_image(image))
	_print.size = print_size
	_print.pivot_offset = print_size * 0.5
	add_child(_print)
	var close: IconButton = UI.icon_button(&"close", "Close")
	close.custom_minimum_size = Vector2(56.0, 56.0)
	close.size = Vector2(56.0, 56.0)
	close.position = Vector2(-22.0, -22.0)
	close.pressed.connect(_dismiss)
	_print.add_child(close)
	if caught:
		_print.position = view * 0.5 - print_size * 0.5
		_print.scale = Vector2.ONE * (view.x * 0.94 / print_size.x)
		var flash: ColorRect = ColorRect.new()
		flash.color = Color(1, 1, 1, 0.9)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		Audio.play(&"tap", -2.0, 1.7)
		Audio.buzz(25)
		var fade: Tween = create_tween()
		fade.tween_property(flash, "color:a", 0.0, 0.35)
		fade.tween_callback(flash.queue_free)
		var fly: Tween = create_tween()
		fly.tween_interval(CATCH)
		fly.tween_callback(sheet.rise)
		fly.tween_property(_print, "position", at, LAND).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(_print, "scale", Vector2.ONE, LAND).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(_print, "rotation_degrees", TILT, LAND).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_print.position = at
		_print.rotation_degrees = TILT
		_print.scale = Vector2(0.9, 0.9)
		_print.modulate.a = 0.0
		var t: Tween = create_tween().set_parallel(true)
		t.tween_property(_print, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_print, "modulate:a", 1.0, 0.2)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.add_child(UI.action(&"share", "Share", func() -> void: ShareCard.send(self, image, moment), ACTION))
	column.add_child(UI.action(&"save", "Save", func() -> void: ShareCard.save(self, image, moment), ACTION))
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
	shown.tween_interval(CATCH + LAND * 0.7 if caught else 0.1)
	shown.tween_property(_actions, "modulate:a", 1.0, 0.2)
	shown.parallel().tween_property(close, "modulate:a", 1.0, 0.2)
	close.modulate.a = 0.0

## The tray's height before layout: each action is its button and its name, inside the tray's margins.
func _height() -> float:
	return 2.0 * (ACTION + 28.0) + 14.0 + 28.0

func _dismiss() -> void:
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_property(_print, "scale", Vector2(0.85, 0.85), 0.18)
	t.chain().tween_callback(queue_free)

## The card as a print: a border in the theme's surface colour with a hairline edge, so it sits in a dark
## theme as well as a light one, a soft shadow, and the card inside.
class _Print extends Control:
	var _texture: Texture2D

	func _init(card: Texture2D) -> void:
		_texture = card
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var paper: StyleBoxFlat = StyleBoxFlat.new()
		paper.bg_color = Brand.SURFACE
		paper.border_color = Brand.LINE
		paper.set_border_width_all(2)
		paper.set_corner_radius_all(18)
		paper.shadow_color = Color(0, 0, 0, 0.3)
		paper.shadow_size = 26
		paper.shadow_offset = Vector2(0, 10)
		paper.anti_aliasing = true
		draw_style_box(paper, Rect2(Vector2.ZERO, size))
		var inner: Rect2 = Rect2(Vector2(Snapshot.FRAME, Snapshot.FRAME), size - Vector2(Snapshot.FRAME, Snapshot.FRAME) * 2.0)
		draw_texture_rect(_texture, inner, false)
