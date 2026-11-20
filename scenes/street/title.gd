class_name StreetTitle
extends Node2D

## The PLUMB title art in the sky, with only blue sky behind it (build/review/revamp2/1-map.png). It is a soft,
## wobbly thing: at rest it bobs and breathes in a slow jelly squash with a little sway, and a tap sets it wobbling on
## the tap spring (Jiggle). Drawn about its middle, so it squashes about its middle. Reduce motion holds it still.

## Its bob at rest: how far, in design pixels, and how fast.
const BOB: float = 6.0
const BOB_SPEED: float = 1.3
## Its idle jelly: how deep the squash and stretch, how far it sways, in radians, and how fast each goes. The two run
## at different speeds so the wobble never settles into a pattern.
const SQUASH: float = 0.035
const SQUASH_SPEED: float = 2.1
const SWAY: float = 0.025
const SWAY_SPEED: float = 1.45
## A tap's push, against the spring's usual one.
const TAP: float = 1.5

var _rest: Vector2 = Vector2.ZERO
var _k: float = 1.0
var _t: float = 0.0
var _spring: Jiggle = Jiggle.new()

## Puts it with its top at `top`, centred on a screen of `size`, at most `width` wide.
func place(size: Vector2, top: float, width: float) -> void:
	var w: float = minf(width, size.x * 0.84)
	_k = w / StreetArt.size("title_plumb").x
	_rest = Vector2(size.x * 0.5, top + StreetArt.size("title_plumb").y * _k * 0.5)
	position = _rest
	queue_redraw()

## Its foot on screen at rest.
func foot() -> float:
	return _rest.y + StreetArt.size("title_plumb").y * _k * 0.5

## Whether a screen point is on it.
func hit(at: Vector2) -> bool:
	var half: Vector2 = StreetArt.size("title_plumb") * _k * 0.5
	return Rect2(_rest - half, half * 2.0).has_point(at)

## A tap: a big wobble, a boing and a tick, or under Reduce motion a short fade.
func poke() -> void:
	Audio.play(&"boing", StreetWobbler.VOICE_DB, randf_range(0.9, 1.15))
	Audio.buzz(StreetWobbler.BUZZ_MS, StreetWobbler.BUZZ)
	if Save.reduce_motion:
		var t: Tween = create_tween()
		t.tween_property(self, "modulate:a", StreetWobbler.FADE_TO, StreetWobbler.FADE_TIME * 0.4)
		t.tween_property(self, "modulate:a", 1.0, StreetWobbler.FADE_TIME * 0.6)
		return
	_spring.kick(TAP)

func _process(delta: float) -> void:
	if Save.reduce_motion:
		position = _rest
		scale = Vector2.ONE
		rotation = 0.0
		return
	_t += delta
	_spring.step(delta)
	var breath: float = SQUASH * sin(_t * SQUASH_SPEED)
	position = _rest + Vector2(0.0, sin(_t * BOB_SPEED) * BOB)
	scale = _spring.squash() * Vector2(1.0 + breath, 1.0 / (1.0 + breath))
	rotation = _spring.tilt() * 2.0 + SWAY * sin(_t * SWAY_SPEED)

func _draw() -> void:
	StreetArt.draw(self, "title_plumb", Vector2.ZERO, _k)
