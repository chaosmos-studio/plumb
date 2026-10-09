class_name RatePrompt
extends RefCounted

## Google lets only its own review card show without a button, and lets no question about liking the game
## come before it, so the sheet asks nothing and its button opens the Play page instead.
##
## The kit expects from the game: in `Save`, `rate_asked` and `rated`, with `set_rating(asked, rated)`,
## and its Play page as `GameShare.STORE`.

## How many levels solved before each ask.
const MILESTONES: Array[int] = [20, 60, 120, 200, 300, 400]

static func open_to_asking() -> bool:
	return Supporter.on_play and not Save.rated

static func due() -> int:
	if not open_to_asking():
		return 0
	var solved: int = Ads.solved()
	var reached: int = 0
	for m: int in MILESTONES:
		if solved >= m and m > Save.rate_asked:
			reached = m
	return reached

static func or_ad(host: Node, on_done: Callable, after_guide: bool = false) -> void:
	var milestone: int = due()
	if milestone == 0:
		Ads.maybe_interstitial(on_done, after_guide)
		return
	var sheet: Sheet = open(host, milestone)
	sheet.closed.connect(on_done)

static func button_text() -> String:
	return "Rate %s" % Brand.NAME

static func rate(milestone: int = 0) -> void:
	Save.set_rating(maxi(milestone, Save.rate_asked), true)
	OS.shell_open(GameShare.STORE)

static func open(host: Node, milestone: int) -> Sheet:
	Save.set_rating(milestone, false)
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.centred(UI.app_icon(120)))
	var stars: HBoxContainer = HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 10)
	for k: int in range(5):
		stars.add_child(StarIcon.new(40.0, true))
	c.add_child(stars)
	c.add_child(UI.title("A rating helps a lot", 52))
	var words: String = "%s is made by one person. If you're enjoying it, a rating on Google Play helps other players find it."
	var why: Label = UI.label(words % Brand.NAME, 28, Brand.MUTED)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(why)
	c.add_child(UI.spacer(6))
	var yes: Button = UI.button(button_text(), UI.Style.PRIMARY)
	yes.pressed.connect(func() -> void:
		rate(milestone)
		sheet.close())
	c.add_child(yes)
	var later: Button = UI.button("Not now", UI.Style.GHOST)
	later.pressed.connect(sheet.close)
	c.add_child(later)
	return sheet
