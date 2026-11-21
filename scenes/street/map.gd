class_name StreetMap
extends Node2D

## Street's Home: the rolling street, one house a level (REVAMP_PLAN.md section 3, MATH.md section 25). The lit door is
## the level to play next. A tap on it, or on a solved door, drops in its start card. After a win the cast walks on
## to the next door and its card drops in by itself. In a debug build, a run with `-- --auto-scroll`, or the file
## user://measure_street, plays a scripted scroll and logs its frames instead.

## The street rolls like a little round world, as Candy Crush Saga's map does (Shravan, 21 November): houses come up
## over the horizon, grow as they travel down the screen and leave through its foot (MATH.md section 25). The drum's
## radius is chosen per screen (`_radius_for`), as large as it can be while the horizon stays low enough that the PLUMB
## title above it only ever has blue sky behind it: nothing on the street, not even the tallest house at the crest or
## the hills, reaches within TITLE_CLEAR of the title's foot. Reduce motion flattens it.
const FLAT_RADIUS: float = 100000.0
const FOCAL: float = 700.0
## The camera's tilt down at the street: each door up the screen is drawn a steady share smaller than the one below.
const TILT: float = 0.0
const TITLE_CLEAR: float = 16.0
## The tallest thing on the street at its near-edge size (the windmill on its plot), and how far the hills rise above
## the horizon.
const TALLEST: float = 520.0
const HILLS_RISE: float = 75.0
## The radius is searched between these, in design units.
const RADIUS_RANGE: Vector2 = Vector2(500.0, 4000.0)
## At rest the door below the current one shows its number just clear of the bottom buttons: its base sits this far
## above their top. On a wide screen, with the buttons down the side, it sits this far above the screen's foot.
const PREV_CLEAR: float = 4.0
const WIDE_PREV_CLEAR: float = 150.0
## The street's near edge sits this far below the screen's foot.
const NEAR_BELOW: float = 60.0
## How far a point sinks toward the sides, per pixel squared across, a gentle curve so the street reads as a hill. It
## is set for a 720-wide world, and a wider one bends less, so the screen's edges always sink the same.
const BOW: float = 0.00012
## On a wide screen the street is a world this tall (the portrait phone's design height the concepts were drawn for),
## scaled to fit the screen's height, so it composes as the portrait street does, horizon and all, with more of the
## meadow either side (StreetLayout).
const WIDE_WORLD_HEIGHT: float = 1400.0
## The ground's mesh: rows evenly down the screen, columns across.
const ROWS: int = 72
const COLUMNS: int = 28
## A fling dies away by this rate a second, and a drag past either end follows the finger by this share.
const FRICTION: float = 2.6
const RUBBER: float = 0.35
## How fast the street settles back inside its ends, a second.
const SPRING: float = 9.0
## A finger's speed is averaged over about this long, in seconds.
const VELOCITY_SMOOTHING: float = 0.05
## A touch that moves less than this, in pixels, and lifts within this long, in seconds, is a tap.
const TAP_SLOP: float = 14.0
const TAP_TIME: float = 0.4
## A notch of the mouse wheel flings the street at this speed, in strip pixels a second.
const WHEEL_SPEED: float = 900.0
## The cast stands this far in front of the current door, along the street.
const CAST_BEFORE: float = 80.0
## How far from the road's middle toward the door it waits at the cast stands.
const CAST_TOWARD_DOOR: float = 0.35
## After a win: the cast's walk to the next door, and the pause before its card drops in.
const WALK_TIME: float = 1.3
const CARD_DELAY: float = 0.35
## Doors after the current one that show their number. Further ones show a padlock. How many show at all is what fits
## under the title at rest.
const NUMBERED_AHEAD: int = 3
## The street can be scrolled this many doors past the current one, to see what is coming.
const AHEAD: int = 6
## The street has no end (the picker keeps finding boards): a door number no one reaches bounds the arithmetic.
const LAST_DOOR: int = 99999
## The bottom row of buttons: their size, and their distance from the screen's foot.
const BUTTON: float = 132.0
const BUTTON_LIFT: float = 54.0
## The PLUMB title's top below the safe area, and its width.
const TITLE_TOP: float = 100.0
const TITLE_WIDTH: float = 470.0
## A round "back home" button shows once the current door is this far off screen, in design pixels.
const PIN_AFTER: float = 140.0
## The coin pill's distance from the screen's top-right corner.
const COINS_EDGE: float = 18.0
## The finish ribbon stands across the front of its milestone's plot, this far nearer along the street, as the
## concept stands it before the new house, and breaks as the cast walks past after the win. Its halves fly apart this
## far, in design pixels.
const RIBBON_BEFORE: float = 34.0
const RIBBON_FLY: float = 260.0
## The scripted scroll: the fling speed, the steady speed, in strip pixels a second, the door it starts from, the rounds
## it plays and the flings each way in each stretch.
const AUTO_FLING: float = 3400.0
const AUTO_STEADY: float = 950.0
const AUTO_DOOR: int = 300
const AUTO_ROUNDS: int = 3
const AUTO_FLINGS: int = 2
const MEASURE_FLAG: String = "user://measure_street"
const SCENE: String = AppLook.MAP_SCENE

## The door just won, set by the play screen before it comes back here, or 0.
static var arrival: int = 0
## A door whose parcel or milestone the win just earned, opened once the cast has walked on, or 0.
static var gift_door: int = 0
## Set while the look chooser makes its live preview: no buttons, card, banner or intro, and a gentle roll on its own.
static var preview: bool = false
## The same, on the one map it was made for. The chooser builds its cards before they are in the tree, so the map's
## _ready ran after `preview` was set back, and the preview showed the banner over the chooser.
var preview_only: bool = false
## How far the preview rolls each way from the current door, in strip pixels, and how fast.
const PREVIEW_ROLL: float = 300.0
const PREVIEW_SPEED: float = 0.4

var _proj: StreetProjection
var _scroll: float = 0.0
var _velocity: float = 0.0
var _steady: float = 0.0
var _bounds: Vector2 = Vector2.ZERO
var _sky: StreetSky
var _ground: MeshInstance2D
var _ground_material: ShaderMaterial
var _props: Node2D
var _houses: Dictionary = {}
var _scenery: Dictionary = {}
## The finish ribbons in view, by the milestone door they stand before.
var _ribbons: Dictionary = {}
var _coins: StreetCoinPill
var _pool: Array[StreetProp] = []
var _cast: StreetCast
## Where the cast stands along the street, and the door to play next.
var _cast_s: float = 0.0
var _current: int = 1
var _last: int = 1
var _dragging: bool = false
var _grab_s: float = 0.0
var _last_drag_us: int = 0
var _press_at: Vector2 = Vector2.ZERO
var _press_us: int = 0
var _moved: bool = false
var _busy: bool = false
var _card: StreetDoorCard
var _hud: CanvasLayer
var _buttons: BoxContainer
var _pin: StreetUI.RoundButton
var _banner_room: float = 0.0
var _probe: FrameProbe
var _time: float = 0.0
var _measuring: bool = false
var _cast_hidden: bool = false
var _preview: bool = false
## Bands of meadow scenery beyond the street's own, as many as the world's width needs.
var _far_bands: int = 0
## Props whose tap wobble is still moving.
var _wobbling: Array[StreetProp] = []
## The scroll at which the current door rests, and the drum's radius for this screen.
var _rest: float = 0.0
var _drum_radius: float = FLAT_RADIUS
## The title in the sky, and what wobbles it and the buttons' neighbours.
var _title: StreetTitle
var _wobbler: StreetWobbler

func _ready() -> void:
	_preview = preview or preview_only
	Palette.use_street()
	Pack.use(Pack.Section.MAIN)
	_last = LAST_DOOR
	_current = Street.current()
	_measuring = OS.is_debug_build() and (OS.get_cmdline_user_args().has("--auto-scroll")
		or FileAccess.file_exists(MEASURE_FLAG))
	if _measuring:
		_current = AUTO_DOOR
	_sky = StreetSky.new()
	_sky.z_index = -10
	add_child(_sky)
	_ground = MeshInstance2D.new()
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = load("res://scenes/street/ground.gdshader")
	_ground_material.set_shader_parameter("grass", load("res://assets/street/grass.png"))
	_ground_material.set_shader_parameter("road", load("res://assets/street/road.png"))
	_ground.material = _ground_material
	add_child(_ground)
	_props = Node2D.new()
	_props.y_sort_enabled = true
	_props.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_props)
	_cast = StreetCast.new()
	_props.add_child(_cast)
	_probe = FrameProbe.new()
	add_child(_probe)
	_set_ground_uniforms()
	if not _preview:
		_build_hud()
	get_viewport().size_changed.connect(_layout)
	EventBus.settings_changed.connect(_layout)
	_layout()
	_cast_s = StreetPath.door_s(_current) - CAST_BEFORE
	_scroll = _scroll_for(_current)
	var walked_from: int = arrival
	arrival = 0
	var gift: int = gift_door if gift_door > 0 else _unclaimed()
	gift_door = 0
	# A parcel or milestone due after the walk: its pieces and backdrop load on a thread while the cast walks.
	if gift > 0 and not _preview:
		StreetArt.prefetch_page(StreetArt.TOWN)
		StreetArt.prefetch_backdrop(StreetArt.WIN_BACKDROP if StreetRewards.is_milestone(gift)
			else StreetArt.GIFT_BACKDROP, StreetLayout.wide(get_viewport_rect().size))
	if walked_from > 0 and walked_from + 1 == _current and not _measuring:
		_cast_s = StreetPath.door_s(walked_from) - CAST_BEFORE
		_scroll = _scroll_for(walked_from)
	_place()
	if _preview:
		return
	Intro.play(self)
	if not _measuring:
		Ads.show_banner(self, _on_banner)
		# The day's puzzle, solved, pays its coins on the way back here, counted up on the pill.
		if Daily.is_open() and Save.pay_daily(Daily.today(), Daily.solved(Daily.today())):
			Audio.play(&"clink", -6.0)
	if _measuring:
		_auto_scroll()
	elif walked_from > 0 and walked_from + 1 == _current:
		_walk_on(gift)
	elif gift > 0:
		_busy = true
		await get_tree().create_timer(0.4).timeout
		await _open_gift(gift)
		_busy = false

## Leaving the street lets the town's page go (the families' houses, the plots and the moments' pieces), since play
## never draws from it; the street loads it again when a milestone next comes into view.
func _exit_tree() -> void:
	StreetArt.release(StreetArt.TOWN)

## The world's scale on screen: 1 in portrait, and on a wide screen the share that fits WIDE_WORLD_HEIGHT in.
func _world_scale() -> float:
	var size: Vector2 = get_viewport_rect().size
	return size.y / WIDE_WORLD_HEIGHT if StreetLayout.wide(size) else 1.0

## The world's size, in world units: the screen's size undone by the world's scale.
func _world_size() -> Vector2:
	return get_viewport_rect().size / _world_scale()

## The drum's radius for this screen (see FOCAL): the largest that keeps the title's sky clear.
func _radius() -> float:
	return _drum_radius

## A drum of radius `r` for a world of `size`, its tilt set and its gain making the door at rest its painted size.
func _drum(r: float, size: Vector2, bow: float) -> StreetProjection:
	var proj: StreetProjection = StreetProjection.new(r, FOCAL, size.y + NEAR_BELOW, size.x * 0.5, bow)
	if r < FLAT_RADIUS:
		proj.tilt = TILT
		proj.normalise_at(proj.s_rel_at(_prev_y()) + StreetPath.DOOR_GAP)
	return proj

## The largest radius whose horizon sits low enough that the hills, and the tallest house at the crest, stay under the
## title's foot, found by halving the range: a larger radius always raises the horizon.
func _radius_for(size: Vector2, bow: float) -> float:
	var ceiling: float = _title_box().end.y / _world_scale() + TITLE_CLEAR
	var low: float = RADIUS_RANGE.x
	var high: float = RADIUS_RANGE.y
	for i: int in range(24):
		var r: float = (low + high) * 0.5
		var proj: StreetProjection = _drum(r, size, bow)
		var rise: float = maxf(HILLS_RISE, TALLEST * proj.scale_at(PI * 0.5))
		if proj.horizon_y() - rise >= ceiling:
			low = r
		else:
			high = r
	return low

func _layout() -> void:
	# A street at rest stays at rest through a new layout (a banner, a turn, Reduce motion), on its new resting place.
	var resting: bool = absf(_scroll - _rest) < 1.0 and _proj != null
	var size: Vector2 = _world_size()
	scale = Vector2.ONE * _world_scale()
	# Reduce motion keeps the street dead flat, with no curve toward the sides.
	var bow: float = 0.0 if Save.reduce_motion else \
		(BOW * pow(StreetLayout.SHORT / size.x, 2.0) if size.x > StreetLayout.SHORT else BOW)
	_drum_radius = FLAT_RADIUS if Save.reduce_motion else _radius_for(size, bow)
	_proj = _drum(_drum_radius, size, bow)
	_sky.horizon_y = _proj.horizon_y() if not Save.reduce_motion else _title_box().end.y / scale.y + TITLE_CLEAR + HILLS_RISE
	_sky.area = size
	_sky.clear_bottom = _title_box().end.y / scale.y
	_ground.mesh = _ground_mesh(size)
	_ground_material.set_shader_parameter("radius", _radius())
	# Bands of meadow scenery out to the screen's edges, as many as its width needs.
	_far_bands = maxi(0, ceili((size.x * 0.5 + 60.0 - StreetPath.SCENERY_SET.y) / StreetPath.FAR_BAND))
	for key: Variant in _scenery.keys():
		_recycle(_scenery[key])
	_scenery.clear()
	for n: Variant in _houses.keys():
		_recycle(_houses[n])
	_houses.clear()
	for n: Variant in _ribbons.keys():
		_recycle(_ribbons[n])
	_ribbons.clear()
	_rest = _scroll_for(_current)
	_bounds = Vector2(_scroll_for(1), _scroll_for(_far_door()))
	if resting and not _busy and not _measuring:
		_scroll = _rest
	if _buttons != null:
		_place_hud()

## The world height the door below the current one stands at when the street is at rest: its base just above the
## bottom buttons, so its number shows clear of them.
func _prev_y() -> float:
	var screen: Vector2 = get_viewport_rect().size
	var safe: Dictionary = UI.safe_margins(get_viewport())
	if StreetLayout.wide(screen):
		return (screen.y - float(safe["bottom"])) / _world_scale() - WIDE_PREV_CLEAR
	return screen.y - float(safe["bottom"]) - BUTTON_LIFT - BUTTON - _banner_room - PREV_CLEAR

## How far along the strip the door at rest stands from the near edge: one door further than the one below it.
func _rest_s_rel() -> float:
	return _proj.s_rel_at(_prev_y()) + StreetPath.DOOR_GAP

## The scroll that rests door `n`.
func _scroll_for(n: int) -> float:
	return StreetPath.door_s(n) - _rest_s_rel()

## The title's box on screen, where StreetTitle puts it.
func _title_box() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	var top: float = float(UI.safe_margins(get_viewport())["top"])
	var wide: bool = StreetLayout.wide(screen)
	# Wide, the title sits in the sky's top-left corner, clear of the street and the buttons.
	var across: float = screen.y * 1.1 if wide else screen.x
	var width: float = minf(TITLE_WIDTH * (0.8 if wide else 1.0), across * 0.84)
	var height: float = StreetArt.size("title_plumb").y * width / StreetArt.size("title_plumb").x
	return Rect2(Vector2(across * 0.5 - width * 0.5, top + (24.0 if wide else TITLE_TOP)), Vector2(width, height))

## The ground never moves: its rows run evenly down the screen from below the foot to the horizon, each projected
## once, and the shader paints the strip under it from `scroll`.
func _ground_mesh(size: Vector2) -> ArrayMesh:
	var bottom: float = size.y + 40.0
	var radius: float = _radius()
	var top: float = maxf(_proj.horizon_y(), -40.0)
	var top_s: float = _proj.s_rel_at(top) if _proj.horizon_y() < -40.0 else radius * PI * 0.5
	if Save.reduce_motion:
		# Flat, the ground runs to the sky line under the title.
		top = _sky.horizon_y
		top_s = _proj.s_rel_at(top)
	var far_k: float = _proj.scale_at(top_s / radius)
	var half_width: float = (size.x * 0.5 + 120.0) / far_k
	var vertices: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for row: int in range(ROWS + 1):
		var y: float = lerpf(bottom, top, float(row) / float(ROWS))
		var s_rel: float = top_s if row == ROWS else radius * asin(clampf((_proj.near_y - y) / radius, -1.0, 1.0))
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
	_ground_material.set_shader_parameter("sway_a_phase", StreetPath.SWAY_A_PHASE)
	_ground_material.set_shader_parameter("sway_b", StreetPath.SWAY_B)
	_ground_material.set_shader_parameter("sway_b_length", StreetPath.SWAY_B_LENGTH)
	_ground_material.set_shader_parameter("sway_b_phase", StreetPath.SWAY_B_PHASE)
	_ground_material.set_shader_parameter("road_half", StreetPath.ROAD_HALF)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 2
	add_child(_hud)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)
	var front: _Front = _Front.new()
	root.add_child(front)
	_title = StreetTitle.new()
	root.add_child(_title)
	_wobbler = StreetWobbler.new()
	add_child(_wobbler)
	_buttons = BoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 56)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_buttons)
	var daily: StreetUI.RoundButton = StreetUI.RoundButton.new(StreetUI.RED, &"calendar", BUTTON)
	daily.pressed.connect(_on_daily)
	var shop: StreetUI.RoundButton = StreetUI.RoundButton.new(StreetUI.ORANGE, &"stall", BUTTON)
	shop.pressed.connect(_open_shop)
	var settings: StreetUI.RoundButton = StreetUI.RoundButton.new(StreetUI.PURPLE, &"gear", BUTTON)
	settings.pressed.connect(_open_settings)
	# A finger coming down on either starts loading the rooms' page and that room's backdrop, so by the time it lifts
	# most of the reading is done.
	shop.button_down.connect(_prefetch_room.bind(StreetArt.SHOP_BACKDROP))
	settings.button_down.connect(_prefetch_room.bind(StreetArt.SETTINGS_BACKDROP))
	_coins = StreetCoinPill.new()
	_coins.pressed.connect(_open_shop)
	root.add_child(_coins)
	for b: StreetUI.RoundButton in [daily, shop, settings]:
		_buttons.add_child(b)
	_pin = StreetUI.RoundButton.new(StreetUI.TEAL, &"home", BUTTON * 0.72)
	_pin.visible = false
	_pin.pressed.connect(_go_home)
	root.add_child(_pin)
	_card = StreetDoorCard.new()
	_card.layer = 4
	_card.play.connect(_on_play)
	_card.closed.connect(func() -> void:
		_busy = false
		_title.create_tween().tween_property(_title, "modulate:a", 1.0, 0.25))
	add_child(_card)
	_place_hud()

## Portrait: the buttons in a row along the foot. Wide: in a column down the right edge, clear of the street.
func _place_hud() -> void:
	var size: Vector2 = get_viewport_rect().size
	var safe: Dictionary = UI.safe_margins(get_viewport())
	var lift: float = BUTTON_LIFT + float(safe["bottom"]) + _banner_room
	var box: Rect2 = _title_box()
	_title.place(Vector2(box.get_center().x * 2.0, size.y), box.position.y, box.size.x)
	# The purse sits in the sky's top-right corner, above the title.
	_coins.position = Vector2(size.x - float(safe["right"]) - COINS_EDGE - _coins.size.x, float(safe["top"]) + COINS_EDGE)
	if StreetLayout.wide(size):
		# The banner sits in the middle of the foot, clear of this column, so the column runs from under the purse
		# down to the foot: lifted by the banner, its top button went under the purse on a turned phone.
		var top: float = _coins.position.y + _coins.size.y + COINS_EDGE
		_buttons.vertical = true
		_buttons.add_theme_constant_override("separation", 36)
		_buttons.size = Vector2(BUTTON, size.y - float(safe["bottom"]) - BUTTON_LIFT * 0.5 - top)
		_buttons.position = Vector2(size.x - float(safe["right"]) - BUTTON_LIFT - BUTTON, top)
		_pin.position = Vector2(size.x * 0.5 - _pin.size.x * 0.5, size.y - lift - _pin.size.y)
		return
	_buttons.vertical = false
	_buttons.add_theme_constant_override("separation", 56)
	_buttons.position = Vector2(0.0, size.y - lift - BUTTON)
	_buttons.size = Vector2(size.x, BUTTON)
	_pin.position = Vector2(size.x * 0.5 - _pin.size.x * 0.5, _buttons.position.y - _pin.size.y - 28.0)

func _on_banner(height: float) -> void:
	# The street's rest moves up with the buttons, and a street at rest follows it (_layout).
	_banner_room = height
	_layout()

func _on_daily() -> void:
	if Daily.is_open():
		Screens.go(Daily.SCENE)
	else:
		Toast.say(self, "The daily puzzle opens after level %d" % Daily.opens_after())

func _unhandled_input(event: InputEvent) -> void:
	if _busy or _measuring or _preview:
		return
	# Keys and the mouse wheel walk the street a door at a time, and Enter opens the door to play next.
	if event.is_action_pressed("tilt_up") or event.is_action_pressed("ui_up"):
		_step(1)
		return
	if event.is_action_pressed("tilt_down") or event.is_action_pressed("ui_down"):
		_step(-1)
		return
	if event.is_action_pressed("ui_accept"):
		_open_card(_current)
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var wheel: MouseButton = (event as InputEventMouseButton).button_index
		if wheel == MOUSE_BUTTON_WHEEL_UP or wheel == MOUSE_BUTTON_WHEEL_DOWN:
			_velocity += WHEEL_SPEED * (1.0 if wheel == MOUSE_BUTTON_WHEEL_UP else -1.0)
			return
	# Touches arrive in screen units, and the world is drawn at _world_scale().
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_dragging = true
			_moved = false
			_press_at = touch.position
			_press_us = Time.get_ticks_usec()
			_steady = 0.0
			_velocity = 0.0
			_grab_s = _scroll + _proj.s_rel_at(touch.position.y / scale.y)
			_last_drag_us = _press_us
		else:
			_dragging = false
			if not _moved and Time.get_ticks_usec() - _press_us < int(TAP_TIME * 1000000.0):
				_velocity = 0.0
				_cast.look_toward(touch.position)
				_tap(touch.position)
	elif event is InputEventScreenDrag and _dragging:
		var drag: InputEventScreenDrag = event
		_cast.look_toward(drag.position)
		if not _moved and drag.position.distance_to(_press_at) < TAP_SLOP:
			return
		_moved = true
		var want: float = _grab_s - _proj.s_rel_at(drag.position.y / scale.y)
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

## A tap on the street, `at` in screen units: whatever is under the finger, front first, wobbles. A cast member
## laughs, and an open door's house opens its card too.
func _tap(at: Vector2) -> void:
	if _title != null and _title.hit(at):
		_title.poke()
		return
	var member: int = _cast.member_at(at) if _cast.visible else -1
	if member >= 0:
		_cast.poke(member)
		return
	var world: Vector2 = at / scale.x
	var hit: StreetProp = null
	for prop: Node in _props.get_children():
		var item: StreetProp = prop as StreetProp
		if item == null or not item.visible or item.z_index < 0 or item.scale.y <= 0.0 \
				or item.kind == StreetPath.Kind.NONE or item.modulate.a < 0.5:
			continue
		var local: Vector2 = (world - item.position) / item.scale.y
		if item.bounds().has_point(local) and (hit == null or item.position.y > hit.position.y):
			hit = item
	if hit == null:
		if _sky.poke(world):
			Audio.play(&"clink", -12.0, randf_range(1.0, 1.3))
		return
	# A family in front of its house: the one tapped laughs and wobbles.
	if hit.folk != null and hit.folk.visible:
		var folk_at: int = hit.folk.member_at((world - hit.position) / hit.scale.y - hit.folk.position)
		if folk_at >= 0:
			hit.folk.poke(folk_at)
			return
	_wobble(hit)
	if hit.kind != StreetProp.HOUSE:
		Audio.play(&"pop", StreetWobbler.VOICE_DB, randf_range(0.95, 1.3))
		return
	if hit.state == StreetProp.Door.FAR or hit.state == StreetProp.Door.LOCKED:
		Audio.play(&"knock", -6.0)
		return
	_open_card(hit.door)

## Kicks a prop's wobble and steps it until it rests, with a tick on a phone.
func _wobble(prop: StreetProp) -> void:
	Audio.buzz(StreetWobbler.BUZZ_MS, StreetWobbler.BUZZ)
	if prop.kick() and not _wobbling.has(prop):
		_wobbling.append(prop)
	elif Save.reduce_motion:
		var t: Tween = prop.create_tween()
		t.tween_property(prop, "modulate:a", StreetWobbler.FADE_TO, StreetWobbler.FADE_TIME * 0.4)
		t.tween_property(prop, "modulate:a", 1.0, StreetWobbler.FADE_TIME * 0.6)

func _open_card(door: int) -> void:
	_busy = true
	_velocity = 0.0
	# Play is likely next: its scene and backdrop start loading on a thread while the card drops and swings.
	Screens.prefetch(StreetPlay.SCENE)
	StreetArt.prefetch_backdrop(StreetArt.PLAY_BACKDROP, StreetLayout.wide(get_viewport_rect().size))
	# The title makes way for the card's ribbon, and comes back when the card goes.
	_title.create_tween().tween_property(_title, "modulate:a", 0.0, 0.2)
	_card.open(door, Street.board(door), Street.par(door), Street.stars(door))

func _on_play(door: int) -> void:
	Pack.use(Pack.Section.MAIN)
	StreetPlay.door = door
	StreetPlay.helpers = _card.chosen()
	var go: Callable = func() -> void: Screens.go(StreetPlay.SCENE)
	# Decision 7: an ad between levels comes only after a tap on Play, with the kit's usual spacing.
	if door > 1:
		RatePrompt.or_ad(self, go, false)
	else:
		go.call()

## Rolls the street `by` doors on from the one at its resting height, back as far as door 1 and on to the newest.
func _step(by: int) -> void:
	var resting: int = StreetPath.door_near(_scroll + _rest_s_rel())
	var to: int = clampi(resting + by, 1, _far_door())
	_velocity = 0.0
	var t: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_scroll", _scroll_for(to), 0.35)

func _go_home() -> void:
	_velocity = 0.0
	var t: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "_scroll", _scroll_for(_current), 0.6)

## After a win: the cast hops along the road to the next door while the street rolls with it, breaking a milestone's
## ribbon on the way, then the parcel or milestone the win earned opens, then the next door's card drops in.
func _walk_on(gift: int = 0) -> void:
	_busy = true
	await get_tree().create_timer(0.45).timeout
	_cast.hopping = true
	Audio.play(&"roll", -10.0)
	var from_s: float = _cast_s
	var to_s: float = StreetPath.door_s(_current) - CAST_BEFORE
	var t: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "_cast_s", to_s, WALK_TIME)
	t.tween_property(self, "_scroll", _scroll_for(_current), WALK_TIME)
	if _ribbons.has(_current - 1):
		# The eased walk crosses the ribbon where the cosine ease reaches its share of the way.
		var share: float = clampf((_ribbon_s(_current - 1) - from_s) / (to_s - from_s), 0.0, 1.0)
		var at: float = acos(1.0 - 2.0 * share) / PI * WALK_TIME
		t.tween_callback(_break_ribbon.bind(_current - 1)).set_delay(at)
	await t.finished
	_cast.hopping = false
	_cast.cheer()
	Audio.play(&"pop", -6.0)
	if gift > 0:
		await _open_gift(gift)
	await get_tree().create_timer(CARD_DELAY).timeout
	_open_card(_current)

## Opens door `n`'s parcel or milestone, once, and waits for it to close. The street then shows what it brought: a
## family's house where the plot was.
func _open_gift(n: int) -> void:
	if Save.gifts.has(n):
		return
	var moment: StreetMoment = null
	if StreetRewards.is_milestone(n):
		moment = StreetMilestone.new()
	elif StreetRewards.has_parcel(n):
		moment = StreetGift.new()
	if moment == null:
		return
	moment.door = n
	moment.layer = 5
	_title.create_tween().tween_property(_title, "modulate:a", 0.0, 0.2)
	add_child(moment)
	await moment.done
	_title.create_tween().tween_property(_title, "modulate:a", 1.0, 0.25)
	if _houses.has(n):
		_recycle(_houses[n])
		_houses.erase(n)
	_place()

## A parcel or milestone won among the last few doors but never opened (the app closed before it could open), or 0.
func _unclaimed() -> int:
	if _measuring or _preview:
		return 0
	for n: int in range(_current - 1, maxi(_current - 1 - StreetRewards.PARCEL_EVERY, 0), -1):
		if (StreetRewards.has_parcel(n) or StreetRewards.is_milestone(n)) and Street.stars(n) > 0 \
				and not Save.gifts.has(n):
			return n
	return 0

## Where milestone `n`'s finish ribbon stands along the street.
func _ribbon_s(n: int) -> float:
	return StreetPath.door_s(n) - RIBBON_BEFORE

## The cast breaks milestone `n`'s ribbon: its halves fly apart and fade, and it is gone from the street.
func _break_ribbon(n: int) -> void:
	var ribbon: StreetProp = _ribbons.get(n, null)
	if ribbon == null:
		return
	Audio.play(&"pop", -2.0, 0.8)
	Audio.buzz(30, 0.6)
	ribbon.visible = false
	for side: int in [-1, 1]:
		var half: StreetPiece = StreetPiece.new("ribbon_half_left" if side < 0 else "ribbon_half_right",
			StreetProp.ribbon_k())
		half.position = ribbon.position
		half.scale = ribbon.scale
		half.z_index = 1
		_props.add_child(half)
		var t: Tween = half.create_tween().set_parallel()
		if Save.reduce_motion:
			t.tween_property(half, "modulate:a", 0.0, 0.3)
		else:
			t.tween_property(half, "position:x", half.position.x + side * RIBBON_FLY, 0.6).set_trans(Tween.TRANS_QUAD) \
				.set_ease(Tween.EASE_OUT)
			t.tween_property(half, "position:y", half.position.y + 60.0, 0.6).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_IN)
			t.tween_property(half, "rotation", side * 0.7, 0.6)
			t.tween_property(half, "modulate:a", 0.0, 0.3).set_delay(0.35)
		t.chain().tween_callback(half.queue_free)

func _prefetch_room(backdrop: String) -> void:
	if _busy:
		return
	StreetArt.prefetch_page(StreetArt.ROOMS)
	StreetArt.prefetch_backdrop(backdrop, StreetLayout.wide(get_viewport_rect().size))

func _open_shop() -> void:
	if _busy:
		return
	_busy = true
	var shop: StreetShop = StreetShop.new()
	shop.closed.connect(func() -> void: _busy = false)
	add_child(shop)

func _open_settings() -> void:
	if _busy:
		return
	_busy = true
	var settings: StreetSettings = StreetSettings.new()
	settings.closed.connect(func() -> void: _busy = false)
	add_child(settings)

func _process(delta: float) -> void:
	_time += delta
	var started_us: int = Time.get_ticks_usec()
	var i: int = _wobbling.size() - 1
	while i >= 0:
		if not _wobbling[i].jiggle.step(delta):
			_wobbling.remove_at(i)
		i -= 1
	if _preview:
		_scroll = _rest + PREVIEW_ROLL * sin(_time * PREVIEW_SPEED)
	elif not _dragging:
		if _steady != 0.0:
			_scroll += _steady * delta
		else:
			_scroll += _velocity * delta
			_velocity *= exp(-FRICTION * delta)
		var inside: float = clampf(_scroll, _bounds.x, _bounds.y)
		if inside != _scroll and not _busy:
			_scroll = lerpf(_scroll, inside, 1.0 - exp(-SPRING * delta))
			_velocity *= exp(-SPRING * delta)
	_place()
	_probe.note(float(Time.get_ticks_usec() - started_us) / 1000.0)

## Puts everything in view where the drum shows it, recycling what has left the view.
func _place() -> void:
	var size: Vector2 = _world_size()
	_ground_material.set_shader_parameter("scroll", _scroll)
	var near: float = _scroll + _proj.near_s_rel(size.y)
	var far: float = _scroll + _proj.far_s_rel(0.0)
	# Flat, nothing hides a far prop behind a crest, so a prop stands only on the ground under the sky line, and one
	# that would reach into the title waits until it would not (_clear_of_title), so nothing floats in the sky.
	if Save.reduce_motion:
		far = _scroll + _proj.s_rel_at(_sky.horizon_y)
	var first: int = clampi(StreetPath.door_near(near) - 1, 1, _last)
	var last: int = clampi(StreetPath.door_near(far) + 1, 1, _last)
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
			house.dress_house(door, _state(door), Street.stars(door), Save.knockers.has(door),
				Save.gifts.has(door))
			_houses[door] = house
		_stand(house, s, StreetPath.door_x(door))
		if Save.reduce_motion:
			house.visible = _clear_of_title(house)
		if house.state == StreetProp.Door.CURRENT:
			house.pulse = _time
			house.queue_redraw()
	# A finish ribbon across the road just past each milestone still to come.
	for n: Variant in _ribbons.keys():
		var m: int = n
		var at_s: float = _ribbon_s(m)
		if at_s < near or at_s > far or Save.gifts.has(m):
			_recycle(_ribbons[m])
			_ribbons.erase(m)
	@warning_ignore("integer_division")
	var milestone: int = (first + StreetRewards.MILESTONE_EVERY - 1) / StreetRewards.MILESTONE_EVERY \
		* StreetRewards.MILESTONE_EVERY
	while milestone <= last:
		var rs: float = _ribbon_s(milestone)
		if rs >= near and rs <= far and not Save.gifts.has(milestone):
			var ribbon: StreetProp = _ribbons.get(milestone, null)
			if ribbon == null:
				ribbon = _take()
				ribbon.dress_ribbon(milestone)
				_ribbons[milestone] = ribbon
			_stand(ribbon, rs, StreetPath.door_x(milestone))
		milestone += StreetRewards.MILESTONE_EVERY
	var from_slot: int = floori(near / StreetPath.SLOT_GAP)
	var to_slot: int = ceili(far / StreetPath.SLOT_GAP)
	for key: Variant in _scenery.keys():
		var slot: Vector2i = key
		if slot.x < from_slot or slot.x > to_slot:
			_recycle(_scenery[slot])
			_scenery.erase(slot)
	for slot: int in range(maxi(from_slot, 0), to_slot + 1):
		for side: int in [-1, 1]:
			# Band 0 is the road's edge and band 1 the row behind it, and the meadow adds bands out to the screen's edges.
			for band: int in range(_far_bands + 2):
				var spot: Vector2 = StreetPath.scenery(slot, side, band == 1) if band < 2 \
					else StreetPath.far_scenery(slot, side, band - 1)
				if int(spot.x) == StreetPath.Kind.NONE:
					continue
				var variety: int = StreetPath.mix(slot * 7 + side + band * 3)
				var key: Vector2i = Vector2i(slot, side * (band + 1))
				var prop: StreetProp = _scenery.get(key, null)
				if prop == null:
					prop = _take()
					prop.dress_scenery(int(spot.x), variety)
					_scenery[key] = prop
				_stand(prop, StreetPath.slot_s(slot), spot.y)
				if Save.reduce_motion:
					prop.visible = _clear_of_title(prop)
	var cast_at: Vector3 = _proj.place(_cast_s - _scroll, _cast_x(_cast_s))
	_cast.visible = not _cast_hidden and _cast_s > near and _cast_s < far and not _proj.behind_crest(_cast_s - _scroll)
	# The cast keeps whole on the screen, however far the road swings.
	var half_row: float = StreetCast.body_width() * cast_at.z * (float(_cast.members.size()) * StreetCast.SPREAD * 0.5)
	_cast.position = Vector2(clampf(cast_at.x, half_row + 34.0, size.x - half_row - 34.0), cast_at.y)
	_cast.scale = Vector2(cast_at.z, cast_at.z)
	if _pin != null:
		var home_y: float = _proj.place(StreetPath.door_s(_current) - _scroll, 0.0).y
		_pin.visible = not _busy and not _measuring and (home_y > size.y + PIN_AFTER
			or _proj.behind_crest(StreetPath.door_s(_current) - _scroll))

## Where the cast stands across the street at `s`: on the road, drawn CAST_TOWARD_DOOR of the way toward the door it
## waits at, blending from one door's side to the next as it walks, so it stands before the door as in the concept.
func _cast_x(s: float) -> float:
	var ahead: float = s + CAST_BEFORE
	var a: int = clampi(floori((ahead - StreetPath.FIRST_DOOR) / StreetPath.DOOR_GAP) + 1, 1, _last)
	var b: int = mini(a + 1, _last)
	var t: float = clampf((ahead - StreetPath.door_s(a)) / StreetPath.DOOR_GAP, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var road: float = StreetPath.road_x(s)
	var toward: float = lerpf(StreetPath.door_x(a) - StreetPath.road_x(StreetPath.door_s(a)),
		StreetPath.door_x(b) - StreetPath.road_x(StreetPath.door_s(b)), t)
	return road + toward * CAST_TOWARD_DOOR

## Behind the crest a prop is drawn before the ground, which hides its foot, so it rises over the horizon. Its depth
## scale carries any tap's wobble, and trees and bushes lean in the breeze.
func _stand(prop: StreetProp, s: float, x: float) -> void:
	var at: Vector3 = _proj.place(s - _scroll, x)
	prop.position = Vector2(at.x, at.y)
	prop.scale = Vector2(at.z, at.z) * prop.wobble_scale()
	prop.rotation = prop.wobble_turn() + (0.0 if Save.reduce_motion else prop.sway(_time))
	prop.z_index = -1 if _proj.behind_crest(s - _scroll) else 0

## Whether a prop as it stands now keeps out of the title, in world units: on the flat street a tall house or lamp
## near the sky line would otherwise reach up into it.
func _clear_of_title(prop: StreetProp) -> bool:
	var b: Rect2 = prop.bounds()
	var box: Rect2 = Rect2(prop.position + b.position * prop.scale.y, b.size * prop.scale.y)
	var title: Rect2 = _title_box()
	return not box.intersects(Rect2(title.position / scale.x, title.size / scale.x))

## The furthest door the street scrolls to: AHEAD past the lit one, or the last door already holding a board.
func _far_door() -> int:
	return mini(maxi(_current + AHEAD, (Save.street["doors"] as PackedStringArray).size()), _last)

func _state(door: int) -> StreetProp.Door:
	if door == _current:
		return StreetProp.Door.CURRENT
	if door < _current:
		return StreetProp.Door.SOLVED if Street.stars(door) > 0 else StreetProp.Door.OPEN
	# A door past the lit one that already has its board was opened before Street, with a key or a chapter's gate.
	if Street.id_of(door) != "" and not _measuring:
		return StreetProp.Door.OPEN
	return StreetProp.Door.LOCKED if door <= _current + NUMBERED_AHEAD else StreetProp.Door.FAR

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
	prop.rotation = 0.0
	_pool.append(prop)

## The scripted scroll for measuring: flings both ways, a steady roll both ways, then a rest, each logged, in rounds
## with the cast and without, so anything that drifts with time weighs on both alike (MATH.md section 25).
func _auto_scroll() -> void:
	print("STREET_DEVICE %s" % JSON.stringify({"adapter": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(), "screen": DisplayServer.screen_get_size(),
		"viewport": get_viewport_rect().size, "refresh_hz": DisplayServer.screen_get_refresh_rate()}))
	_buttons.visible = false
	_bounds = Vector2(_scroll_for(1), _scroll_for(Pack.main_count()))
	_scroll = _scroll_for(AUTO_DOOR)
	await get_tree().create_timer(2.5).timeout
	for round: int in range(AUTO_ROUNDS):
		for cast: bool in [true, false]:
			_cast_hidden = not cast
			_cast.process_mode = Node.PROCESS_MODE_INHERIT if cast else Node.PROCESS_MODE_DISABLED
			await _auto_pass(("_cast_" if cast else "_street_") + str(round + 1))
	_cast_hidden = false
	_cast.process_mode = Node.PROCESS_MODE_INHERIT
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


## What frames the street on the screen itself, under the buttons, as in every concept: a strip of grass and flowers
## along the foot, and leafy corners growing up from the bottom corners.
class _Front extends Node2D:
	const GRASS_HEIGHT: float = 150.0
	const CORNER_WIDTH: float = 300.0

	func _ready() -> void:
		get_viewport().size_changed.connect(queue_redraw)

	func _draw() -> void:
		var size: Vector2 = get_viewport_rect().size
		var grass_k: float = GRASS_HEIGHT / StreetArt.size("grass_front").y
		var step: float = StreetArt.size("grass_front").x * grass_k
		var x: float = 0.0
		while x < size.x:
			StreetArt.draw_at(self, "grass_front", Vector2(x, size.y - GRASS_HEIGHT), grass_k)
			x += step - 1.0
		var corner_k: float = CORNER_WIDTH / StreetArt.size("front_left").x
		var corner: Vector2 = StreetArt.size("front_left") * corner_k
		StreetArt.draw_at(self, "front_left", Vector2(0.0, size.y - corner.y), corner_k)
		StreetArt.draw_at(self, "front_right", Vector2(size.x - corner.x, size.y - corner.y), corner_k)
