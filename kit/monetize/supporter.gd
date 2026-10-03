class_name Supporter
extends RefCounted

## The Supporter pack, which turns the ads off for good and makes every hint free, and the way to support
## the game in each build. On Android it is one of the products the Shop sells through Google Play billing,
## because Play's Payments policy allows nothing else for things bought in an app and forbids pointing
## players to another way to pay, so the Android build never links to GitHub Sponsors. Every other build
## (the web one) has no ads and sells nothing: supporting there means GitHub Sponsors.
##
## The kit expects from the game what Shop does, plus `GameCredits.SPONSOR`, and Save._ready calling
## `Supporter.start()` before `Ads.start()`.

const SHEET_ROWS: PackedStringArray = ["No banner", "No ads between levels", "Every hint free"]

## Whether this copy came from Google Play, which decides how it may ask for support. Captures and tests
## set it to stage either variant anywhere.
static var on_play: bool = OS.has_feature("android")
## The pack's price in the player's currency as Play gives it, or "" until Play has answered. Captures
## set it to stage a price.
static var price: String = "":
	set(value):
		price = value
		Shop.prices[GameMonetize.SUPPORTER_ID] = value

## Whether the ads are off: the Supporter pack, alone or in the Complete pack.
static func active() -> bool:
	return Shop.ads_off()

static func start() -> void:
	Shop.start()

static func buy() -> void:
	Shop.buy(GameMonetize.SUPPORTER_ID)

static func restore() -> void:
	Shop.restore()

static func grant(owned: bool) -> void:
	Shop.grant(GameMonetize.SUPPORTER_ID, owned)

## A short note on whatever screen is showing, for store answers that arrive after the tap that asked.
static func say(text: String) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.current_scene != null:
		Toast.say(tree.current_scene, text)

## The title screen's way to the shop: a shopping bag in the corner opposite `gear`, the settings button,
## on Google Play only. It stays once every pack is had, since the tip jar is always there.
static func add_title_button(host: Node, ui: Control, gear: Control) -> void:
	if not on_play:
		return
	var shop: IconButton = UI.icon_button(&"shop", "Shop")
	shop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	shop.offset_left = -gear.offset_right
	shop.offset_right = -gear.offset_left
	shop.offset_top = gear.offset_top
	shop.offset_bottom = gear.offset_bottom
	shop.pressed.connect(func() -> void: Shop.open(host))
	ui.add_child(shop)

## The support sheet: the Supporter pack with its price and Restore on Google Play; one Sponsor on GitHub
## button elsewhere.
static func open(host: Node) -> Sheet:
	if on_play:
		return Shop.offer(host, GameMonetize.SUPPORTER_ID)
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Support the game", 56))
	var line: Label = UI.label("If %s gave you a few calm minutes, you can help me make the next game. Sponsoring goes through GitHub Sponsors." % Brand.NAME,
		28, Brand.MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(line)
	c.add_child(UI.spacer(8))
	var sponsor: Button = UI.button("Sponsor on GitHub", UI.Style.PRIMARY)
	sponsor.pressed.connect(func() -> void: OS.shell_open(GameCredits.SPONSOR))
	c.add_child(sponsor)
	return sheet
