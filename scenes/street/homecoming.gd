class_name StreetHomecoming
extends Node2D

## A win's homecoming, with nothing to press (REVAMP_PLAN.md section 8 moment 14, build/review/revamp2/4-win.png). The
## board's colours each have a house at the top of the square's steps, doors open. The level's marbles hop home into
## them, the doors close and the windows light. Then the stars earned slam in over slow rays of light, and on three
## stars the marbles pop back out in party hats and cheer under confetti. `play` builds it, starts it and answers how
## long it takes.

## The houses: their widest, and the line their feet stand on, as a share of the screen's height.
const HOUSE_WIDTH: float = 380.0
const GROUND_AT: float = 0.6
## The neighbours a row back: their size beside the level's houses, how far back they stand, and their trees' size.
const BACK_SCALE: float = 0.62
const BACK_RISE: float = 70.0
const BACK_TREE: float = 1.0
## A marble's size, and its hop home: its height and how long it takes.
const BALL: float = 160.0
const HOP: float = 150.0
const HOP_TIME: float = 0.6
const HOP_GAP: float = 0.14
## The stars: the middle one's size and the outer ones', their spacing and height on screen, how far the outer ones
## sit lower, and the gap between them landing.
const STAR_MIDDLE: float = 190.0
const STAR_SIDE: float = 150.0
const STAR_GAP: float = 205.0
const STARS_AT: float = 0.22
const STAR_DROP: float = 40.0
const STAR_TIME: float = 0.3
## Rays behind the stars turn this fast, in radians a second.
const RAY_SPIN: float = 0.25
## A wide screen: the line the houses stand on, the stars' height, and everything's size against the portrait one's,
## so the scene fits a screen 720 tall with the stars clear above the roofs.
const WIDE_GROUND_AT: float = 0.6
const WIDE_STARS_AT: float = 0.19
const WIDE_SCALE: float = 0.66

var colours: PackedInt32Array = PackedInt32Array()
var earned: int = 0
## Where the marbles start: the board's middle on screen.
var from: Vector2 = Vector2.ZERO
var _rays: _Piece
var _balls: Array[_Ball] = []
var _houses: Array[_Piece] = []
var _wobbler: StreetWobbler

func play() -> float:
	var size: Vector2 = get_viewport_rect().size
	var n: int = colours.size()
	var wide: bool = StreetLayout.wide(size)
	var u: float = WIDE_SCALE if wide else 1.0
	var ground: float = size.y * (WIDE_GROUND_AT if wide else GROUND_AT)
	var stars_y: float = size.y * (WIDE_STARS_AT if wide else STARS_AT)
	var plaza: TextureRect = TextureRect.new()
	plaza.texture = StreetArt.backdrop(StreetArt.WIN_BACKDROP, wide)
	plaza.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plaza.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	plaza.size = size
	plaza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaza.modulate.a = 0.0
	add_child(plaza)
	var width: float = minf(HOUSE_WIDTH * u, (size.x - 20.0) / float(n))
	var ball_w: float = BALL * u
	# The street behind: neighbours' houses a row back with trees among them, so the square is a full street, as in
	# the concept, however few colours the level had.
	var back: Array[_Piece] = []
	var back_w: float = width * BACK_SCALE
	var back_n: int = ceili(size.x / back_w) + 1
	for i: int in range(back_n + 1):
		var tree: _Piece = _Piece.new("tree_%d" % (1 + i % 3), BACK_TREE * u)
		tree.position = Vector2(size.x * 0.5 + (float(i) - float(back_n) * 0.5) * back_w, ground - BACK_RISE * u - 20.0)
		back.append(tree)
	for i: int in range(back_n):
		var name: String = "house_%s_%d" % [StreetArt.COLOURS[(i + 1) % 4], 1 + (i * 3 + 1) % StreetArt.SHAPES]
		var bk: float = back_w / StreetArt.size(name).x * 0.95
		var neighbour: _Piece = _Piece.new(name, bk)
		neighbour.position = Vector2(size.x * 0.5 + (float(i) - float(back_n - 1) * 0.5) * back_w, ground - BACK_RISE * u)
		back.append(neighbour)
		var nd: Vector3 = StreetArt.door(name) * bk
		var shut: _Piece = _Piece.new("door_" + StreetArt.COLOURS[(i + 1) % 4], bk)
		shut.position = neighbour.position + Vector2(nd.x, nd.y)
		back.append(shut)
	for p: _Piece in back:
		p.modulate.a = 0.0
		add_child(p)
	var houses: Array[_Piece] = []
	var feet: Array[_Piece] = []
	var opens: Array[_Piece] = []
	var shuts: Array[_Piece] = []
	var windows: Array[_Piece] = []
	var balls: Array[_Ball] = []
	for i: int in range(n):
		var colour: String = StreetArt.COLOURS[colours[i] % 4]
		var house_name: String = "house_%s_1" % colour
		var k: float = width / StreetArt.size(house_name).x * 0.96
		var x: float = size.x * 0.5 + (float(i) - float(n - 1) * 0.5) * width
		var house: _Piece = _Piece.new(house_name, k)
		house.position = Vector2(x, ground)
		houses.append(house)
		for side: int in [-1, 1]:
			var bed: _Piece = _Piece.new(("flowerbed_%d" % (1 + (i + side + 3) % 3)) if (i + side) % 2 == 0 else "bush_big_1",
				k * 0.7)
			bed.position = Vector2(x + side * width * 0.4, ground + 10.0)
			feet.append(bed)
		var d: Vector3 = StreetArt.door(house_name) * k
		var at: Vector2 = Vector2(x + d.x, ground + d.y)
		opens.append(_Piece.new("door_open", k))
		opens[i].position = at
		shuts.append(_Piece.new("door_" + colour, k))
		shuts[i].position = at
		for wr: Rect2 in StreetArt.windows(house_name):
			var lit: _Piece = _Piece.new("window_lit", k)
			lit.position = house.position + wr.get_center() * k
			windows.append(lit)
		var ball: _Ball = _Ball.new()
		ball.colour = colours[i]
		ball.width = ball_w
		ball.lift = HOP * u
		ball.position = from + Vector2((float(i) - float(n - 1) * 0.5) * ball_w * 1.1, 0.0)
		ball.home = at
		ball.step_out = Vector2(lerpf(at.x, size.x * 0.5, 0.25), ground + ball_w * (1.5 + 0.35 * float(i % 2)))
		balls.append(ball)
	for layer: Array in [houses, opens, shuts, windows, feet]:
		for p: _Piece in layer:
			p.modulate.a = 0.0
			add_child(p)
	for b: _Ball in balls:
		add_child(b)
	_balls = balls
	_houses = houses
	_wobbler = StreetWobbler.new()
	add_child(_wobbler)
	_rays = _Piece.new("rays", 1.1)
	_rays.position = Vector2(size.x * 0.5, stars_y)
	_rays.scale = Vector2.ONE * u
	_rays.modulate.a = 0.0
	add_child(_rays)
	var stars: Array[_Piece] = []
	var sparks: Array[_Piece] = []
	for s: int in range(3):
		var star_size: float = (STAR_MIDDLE if s == 1 else STAR_SIDE) * u
		var at: Vector2 = Vector2(size.x * 0.5 + (s - 1) * STAR_GAP * u, stars_y + (0.0 if s == 1 else STAR_DROP * u))
		if s < earned:
			var spark: _Piece = _Piece.new("sparks", star_size * 1.25 / StreetArt.size("sparks").x)
			spark.position = at + Vector2(0.0, -star_size * 0.12)
			spark.scale = Vector2.ZERO
			add_child(spark)
			sparks.append(spark)
		var piece: String = "star_big" if s < earned else "star_big_dim"
		var star: _Piece = _Piece.new(piece, star_size / StreetArt.size(piece).x)
		star.position = at
		star.scale = Vector2.ZERO
		add_child(star)
		stars.append(star)

	var t: Tween = create_tween().set_parallel()
	t.tween_property(plaza, "modulate:a", 1.0, 0.3)
	for p: _Piece in back:
		t.tween_property(p, "modulate:a", 1.0, 0.3)
	for p: _Piece in feet:
		t.tween_property(p, "modulate:a", 1.0, 0.25).set_delay(0.2)
	for i: int in range(n):
		t.tween_property(houses[i], "modulate:a", 1.0, 0.25).set_delay(i * 0.07)
		t.tween_property(houses[i], "position:y", ground, 0.45).from(ground + 90.0).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT).set_delay(i * 0.07)
		t.tween_property(opens[i], "modulate:a", 1.0, 0.2).set_delay(0.3 + i * 0.07)
	var hop_at: float = 0.5
	for i: int in range(n):
		var b: _Ball = balls[i]
		var at: float = hop_at + i * HOP_GAP
		t.tween_method(b.hop.bind(b.position, b.home), 0.0, 1.0, HOP_TIME).set_delay(at)
		t.tween_property(b, "scale", Vector2(0.4, 0.4), 0.14).set_delay(at + HOP_TIME - 0.08)
		t.tween_property(b, "modulate:a", 0.0, 0.1).set_delay(at + HOP_TIME - 0.04)
		t.tween_property(shuts[i], "modulate:a", 1.0, 0.1).set_delay(at + HOP_TIME + 0.04)
		t.tween_property(shuts[i], "scale", Vector2.ONE, 0.28).from(Vector2(1.18, 1.18)).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT).set_delay(at + HOP_TIME + 0.04)
		var colour: int = colours[i]
		t.tween_callback(func() -> void:
			Audio.sink(colour)
			Audio.play(&"plop", -6.0)
			Audio.buzz(12, 0.35)).set_delay(at + HOP_TIME)
	var lit_at: float = hop_at + (n - 1) * HOP_GAP + HOP_TIME + 0.25
	for i: int in range(windows.size()):
		t.tween_property(windows[i], "modulate:a", 1.0, 0.16).set_delay(lit_at + i * 0.05)
	var star_at: float = lit_at + 0.35
	t.tween_property(_rays, "modulate:a", 0.85, 0.5).set_delay(star_at - 0.2)
	for s: int in range(3):
		var at: float = star_at + s * STAR_TIME
		t.tween_property(stars[s], "scale", Vector2.ONE, 0.34).from(Vector2(1.7, 1.7) if s < earned else Vector2(0.6, 0.6)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(at)
		if s < earned:
			t.tween_property(sparks[s], "scale", Vector2.ONE, 0.3).from(Vector2(0.5, 0.5)).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT).set_delay(at + 0.12)
			t.tween_callback(func() -> void:
				Audio.play(&"star", -2.0, 1.0 + 0.08 * s)
				Audio.buzz(16, 0.55)).set_delay(at + 0.05)
	var end: float = star_at + 3.0 * STAR_TIME + 0.4
	if earned == 3:
		for i: int in range(n):
			var b: _Ball = balls[i]
			var hat: int = 1 + (colours[i] % 4)
			var at: float = end + i * 0.08
			t.tween_callback(func() -> void: b.hat = hat).set_delay(at)
			t.tween_property(shuts[i], "modulate:a", 0.0, 0.1).set_delay(at)
			t.tween_property(b, "modulate:a", 1.0, 0.08).set_delay(at)
			t.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
				.set_delay(at)
			t.tween_method(b.hop.bind(b.home, b.step_out), 0.0, 1.0, 0.45).set_delay(at)
			t.tween_callback(func() -> void: b.cheering = true).set_delay(at + 0.45)
		t.tween_callback(func() -> void:
			Audio.play(&"chord", -4.0)
			# Confetti from the stars and from both sides of the square, so it rains over the whole street.
			for spot: Vector2 in [Vector2(0.5, 0.0), Vector2(0.08, 0.35), Vector2(0.92, 0.35)]:
				var burst: Flourish.Burst = Flourish.Burst.new()
				burst.count = 70
				burst.speed = 950.0
				burst.gravity = 1000.0
				burst.life = 1.9
				burst.size = 17.0
				burst.colours = [StreetUI.RED, StreetUI.YELLOW, StreetUI.TEAL, StreetUI.PURPLE, Color.WHITE]
				burst.position = Vector2(size.x * spot.x, stars_y + size.y * spot.y)
				add_child(burst)).set_delay(end + 0.2)
		end += 1.6
	return end + 0.5

## A tap at `at`: the marble or the house under it wobbles. Answers whether one did.
func poke(at: Vector2) -> bool:
	for b: _Ball in _balls:
		if b.modulate.a > 0.5 and at.distance_to(b.position) < b.width * 0.6:
			_wobbler.tap(b, StreetWobbler.Voice.BOING)
			return true
	for h: _Piece in _houses:
		var size: Vector2 = StreetArt.size(h.piece) * h.k
		if Rect2(h.position - Vector2(size.x * 0.5, size.y), size).has_point(at):
			_wobbler.tap(h, StreetWobbler.Voice.KNOCK)
			return true
	return false

func _process(delta: float) -> void:
	if _rays != null:
		_rays.rotation += RAY_SPIN * delta


class _Piece extends Node2D:
	var piece: String
	var k: float

	func _init(name: String, scale_k: float) -> void:
		piece = name
		k = scale_k

	func _draw() -> void:
		StreetArt.draw(self, piece, Vector2.ZERO, k)


## A cast member on the move: its painted body, a happy face, and a party hat once it has one.
class _Ball extends Node2D:
	var colour: int = 0
	var width: float = 112.0
	var home: Vector2 = Vector2.ZERO
	var step_out: Vector2 = Vector2.ZERO
	var hat: int = 0
	## How high a hop rises.
	var lift: float = 150.0
	var cheering: bool = false:
		set(value):
			cheering = value
			set_process(value)
	var _t: float = 0.0

	func _ready() -> void:
		set_process(false)

	## Moves along a hop from `a` to `b`, `t` from 0 to 1.
	func hop(t: float, a: Vector2, b: Vector2) -> void:
		position = a.lerp(b, t) + Vector2(0.0, -lift * 4.0 * t * (1.0 - t))
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		position.y = step_out.y - absf(sin(_t * 7.0)) * width * 0.25
		queue_redraw()

	func _draw() -> void:
		var k: float = width / StreetArt.size("marble_red").x
		StreetArt.draw(self, "marble_" + StreetArt.COLOURS[colour % 4], Vector2.ZERO, k)
		StreetArt.draw(self, "eye_happy", Vector2(-0.17, -0.04) * width, k)
		StreetArt.draw(self, "eye_happy", Vector2(0.17, -0.04) * width, k)
		StreetArt.draw(self, "blush", Vector2(-0.27, 0.1) * width, k)
		StreetArt.draw(self, "blush", Vector2(0.27, 0.1) * width, k)
		StreetArt.draw(self, "mouth_laugh", Vector2(0.0, 0.16) * width, k)
		if hat > 0:
			StreetArt.draw(self, "hat_%d" % hat, Vector2(width * 0.12, -width * 0.36), k * 1.05)
