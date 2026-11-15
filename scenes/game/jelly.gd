class_name Jelly
extends Node2D

## A bouncy block (MATH.md section 22): a soft lime cube of jelly filling its cell, rounder than a wall, with a
## gloss on top and no lip, so it never reads as a wall or a sleeping animal. Each is its own node, so one that is
## hit wobbles on its own.

## How long a wobble lasts, and how far the block gives along the hit and swells across it.
const WOBBLE_TIME: float = 0.6
const GIVE: float = 0.28
const SWELL: float = 0.16
## Wobbles a second, and how fast they die away over WOBBLE_TIME.
const WOBBLE_RATE: float = 5.0
const DAMPING: float = 4.0

## Half the drawn block's side, in pixels.
var half: float = 36.0
var colour: Color = Color("5aa62a")

var _box: StyleBoxFlat = StyleBoxFlat.new()
var _shine: StyleBoxFlat = StyleBoxFlat.new()
var _left: float = 0.0
## Whether the last hit came along a row rather than a column.
var _across: bool = true

func _ready() -> void:
	set_process(false)
	dress()

## Called again when the theme changes.
func dress() -> void:
	_box.bg_color = colour
	_box.border_color = colour.darkened(0.22)
	_box.set_border_width_all(int(maxf(2.0, half * 0.08)))
	_box.set_corner_radius_all(int(half * 0.5))
	_box.anti_aliasing = true
	_shine.bg_color = Color(1, 1, 1, 0.38)
	_shine.set_corner_radius_all(int(half * 0.24))
	_shine.anti_aliasing = true
	queue_redraw()

## A marble bounced off it, coming from `toward`'s way.
func wobble(toward: Vector2) -> void:
	_across = absf(toward.x) > absf(toward.y)
	_left = WOBBLE_TIME
	set_process(true)

func _process(delta: float) -> void:
	_left = maxf(_left - delta, 0.0)
	var t: float = 1.0 - _left / WOBBLE_TIME
	# A damped spring: squashed along the hit at once, then ringing out.
	var give: float = cos(TAU * WOBBLE_RATE * t * WOBBLE_TIME) * exp(-DAMPING * t)
	var along: float = 1.0 - GIVE * give
	var across: float = 1.0 + SWELL * give
	scale = Vector2(along, across) if _across else Vector2(across, along)
	if _left <= 0.0:
		scale = Vector2.ONE
		set_process(false)

func _draw() -> void:
	draw_style_box(_box, Rect2(-half, -half, half * 2.0, half * 2.0))
	# Light through the top, and a bright spot where it catches, as on a gummy sweet.
	draw_style_box(_shine, Rect2(-half * 0.62, -half * 0.74, half * 1.24, half * 0.42))
	draw_circle(Vector2(-half * 0.42, -half * 0.52), half * 0.1, Color(1, 1, 1, 0.75), true, -1.0, true)
	draw_circle(Vector2(half * 0.12, half * 0.18), half * 0.32, Color(colour.lightened(0.18), 0.55), true, -1.0, true)
