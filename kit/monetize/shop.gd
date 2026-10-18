class_name Shop
extends RefCounted

## The kit expects from the game:
## - In `GameMonetize`: SUPPORTER_ID, LEVELS_ID, LOOKS_ID, THEMES_ID, COMPLETE_ID, KEY_IDS with KEY_COUNTS,
##   and TIP_IDS, each a one-time product in Play Console (keys and tips are consumed after each purchase).
## - In `Save`: `supporter`, `owned`, `keys` and `tips`, with `set_supporter`, `set_owned`, `add_keys` and
##   `add_tip`.
## - In `GameLooks`: PACK, PACK_LINE and PACK_ROW.

## The shop's row that leads to the level keys, which are several products.
const KEYS: String = "keys"
const THEMES_PACK: String = "Themes pack"
const THEMES_LINE: String = "Nord, Dracula, Rosé Pine and twelve more"
const THEMES_ROW: String = "Fifteen more colour themes"
const KEEP_ROW: String = "Yours to keep after one purchase"

## Play's formatted prices in the player's currency, by product id.
static var prices: Dictionary = {}

static var _store: StoreBackend

static func start() -> void:
	Passes.start()
	if is_instance_valid(_store) or not OS.has_feature("android") or not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	var billing: GDScript = load("res://kit/monetize/android/play_billing.gd")
	_store = billing.new()
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_store)

## In the order the shop lists them.
static func one_time_ids() -> PackedStringArray:
	return PackedStringArray([GameMonetize.COMPLETE_ID, GameMonetize.SUPPORTER_ID, GameMonetize.LEVELS_ID,
		GameMonetize.LOOKS_ID, GameMonetize.THEMES_ID])

static func all_ids() -> PackedStringArray:
	return one_time_ids() + GameMonetize.KEY_IDS + GameMonetize.TIP_IDS

static func is_tip(id: String) -> bool:
	return GameMonetize.TIP_IDS.has(id)

static func is_key(id: String) -> bool:
	return GameMonetize.KEY_IDS.has(id)

static func is_consumable(id: String) -> bool:
	return is_key(id) or is_tip(id)

static func keys_in(id: String) -> int:
	var at: int = GameMonetize.KEY_IDS.find(id)
	return GameMonetize.KEY_COUNTS[at] if at >= 0 else 0

static func owns(id: String) -> bool:
	return Save.supporter if id == GameMonetize.SUPPORTER_ID else Save.owned.has(id)

## What the Complete pack holds.
static func parts() -> PackedStringArray:
	return PackedStringArray([GameMonetize.SUPPORTER_ID, GameMonetize.LEVELS_ID, GameMonetize.LOOKS_ID,
		GameMonetize.THEMES_ID])

static func has(id: String) -> bool:
	return owns(id) or (parts().has(id) and owns(GameMonetize.COMPLETE_ID))

static func ads_off() -> bool:
	return has(GameMonetize.SUPPORTER_ID)

static func on(id: String) -> bool:
	return has(id) or Passes.active(id)

static func levels_open() -> bool:
	return on(GameMonetize.LEVELS_ID)

static func looks_open() -> bool:
	return not Supporter.on_play or on(GameMonetize.LOOKS_ID)

static func themes_open() -> bool:
	return not Supporter.on_play or on(GameMonetize.THEMES_ID)

static func has_everything() -> bool:
	for id: String in parts():
		if not has(id):
			return false
	return true

## The Complete pack is offered only while none of it is owned, so it never sells a part twice.
static func offers_complete() -> bool:
	for id: String in parts() + PackedStringArray([GameMonetize.COMPLETE_ID]):
		if owns(id):
			return false
	return true

static func price(id: String) -> String:
	return String(prices.get(id, ""))

static func buy(id: String) -> void:
	if is_instance_valid(_store):
		_store.buy(id)
	else:
		Supporter.say("Google Play is not reachable right now")

static func restore() -> void:
	if is_instance_valid(_store):
		_store.restore(false)
	else:
		Supporter.say("Google Play is not reachable right now")

static func grant(id: String, owned: bool) -> void:
	if owns(id) == owned:
		return
	var quiet: bool = ads_off()
	if id == GameMonetize.SUPPORTER_ID:
		Save.set_supporter(owned)
	else:
		Save.set_owned(id, owned)
	if ads_off() != quiet:
		if ads_off():
			Ads.stop()
		else:
			Ads.start()

static func tipped() -> void:
	Save.add_tip()
	Supporter.say("Thank you for the tip. It goes into the next game")

static func keyed(id: String) -> void:
	Save.add_keys(keys_in(id))
	Unlocks.delivered(keys_in(id))

static func title(id: String) -> String:
	if id == GameMonetize.COMPLETE_ID:
		return "Complete pack"
	if id == GameMonetize.SUPPORTER_ID:
		return "Supporter pack"
	if id == GameMonetize.LEVELS_ID:
		return "Every level"
	if id == GameMonetize.LOOKS_ID:
		return GameLooks.PACK
	if id == GameMonetize.THEMES_ID:
		return THEMES_PACK
	if is_key(id):
		return "1 level key" if keys_in(id) == 1 else "%d level keys" % keys_in(id)
	return "Tip"

static func line(id: String) -> String:
	if id == GameMonetize.COMPLETE_ID:
		return "All below, for less"
	if id == GameMonetize.SUPPORTER_ID:
		return "No ads, and every hint free"
	if id == GameMonetize.LEVELS_ID:
		return "Play any level, solved or not"
	if id == GameMonetize.LOOKS_ID:
		return GameLooks.PACK_LINE
	if id == GameMonetize.THEMES_ID:
		return THEMES_LINE
	return ""

## Each pack a video can lend, and the Complete pack, says that buying it is for good, so a player who has
## seen the six hour try does not read the price as six hours too.
static func rows(id: String) -> PackedStringArray:
	if id == GameMonetize.COMPLETE_ID:
		return PackedStringArray(["No ads, every hint free", "Every level open", GameLooks.PACK_ROW, THEMES_ROW, KEEP_ROW])
	if id == GameMonetize.SUPPORTER_ID:
		return Supporter.SHEET_ROWS
	if id == GameMonetize.LEVELS_ID:
		return PackedStringArray(["Every level open now", "Stars still earned by solving", KEEP_ROW])
	if id == GameMonetize.LOOKS_ID:
		return PackedStringArray([GameLooks.PACK_ROW, "Pick one any time in Settings", KEEP_ROW])
	if id == GameMonetize.THEMES_ID:
		return PackedStringArray([THEMES_ROW, "Light and dark, picked in Settings", KEEP_ROW])
	return PackedStringArray()

static func open(host: Node) -> Sheet:
	if not Supporter.on_play:
		return Supporter.open(host)
	Analytics.event(&"shop_open")
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Shop", 56))
	c.add_child(_line("Every level of %s opens by playing. These help me make the next game." % Brand.NAME))
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	for id: String in one_time_ids():
		if id == GameMonetize.COMPLETE_ID and not offers_complete() and not owns(id):
			continue
		list.add_child(_item(id, func() -> void:
			sheet.close()
			offer(host, id)))
	if not levels_open():
		list.add_child(_item(KEYS, func() -> void:
			sheet.close()
			keys(host)))
	list.add_child(_item("", func() -> void:
		sheet.close()
		tips(host)))
	c.add_child(list)
	var again: Button = UI.button("Restore purchases", UI.Style.GHOST)
	again.pressed.connect(restore)
	c.add_child(again)
	live(sheet, func() -> void:
		sheet.close()
		open(host))
	return sheet

static func offer(host: Node, id: String) -> Sheet:
	if not Supporter.on_play:
		return Supporter.open(host)
	Analytics.event(&"shop_offer", {"item": id})
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	var owned: bool = has(id)
	c.add_child(UI.title(title(id), 56))
	if owned:
		c.add_child(_line("Thank you. It is on for this Google account."))
	elif id == GameMonetize.SUPPORTER_ID:
		c.add_child(_line("One purchase that helps me\nmake the next game."))
	elif Passes.active(id):
		c.add_child(_line("You are trying it, %s left. Get it to keep it for good." % Passes.say_left(id)))
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	for text: String in rows(id):
		list.add_child(_row(text))
	c.add_child(UI.centred(list))
	c.add_child(UI.spacer(8))
	if not owned:
		var buy_button: Button = UI.button(_buy_text(id), UI.Style.PRIMARY)
		buy_button.pressed.connect(func() -> void: buy(id))
		c.add_child(buy_button)
		if Passes.offers(id):
			var lend: Button = UI.button("Try it for %d hours %s" % [Passes.HOURS, Ads.with_one()], UI.Style.SECONDARY)
			lend.pressed.connect(func() -> void:
				sheet.close()
				Passes.lend(id, func() -> void: _show_lent(host, id)))
			c.add_child(lend)
		var again: Button = UI.button("Restore purchase", UI.Style.GHOST)
		again.pressed.connect(restore)
		c.add_child(again)
	var more: Button = UI.button("See the shop", UI.Style.GHOST)
	more.pressed.connect(func() -> void:
		sheet.close()
		open(host))
	c.add_child(more)
	live(sheet, func() -> void:
		sheet.close()
		offer(host, id))
	return sheet

static func keys(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Level keys", 56))
	var held: String = "You have none yet." if Save.keys == 0 else "You have %d." % Save.keys
	c.add_child(_line("A key opens any one locked level for good. Tap a locked level to use one. " + held))
	for id: String in GameMonetize.KEY_IDS:
		var pack: Button = UI.button("%s  %s" % [title(id), price(id)] if price(id) != "" else title(id), UI.Style.SECONDARY)
		pack.pressed.connect(func() -> void: Unlocks.buy_key(id, -1))
		c.add_child(pack)
	if Ads.rewards():
		var video: Button = UI.button("%s for a key" % Ads.watch(), UI.Style.GHOST)
		video.pressed.connect(func() -> void:
			sheet.close()
			Passes.give_key(func() -> void:
				if is_instance_valid(host) and host.is_inside_tree():
					keys(host)))
		c.add_child(video)
	live(sheet, func() -> void:
		sheet.close()
		keys(host))
	return sheet

## Play sells only fixed prices, so the jar holds a row of them, from small to generous.
static func tips(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Tip jar", 56))
	c.add_child(_line("Say thanks, as often as you like. A tip opens nothing new: it all goes into making the next game."))
	var grid: GridContainer = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for id: String in GameMonetize.TIP_IDS:
		var tip: Button = UI.button(price(id) if price(id) != "" else "Tip", UI.Style.SECONDARY)
		tip.custom_minimum_size.x = 260.0
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tip.pressed.connect(func() -> void: buy(id))
		grid.add_child(tip)
	c.add_child(UI.centred(grid))
	# Two to a row only where two fit: a price such as "Rp 799.000,00" is too wide for two on a phone.
	var widest: float = 0.0
	for tip: Node in grid.get_children():
		widest = maxf(widest, (tip as Control).get_combined_minimum_size().x)
	grid.columns = 2 if widest * 2.0 + 14.0 <= Sheet.room() else 1
	if Save.tips > 0:
		c.add_child(_line("Thank you for %s." % ("your tip" if Save.tips == 1 else "your %d tips" % Save.tips)))
	live(sheet, func() -> void:
		sheet.close()
		tips(host))
	return sheet

static func _show_lent(host: Node, id: String) -> void:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return
	if id == GameMonetize.LOOKS_ID:
		Looks.open(host)
	elif id == GameMonetize.THEMES_ID:
		Themes.open(host)

static func _buy_text(id: String) -> String:
	if id == GameMonetize.SUPPORTER_ID:
		return "Support for %s" % price(id) if price(id) != "" else "Support the game"
	return "Get it for %s" % price(id) if price(id) != "" else "Get %s" % title(id)

## `id` is "" for the tip jar and KEYS for the level keys.
static func _item(id: String, pick: Callable) -> Button:
	var product: bool = id != "" and id != KEYS
	var item: Button = Button.new()
	item.flat = true
	item.focus_mode = Control.FOCUS_NONE
	item.custom_minimum_size = Vector2(0, 104)
	item.pressed.connect(pick)
	UI.press_feedback(item)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(row)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading: Label = UI.label(title(id) if product else ("Level keys" if id == KEYS else "Tip jar"), 32)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.add_child(heading)
	var keys_line: String = "Open any one level now" + (". You have %d" % Save.keys if Save.keys > 0 else "")
	var product_line: String = line(id)
	if product and not has(id) and Passes.active(id):
		product_line = "Trying it, %s left" % Passes.say_left(id)
	var said: Label = UI.label(product_line if product else (keys_line if id == KEYS else "Say thanks, as often as you like"),
		24, Brand.MUTED)
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(said)
	row.add_child(words)
	if product and has(id):
		row.add_child(_Tick.new())
	else:
		var tag: Label = UI.label(price(id) if product and price(id) != "" else "", 30, Brand.ACCENT)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tag)
		row.add_child(_Chevron.new())
	return item

static func live(sheet: Sheet, rebuild: Callable) -> void:
	if not is_instance_valid(_store):
		return
	var once: Callable = func() -> void:
		if is_instance_valid(sheet) and not sheet.is_queued_for_deletion():
			rebuild.call()
	_store.changed.connect(once, CONNECT_ONE_SHOT)
	sheet.tree_exiting.connect(func() -> void:
		if is_instance_valid(_store) and _store.changed.is_connected(once):
			_store.changed.disconnect(once))

static func _line(text: String) -> Label:
	var l: Label = UI.label(text, 28, Brand.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func _row(text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_Tick.new())
	var l: Label = UI.label(text, 32)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)
	return row

class _Tick extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(48, 48)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 22.0, Color(Brand.ACCENT, 0.14), true, -1.0, true)
		Icons.draw(self, &"check", size * 0.5, 34.0, Brand.ACCENT)

class _Chevron extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(28, 48)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		draw_polyline(PackedVector2Array([c + Vector2(-5, -10), c + Vector2(5, 0), c + Vector2(-5, 10)]),
			Color(Brand.MUTED, 0.7), 3.0, true)
