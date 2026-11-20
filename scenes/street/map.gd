extends Node2D

## Street's Home: the rolling street (REVAMP_PLAN.md section 3, MATH.md section 25). M1 is the spike: the projection,
## the ground, stand-in houses and scenery, the cast at the current door, drag and fling, and a frame probe. A build
## with the street_spike feature, or a run with `-- --auto-scroll`, plays a scripted scroll and logs its frames.

## The drum: its radius and the camera's focal length, in design pixels (StreetProjection). A smaller radius is a
## tighter little world, and a very large one a flat scroll.
const RADIUS: float = 1150.0
const FOCAL: float = 900.0
## The drum's near edge sits this far below the screen's foot.
const NEAR_BELOW: float = 60.0
## How far a point sinks toward the sides, per pixel squared across: the street reads as a small planet.
const BOW: float = 0.00022
## The ground's mesh: rows evenly down the screen, columns across.
const ROWS: int = 72
const COLUMNS: int = 28
## Where the current door rests, as a share of the screen's height from the top.
const REST_AT: float = 0.7
## A fling dies away by this rate a second, and a drag past either end follows the finger by this share.
const FRICTION: float = 2.6
const RUBBER: float = 0.35
## How fast the street settles back inside its ends, a second.
const SPRING: float = 9.0
## A finger's speed is averaged over about this long, in seconds.
const VELOCITY_SMOOTHING: float = 0.05
## Stand-ins for M1: the door to play next and the last door the street runs to.
const CURRENT_DOOR: int = 12
const LAST_DOOR: int = 5000
## The cast stands this far in front of the current door, spread across the road.
const CAST_BEFORE: float = 70.0
const CAST_SPREAD: float = 46.0
const CAST_RADIUS: float = 30.0
## The scripted scroll: the fling speed, the steady speed, in strip pixels a second, and the door it starts from, far
## enough along that no fling reaches either end.
const AUTO_FLING: float = 3400.0
const AUTO_STEADY: float = 950.0
const AUTO_DOOR: int = 300
## How many rounds the measuring run plays, and how many flings each way in each stretch.
const AUTO_ROUNDS: int = 3
const AUTO_FLINGS: int = 2

const SKY_SHADER: String = """
shader_type canvas_item;
uniform vec4 top : source_color = vec4(0.16, 0.56, 0.94, 1.0);
uniform vec4 low : source_color = vec4(0.73, 0.89, 0.99, 1.0);
uniform float horizon = 0.25;
void fragment() {
	COLOR = vec4(mix(top.rgb, low.rgb, smoothstep(0.0, horizon + 0.08, UV.y)), 1.0);
}
"""

var _proj: StreetProjection
var _scroll: float = 0.0
var _velocity: float = 0.0
var _steady: float = 0.0
var _bounds: Vector2 = Vector2.ZERO
var _sky: ColorRect
var _ground: MeshInstance2D
var _ground_material: ShaderMaterial
var _props: Node2D
var _houses: Dictionary = {}
var _scenery: Dictionary = {}
var _pool: Array[StreetProp] = []
var _cast: Array[Marble] = []
var _dragging: bool = false
var _grab_s: float = 0.0
var _last_drag_us: int = 0
var _probe: FrameProbe
var _readout: Label
var _readout_at: float = 0.0
## Set once the atlas is baked: nothing is placed before.
var _built: bool = false
## The measuring run's second pass leaves the cast out.
var _cast_hidden: bool = false
## The door to play next: CURRENT_DOOR, or AUTO_DOOR while measuring.
var _current: int = CURRENT_DOOR

func _ready() -> void:
	_sky = ColorRect.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sky_shader: Shader = Shader.new()
	sky_shader.code = SKY_SHADER
	var sky_material: ShaderMaterial = ShaderMaterial.new()
	sky_material.shader = sky_shader
	_sky.material = sky_material
	_sky.z_index = -10
	add_child(_sky)
	_ground = MeshInstance2D.new()
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = load("res://scenes/street/ground.gdshader")
	_ground.material = _ground_material
	add_child(_ground)
	_props = Node2D.new()
	_props.y_sort_enabled = true
	_props.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_props)
	for who: int in range(4):
		var marble: Marble = Marble.new()
		marble.radius = CAST_RADIUS
		marble.colour = Palette.marble(who)
		marble.who = who
		_props.add_child(marble)
		_cast.append(marble)
	_probe = FrameProbe.new()
	add_child(_probe)
	if OS.is_debug_build():
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		_readout = Label.new()
		_readout.position = Vector2(24, 60)
		_readout.add_theme_font_size_override("font_size", 22)
		_readout.add_theme_color_override("font_color", Color(0.1, 0.12, 0.2, 0.8))
		layer.add_child(_readout)
	_set_ground_uniforms()
	get_viewport().size_changed.connect(_layout)
	_layout()
	var measuring: bool = OS.has_feature("street_spike") or OS.get_cmdline_user_args().has("--auto-scroll")
	_current = AUTO_DOOR if measuring else CURRENT_DOOR
	_scroll = _scroll_for(_current)
	await StreetAtlas.bake(self)
	_built = true
	_place()
	if measuring:
		_auto_scroll()

func _layout() -> void:
	var size: Vector2 = get_viewport_rect().size
	_sky.size = size
	_proj = StreetProjection.new(RADIUS, FOCAL, size.y + NEAR_BELOW, size.x * 0.5, BOW)
	(_sky.material as ShaderMaterial).set_shader_parameter("horizon", clampf(_proj.horizon_y() / size.y, 0.0, 1.0))
	_ground.mesh = _ground_mesh(size)
	_ground_material.set_shader_parameter("radius", RADIUS)
	_bounds = Vector2(_scroll_for(1), _scroll_for(LAST_DOOR))

## The scroll that rests door `n` at REST_AT.
func _scroll_for(n: int) -> float:
	return StreetPath.door_s(n) - _proj.s_rel_at(get_viewport_rect().size.y * REST_AT)

## The ground never moves: its rows run evenly down the screen from below the foot to the horizon, each projected
## once, and the shader paints the strip under it from `scroll`.
func _ground_mesh(size: Vector2) -> ArrayMesh:
	var bottom: float = size.y + 40.0
	var top: float = maxf(_proj.horizon_y(), -40.0)
	var top_s: float = _proj.s_rel_at(top) if _proj.horizon_y() < -40.0 else RADIUS * PI * 0.5
	var far_k: float = _proj.scale_at(top_s / RADIUS)
	var half_width: float = (size.x * 0.5 + 120.0) / far_k
	var vertices: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for row: int in range(ROWS + 1):
		var y: float = lerpf(bottom, top, float(row) / float(ROWS))
		var s_rel: float = top_s if row == ROWS else RADIUS * asin(clampf((_proj.near_y - y) / RADIUS, -1.0, 1.0))
		for column: int in range(COLUMNS + 1):
			var x: float = lerpf(-half_width, half_width, float(column) / float(COLUMNS))
			var at: Vector3 = _proj.place(s_rel, x)
			vertices.append(Vector2(at.x, at.y))
			uvs.append(Vector2(s_rel, x))
	var indices: PackedInt32Array = PackedInt32Array()
	for row: int in range(ROWS):
		for column: int in range(COLUMNS):
			var a: int = row * (COLUMNS + 1) + column
			var b: int = a + COLUMNS + 1
			indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh

func _set_ground_uniforms() -> void:
	_ground_material.set_shader_parameter("sway_a", StreetPath.SWAY_A)
	_ground_material.set_shader_parameter("sway_a_length", StreetPath.SWAY_A_LENGTH)
	_ground_material.set_shader_parameter("sway_b", StreetPath.SWAY_B)
	_ground_material.set_shader_parameter("sway_b_length", StreetPath.SWAY_B_LENGTH)
	_ground_material.set_shader_parameter("sway_b_phase", StreetPath.SWAY_B_PHASE)
	_ground_material.set_shader_parameter("road_half", StreetPath.ROAD_HALF)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		_dragging = touch.pressed
		if touch.pressed:
			_steady = 0.0
			_velocity = 0.0
			_grab_s = _scroll + _proj.s_rel_at(touch.position.y)
			_last_drag_us = Time.get_ticks_usec()
	elif event is InputEventScreenDrag and _dragging:
		var drag: InputEventScreenDrag = event
		var want: float = _grab_s - _proj.s_rel_at(drag.position.y)
		var now: int = Time.get_ticks_usec()
		var dt: float = maxf(float(now - _last_drag_us) / 1000000.0, 0.001)
		_last_drag_us = now
		var next: float = _rubber(want)
		var weight: float = 1.0 - exp(-dt / VELOCITY_SMOOTHING)
		_velocity = lerpf(_velocity, (next - _scroll) / dt, weight)
		_scroll = next

## A scroll past either end follows the finger only by RUBBER.
func _rubber(want: float) -> float:
	if want < _bounds.x:
		return _bounds.x + (want - _bounds.x) * RUBBER
	if want > _bounds.y:
		return _bounds.y + (want - _bounds.y) * RUBBER
	return want

func _process(delta: float) -> void:
	if not _built:
		return
	var started_us: int = Time.get_ticks_usec()
	if not _dragging:
		if _steady != 0.0:
			_scroll += _steady * delta
		else:
			_scroll += _velocity * delta
			_velocity *= exp(-FRICTION * delta)
		var inside: float = clampf(_scroll, _bounds.x, _bounds.y)
		if inside != _scroll:
			_scroll = lerpf(_scroll, inside, 1.0 - exp(-SPRING * delta))
			_velocity *= exp(-SPRING * delta)
	_place()
	_probe.note(float(Time.get_ticks_usec() - started_us) / 1000.0)
	if _readout != null:
		_readout_at -= delta
		if _readout_at <= 0.0:
			_readout_at = 0.25
			_readout.text = "%d fps  %d draws  door %d" % [Engine.get_frames_per_second(),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				StreetPath.door_near(_scroll + _proj.s_rel_at(get_viewport_rect().size.y * REST_AT))]

## Puts everything in view where the drum shows it, recycling what has left the view.
func _place() -> void:
	var size: Vector2 = get_viewport_rect().size
	_ground_material.set_shader_parameter("scroll", _scroll)
	var near: float = _scroll + _proj.near_s_rel(size.y)
	var far: float = _scroll + _proj.far_s_rel(0.0)
	var first: int = clampi(StreetPath.door_near(near) - 1, 1, LAST_DOOR)
	var last: int = clampi(StreetPath.door_near(far) + 1, 1, LAST_DOOR)
	for n: Variant in _houses.keys():
		var door: int = n
		var at_s: float = StreetPath.door_s(door)
		if door < first or door > last or at_s < near or at_s > far:
			_recycle(_houses[door])
			_houses.erase(door)
	for door: int in range(first, last + 1):
		var s: float = StreetPath.door_s(door)
		if s < near or s > far:
			continue
		var house: StreetProp = _houses.get(door, null)
		if house == null:
			house = _take()
			house.dress_house(door, _state(door), 1 + StreetPath.mix(door) % 3)
			_houses[door] = house
		_stand(house, s, StreetPath.door_x(door))
	var from_slot: int = floori(near / StreetPath.SLOT_GAP)
	var to_slot: int = ceili(far / StreetPath.SLOT_GAP)
	for key: Variant in _scenery.keys():
		var slot: Vector2i = key
		if slot.x < from_slot or slot.x > to_slot:
			_recycle(_scenery[slot])
			_scenery.erase(slot)
	for slot: int in range(maxi(from_slot, 0), to_slot + 1):
		for side: int in [-1, 1]:
			var spot: Vector2 = StreetPath.scenery(slot, side)
			if int(spot.x) == StreetPath.Kind.NONE:
				continue
			var key: Vector2i = Vector2i(slot, side)
			var prop: StreetProp = _scenery.get(key, null)
			if prop == null:
				prop = _take()
				prop.dress_scenery(int(spot.x), StreetPath.mix(slot * 7 + side))
				_scenery[key] = prop
			_stand(prop, StreetPath.slot_s(slot), spot.y)
	var door_s: float = StreetPath.door_s(_current) - CAST_BEFORE
	for who: int in range(_cast.size()):
		var marble: Marble = _cast[who]
		var x: float = StreetPath.road_x(door_s) + (float(who) - 1.5) * CAST_SPREAD
		var at: Vector3 = _proj.place(door_s - _scroll, x)
		marble.visible = not _cast_hidden and door_s > near and door_s < far and not _proj.behind_crest(door_s - _scroll)
		marble.position = Vector2(at.x, at.y - CAST_RADIUS * at.z)
		marble.scale = Vector2(at.z, at.z)

## Behind the crest a prop is drawn before the ground, which hides its foot, so it rises over the horizon.
func _stand(prop: StreetProp, s: float, x: float) -> void:
	var at: Vector3 = _proj.place(s - _scroll, x)
	prop.position = Vector2(at.x, at.y)
	prop.scale = Vector2(at.z, at.z)
	prop.z_index = -1 if _proj.behind_crest(s - _scroll) else 0

func _state(door: int) -> StreetProp.Door:
	if door < _current:
		return StreetProp.Door.SOLVED
	if door == _current:
		return StreetProp.Door.CURRENT
	return StreetProp.Door.LOCKED if door <= _current + 3 else StreetProp.Door.FAR

func _take() -> StreetProp:
	if not _pool.is_empty():
		var prop: StreetProp = _pool.pop_back()
		prop.visible = true
		return prop
	var made: StreetProp = StreetProp.new()
	_props.add_child(made)
	return made

func _recycle(prop: StreetProp) -> void:
	prop.visible = false
	_pool.append(prop)

## The scripted scroll for measuring: flings both ways, a steady roll both ways, then a rest, each logged. It runs with
## the cast and again without, since the cast's marbles cost far more draw calls than the street. Android keeps vsync
## on whatever the game asks, so the room left is read from the phone's own CPU load instead.
func _auto_scroll() -> void:
	print("STREET_DEVICE %s" % JSON.stringify({"adapter": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(), "screen": DisplayServer.screen_get_size(),
		"viewport": get_viewport_rect().size, "refresh_hz": DisplayServer.screen_get_refresh_rate()}))
	_scroll = _scroll_for(AUTO_DOOR)
	await get_tree().create_timer(2.5).timeout
	# Rounds alternate with and without the cast, so anything that drifts with time, such as the phone's clocks or
	# its other apps, weighs on both alike.
	for round: int in range(AUTO_ROUNDS):
		for cast: bool in [true, false]:
			_cast_hidden = not cast
			for marble: Marble in _cast:
				marble.process_mode = Node.PROCESS_MODE_INHERIT if cast else Node.PROCESS_MODE_DISABLED
			await _auto_pass(("_cast_" if cast else "_street_") + str(round + 1))
	_cast_hidden = false
	for marble: Marble in _cast:
		marble.process_mode = Node.PROCESS_MODE_INHERIT
	print("STREET_AUTO_DONE")

func _auto_pass(suffix: String) -> void:
	_begin("fling" + suffix)
	for i: int in range(AUTO_FLINGS):
		_velocity = AUTO_FLING
		await get_tree().create_timer(2.2).timeout
		_velocity = -AUTO_FLING
		await get_tree().create_timer(2.2).timeout
	_probe.end()
	_begin("steady" + suffix)
	_steady = AUTO_STEADY
	await get_tree().create_timer(4.0).timeout
	_steady = -AUTO_STEADY
	await get_tree().create_timer(4.0).timeout
	_steady = 0.0
	_velocity = 0.0
	_probe.end()
	_begin("rest" + suffix)
	await get_tree().create_timer(3.0).timeout
	_probe.end()
	_scroll = _scroll_for(AUTO_DOOR)

## The marker lets a host reading the log time its own measurements, such as SurfaceFlinger's frame times.
func _begin(label: String) -> void:
	print("STREET_BEGIN %s" % label)
	_probe.begin(label)
