class_name Cheers
extends RefCounted

## The game adds its own lines for one, two and three stars as GameShare.CHEERS.

const HEADINGS: Array = [
	["Solved", "Got there", "Done", "Cracked it", "There it is", "Sorted"],
	["Nice one", "Well played", "Smooth", "Sharp", "Good going", "Tidy"],
	["Flawless", "Perfect", "Spotless", "Brilliant", "Masterful", "Immaculate", "Pure class"],
]
## %s is the game's word for a move, in the plural.
const LINES: Array = [
	["Solved is solved.", "A better way is waiting.", "The stars will keep.", "Every solve counts.",
		"Come back for the stars."],
	["Close to perfect.", "Three stars are in reach.", "So nearly the best way.", "One more go for three stars?"],
	["Not one of your %s wasted.", "As good as it gets.", "Clean from start to finish.", "Nothing left to improve.",
		"The best way there is.", "It could not be better."],
]
const MILESTONES: PackedInt32Array = [10, 25, 50, 75, 100, 150, 200, 250, 300, 350, 400, 450, 500]
## Lines said lately, so none comes back too soon.
const MEMORY: int = 6

static var _recent: PackedStringArray = PackedStringArray()
static var _perfect_run: int = 0
## Its own generator, so what a win says depends on nothing else that rolls dice, and a capture can make
## it say the same thing every time.
static var _dice: RandomNumberGenerator = _rolled()

static func _rolled() -> RandomNumberGenerator:
	var dice: RandomNumberGenerator = RandomNumberGenerator.new()
	dice.randomize()
	return dice

static func pick(moment: Result.Moment, earned: int) -> PackedStringArray:
	_perfect_run = _perfect_run + 1 if earned == 3 else 0
	var heading: String = _fresh(HEADINGS[clampi(earned, 1, 3) - 1])
	var news: String = _news(moment, earned)
	if news == "":
		var pool: Array = []
		pool.append_array(LINES[clampi(earned, 1, 3) - 1])
		pool.append_array(GameShare.CHEERS[clampi(earned, 1, 3) - 1])
		news = _fresh(pool)
		if news.contains("%s"):
			news = news % (moment.unit + "s")
	_remember(news)
	return PackedStringArray([heading, news])

static func _news(moment: Result.Moment, earned: int) -> String:
	var first: bool = moment.before == 0
	if first and Pack.chapter_of(moment.level) >= 0:
		var opened: int = Unlocks.gate_opened_by(moment.level)
		if opened >= 0:
			return "Chapter %d is open: %s." % [Shown.chapter(opened), Pack.chapter_name(opened)]
	var chapter: int = Pack.chapter_of(moment.level)
	if chapter >= 0 and earned > moment.before:
		var standing: Vector2i = _chapter_standing(chapter)
		var count: int = int(Pack.chapters[chapter]["count"])
		if standing.y == count * 3 and earned == 3:
			return "Chapter %d, every star." % Shown.chapter(chapter)
		if standing.x == count and first:
			return "Chapter %d, every level solved." % Shown.chapter(chapter)
	if first:
		var solved: int = Ads.solved()
		if MILESTONES.has(solved):
			return "That makes %d levels solved." % solved
		if earned == 3 and moment.clean:
			return "First try, and perfect."
	elif earned > moment.before:
		return "Up from %d %s." % [moment.before, "star" if moment.before == 1 else "stars"]
	if _perfect_run >= 3:
		return "%d perfect in a row." % _perfect_run
	return ""

static func _chapter_standing(chapter: int) -> Vector2i:
	var first: int = Pack.chapter_first(chapter)
	var out: Vector2i = Vector2i.ZERO
	for i: int in range(first, first + int(Pack.chapters[chapter]["count"])):
		out.x += 1 if Save.best(i) > 0 else 0
		out.y += Save.best(i)
	return out

## For a capture that stages one win after another and wants each to come out the same.
static func forget() -> void:
	_recent = PackedStringArray()
	_perfect_run = 0
	_dice.seed = 1

static func _fresh(pool: Array) -> String:
	var unsaid: Array = pool.filter(func(line: Variant) -> bool: return not _recent.has(String(line)))
	var from: Array = unsaid if not unsaid.is_empty() else pool
	var chosen: String = String(from[_dice.randi() % from.size()])
	_remember(chosen)
	return chosen

static func _remember(line: String) -> void:
	if _recent.has(line):
		return
	_recent.append(line)
	if _recent.size() > MEMORY * 2:
		_recent.remove_at(0)
