class_name StreetWobbler
extends Node

## Gives any Node2D or Control the tap wobble (Jiggle): a squash and stretch about its foot or middle, a little rock,
## a small sound and a haptic tick, as tapping anything in Candy Crush does. One per screen steps every wobble still
## moving and puts each thing back exactly as it was when it rests. With Reduce motion a tap answers with a short
## fade instead. Things whose scale another script sets every frame (the map's props) keep their own Jiggle instead.

## A tap's fade under Reduce motion: how far it dims and for how long.
const FADE_TO: float = 0.65
const FADE_TIME: float = 0.18
## The tick a tap gives on a phone: its length in milliseconds and its strength.
const BUZZ_MS: int = 8
const BUZZ: float = 0.25

## The sounds a tap may make, from the game's own palette, and their volume.
enum Voice { POP, BOING, KNOCK, CLINK }
const VOICES: Array[StringName] = [&"pop", &"boing", &"knock", &"clink"]
const VOICE_DB: float = -12.0

var _items: Array[CanvasItem] = []
var _springs: Array[Jiggle] = []
var _scales: Array[Vector2] = []
var _turns: Array[float] = []

func _ready() -> void:
	set_process(false)

## Wobbles `item` (a Node2D or a Control), `strength` 1 for a usual tap.
func tap(item: CanvasItem, voice: Voice = Voice.POP, strength: float = 1.0) -> void:
	if item == null or not is_instance_valid(item):
		return
	Audio.play(VOICES[voice], VOICE_DB, randf_range(0.92, 1.18))
	Audio.buzz(BUZZ_MS, BUZZ)
	if Save.reduce_motion:
		var t: Tween = item.create_tween()
		t.tween_property(item, "modulate:a", FADE_TO, FADE_TIME * 0.4)
		t.tween_property(item, "modulate:a", 1.0, FADE_TIME * 0.6)
		return
	var i: int = _items.find(item)
	if i < 0:
		_items.append(item)
		_springs.append(Jiggle.new())
		_scales.append(_scale_of(item))
		_turns.append(_turn_of(item))
		i = _items.size() - 1
	_springs[i].kick(strength)
	set_process(true)

func _process(delta: float) -> void:
	var i: int = _items.size() - 1
	while i >= 0:
		var item: CanvasItem = _items[i]
		var spring: Jiggle = _springs[i]
		var moving: bool = spring.step(delta)
		if is_instance_valid(item):
			_apply(item, _scales[i] * spring.squash(), _turns[i] + spring.tilt())
		if not moving or not is_instance_valid(item):
			_items.remove_at(i)
			_springs.remove_at(i)
			_scales.remove_at(i)
			_turns.remove_at(i)
		i -= 1
	if _items.is_empty():
		set_process(false)

func _scale_of(item: CanvasItem) -> Vector2:
	if item is Node2D:
		return (item as Node2D).scale
	return (item as Control).scale

func _turn_of(item: CanvasItem) -> float:
	if item is Node2D:
		return (item as Node2D).rotation
	return (item as Control).rotation

func _apply(item: CanvasItem, scale: Vector2, turn: float) -> void:
	if item is Node2D:
		(item as Node2D).scale = scale
		(item as Node2D).rotation = turn
	else:
		(item as Control).scale = scale
		(item as Control).rotation = turn
