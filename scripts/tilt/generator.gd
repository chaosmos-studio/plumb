class_name TiltGenerator
extends RefCounted

## Makes the level set, one phase at a time. A phase fixes the board size and what goes on it. Random
## boards for the phase are proposed, solved and measured; the ones that solve inside the phase's par
## window, sit near its stretch of the difficulty ramp, and are not a replay of any level already made
## go into a pool. From the pool the generator picks the run of levels that follows the ramp most
## closely without ever getting easier, in par or in difficulty. Nothing is hand-placed.

## count, width, height, colours, marbles, wall density, pits, par min, par max. From phase to phase the
## board, the colours, the marbles and the pits only grow, so no level takes away what one before taught.
const PHASES: Array = [
	[1, 4, 4, 1, 1, 0.10, 0, 1, 1],
	[2, 4, 4, 1, 1, 0.12, 0, 2, 3],
	[5, 5, 5, 1, 2, 0.16, 0, 2, 4],
	[10, 5, 6, 2, 2, 0.14, 0, 2, 5],
	[9, 5, 6, 2, 3, 0.14, 0, 3, 6],
	[11, 6, 6, 2, 3, 0.15, 1, 4, 7],
	[11, 6, 6, 2, 4, 0.15, 1, 6, 9],
	[13, 6, 7, 3, 4, 0.16, 1, 7, 10],
	[13, 6, 7, 3, 5, 0.16, 2, 8, 11],
	[13, 7, 7, 3, 6, 0.17, 2, 9, 12],
	[15, 7, 8, 4, 6, 0.17, 2, 10, 13],
	[17, 7, 8, 4, 8, 0.18, 3, 11, 13],
]
## The ramp: level 1 aims at FIRST_PAR and FIRST_BITS (see TiltDifficulty), the last level at LAST_PAR
## and LAST_BITS, and both climb along the same curve. A RAMP_POWER below 1 climbs faster early.
const FIRST_PAR: float = 1.0
const LAST_PAR: float = 13.0
const FIRST_BITS: float = 1.6
const LAST_BITS: float = 18.0
const RAMP_POWER: float = 0.75
## How much a move of par off the ramp costs against a bit of difficulty off it.
const PAR_WEIGHT: float = 2.0
## What repeating the last level's bits exactly costs, so the ramp takes a step over a plateau.
const FLAT: float = 0.5
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
	for phase: Array in PHASES:
		n += int(phase[0])
	return n

## How far along the ramp level `i` (0-based) is, from 0 to 1.
static func progress(i: int) -> float:
	return pow(float(i) / float(level_count() - 1), RAMP_POWER)

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

## Makes phase `p`'s levels and appends them. False if its pool could not fill a run that never gets
## easier.
func add_phase(p: int) -> bool:
	var phase: Array = PHASES[p]
	var count: int = phase[0]
	var par_min: int = phase[7]
	var par_max: int = phase[8]
	var first: int = levels.size()
	var last: TiltDifficulty = null if _made.is_empty() else _made[-1].measure
	var lo: float = target_bits(first) - BAND
	var hi: float = target_bits(first + count - 1) + BAND
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
		var v: TiltNovelty.Views = TiltNovelty.views(board, m.path)
		if _replays(v, pool):
			continue
		pool.append(Candidate.new(board, m, v, pool.size()))
	pooled = pool.size()
	var run: Array[Candidate] = _run(pool, first, count, last)
	if run.is_empty():
		return false
	for c: Candidate in run:
		var level: Dictionary = c.board.to_dict()
		level["par"] = c.measure.par
		levels.append(level)
		_made.append(c)
	return true

func _replays(v: TiltNovelty.Views, pool: Array[Candidate]) -> bool:
	for c: Candidate in _made:
		if TiltNovelty.clash(c.views, v) != "":
			return true
	for c: Candidate in pool:
		if TiltNovelty.clash(c.views, v) != "":
			return true
	return false

## The `count` candidates, in order of difficulty with par never falling, closest to the ramp in the
## least-squares sense. A phase's first level aims where the level before it aimed, so whatever the
## phase introduces arrives without a step up in difficulty.
func _run(pool: Array[Candidate], first: int, count: int, last: TiltDifficulty) -> Array[Candidate]:
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
		row.resize(n)
		from.resize(n)
		for j: int in range(n):
			var m: TiltDifficulty = sorted[j].measure
			row[j] = INF
			from[j] = -1
			var before: float = FLAT if k == 0 and last != null and m.bits == last.bits else 0.0
			if k > 0:
				before = INF
				for i: int in range(j):
					var prior: TiltDifficulty = sorted[i].measure
					var step: float = cost[k - 1][i] + (FLAT if prior.bits == m.bits else 0.0)
					if step < before and prior.par <= m.par:
						before = step
						from[j] = i
				if from[j] < 0:
					continue
			var miss_par: float = m.par - target_par(aim)
			var miss_bits: float = m.bits - target_bits(aim)
			row[j] = before + PAR_WEIGHT * miss_par * miss_par + miss_bits * miss_bits
		cost.append(row)
		back.append(from)
	var end: int = -1
	for j: int in range(n):
		if cost[count - 1][j] < INF and (end < 0 or cost[count - 1][j] < cost[count - 1][end]):
			end = j
	var run: Array[Candidate] = []
	if end < 0:
		return run
	for k: int in range(count - 1, -1, -1):
		run.push_front(sorted[end])
		end = back[k][end]
	return run

## A marble only ever rolls over floor, so one that open floor does not join to the hole of its colour
## can never drop in. A cheap test that spares the solver boards it could only fail on. The generator
## makes one hole per colour.
static func _open(board: TiltBoard) -> bool:
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
	var board: TiltBoard = TiltBoard.create(w, h)
	var free: Array[int] = []
	for i: int in range(w * h):
		if rng.randf() < density:
			board.cells[i] = TiltBoard.Cell.WALL
		else:
			free.append(i)
	_shuffle(free)
	if free.size() < colours + marbles + pits + 4:
		return null
	for p: int in range(pits):
		board.cells[free.pop_back()] = TiltBoard.Cell.PIT
	for c: int in range(colours):
		board.holes[free.pop_back()] = c
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
