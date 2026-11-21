class_name StreetGift
extends StreetMoment

## The parcel at every fifth door (REVAMP_PLAN.md section 8 moment 15, build/review/art/d1-gift.png): in front of the
## door's house, its door open, the parcel drops and waits for the player's tap, never opening by itself, so no tap
## meant for something else can open it (the lead, 21 November). After a few seconds a soft glow and a hop invite the
## tap. The lid flies off, its flaps fold open over slow rays, and what it holds rises (coins, a helper or a hat) and
## flies to where it belongs. Then "x2" waits: a video doubles it, and with no video ready it doubles anyway
## (decision 7).

## The parcel starts inviting a tap after this long, then hops this often, this high, with a glow behind it.
const INVITE_AFTER: float = 2.5
const HOP_EVERY: float = 1.6
const HOP: float = 40.0
const GLOW_SPEED: float = 3.0
## The concept's composition, as shares of the screen (portrait, then wide): the house's foot, the parcel's foot in
## front of its door, and each cast member's foot about the road. Then the house's and the parcel's widths, and how
## high the parcel's contents rise above it.
const HOUSE_AT: Vector2 = Vector2(0.66, 0.58)
const PARCEL_AT: Vector2 = Vector2(0.6, 0.69)
const CAST_AT: Array[Vector2] = [Vector2(0.17, 0.7), Vector2(0.3, 0.81), Vector2(0.62, 0.82), Vector2(0.85, 0.74)]
const WIDE_HOUSE_AT: Vector2 = Vector2(0.66, 0.62)
const WIDE_PARCEL_AT: Vector2 = Vector2(0.6, 0.78)
const WIDE_CAST_AT: Array[Vector2] = [Vector2(0.12, 0.7), Vector2(0.23, 0.9), Vector2(0.34, 0.72), Vector2(0.44, 0.92)]
const HOUSE: float = 600.0
const PARCEL: float = 290.0
const RISE: float = 330.0
## The cast's size beside the street's.
const CAST_SCALE: float = 1.9
## The "x2" pill, left of the Play pill, which stands right of the middle to make room.
const DOUBLE_SIZE: Vector2 = Vector2(230.0, 110.0)
const DOUBLE_GAP: float = 24.0

func go_centre() -> Vector2:
	return super.go_centre() + Vector2((DOUBLE_SIZE.x + DOUBLE_GAP) * u * 0.5, 0.0)

var _reward: Dictionary = {}
var _parcel: Node2D
var _body: StreetPiece
var _lid: StreetPiece
var _bow: StreetPiece
var _back: StreetPiece
var _front: StreetPiece
var _rays: StreetPiece
var _glow: StreetPiece
## The cast, one member each, scattered over the road as in the concept.
var _cast: Array[StreetCast] = []
var _house: StreetPiece
var _opened: bool = false
var _hop: float = 0.0
var _waited: float = 0.0
var _double: Button
var _contents: Array[StreetPiece] = []

func backdrop_path() -> String:
	return StreetArt.GIFT_BACKDROP

func _ready() -> void:
	super._ready()
	_reward = _grant(1)
	coins_before(int(_reward["coins"]))
	var gained: PackedInt32Array = PackedInt32Array([0, 0, 0])
	if int(_reward["booster"]) >= 0:
		gained[int(_reward["booster"])] = int(_reward["count"])
	slots_before(gained)
	_build()
	Audio.play(&"fanfare", -10.0)

## Claims the parcel and puts what it holds in the save, `times` over. A hat already owned comes as its price in coins
## instead. Answers what it held.
func _grant(times: int) -> Dictionary:
	var reward: Dictionary = StreetRewards.parcel(door)
	if times == 1:
		Save.claim_gift(door)
	var hat: int = int(reward["hat"])
	if hat >= 0 and Save.street_owned.has("hat_%d" % (hat + 1)):
		reward["coins"] = int(reward["coins"]) + StreetRewards.PRICE_HAT
		reward["hat"] = -1
	if int(reward["coins"]) > 0:
		Save.add_coins(int(reward["coins"]) * times)
	if int(reward["booster"]) >= 0:
		Save.add_booster(StreetRewards.BOOSTER_IDS[int(reward["booster"])], int(reward["count"]) * times)
	if int(reward["hat"]) >= 0:
		var item: String = "hat_%d" % (int(reward["hat"]) + 1)
		Save.own_street(item)
		# Each hat is worn by the cast member of its colour (StreetShop), who puts a new one on.
		Save.wear(int(reward["hat"]), int(reward["hat"]) + 1)
	return reward

func _build() -> void:
	var house_name: String = StreetArt.house_of(door)
	_house = StreetPiece.new(house_name, HOUSE * u / StreetArt.size(house_name).x)
	_house.position = size * (WIDE_HOUSE_AT if wide else HOUSE_AT)
	stage.add_child(_house)
	var d: Vector3 = StreetArt.door(house_name) * _house.k
	var door_open: StreetPiece = StreetPiece.new("door_open", _house.k)
	door_open.position = _house.position + Vector2(d.x, d.y)
	stage.add_child(door_open)
	_rays = StreetPiece.new("rays", 1.0 * u)
	_rays.modulate.a = 0.0
	stage.add_child(_rays)
	# The glow that invites a tap: soft rays of light turning behind the parcel.
	_glow = StreetPiece.new("rays", PARCEL * u * 2.6 / StreetArt.size("rays").x)
	_glow.visible = false
	stage.add_child(_glow)
	_parcel = Node2D.new()
	_parcel.position = size * (WIDE_PARCEL_AT if wide else PARCEL_AT)
	stage.add_child(_parcel)
	var k: float = PARCEL * u / StreetArt.size("parcel_body").x
	_back = StreetPiece.new("parcel_flaps_back", k)
	_body = StreetPiece.new("parcel_body", k)
	_front = StreetPiece.new("parcel_flaps_front", k)
	_lid = StreetPiece.new("parcel_lid", k)
	_bow = StreetPiece.new("parcel_bow", k)
	var body_h: float = StreetArt.size("parcel_body").y * k
	var top: Vector2 = Vector2(0.0, -body_h)
	_rays.position = _parcel.position + top + Vector2(0.0, -RISE * u)
	for p: StreetPiece in [_back, _body, _front, _lid, _bow]:
		_parcel.add_child(p)
	_body.position = Vector2(0.0, -body_h * 0.5)
	_back.position = top
	_front.position = top
	_back.visible = false
	_front.visible = false
	_lid.position = top + Vector2(0.0, StreetArt.size("parcel_lid").y * k * 0.2)
	_bow.position = _lid.position + Vector2(0.0, -StreetArt.size("parcel_lid").y * k * 0.35)
	var spots: Array[Vector2] = WIDE_CAST_AT if wide else CAST_AT
	for i: int in range(4):
		var member: StreetCast = StreetCast.new()
		member.members = PackedInt32Array([i])
		member.scale = Vector2.ONE * CAST_SCALE * u
		member.position = size * spots[i]
		# Nearer members stand in front.
		member.z_index = int(spots[i].y * 100.0)
		stage.add_child(member)
		_cast.append(member)
	# The house rises in, the parcel drops onto the road with a squash.
	if not Save.reduce_motion:
		_house.scale = Vector2(1.0, 0.0)
		_house.create_tween().tween_property(_house, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
		var landing: float = _parcel.position.y
		_parcel.position.y -= size.y * 0.5
		var t: Tween = _parcel.create_tween()
		t.tween_property(_parcel, "position:y", landing, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN) \
			.set_delay(0.2)
		t.tween_callback(func() -> void:
			Audio.play(&"plop", -4.0)
			wobbler.tap(_parcel, StreetWobbler.Voice.BOING, 1.4))

func _process(delta: float) -> void:
	if _rays.modulate.a > 0.0 and not Save.reduce_motion:
		_rays.rotation += 0.3 * delta
	if _opened:
		_glow.visible = false
		return
	_waited += delta
	if _waited < INVITE_AFTER:
		return
	# Once it has waited a while, a soft glow breathes behind it, and it hops now and then, inviting the tap.
	_glow.visible = true
	_glow.position = _parcel.position + Vector2(0.0, -StreetArt.size("parcel_body").y * _body.k * 0.5)
	_glow.modulate.a = clampf((_waited - INVITE_AFTER) * 2.0, 0.0, 1.0) \
		* (1.0 if Save.reduce_motion else 0.8 + 0.2 * sin(_waited * GLOW_SPEED))
	if not Save.reduce_motion:
		_glow.rotation += 0.4 * delta
	_hop += delta
	if _hop > HOP_EVERY and not Save.reduce_motion:
		_hop = 0.0
		var t: Tween = _parcel.create_tween()
		var y: float = _parcel.position.y
		t.tween_property(_parcel, "position:y", y - HOP * u, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(_parcel, "position:y", y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void: wobbler.tap(_parcel, StreetWobbler.Voice.POP, 0.6))

func tap(at: Vector2) -> void:
	if not _opened:
		var reach: float = PARCEL * u
		if at.distance_to(_parcel.position + Vector2(0.0, -reach * 0.4)) < reach:
			_open()
			return
	for member: StreetCast in _cast:
		if member.member_at(at) >= 0:
			member.poke(0)
			return
	if _house.hit(at):
		wobbler.tap(_house, StreetWobbler.Voice.KNOCK)

func hurry() -> void:
	if not _opened:
		_open()

## The lid flies off, the flaps fold open, the rays come up and what it holds rises and flies home.
func _open() -> void:
	if _opened:
		return
	_opened = true
	Audio.play(&"cannon", -8.0)
	Audio.buzz(30, 0.7)
	_back.visible = true
	_front.visible = true
	var still: bool = Save.reduce_motion
	var t: Tween = create_tween().set_parallel()
	if still:
		_lid.visible = false
		_bow.visible = false
	else:
		for p: StreetPiece in [_lid, _bow]:
			t.tween_property(p, "position", p.position + Vector2(160.0 * u, -420.0 * u), 0.55).set_trans(Tween.TRANS_QUAD) \
				.set_ease(Tween.EASE_OUT)
			t.tween_property(p, "rotation", 2.4, 0.55)
			t.tween_property(p, "modulate:a", 0.0, 0.25).set_delay(0.3)
		_back.scale = Vector2(1.0, 0.0)
		_front.scale = Vector2(1.0, 0.0)
		t.tween_property(_back, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_front, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_rays, "modulate:a", 0.85, 0.4)
	for member: StreetCast in _cast:
		member.cheer()
	await _rise(1)
	_offer_double()

## What the parcel holds rises above it, waits a beat, and flies home: coins to the pill, a helper to its slot and a
## hat onto the cast. `times` is 2 for the doubled share.
func _rise(times: int) -> void:
	var top: Vector2 = _parcel.position + Vector2(0.0, -StreetArt.size("parcel_body").y * _body.k)
	var above: Vector2 = top + Vector2(0.0, -RISE * u)
	var pieces: Array[StreetPiece] = []
	if int(_reward["coins"]) > 0:
		pieces.append(StreetPiece.new("coin_stack", 150.0 * u / StreetArt.size("coin_stack").x))
	if int(_reward["booster"]) >= 0:
		var icon: String = StreetMoment.SLOT_ICONS[int(_reward["booster"])]
		pieces.append(StreetPiece.new(icon, 120.0 * u / StreetArt.size(icon).x))
	if int(_reward["hat"]) >= 0:
		var hat: String = "hat_%d" % (int(_reward["hat"]) + 1)
		pieces.append(StreetPiece.new(hat, 120.0 * u / StreetArt.size(hat).x))
	var n: int = pieces.size()
	for i: int in range(n):
		var p: StreetPiece = pieces[i]
		p.position = top
		p.z_index = 100
		stage.add_child(p)
		_contents.append(p)
		var to: Vector2 = above + Vector2((float(i) - float(n - 1) * 0.5) * 190.0 * u, 0.0)
		if Save.reduce_motion:
			p.position = to
			continue
		p.scale = Vector2(0.3, 0.3)
		var t: Tween = p.create_tween().set_parallel()
		t.tween_property(p, "position", to, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.1)
		t.tween_property(p, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.set_delay(i * 0.1)
	Audio.play(&"star", -6.0, 1.1)
	await get_tree().create_timer(0.0 if Save.reduce_motion else 0.9).timeout
	var longest: float = 0.0
	for p: StreetPiece in pieces:
		if p.piece == "coin_stack":
			longest = maxf(longest, fly_coins(p.position, int(_reward["coins"]) * times))
			p.queue_free()
		elif p.piece.begins_with("icon_"):
			longest = maxf(longest, fly_helper(int(_reward["booster"]), p.position, int(_reward["count"]) * times))
			p.queue_free()
		else:
			longest = maxf(longest, _hat_home(p))
	_contents.clear()
	await get_tree().create_timer(longest + 0.2).timeout

## The hat drops onto the cast member who now wears it.
func _hat_home(p: StreetPiece) -> float:
	var cast: StreetCast = _cast[int(_reward["hat"])]
	var to: Vector2 = cast.position + Vector2(0.0, -StreetCast.body_width() * cast.scale.y * 1.1)
	if Save.reduce_motion:
		p.queue_free()
		return 0.0
	var t: Tween = p.create_tween()
	t.tween_property(p, "position", to, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		p.queue_free()
		cast.poke(0))
	return 0.5

## "x2" by a video, beside the Play pill, until it is used. With no video ready the reward doubles anyway.
func _offer_double() -> void:
	finish()
	_double = Button.new()
	_double.flat = true
	_double.focus_mode = Control.FOCUS_NONE
	_double.size = DOUBLE_SIZE * u
	_double.position = go_centre() - Vector2(StreetMoment.GO_SIZE.x * u * 0.5 + DOUBLE_GAP * u + _double.size.x,
		_double.size.y * 0.5)
	var face: _Double = _Double.new()
	face.k = u
	_double.add_child(face)
	_double.pressed.connect(func() -> void:
		_double.disabled = true
		Ads.rewarded(_doubled))
	root.add_child(_double)
	_double.pivot_offset = _double.size * 0.5
	if not Save.reduce_motion:
		_double.scale = Vector2(0.4, 0.4)
		_double.create_tween().tween_property(_double, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)

func _doubled() -> void:
	if not is_instance_valid(_double):
		return
	_double.queue_free()
	finished = false
	_grant_again()
	await _rise(1)
	finished = true

## The doubled share: the same again, a hat as its price in coins since it is already owned.
func _grant_again() -> void:
	if int(_reward["hat"]) >= 0:
		_reward["coins"] = int(_reward["coins"]) + StreetRewards.PRICE_HAT
		_reward["hat"] = -1
	Save.add_coins(int(_reward["coins"]))
	if int(_reward["booster"]) >= 0:
		Save.add_booster(StreetRewards.BOOSTER_IDS[int(_reward["booster"])], int(_reward["count"]))


## The "x2" pill: orange, a small play triangle for the video, and x2.
class _Double extends StreetPiece:
	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, StreetGift.DOUBLE_SIZE * k)
		StreetArt.draw_nine(self, "pill_orange", r, r.size.y / StreetArt.size("pill_orange").y)
		StreetUI.glyph(self, &"play", Vector2(r.size.x * 0.27, r.size.y * 0.46), r.size.y * 0.42)
		draw_string(StreetArt.font(), Vector2(r.size.x * 0.4, r.size.y * 0.68), "×2", HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(r.size.y * 0.5), StreetUI.CREAM)
