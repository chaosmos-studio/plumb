class_name Coach
extends CanvasLayer

## The first level's guide. The screen dims a little except where to look, a ghost finger shows the
## gesture, and a card says what to do. A step that asks for a move lets the move through to the game,
## which calls the next step once it has happened; a step that only explains waits for a tap. Skip ends
## it at any point, and Settings plays it again.

signal advanced
signal closed(completed: bool)

const LAYER: int = 40
const SCRIM_ALPHA: float = 0.34
## A dark screen dimmed toward a darker scrim barely changes, so dark themes dim harder.
const SCRIM_ALPHA_DARK: float = 0.6
const FEATHER: float = 34.0
const CARD_WIDTH: float = 580.0
const CARD_GAP: float = 56.0
const EDGE: float = 28.0
const FADE: float = 0.18

## Off in the tools that stage and film the game, so no capture ever shows the guide.
static var enabled: bool = true
## Set by Settings, so level 1 guides again for a player who has already seen it.
static var requested: bool = false

var done: bool = false
## True while a step waits for a tap.
var waiting: bool:
	get:
		return _waiting
## What the game's input handler checks: `waiting`, and also the rest of the frame in which a tap or Skip
## ended a step, since Godot delivers a tap twice (as a touch and as a mouse click) and the twin must not
## reach the game as a fresh press.
var blocks_input: bool:
	get:
		return _waiting or Engine.get_process_frames() == _tapped_at
var _root: Control
var _scrim: ColorRect
var _catcher: Control
var _card: PanelContainer
var _text: Label
var _foot: Label
var _finger: _Finger
var _halo: _Halo
var _serial: int = 0
var _waiting: bool = false
var _tapped_at: int = -1

## Whether this level should open with the guide.
static func due(level: int) -> bool:
	return enabled and level == 0 and (requested or not Save.tutorial_seen)

## Level 1 with the guide, from any screen.
static func replay() -> void:
	requested = true
	Pack.current = 0
	Screens.go(Brand.GAME_SCENE)

static func open(host: Node) -> Coach:
	var coach: Coach = Coach.new()
	host.add_child(coach)
	return coach

func _init() -> void:
	layer = LAYER
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = preload("res://kit/ui/spotlight.gdshader")
	m.set_shader_parameter("scrim", Color(Brand.SCRIM, SCRIM_ALPHA_DARK if Appearance.dark else SCRIM_ALPHA))
	m.set_shader_parameter("strength", 0.0)
	_scrim.material = m
	_root.add_child(_scrim)
	_catcher = Control.new()
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catcher.gui_input.connect(_on_catch)
	_root.add_child(_catcher)
	_halo = _Halo.new()
	add_child(_halo)
	_finger = _Finger.new()
	add_child(_finger)
	_card = _build_card()
	_root.add_child(_card)

func _ready() -> void:
	_scrim.resized.connect(func() -> void: (_scrim.material as ShaderMaterial).set_shader_parameter("rect_size", _scrim.size))
	(_scrim.material as ShaderMaterial).set_shader_parameter("rect_size", _scrim.size)

## Shows one step. `holes` are the places to look, Vector3(x, y, radius) in viewport coordinates, as for
## Spotlight. `gesture` is &"tap" at `from`, &"swipe" from `from` to `to`, or none. With `wait_tap` the
## call returns once the player taps; otherwise it returns as soon as the step is showing.
func step(text: String, holes: Array[Vector3] = [], gesture: StringName = &"", from: Vector2 = Vector2.ZERO,
		to: Vector2 = Vector2.ZERO, wait_tap: bool = false) -> void:
	if done:
		return
	_serial += 1
	var serial: int = _serial
	_waiting = wait_tap
	_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finger.show_gesture(&"", from, to)
	if _card.modulate.a > 0.0:
		await _fade(_card, 0.0)
	if done or serial != _serial:
		return
	_text.text = text
	_foot.visible = wait_tap
	_light(holes)
	_card.reset_size()
	await get_tree().process_frame
	if done or serial != _serial:
		return
	_place(holes)
	_finger.show_gesture(gesture, from, to)
	if wait_tap:
		_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade(_card, 1.0)
	if wait_tap and not done and serial == _serial:
		await advanced
		_waiting = false

## The player got there: the guide fades away.
func finish() -> void:
	_close(true)

func _on_skip() -> void:
	_tapped_at = Engine.get_process_frames()
	_close(false)

func _close(completed: bool) -> void:
	if done:
		return
	done = true
	_waiting = false
	requested = false
	Save.set_tutorial_seen(true)
	advanced.emit()
	_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finger.show_gesture(&"", Vector2.ZERO, Vector2.ZERO)
	_halo.show_holes([])
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_card, "modulate:a", 0.0, FADE)
	t.tween_method(_strength, (_scrim.material as ShaderMaterial).get_shader_parameter("strength"), 0.0, FADE * 1.5)
	closed.emit(completed)
	await t.finished
	queue_free()

func _on_catch(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or \
		(event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if press and _foot.visible and _card.modulate.a >= 1.0:
		_tapped_at = Engine.get_process_frames()
		_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Audio.play(&"tap", -10.0)
		advanced.emit()

func _light(holes: Array[Vector3]) -> void:
	var packed: Array[Vector4] = []
	for h: Vector3 in holes.slice(0, Spotlight.MAX_HOLES):
		packed.append(Vector4(h.x, h.y, h.z, FEATHER))
	while packed.size() < Spotlight.MAX_HOLES:
		packed.append(Vector4.ZERO)
	var m: ShaderMaterial = _scrim.material as ShaderMaterial
	m.set_shader_parameter("holes", packed)
	m.set_shader_parameter("count", mini(holes.size(), Spotlight.MAX_HOLES))
	_halo.show_holes(holes.slice(0, Spotlight.MAX_HOLES))
	if float(m.get_shader_parameter("strength")) < 1.0:
		create_tween().tween_method(_strength, float(m.get_shader_parameter("strength")), 1.0, Spotlight.FADE_IN)

## Puts the card beside what is lit, on whichever side has more room. When the lit places are spread
## over the whole screen, as for buttons at the top and the bottom, it sits in the middle between them.
func _place(holes: Array[Vector3]) -> void:
	var view: Vector2 = _root.get_viewport_rect().size
	var safe: Dictionary = UI.safe_margins(_root.get_viewport())
	var w: float = minf(CARD_WIDTH, view.x - EDGE * 2.0)
	_card.size = Vector2(w, _card.get_combined_minimum_size().y)
	var h: float = _card.size.y
	var lowest: float = float(safe["top"]) + EDGE
	var highest: float = maxf(lowest, view.y - float(safe["bottom"]) - EDGE - h)
	var y: float = view.y * 0.62 - h * 0.5
	if not holes.is_empty():
		var top: float = INF
		var bottom: float = -INF
		for hole: Vector3 in holes:
			top = minf(top, hole.y - hole.z)
			bottom = maxf(bottom, hole.y + hole.z)
		var above: float = top - CARD_GAP - h
		var below: float = bottom + CARD_GAP
		if above >= lowest and (top > view.y - bottom or below > highest):
			y = above
		elif below <= highest:
			y = below
		else:
			y = (view.y - h) * 0.5
	_card.position = Vector2((view.x - w) * 0.5, clampf(y, lowest, highest))

func _fade(node: CanvasItem, to: float) -> void:
	var t: Tween = create_tween()
	t.tween_property(node, "modulate:a", to, FADE)
	await t.finished

func _strength(v: float) -> void:
	(_scrim.material as ShaderMaterial).set_shader_parameter("strength", v)

func _build_card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	# The card says "Tap to continue", so a tap on it counts as much as one beside it. Skip, a child,
	# still takes its own press first.
	card.gui_input.connect(_on_catch)
	card.modulate.a = 0.0
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Brand.SURFACE
	style.set_corner_radius_all(40)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 26
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 40
	style.content_margin_right = 30
	style.content_margin_top = 32
	style.content_margin_bottom = 14
	style.anti_aliasing = true
	card.add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	_text = UI.label("", 32)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = CARD_WIDTH - 70.0
	column.add_child(_text)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)
	_foot = UI.caption("Tap to continue", 18)
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_foot)
	var skip: Button = UI.button("Skip", UI.Style.GHOST)
	skip.custom_minimum_size = Vector2(0, 72)
	skip.add_theme_font_size_override("font_size", 26)
	skip.pressed.connect(_on_skip)
	foot.add_child(skip)
	return card

## A soft ring breathing around each lit place, so what to look at stands out on either theme.
class _Halo extends Node2D:
	var holes: Array[Vector3] = []
	var _t: float = 0.0

	func show_holes(lit: Array[Vector3]) -> void:
		holes = lit
		_t = 0.0
		set_process(not holes.is_empty())
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pale: Color = Brand.INK if Appearance.dark else Brand.SURFACE
		var breath: float = 0.5 + 0.5 * sin(_t * 2.6)
		var fade: float = clampf(_t / 0.3, 0.0, 1.0)
		for h: Vector3 in holes:
			draw_arc(Vector2(h.x, h.y), h.z + 4.0 + 5.0 * breath, 0.0, TAU, 72, Color(pale, (0.3 + 0.25 * breath) * fade), 3.0, true)

## A soft ghost of a fingertip, pressing for a tap and gliding for a swipe, on a loop until the step
## changes.
class _Finger extends Node2D:
	const RADIUS: float = 34.0
	const TAP_CYCLE: float = 1.5
	const SWIPE_CYCLE: float = 1.9

	var kind: StringName = &""
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var _t: float = 0.0

	func show_gesture(gesture: StringName, a: Vector2, b: Vector2) -> void:
		kind = gesture
		from = a
		to = b
		_t = 0.0
		set_process(kind != &"")
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	## A fingertip is pale on either theme: the surface colour in light, the ink colour in dark.
	func _pale() -> Color:
		return Brand.INK if Appearance.dark else Brand.SURFACE

	func _draw() -> void:
		match kind:
			&"tap":
				var p: float = fmod(_t, TAP_CYCLE) / TAP_CYCLE
				var fade: float = smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.8, 1.0, p))
				var press: float = smoothstep(0.18, 0.32, p) * (1.0 - smoothstep(0.36, 0.5, p))
				if p > 0.3:
					var k: float = clampf((p - 0.3) / 0.5, 0.0, 1.0)
					draw_arc(from, RADIUS * lerpf(1.0, 2.6, k), 0.0, TAU, 48, Color(_pale(), 0.8 * (1.0 - k) * fade), 4.0, true)
				_tip(from, 1.0 - 0.16 * press, fade)
			&"swipe":
				var p2: float = fmod(_t, SWIPE_CYCLE) / SWIPE_CYCLE
				var fade2: float = smoothstep(0.0, 0.1, p2) * (1.0 - smoothstep(0.72, 0.86, p2))
				var along: float = ease(clampf((p2 - 0.12) / 0.5, 0.0, 1.0), -2.2)
				var at: Vector2 = from.lerp(to, along)
				if along > 0.0:
					draw_line(from, at, Color(_pale(), 0.55 * fade2), RADIUS * 0.9, true)
					draw_circle(from, RADIUS * 0.45, Color(_pale(), 0.55 * fade2), true, -1.0, true)
				_tip(at, 1.0, fade2)

	func _tip(at: Vector2, scale_by: float, alpha: float) -> void:
		var r: float = RADIUS * scale_by
		draw_circle(at + Vector2(0, 6), r, Color(0, 0, 0, 0.16 * alpha), true, -1.0, true)
		draw_circle(at, r, Color(_pale(), 0.94 * alpha), true, -1.0, true)
		var edge: Color = Color(Brand.BG, 0.35) if Appearance.dark else Color(Brand.INK, 0.22)
		draw_arc(at, r, 0.0, TAU, 48, Color(edge, edge.a * alpha), 3.0, true)
		draw_circle(at, r * 0.32, Color(Brand.ACCENT, 0.7 * alpha), true, -1.0, true)
