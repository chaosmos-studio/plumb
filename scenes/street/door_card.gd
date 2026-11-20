class_name StreetDoorCard
extends CanvasLayer

## The start card a door drops when tapped (REVAMP_PLAN.md section 3, build/review/revamp2/2-start.png): the door's
## number on a red ribbon, the level's marbles over their holes, its par as footprints, the three helpers (locked
## until their parcels arrive, each showing the door it opens at), and Play. It drops from the top with an overshoot,
## swings to rest, and rises away when closed.

signal play(door: int)
signal closed

## The card's box, ribbon included, and where its frame begins (the ribbon rises above it). Every measure below is
## taken from the concept, in design pixels from the frame's top-left corner.
const SIZE: Vector2 = Vector2(640, 1100)
const FRAME_TOP: float = 140.0
const FRAME_HEIGHT: float = 940.0
## The card's top sits this share of the way down the room left above and below it.
const DROP_TO: float = 0.55
const INSET_RECT: Rect2 = Rect2(48, 92, 544, 262)
const MARBLE: float = 92.0
const MARBLE_GAP: float = 126.0
const MARBLES_Y: float = 160.0
const HOLES_Y: float = 290.0
const PAR_RECT: Rect2 = Rect2(194, 372, 252, 100)
const SLOT: float = 160.0
const SLOT_GAP: float = 18.0
const SLOTS_Y: float = 504.0
## Where Play sits.
const PLAY_RECT: Rect2 = Rect2(130, 700, 380, 180)
## On a wide screen the card turns sideways: the marbles over their holes and par on the left, the helpers and Play on
## the right, under the same ribbon (StreetLayout).
const WIDE_SIZE: Vector2 = Vector2(1040, 620)
const WIDE_FRAME_TOP: float = 120.0
const WIDE_FRAME_HEIGHT: float = 480.0
const WIDE_INSET_RECT: Rect2 = Rect2(40, 74, 480, 250)
const WIDE_PAR_RECT: Rect2 = Rect2(154, 348, 252, 96)
const WIDE_SLOT: float = 128.0
const WIDE_SLOTS: Vector2 = Vector2(580, 84)
const WIDE_PLAY_RECT: Rect2 = Rect2(586, 272, 360, 164)
const SLOT_PIECES: PackedStringArray = ["slot_teal", "slot_purple", "slot_grey"]
const SLOT_GLYPHS: Array[StringName] = [&"footprints", &"ghosts", &"play"]
## The door each helper opens at (REVAMP_PLAN.md section 4.7).
const HELPERS_AT: PackedInt32Array = [5, 10, 15]
## The drop: its time, and the swing after it, a damped spring in radians.
const DROP_TIME: float = 0.45
const SWING_START: float = 0.06
const SWING_STIFFNESS: float = 90.0
const SWING_DAMPING: float = 7.0
const RISE_TIME: float = 0.28

var _door: int = 0
var _colours: PackedInt32Array = PackedInt32Array()
var _par: int = 0
var _best: int = 0
var _dim: ColorRect
var _card: _Card
var _play_button: Button
var _angle: float = 0.0
var _spin: float = 0.0
var _swinging: bool = false
var _open: bool = false
var _shape: Shape = Shape.tall()

## Where everything sits on the card, in its portrait or its wide form. Boxes are measured from the frame's top-left.
class Shape:
	var size: Vector2
	var frame_top: float
	var frame_height: float
	var inset: Rect2
	var marbles_y: float
	var holes_y: float
	var par: Rect2
	var slot: float
	## The first helper slot's top-left corner, and the step to the next.
	var slots: Vector2
	var slot_step: float
	var play: Rect2

	static func tall() -> Shape:
		var s: Shape = Shape.new()
		s.size = StreetDoorCard.SIZE
		s.frame_top = StreetDoorCard.FRAME_TOP
		s.frame_height = StreetDoorCard.FRAME_HEIGHT
		s.inset = StreetDoorCard.INSET_RECT
		s.marbles_y = StreetDoorCard.MARBLES_Y
		s.holes_y = StreetDoorCard.HOLES_Y
		s.par = StreetDoorCard.PAR_RECT
		s.slot = StreetDoorCard.SLOT
		s.slot_step = StreetDoorCard.SLOT + StreetDoorCard.SLOT_GAP
		s.slots = Vector2(s.size.x * 0.5 - s.slot_step - s.slot * 0.5, StreetDoorCard.SLOTS_Y)
		s.play = StreetDoorCard.PLAY_RECT
		return s

	static func wide() -> Shape:
		var s: Shape = Shape.new()
		s.size = StreetDoorCard.WIDE_SIZE
		s.frame_top = StreetDoorCard.WIDE_FRAME_TOP
		s.frame_height = StreetDoorCard.WIDE_FRAME_HEIGHT
		s.inset = StreetDoorCard.WIDE_INSET_RECT
		s.marbles_y = s.inset.position.y + 64.0
		s.holes_y = s.inset.position.y + 188.0
		s.par = StreetDoorCard.WIDE_PAR_RECT
		s.slot = StreetDoorCard.WIDE_SLOT
		s.slot_step = StreetDoorCard.WIDE_SLOT + StreetDoorCard.SLOT_GAP
		s.slots = StreetDoorCard.WIDE_SLOTS
		s.play = StreetDoorCard.WIDE_PLAY_RECT
		return s

func _ready() -> void:
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.04, 0.12, 0.2, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			close())
	add_child(_dim)
	_card = _Card.new()
	_card.owner_card = self
	add_child(_card)
	_play_button = Button.new()
	_play_button.flat = true
	_play_button.focus_mode = Control.FOCUS_NONE
	_play_button.pressed.connect(_on_play)
	_card.add_child(_play_button)
	_reshape()
	# A turned phone or a resized window while the card is up: it takes its other form where it hangs.
	get_viewport().size_changed.connect(func() -> void:
		_reshape()
		if _open:
			var screen: Vector2 = _card.get_viewport_rect().size
			_card.position = Vector2(screen.x * 0.5 - _shape.size.x * 0.5, _top()))

## Picks the card's form for the screen's shape.
func _reshape() -> void:
	_shape = Shape.wide() if StreetLayout.wide(_card.get_viewport_rect().size) else Shape.tall()
	_card.size = _shape.size
	_play_button.position = _shape.play.position + Vector2(0, _shape.frame_top)
	_play_button.size = _shape.play.size
	_card.queue_redraw()

## Where the card's top rests on screen.
func _top() -> float:
	return maxf(10.0, (_card.get_viewport_rect().size.y - _shape.size.y) * DROP_TO)

func open(door: int, board: TiltBoard, par: int, best: int) -> void:
	_door = door
	_par = par
	_best = best
	var seen: Dictionary = {}
	for c: int in board.marble_colour:
		if c != TiltBoard.STONE:
			seen[c] = true
	_colours = PackedInt32Array(seen.keys())
	_colours.sort()
	visible = true
	_open = true
	_reshape()
	var screen: Vector2 = _card.get_viewport_rect().size
	var top: float = _top()
	_card.position = Vector2(screen.x * 0.5 - _shape.size.x * 0.5, -_shape.size.y - 40.0)
	_card.pivot_offset = Vector2(_shape.size.x * 0.5, -top)
	_card.rotation = 0.0
	_card.queue_redraw()
	Audio.play(&"tap", -4.0, 0.8)
	var t: Tween = create_tween().set_parallel()
	t.tween_property(_card, "position:y", top, DROP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_dim, "color:a", 0.32, DROP_TIME)
	t.chain().tween_callback(func() -> void:
		_angle = SWING_START
		_spin = 0.0
		_swinging = true
		Audio.buzz(10, 0.3))

func close() -> void:
	if not _open:
		return
	_open = false
	_swinging = false
	var t: Tween = create_tween().set_parallel()
	t.tween_property(_card, "position:y", -_shape.size.y - 40.0, RISE_TIME).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_IN)
	t.tween_property(_dim, "color:a", 0.0, RISE_TIME)
	t.chain().tween_callback(func() -> void:
		visible = false
		closed.emit())

func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		close()
	elif _open and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_play()

func _process(delta: float) -> void:
	if not _swinging:
		return
	_spin += (-SWING_STIFFNESS * _angle - SWING_DAMPING * _spin) * delta
	_angle += _spin * delta
	_card.rotation = _angle
	if absf(_angle) < 0.0005 and absf(_spin) < 0.002:
		_card.rotation = 0.0
		_swinging = false

func _on_play() -> void:
	if not _open:
		return
	_open = false
	_swinging = false
	_card.rotation = 0.0
	var t: Tween = create_tween()
	t.tween_property(_card, "scale", Vector2(0.94, 0.94), 0.07)
	t.tween_property(_card, "scale", Vector2(1.0, 1.0), 0.12)
	t.tween_callback(func() -> void: play.emit(_door))


class _Card extends Control:
	var owner_card: StreetDoorCard

	func _draw() -> void:
		var c: StreetDoorCard = owner_card
		var shape: StreetDoorCard.Shape = c._shape
		var w: float = size.x
		var font: Font = StreetArt.font()
		var o: Vector2 = Vector2(0.0, shape.frame_top)
		# The frame, then the ribbon over its top edge with the door's number on its face.
		StreetArt.draw_nine(self, "card_frame", Rect2(o, Vector2(w, shape.frame_height)))
		var ribbon_at: Vector2 = Vector2(w * 0.5 - StreetArt.size("ribbon").x * 0.5, shape.frame_top - 132.0)
		StreetArt.draw_at(self, "ribbon", ribbon_at)
		var face: Rect2 = StreetArt.meta_rect("ribbon", "face")
		face = Rect2(ribbon_at + face.position * StreetArt.DESIGN_PER_PIXEL, face.size * StreetArt.DESIGN_PER_PIXEL)
		draw_string(font, Vector2(face.position.x, face.get_center().y + 33.0), str(c._door), HORIZONTAL_ALIGNMENT_CENTER,
			face.size.x, 96, StreetUI.CREAM)
		if c._best > 0:
			for i: int in range(3):
				StreetArt.draw(self, "star" if i < c._best else "star_dim", o + Vector2(w * 0.5 + (i - 1) * 36.0,
					shape.inset.position.y - 30.0), 1.2)
		# The level's marbles over their holes, centred in the inset.
		var inset: Rect2 = Rect2(o + shape.inset.position, shape.inset.size)
		StreetArt.draw_nine(self, "card_inset", inset)
		var n: int = c._colours.size()
		var body_w: float = StreetDoorCard.MARBLE
		var k: float = body_w / StreetArt.size("marble_red").x
		for i: int in range(n):
			var x: float = inset.get_center().x + (float(i) - float(n - 1) * 0.5) * StreetDoorCard.MARBLE_GAP
			var colour: Color = Palette.marble(c._colours[i])
			var top: Vector2 = Vector2(x, o.y + shape.marbles_y)
			StreetArt.draw(self, "marble_" + StreetArt.COLOURS[c._colours[i] % 4], top, k)
			StreetArt.draw(self, "eye", top + Vector2(-0.17, -0.04) * body_w, k)
			StreetArt.draw(self, "eye", top + Vector2(0.17, -0.04) * body_w, k)
			StreetArt.draw(self, "mouth_smile", top + Vector2(0.0, 0.16) * body_w, k)
			var arrow: float = o.y + (shape.marbles_y + shape.holes_y) * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(x - 11, arrow - 6), Vector2(x + 11, arrow - 6),
				Vector2(x, arrow + 8)]), colour)
			var hole: Vector2 = Vector2(x, o.y + shape.holes_y)
			draw_set_transform(hole, 0.0, Vector2(1.0, 0.82))
			draw_circle(Vector2(0, 6), 46.0, colour.darkened(0.2), true, -1.0, true)
			draw_circle(Vector2.ZERO, 46.0, colour, true, -1.0, true)
			draw_circle(Vector2(0, 2), 30.0, Palette.HOLE, true, -1.0, true)
			draw_set_transform(Vector2.ZERO)
		# Par, as footprints, with sparks either side.
		var pill: Rect2 = Rect2(o + shape.par.position, shape.par.size)
		StreetUI.sparks(self, pill, 44.0)
		StreetArt.draw_nine(self, "pill_orange", pill, _pill_scale("pill_orange", pill.size.y))
		StreetUI.glyph(self, &"footprints", pill.position + Vector2(76.0, pill.size.y * 0.48), pill.size.y * 0.92)
		draw_string(font, Vector2(pill.position.x + 120.0, pill.get_center().y + 27.0), str(c._par),
			HORIZONTAL_ALIGNMENT_CENTER, 100.0, 76, StreetUI.CREAM)
		# The helpers, locked until their door.
		var slot: float = shape.slot
		for i: int in range(3):
			var at: Vector2 = o + shape.slots + Vector2(float(i) * shape.slot_step, 0.0)
			var open_now: bool = c._door >= StreetDoorCard.HELPERS_AT[i]
			var piece: String = StreetDoorCard.SLOT_PIECES[i] if open_now else "slot_grey"
			StreetArt.draw_at(self, piece, at, slot / StreetArt.size(piece).x)
			var centre: Vector2 = at + Vector2.ONE * slot * 0.5
			if open_now:
				StreetUI.glyph(self, StreetDoorCard.SLOT_GLYPHS[i], centre, slot * 0.69)
			else:
				StreetUI.glyph(self, &"lock", centre + Vector2(0.0, -8.0), slot * 0.6)
				draw_string_outline(font, Vector2(at.x, at.y + slot - 14.0), str(StreetDoorCard.HELPERS_AT[i]),
					HORIZONTAL_ALIGNMENT_RIGHT, slot - 22.0, 34, 8, Color("7d8196"))
				draw_string(font, Vector2(at.x, at.y + slot - 14.0), str(StreetDoorCard.HELPERS_AT[i]),
					HORIZONTAL_ALIGNMENT_RIGHT, slot - 22.0, 34, StreetUI.CREAM)
		# Play.
		var play_rect: Rect2 = Rect2(o + shape.play.position, shape.play.size)
		StreetUI.sparks(self, play_rect, 50.0)
		StreetArt.draw_nine(self, "pill_play", play_rect, _pill_scale("pill_play", play_rect.size.y))
		StreetUI.glyph(self, &"play", play_rect.get_center() + Vector2(6.0, -6.0), play_rect.size.y * 0.71)

	## A painted pill's scale for it to stand `height` tall.
	func _pill_scale(piece: String, height: float) -> float:
		return height / StreetArt.size(piece).y
