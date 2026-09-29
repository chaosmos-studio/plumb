class_name Spotlight
extends ColorRect

## A hint that cannot be missed: everything dims except soft circles around the answer. It never takes
## input, so the player taps the lit thing directly, and the game clears it when they act.

const FADE_IN: float = 0.28
const FADE_OUT: float = 0.2
const FEATHER: float = 46.0
const MAX_HOLES: int = 4

static var _shader: Shader = preload("res://kit/ui/spotlight.gdshader")

var _canvas: CanvasLayer

## `holes` are Vector3(x, y, radius) in viewport coordinates. Use
## `node.get_global_transform_with_canvas() * local_point` to get a world point there.
static func open(host: Node, holes: Array[Vector3]) -> Spotlight:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 30
	host.add_child(canvas)
	var s: Spotlight = Spotlight.new()
	s._canvas = canvas
	canvas.add_child(s)
	s.set_holes(holes)
	return s

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("scrim", Color(Brand.SCRIM, 0.58))
	m.set_shader_parameter("strength", 0.0)
	material = m

func _ready() -> void:
	resized.connect(func() -> void: (material as ShaderMaterial).set_shader_parameter("rect_size", size))
	(material as ShaderMaterial).set_shader_parameter("rect_size", size)
	create_tween().tween_method(_strength, 0.0, 1.0, FADE_IN)

func set_holes(holes: Array[Vector3]) -> void:
	var packed: Array[Vector4] = []
	for h: Vector3 in holes.slice(0, MAX_HOLES):
		packed.append(Vector4(h.x, h.y, h.z, FEATHER))
	while packed.size() < MAX_HOLES:
		packed.append(Vector4.ZERO)
	var m: ShaderMaterial = material as ShaderMaterial
	m.set_shader_parameter("holes", packed)
	m.set_shader_parameter("count", mini(holes.size(), MAX_HOLES))

func dismiss() -> void:
	var t: Tween = create_tween()
	t.tween_method(_strength, (material as ShaderMaterial).get_shader_parameter("strength"), 0.0, FADE_OUT)
	t.tween_callback(func() -> void:
		if is_instance_valid(_canvas):
			_canvas.queue_free())

func _strength(v: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("strength", v)
