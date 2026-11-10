class_name HintGate
extends RefCounted

## The kit expects from the game: its hint button's press going through `request`, the button dressed by
## `dress` whenever a hint is used or the settings change, and `Save.hint_day`, `Save.hints_used` and
## `Save.set_hints(day, used)`.

## A hint that would ask for a video is free while none is ready to play: the house banner standing in for AdMob,
## offline, no fill or an ad blocker. Nothing would earn from the ask.
static func cost(level: int) -> AdPacing.Hint:
	if not Ads.rewards():
		return AdPacing.Hint.FREE
	var price: AdPacing.Hint = AdPacing.hint_cost(level, used(), Supporter.active())
	if price == AdPacing.Hint.VIDEO and not Ads.video_ready():
		return AdPacing.Hint.FREE
	return price

static func used() -> int:
	return AdPacing.used_today(Save.hint_day, Save.hints_used, today())

static func today() -> String:
	return Time.get_date_string_from_system(false)

## Returns the sheet that asks, or null, so the play screen can hold its input while it is open.
static func request(host: Node, level: int, give: Callable) -> Sheet:
	give = _counted(give)
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
	# Broken by hand, so no line is left with one word on it. Only asked while a video is ready (cost).
	c.add_child(UI.title("Watch a short video\nfor %d hints?" % AdPacing.VIDEO_HINTS, 50))
	var why: Label = UI.label("Today's free hints are used.\nMore come at midnight.", 28, Brand.MUTED)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(why)
	c.add_child(UI.spacer(6))
	var watch: Button = UI.button("Watch", UI.Style.PRIMARY)
	# A watched video pays for this hint and gives the rest of its hints back as today's free ones.
	var paid: Callable = func() -> void:
		Save.set_hints(today(), AdPacing.used_after_video(used()))
		if give.is_valid():
			give.call()
	watch.pressed.connect(func() -> void:
		sheet.close()
		Ads.rewarded(paid))
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

## Game Stats counts the hints a solve took, so only one actually given is counted.
static func _counted(give: Callable) -> Callable:
	return func() -> void:
		if give.is_valid():
			PlayGames.hinted()
			give.call()

static func dress(button: IconButton, level: int) -> void:
	HintNudge.attach(button)
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
