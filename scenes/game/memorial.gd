class_name Memorial
extends CanvasLayer

## A marble down a pit, with faces on, gets a short memorial in the reel's spirit: the screen goes black and
## white, a framed photo with its name, a candle and a flower, then the colour snaps back. A tap skips it, and
## after the first few in a session it is shorter (Mood.memorial_length).

signal done

## Over the play screen's HUD and under the sheets, so the pit banner that follows rises over the colour.
const LAYER: int = 50
const GREY: Shader = preload("res://scenes/game/grey.gdshader")
const FRAME: Vector2 = Vector2(232, 268)
const PORTRAIT: float = 66.0
const NAME_SIZE: int = 52
const YEARS_SIZE: int = 26
const FLASH: float = 0.12
## The whole card's size on the screen, in the 720 wide design.
const SIZE: float = 1.25
## A dark plaque behind the card, so the words read on a light board gone grey as well as a dark one.
const PLAQUE: Color = Color(0.08, 0.08, 0.08, 0.62)
const OUTLINE: int = 8

## How many this session has shown, for Mood.memorial_length.
static var shown: int = 0

var _grey: ColorRect
var _flash: ColorRect
var _card: _Card
var _over: bool = false

## `centre` is where on the screen the card goes, the board's middle.
static func open(host: Node, who: int, colour: Color, centre: Vector2) -> Memorial:
	var m: Memorial = Memorial.new()
	m.layer = LAYER
	host.add_child(m)
	m._build(who, colour, centre)
	return m

## Draws the grey pass once, unseen, so its shader is ready before the first fall needs it.
static func warm(host: Node) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = LAYER
	host.add_child(layer)
	var dot: ColorRect = ColorRect.new()
	dot.size = Vector2(2, 2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GREY
	material.set_shader_parameter("amount", 0.0)
	material.set_shader_parameter("dusk", 0.0)
	dot.material = material
	layer.add_child(dot)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if is_instance_valid(layer):
		layer.queue_free()

func _build(who: int, colour: Color, centre: Vector2) -> void:
	var length: float = Mood.memorial_length(shown)
	var full: bool = shown < Mood.MEMORIAL_FULL_COUNT
	shown += 1
	_grey = ColorRect.new()
	_grey.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GREY
	_grey.material = material
	_grey.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
			skip())
	add_child(_grey)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0.22)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	create_tween().tween_property(_flash, "color:a", 0.0, FLASH)
	_card = _Card.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.position = centre
	_card.who = Cast.of(who)
	_card.year = Time.get_date_dict_from_system()["year"]
	add_child(_card)
	var portrait: Marble = Marble.new()
	portrait.radius = PORTRAIT
	var grey: float = clampf(colour.get_luminance() * 0.75 + 0.2, 0.0, 1.0)
	portrait.colour = Color(grey, grey, grey)
	portrait.who = who
	portrait.position = Vector2(0.0, -FRAME.y * 0.5 - 40.0 + FRAME.y * 0.47)
	# A photo holds still: no blinks.
	portrait.set_process(false)
	_card.add_child(portrait)
	_card.scale = Vector2.ONE * SIZE * (0.9 if full else 1.0)
	_card.modulate.a = 0.0
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_card, "modulate:a", 1.0, 0.12)
	if full:
		t.tween_property(_card, "scale", Vector2.ONE * SIZE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_card.words = 0.0
		t.tween_property(_card, "words", 1.0, 0.4).set_delay(0.12)
	else:
		_card.words = 1.0
	get_tree().create_timer(length).timeout.connect(skip)

## The colour snaps back: the memorial ends now, whether its time is up or the player tapped.
func skip() -> void:
	if _over:
		return
	_over = true
	done.emit()
	queue_free()

## The photo in its frame, the candle, the flower and the name, all in greys.
class _Card extends Control:
	var who: Cast.Who
	var year: int = 2026
	## 0 to 1: the name, then the years, fade in.
	var words: float = 1.0:
		set(value):
			words = value
			queue_redraw()
	var _t: float = 0.0
	# Made once, since the candle draws the card again every frame.
	var _plaque: StyleBoxFlat = _box(PLAQUE, 36)
	var _outer: StyleBoxFlat = _box(Color(0.23, 0.23, 0.23), 18)
	var _mat: StyleBoxFlat = _box(Color(0.86, 0.86, 0.86), 8)
	var _wax: StyleBoxFlat = _box(Color(0.94, 0.94, 0.94), 6)
	var _font: Font = load(Brand.FONT_UI)
	var _points: PackedVector2Array = PackedVector2Array()

	var _name: String = ""
	var _years: String = ""

	func _ready() -> void:
		_outer.shadow_color = Color(0, 0, 0, 0.35)
		_outer.shadow_size = 18
		_outer.shadow_offset = Vector2(0, 8)
		_name = who.name.to_lower()
		_years = "%d to %d" % [year, year]

	static func _box(colour: Color, corner: int) -> StyleBoxFlat:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = colour
		box.set_corner_radius_all(corner)
		box.anti_aliasing = true
		return box

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var frame: Rect2 = Rect2(Vector2(-FRAME.x * 0.5, -FRAME.y * 0.5 - 40.0), FRAME)
		draw_style_box(_plaque, Rect2(frame.position - Vector2(116.0, 34.0), frame.size + Vector2(232.0, 186.0)))
		draw_style_box(_outer, frame)
		draw_style_box(_mat, frame.grow(-16.0))
		# A black sash across the top right corner.
		var c: Vector2 = Vector2(frame.end.x, frame.position.y)
		_points.resize(4)
		_points[0] = c + Vector2(-58, 0)
		_points[1] = c + Vector2(-30, 0)
		_points[2] = c + Vector2(0, 30)
		_points[3] = c + Vector2(0, 58)
		draw_colored_polygon(_points, Color(0.06, 0.06, 0.06))
		_candle(Vector2(frame.position.x - 62.0, frame.end.y))
		_flower(Vector2(frame.end.x + 58.0, frame.end.y))
		var name_alpha: float = clampf(words * 2.0, 0.0, 1.0)
		var years_alpha: float = clampf(words * 2.0 - 1.0, 0.0, 1.0)
		_centred(_name, Vector2(0.0, frame.end.y + 62.0), NAME_SIZE, Color(0.95, 0.95, 0.95, name_alpha))
		_centred(_years, Vector2(0.0, frame.end.y + 104.0), YEARS_SIZE, Color(0.78, 0.78, 0.78, years_alpha))

	func _centred(text: String, at: Vector2, size: int, colour: Color) -> void:
		var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string_outline(_font, at - Vector2(w * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, OUTLINE,
			Color(0.06, 0.06, 0.06, colour.a))
		draw_string(_font, at - Vector2(w * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)

	## A white candle standing on `foot`, its flame flickering.
	func _candle(foot: Vector2) -> void:
		var body: Rect2 = Rect2(foot + Vector2(-17.0, -104.0), Vector2(34.0, 104.0))
		draw_style_box(_wax, body)
		var top: Vector2 = Vector2(foot.x, body.position.y)
		draw_line(top, top + Vector2(0.0, -10.0), Color(0.2, 0.2, 0.2), 3.0, true)
		var flicker: float = 1.0 + 0.08 * sin(_t * 23.0) + 0.05 * sin(_t * 37.0 + 1.3)
		var sway: float = 2.0 * sin(_t * 9.0)
		draw_circle(top + Vector2(0.0, -24.0), 30.0 * flicker, Color(1, 1, 1, 0.12), true, -1.0, true)
		var base: Vector2 = top + Vector2(0.0, -12.0)
		_points.resize(14)
		for k: int in range(13):
			var a: float = PI * k / 12.0
			_points[k] = base + Vector2(cos(a) * 9.0, sin(a) * 7.0)
		_points[13] = top + Vector2(sway, -42.0 * flicker)
		draw_colored_polygon(_points, Color(1, 1, 1, 0.95))

	## A daisy on a stem, standing on `foot`.
	func _flower(foot: Vector2) -> void:
		_points.resize(9)
		for k: int in range(9):
			var t: float = k / 8.0
			_points[k] = foot + Vector2(sin(t * 2.2) * 8.0, -t * 112.0)
		draw_polyline(_points, Color(0.55, 0.55, 0.55), 4.0, true)
		draw_set_transform(foot + Vector2(10.0, -46.0), -0.6, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 14.0, Color(0.55, 0.55, 0.55), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
		var head: Vector2 = _points[8]
		for k: int in range(6):
			draw_circle(head + Vector2.from_angle(TAU * k / 6.0 + 0.3) * 15.0, 11.0, Color(0.96, 0.96, 0.96), true, -1.0, true)
		draw_circle(head, 9.0, Color(0.6, 0.6, 0.6), true, -1.0, true)
