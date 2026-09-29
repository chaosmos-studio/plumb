class_name TiltGenerator
extends RefCounted

## Makes levels by proposing random boards and keeping only those the solver proves solvable in a par
## that fits the tier. Nothing is hand-placed: difficulty comes from the tier's numbers and the par
## window, and every level shipped has a known shortest solution.

## count, width, height, colours, marbles per colour, wall density, pits, par min, par max
const TIERS: Array = [
	[3, 4, 4, 1, 1, 0.06, 0, 1, 2],
	[7, 5, 5, 1, 1, 0.12, 0, 2, 4],
	[10, 5, 5, 1, 2, 0.14, 0, 3, 5],
	[15, 5, 6, 2, 1, 0.14, 0, 3, 6],
	[15, 6, 6, 2, 2, 0.15, 1, 4, 7],
	[20, 6, 7, 3, 1, 0.16, 1, 5, 8],
	[20, 6, 7, 3, 2, 0.16, 2, 6, 10],
	[15, 7, 8, 4, 1, 0.17, 2, 7, 11],
	[15, 7, 8, 4, 2, 0.18, 3, 8, 13],
]
## States the solver may explore for one candidate. A candidate that needs more is simply rejected:
## it is either unsolvable or too tangled for its tier.
const SEARCH_LIMIT: int = 12000
const ATTEMPTS: int = 4000

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var solver: TiltSolver = TiltSolver.new()

func _init(seed_value: int) -> void:
	rng.seed = seed_value

static func level_count() -> int:
	var n: int = 0
	for tier: Array in TIERS:
		n += int(tier[0])
	return n

## One level for a tier, as {"rows", "marbles", "par"}, or {} if none was found.
func make(tier: Array, avoid: Dictionary) -> Dictionary:
	for attempt: int in range(ATTEMPTS):
		var board: TiltBoard = _propose(tier)
		if board == null:
			continue
		var layout: String = JSON.stringify(board.to_dict())
		if avoid.has(layout):
			continue
		var path: PackedInt32Array = solver.solve(board, SEARCH_LIMIT)
		if path.is_empty():
			continue
		if path.size() < int(tier[7]) or path.size() > int(tier[8]):
			continue
		avoid[layout] = true
		var level: Dictionary = board.to_dict()
		level["par"] = path.size()
		return level
	return {}

func _propose(tier: Array) -> TiltBoard:
	var w: int = tier[1]
	var h: int = tier[2]
	var colours: int = tier[3]
	var per_colour: int = tier[4]
	var density: float = tier[5]
	var pits: int = tier[6]
	var board: TiltBoard = TiltBoard.create(w, h)
	var free: Array[int] = []
	for i: int in range(w * h):
		if rng.randf() < density:
			board.cells[i] = TiltBoard.Cell.WALL
		else:
			free.append(i)
	_shuffle(free)
	var needed: int = colours * (1 + per_colour) + pits
	if free.size() < needed + 4:
		return null
	for p: int in range(pits):
		board.cells[free.pop_back()] = TiltBoard.Cell.PIT
	for c: int in range(colours):
		board.holes[free.pop_back()] = c
	for c: int in range(colours):
		for k: int in range(per_colour):
			board.add_marble(board.coords(free.pop_back()), c)
	return board

## Fisher-Yates against this generator's own RNG, so the level set depends only on the seed.
func _shuffle(values: Array[int]) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = values[i]
		values[i] = values[j]
		values[j] = t
