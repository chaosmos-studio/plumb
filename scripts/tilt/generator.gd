class_name TiltGenerator
extends RefCounted

## Levels by rejection, then a run picked from each pool to follow the ramp or hold the plateau (MATH.md sections 3,
## 6, 8 to 10 and 16).

## `rule` names the tile a chapter's levels must need: a TiltBoard.TILE_NAMES entry, "plug", "stone", "ice",
## "number", "wrap" or "locked", "" for the opening chapters, whose rules are the game's own, or "mix" for a
## chapter that needs every rule on each board. A phase is: count, width, height, colours, marbles, wall
## density, pits, par min, par max, then the marks it places: a count per tile name (a pair for "portal", a
## switch and its hatch for "switch", a key and its lock for "key"), "stone" for stones, "plug" true to make
## every hole a plug, with as many holes of a colour as it has marbles, "ice" for icy holes, "number" for
## numbered marbles, "wrap" 1 for one axis that wraps and 2 for both, "locked" for a turning lock, and "mix"
## for that many rules drawn from MIX. A chapter with "after_hard" was added after the Hard levels were shelved:
## it has no Hard counterpart, and it is made after every other chapter (making_order), so adding it moved none.
const CHAPTERS: Array = [
	{"name": "Roll home", "rule": "", "line": "Swipe to tilt the board", "phases": [
		[1, 4, 4, 1, 1, 0.10, 0, 1, 1, {}],
		[2, 4, 4, 1, 1, 0.12, 0, 1, 3, {}],
		[5, 5, 5, 1, 2, 0.16, 0, 2, 4, {}],
		[12, 5, 6, 2, 2, 0.14, 0, 2, 5, {}],
	]},
	{"name": "Three colours", "rule": "", "line": "Three colours, three holes to share out", "phases": [
		[10, 5, 6, 3, 3, 0.14, 0, 3, 6, {}],
		[10, 6, 6, 3, 3, 0.15, 0, 4, 7, {}],
	]},
	{"name": "Pits", "rule": "", "line": "Square pits swallow any marble", "phases": [
		[10, 6, 6, 3, 3, 0.15, 1, 4, 7, {}],
		[10, 6, 6, 3, 4, 0.15, 1, 5, 8, {}],
	]},
	{"name": "Four colours", "rule": "", "line": "Four colours, and more room to roll", "phases": [
		[10, 6, 7, 4, 4, 0.16, 1, 5, 8, {}],
		[10, 7, 7, 4, 5, 0.16, 1, 6, 9, {}],
	]},
	{"name": "Stop pads", "rule": "stop", "line": "A marble that rolls onto a pad stops on it", "phases": [
		[10, 6, 7, 3, 4, 0.15, 1, 6, 9, {"stop": 2}],
		[10, 7, 7, 3, 5, 0.16, 1, 6, 10, {"stop": 3}],
	]},
	{"name": "One-way gates", "rule": "gate", "line": "A gate lets marbles through one way only", "phases": [
		[10, 6, 7, 3, 4, 0.14, 1, 7, 10, {"gate": 2, "stop": 1}],
		[10, 7, 7, 3, 5, 0.15, 1, 7, 11, {"gate": 3, "stop": 1}],
	]},
	{"name": "Plugs", "rule": "plug", "line": "A ringed hole takes one marble, then closes", "phases": [
		[10, 7, 7, 3, 5, 0.15, 1, 9, 11, {"plug": true}],
		[10, 7, 7, 3, 5, 0.15, 1, 9, 12, {"plug": true, "stop": 1}],
	]},
	{"name": "Colour gates", "rule": "door", "line": "A coloured gate only lets its own colour through", "phases": [
		[10, 7, 7, 3, 5, 0.15, 1, 9, 13, {"door": 2}],
		[10, 7, 8, 3, 5, 0.15, 1, 9, 13, {"door": 3, "plug": true}],
	]},
	{"name": "Paint", "rule": "paint", "line": "Rolling over paint changes a marble's colour", "phases": [
		[10, 7, 7, 3, 5, 0.15, 1, 9, 13, {"paint": 2}],
		[10, 7, 8, 3, 5, 0.15, 1, 9, 14, {"paint": 2, "door": 1}],
	]},
	{"name": "Bouncy blocks", "rule": "bounce", "line": "A marble bounces back the way it came",
		"after_hard": true, "phases": [
		[10, 7, 7, 3, 5, 0.15, 1, 12, 13, {"bounce": 2}],
		[10, 7, 8, 3, 5, 0.15, 1, 12, 13, {"bounce": 3, "stop": 1}],
	]},
	{"name": "Cracked floor", "rule": "crack", "line": "Cracked floor gives way once a marble rolls off it", "phases": [
		[10, 7, 7, 3, 5, 0.14, 1, 10, 14, {"crack": 3}],
		[10, 7, 8, 3, 5, 0.15, 2, 10, 14, {"crack": 4, "stop": 1}],
	]},
	{"name": "Stones", "rule": "stone", "line": "Stones roll like marbles, never drop in, and fill a pit", "search": 30000,
		"phases": [
		[10, 7, 8, 3, 5, 0.14, 2, 14, 24, {"stone": 2}],
		[10, 8, 8, 3, 6, 0.15, 2, 14, 24, {"stone": 2, "crack": 2}],
	]},
	{"name": "Portals", "rule": "portal", "line": "A marble that rolls into a portal comes out of its twin", "search": 30000,
		"phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"portal": 1}],
		[10, 8, 8, 3, 6, 0.15, 1, 14, 24, {"portal": 2, "gate": 1}],
	]},
	{"name": "Bumpers", "rule": "bumper", "line": "A bumper turns a rolling marble a quarter", "search": 30000, "phases": [
		[10, 8, 8, 3, 5, 0.14, 1, 14, 24, {"bumper": 3}],
		[10, 8, 8, 3, 6, 0.15, 1, 14, 24, {"bumper": 3, "portal": 1}],
	]},
	{"name": "Switches", "rule": "switch", "line": "A door is open while something rests on its switch", "search": 30000,
		"phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"switch": 1, "stone": 1}],
		[10, 8, 8, 3, 6, 0.15, 1, 14, 24, {"switch": 2, "stone": 1}],
	]},
	{"name": "Keys and locks", "rule": "key", "line": "Rolling over a key opens every lock of its colour", "search": 30000,
		"phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"key": 1, "door": 1}],
		[10, 8, 8, 3, 6, 0.15, 1, 14, 24, {"key": 2, "door": 1}],
	]},
	{"name": "Blinking walls", "rule": "blink", "line": "Blinking walls switch after every tilt that moves",
		"search": 30000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"blink": 4}],
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"blink": 4, "switch": 1}],
	]},
	{"name": "Conveyors", "rule": "conveyor", "line": "Once the board stops, a conveyor carries its marble on",
		"search": 30000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"conveyor": 3}],
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"conveyor": 3, "bumper": 2}],
	]},
	{"name": "Springs", "rule": "spring", "line": "A spring jumps a marble over the next square",
		"search": 30000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"spring": 3}],
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"spring": 3, "crack": 3}],
	]},
	{"name": "Wrap edges", "rule": "wrap", "line": "Off one edge and back in at the other",
		"search": 30000, "phases": [
		[10, 8, 8, 3, 5, 0.17, 1, 14, 24, {"wrap": 1}],
		[10, 8, 8, 3, 5, 0.17, 1, 14, 24, {"wrap": 1, "portal": 1}],
	]},
	{"name": "Magnets", "rule": "magnet", "line": "A marble stops as soon as it rolls beside a magnet",
		"search": 30000, "phases": [
		[10, 8, 8, 3, 5, 0.14, 1, 14, 24, {"magnet": 2}],
		[10, 8, 8, 3, 5, 0.14, 1, 14, 24, {"magnet": 2, "conveyor": 2}],
	]},
	{"name": "Numbered marbles", "rule": "number", "line": "Numbered marbles drop in order, 1 first",
		"search": 40000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"number": 3}],
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"number": 3, "plug": true}],
	]},
	{"name": "Glass posts", "rule": "glass", "line": "Glass stops a marble once, then shatters",
		"search": 40000, "phases": [
		[10, 8, 8, 3, 5, 0.14, 1, 14, 24, {"glass": 3}],
		[10, 8, 8, 3, 5, 0.14, 1, 14, 24, {"glass": 3, "stone": 1}],
	]},
	{"name": "Ice holes", "rule": "ice", "line": "An icy hole only takes a marble that stops on it",
		"search": 40000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"ice": 2}],
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"ice": 3, "stop": 2}],
	]},
	{"name": "Turning lock", "rule": "locked", "line": "One way is locked, and the lock turns after every tilt",
		"search": 40000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"locked": 1}],
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"locked": 1, "spring": 2}],
	]},
	{"name": "Everything", "rule": "mix", "line": "Every rule so far, mixed", "search": 40000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"mix": 2}],
		[10, 8, 8, 3, 5, 0.15, 1, 14, 24, {"mix": 3}],
	]},
]
const MIX: Array[Dictionary] = [{"stop": 2}, {"gate": 2}, {"door": 1}, {"paint": 1}, {"crack": 3}, {"stone": 1},
	{"portal": 1}, {"bumper": 2}, {"switch": 1}, {"key": 1}, {"blink": 3}, {"conveyor": 2}, {"spring": 2},
	{"wrap": 1}, {"magnet": 2}, {"number": 3}, {"glass": 2}, {"ice": 2}, {"locked": 1}]
const STONE_NAME: String = "stone"
const PAIRED: Array[String] = ["portal", "switch", "key"]
## The rule tiles that stand on one cell alone, which `prune` takes off a board where they change nothing.
const SINGLE: Array[int] = [TiltBoard.Tile.STOP, TiltBoard.Tile.GATE, TiltBoard.Tile.DOOR, TiltBoard.Tile.PAINT,
	TiltBoard.Tile.CRACK, TiltBoard.Tile.BUMPER, TiltBoard.Tile.BLINK, TiltBoard.Tile.CONVEYOR, TiltBoard.Tile.SPRING,
	TiltBoard.Tile.MAGNET, TiltBoard.Tile.GLASS, TiltBoard.Tile.BOUNCE]
## The ramp runs over the whole game as planned, not the chapters made so far, so adding chapters later
## leaves the levels made now as they are (MATH.md sections 6 and 8).
const RAMP_LEVELS: int = 500
const FIRST_PAR: float = 1.0
const LAST_PAR: float = 16.0
const FIRST_BITS: float = 1.6
const LAST_BITS: float = 28.0
const RAMP_POWER: float = 0.55
## How much a move of par off the ramp costs against a bit of difficulty off it.
const PAR_WEIGHT: float = 2.0
## What repeating the last level's bits exactly costs, so the ramp takes a step over a plateau, and the
## most levels in a row that may share one value.
const FLAT: float = 0.5
const RUN: int = 5
## A pool keeps candidates within this many bits of its phase's stretch of the ramp.
const BAND: float = 1.0
## Candidates pooled per level a phase ships, so the ramp has something to choose from.
const POOL: int = 6
## Positions the solver may explore for one candidate. One that needs more is too tangled for its phase.
const SEARCH_LIMIT: int = 12000
## Proposals tried per level a phase ships before its pool closes, full or not. Chapters from TILED_FROM on
## try ATTEMPTS_TILED, since pruning their tiles turns down far more proposals (MATH.md section 8).
const ATTEMPTS: int = 1500
const ATTEMPTS_TILED: int = 4500
const TILED_FROM: int = 4
## Chapters from this one on pool in seeded batches of BATCH that a Farm may run anywhere, merged in batch
## order, so the levels depend only on the seed (MATH.md section 10). The chapters before keep the
## one-at-a-time way they were made, so a full run still writes the levels already shipped.
const PARALLEL_FROM: int = 4
const BATCH: int = 24
## Chapters from this one on ship in TiltDifficulty.before's order, par first, rather than with par and
## bits each never falling (MATH.md section 10). Every level before them keeps both, which also keeps this.
## Stones, the chapter these were set at on the climb.
const BY_PAR_FROM: int = 11
## From this chapter on a phase pools only boards at the last level's par or one more, and POOL_LATE per
## level rather than POOL, so par climbs slowly (MATH.md section 10).
const CLOSE_FROM: int = 11
const POOL_LATE: int = 8
## From this chapter on the main path stops climbing: every level sits in a narrow band at level PLATEAU_LEVEL's
## difficulty, on a board no larger than that level's and with no more marbles. The climb these chapters had
## before ships as the Hard levels (MATH.md section 16).
const PLATEAU_FROM: int = 9
## The level, counted from 1, whose par and bits are the plateau's floor.
const PLATEAU_LEVEL: int = 160
## How far above the floor a plateau level may sit, in moves of par and in bits.
const PLATEAU_PARS: int = 1
const PLATEAU_BITS: float = 1.5
## The share of that band one chapter aims to climb through, from the floor at its first level.
const PLATEAU_RISE: float = 0.5
## The chapter rule that leaves a random player three tilts where every other board offers four.
const THREE_WAY: String = "locked"

class Candidate:
	var board: TiltBoard
	var measure: TiltDifficulty
	var views: TiltNovelty.Views
	var order: int
	## The phase whose pool it came from, which a plateau chapter's one run keeps it to.
	var phase: int = 0

	func _init(b: TiltBoard, m: TiltDifficulty, v: TiltNovelty.Views, n: int) -> void:
		board = b
		measure = m
		views = v
		order = n

## Runs each batch here when asked. tools/generate_levels.gd puts in its place one that spreads them over
## worker processes, and its `take(b)` must give batch b's candidates in the order they were found.
class Farm:
	extends RefCounted
	var _job: Dictionary

	func start(job: Dictionary) -> void:
		_job = job

	func take(b: int) -> Array[Candidate]:
		return TiltGenerator.batch(_job, b)

	func stop() -> void:
		pass

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var farm: Farm = Farm.new()
## False makes every chapter climb the ramp, as the Hard levels were made.
var plateau: bool = true
## Each a TiltBoard.to_dict() with its "par", in the order made, and each one's place in the game (shipped()).
var levels: Array[Dictionary] = []
var placed: PackedInt32Array = PackedInt32Array()
## What the last phase measured, for reporting: pool size and attempts used.
var pooled: int = 0
var attempts: int = 0
var _made: Array[Candidate] = []
## Levels outside this run that none of its levels may replay: the Hard levels.
var _avoid: Array[Candidate] = []
## A plateau chapter's pools so far, each candidate tagged with its phase, until its last phase picks one run
## through them all.
var _held: Array[Candidate] = []

func _init(seed_value: int) -> void:
	rng.seed = seed_value

static func level_count() -> int:
	var n: int = 0
	for c: int in range(CHAPTERS.size()):
		n += chapter_size(c)
	return n

static func chapter_size(c: int) -> int:
	var n: int = 0
	for phase: Array in CHAPTERS[c]["phases"]:
		n += int(phase[0])
	return n

static func chapter_list() -> Array:
	var out: Array = []
	for c: int in range(CHAPTERS.size()):
		var entry: Dictionary = {"name": CHAPTERS[c]["name"], "line": CHAPTERS[c]["line"], "count": chapter_size(c)}
		if CHAPTERS[c].get("after_hard", false):
			entry["after_hard"] = true
		out.append(entry)
	return out

## The chapters in the order they are made: by number, then the ones added after the Hard levels were shelved,
## from where the others leave the random stream, so adding a chapter never changes one made before it (MATH.md
## section 22).
static func making_order() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for late: bool in [false, true]:
		for c: int in range(CHAPTERS.size()):
			if bool(CHAPTERS[c].get("after_hard", false)) == late:
				out.append(c)
	return out

## The first level (0-based) of chapter `c`.
static func chapter_start(c: int) -> int:
	var n: int = 0
	for k: int in range(c):
		n += chapter_size(k)
	return n

## The chapter level `i` (0-based) sits in.
static func chapter_at(i: int) -> int:
	var end: int = 0
	for c: int in range(CHAPTERS.size()):
		end += chapter_size(c)
		if i < end:
			return c
	return CHAPTERS.size() - 1

## A phase as it is made. `floor` is empty on the ramp, and on the plateau holds the floor level's par, bits, width,
## height and marbles: the board shrinks to fit inside it and par may sit only in the band.
static func phase_of(chapter: int, p: int, floor: Dictionary = {}) -> Array:
	var phase: Array = (CHAPTERS[chapter]["phases"][p] as Array).duplicate()
	if floor.is_empty():
		return phase
	phase[1] = mini(int(phase[1]), int(floor["width"]))
	phase[2] = mini(int(phase[2]), int(floor["height"]))
	phase[4] = mini(int(phase[4]), int(floor["marbles"]))
	phase[7] = int(floor["par"])
	phase[8] = int(floor["par"]) + PLATEAU_PARS
	return phase

## How far along the ramp level `i` (0-based) is, from 0 to 1.
static func progress(i: int) -> float:
	return pow(float(i) / float(RAMP_LEVELS - 1), RAMP_POWER)

static func target_par(i: int) -> float:
	return FIRST_PAR + (LAST_PAR - FIRST_PAR) * progress(i)

static func target_bits(i: int) -> float:
	return FIRST_BITS + (LAST_BITS - FIRST_BITS) * progress(i)

## `made` in the order it was made, `places` each level's place in the game, and `state` the RNG state saved once
## they were made, so the chapters after come out exactly as a full run would make them (MATH.md section 9).
func resume(made: Array, places: PackedInt32Array, state: int) -> void:
	for k: int in range(made.size()):
		var level: Dictionary = made[k]
		var board: TiltBoard = TiltBoard.from_dict(level)
		var m: TiltDifficulty = TiltDifficulty.of(board, int(level["par"]), 200000)
		levels.append(level)
		placed.append(places[k])
		_made.append(Candidate.new(board, m, TiltNovelty.views(board, m.path), _made.size()))
	rng.state = state

## The levels made so far in the game's order.
func shipped() -> Array[Dictionary]:
	var order: Array[int] = []
	for k: int in range(levels.size()):
		order.append(k)
	order.sort_custom(func(a: int, b: int) -> bool: return placed[a] < placed[b])
	var out: Array[Dictionary] = []
	for k: int in order:
		out.append(levels[k])
	return out

## Levels this run must not replay though it does not make them, each a TiltBoard.to_dict() with its "par": the Hard
## levels. A route replays only a level of the same par (MATH.md section 4), so a level past `deepest`, the most par
## this run makes, is kept for its layout alone and never solved.
func reserve(others: Array, deepest: int = 1 << 30) -> void:
	for entry: Variant in others:
		var level: Dictionary = entry
		var board: TiltBoard = TiltBoard.from_dict(level)
		var path: PackedInt32Array = PackedInt32Array()
		if int(level["par"]) <= deepest:
			path = TiltSolver.new().solve(board, 200000)
		_avoid.append(Candidate.new(board, null, TiltNovelty.views(board, path), 0))

## Call once the levels after the opening are made. The showcase has a random stream of its own, so those
## levels come out the same either way.
func open() -> bool:
	var count: int = TiltShowcase.SLOTS.size()
	var picks: Array[Candidate] = TiltShowcase.new(rng.seed).make(_made.slice(count))
	if picks.is_empty():
		return false
	for k: int in range(count):
		var level: Dictionary = picks[k].board.to_dict()
		level["par"] = picks[k].measure.par
		levels[k] = level
		_made[k] = picks[k]
	return true

func made() -> Array[TiltDifficulty]:
	var out: Array[TiltDifficulty] = []
	for c: Candidate in _made:
		out.append(c.measure)
	return out

## False when the pool cannot hold a run. On the plateau a phase only pools, and a chapter's last phase picks one
## run through all its phases' pools (MATH.md section 16).
func add_phase(chapter: int, p: int) -> bool:
	var flat: bool = plateau and chapter >= PLATEAU_FROM
	var floor: Dictionary = floor_level() if flat else {}
	var phase: Array = phase_of(chapter, p, floor)
	var rule: String = CHAPTERS[chapter]["rule"]
	var count: int = phase[0]
	var par_max: int = phase[8]
	# Deeper chapters may search further, but the ones before keep the limit they were made with.
	var limit: int = int(CHAPTERS[chapter].get("search", SEARCH_LIMIT))
	# Where this phase's levels go in the game, which a chapter made late is not where the making has got to.
	var first: int = chapter_start(chapter)
	for k: int in placed:
		first += 1 if chapter_at(k) == chapter else 0
	# The level made last, which for every chapter but a late one is also the one before it in the game.
	var last: TiltDifficulty = null if _made.is_empty() else _made[-1].measure
	var by_par: bool = flat or chapter >= BY_PAR_FROM
	# On the plateau a chapter starts again from the floor, and its own order is the chapter's one run's to keep,
	# so no phase pools above a level.
	var above: TiltDifficulty = null if flat else last
	# Levels that ran ahead of the ramp carry the window up with them, or it would close above the last one.
	# Ordered by par first, bits may start lower again when par steps up, so there is no window on bits.
	var ahead: float = 0.0 if last == null else maxf(last.bits - target_bits(first), 0.0)
	var lo: float = -1.0 if by_par else target_bits(first) + ahead - BAND
	var hi: float = 1e9 if by_par else target_bits(first + count - 1) + ahead + BAND
	if flat:
		lo = float(floor["bits"]) * bits_scale(chapter)
		hi = lo + PLATEAU_BITS * bits_scale(chapter)
	var close: bool = chapter >= CLOSE_FROM and last != null and not flat
	var cap: int = mini(par_max, last.par + 1) if close else par_max
	var size: int = count * (POOL_LATE if chapter >= CLOSE_FROM or flat else POOL)
	var pool: Array[Candidate] = []
	attempts = 0
	if chapter < PARALLEL_FROM:
		while pool.size() < size and attempts < count * ATTEMPTS:
			attempts += 1
			_keep(_try(_propose(phase), phase, rule, limit, lo, hi, above, by_par, cap), pool)
	else:
		_fill(pool, chapter, p, floor, lo, hi, above, by_par, cap, size)
	pooled = pool.size()
	# A plateau phase's levels may only come from its own pool, so the boards still grow phase by phase.
	var allowed: PackedInt32Array = PackedInt32Array()
	if flat:
		for c: Candidate in pool:
			c.phase = p
		_held.append_array(pool)
		if p < (CHAPTERS[chapter]["phases"] as Array).size() - 1:
			return true
		pool = _held.duplicate()
		_held.clear()
		count = chapter_size(chapter)
		for q: int in range((CHAPTERS[chapter]["phases"] as Array).size()):
			for k: int in range(int(CHAPTERS[chapter]["phases"][q][0])):
				allowed.append(q)
	# A phase's first level aims where the level before it aimed, except where the plateau starts a chapter again.
	var aim_par: PackedFloat64Array = PackedFloat64Array()
	var aim_bits: PackedFloat64Array = PackedFloat64Array()
	for k: int in range(count):
		var at: int = first + k if k > 0 or flat else maxi(first - 1, 0)
		aim_par.append(_aim_par(at, floor))
		aim_bits.append(_aim_bits(at, floor))
	var run: Array[Candidate] = _run(pool, aim_par, aim_bits, last, _streak(by_par), by_par, allowed)
	if run.is_empty():
		return false
	for k: int in range(run.size()):
		var level: Dictionary = run[k].board.to_dict()
		level["par"] = run[k].measure.par
		levels.append(level)
		placed.append(first + k)
		_made.append(run[k])
	return true

## The plateau's floor and its most: level PLATEAU_LEVEL's par and bits, board size and marbles.
func floor_level() -> Dictionary:
	var c: Candidate = _made[PLATEAU_LEVEL - 1]
	return {"par": c.measure.par, "bits": c.measure.bits, "width": c.board.width, "height": c.board.height,
		"marbles": c.board.marbles_left()}

## Where level `i` (0-based) aims: the ramp, or on the plateau a climb through PLATEAU_RISE of the band that starts
## from the floor at each chapter's first level.
func _aim_par(i: int, floor: Dictionary) -> float:
	if floor.is_empty():
		return target_par(i)
	return float(floor["par"]) + PLATEAU_PARS * _rise(i)

func _aim_bits(i: int, floor: Dictionary) -> float:
	if floor.is_empty():
		return target_bits(i)
	return (float(floor["bits"]) + PLATEAU_BITS * _rise(i)) * bits_scale(chapter_at(i))

## What a plateau's bits are measured in for chapter `c`: with one way always locked, a random player has three
## tilts where any other board offers four, so the most luck a tilt can ask is log2(3) bits instead of 2, and
## the floor and band shrink by that share (MATH.md section 16).
static func bits_scale(c: int) -> float:
	return log(3.0) / log(4.0) if CHAPTERS[c]["rule"] == THREE_WAY else 1.0

static func _rise(i: int) -> float:
	var c: int = chapter_at(i)
	return PLATEAU_RISE * float(i - chapter_start(c)) / float(maxi(chapter_size(c) - 1, 1))

static func _try(board: TiltBoard, phase: Array, rule: String, limit: int, lo: float, hi: float,
		last: TiltDifficulty, by_par: bool = false, cap: int = -1) -> Candidate:
	if board == null or not _open(board):
		return null
	var deepest: int = cap if cap > 0 else int(phase[8])
	# The plain search is cheaper, so a board outside the window never pays for the measure. It counts
	# positions a little differently, so the chapters before BY_PAR_FROM keep the one way they were made.
	if by_par and TiltSolver.new().solve(board, limit, deepest).size() < int(phase[7]):
		return null
	var m: TiltDifficulty = TiltDifficulty.of(board, deepest, limit)
	if not _fits(m, phase, lo, hi, last, by_par):
		return null
	# A tile that never changes the best way through still blocks wrong ones, so taking it off can make the
	# board easier: it is measured again without it, and has to fit the window as it is.
	var kept: TiltBoard = prune(board, m.par, limit)
	if kept.tiles != board.tiles:
		board = kept
		m = TiltDifficulty.of(board, deepest, limit)
		if not _fits(m, phase, lo, hi, last, by_par):
			return null
	if rule != "" and not needs(board, rule, m.par, limit):
		return null
	return Candidate.new(board, m, TiltNovelty.views(board, m.path), 0)

static func _fits(m: TiltDifficulty, phase: Array, lo: float, hi: float, last: TiltDifficulty, by_par: bool) -> bool:
	if m.par < int(phase[7]) or m.bits < lo or m.bits > hi:
		return false
	if last != null and (m.before(last) if by_par else (m.par < last.par or m.easier_than(last))):
		return false
	return int(phase[6]) <= 0 or m.risk > 0.0

## Goes round until nothing more comes off, since taking one tile off can make another matter or stop
## mattering. A search that gives up proves nothing, so that tile stays (MATH.md section 8).
static func prune(board: TiltBoard, par: int, limit: int = SEARCH_LIMIT) -> TiltBoard:
	var out: TiltBoard = board.copy()
	var changed: bool = true
	while changed:
		changed = false
		for i: int in range(out.tiles.size()):
			if not SINGLE.has(out.tiles[i]):
				continue
			var trial: TiltBoard = _without_tile(out, i)
			if TiltSolver.new().solve(trial, limit, par).size() == par:
				out = trial
				changed = true
	return out

static func _without_tile(board: TiltBoard, i: int) -> TiltBoard:
	var out: TiltBoard = board.copy()
	out.tiles[i] = TiltBoard.Tile.NONE
	return out

func _keep(c: Candidate, pool: Array[Candidate]) -> void:
	if c == null or _replays(c.views, pool):
		return
	c.order = pool.size()
	pool.append(c)

## Batches are merged strictly in batch order, so the pool never depends on where a batch ran. `cap` is the
## deepest par searched for.
func _fill(pool: Array[Candidate], chapter: int, p: int, floor: Dictionary, lo: float, hi: float, last: TiltDifficulty,
		by_par: bool, cap: int, size: int) -> void:
	var count: int = CHAPTERS[chapter]["phases"][p][0]
	var batches: int = ceili(float(count * (ATTEMPTS_TILED if chapter >= TILED_FROM else ATTEMPTS)) / BATCH)
	var job: Dictionary = {"chapter": chapter, "phase": p, "seed": rng.randi(), "batches": batches,
		"lo": lo, "hi": hi, "cap": cap,
		"last": {} if last == null else {"par": last.par, "bits": last.bits, "states": last.states}}
	# Written only where they differ from what the chapter alone implies, so a job for the ramp is as it was.
	if not floor.is_empty():
		job["floor"] = floor
	if by_par != (chapter >= BY_PAR_FROM):
		job["by_par"] = by_par
	farm.start(job)
	for b: int in range(batches):
		if pool.size() >= size:
			break
		attempts += BATCH
		for c: Candidate in farm.take(b):
			if pool.size() < size:
				_keep(c, pool)
	farm.stop()

## Seeded from the job's seed and `b` alone, so a batch comes out the same wherever it runs.
static func batch(job: Dictionary, b: int) -> Array[Candidate]:
	var chapter: int = job["chapter"]
	var phase: Array = phase_of(chapter, int(job["phase"]), job.get("floor", {}))
	var rule: String = CHAPTERS[chapter]["rule"]
	var limit: int = int(CHAPTERS[chapter].get("search", SEARCH_LIMIT))
	var last: TiltDifficulty = null
	var was: Dictionary = job["last"]
	if not was.is_empty():
		last = TiltDifficulty.new()
		last.par = int(was["par"])
		last.bits = float(was["bits"])
		last.states = int(was["states"])
	var own: TiltGenerator = TiltGenerator.new(hash([int(job["seed"]), b]))
	var found: Array[Candidate] = []
	for k: int in range(BATCH):
		var c: Candidate = _try(own._propose(phase), phase, rule, limit, float(job["lo"]), float(job["hi"]), last,
			bool(job.get("by_par", chapter >= BY_PAR_FROM)), int(job.get("cap", phase[8])))
		if c != null:
			found.append(c)
	return found

## Floats must be written at full precision, since equal bits are compared exactly.
static func batch_to_json(found: Array[Candidate]) -> Array:
	var out: Array = []
	for c: Candidate in found:
		var m: TiltDifficulty = c.measure
		out.append({"board": c.board.to_dict(), "par": m.par, "bits": m.bits, "risk": m.risk, "states": m.states,
			"path": Array(m.path)})
	return out

static func batch_from_json(data: Array) -> Array[Candidate]:
	var found: Array[Candidate] = []
	for entry: Variant in data:
		var d: Dictionary = entry
		var board: TiltBoard = TiltBoard.from_dict(d["board"])
		var m: TiltDifficulty = TiltDifficulty.new()
		m.par = int(d["par"])
		m.bits = float(d["bits"])
		m.risk = float(d["risk"])
		m.states = int(d["states"])
		m.path = PackedInt32Array(d["path"])
		found.append(Candidate.new(board, m, TiltNovelty.views(board, m.path), 0))
	return found

## The board without its rule must have no solution or a different par. A search that gives up proves
## nothing, so that board is turned down (MATH.md section 8).
static func needs(board: TiltBoard, rule: String, par: int, limit: int = SEARCH_LIMIT) -> bool:
	if rule == "mix":
		var on: PackedStringArray = rules_on(board)
		for r: String in on:
			if not needs(board, r, par, limit):
				return false
		return not on.is_empty()
	var solver: TiltSolver = TiltSolver.new()
	var path: PackedInt32Array = solver.solve(without(board, rule), limit, par)
	if path.is_empty():
		return solver.exhausted(limit)
	return path.size() < par

## Every chapter rule a board carries, by the name `without` takes off.
static func rules_on(board: TiltBoard) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for name: String in TiltBoard.TILE_NAMES:
		if name not in ["", "hatch", "lock"] and board.tiles.has(TiltBoard.TILE_NAMES.find(name)):
			out.append(name)
	if board.plugs.has(1):
		out.append(TiltBoard.PLUG_NAME)
	if board.ice.has(1):
		out.append("ice")
	if board.marble_colour.has(TiltBoard.STONE):
		out.append(STONE_NAME)
	for n: int in board.marble_number:
		if n > 0:
			out.append("number")
			break
	if board.wrap != 0:
		out.append("wrap")
	if board.locked >= 0:
		out.append("locked")
	return out

static func without(board: TiltBoard, rule: String) -> TiltBoard:
	var plain: TiltBoard = board.copy()
	match rule:
		TiltBoard.PLUG_NAME:
			plain.plugs.fill(0)
			return plain
		"ice":
			plain.ice.fill(0)
			return plain
		"number":
			plain.marble_number.fill(0)
			return plain
		"wrap":
			plain.wrap = 0
			return plain
		"locked":
			plain.locked = -1
			return plain
	if rule == STONE_NAME:
		plain.marble_cell = PackedInt32Array()
		plain.marble_colour = PackedInt32Array()
		plain.marble_number = PackedInt32Array()
		for m: int in range(board.marble_cell.size()):
			if not board.is_stone(m):
				plain.marble_cell.append(board.marble_cell[m])
				plain.marble_colour.append(board.marble_colour[m])
				plain.marble_number.append(board.marble_number[m])
		return plain
	# A switch goes with its hatch, so the door is simply open, and a key goes with its lock.
	var gone: Array[int] = [TiltBoard.TILE_NAMES.find(rule)]
	if rule == "switch":
		gone.append(TiltBoard.Tile.HATCH)
	elif rule == "key":
		gone.append(TiltBoard.Tile.LOCK)
	for i: int in range(plain.tiles.size()):
		if gone.has(plain.tiles[i]):
			plain.tiles[i] = TiltBoard.Tile.NONE
	return plain

func _replays(v: TiltNovelty.Views, pool: Array[Candidate]) -> bool:
	for c: Candidate in _made:
		if TiltNovelty.clash(c.views, v) != "":
			return true
	for c: Candidate in _avoid:
		if TiltNovelty.clash(c.views, v) != "":
			return true
	for c: Candidate in _held:
		if TiltNovelty.clash(c.views, v) != "":
			return true
	for c: Candidate in pool:
		if TiltNovelty.clash(c.views, v) != "":
			return true
	return false

## The dynamic program of MATH.md sections 6, 8 and 16: a run through the pool, in order, nearest the aims, one
## level for each. The state is (candidate, how many levels in a row it ends that share its bits). `allowed`, when
## given, names the phase each level must come from.
func _run(pool: Array[Candidate], aim_par: PackedFloat64Array, aim_bits: PackedFloat64Array, last: TiltDifficulty,
		streak: int, by_par: bool = false, allowed: PackedInt32Array = PackedInt32Array()) -> Array[Candidate]:
	var count: int = aim_par.size()
	var sorted: Array[Candidate] = pool.duplicate()
	sorted.sort_custom(func(a: Candidate, b: Candidate) -> bool:
		if by_par and a.measure.par != b.measure.par:
			return a.measure.par < b.measure.par
		if a.measure.easier_than(b.measure):
			return true
		if b.measure.easier_than(a.measure):
			return false
		if a.measure.par != b.measure.par:
			return a.measure.par < b.measure.par
		if a.phase != b.phase:
			return a.phase < b.phase
		return a.order < b.order)
	var n: int = sorted.size()
	var cost: Array[PackedFloat64Array] = []
	var back: Array[PackedInt32Array] = []
	for k: int in range(count):
		var row: PackedFloat64Array = PackedFloat64Array()
		var from: PackedInt32Array = PackedInt32Array()
		row.resize(n * RUN)
		row.fill(INF)
		from.resize(n * RUN)
		from.fill(-1)
		for j: int in range(n):
			if not allowed.is_empty() and sorted[j].phase != allowed[k]:
				continue
			var m: TiltDifficulty = sorted[j].measure
			var miss_par: float = m.par - aim_par[k]
			var miss_bits: float = m.bits - aim_bits[k]
			var here: float = PAR_WEIGHT * miss_par * miss_par + miss_bits * miss_bits
			if k == 0:
				var length: int = streak + 1 if last != null and m.same_as(last, by_par) else 1
				if length <= RUN:
					row[j * RUN + length - 1] = here + (FLAT if length > 1 else 0.0)
				continue
			for i: int in range(j):
				var prior: TiltDifficulty = sorted[i].measure
				if prior.par > m.par:
					continue
				var same: bool = prior.same_as(m, by_par)
				for length: int in range(1, RUN + 1):
					var was: float = cost[k - 1][i * RUN + length - 1]
					var next: int = length + 1 if same else 1
					if was == INF or next > RUN:
						continue
					var total: float = was + here + (FLAT if same else 0.0)
					if total < row[j * RUN + next - 1]:
						row[j * RUN + next - 1] = total
						from[j * RUN + next - 1] = i * RUN + length - 1
		cost.append(row)
		back.append(from)
	var end: int = -1
	var final: PackedFloat64Array = cost[count - 1]
	for s: int in range(n * RUN):
		if final[s] < INF and (end < 0 or final[s] < final[end]):
			end = s
	var run: Array[Candidate] = []
	if end < 0:
		return run
	for k: int in range(count - 1, -1, -1):
		@warning_ignore("integer_division")
		run.push_front(sorted[end / RUN])
		end = back[k][end]
	return run

func _streak(by_par: bool = false) -> int:
	var n: int = 0
	for k: int in range(_made.size() - 1, -1, -1):
		if not _made[k].measure.same_as(_made[-1].measure, by_par):
			break
		n += 1
	return n

## A cheap flood fill (MATH.md section 3). Paint can change a marble's colour on the way, a portal or a
## spring can carry it across a wall, an edge can wrap and a stone can fill a pit in its way, so a board
## with any of those is left to the solver.
static func _open(board: TiltBoard) -> bool:
	if board.tiles.has(TiltBoard.Tile.PAINT) or board.tiles.has(TiltBoard.Tile.PORTAL) or board.marble_colour.has(TiltBoard.STONE):
		return true
	if board.tiles.has(TiltBoard.Tile.SPRING) or board.wrap != 0:
		return true
	for h: int in range(board.holes.size()):
		var colour: int = board.holes[h]
		if colour == TiltBoard.NO_HOLE:
			continue
		var reach: PackedByteArray = PackedByteArray()
		reach.resize(board.cells.size())
		reach[h] = 1
		var queue: PackedInt32Array = PackedInt32Array([h])
		var head: int = 0
		while head < queue.size():
			var at: Vector2i = board.coords(queue[head])
			head += 1
			for d: Vector2i in TiltBoard.DIRS:
				var next: Vector2i = at + d
				if not board.inside(next):
					continue
				var i: int = board.index(next)
				if reach[i] == 0 and board.cells[i] == TiltBoard.Cell.FLOOR:
					reach[i] = 1
					queue.append(i)
		for m: int in range(board.marble_cell.size()):
			if board.marble_colour[m] == colour and reach[board.marble_cell[m]] == 0:
				return false
	return true

func _propose(phase: Array) -> TiltBoard:
	var w: int = phase[1]
	var h: int = phase[2]
	var colours: int = phase[3]
	var marbles: int = phase[4]
	var density: float = phase[5]
	var pits: int = phase[6]
	var extras: Dictionary = phase[9]
	if extras.has("mix"):
		extras = _mixed(int(extras["mix"]))
	var plugged: bool = extras.get("plug", false)
	var tiles: int = 0
	for name: String in extras:
		if name != TiltBoard.PLUG_NAME:
			tiles += int(extras[name]) * (2 if PAIRED.has(name) else 1)
	var holes: int = marbles if plugged else colours
	var board: TiltBoard = TiltBoard.create(w, h)
	var free: Array[int] = []
	for i: int in range(w * h):
		if rng.randf() < density:
			board.cells[i] = TiltBoard.Cell.WALL
		else:
			free.append(i)
	_shuffle(free)
	if free.size() < holes + marbles + pits + tiles + 4:
		return null
	for p: int in range(pits):
		board.cells[free.pop_back()] = TiltBoard.Cell.PIT
	# With plugs every marble needs a hole of its own: one per marble, in the marbles' colours.
	for k: int in range(holes):
		var at: int = free.pop_back()
		board.holes[at] = k % colours
		if plugged:
			board.plugs[at] = 1
	for name: String in TiltBoard.TILE_NAMES:
		if name == "" or not extras.has(name):
			continue
		var tile: int = TiltBoard.TILE_NAMES.find(name)
		for k: int in range(int(extras[name])):
			var value: int = 0
			match tile:
				TiltBoard.Tile.GATE:
					value = rng.randi_range(0, 3)
				TiltBoard.Tile.DOOR, TiltBoard.Tile.PAINT, TiltBoard.Tile.KEY:
					value = rng.randi_range(0, colours - 1)
				TiltBoard.Tile.BUMPER, TiltBoard.Tile.BLINK:
					value = rng.randi_range(0, 1)
				TiltBoard.Tile.CONVEYOR:
					value = rng.randi_range(0, 3)
				TiltBoard.Tile.PORTAL, TiltBoard.Tile.SWITCH:
					value = k
			board.set_tile(board.coords(free.pop_back()), tile as TiltBoard.Tile, value)
			match tile:
				TiltBoard.Tile.PORTAL:
					board.set_tile(board.coords(free.pop_back()), TiltBoard.Tile.PORTAL, value)
				TiltBoard.Tile.SWITCH:
					board.set_tile(board.coords(free.pop_back()), TiltBoard.Tile.HATCH, value)
				TiltBoard.Tile.KEY:
					board.set_tile(board.coords(free.pop_back()), TiltBoard.Tile.LOCK, value)
	for m: int in range(marbles):
		board.add_marble(board.coords(free.pop_back()), m % colours)
	for s: int in range(int(extras.get(STONE_NAME, 0))):
		board.add_marble(board.coords(free.pop_back()), TiltBoard.STONE)
	for m: int in range(mini(int(extras.get("number", 0)), marbles)):
		board.marble_number[m] = m + 1
	if extras.has("ice"):
		var holed: Array[int] = []
		for i: int in range(board.holes.size()):
			if board.holes[i] != TiltBoard.NO_HOLE:
				holed.append(i)
		_shuffle(holed)
		for k: int in range(mini(int(extras["ice"]), holed.size())):
			board.ice[holed[k]] = 1
	if extras.has("wrap"):
		var both: bool = int(extras["wrap"]) >= 2
		board.wrap = TiltBoard.WRAP_X | TiltBoard.WRAP_Y if both else [TiltBoard.WRAP_X, TiltBoard.WRAP_Y][rng.randi_range(0, 1)]
	if extras.has("locked"):
		board.locked = rng.randi_range(0, 3)
	return board

func _mixed(n: int) -> Dictionary:
	var picks: Array[int] = []
	for k: int in range(MIX.size()):
		picks.append(k)
	_shuffle(picks)
	var out: Dictionary = {}
	for k: int in range(n):
		out.merge(MIX[picks[k]])
	return out

## Fisher-Yates against this generator's own RNG, so the level set depends only on the seed.
func _shuffle(values: Array[int]) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = values[i]
		values[i] = values[j]
		values[j] = t
