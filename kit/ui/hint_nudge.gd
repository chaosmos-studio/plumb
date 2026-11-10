class_name HintNudge
extends Control

## A player stuck on a level is reminded the hint is there: after a while without one, the hint button wiggles and a
## ring pulses out of it, a few times, then it lets them be. No words. Plumb's most devoted early player solved 127
## levels in five days without ever pressing hint, slowed to a crawl at a new rule, and uninstalled.

## Seconds on a level before the first nudge, between nudges, and how many a level gets at most.
const FIRST: float = 60.0
const AGAIN: float = 45.0
const MOST: int = 3
## The wiggle: its swing in radians and its length in seconds.
const SWING: float = 0.2
const WIGGLE: float = 0.55
## The ring: how far past the button it reaches, as a share of the button's width, and how long it takes.
const REACH: float = 0.8
const RING_TIME: float = 0.85

var _wait: float = FIRST
var _given: int = 0
var _ring: float = -1.0


## Called from HintGate.dress, which every game calls on its hint button: adds the nudge once, and starts the wait
## again whenever the button is dressed (a level opens, a hint is used, the settings change).
static func attach(button: Control) -> void:
	var found: HintNudge = button.get_node_or_null("HintNudge") as HintNudge
	if found != null:
		found.reset()
		return
	var nudge: HintNudge = HintNudge.new()
	nudge.name = "HintNudge"
	button.add_child(nudge)
	var pressable: BaseButton = button as BaseButton
	if pressable != null:
		pressable.pressed.connect(nudge.reset)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func reset() -> void:
	_wait = FIRST
	_given = 0


func _process(delta: float) -> void:
	if _ring >= 0.0:
		_ring += delta
		if _ring > RING_TIME:
			_ring = -1.0
		queue_redraw()
	var button: BaseButton = get_parent() as BaseButton
	if button == null or button.disabled or not button.is_visible_in_tree() or Sheet.any_open() or _given >= MOST:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = AGAIN
		_given += 1
		_nudge(button)


func _nudge(button: Control) -> void:
	button.pivot_offset = button.size * 0.5
	var shake: Tween = button.create_tween()
	var step: float = WIGGLE / 5.0
	for k: int in range(4):
		var side: float = 1.0 if k % 2 == 0 else -1.0
		shake.tween_property(button, "rotation", SWING * side * (1.0 - 0.2 * float(k)), step).set_trans(Tween.TRANS_SINE)
	shake.tween_property(button, "rotation", 0.0, step).set_trans(Tween.TRANS_SINE)
	_ring = 0.0


func _draw() -> void:
	if _ring < 0.0:
		return
	var t: float = clampf(_ring / RING_TIME, 0.0, 1.0)
	var grow: float = 1.0 - pow(1.0 - t, 3.0)
	var radius: float = size.x * 0.5 * (1.0 + REACH * grow)
	draw_arc(size * 0.5, radius, 0.0, TAU, 64, Color(Brand.ACCENT, 0.6 * (1.0 - t)), 2.0 + 6.0 * (1.0 - t), true)
