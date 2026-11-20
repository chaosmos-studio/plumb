class_name StreetLayout
extends RefCounted

## Street's rule for screen shapes (REVAMP_PLAN.md section 16): portrait is the design, and a wide screen (a phone or
## tablet turned sideways, a Chromebook, a desktop or web window) gets its own composed layout, never a stretched or
## letterboxed portrait. The stretch's base turns with the screen, 720 x 1280 or 1280 x 720, so a phone is 720 units
## across its short side either way and a button is the same size in the hand. A squarer screen, such as a tablet,
## shows more than the base along one side. Each screen asks `wide` and lays itself out.
## Classic keeps its own rule (a phone stays portrait, a large screen turns around a centred column), so `stop`
## puts that back when the look changes.

const SHORT: float = 720.0
const LONG: float = 1280.0

## The design size a screen of `pixels` shows, by the stretch's "expand" rule on the base for its orientation.
static func design_size(pixels: Vector2) -> Vector2:
	var base: Vector2 = base_for(pixels)
	var k: float = minf(pixels.x / base.x, pixels.y / base.y)
	return pixels / k

## The base design size for a screen of this shape: portrait for a square or tall screen, landscape for a wide one.
static func base_for(pixels: Vector2) -> Vector2:
	return Vector2(SHORT, LONG) if pixels.y >= pixels.x else Vector2(LONG, SHORT)

## Whether a screen of this design size gets the wide layouts.
static func wide(size: Vector2) -> bool:
	return size.x > size.y

## Street's rule on: phones may turn too, and the base follows the window's shape. Safe to call again.
static func start() -> void:
	ScreenLock.phones_turn = true
	if OS.has_feature("android"):
		ScreenLock.apply()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	if not root.size_changed.is_connected(_fit):
		root.size_changed.connect(_fit)
	_fit()

## Classic's rule back: the project's portrait base, and phones held in portrait.
static func stop() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	if root.size_changed.is_connected(_fit):
		root.size_changed.disconnect(_fit)
	root.content_scale_size = Vector2i(int(SHORT), int(LONG))
	ScreenLock.phones_turn = false
	if OS.has_feature("android"):
		ScreenLock.apply()

static func _fit() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var want: Vector2i = Vector2i(base_for(Vector2(root.size)))
	if root.content_scale_size != want:
		root.content_scale_size = want
