class_name TiltShowcase
extends RefCounted

## The opening: the first levels a new player meets, made to be remembered as well as easy. Each slot says
## what its level holds and the traits every route that clears it in par must show: a long roll home, two
## marbles dropping on one tilt, a bank off a wall, a tempting tilt that strands a marble, two marbles
## dropping together on the last tilt. Random boards for each slot, most of them built around a mirror or a
## turn, are kept if they show their slot's traits and fit under the level that follows the opening, then
## scored for how they look and play. The opening is the run of one board per slot with the best total score
## that never gets easier and repeats nothing (MATH.md section 12). Nothing is hand-placed.

## Each slot's marbles, its par, and the traits every route that clears it in par shows (see `shows`).
const SLOTS: Array[Dictionary] = [
	{"marbles": 1, "par": 1, "traits": ["long"]},
	{"marbles": 2, "par": 1, "traits": ["together", "busy"]},
	{"marbles": 2, "par": 2, "traits": ["apart", "bank", "busy"]},
	{"marbles": 2, "par": 2, "traits": ["trap"]},
	{"marbles": 2, "par": 2, "traits": ["together", "busy"]},
]
## The shapes an opening board may take, as long as it holds no more cells than the level after the opening.
const SHAPES: Array[Vector2i] = [Vector2i(4, 5), Vector2i(5, 4), Vector2i(5, 5)]
## The symmetry groups a proposal is built around, each a list of TiltNovelty's symmetries: none, a mirror
## either way, a half turn, both mirrors, and on square boards a diagonal mirror, both diagonals or the
## quarter turns.
const GROUPS: Array = [[0], [0, 1], [0, 2], [0, 3], [0, 1, 2, 3], [0, 4], [0, 7], [0, 3, 4, 7], [0, 3, 5, 6]]
## How strongly each of TiltNovelty's symmetries reads as design: a mirror left to right or top to bottom at
## once, a half or quarter turn a little less, a diagonal mirror least.
const SALIENCE: PackedFloat32Array = [0.0, 1.0, 1.0, 0.8, 0.6, 0.8, 0.8, 0.6]
## Proposals per slot, the most a proposal's wall density may be, and the chance that a marble is placed on
## a cell the proposal's symmetry leaves in place, where one is free.
const PROPOSALS: int = 20000
const DENSITY: float = 0.3
const POSED: float = 0.5
## A long roll crosses at least this many cells before its marble drops.
const LONG: int = 3
## Positions searched for one board, to measure it or to see where its marbles can go.
const LIMIT: int = 5000
## The score, each part from 0 to 1: how symmetric the walls and holes are, and the whole board with its
## marbles; the share of floor the par routes cross, and that any play reaches; how far the marbles roll
## against how far they could. Walls cost by how far their share of the board falls outside LEAST to FEW: a
## bare board looks unfinished, a busy one cluttered.
const W_SYMMETRY: float = 3.0
const W_POSE: float = 1.0
const W_COVER: float = 2.0
const W_REACH: float = 1.0
const W_ROLL: float = 1.5
const W_WALLS: float = 6.0
const LEAST: float = 0.08
const FEW: float = 0.16
## Every player sees the first level and fewer see each one after it, so in the run's total a slot's score
## counts FUNNEL times as much as the one before it. A level as hard as the one before costs FLAT: a tie-break
## only, since every level of the opening is easy and a first look matters more than a step in bits.
const FUNNEL: float = 0.8
const FLAT: float = 0.1
## Candidates a slot keeps for each size and difficulty, and the partial openings carried from slot to slot.
const KEEP: int = 8
const BEAM: int = 500

class Pick:
	var candidate: TiltGenerator.Candidate
	var score: float

	func _init(c: TiltGenerator.Candidate, s: float) -> void:
		candidate = c
		score = s

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Seeded apart from the generator's own stream, so making the opening again never moves a later level.
func _init(seed_value: int) -> void:
	rng.seed = hash(["opening", seed_value])

## The opening for a level set whose levels after it are `after`, in order: one candidate per slot, or none
## if some slot finds nothing that fits.
func make(after: Array[TiltGenerator.Candidate]) -> Array[TiltGenerator.Candidate]:
	var out: Array[TiltGenerator.Candidate] = []
	var pools: Array[Array] = []
	for slot: Dictionary in SLOTS:
		var pool: Array[Pick] = _pool(slot, after)
		if pool.is_empty():
			return out
		pools.append(pool)
	for p: Pick in _run(pools, after):
		out.append(p.candidate)
	return out

## Whether `board` is what `slot` asks for: its marbles, exactly its par, and every route that clears it in
## par showing the slot's traits.
static func holds(board: TiltBoard, slot: Dictionary) -> bool:
	var par: int = slot["par"]
	var traits: Array = slot["traits"]
	if board.marbles_left() != int(slot["marbles"]) or TiltSolver.new().solve(board, LIMIT, par).size() != par:
		return false
	if traits.has("trap") and not tempts(board, par):
		return false
	var found: Array[PackedInt32Array] = routes(board, par)
	for route: PackedInt32Array in found:
		if not shows(board, route, traits):
			return false
	return not found.is_empty()

## Every way to clear `board` in exactly `par` tilts, each tilt moving something and none losing a marble.
static func routes(board: TiltBoard, par: int) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	_extend(board, PackedInt32Array(), par, out)
	return out

static func _extend(board: TiltBoard, path: PackedInt32Array, par: int, out: Array[PackedInt32Array]) -> void:
	for dir: int in range(4):
		var next: TiltBoard = board.copy()
		if not next.tilt(dir).changed() or next.lost:
			continue
		var step: PackedInt32Array = path.duplicate()
		step.append(dir)
		if next.is_won():
			if step.size() == par:
				out.append(step)
		elif step.size() < par:
			_extend(next, step, par, out)

## Whether `route` shows `traits` on `start`. "busy": every marble on the board rolls on every tilt. "long":
## each marble drops at the end of a roll of at least LONG cells. "together": the last tilt drops two marbles
## or more. "apart": every tilt drops a marble. "bank": every tilt but the last leaves each marble on the board
## resting against a wall, and the next tilt turns a corner off it.
static func shows(start: TiltBoard, route: PackedInt32Array, traits: Array) -> bool:
	var board: TiltBoard = start.copy()
	for k: int in range(route.size()):
		var dir: int = route[k]
		var before: PackedInt32Array = board.marble_cell.duplicate()
		var move: TiltMove = board.tilt(dir)
		if traits.has("busy"):
			for m: int in range(before.size()):
				if before[m] != TiltBoard.GONE and not move.moved(m):
					return false
		var sank: int = 0
		for e: Dictionary in move.events:
			if e["kind"] != &"sink":
				continue
			sank += 1
			if traits.has("long") and _rolled(move, int(e["marble"])) < LONG:
				return false
		var last: bool = k == route.size() - 1
		if (traits.has("together") and last and sank < 2) or (traits.has("apart") and sank == 0):
			return false
		if traits.has("bank") and not last:
			if (TiltBoard.DIRS[dir].x == 0) == (TiltBoard.DIRS[route[k + 1]].x == 0):
				return false
			for c: int in board.marble_cell:
				if c == TiltBoard.GONE:
					continue
				var beyond: Vector2i = board.coords(c) + TiltBoard.DIRS[dir]
				if not board.inside(beyond) or board.cells[board.index(beyond)] != TiltBoard.Cell.WALL:
					return false
	return true

## Whether some first tilt drops a marble yet leaves a board the tilts left in par cannot clear.
static func tempts(board: TiltBoard, par: int) -> bool:
	for dir: int in range(4):
		var next: TiltBoard = board.copy()
		next.tilt(dir)
		if next.lost or next.is_won() or next.marbles_left() == board.marbles_left():
			continue
		if TiltSolver.new().solve(next, LIMIT, par - 1).is_empty():
			return true
	return false

static func _rolled(move: TiltMove, m: int) -> int:
	var n: int = 0
	for step: Array in move.steps:
		if step.has(m):
			n += 1
	return n

## How a board looks and plays, the sum of the weighted parts.
static func score(board: TiltBoard, par: int) -> float:
	var found: Array[PackedInt32Array] = routes(board, par)
	var walls: float = float(board.cells.count(TiltBoard.Cell.WALL)) / board.cells.size()
	return W_SYMMETRY * symmetry(board, false) + W_POSE * symmetry(board, true) + W_COVER * cover(board, found) \
		+ W_REACH * reach(board) + W_ROLL * roll(board, found) - W_WALLS * maxf(maxf(LEAST - walls, walls - FEW), 0.0)

## The largest share of cells that one mirror or turn of the board leaves as they were, weighed by how
## strongly that symmetry reads (SALIENCE): walls and holes, and with `marbles` where the marbles start too.
static func symmetry(board: TiltBoard, marbles: bool) -> float:
	var at: PackedByteArray = PackedByteArray()
	at.resize(board.cells.size())
	if marbles:
		for c: int in board.marble_cell:
			at[c] = 1
	var best: float = 0.0
	for s: int in range(1, TiltNovelty.SYMMETRIES):
		if s & 4 and board.width != board.height:
			continue
		var same: int = 0
		for i: int in range(board.cells.size()):
			var j: int = board.index(TiltNovelty.map_cell(board.coords(i), s, board.width, board.height))
			if board.cells[i] == board.cells[j] and board.holes[i] == board.holes[j] and at[i] == at[j]:
				same += 1
		best = maxf(best, SALIENCE[s] * same / board.cells.size())
	return best

## The share of floor the routes `found` roll over or rest on: the room a solution uses.
static func cover(board: TiltBoard, found: Array[PackedInt32Array]) -> float:
	var touched: PackedByteArray = _touched(board)
	for route: PackedInt32Array in found:
		var b: TiltBoard = board.copy()
		for dir: int in route:
			_touch(touched, b.tilt(dir))
	return _share(board, touched)

## The share of floor some marble rolls over or rests on, in any play from the start: floor no play ever
## touches is wasted room.
static func reach(board: TiltBoard) -> float:
	var touched: PackedByteArray = _touched(board)
	var seen: Dictionary = {board.key(): true}
	var queue: Array[TiltBoard] = [board]
	var head: int = 0
	while head < queue.size() and queue.size() < LIMIT:
		var at: TiltBoard = queue[head]
		head += 1
		for dir: int in range(4):
			var next: TiltBoard = at.copy()
			_touch(touched, next.tilt(dir))
			if next.lost or next.is_won() or seen.has(next.key()):
				continue
			seen[next.key()] = true
			queue.append(next)
	return _share(board, touched)

static func _touched(board: TiltBoard) -> PackedByteArray:
	var touched: PackedByteArray = PackedByteArray()
	touched.resize(board.cells.size())
	for c: int in board.marble_cell:
		touched[c] = 1
	return touched

static func _touch(touched: PackedByteArray, move: TiltMove) -> void:
	for landed: PackedInt32Array in move.cells:
		for c: int in landed:
			touched[c] = 1

static func _share(board: TiltBoard, touched: PackedByteArray) -> float:
	var floor_cells: int = 0
	var reached: int = 0
	for i: int in range(board.cells.size()):
		if board.cells[i] == TiltBoard.Cell.FLOOR:
			floor_cells += 1
			reached += touched[i]
	return float(reached) / floor_cells

## How far the marbles roll on `found`, against how far they could: every marble on the board crossing the
## whole board on every tilt would be 1.
static func roll(board: TiltBoard, found: Array[PackedInt32Array]) -> float:
	var rolled: int = 0
	var room: int = 0
	for route: PackedInt32Array in found:
		var b: TiltBoard = board.copy()
		for dir: int in route:
			room += ((b.width if TiltBoard.DIRS[dir].x != 0 else b.height) - 1) * b.marbles_left()
			for step: Array in b.tilt(dir).steps:
				rolled += step.size()
	return 0.0 if room == 0 else float(rolled) / room

## A slot's pool: the proposals that hold it, fit under the level after the opening and repeat none of the
## levels after it, each board once up to symmetry, and for each size and difficulty only the KEEP best.
func _pool(slot: Dictionary, after: Array[TiltGenerator.Candidate]) -> Array[Pick]:
	var next: TiltGenerator.Candidate = after[0]
	var par: int = slot["par"]
	var marbles: int = slot["marbles"]
	var pool: Array[Pick] = []
	if par > next.measure.par or marbles > next.board.marbles_left():
		return pool
	var shapes: Array[Vector2i] = []
	for shape: Vector2i in SHAPES:
		if shape.x * shape.y <= next.board.cells.size():
			shapes.append(shape)
	var seen: Dictionary = {}
	var groups: Dictionary = {}
	for k: int in range(PROPOSALS):
		var board: TiltBoard = _propose(shapes, marbles)
		if board == null:
			continue
		var m: TiltDifficulty = TiltDifficulty.of(board, par, LIMIT)
		if m.par != par or next.measure.easier_than(m) or not holds(board, slot):
			continue
		var key: String = TiltNovelty.canonical(board)
		if seen.has(key):
			continue
		seen[key] = true
		var views: TiltNovelty.Views = TiltNovelty.views(board, m.path)
		if _clashes(views, after):
			continue
		var group: String = "%d/%s/%d" % [board.cells.size(), str(m.bits), m.states]
		if not groups.has(group):
			groups[group] = []
		(groups[group] as Array).append(Pick.new(TiltGenerator.Candidate.new(board, m, views, k), score(board, par)))
	for group: String in groups:
		var picks: Array = groups[group]
		picks.sort_custom(_better)
		for p: Pick in picks.slice(0, KEEP):
			pool.append(p)
	pool.sort_custom(_better)
	return pool

static func _better(a: Pick, b: Pick) -> bool:
	if a.score != b.score:
		return a.score > b.score
	return a.candidate.order < b.candidate.order

static func _clashes(views: TiltNovelty.Views, others: Array[TiltGenerator.Candidate]) -> bool:
	for c: TiltGenerator.Candidate in others:
		if TiltNovelty.clash(c.views, views) != "":
			return true
	return false

## The best run of one pick per slot, by the scores weighed down the FUNNEL, less FLAT for each level as hard
## as the one before: a beam of the BEAM best partial runs, each grown by every pick of the next slot that may
## follow it and repeats no pick before it. The first run whose plateau, carried into the levels after, is no
## longer than TiltGenerator.RUN wins.
func _run(pools: Array[Array], after: Array[TiltGenerator.Candidate]) -> Array[Pick]:
	var beam: Array[Array] = [[]]
	var totals: PackedFloat64Array = PackedFloat64Array([0.0])
	for k: int in range(pools.size()):
		var pool: Array = pools[k]
		var weight: float = pow(FUNNEL, k)
		var grown: Array[Array] = []
		var sums: PackedFloat64Array = PackedFloat64Array()
		for b: int in range(beam.size()):
			var run: Array = beam[b]
			var last: TiltGenerator.Candidate = null if run.is_empty() else (run[-1] as Pick).candidate
			for p: Pick in pool:
				if last != null and not _follows(last, p.candidate):
					continue
				var repeats: bool = false
				for q: Pick in run:
					repeats = repeats or TiltNovelty.clash(q.candidate.views, p.candidate.views) != ""
				if repeats:
					continue
				var flat: bool = last != null and last.measure.same_as(p.candidate.measure, false)
				grown.append(run + [p])
				sums.append(totals[b] + weight * p.score - (FLAT if flat else 0.0))
		var order: Array[int] = []
		for i: int in range(grown.size()):
			order.append(i)
		order.sort_custom(func(a: int, b: int) -> bool: return sums[a] > sums[b] if sums[a] != sums[b] else a < b)
		beam = []
		totals = PackedFloat64Array()
		for i: int in order.slice(0, BEAM):
			beam.append(grown[i])
			totals.append(sums[i])
	var out: Array[Pick] = []
	for run: Array in beam:
		if _plateau(run, after) <= TiltGenerator.RUN:
			out.assign(run)
			break
	return out

## Whether `b` may come straight after `a`: no easier, par no lower, and no less room or fewer marbles.
static func _follows(a: TiltGenerator.Candidate, b: TiltGenerator.Candidate) -> bool:
	return not b.measure.easier_than(a.measure) and b.measure.par >= a.measure.par \
		and b.board.cells.size() >= a.board.cells.size() and b.board.marbles_left() >= a.board.marbles_left()

## The longest run of equal difficulty in the opening and on into the levels after it.
static func _plateau(run: Array, after: Array[TiltGenerator.Candidate]) -> int:
	var measures: Array[TiltDifficulty] = []
	for p: Pick in run:
		measures.append(p.candidate.measure)
	for c: TiltGenerator.Candidate in after.slice(0, TiltGenerator.RUN + 1):
		measures.append(c.measure)
	var longest: int = 1
	var length: int = 1
	for i: int in range(1, measures.size()):
		length = length + 1 if measures[i].same_as(measures[i - 1], false) else 1
		longest = maxi(longest, length)
	return longest

## A board for a slot of `marbles`: walls laid in whole orbits of a random symmetry group at a random density,
## the hole on a cell the group leaves in place where there is one, and each marble too with the chance POSED,
## or anywhere left.
func _propose(shapes: Array[Vector2i], marbles: int) -> TiltBoard:
	var shape: Vector2i = shapes[rng.randi_range(0, shapes.size() - 1)]
	var fits: Array = []
	for g: Array in GROUPS:
		if shape.x == shape.y or not g.any(func(s: int) -> bool: return s & 4 != 0):
			fits.append(g)
	var group: Array = fits[rng.randi_range(0, fits.size() - 1)]
	var board: TiltBoard = TiltBoard.create(shape.x, shape.y)
	var density: float = rng.randf() * DENSITY
	var free: PackedInt32Array = PackedInt32Array()
	var fixed: PackedInt32Array = PackedInt32Array()
	for orbit: PackedInt32Array in _orbits(shape, group):
		if rng.randf() < density:
			for c: int in orbit:
				board.cells[c] = TiltBoard.Cell.WALL
			continue
		free.append_array(orbit)
		if orbit.size() == 1:
			fixed.append(orbit[0])
	if free.size() <= marbles:
		return null
	for m: int in range(marbles + 1):
		var spots: PackedInt32Array = fixed if not fixed.is_empty() and (m == 0 or rng.randf() < POSED) else free
		var at: int = spots[rng.randi_range(0, spots.size() - 1)]
		free.remove_at(free.find(at))
		if fixed.has(at):
			fixed.remove_at(fixed.find(at))
		# The hole first, where the symmetry leaves it in place if it can, so the board stays symmetric.
		if m == 0:
			board.holes[at] = 0
		else:
			board.add_marble(board.coords(at), 0)
	return board

## The cells of a `shape` board in orbits under `group`: each orbit is a cell and everywhere the group takes it.
static func _orbits(shape: Vector2i, group: Array) -> Array[PackedInt32Array]:
	var taken: PackedByteArray = PackedByteArray()
	taken.resize(shape.x * shape.y)
	var out: Array[PackedInt32Array] = []
	for i: int in range(taken.size()):
		if taken[i] == 1:
			continue
		var orbit: PackedInt32Array = PackedInt32Array()
		for s: int in group:
			@warning_ignore("integer_division")
			var at: Vector2i = TiltNovelty.map_cell(Vector2i(i % shape.x, i / shape.x), s, shape.x, shape.y)
			var j: int = at.y * shape.x + at.x
			if taken[j] == 0:
				taken[j] = 1
				orbit.append(j)
		out.append(orbit)
	return out
