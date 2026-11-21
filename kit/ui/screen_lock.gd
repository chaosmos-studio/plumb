class_name ScreenLock
extends RefCounted

## A phone stays in portrait, which every screen is drawn for. A tablet, an open foldable or a Chromebook,
## 600 dp across and up, turns with the device, and the screens keep to a centred column there. The
## manifest locks nothing (project setting display/window/handheld/orientation is Sensor), since Play
## counts a locked orientation against large screens.
##
## The kit expects from the game: `ScreenLock.start()` in Save's `_ready`.

## Android's own line between a phone and a large screen, in density-independent pixels.
const LARGE_DP: float = 600.0

## Set by a game whose every screen has a wide layout too: then phones turn with the device as well.
static var phones_turn: bool = false

## A debug build turns to the orientation named in this file ("landscape" or "portrait"), looked at every second, so a
## device check can turn the screen without anyone turning the phone. Release builds never read it.
const FORCE_FILE: String = "user://orientation"

static func start() -> void:
	if not OS.has_feature("android"):
		return
	apply()
	# A foldable opening or closing changes the size, and so maybe the answer.
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.size_changed.connect(apply)
	if OS.is_debug_build():
		var poll: Timer = Timer.new()
		poll.wait_time = 1.0
		poll.autostart = true
		poll.timeout.connect(apply)
		root.add_child.call_deferred(poll)

static func apply() -> void:
	var want: DisplayServer.ScreenOrientation = orientation_for(DisplayServer.screen_get_size(), DisplayServer.screen_get_dpi())
	if OS.is_debug_build() and FileAccess.file_exists(FORCE_FILE):
		match FileAccess.get_file_as_string(FORCE_FILE).strip_edges():
			"landscape":
				want = DisplayServer.SCREEN_LANDSCAPE
			"portrait":
				want = DisplayServer.SCREEN_PORTRAIT
	if DisplayServer.screen_get_orientation() != want:
		DisplayServer.screen_set_orientation(want)

static func orientation_for(pixels: Vector2i, dpi: int) -> DisplayServer.ScreenOrientation:
	if phones_turn:
		return DisplayServer.SCREEN_SENSOR
	if dpi <= 0:
		return DisplayServer.SCREEN_PORTRAIT
	var dp: float = minf(pixels.x, pixels.y) * 160.0 / float(dpi)
	return DisplayServer.SCREEN_SENSOR if dp >= LARGE_DP else DisplayServer.SCREEN_PORTRAIT
