class_name Device
extends Control

## A phone around the game, for landscape films, shaped like a current handset: a 19.5:9 screen, thin
## even bezels, a punch-hole camera, side keys and a hint of glass. The game is laid out for that screen
## shape, so what is inside is exactly what a player on such a phone sees.

## Screen height over width.
const ASPECT: float = 19.5 / 9.0
## Bezel and corner radius as fractions of the body's width.
const BEZEL: float = 0.028
const RADIUS: float = 0.15

var texture: Texture2D
var _screen: TextureRect
var _glass: _Glass
var _shader: Shader

## The body's size for a given height, so a film can place the phone before it is built.
static func body_for_height(h: float) -> Vector2:
	return Vector2(h / (ASPECT * (1.0 - 2.0 * BEZEL) + 2.0 * BEZEL), h)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader = Shader.new()
	_shader.code = """
shader_type canvas_item;
uniform vec2 rect_size = vec2(540.0, 960.0);
uniform float radius = 56.0;
void fragment() {
	vec2 p = UV * rect_size;
	vec2 q = abs(p - rect_size * 0.5) - (rect_size * 0.5 - vec2(radius));
	float d = length(max(q, vec2(0.0))) - radius;
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(-1.0, 1.0, d);
}
"""

func _ready() -> void:
	_screen = TextureRect.new()
	_screen.texture = texture
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader
	_screen.material = m
	add_child(_screen)
	_glass = _Glass.new()
	add_child(_glass)
	resized.connect(_layout)
	_layout()

## The screen, for mapping a point in the game onto the film.
func screen() -> TextureRect:
	return _screen

func _layout() -> void:
	var bezel: float = size.x * BEZEL
	_screen.position = Vector2(bezel, bezel)
	_screen.size = size - Vector2(bezel, bezel) * 2.0
	var r: float = size.x * RADIUS - bezel
	var m: ShaderMaterial = _screen.material as ShaderMaterial
	m.set_shader_parameter("rect_size", _screen.size)
	m.set_shader_parameter("radius", r)
	_glass.position = _screen.position
	_glass.size = _screen.size
	_glass.radius = r
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var dark: bool = Brand.INK.get_luminance() > 0.6
	var body_colour: Color = Color("1a1c22") if not dark else Color("252a44")
	var edge: Color = Color("5b5f6b") if not dark else Color("6d76a8")
	# Side keys first, so the body covers their inner edge: power on the right, volume on the left.
	var key: Color = edge.darkened(0.25)
	draw_rect(Rect2(w - 2.0, size.y * 0.22, 5.0, size.y * 0.09), key)
	draw_rect(Rect2(-3.0, size.y * 0.18, 5.0, size.y * 0.06), key)
	draw_rect(Rect2(-3.0, size.y * 0.26, 5.0, size.y * 0.06), key)
	var body: StyleBoxFlat = StyleBoxFlat.new()
	body.bg_color = body_colour
	body.set_corner_radius_all(int(w * RADIUS))
	body.corner_detail = 16
	body.border_color = edge
	body.set_border_width_all(3)
	body.shadow_color = Color(0, 0, 0, 0.32)
	body.shadow_size = int(w * 0.09)
	body.shadow_offset = Vector2(0, w * 0.05)
	body.anti_aliasing = true
	draw_style_box(body, Rect2(Vector2.ZERO, size))

## What sits on top of the screen: the camera hole and a faint diagonal sheen across the glass.
class _Glass extends Control:
	var radius: float = 40.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var hole: float = size.x * 0.034
		var at: Vector2 = Vector2(size.x * 0.5, hole * 1.6)
		draw_circle(at, hole, Color("0b0c10"), true, -1.0, true)
		draw_circle(at, hole * 0.45, Color("1c2233"), true, -1.0, true)
		var sheen: PackedVector2Array = PackedVector2Array([
			Vector2(size.x * 0.55, 0.0), Vector2(size.x * 0.78, 0.0),
			Vector2(size.x * 0.22, size.y), Vector2(0.0, size.y), Vector2(0.0, size.y * 0.72)])
		draw_colored_polygon(sheen, Color(1, 1, 1, 0.035))
