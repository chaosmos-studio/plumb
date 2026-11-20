extends Node

## A short film of the tap wobble for Shravan to feel without a phone: the street map, then mouse clicks on the title,
## the sun, houses, trees and bushes, the cast and a cloud, each one drawn as a ring where the click lands. The clicks
## go through the engine's own input, as mouse clicks become touches in the game.
##
## Run: DISPLAY=:0 godot --path . --resolution 450x1000 --write-movie build/review/wobble.avi --fixed-fps 30
##      res://tools/wobble_demo.tscn
## then ffmpeg -i build/review/wobble.avi -c:v libx264 -pix_fmt yuv420p build/review/wobble.mp4

const GAP: float = 0.9
const START: float = 1.6

var _map: StreetMap
var _ring: _Ring

func _ready() -> void:
	Intro.enabled = false
	Save.path = "user://wobble_demo.cfg"
	Save.app_look = AppLook.STREET
	Save.look_chosen = true
	Save.tutorial_seen = true
	Save.look = ""
	GameLooks.use("classic")
	Save.stars = PackedByteArray([3, 3, 2, 3, 1, 3, 2, 3, 3, 2, 3])
	AppLook.use(AppLook.STREET)
	_map = (load(StreetMap.SCENE) as PackedScene).instantiate()
	add_child(_map)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ring = _Ring.new()
	layer.add_child(_ring)
	await _wait(START)
	print("WOBBLE_DEMO_START")
	# `-- scroll`: drag the street up several doors, so the houses travel down and out through the screen's foot,
	# then back again.
	if OS.get_cmdline_user_args().has("scroll"):
		var size: Vector2 = get_viewport().get_visible_rect().size
		for k: int in range(4):
			await _drag(Vector2(size.x * 0.5, size.y * 0.3), Vector2(size.x * 0.5, size.y * 0.75), 1.1)
			await _wait(0.5)
		for k: int in range(2):
			await _drag(Vector2(size.x * 0.5, size.y * 0.75), Vector2(size.x * 0.5, size.y * 0.25), 0.9)
			await _wait(0.5)
		await _wait(0.8)
		print("WOBBLE_DEMO_DONE")
		get_tree().quit()
		return
	for target: Callable in [_title, _sun, _tree, _house, _bush, _cast, _cast_other, _title, _door, _card, _card]:
		var at: Vector2 = target.call()
		print("WOBBLE_DEMO_CLICK ", target.get_method(), " ", at, " member ", (_map.get("_cast") as StreetCast).member_at(at),
			" busy ", _map.get("_busy"))
		if at.x < 0.0:
			continue
		_click(at)
		await _wait(GAP)
	await _wait(0.6)
	print("WOBBLE_DEMO_DONE")
	get_tree().quit()

## A mouse drag from `a` to `b` over `seconds`, in the game's design space, its ring following the pointer.
func _drag(a: Vector2, b: Vector2, seconds: float) -> void:
	var to_window: Transform2D = get_viewport().get_final_transform()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = to_window * a
	press.global_position = press.position
	Input.parse_input_event(press)
	var t: float = 0.0
	var last: Vector2 = a
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		var u: float = clampf(t / seconds, 0.0, 1.0)
		var at: Vector2 = a.lerp(b, u * u * (3.0 - 2.0 * u))
		_ring.show_at(at)
		var move: InputEventMouseMotion = InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		move.position = to_window * at
		move.global_position = move.position
		move.relative = to_window.basis_xform(at - last)
		Input.parse_input_event(move)
		last = at
	var lift: InputEventMouseButton = InputEventMouseButton.new()
	lift.button_index = MOUSE_BUTTON_LEFT
	lift.pressed = false
	lift.position = to_window * b
	lift.global_position = lift.position
	Input.parse_input_event(lift)

## Waits by counting frames, so the film's timing holds in the movie writer's fixed frame rate too.
func _wait(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()

## A mouse click at a point in the game's design space.
func _click(at: Vector2) -> void:
	_ring.show_at(at)
	var window: Vector2 = get_viewport().get_final_transform() * at
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = window
		click.global_position = window
		Input.parse_input_event(click)

func _on_screen(item: CanvasItem, offset: Vector2 = Vector2.ZERO) -> Vector2:
	return item.get_global_transform_with_canvas() * offset

func _title() -> Vector2:
	return _on_screen(_map.get("_title"))

func _sun() -> Vector2:
	var size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(size.x * StreetSky.SUN_AT.x, size.y * StreetSky.SUN_AT.y + StreetArt.size("sun").y * 0.5 * StreetSky.SUN_SCALE)

## The nearest visible prop of `kind` whose middle is on screen, or one of the door's houses.
func _prop(kind: int, rank: int = 0) -> Vector2:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var found: Array[StreetProp] = []
	for child: Node in (_map.get("_props") as Node2D).get_children():
		var prop: StreetProp = child as StreetProp
		if prop == null or not prop.visible or prop.kind != kind or prop.modulate.a < 0.9 or prop.z_index < 0:
			continue
		var mid: Vector2 = _on_screen(prop, prop.bounds().get_center())
		if mid.x > 60.0 and mid.x < size.x - 60.0 and mid.y > 300.0 and mid.y < size.y - 260.0:
			found.append(prop)
	found.sort_custom(func(a: StreetProp, b: StreetProp) -> bool: return a.position.y > b.position.y)
	# Only one the click would reach: nothing standing in front of it at that point.
	var reachable: Array[Vector2] = []
	for prop: StreetProp in found:
		var at: Vector2 = _on_screen(prop, prop.bounds().get_center() + Vector2(0.0, prop.bounds().size.y * 0.15))
		if _front_at(at) == prop:
			reachable.append(at)
	return reachable[rank] if reachable.size() > rank else Vector2(-1, -1)

## The prop a click at `at` reaches: the front-most one under it, as the map decides.
func _front_at(at: Vector2) -> StreetProp:
	var hit: StreetProp = null
	for child: Node in (_map.get("_props") as Node2D).get_children():
		var item: StreetProp = child as StreetProp
		if item == null or not item.visible or item.z_index < 0 or item.kind == StreetPath.Kind.NONE \
				or item.modulate.a < 0.5:
			continue
		var local: Vector2 = (at - item.position) / item.scale.y
		if item.bounds().has_point(local) and (hit == null or item.position.y > hit.position.y):
			hit = item
	return hit

## The door to play next: a click there drops its start card.
func _door() -> Vector2:
	for child: Node in (_map.get("_props") as Node2D).get_children():
		var prop: StreetProp = child as StreetProp
		if prop != null and prop.visible and prop.kind == StreetProp.HOUSE and prop.state == StreetProp.Door.CURRENT:
			var d: Vector3 = StreetArt.door(StreetArt.house_of(prop.door)) * StreetProp.HOUSE_SCALE
			return _on_screen(prop, Vector2(d.x, d.y))
	return Vector2(-1, -1)

## The start card's middle, once it has dropped: a click sets it swinging.
func _card() -> Vector2:
	var size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(size.x * 0.68, size.y * 0.42)

func _house() -> Vector2:
	return _prop(StreetProp.HOUSE, 1)

func _tree() -> Vector2:
	return _prop(StreetPath.Kind.TREE)

func _bush() -> Vector2:
	return _prop(StreetPath.Kind.BUSH)

func _cast() -> Vector2:
	var cast: StreetCast = _map.get("_cast")
	return _on_screen(cast, Vector2(-StreetCast.body_width() * 0.55, -StreetCast.body_width() * 0.5))

func _cast_other() -> Vector2:
	var cast: StreetCast = _map.get("_cast")
	return _on_screen(cast, Vector2(StreetCast.body_width() * 1.6, -StreetCast.body_width() * 0.5))


## A ring that shows where a click landed, fading out.
class _Ring extends Node2D:
	var _left: float = 0.0

	func show_at(at: Vector2) -> void:
		position = at
		_left = 0.45
		queue_redraw()

	func _process(delta: float) -> void:
		if _left > 0.0:
			_left -= delta
			queue_redraw()

	func _draw() -> void:
		if _left <= 0.0:
			return
		var a: float = clampf(_left / 0.45, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 34.0 + (1.0 - a) * 26.0, Color(1, 1, 1, 0.9 * a), false, 6.0, true)
		draw_circle(Vector2.ZERO, 10.0, Color(1, 1, 1, 0.8 * a), true, -1.0, true)
