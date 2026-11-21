class_name StreetMilestone
extends StreetMoment

## A new family moves in at every twentieth door (REVAMP_PLAN.md section 8 moment 16, build/review/art/h2-milestone.png).
## On the square, the empty plot waits with its sign. Fireworks burst over it, the family's house rises onto the plot
## with a spring, the sign turns to "sold", the family rolls out of the door and waves, and coins and one of each
## helper fly home. About six seconds, and a tap on Play or the back key skips to the end.

## The house at its widest and its tallest, and the line the plot stands on, as a share of the screen's height.
const HOUSE: float = 520.0
const HOUSE_TALL: float = 560.0
const GROUND_AT: float = 0.66
const WIDE_GROUND_AT: float = 0.73
## The family stands this far in front of the plot, this size beside a cast member.
const FOLK_FRONT: float = 70.0
const FOLK_SIZE: float = 1.7
## The cast stands on the square in front, between the family and the Play pill.
const CAST_SCALE: float = 1.6
const CAST_AT: float = 0.8
## The fireworks: where each bursts, as shares of the screen, and their width.
const FIREWORKS: Array[Vector2] = [Vector2(0.2, 0.2), Vector2(0.52, 0.12), Vector2(0.82, 0.24)]
const FIREWORK: float = 330.0

var _reward: Dictionary = {}
var _house: StreetPiece
var _plot: StreetPiece
var _sign: StreetPiece
var _sails: StreetPiece
var _folk: StreetFolk
var _cast: StreetCast
var _beats: Tween
var _rays: StreetPiece

func _ready() -> void:
	super._ready()
	_reward = _grant()
	coins_before(int(_reward["coins"]))
	var gained: PackedInt32Array = PackedInt32Array()
	for b: int in range(3):
		gained.append(int(_reward["boosters"]) if StreetRewards.booster_open(b, door + 1) else 0)
	slots_before(gained)
	_build()
	_play()

## Claims the milestone and puts its coins and one of each open helper in the save.
func _grant() -> Dictionary:
	var reward: Dictionary = StreetRewards.milestone(door)
	Save.claim_gift(door)
	Save.add_coins(int(reward["coins"]))
	for b: int in range(3):
		if StreetRewards.booster_open(b, door + 1):
			Save.add_booster(StreetRewards.BOOSTER_IDS[b], int(reward["boosters"]))
	return reward

func _build() -> void:
	var family: int = int(_reward["family"])
	var house_name: String = StreetFamilies.house(family)
	var ground: float = size.y * (WIDE_GROUND_AT if wide else GROUND_AT)
	var k: float = minf(HOUSE * u / StreetArt.size(house_name).x, HOUSE_TALL * u / StreetArt.size(house_name).y)
	var plot_k: float = k * StreetProp.PLOT_SCALE / StreetProp.MILESTONE_SCALE
	var lift: float = StreetProp.PLATFORM * StreetArt.DESIGN_PER_PIXEL * plot_k
	_rays = StreetPiece.new("rays", 1.3 * u)
	_rays.position = Vector2(size.x * 0.5, ground - StreetArt.size(house_name).y * k * 0.6)
	_rays.modulate.a = 0.0
	stage.add_child(_rays)
	_plot = StreetPiece.new("milestone_plot", plot_k)
	_plot.position = Vector2(size.x * 0.5, ground)
	stage.add_child(_plot)
	_house = StreetPiece.new(house_name, k)
	_house.position = _plot.position + Vector2(0.0, -lift)
	stage.add_child(_house)
	var d: Vector3 = StreetArt.door(house_name) * k
	var shut: StreetPiece = StreetPiece.new("door_" + StreetArt.COLOURS[family % 4], k * StreetArt.door_scale(house_name))
	shut.position = Vector2(d.x, d.y)
	_house.add_child(shut)
	for w: Rect2 in StreetArt.windows(house_name):
		var lit: StreetPiece = StreetPiece.new("window_lit", k)
		lit.position = w.get_center() * k
		_house.add_child(lit)
	if StreetArt.meta(house_name, "hub").size() == 2:
		_sails = StreetPiece.new("milestone_windmill_sails", k)
		_sails.position = StreetArt.point(house_name, "hub") * k
		_house.add_child(_sails)
	_sign = StreetPiece.new("milestone_plot_sign", plot_k * 1.1)
	_sign.position = _plot.position + Vector2(-StreetArt.size("milestone_plot").x * plot_k * 0.36, -lift * 0.3)
	stage.add_child(_sign)
	_folk = StreetFolk.new()
	_folk.family = family
	_folk.size_k = FOLK_SIZE * u
	_folk.position = _house.position + Vector2(d.x, d.y + d.z)
	_folk.scale = Vector2(0.2, 0.2)
	_folk.visible = false
	stage.add_child(_folk)
	_cast = StreetCast.new()
	_cast.scale = Vector2.ONE * CAST_SCALE * u
	_cast.position = Vector2(size.x * (0.22 if wide else 0.5), size.y * (0.93 if wide else CAST_AT))
	stage.add_child(_cast)
	_house.scale = Vector2(1.0, 0.0)

func _process(delta: float) -> void:
	if Save.reduce_motion:
		return
	if _sails != null:
		_sails.rotation += StreetProp.SAIL_SPIN * delta
	if _rays.modulate.a > 0.0:
		_rays.rotation += 0.25 * delta

## The beats, each a tween step, so a skip can run them out at once.
func _play() -> void:
	var still: bool = Save.reduce_motion
	var front: Vector2 = _plot.position + Vector2(0.0, FOLK_FRONT * u)
	var t: Tween = create_tween().set_parallel()
	_beats = t
	# Fireworks over the plot, twice round.
	for round: int in range(2 if not still else 0):
		for i: int in range(FIREWORKS.size()):
			var at: float = 0.3 + round * 1.1 + i * 0.28
			var spot: Vector2 = Vector2(size.x * FIREWORKS[i].x, size.y * FIREWORKS[i].y)
			if wide:
				spot.y = size.y * (FIREWORKS[i].y + 0.02)
			var piece: String = "firework_%d" % (1 + (i + round) % 3)
			var burst: StreetPiece = StreetPiece.new(piece, FIREWORK * u / StreetArt.size(piece).x)
			burst.position = spot
			burst.scale = Vector2.ZERO
			stage.add_child(burst)
			t.tween_property(burst, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT) \
				.set_delay(at)
			t.tween_property(burst, "rotation", 0.3, 0.9).set_delay(at)
			t.tween_property(burst, "modulate:a", 0.0, 0.4).set_delay(at + 0.55)
			t.tween_callback(func() -> void: Audio.play(&"cannon", -12.0, randf_range(1.1, 1.4))).set_delay(at)
	t.tween_callback(func() -> void: Audio.play(&"fanfare", -6.0)).set_delay(0.2)
	# The house rises onto the plot with a spring, and the sign turns to "sold".
	var rise_at: float = 0.0 if still else 0.7
	t.tween_property(_house, "scale", Vector2.ONE, 0.01 if still else 0.8).set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT).set_delay(rise_at)
	t.tween_property(_rays, "modulate:a", 0.8, 0.5).set_delay(rise_at)
	t.tween_callback(func() -> void:
		Audio.play(&"plop", -2.0, 0.7)
		Audio.buzz(40, 0.8)
		_sign.piece = "plot_sign_sold"
		_sign.queue_redraw()
		wobbler.tap(_sign, StreetWobbler.Voice.POP)).set_delay(rise_at + 0.4)
	# The family rolls out of the door and waves.
	var out_at: float = rise_at + (0.0 if still else 1.0)
	t.tween_callback(func() -> void:
		_folk.visible = true
		_folk.waving = not still
		Audio.play(&"boing", -6.0, 1.2)).set_delay(out_at)
	t.tween_property(_folk, "position", front, 0.01 if still else 0.6).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT).set_delay(out_at)
	t.tween_property(_folk, "scale", Vector2.ONE, 0.01 if still else 0.6).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT).set_delay(out_at)
	t.tween_callback(func() -> void: _folk.waving = false).set_delay(out_at + 2.4)
	t.tween_callback(_cast.cheer).set_delay(out_at + 0.3)
	# The coins and the helpers fly home.
	var gifts_at: float = out_at + (0.0 if still else 0.9)
	t.tween_callback(func() -> void:
		fly_coins(_house.position + Vector2(0.0, -StreetArt.size(_house.piece).y * _house.k * 0.5),
			int(_reward["coins"]))
		var i: int = 0
		for b: int in range(3):
			if StreetRewards.booster_open(b, door + 1):
				var from: Vector2 = _house.position + Vector2((float(i) - 1.0) * 120.0 * u, -60.0 * u)
				fly_helper(b, from, int(_reward["boosters"]))
				i += 1).set_delay(gifts_at)
	t.tween_callback(finish).set_delay(gifts_at + (0.1 if still else 1.4))

func tap(at: Vector2) -> void:
	var local: Vector2 = (at - _folk.position) / maxf(_folk.scale.x, 0.01)
	var member: int = _folk.member_at(local) if _folk.visible else -1
	if member >= 0:
		_folk.poke(member)
		return
	var cast_member: int = _cast.member_at(at)
	if cast_member >= 0:
		_cast.poke(cast_member)
	elif _house.hit(at):
		wobbler.tap(_house, StreetWobbler.Voice.KNOCK)

## Runs the beats out at once.
func hurry() -> void:
	if _beats != null and _beats.is_running():
		_beats.custom_step(30.0)
