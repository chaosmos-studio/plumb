class_name Device
extends Control

## A phone around the game, for landscape films: a dark bezel with rounded corners and a soft shadow.
## The game's texture is drawn inside it, clipped to the rounded screen.

var texture: Texture2D
var bezel: float = 18.0
var radius: float = 64.0
var _shader: Shader

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

var _screen: TextureRect

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
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	_screen.position = Vector2(bezel, bezel)
	_screen.size = size - Vector2(bezel, bezel) * 2.0
	var m: ShaderMaterial = _screen.material as ShaderMaterial
	m.set_shader_parameter("rect_size", _screen.size)
	m.set_shader_parameter("radius", radius - bezel * 0.6)
	queue_redraw()

func _draw() -> void:
	var body: StyleBoxFlat = StyleBoxFlat.new()
	body.bg_color = Color("16181e") if not Brand.INK.get_luminance() > 0.6 else Color("2b3150")
	body.set_corner_radius_all(int(radius))
	body.shadow_color = Color(0, 0, 0, 0.28)
	body.shadow_size = 40
	body.shadow_offset = Vector2(0, 24)
	body.anti_aliasing = true
	draw_style_box(body, Rect2(Vector2.ZERO, size))
