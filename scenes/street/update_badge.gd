class_name StreetUpdateBadge
extends Button

## The small badge on the street's gear while a newer version waits on Google Play (REVAMP_PLAN.md section 7): red
## with an arrow into a tray while it is on offer, teal with a ring that fills as it downloads, green with a tick once
## it is ready to restart into. It stays until the update is installed. A tap opens the update card.

signal opened

const DIAMETER: float = 54.0
const RING: float = 7.0
const GREEN: Color = Color("4caf3a")

## What it shows: "" (hidden), "available", "downloading" or "ready", and how far the download has come.
var phase: String = ""
var progress: float = 0.0
var _poll: float = 0.0

func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2.ONE * DIAMETER
	size = custom_minimum_size
	visible = false
	pressed.connect(func() -> void: opened.emit())

func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	refresh()

## Reads Play's state, through PlayCore.
func refresh() -> void:
	var state: String = PlayCore.update_state()
	var was: String = phase
	match state:
		"available", "asking", "failed":
			phase = "available" if PlayCore.update_mode() != "" else ""
		"downloading", "installing":
			phase = "downloading"
		"downloaded":
			phase = "ready"
		_:
			phase = ""
	progress = UpdatePolicy.progress(PlayCore.update_info())
	visible = phase != ""
	if phase != was or phase == "downloading":
		queue_redraw()

func _draw() -> void:
	if phase == "":
		return
	var c: Vector2 = size * 0.5
	var r: float = size.x * 0.5
	var fill: Color = StreetUI.RED if phase == "available" else (StreetUI.TEAL if phase == "downloading" else GREEN)
	draw_circle(c + Vector2(0, 3), r, StreetUI.SHADOW, true, -1.0, true)
	StreetUI.gloss_circle(self, c, r, fill)
	draw_arc(c, r - 1.0, 0.0, TAU, 32, StreetUI.CREAM, 3.0, true)
	if phase == "ready":
		StreetArt.draw(self, "icon_tick", c, r * 1.1 / StreetArt.size("icon_tick").x)
		return
	StreetUI.glyph(self, &"update", c, r * 1.15)
	if phase == "downloading":
		draw_arc(c, r + RING * 0.5, -PI * 0.5, -PI * 0.5 + TAU * maxf(progress, 0.04), 40, StreetUI.CREAM, RING, true)
