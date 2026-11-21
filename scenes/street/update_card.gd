class_name StreetUpdateCard
extends CanvasLayer

## The update card on the street (REVAMP_PLAN.md section 7): the game's own card, in Street's look, for a newer
## version on Google Play. A picture, one line of what is new, and one big button: Update (an arrow into a tray) while
## an update is on offer, Restart once it has downloaded. A small X puts it away for later, except when the version
## must go out. It pops in over a lightly dimmed street, or fades in under Reduce motion, and turns sideways on a wide
## screen. PlayCore says what Play knows and counts each step for analytics.

signal closed

## Portrait: the card's box (ribbon included), where its frame begins, and its parts, in design pixels from the
## frame's top-left corner.
const SIZE: Vector2 = Vector2(640, 860)
const FRAME_TOP: float = 120.0
const FRAME_HEIGHT: float = 740.0
const PICTURE: Rect2 = Rect2(48, 92, 544, 306)
const LINE_Y: float = 470.0
const BUTTON: Rect2 = Rect2(130, 540, 380, 160)
## Wide: the picture on the left, the line and the button on the right.
const WIDE_SIZE: Vector2 = Vector2(1040, 560)
const WIDE_FRAME_TOP: float = 110.0
const WIDE_FRAME_HEIGHT: float = 420.0
const WIDE_PICTURE: Rect2 = Rect2(40, 70, 520, 292)
const WIDE_LINE_Y: float = 150.0
const WIDE_BUTTON: Rect2 = Rect2(610, 200, 360, 150)
## The line's size, and the least it shrinks to for a long one.
const LINE_SIZE: int = 46
const LINE_MIN: int = 30
## The X that puts the card away, and how far it sits in from the frame's corner.
const CLOSE: float = 92.0
const CLOSE_IN: float = 18.0
## The picture when the feed has none: a scene from the street, small and with its mipmaps.
const PICTURE_FILE: String = "res://assets/street/update_picture.png"
const POP_TIME: float = 0.4
const FADE_TIME: float = 0.2
const DIM: float = 0.18

## Whether the card offers the download (false) or the restart into a downloaded one (true).
var ready_to_restart: bool = false
var _immediate: bool = false
var _line: String = ""
var _picture: Texture2D
var _wide: bool = false
var _dim: ColorRect
var _card: _Card
var _go: Button
var _close: Button
var _open: bool = false

func _ready() -> void:
	layer = 6
	_immediate = not ready_to_restart and PlayCore.update_mode() == "immediate"
	var code: int = int(PlayCore.update_info().get("code", 0))
	var note: Dictionary = PlayCore.note()
	_line = "" if ready_to_restart else UpdatePolicy.line(note, code)
	_picture = PlayCore.picture_of(note) if int(note.get("latest", 0)) == code else null
	# Held here, not loaded where it is drawn: a texture nothing holds is freed, and the card would draw nothing.
	if _picture == null:
		_picture = load(PICTURE_FILE) as Texture2D
	_dim = ColorRect.new()
	_dim.color = Color(0.04, 0.12, 0.2, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and not _immediate:
			_later())
	add_child(_dim)
	_card = _Card.new()
	_card.owner_card = self
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	_go = _flat_button(_on_go)
	_card.add_child(_go)
	_close = _flat_button(_later)
	_close.visible = not _immediate
	_card.add_child(_close)
	_layout()
	get_viewport().size_changed.connect(_layout)
	# The banner steps aside while the card is up: it is a moment, not a screen to carry an ad (decision 7).
	Ads.cover(true)
	_open = true
	if not ready_to_restart:
		PlayCore.card_shown()
	Audio.play(&"tap", -4.0, 0.9)
	var t: Tween = create_tween().set_parallel()
	t.tween_property(_dim, "color:a", DIM, FADE_TIME)
	if Save.reduce_motion:
		_card.modulate.a = 0.0
		t.tween_property(_card, "modulate:a", 1.0, FADE_TIME)
	else:
		_card.scale = Vector2(0.82, 0.82)
		_card.modulate.a = 0.0
		t.tween_property(_card, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_card, "modulate:a", 1.0, FADE_TIME)

func _exit_tree() -> void:
	if _open:
		Ads.cover(false)

static func _flat_button(on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b

## Lays the card out for the screen's shape, centred.
func _layout() -> void:
	var screen: Vector2 = _card.get_viewport_rect().size
	_wide = StreetLayout.wide(screen)
	_card.size = WIDE_SIZE if _wide else SIZE
	_card.position = (screen - _card.size) * 0.5
	_card.pivot_offset = _card.size * 0.5
	var b: Rect2 = button_rect()
	_go.position = b.position
	_go.size = b.size
	var frame: Rect2 = frame_rect()
	_close.size = Vector2.ONE * CLOSE
	_close.position = Vector2(frame.end.x - CLOSE - CLOSE_IN, frame.position.y + CLOSE_IN)
	_card.queue_redraw()

func frame_rect() -> Rect2:
	var top: float = WIDE_FRAME_TOP if _wide else FRAME_TOP
	return Rect2(Vector2(0.0, top), Vector2(_card.size.x, WIDE_FRAME_HEIGHT if _wide else FRAME_HEIGHT))

func picture_rect() -> Rect2:
	var r: Rect2 = WIDE_PICTURE if _wide else PICTURE
	return Rect2(r.position + Vector2(0.0, frame_rect().position.y), r.size)

func button_rect() -> Rect2:
	var r: Rect2 = WIDE_BUTTON if _wide else BUTTON
	if _line == "" and not _wide:
		r.position.y -= 40.0
	return Rect2(r.position + Vector2(0.0, frame_rect().position.y), r.size)

func _on_go() -> void:
	if not _open:
		return
	Audio.play(&"pop", -4.0, 1.1)
	Audio.buzz(14, 0.4)
	if ready_to_restart:
		PlayCore.complete_update()
	else:
		PlayCore.start_update()
	_dismiss()

func _later() -> void:
	if not _open or _immediate:
		return
	if not ready_to_restart:
		PlayCore.later()
	Audio.play(&"tap", -8.0)
	_dismiss()

func _dismiss() -> void:
	_open = false
	Ads.cover(false)
	var t: Tween = create_tween().set_parallel()
	t.tween_property(_dim, "color:a", 0.0, FADE_TIME)
	t.tween_property(_card, "modulate:a", 0.0, FADE_TIME)
	if not Save.reduce_motion:
		t.tween_property(_card, "scale", Vector2(0.9, 0.9), FADE_TIME)
	t.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())

func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		_later()
	elif _open and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_go()


class _Card extends Control:
	var owner_card: StreetUpdateCard

	func _draw() -> void:
		var c: StreetUpdateCard = owner_card
		var frame: Rect2 = c.frame_rect()
		var font: Font = StreetArt.font()
		StreetArt.draw_nine(self, "card_frame", frame)
		# The ribbon over the frame's top edge, with an arrow into a tray, or a tick once it has downloaded.
		var ribbon_at: Vector2 = Vector2(size.x * 0.5 - StreetArt.size("ribbon").x * 0.5, frame.position.y - 132.0)
		StreetArt.draw_at(self, "ribbon", ribbon_at)
		var face: Rect2 = StreetArt.meta_rect("ribbon", "face")
		face = Rect2(ribbon_at + face.position * StreetArt.DESIGN_PER_PIXEL, face.size * StreetArt.DESIGN_PER_PIXEL)
		if c.ready_to_restart:
			StreetArt.draw(self, "icon_tick", face.get_center(), face.size.y * 0.8 / StreetArt.size("icon_tick").y)
		else:
			StreetUI.glyph(self, &"update", face.get_center() + Vector2(0, 2), face.size.y * 0.86)
		# The picture, filling its inset, the feed's when it has one, else a scene from the street.
		var pic: Rect2 = c.picture_rect()
		StreetArt.draw_nine(self, "card_inset", pic)
		var inner: Rect2 = pic.grow(-14.0)
		var tex: Texture2D = c._picture
		if tex != null:
			var src: Vector2 = Vector2(tex.get_size())
			var k: float = maxf(inner.size.x / src.x, inner.size.y / src.y)
			var cut: Vector2 = inner.size / k
			draw_texture_rect_region(tex, inner, Rect2((src - cut) * Vector2(0.5, 0.42), cut))
		# One line of what is new, shrunk to fit if it must.
		if c._line != "":
			var room: float = (size.x - 80.0) if not c._wide else (size.x - c.button_rect().position.x - 40.0)
			var left: float = 40.0 if not c._wide else c.button_rect().position.x - 10.0
			var y: float = frame.position.y + (StreetUpdateCard.WIDE_LINE_Y if c._wide else StreetUpdateCard.LINE_Y)
			var px: int = StreetUpdateCard.LINE_SIZE
			while px > StreetUpdateCard.LINE_MIN and font.get_string_size(c._line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
				px -= 2
			draw_string(font, Vector2(left, y), c._line, HORIZONTAL_ALIGNMENT_CENTER, room, px, StreetUI.INK)
		# The one button.
		var b: Rect2 = c.button_rect()
		StreetUI.sparks(self, b, 50.0)
		StreetArt.draw_nine(self, "pill_play", b, b.size.y / StreetArt.size("pill_play").y)
		StreetUI.glyph(self, &"restart" if c.ready_to_restart else &"update", b.get_center() + Vector2(0, -6.0),
			b.size.y * 0.62)
		# The X for later.
		if c._close.visible:
			var x: Rect2 = Rect2(c._close.position, c._close.size)
			StreetUI.button(self, x.get_center(), x.size.x * 0.5, StreetUI.RED)
			StreetUI.glyph(self, &"close", x.get_center(), x.size.x * 0.5)
