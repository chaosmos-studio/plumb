class_name Supporter
extends RefCounted

## The Supporter pack: one purchase that turns the ads off for good and makes every hint free, and the
## in-app way to support the game. On Android it is sold through Google Play billing, because Play's
## Payments policy allows nothing else for things bought in an app and forbids pointing players to another
## way to pay, so the Android build never links to GitHub Sponsors. Every other build (the web one) has no
## ads and no pack: supporting there means GitHub Sponsors.
##
## The kit expects from the game: `GameMonetize.SUPPORTER_ID`, a one-time (non-consumable) product with
## that id in Play Console; the GodotGooglePlayBilling plugin in addons/, enabled; `Save.supporter` and
## `Save.set_supporter(on)`, which keep what Play last said so the pack works offline; `GameCredits.SPONSOR`;
## and Save._ready calling `Supporter.start()` before `Ads.start()`.

const SHEET_ROWS: PackedStringArray = ["No banner", "No ads between levels", "Every hint free"]

## Whether this copy came from Google Play, which decides how it may ask for support. Captures and tests
## set it to stage either variant anywhere.
static var on_play: bool = OS.has_feature("android")
## The pack's price in the player's currency as Play gives it, or "" until Play has answered.
static var price: String = ""

static var _store: StoreBackend

static func active() -> bool:
	return Save.supporter

## Connects to Play and asks what this account owns, on Android only.
static func start() -> void:
	if is_instance_valid(_store) or not OS.has_feature("android") or not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	var billing: GDScript = load("res://kit/monetize/android/play_billing.gd")
	_store = billing.new()
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_store)

static func buy() -> void:
	if is_instance_valid(_store):
		_store.buy()
	else:
		say("Google Play is not reachable right now")

static func restore() -> void:
	if is_instance_valid(_store):
		_store.restore(false)
	else:
		say("Google Play is not reachable right now")

## What Play says: the pack is owned, or no longer is (a refund). Ads follow.
static func grant(owned: bool) -> void:
	if owned == Save.supporter:
		return
	Save.set_supporter(owned)
	if owned:
		Ads.stop()
	else:
		Ads.start()

## A short note on whatever screen is showing, for store answers that arrive after the tap that asked.
static func say(text: String) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.current_scene != null:
		Toast.say(tree.current_scene, text)

## The title screen's way to the pack: a heart in the corner opposite `gear`, the settings button, on
## Google Play only and never for a Supporter.
static func add_title_button(host: Node, ui: Control, gear: Control) -> void:
	if not on_play or active():
		return
	var heart: IconButton = UI.icon_button(&"heart", "Supporter pack")
	heart.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	heart.offset_left = -gear.offset_right
	heart.offset_right = -gear.offset_left
	heart.offset_top = gear.offset_top
	heart.offset_bottom = gear.offset_bottom
	heart.pressed.connect(func() -> void: open(host))
	ui.add_child(heart)

## The support sheet: the pack with its price, Support and Restore on Google Play; one Sponsor on GitHub
## button elsewhere.
static func open(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	if not on_play:
		c.add_child(UI.title("Support the game", 56))
		c.add_child(_line("If %s gave you a few calm minutes, you can help me make the next game. Sponsoring goes through GitHub Sponsors." % Brand.NAME))
		c.add_child(UI.spacer(8))
		var sponsor: Button = UI.button("Sponsor on GitHub", UI.Style.PRIMARY)
		sponsor.pressed.connect(func() -> void: OS.shell_open(GameCredits.SPONSOR))
		c.add_child(sponsor)
		return sheet
	var owned: bool = active()
	c.add_child(UI.title("Supporter pack", 56))
	c.add_child(_line("Thank you for supporting %s. The pack is on for this Google account." % Brand.NAME if owned
		else "One purchase that helps me\nmake the next game."))
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	for text: String in SHEET_ROWS:
		rows.add_child(_row(text))
	c.add_child(UI.centred(rows))
	if owned:
		c.add_child(UI.spacer(8))
		return sheet
	c.add_child(UI.spacer(8))
	var support: Button = UI.button(_support_text(), UI.Style.PRIMARY)
	support.pressed.connect(buy)
	c.add_child(support)
	var again: Button = UI.button("Restore purchase", UI.Style.GHOST)
	again.pressed.connect(restore)
	c.add_child(again)
	if is_instance_valid(_store):
		var refresh: Callable = func() -> void:
			if active():
				sheet.close()
				open(host)
			else:
				support.text = _support_text()
		_store.changed.connect(refresh)
		sheet.tree_exiting.connect(func() -> void:
			if is_instance_valid(_store) and _store.changed.is_connected(refresh):
				_store.changed.disconnect(refresh))
	return sheet

static func _support_text() -> String:
	return "Support for %s" % price if price != "" else "Support the game"

static func _line(text: String) -> Label:
	var l: Label = UI.label(text, 28, Brand.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func _row(text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tick: _Tick = _Tick.new()
	row.add_child(tick)
	var l: Label = UI.label(text, 32)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)
	return row

class _Tick extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(48, 48)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 22.0, Color(Brand.ACCENT, 0.14), true, -1.0, true)
		Icons.draw(self, &"check", size * 0.5, 34.0, Brand.ACCENT)
