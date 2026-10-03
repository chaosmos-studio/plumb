class_name TiltGenerator
extends RefCounted

## Makes the level set, one chapter at a time, and each chapter one phase at a time. A phase fixes the board
## size and what goes on it. Random boards for the phase are proposed, solved and measured; the ones that
## solve inside the phase's par window, sit near its stretch of the difficulty ramp, need the chapter's
## rule, and are not a replay of any level already made go into a pool. From the pool the generator picks
## the run of levels that follows the ramp most closely without ever getting easier, in par or in
## difficulty, chapter starts included. Nothing is hand-placed.

## Each chapter is one page of the Levels screen and brings one rule. `rule` names the tile its levels must
## need (TiltBoard.TILE_NAMES, or "plug", "stone", "ice", "number", "wrap", "locked"; "" for the opening
## chapters, whose rules are the game's own; "mix" for a chapter that needs every rule on each board), and
## `line` is how the game teaches it. A phase is: count, width, height, colours, marbles, wall density,
## pits, par min, par max, then the marks it places: a count per tile name (a pair for "portal", a switch
## and its hatch for "switch", a key and its lock for "key"), "stone" for stones, "plug" true to make every
## hole a plug, with as many holes of a colour as it has marbles, "ice" for icy holes, "number" for
## numbered marbles, "wrap" 1 for one axis that wraps and 2 for both, "locked" for a turning lock,
## and "mix" for that many rules drawn from MIX.
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
	{"name": "Cracked floor", "rule": "crack", "line": "Cracked floor gives way once a marble rolls off it", "phases": [
		[10, 7, 7, 3, 5, 0.14, 1, 10, 14, {"crack": 3}],
		[10, 7, 8, 3, 5, 0.15, 2, 10, 14, {"crack": 4, "stop": 1}],
	]},
	{"name": "Stones", "rule": "stone", "line": "Stones roll like marbles, never drop in, and fill a pit", "search": 20000,
		"phases": [
		[10, 7, 8, 3, 5, 0.14, 2, 14, 17, {"stone": 2}],
		[10, 8, 8, 3, 6, 0.15, 2, 15, 17, {"stone": 2, "crack": 2}],
	]},
	{"name": "Portals", "rule": "portal", "line": "A marble that rolls into a portal comes out of its twin", "search": 20000,
		"phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 15, 17, {"portal": 1}],
		[10, 8, 8, 3, 6, 0.15, 1, 15, 18, {"portal": 2, "gate": 1}],
	]},
	{"name": "Bumpers", "rule": "bumper", "line": "A bumper turns a rolling marble a quarter", "search": 20000, "phases": [
		[10, 8, 8, 3, 5, 0.14, 1, 15, 18, {"bumper": 3}],
		[10, 8, 8, 3, 6, 0.15, 1, 15, 18, {"bumper": 3, "portal": 1}],
	]},
	{"name": "Switches", "rule": "switch", "line": "A door is open while something rests on its switch", "search": 20000,
		"phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 17, 19, {"switch": 1, "stone": 1}],
		[10, 8, 8, 3, 6, 0.15, 1, 17, 19, {"switch": 2, "stone": 1}],
	]},
	{"name": "Keys and locks", "rule": "key", "line": "Rolling over a key opens every lock of its colour", "search": 20000,
		"phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 17, 19, {"key": 1, "door": 1}],
		[10, 8, 8, 3, 6, 0.15, 1, 17, 19, {"key": 2, "door": 1}],
	]},
	{"name": "Blinking walls", "rule": "blink", "line": "Blinking walls switch after every tilt that moves",
		"search": 24000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 16, 18, {"blink": 4}],
		[10, 8, 8, 3, 5, 0.15, 1, 16, 18, {"blink": 4, "switch": 1}],
	]},
	{"name": "Conveyors", "rule": "conveyor", "line": "Once the board stops, a conveyor carries its marble on",
		"search": 24000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 16, 18, {"conveyor": 3}],
		[10, 8, 8, 3, 5, 0.15, 1, 16, 18, {"conveyor": 3, "bumper": 2}],
	]},
	{"name": "Springs", "rule": "spring", "line": "A spring jumps a marble over the next square",
		"search": 24000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 16, 18, {"spring": 3}],
		[10, 8, 8, 3, 5, 0.15, 1, 16, 18, {"spring": 3, "crack": 3}],
	]},
	{"name": "Wrap edges", "rule": "wrap", "line": "Off one edge and back in at the other",
		"search": 24000, "phases": [
		[10, 8, 8, 3, 5, 0.17, 1, 16, 18, {"wrap": 1}],
		[10, 8, 8, 3, 5, 0.17, 1, 16, 19, {"wrap": 1, "portal": 1}],
	]},
	{"name": "Magnets", "rule": "magnet", "line": "A marble stops as soon as it rolls beside a magnet",
		"search": 24000, "phases": [
		[10, 8, 8, 3, 5, 0.14, 1, 16, 19, {"magnet": 2}],
		[10, 8, 8, 3, 5, 0.14, 1, 16, 19, {"magnet": 2, "conveyor": 2}],
	]},
	{"name": "Numbered marbles", "rule": "number", "line": "Numbered marbles drop in order, 1 first",
		"search": 24000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 16, 19, {"number": 3}],
		[10, 8, 8, 3, 5, 0.15, 1, 16, 19, {"number": 3, "plug": true}],
	]},
	{"name": "Glass posts", "rule": "glass", "line": "Glass stops a marble once, then shatters",
		"search": 24000, "phases": [
		[10, 8, 8, 3, 5, 0.14, 1, 16, 19, {"glass": 3}],
		[10, 8, 8, 3, 5, 0.14, 1, 16, 19, {"glass": 3, "stone": 1}],
	]},
	{"name": "Ice holes", "rule": "ice", "line": "An icy hole only takes a marble that stops on it",
		"search": 24000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 16, 19, {"ice": 2}],
		[10, 8, 8, 3, 5, 0.15, 1, 16, 19, {"ice": 3, "stop": 2}],
	]},
	{"name": "Turning lock", "rule": "locked", "line": "One way is locked, and the lock turns after every tilt",
		"search": 24000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 16, 19, {"locked": 1}],
		[10, 8, 8, 3, 5, 0.15, 1, 16, 19, {"locked": 1, "spring": 2}],
	]},
	{"name": "Everything", "rule": "mix", "line": "Every rule so far, mixed", "search": 24000, "phases": [
		[10, 8, 8, 3, 5, 0.15, 1, 16, 19, {"mix": 2}],
		[10, 8, 8, 3, 5, 0.15, 1, 16, 19, {"mix": 3}],
	]},
]
## What a mixed chapter (rule "mix") draws its rules from, one entry per rule, each with the marks that
## rule places on a board.
const MIX: Array[Dictionary] = [{"stop": 2}, {"gate": 2}, {"door": 1}, {"paint": 1}, {"crack": 3}, {"stone": 1},
	{"portal": 1}, {"bumper": 2}, {"switch": 1}, {"key": 1}, {"blink": 3}, {"conveyor": 2}, {"spring": 2},
	{"wrap": 1}, {"magnet": 2}, {"number": 3}, {"glass": 2}, {"ice": 2}, {"locked": 1}]
## A phase's count of stones, and the tile names that place two tiles each.
const STONE_NAME: String = "stone"
const PAIRED: Array[String] = ["portal", "switch", "key"]
## The ramp runs over RAMP_LEVELS, the whole game as planned (CHAPTERS.md), not just the chapters made so
## far, so the levels made now stay the same when later chapters are added after them. Level 1 aims at
## FIRST_PAR and FIRST_BITS (see TiltDifficulty), level RAMP_LEVELS at LAST_PAR and LAST_BITS, and both
## climb along the same curve. A RAMP_POWER below 1 climbs faster early.
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
## Proposals tried per level a phase ships before its pool closes, full or not.
const ATTEMPTS: int = 1500
## Chapters from this one on build their pools in batches of BATCH proposals, which a Farm may work out
## anywhere, in any order. Each batch has its own seed, made from one number the phase draws from the
## generator's RNG and the batch's index, and the batches are merged in index order, so the levels depend
## only on the seed, never on where or when a batch ran. The chapters before keep the one-at-a-time way
## they were made, so a full run still writes the levels already shipped.
const PARALLEL_FROM: int = 11
const BATCH: int = 24
## Chapters from this one on ship in TiltDifficulty.before's order, par first, rather than with par and
## bits each never falling (MATH.md section 10). Every level before them keeps both, which also keeps this.
const BY_PAR_FROM: int = 13

class Candidate:
	var board: TiltBoard
	var measure: TiltDifficulty
	var views: TiltNovelty.Views
	var order: int

	func _init(b: TiltBoard, m: TiltDifficulty, v: TiltNovelty.Views, n: int) -> void:
		board = b
		measure = m
		views = v
		order = n

## Works out a batched phase's batches. `job` (see `_fill`) says which phase and window; `take(b)` gives
## batch b's candidates in the order they were found. This one works each batch out here when it is
## asked for; tools/generate_levels.gd puts one in its place that spreads them over worker processes.
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
## Every level made so far, in shipping order, as {"rows", "marbles", "par"}.
var levels: Array[Dictionary] = []
## What the last phase measured, for reporting: pool size and attempts used.
var pooled: int = 0
var attempts: int = 0
var _made: Array[Candidate] = []

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

## The chapters as the level file lists them: name, line and how many levels, in order.
static func chapter_list() -> Array:
	var out: Array = []
	for c: int in range(CHAPTERS.size()):
		out.append({"name": CHAPTERS[c]["name"], "line": CHAPTERS[c]["line"], "count": chapter_size(c)})
	return out

## How far along the ramp level `i` (0-based) is, from 0 to 1.
static func progress(i: int) -> float:
	return pow(float(i) / float(RAMP_LEVELS - 1), RAMP_POWER)

static func target_par(i: int) -> float:
	return FIRST_PAR + (LAST_PAR - FIRST_PAR) * progress(i)

static func target_bits(i: int) -> float:
	return FIRST_BITS + (LAST_BITS - FIRST_BITS) * progress(i)

## Takes `made`, the levels of the chapters already shipped, as made, measuring each one afresh, and the
## random state the generator had once it made them, so the chapters after them come out exactly as a
## full run from the start would make them.
func resume(made: Array, state: int) -> void:
	for entry: Variant in made:
		var level: Dictionary = entry
		var board: TiltBoard = TiltBoard.from_dict(level)
		var m: TiltDifficulty = TiltDifficulty.of(board, int(level["par"]), 200000)
		levels.append(level)
		_made.append(Candidate.new(board, m, TiltNovelty.views(board, m.path), _made.size()))
	rng.state = state

## The measured difficulty of every level made so far, in order.
func made() -> Array[TiltDifficulty]:
	var out: Array[TiltDifficulty] = []
	for c: Candidate in _made:
		out.append(c.measure)
	return out

## Makes phase `p` of chapter `chapter` and appends its levels. False if its pool could not fill a run that
## never gets easier.
func add_phase(chapter: int, p: int) -> bool:
	var phase: Array = CHAPTERS[chapter]["phases"][p]
	var rule: String = CHAPTERS[chapter]["rule"]
	var count: int = phase[0]
	var par_min: int = phase[7]
	var par_max: int = phase[8]
	# Deeper chapters may search further; the ones before keep the limit they were made with.
	var limit: int = int(CHAPTERS[chapter].get("search", SEARCH_LIMIT))
	var first: int = levels.size()
	var last: TiltDifficulty = null if _made.is_empty() else _made[-1].measure
	var by_par: bool = chapter >= BY_PAR_FROM
	# Levels that ran ahead of the ramp carry the window up with them, or it would close above the last one.
	# Ordered by par first, bits may start lower again when par steps up, so there is no window on bits.
	var ahead: float = 0.0 if last == null else maxf(last.bits - target_bits(first), 0.0)
	var lo: float = -1.0 if by_par else target_bits(first) + ahead - BAND
	var hi: float = 1e9 if by_par else target_bits(first + count - 1) + ahead + BAND
	var pool: Array[Candidate] = []
	attempts = 0
	if chapter < PARALLEL_FROM:
		while pool.size() < count * POOL and attempts < count * ATTEMPTS:
			attempts += 1
			_keep(_try(_propose(phase), phase, rule, limit, lo, hi, last), pool)
	else:
		_fill(pool, chapter, p, lo, hi, last)
	pooled = pool.size()
	var run: Array[Candidate] = _run(pool, first, count, last, _streak(by_par), by_par)
	if run.is_empty():
		return false
	for c: Candidate in run:
		var level: Dictionary = c.board.to_dict()
		level["par"] = c.measure.par
		levels.append(level)
		_made.append(c)
	return true

## A proposal measured against everything a phase asks that does not depend on the pool: solved within
## the search, par and bits in the window, no easier than the last level, its pits a real risk where the
## phase has pits, and needing the chapter's rule. Null if it fails any of them.
static func _try(board: TiltBoard, phase: Array, rule: String, limit: int, lo: float, hi: float,
		last: TiltDifficulty, by_par: bool = false) -> Candidate:
	if board == null or not _open(board):
		return null
	# A plain search finds par first, so a board outside the phase's window never pays for the measure,
	# which carries every position's chance as well. Its count of positions differs a little from the
	# measure's, so the chapters made before it keep the one way they were made.
	if by_par and TiltSolver.new().solve(board, limit, int(phase[8])).size() < int(phase[7]):
		return null
	var m: TiltDifficulty = TiltDifficulty.of(board, int(phase[8]), limit)
	if m.par < int(phase[7]) or m.bits < lo or m.bits > hi:
		return null
	if last != null and (m.before(last) if by_par else (m.par < last.par or m.easier_than(last))):
		return null
	if int(phase[6]) > 0 and m.risk <= 0.0:
		return null
	if rule != "" and not needs(board, rule, m.par, limit):
		return null
	return Candidate.new(board, m, TiltNovelty.views(board, m.path), 0)

## Adds a measured candidate to the pool unless it repeats a level made or pooled already.
func _keep(c: Candidate, pool: Array[Candidate]) -> void:
	if c == null or _replays(c.views, pool):
		return
	c.order = pool.size()
	pool.append(c)

## The batched pool (PARALLEL_FROM): the farm's batches, merged in batch order until the pool is full or
## the phase's attempts are spent.
func _fill(pool: Array[Candidate], chapter: int, p: int, lo: float, hi: float, last: TiltDifficulty) -> void:
	var count: int = CHAPTERS[chapter]["phases"][p][0]
	var batches: int = ceili(float(count * ATTEMPTS) / BATCH)
	var job: Dictionary = {"chapter": chapter, "phase": p, "seed": rng.randi(), "batches": batches,
		"lo": lo, "hi": hi, "last": {} if last == null else {"par": last.par, "bits": last.bits, "states": last.states}}
	farm.start(job)
	for b: int in range(batches):
		if pool.size() >= count * POOL:
			break
		attempts += BATCH
		for c: Candidate in farm.take(b):
			if pool.size() < count * POOL:
				_keep(c, pool)
	farm.stop()

## Batch b of a batched phase's `job`: BATCH proposals from a generator seeded for that batch alone,
## measured, in order.
static func batch(job: Dictionary, b: int) -> Array[Candidate]:
	var chapter: int = job["chapter"]
	var phase: Array = CHAPTERS[chapter]["phases"][int(job["phase"])]
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
			chapter >= BY_PAR_FROM)
		if c != null:
			found.append(c)
	return found

## A batch's candidates as JSON a worker process can send, and back. Floats must be written at full
## precision, since equal bits are compared exactly.
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

## Whether `board` needs its `rule`: the same board with every such tile turned back into plain floor, or
## every plug into an ordinary hole, has no solution or a different par. A rule that helps (a stop pad,
## paint) shows by the plain board getting harder; one that restricts (a gate, a plug, cracked floor) by
## it getting easier. A level whose rule changes nothing would teach nothing. The search only has to look
## `par` moves deep, and one that gives up proves nothing, so that board is turned down.
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
	# A switch goes with its hatch, so the door is simply open; a key goes with its lock.
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
	for c: Candidate in pool:
		if TiltNovelty.clash(c.views, v) != "":
			return true
	return false

## The `count` candidates, in order of difficulty with par never falling, closest to the ramp in the
## least-squares sense, with no more than RUN levels in a row on one bits value, counting the `streak` of
## them the set already ends on. A phase's first level aims where the level before it aimed, so whatever
## the phase introduces arrives without a step up in difficulty. The state is (candidate, how many levels
## in a row it ends that share its bits).
func _run(pool: Array[Candidate], first: int, count: int, last: TiltDifficulty, streak: int,
		by_par: bool = false) -> Array[Candidate]:
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
		return a.order < b.order)
	var n: int = sorted.size()
	var cost: Array[PackedFloat64Array] = []
	var back: Array[PackedInt32Array] = []
	for k: int in range(count):
		var aim: int = first + k if k > 0 else maxi(first - 1, 0)
		var row: PackedFloat64Array = PackedFloat64Array()
		var from: PackedInt32Array = PackedInt32Array()
		row.resize(n * RUN)
		row.fill(INF)
		from.resize(n * RUN)
		from.fill(-1)
		for j: int in range(n):
			var m: TiltDifficulty = sorted[j].measure
			var miss_par: float = m.par - target_par(aim)
			var miss_bits: float = m.bits - target_bits(aim)
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

## How many levels at the end of the set so far are as hard as the last one.
func _streak(by_par: bool = false) -> int:
	var n: int = 0
	for k: int in range(_made.size() - 1, -1, -1):
		if not _made[k].measure.same_as(_made[-1].measure, by_par):
			break
		n += 1
	return n

## A marble only ever rolls over floor, so one that open floor does not join to the hole of its colour
## can never drop in. A cheap test that spares the solver boards it could only fail on. Paint can change a
## marble's colour on the way, a portal or a spring can carry it across a wall, an edge can wrap and a
## stone can fill a pit in its way, so a board with any of those is left to the solver.
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

## `n` different rules from MIX, their marks together.
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
