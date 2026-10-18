class_name RatePrompt
extends RefCounted

## Google Play's own review card (`PlayCore.review`), at a few milestones as a solved level is left with Next
## level, and once as the ending closes. Google's rules: nothing of the game's may come before the card or ask
## whether the game is liked, and no button may call it, since Play shows it only so often and a button that
## sometimes does nothing reads as broken. So the card comes unasked at those breaks, and the Rate buttons in
## About and on the ending open the Play page.
##
## The kit expects from the game: in `Save`, `rate_asked` and `rated`, with `set_rating(asked, rated)`,
## and its Play page as `GameShare.STORE`.

## How many levels solved before each ask.
const MILESTONES: Array[int] = [20, 60, 120, 200, 300, 400]

static var _asked_this_session: bool = false

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

## Next level's way on: the review card at a milestone, otherwise maybe an ad.
static func or_ad(host: Node, on_done: Callable, after_guide: bool = false) -> void:
	var milestone: int = due()
	if milestone == 0:
		Ads.maybe_interstitial(on_done, after_guide)
		return
	ask(milestone, on_done)

## The ending asks once more, unless this session has asked already.
static func at_end() -> void:
	if open_to_asking() and not _asked_this_session:
		ask(maxi(Ads.solved(), Save.rate_asked), Callable())

static func ask(milestone: int, then: Callable) -> void:
	_asked_this_session = true
	Save.set_rating(milestone, false)
	PlayCore.review(then)

static func button_text() -> String:
	return "Rate %s" % Brand.NAME

## The Rate buttons. Play never says whether a rating came of it, so the card stops after this.
static func rate() -> void:
	Save.set_rating(Save.rate_asked, true)
	OS.shell_open(GameShare.STORE)
