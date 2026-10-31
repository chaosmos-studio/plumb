class_name GoBack
extends RefCounted

## Android's back button and back gesture. Godot would quit the app on either, so the project turns that off
## (application/config/quit_on_go_back) and Screens hands each one here: an open sheet closes, the play
## screen and the level grid go back a screen as Escape does, and on the title the player is asked before
## the game closes.

## Android sends one press of a back key as two go-back requests about 50 ms apart (seen with adb's keyevent on a
## Nothing phone), so the second would close the sheet the first opened. Requests closer than this are one.
const ONE_PRESS_MS: int = 250

static var _last_ms: int = -ONE_PRESS_MS

static func request(tree: SceneTree) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_ms < ONE_PRESS_MS:
		return
	_last_ms = now
	if Sheet.back():
		return
	var scene: Node = tree.current_scene
	if scene != null and scene.scene_file_path == Brand.TITLE_SCENE:
		ask(scene)
		return
	for pressed: bool in [true, false]:
		var back: InputEventAction = InputEventAction.new()
		back.action = &"back"
		back.pressed = pressed
		Input.parse_input_event(back)

static func ask(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.centred(UI.app_icon(120)))
	c.add_child(UI.title("Leaving already?", 52))
	var why: Label = UI.label("Your progress is saved, so the next level is waiting right where you left it.", 28, Brand.MUTED)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(why)
	c.add_child(UI.spacer(6))
	var stay: Button = UI.button("Keep playing", UI.Style.PRIMARY)
	stay.pressed.connect(sheet.close)
	c.add_child(stay)
	var leave: Button = UI.button("Close %s" % Brand.NAME, UI.Style.GHOST)
	leave.pressed.connect(func() -> void: host.get_tree().quit())
	c.add_child(leave)
	return sheet
