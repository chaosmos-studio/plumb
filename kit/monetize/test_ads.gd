class_name TestAds
extends RefCounted

## Test ads on every phone that is not a real player's: in every debug build, and in any build once the hidden
## tester switch is on (seven quick taps on the version line in About). Unity locks ad accounts whose own phones
## view or tap live ads, so the studio's and the testers' phones never ask the game's own app. The switch counts
## from the next launch, since the ad SDK starts once.

const FILE: String = "user://ads.cfg"
const TAPS: int = 7
## Taps further apart than this, in seconds, start the count again.
const TAP_GAP: float = 1.0

## Tests point it elsewhere.
static var path: String = FILE
static var _taps: int = 0
static var _last_tap: float = -10.0

## The plugin's test mode, where every ad comes from LevelPlay's demo app, never the game's own.
static func test_mode() -> bool:
	if OS.is_debug_build():
		return not own_app()
	return tester()

static func tester() -> bool:
	return bool(_file().get_value("testing", "tester", false))

static func set_tester(on: bool) -> void:
	var file: ConfigFile = _file()
	file.set_value("testing", "tester", on)
	file.save(path)

## Debug builds only, and only on a phone registered as a test device in the LevelPlay and Unity dashboards:
## `own_app=true` under [testing] in user://ads.cfg (PUBLISHING.md) asks the game's own app. It serves LIVE ads, even
## with Unity's test mode forced on (seen on 21 November), so it is for load-only checks: never show one on a studio
## phone.
static func own_app() -> bool:
	return OS.is_debug_build() and bool(_file().get_value("testing", "own_app", false))

## Turns `control` into the switch's hidden trigger.
static func listen(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.gui_input.connect(func(event: InputEvent) -> void:
		var press: InputEventMouseButton = event as InputEventMouseButton
		if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
			tap(control))

## True on the tap that flips the switch.
static func tap(host: Node) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	_taps = _taps + 1 if now - _last_tap <= TAP_GAP else 1
	_last_tap = now
	if _taps < TAPS:
		return false
	_taps = 0
	set_tester(not tester())
	if host.is_inside_tree():
		Toast.say(host, "Test ads %s from the next launch" % ("on" if tester() else "off"))
	return true

static func _file() -> ConfigFile:
	var file: ConfigFile = ConfigFile.new()
	file.load(path)
	return file
