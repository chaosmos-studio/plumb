class_name StreetMoment
extends CanvasLayer

## What the parcel and the milestone share (REVAMP_PLAN.md section 8, moments 15 and 16): a painted backdrop for the
## screen's shape, the coin pill top right, the three helpers' slots with their counts, a wobbler for taps, and a
## Play pill to go on that shows when the moment is over. A tap anywhere once it is over goes on too. The moment's
## rewards are in the save before anything moves, so leaving early loses nothing. `done` fires as it closes.

signal done

## The helpers' slots, in a row in the sky's top-left corner across from the coin pill: their size and the gap
## between them.
const SLOT: float = 84.0
const SLOT_GAP: float = 16.0
## The Play pill: its size and its middle's height, as a share of the screen's.
const GO_SIZE: Vector2 = Vector2(300.0, 140.0)
const GO_AT: float = 0.91
const PILL_EDGE: float = 22.0
## On a wide screen (720 tall) the scene is drawn this size beside portrait's, the slots and pill kept at theirs.
const WIDE_SCALE: float = 0.7
## A slot's painted piece and glyph, by helper (StreetRewards.Booster). Spare step's slot is the grey one in yellow.
const SLOT_PIECES: PackedStringArray = ["slot_teal", "slot_purple", "slot_grey"]
const SLOT_TINTS: Array[Color] = [Color.WHITE, Color.WHITE, Color("ffc23d")]
const SLOT_ICONS: PackedStringArray = ["icon_footprints", "icon_ghosts", "icon_spare_step"]

## The door whose parcel or milestone this is.
var door: int = 0
var size: Vector2 = Vector2.ZERO
var wide: bool = false
## Everything's size against the portrait layout's.
var u: float = 1.0
var root: Control
var stage: Node2D
var coins: StreetCoinPill
var wobbler: StreetWobbler
var finished: bool = false
var _backdrop: TextureRect
var _slots: _Slots
var _go: Button
var _go_face: StreetPiece
var _shown_coins: int = 0
var _closing: bool = false

## The backdrop this moment is painted on.
func backdrop_path() -> String:
	return StreetArt.WIN_BACKDROP

func _ready() -> void:
	size = get_viewport().get_visible_rect().size
	wide = StreetLayout.wide(size)
	u = WIDE_SCALE if wide else 1.0
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_input)
	add_child(root)
	_backdrop = TextureRect.new()
	_backdrop.texture = StreetArt.backdrop(backdrop_path(), wide)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.size = size
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_backdrop)
	stage = Node2D.new()
	root.add_child(stage)
	wobbler = StreetWobbler.new()
	add_child(wobbler)
	_slots = _Slots.new()
	root.add_child(_slots)
	coins = StreetCoinPill.new()
	coins.follow_save = false
	coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coins)
	_go = Button.new()
	_go.flat = true
	_go.focus_mode = Control.FOCUS_NONE
	_go.size = GO_SIZE * u
	_go.visible = false
	_go.pressed.connect(close)
	root.add_child(_go)
	_go_face = _GoFace.new()
	_go_face.k = u
	_go.add_child(_go_face)
	_place_frame()
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	get_viewport().size_changed.connect(_on_resize)

## Puts the pill, the slots and the Play pill for the screen's shape.
func _place_frame() -> void:
	var safe: Dictionary = UI.safe_margins(get_viewport())
	coins.position = Vector2(size.x - float(safe["right"]) - PILL_EDGE - coins.size.x, float(safe["top"]) + PILL_EDGE)
	_slots.position = Vector2(float(safe["left"]) + PILL_EDGE + _slots.width() * 0.5,
		coins.position.y + StreetCoinPill.HEIGHT * 0.5)
	_go.position = go_centre() - _go.size * 0.5

## Where the Play pill stands: under the middle in portrait, toward the right edge on a wide screen.
func go_centre() -> Vector2:
	return Vector2(size.x * 0.84, size.y * 0.86) if wide else Vector2(size.x * 0.5, size.y * GO_AT)

func _on_resize() -> void:
	size = get_viewport().get_visible_rect().size
	_backdrop.size = size
	_backdrop.texture = StreetArt.backdrop(backdrop_path(), StreetLayout.wide(size))
	_place_frame()

## Starts the purse showing what it held before this moment's coins (already in the save).
func coins_before(amount: int) -> void:
	_shown_coins = Save.coins - amount
	coins.set_value(_shown_coins)

## Flies `amount` coins from `from` into the pill. Answers how long it takes.
func fly_coins(from: Vector2, amount: int) -> float:
	return StreetCoinPill.fly(stage, from, coins, amount, func(share: int) -> void:
		_shown_coins += share
		coins.count_to(_shown_coins))

## The slots show the helpers' counts before this moment's (already in the save), `gained` by helper.
func slots_before(gained: PackedInt32Array) -> void:
	for b: int in range(3):
		_slots.counts[b] = Save.booster_count(StreetRewards.BOOSTER_IDS[b]) - gained[b]
	_slots.queue_redraw()

## A helper's slot's middle, on screen.
func slot_point(b: int) -> Vector2:
	return _slots.position + _slots.slot_centre(b)

## A helper lands in its slot: its count goes up by `n` and the slot bounces.
func land_helper(b: int, n: int) -> void:
	_slots.counts[b] += n
	_slots.bump(b)
	Audio.play(&"pop", -6.0, 1.2)

## Flies a helper's icon from `from` into its slot, then lands it. Answers how long it takes.
func fly_helper(b: int, from: Vector2, n: int) -> float:
	var icon: StreetPiece = StreetPiece.new(SLOT_ICONS[b], SLOT * 0.7 * u / StreetArt.size(SLOT_ICONS[b]).x)
	icon.position = from
	stage.add_child(icon)
	if Save.reduce_motion:
		icon.queue_free()
		land_helper(b, n)
		return 0.0
	var t: Tween = icon.create_tween().set_parallel()
	t.tween_property(icon, "position", slot_point(b), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(icon, "scale", Vector2(0.7, 0.7), 0.6)
	t.chain().tween_callback(func() -> void:
		land_helper(b, n)
		icon.queue_free())
	return 0.6

## The moment is over: the Play pill springs up, and a tap anywhere goes on.
func finish() -> void:
	finished = true
	_go.visible = true
	_go.pivot_offset = _go.size * 0.5
	if not Save.reduce_motion:
		_go.scale = Vector2(0.4, 0.4)
		_go.create_tween().tween_property(_go, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)

func close() -> void:
	if _closing:
		return
	_closing = true
	var t: Tween = root.create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.25)
	t.tween_callback(func() -> void:
		done.emit()
		queue_free())

func _on_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tap((event as InputEventScreenTouch).position)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if finished:
			close()
		else:
			hurry()

## A tap on the moment at `at`: subclasses wobble what is under it. Once it is over, a tap goes on.
func tap(_at: Vector2) -> void:
	if finished:
		close()

## Skips ahead: subclasses play out what is left at once.
func hurry() -> void:
	pass


## The three helpers' slots in a row, each with its count on a red badge; a locked one is grey with a padlock.
class _Slots extends Control:
	var u: float = 1.0
	var counts: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var _springs: Array[Jiggle] = [Jiggle.new(), Jiggle.new(), Jiggle.new()]

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func width() -> float:
		return (StreetMoment.SLOT * 3.0 + StreetMoment.SLOT_GAP * 2.0) * u

	func slot_centre(b: int) -> Vector2:
		return Vector2((float(b) - 1.0) * (StreetMoment.SLOT + StreetMoment.SLOT_GAP) * u, 0.0)

	func bump(b: int) -> void:
		if not Save.reduce_motion:
			_springs[b].kick(1.2)

	func _process(delta: float) -> void:
		for s: Jiggle in _springs:
			s.step(delta)
		queue_redraw()

	func _draw() -> void:
		var slot: float = StreetMoment.SLOT * u
		var font: Font = StreetArt.font()
		for b: int in range(3):
			var c: Vector2 = slot_centre(b)
			var open: bool = counts[b] > 0 or Save.booster_count(StreetRewards.BOOSTER_IDS[b]) > 0
			draw_set_transform(c, _springs[b].tilt(), _springs[b].squash())
			var piece: String = StreetMoment.SLOT_PIECES[b] if open else "slot_grey"
			StreetArt.draw(self, piece, Vector2.ZERO, slot / StreetArt.size(piece).x,
				StreetMoment.SLOT_TINTS[b] if open else Color.WHITE)
			if open:
				var icon: String = StreetMoment.SLOT_ICONS[b]
				StreetArt.draw(self, icon, Vector2.ZERO, slot * 0.66 / StreetArt.size(icon).x)
			else:
				StreetArt.draw(self, "icon_lock", Vector2(0.0, -2.0), slot * 0.5 / StreetArt.size("icon_lock").x)
			draw_set_transform(Vector2.ZERO)
			# The count's badge, drawn after, since a glossy circle sets its own transform.
			if open:
				var badge: Vector2 = c + Vector2(slot * 0.4, -slot * 0.4)
				StreetUI.gloss_circle(self, badge, slot * 0.22, StreetUI.RED)
				draw_string(font, badge + Vector2(-slot * 0.22, slot * 0.11), str(counts[b]),
					HORIZONTAL_ALIGNMENT_CENTER, slot * 0.44, int(slot * 0.32), StreetUI.CREAM)


## The Play pill's face, drawn in the button's corner space.
class _GoFace extends StreetPiece:
	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, StreetMoment.GO_SIZE * k)
		StreetUI.sparks(self, r, 40.0 * k)
		StreetArt.draw_nine(self, "pill_play", r, r.size.y / StreetArt.size("pill_play").y)
		StreetUI.glyph(self, &"play", r.get_center() + Vector2(4.0, -4.0) * k, r.size.y * 0.7)
