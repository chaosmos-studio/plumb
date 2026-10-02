class_name TiltGenerator
extends RefCounted

## Makes the level set, one chapter at a time, and each chapter one phase at a time. A phase fixes the board
## size and what goes on it. Random boards for the phase are proposed, solved and measured; the ones that
## solve inside the phase's par window, sit near its stretch of the difficulty ramp, need the chapter's
## rule, and are not a replay of any level already made go into a pool. From the pool the generator picks
## the run of levels that follows the ramp most closely without ever getting easier, in par or in
## difficulty, chapter starts included. Nothing is hand-placed.

## Each chapter is one page of the Levels screen and brings one rule. `rule` names the tile its levels must
## need (TiltBoard.TILE_NAMES, or "plug"; "" for the opening chapters, whose rules are the game's own),
## and `line` is how the game teaches it. A phase is: count, width, height, colours, marbles, wall density,
## pits, par min, par max, then the tiles it places: a count per tile name, and "plug" true to make every
## hole a plug, with as many holes of a colour as it has marbles.
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
]
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

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
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
	var first: int = levels.size()
	var last: TiltDifficulty = null if _made.is_empty() else _made[-1].measure
	# Levels that ran ahead of the ramp carry the window up with them, or it would close above the last one.
	var ahead: float = 0.0 if last == null else maxf(last.bits - target_bits(first), 0.0)
	var lo: float = target_bits(first) + ahead - BAND
	var hi: float = target_bits(first + count - 1) + ahead + BAND
	var pool: Array[Candidate] = []
	attempts = 0
	while pool.size() < count * POOL and attempts < count * ATTEMPTS:
		attempts += 1
		var board: TiltBoard = _propose(phase)
		if board == null or not _open(board):
			continue
		var m: TiltDifficulty = TiltDifficulty.of(board, par_max, SEARCH_LIMIT)
		if m.par < par_min or m.bits < lo or m.bits > hi:
			continue
		if last != null and (m.par < last.par or m.easier_than(last)):
			continue
		if int(phase[6]) > 0 and m.risk <= 0.0:
			continue
		if rule != "" and not needs(board, rule, m.par):
			continue
		var v: TiltNovelty.Views = TiltNovelty.views(board, m.path)
		if _replays(v, pool):
			continue
		pool.append(Candidate.new(board, m, v, pool.size()))
	pooled = pool.size()
	var run: Array[Candidate] = _run(pool, first, count, last, _streak())
	if run.is_empty():
		return false
	for c: Candidate in run:
		var level: Dictionary = c.board.to_dict()
		level["par"] = c.measure.par
		levels.append(level)
		_made.append(c)
	return true

## Whether `board` needs its `rule`: the same board with every such tile turned back into plain floor, or
## every plug into an ordinary hole, has no solution or a different par. A rule that helps (a stop pad,
## paint) shows by the plain board getting harder; one that restricts (a gate, a plug, cracked floor) by
## it getting easier. A level whose rule changes nothing would teach nothing. The search only has to look
## `par` moves deep, and one that gives up proves nothing, so that board is turned down.
static func needs(board: TiltBoard, rule: String, par: int) -> bool:
	var solver: TiltSolver = TiltSolver.new()
	var path: PackedInt32Array = solver.solve(without(board, rule), SEARCH_LIMIT, par)
	if path.is_empty():
		return solver.exhausted(SEARCH_LIMIT)
	return path.size() < par

static func without(board: TiltBoard, rule: String) -> TiltBoard:
	var plain: TiltBoard = board.copy()
	if rule == TiltBoard.PLUG_NAME:
		plain.plugs.fill(0)
		return plain
	var tile: int = TiltBoard.TILE_NAMES.find(rule)
	for i: int in range(plain.tiles.size()):
		if plain.tiles[i] == tile:
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
func _run(pool: Array[Candidate], first: int, count: int, last: TiltDifficulty, streak: int) -> Array[Candidate]:
	var sorted: Array[Candidate] = pool.duplicate()
	sorted.sort_custom(func(a: Candidate, b: Candidate) -> bool:
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
				var length: int = streak + 1 if last != null and m.bits == last.bits else 1
				if length <= RUN:
					row[j * RUN + length - 1] = here + (FLAT if length > 1 else 0.0)
				continue
			for i: int in range(j):
				var prior: TiltDifficulty = sorted[i].measure
				if prior.par > m.par:
					continue
				var same: bool = prior.bits == m.bits
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

## How many levels at the end of the set so far share the last one's bits.
func _streak() -> int:
	var n: int = 0
	for k: int in range(_made.size() - 1, -1, -1):
		if _made[k].measure.bits != _made[-1].measure.bits:
			break
		n += 1
	return n

## A marble only ever rolls over floor, so one that open floor does not join to the hole of its colour
## can never drop in. A cheap test that spares the solver boards it could only fail on. Paint can change a
## marble's colour on the way, so a board with paint is left to the solver.
static func _open(board: TiltBoard) -> bool:
	if board.tiles.has(TiltBoard.Tile.PAINT):
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
	var plugged: bool = extras.get("plug", false)
	var tiles: int = 0
	for name: String in extras:
		if name != TiltBoard.PLUG_NAME:
			tiles += int(extras[name])
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
		if name == "":
			continue
		var tile: int = TiltBoard.TILE_NAMES.find(name)
		for k: int in range(int(extras.get(name, 0))):
			var value: int = 0
			match tile:
				TiltBoard.Tile.GATE:
					value = rng.randi_range(0, 3)
				TiltBoard.Tile.DOOR, TiltBoard.Tile.PAINT:
					value = rng.randi_range(0, colours - 1)
			board.set_tile(board.coords(free.pop_back()), tile as TiltBoard.Tile, value)
	for m: int in range(marbles):
		board.add_marble(board.coords(free.pop_back()), m % colours)
	return board

## Fisher-Yates against this generator's own RNG, so the level set depends only on the seed.
func _shuffle(values: Array[int]) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = values[i]
		values[i] = values[j]
		values[j] = t
