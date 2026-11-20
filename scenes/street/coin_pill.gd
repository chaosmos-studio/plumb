class_name StreetCoinPill
extends Control

## The coins a player has, on a cream pill with the painted coin over its left end (REVAMP_PLAN.md section 4.7). It
## counts up when coins arrive, its coin bouncing on each, and idles with a slow glint. A tap opens the shop.
## `fly` sends coins arcing from a point into it, each one counted as it lands.

signal pressed

const HEIGHT: float = 72.0
## The painted coin's size, as a share of the pill's height, and how far it overhangs the pill's left end.
const COIN: float = 1.18
const OVERHANG: float = 10.0
const FONT_SIZE: int = 48
const PAD: float = 26.0
## A count-up's length: a base, plus this much a coin, never longer than COUNT_MAX seconds.
const COUNT_BASE: float = 0.25
const COUNT_PER: float = 0.02
const COUNT_MAX: float = 0.9
## The idle glint: the coin rocks this far, in radians, this fast.
const GLINT: float = 0.08
const GLINT_SPEED: float = 1.4
## A flying coin: its size, its arc's height as a share of its flight, and its flight time; coins leave this far
## apart.
const FLY_SIZE: float = 54.0
const FLY_ARC: float = 0.35
const FLY_TIME: float = 0.55
const FLY_GAP: float = 0.05

## Whether it follows the purse in the save as it changes. A scene that flies coins in turns this off and counts
## them itself.
var follow_save: bool = true:
	set(value):
		follow_save = value
		if value:
			set_value(Save.coins)
var _shown: float = 0.0
var _count: Tween
var _spring: Jiggle = Jiggle.new()
var _t: float = 0.0
var _tick_at: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shown = float(Save.coins)
	Save.coins_changed.connect(func(total: int) -> void:
		if follow_save:
			count_to(total))
	_fit()

## Shows `value` at once.
func set_value(value: int) -> void:
	if _count != null:
		_count.kill()
	_shown = float(value)
	_fit()

## Counts up (or down) to `value`, ticking, its coin bouncing. Under Reduce motion it shows the new number at once.
func count_to(value: int) -> void:
	if _count != null:
		_count.kill()
	if Save.reduce_motion:
		set_value(value)
		return
	var time: float = minf(COUNT_MAX, COUNT_BASE + COUNT_PER * absf(float(value) - _shown))
	_count = create_tween()
	_count.tween_method(_show, _shown, float(value), time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bump()

## The coin bounces, with a tick.
func bump() -> void:
	if not Save.reduce_motion:
		_spring.kick(0.8)

func _show(value: float) -> void:
	var whole: int = roundi(value)
	if whole != roundi(_shown) and Time.get_ticks_msec() - _tick_at > 60:
		_tick_at = Time.get_ticks_msec()
		Audio.play(&"clink", -16.0, randf_range(1.2, 1.5))
	_shown = value
	_fit()

## Its width follows the number's.
func _fit() -> void:
	var text_w: float = StreetArt.font().get_string_size(str(roundi(_shown)), HORIZONTAL_ALIGNMENT_LEFT, -1,
		FONT_SIZE).x
	custom_minimum_size = Vector2(HEIGHT * COIN - OVERHANG + text_w + PAD * 1.4, HEIGHT)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	queue_redraw()

## The coin's middle, on screen.
func coin_point() -> Vector2:
	return get_global_transform_with_canvas() * Vector2(HEIGHT * COIN * 0.5 - OVERHANG, HEIGHT * 0.5)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		accept_event()
		Audio.play(&"clink", -8.0)
		Audio.buzz(StreetWobbler.BUZZ_MS, StreetWobbler.BUZZ)
		bump()
		pressed.emit()

func _process(delta: float) -> void:
	_t += delta
	_spring.step(delta)
	queue_redraw()

func _draw() -> void:
	var coin_w: float = HEIGHT * COIN
	var pill: Rect2 = Rect2(Vector2(coin_w * 0.5 - OVERHANG, 2.0), Vector2(size.x - coin_w * 0.5 + OVERHANG, HEIGHT - 4.0))
	StreetUI.gloss_pill(self, pill, StreetUI.CREAM)
	var font: Font = StreetArt.font()
	draw_string(font, Vector2(coin_w - OVERHANG + PAD * 0.5, HEIGHT * 0.5 + FONT_SIZE * 0.36), str(roundi(_shown)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, StreetUI.INK)
	var centre: Vector2 = Vector2(coin_w * 0.5 - OVERHANG, HEIGHT * 0.5)
	var rock: float = 0.0 if Save.reduce_motion else GLINT * sin(_t * GLINT_SPEED)
	draw_set_transform(centre, rock + _spring.tilt(), _spring.squash())
	StreetArt.draw(self, "coin", Vector2.ZERO, coin_w / StreetArt.size("coin").x)
	draw_set_transform(Vector2.ZERO)

## Sends `count` coins (drawn, at most a dozen) arcing from `from` to `pill`'s coin, on `parent`, which must draw in
## screen space. Each landing calls `on_land` with its share of `amount`, the last one taking what is left, so the
## shares always add up to it. Answers how long the flight takes. Under Reduce motion the coins simply arrive.
static func fly(parent: Node, from: Vector2, pill: StreetCoinPill, amount: int, on_land: Callable) -> float:
	@warning_ignore("integer_division")
	var count: int = clampi(amount / 5 + 3, 3, 12)
	if Save.reduce_motion:
		on_land.call(amount)
		return 0.0
	@warning_ignore("integer_division")
	var share: int = amount / count
	var to: Vector2 = pill.coin_point()
	for i: int in range(count):
		var coin: _Flying = _Flying.new()
		coin.from = from + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0))
		coin.to = to
		coin.top = minf(coin.from.y, to.y) - absf(to.x - coin.from.x) * FLY_ARC - 60.0
		parent.add_child(coin)
		var last: bool = i == count - 1
		var lands: int = amount - share * (count - 1) if last else share
		var t: Tween = coin.create_tween()
		t.tween_interval(i * FLY_GAP)
		t.tween_method(coin.at, 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void:
			on_land.call(lands)
			pill.bump()
			Audio.play(&"clink", -12.0, randf_range(1.1, 1.5))
			coin.queue_free())
	return (count - 1) * FLY_GAP + FLY_TIME


## One coin in flight: up over a little arc and down into the pill, spinning as it goes.
class _Flying extends Node2D:
	var from: Vector2
	var to: Vector2
	var top: float

	func at(t: float) -> void:
		var mid: Vector2 = Vector2((from.x + to.x) * 0.5, top)
		position = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		scale = Vector2(cos(t * TAU * 1.5), 1.0) * lerpf(1.0, 0.7, t)
		queue_redraw()

	func _draw() -> void:
		StreetArt.draw(self, "coin", Vector2.ZERO, StreetCoinPill.FLY_SIZE / StreetArt.size("coin").x)
