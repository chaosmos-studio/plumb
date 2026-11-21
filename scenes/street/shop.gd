class_name StreetShop
extends CanvasLayer

## Street's shop (REVAMP_PLAN.md section 4.7, concept build/review/revamp2/6-shop.png): a market stall on the street,
## a cast member behind the counter, and soft trays with one quiet price pill each. Hats (worn by the cast member of
## their colour), marble sets (the board's finishes, GameLooks) and helpers, all for coins, and below the stall one
## row for the Supporter pack, the only thing Street sells for money (decision 5). No timers, no offers.
##
## Everything is laid out in the painting's own pixels (Codex's 1084 x 2412 composition, build/review/art/d2-shop.png)
## on a frame scaled to fit the screen, so the stall keeps the concept's proportions on every shape. It enters as
## moment 19 says: the stall slides up, its awning drops and bounces, the trays slide in one by one.

signal closed

## The composition, in the backdrop painting's pixels: its size, the stall's corner, the counter's and each tray's
## top, the trays' left edge and width, the items' row and the price pill below each tray, the cast member's middle
## and size, the planters' x and the Supporter row.
const FRAME: Vector2 = Vector2(1084.0, 2412.0)
const STALL_AT: Vector2 = Vector2(62.0, 567.0)
const COUNTER_Y: float = 867.0
const TRAY_X: float = 122.0
const TRAY_SIZE: Vector2 = Vector2(840.0, 276.0)
const TRAYS_Y: PackedFloat32Array = [977.0, 1285.0, 1593.0]
const ITEMS_DY: float = 120.0
const PILL_DY: float = 257.0
const PILL_SIZE: Vector2 = Vector2(250.0, 86.0)
## The helpers' tray has a second pill, a video for one of each open helper (free when no video is ready), its price
## pill and this one side by side under the tray, this far from its middle.
const VIDEO_SIZE: Vector2 = Vector2(210.0, 86.0)
const PAIR_SHIFT: float = 122.0
const VENDOR: Vector2 = Vector2(433.0, 808.0)
const VENDOR_D: float = 231.0
const PLANTERS: PackedFloat32Array = [198.0, 886.0]
const SUPPORT_Y: float = 2075.0
const SUPPORT_SIZE: Vector2 = Vector2(560.0, 130.0)
## On a wide screen the frame shows from the awning to the Supporter row, scaled to the height.
const WIDE_TOP: float = 300.0
const WIDE_BOTTOM: float = 2170.0
## The items: a hat's width, a marble's diameter, a helper's slot, and how near a tap must land.
const HAT: float = 150.0
const MARBLE: float = 90.0
const SLOT: float = 150.0
const REACH: float = 80.0
## Items bob at rest this far, in painting pixels, this fast.
const BOB: float = 5.0
const BOB_SPEED: float = 2.0
## The marble sets, in GameLooks' order.
const SETS: PackedStringArray = ["classic", "glass", "gems", "planets", "candy", "pearls", "yarn"]

enum Tray { HATS, MARBLES, HELPERS }

var _root: Control
var _backdrop: TextureRect
var _frame: _Back
var _front: _Front
var _items: _Items
var _coins: StreetCoinPill
var _close: StreetUI.RoundButton
var _vendor: StreetCast
var _samples: Array[Node2D] = []
var _wobbler: StreetWobbler
var _leaving: bool = false
var _watching: bool = false

func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)
	_backdrop = TextureRect.new()
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_backdrop)
	# Back to front: the stall and its awning, the cast member, then the counter, the trays and what is on them.
	_frame = _Back.new()
	_root.add_child(_frame)
	_vendor = StreetCast.new()
	_vendor.members = PackedInt32Array([_first_hatted()])
	_vendor.scale = Vector2.ONE * VENDOR_D / StreetCast.body_width()
	_frame.add_child(_vendor)
	_front = _Front.new()
	_front.shop = self
	_frame.add_child(_front)
	_items = _Items.new()
	_items.shop = self
	_frame.add_child(_items)
	# Each marble set's sample rides in a holder that bobs, so the marble itself never moves: a moving marble thinks it
	# is rolling and draws its tail and turning pattern again every frame (the shop missed frames on the phone).
	for i: int in range(SETS.size()):
		var colours: Array = GameLooks.swatch(SETS[i])
		var holder: Node2D = Node2D.new()
		holder.add_child(GameLooks.sample(SETS[i], colours[i % colours.size()], MARBLE * 0.5))
		_frame.add_child(holder)
		_samples.append(holder)
	_wobbler = StreetWobbler.new()
	add_child(_wobbler)
	_coins = StreetCoinPill.new()
	_coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_coins)
	_close = StreetUI.RoundButton.new(StreetUI.RED, &"close", 104.0)
	_close.pressed.connect(close)
	_root.add_child(_close)
	_layout()
	get_viewport().size_changed.connect(_layout)
	# The shop covers the street, so the banner steps away until it closes and never sits over a tray or a row.
	Ads.cover(true)
	Analytics.event(&"shop_open", {"from": "street"})
	if Save.reduce_motion:
		_root.modulate.a = 0.0
		_root.create_tween().tween_property(_root, "modulate:a", 1.0, 0.2)
	else:
		_frame.enter = 0.0
		_frame.create_tween().tween_property(_frame, "enter", 1.0, 0.9)

func _exit_tree() -> void:
	Ads.cover(false)
	# Its page goes with it: the rooms' art is only ever drawn here and in Settings.
	StreetArt.release(StreetArt.ROOMS)

## The cast member shown behind the counter: the first wearing a hat, or Rosie.
func _first_hatted() -> int:
	for i: int in range(4):
		if Save.worn[i] > 0:
			return i
	return 0

func _layout() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var wide: bool = StreetLayout.wide(size)
	var safe: Dictionary = UI.safe_margins(get_viewport())
	_backdrop.size = size
	_backdrop.texture = StreetArt.backdrop(StreetArt.SHOP_BACKDROP, wide)
	if wide:
		var s: float = size.y / (WIDE_BOTTOM - WIDE_TOP)
		_frame.scale = Vector2.ONE * s
		_frame.position = Vector2(size.x * 0.5 - FRAME.x * 0.5 * s, -WIDE_TOP * s)
	else:
		var s: float = minf(size.x / FRAME.x, (size.y - float(safe["top"])) / FRAME.y)
		_frame.scale = Vector2.ONE * s
		_frame.position = Vector2(size.x * 0.5 - FRAME.x * 0.5 * s, float(safe["top"]))
	_coins.position = Vector2(float(safe["left"]) + 22.0, float(safe["top"]) + 22.0)
	_close.position = Vector2(size.x - float(safe["right"]) - 22.0 - _close.size.x, float(safe["top"]) + 16.0)

## How many items a tray holds.
static func count_of(tray: int) -> int:
	match tray:
		Tray.HATS:
			return StreetRewards.HATS
		Tray.MARBLES:
			return SETS.size()
	return 3

## Item `i`'s middle on tray `tray`, in the painting's pixels, before the entrance moves it.
static func item_at(tray: int, i: int) -> Vector2:
	var inner: float = TRAY_SIZE.x - 120.0
	return Vector2(TRAY_X + 60.0 + inner * (float(i) + 0.5) / float(count_of(tray)), TRAYS_Y[tray] + ITEMS_DY)

## The price pill's box under tray `tray`: in the middle, or left of the video pill under the helpers.
static func pill_rect(tray: int) -> Rect2:
	var shift: float = -PAIR_SHIFT if tray == Tray.HELPERS else 0.0
	return Rect2(Vector2(TRAY_X + TRAY_SIZE.x * 0.5 + shift, TRAYS_Y[tray] + PILL_DY) - PILL_SIZE * 0.5, PILL_SIZE)

## The helpers' video pill's box.
static func video_rect() -> Rect2:
	return Rect2(Vector2(TRAY_X + TRAY_SIZE.x * 0.5 + PAIR_SHIFT, TRAYS_Y[Tray.HELPERS] + PILL_DY) - VIDEO_SIZE * 0.5,
		VIDEO_SIZE)

## Whether helper `b` is open yet: its parcel has come, at the door the player has reached.
static func helper_open(b: int) -> bool:
	return StreetRewards.booster_open(b, Save.main_frontier() + 1)

static func support_rect() -> Rect2:
	return Rect2(Vector2(FRAME.x * 0.5, SUPPORT_Y) - SUPPORT_SIZE * 0.5, SUPPORT_SIZE)

## The price of tray `tray`'s items, in coins.
static func price_of(tray: int) -> int:
	match tray:
		Tray.HATS:
			return StreetRewards.PRICE_HAT
		Tray.MARBLES:
			return StreetRewards.PRICE_MARBLES
	return StreetRewards.PRICE_BOOSTER

## Whether marble set `id` is the player's: free, bought here, or in the pack (Looks).
static func set_owned(id: String) -> bool:
	return Looks.is_open(id)

## The set the board plays in.
static func current_set() -> String:
	return Looks.current()

func close() -> void:
	if _leaving:
		return
	_leaving = true
	var t: Tween = _root.create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.2)
	t.tween_callback(func() -> void:
		closed.emit()
		queue_free())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		close()

func _on_input(event: InputEvent) -> void:
	if _leaving or not (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		return
	var at: Vector2 = _frame.get_global_transform_with_canvas().affine_inverse() * (event as InputEventScreenTouch).position
	for tray: int in range(3):
		for i: int in range(count_of(tray)):
			if (item_at(tray, i) + Vector2(0.0, _frame.lift(tray))).distance_to(at) < REACH:
				_pick(tray, i)
				return
		if pill_rect(tray).has_point(at):
			_front.wiggle(tray)
			Audio.play(&"pop", StreetWobbler.VOICE_DB)
			return
	if video_rect().has_point(at):
		_video()
		return
	if support_rect().has_point(at):
		Audio.play(&"tap", -6.0)
		Supporter.open(self)
		return
	if at.distance_to(VENDOR) < VENDOR_D * 0.6:
		_vendor.poke(0)

## A tap on item `i` of tray `tray`: one owned is put on or chosen, one not owned is bought if the coins allow, and
## the tray's price pill wiggles when they do not.
func _pick(tray: int, i: int) -> void:
	match tray:
		Tray.HATS:
			var hat: int = i + 1
			var item: String = "hat_%d" % hat
			if not Save.street_owned.has(item):
				if not _pay(tray):
					return
				Save.own_street(item)
				Analytics.event(&"shop_buy", {"item": item, "price": price_of(tray), "currency": "coins"})
			# Each hat is worn by the cast member of its colour, and a tap on a worn one takes it off.
			Save.wear(i, 0 if Save.worn[i] == hat else hat)
			_vendor.members = PackedInt32Array([i])
			_vendor.poke(0)
			Audio.play(&"pop", -4.0, 1.2)
		Tray.MARBLES:
			var id: String = SETS[i]
			if not set_owned(id):
				if not _pay(tray):
					return
				Save.own_street("marbles_" + id)
				Analytics.event(&"shop_buy", {"item": "marbles_" + id, "price": price_of(tray), "currency": "coins"})
			Save.set_look(id)
			GameLooks.use(id)
			_wobbler.tap(_samples[i], StreetWobbler.Voice.CLINK, 1.4)
			_items.puff(item_at(tray, i))
		Tray.HELPERS:
			# A helper is sold once its parcel has brought it; before that its slot only wobbles.
			if not helper_open(i):
				_items.bump(i)
				Audio.play(&"knock", -6.0)
				return
			if not _pay(tray):
				return
			Save.add_booster(StreetRewards.BOOSTER_IDS[i], 1)
			Analytics.event(&"shop_buy", {"item": StreetRewards.BOOSTER_IDS[i], "price": price_of(tray),
				"currency": "coins"})
			_items.bump(i)
			Audio.play(&"pop", -4.0, 1.3)

## The helpers' video: one of each open helper, given anyway when no video is ready (Ads.rewarded, decision 7).
func _video() -> void:
	if _watching or not helper_open(0):
		_front.wiggle_video()
		return
	_watching = true
	Audio.play(&"tap", -6.0)
	_front.wiggle_video()
	Ads.rewarded(_video_reward)

func _video_reward() -> void:
	_watching = false
	if _leaving:
		return
	for b: int in range(3):
		if helper_open(b):
			Save.add_booster(StreetRewards.BOOSTER_IDS[b], 1)
			_items.bump(b)
	Audio.play(&"star", -6.0, 1.2)

## Spends a tray's price, or wiggles its pill and answers false when the coins fall short.
func _pay(tray: int) -> bool:
	if Save.spend_coins(price_of(tray)):
		Audio.play(&"clink", -4.0, 0.9)
		return true
	_front.wiggle(tray)
	Audio.play(&"knock", -6.0)
	Audio.buzz(30, 0.5)
	return false

func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	_vendor.position = VENDOR + Vector2(0.0, VENDOR_D * 0.5 + _frame.rise())
	for i: int in range(_samples.size()):
		var bob: float = 0.0 if Save.reduce_motion else BOB * sin(t * BOB_SPEED + float(i) * 1.3)
		var sample: Node2D = _samples[i]
		# A sample being wobbled keeps its place; the wobbler only scales it.
		sample.position = item_at(Tray.MARBLES, i) + Vector2(0.0, bob + _frame.lift(Tray.MARBLES))
		sample.modulate.a = _frame.shown(Tray.MARBLES)


## The back of the stall: the bunting, the stall and its awning. It holds the entrance's progress, which the rest
## reads.
class _Back extends Node2D:
	## The entrance's progress, 0 to 1.
	var enter: float = 1.0:
		set(value):
			enter = value
			queue_redraw()

	## How far below its place the stall still is, in painting pixels.
	func rise() -> float:
		return 0.0 if Save.reduce_motion else (1.0 - _back_out(clampf(enter * 1.6, 0.0, 1.0))) * 1400.0

	## How far above its place the awning still is.
	func drop() -> float:
		return 0.0 if Save.reduce_motion else (1.0 - _bounce(clampf(enter * 1.6 - 0.35, 0.0, 1.0))) * -500.0

	## How far below its place tray `tray` still is, the stall's rise included.
	func lift(tray: int) -> float:
		return rise() + (1.0 - _back_out(shown(tray))) * 260.0

	## How much of tray `tray` shows.
	func shown(tray: int) -> float:
		return 1.0 if Save.reduce_motion else clampf(enter * 1.8 - 0.5 - float(tray) * 0.18, 0.0, 1.0)

	static func _back_out(t: float) -> float:
		var c: float = 1.70158
		return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)

	## An ease that lands and bounces twice, for the awning.
	static func _bounce(t: float) -> float:
		if t < 0.6:
			return pow(t / 0.6, 2.0)
		if t < 0.85:
			var u: float = (t - 0.725) / 0.125
			return 1.0 - 0.08 * (1.0 - u * u)
		var w: float = (t - 0.925) / 0.075
		return 1.0 - 0.025 * (1.0 - w * w)

	func _draw() -> void:
		var bunting_k: float = StreetShop.FRAME.x / (StreetArt.size("bunting").x / StreetArt.DESIGN_PER_PIXEL)
		StreetArt.draw_at(self, "bunting", Vector2(0.0, 33.0 + drop() * 0.3), bunting_k / StreetArt.DESIGN_PER_PIXEL)
		var stall: Vector2 = StreetShop.STALL_AT + Vector2(0.0, rise())
		StreetArt.draw_at(self, "shop_stall", stall, 1.0 / StreetArt.DESIGN_PER_PIXEL)
		var posts_top: float = stall.y + 28.0
		StreetArt.draw_at(self, "shop_awning", Vector2(stall.x, posts_top - 288.0 + 26.0 + drop()),
			1.0 / StreetArt.DESIGN_PER_PIXEL)


## The counter, the trays, the price pills and the Supporter row, in front of the cast member. They hold still, so
## this layer is drawn again only while the stall enters or a pill wiggles; what lives on the trays is drawn by
## _Items above it, every frame (the phone showed the shop missing frames when everything redrew each one).
class _Front extends Node2D:
	var shop: StreetShop
	var _pills: Array[Jiggle] = [Jiggle.new(), Jiggle.new(), Jiggle.new()]
	var _video: Jiggle = Jiggle.new()
	var _t: float = 0.0

	func wiggle_video() -> void:
		if not Save.reduce_motion:
			_video.kick(1.2)
		queue_redraw()

	func wiggle(tray: int) -> void:
		if not Save.reduce_motion:
			_pills[tray].kick(1.4)
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		var moving: bool = false
		for j: Jiggle in _pills:
			moving = j.step(delta) or moving
		moving = _video.step(delta) or moving
		var back: _Back = get_parent()
		if moving or back.enter < 1.0:
			queue_redraw()

	## Draws `piece` about its base point at `at`, `width` painting pixels wide.
	func _fit(piece: String, at: Vector2, width: float, tint: Color = Color.WHITE) -> void:
		StreetArt.draw(self, piece, at, width / StreetArt.size(piece).x, tint)

	func _draw() -> void:
		var back: _Back = get_parent()
		var rise: float = back.rise()
		var still: bool = Save.reduce_motion
		var counter_top: float = StreetShop.COUNTER_Y + rise + 27.0
		for x: float in StreetShop.PLANTERS:
			_fit("planter", Vector2(x, counter_top + 7.0), 182.0)
		StreetArt.draw_at(self, "shop_counter", Vector2(StreetShop.STALL_AT.x, StreetShop.COUNTER_Y + rise),
			1.0 / StreetArt.DESIGN_PER_PIXEL)
		var font: Font = StreetArt.font()
		for tray: int in range(3):
			var lift: float = back.lift(tray)
			var a: float = back.shown(tray)
			var tint: Color = Color(1, 1, 1, a)
			StreetArt.draw_nine(self, "shop_tray", Rect2(Vector2(StreetShop.TRAY_X, StreetShop.TRAYS_Y[tray] + lift),
				StreetShop.TRAY_SIZE), 1.0 / StreetArt.DESIGN_PER_PIXEL, tint)
			# The tray's one quiet price pill: a coin and its price. Its wiggle squashes its box, since a nine-patch
			# sets its own transform.
			var pill: Rect2 = StreetShop.pill_rect(tray)
			pill.position.y += lift
			var squash: Vector2 = _pills[tray].squash()
			var shake: float = _pills[tray].tilt() * 60.0
			var box: Rect2 = Rect2(pill.get_center() + Vector2(shake, 0.0) - pill.size * squash * 0.5, pill.size * squash)
			StreetArt.draw_nine(self, "pill_orange", box, box.size.y / StreetArt.size("pill_orange").y, tint)
			_fit("coin", Vector2(box.position.x + 54.0, box.get_center().y), 64.0, tint)
			draw_string(font, Vector2(box.position.x + 88.0, box.get_center().y + 22.0), str(StreetShop.price_of(tray)),
				HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 110.0, 62, Color(StreetUI.CREAM, a))
			if tray == StreetShop.Tray.HELPERS:
				# The video pill beside it: a play triangle and +1, teal so it never reads as a price.
				var video: Rect2 = StreetShop.video_rect()
				video.position.y += lift
				var vs: Vector2 = _video.squash()
				var vbox: Rect2 = Rect2(video.get_center() - video.size * vs * 0.5, video.size * vs)
				StreetUI.gloss_pill(self, vbox, Color(StreetUI.TEAL, a))
				StreetUI.glyph(self, &"play", Vector2(vbox.position.x + 54.0, vbox.get_center().y - 2.0), 54.0,
					Color(StreetUI.CREAM, a))
				draw_string(font, Vector2(vbox.position.x + 84.0, vbox.get_center().y + 22.0), "+1",
					HORIZONTAL_ALIGNMENT_CENTER, vbox.size.x - 104.0, 62, Color(StreetUI.CREAM, a))
		# The Supporter row: a heart and its price, or a tick once it is the player's.
		var row: Rect2 = StreetShop.support_rect()
		row.position.y += rise
		StreetUI.gloss_pill(self, row, StreetUI.CREAM)
		_heart(Vector2(row.position.x + 86.0, row.get_center().y), 34.0)
		var label: String = Shop.price(GameMonetize.SUPPORTER_ID)
		var text_at: Vector2 = Vector2(row.position.x + 140.0, row.get_center().y)
		if Supporter.active():
			_tick(Vector2(row.get_center().x + 40.0, row.get_center().y), 1.0)
		elif label != "":
			draw_string(font, text_at + Vector2(0.0, 20.0), label, HORIZONTAL_ALIGNMENT_CENTER, row.size.x - 180.0, 58,
				StreetUI.INK)
		else:
			_fit("icon_play", Vector2(row.get_center().x + 40.0, row.get_center().y), 64.0, StreetUI.INK)

	## A green tick badge: worn, chosen or had.
	func _tick(at: Vector2, a: float) -> void:
		StreetUI.gloss_circle(self, at, 26.0, Color(0.3, 0.69, 0.23, a))
		_fit("icon_tick", at, 34.0, Color(1, 1, 1, a))

	## A small padlock: not the player's yet.
	func _lock(at: Vector2, a: float) -> void:
		StreetUI.gloss_circle(self, at, 22.0, Color(0.55, 0.56, 0.66, a))
		_fit("icon_lock", at, 28.0, Color(1, 1, 1, a))

	## A soft red heart for the Supporter row.
	func _heart(c: Vector2, r: float) -> void:
		var red: Color = StreetUI.RED
		draw_circle(c + Vector2(-r * 0.5, -r * 0.2), r * 0.62, red, true, -1.0, true)
		draw_circle(c + Vector2(r * 0.5, -r * 0.2), r * 0.62, red, true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.08, 0.0), c + Vector2(r * 1.08, 0.0),
			c + Vector2(0.0, r * 1.1)]), red)


## What lives on the trays, drawn every frame above them: the hats, the marble sets' rings and locks, the helpers'
## slots with their counts, each bobbing in its own time, and the puff when a set is chosen.
class _Items extends _Front:
	var _slots: Array[Jiggle] = [Jiggle.new(), Jiggle.new(), Jiggle.new()]
	var _puffs: Array[Vector3] = []

	func bump(slot: int) -> void:
		if not Save.reduce_motion:
			_slots[slot].kick(1.2)

	## A soft puff of sparks where a marble set was chosen.
	func puff(at: Vector2) -> void:
		_puffs.append(Vector3(at.x, at.y, 0.0))

	func _process(delta: float) -> void:
		_t += delta
		for j: Jiggle in _slots:
			j.step(delta)
		var i: int = _puffs.size() - 1
		while i >= 0:
			_puffs[i].z += delta
			if _puffs[i].z > 0.5:
				_puffs.remove_at(i)
			i -= 1
		queue_redraw()

	func _draw() -> void:
		var back: _Back = get_parent()
		var still: bool = Save.reduce_motion
		for tray: int in range(3):
			var lift: float = back.lift(tray)
			var tint: Color = Color(1, 1, 1, back.shown(tray))
			for i: int in range(StreetShop.count_of(tray)):
				var bob: float = 0.0 if still else sin(_t * StreetShop.BOB_SPEED + float(i) * 1.3) * StreetShop.BOB
				_item(tray, i, StreetShop.item_at(tray, i) + Vector2(0.0, lift + bob), tint)
		for p: Vector3 in _puffs:
			var k: float = p.z / 0.5
			_fit("sparks", Vector2(p.x, p.y + back.rise()), 180.0 * (0.6 + k * 0.6), Color(1, 1, 1, 1.0 - k))

	## One item: a hat, a marble set (its sample is a node of its own; this draws its ring) or a helper.
	func _item(tray: int, i: int, c: Vector2, tint: Color) -> void:
		match tray:
			StreetShop.Tray.HATS:
				var hat: int = i + 1
				var owned: bool = Save.street_owned.has("hat_%d" % hat)
				_fit("shadow", c + Vector2(0.0, 58.0), 120.0, Color(1, 1, 1, tint.a * 0.5))
				_fit("hat_%d" % hat, c + Vector2(0.0, 60.0), StreetShop.HAT, tint)
				if Save.worn[i] == hat:
					_tick(c + Vector2(58.0, -52.0), tint.a)
				elif not owned:
					_lock(c + Vector2(52.0, 40.0), tint.a)
			StreetShop.Tray.MARBLES:
				var id: String = StreetShop.SETS[i]
				if StreetShop.current_set() == id:
					draw_arc(c, StreetShop.MARBLE * 0.68, 0.0, TAU, 40, Color(StreetUI.YELLOW, tint.a), 7.0, true)
				elif not StreetShop.set_owned(id):
					_lock(c + Vector2(30.0, 32.0), tint.a)
			StreetShop.Tray.HELPERS:
				var spring: Jiggle = _slots[i]
				draw_set_transform(c, spring.tilt(), spring.squash())
				var open: bool = StreetShop.helper_open(i)
				var piece: String = StreetMoment.SLOT_PIECES[i] if open else "slot_grey"
				_fit(piece, Vector2.ZERO, StreetShop.SLOT, (StreetMoment.SLOT_TINTS[i] if open else Color.WHITE) * tint)
				_fit(StreetMoment.SLOT_ICONS[i], Vector2.ZERO, StreetShop.SLOT * 0.62, tint)
				draw_set_transform(Vector2.ZERO)
				var badge: Vector2 = c + Vector2(StreetShop.SLOT * 0.4, -StreetShop.SLOT * 0.4)
				if not StreetShop.helper_open(i):
					_lock(badge, tint.a)
					return
				StreetUI.gloss_circle(self, badge, 30.0, Color(StreetUI.RED, tint.a))
				draw_string(StreetArt.font(), badge + Vector2(-30.0, 15.0),
					str(Save.booster_count(StreetRewards.BOOSTER_IDS[i])), HORIZONTAL_ALIGNMENT_CENTER, 60.0, 42,
					Color(StreetUI.CREAM, tint.a))
