class_name HintGate
extends RefCounted

## The kit expects from the game: its hint button's press going through `request`, the button dressed by
## `dress` whenever a hint is used or the settings change, and `Save.hint_day`, `Save.hints_used` and
## `Save.set_hints(day, used)`.

static func cost(level: int) -> AdPacing.Hint:
	if not Ads.rewards():
		return AdPacing.Hint.FREE
	return AdPacing.hint_cost(level, used(), Supporter.active())

static func used() -> int:
	return AdPacing.used_today(Save.hint_day, Save.hints_used, today())

static func today() -> String:
	return Time.get_date_string_from_system(false)

## Returns the sheet that asks, or null, so the play screen can hold its input while it is open.
static func request(host: Node, level: int, give: Callable) -> Sheet:
	var price: AdPacing.Hint = cost(level)
	Analytics.event(&"hint", {"level": level + 1, "cost": String(AdPacing.Hint.keys()[price]).to_lower()})
	match price:
		AdPacing.Hint.ALLOWANCE:
			Save.set_hints(today(), used() + 1)
		AdPacing.Hint.VIDEO:
			return ask(host, give)
	give.call()
	return null

static func ask(host: Node, give: Callable) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	# Broken by hand, so no line is left with one word on it.
	c.add_child(UI.title("Watch a short video\nfor a hint?", 50))
	var why: Label = UI.label("Today's free hints are used.\nMore come at midnight.", 28, Brand.MUTED)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(why)
	c.add_child(UI.spacer(6))
	var watch: Button = UI.button("Watch", UI.Style.PRIMARY)
	watch.pressed.connect(func() -> void:
		sheet.close()
		Ads.rewarded(give, func() -> void:
			if is_instance_valid(host):
				Toast.say(host, "No video right now, so this hint is free")
			if give.is_valid():
				give.call()))
	c.add_child(watch)
	if Supporter.on_play and not Supporter.active():
		var pack: Button = UI.button("Remove ads, unlimited hints", UI.Style.SECONDARY)
		pack.pressed.connect(func() -> void:
			sheet.close()
			Supporter.open(host))
		c.add_child(pack)
	var later: Button = UI.button("Not now", UI.Style.GHOST)
	later.pressed.connect(sheet.close)
	c.add_child(later)
	return sheet

static func dress(button: IconButton, level: int) -> void:
	match cost(level):
		AdPacing.Hint.ALLOWANCE:
			button.badge = str(AdPacing.hints_left(used()))
			button.badge_icon = &""
		AdPacing.Hint.VIDEO:
			button.badge = ""
			button.badge_icon = &"play"
		_:
			button.badge = ""
			button.badge_icon = &""
