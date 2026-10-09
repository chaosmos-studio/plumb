class_name Replay
extends CanvasLayer

## Watching a solve again. The game plays its own recorded moves from the start between `opening()` and
## `closing()`, calls `beat()` as each move lands, and `finish()` at the end. This sets the game clock's
## pace, puts the screen's controls and the banner away, gives the board a kick on every beat, and reads a
## tap as a wish to skip, which the game sees in `skipping` between moves. A Replay mark sits at the top.
## The clock, the board and the controls come back when it finishes or the screen goes.

const SPEED: float = 2.2
const LAYER: int = 50
## How far the board is thrown on a beat, in pixels, and how long the kick takes to die away.
const KICK: float = 8.0
const KICK_TIME: float = 0.34

var skipping: bool = false
var _hidden: Array[CanvasLayer] = []
var _root: Control
var _kick: float = 0.0
var _clock: float = 0.0
var _canvas: Transform2D = Transform2D.IDENTITY

## Starts a replay over `host`.
static func begin(host: Node) -> Replay:
	var replay: Replay = Replay.new()
	host.add_child(replay)
	return replay

func _ready() -> void:
	layer = LAYER
	_canvas = get_viewport().canvas_transform
	# Controls sit on layers from 1 up; a backdrop under the board, on a lower layer, stays.
	for child: Node in get_parent().get_children():
		if child is CanvasLayer and child != self and (child as CanvasLayer).visible and (child as CanvasLayer).layer >= 1:
			(child as CanvasLayer).visible = false
			_hidden.append(child)
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)
	_mark()
	Ads.cover(true)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_viewport().canvas_transform = _canvas
	_show_controls()
	Ads.cover(false)

## Before the first move: a short pause, then the clock runs at the replay's pace.
func opening() -> void:
	Engine.time_scale = SPEED
	await get_tree().create_timer(0.45).timeout

## A move has landed: the board takes a kick.
func beat() -> void:
	_kick = 1.0

## After the last move: the clock and the board come back to rest.
func closing() -> void:
	Engine.time_scale = 1.0
	_kick = 0.0
	get_viewport().canvas_transform = _canvas

func finish() -> void:
	queue_free()

func _process(delta: float) -> void:
	if _kick <= 0.0:
		return
	_clock += delta
	_kick = maxf(0.0, _kick - delta / KICK_TIME)
	var reach: float = KICK * _kick * _kick
	var zoom: float = 1.0 + 0.018 * _kick
	var centre: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var offset: Vector2 = Vector2(sin(_clock * 61.0), cos(_clock * 47.0)) * reach
	get_viewport().canvas_transform = _canvas * Transform2D(0.0, Vector2(zoom, zoom), 0.0, centre - centre * zoom + offset)

func _on_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed:
		skipping = true

func _show_controls() -> void:
	for hidden: CanvasLayer in _hidden:
		if is_instance_valid(hidden):
			hidden.visible = true
	_hidden.clear()

## The mark: the fast-forward sign and the word on a pill, and how to skip.
func _mark() -> void:
	var mark: VBoxContainer = VBoxContainer.new()
	mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mark.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mark.offset_top = Hud.TOP + float(UI.safe_margins(get_viewport())["top"]) + 6.0
	mark.add_theme_constant_override("separation", 4)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_child(UI.centred(_Pill.new()))
	mark.add_child(UI.caption("Tap to skip", 18))
	_root.add_child(mark)

## The Replay mark: the fast-forward sign and the word, on a pill in the accent colour.
class _Pill extends Control:
	const HEIGHT: float = 64.0

	func _init() -> void:
		custom_minimum_size = Vector2(212.0, HEIGHT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Brand.ACCENT
		box.set_corner_radius_all(int(HEIGHT * 0.5))
		box.anti_aliasing = true
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		Icons.draw(self, &"watch", Vector2(44.0, size.y * 0.5), 40.0, Brand.ACCENT_INK)
		var font: Font = UI.ui_font()
		draw_string(font, Vector2(76.0, size.y * 0.5 + 11.0), "Replay", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Brand.ACCENT_INK)
