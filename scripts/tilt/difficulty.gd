class_name TiltDifficulty
extends RefCounted

## The bits of luck a player tilting at random needs to clear the board in par (MATH.md section 5).

var par: int = 0
## The same shortest solution the solver finds, empty when there is none within the search.
var path: PackedInt32Array = PackedInt32Array()
var bits: float = 0.0
## The chance that random tilting drops a marble down a pit while par is still possible. Above zero
## means some pit is in play.
var risk: float = 0.0
## Positions strictly closer than par: the search a perfect planner has to rule out.
var states: int = 0

static func of(start: TiltBoard, max_depth: int = 64, limit: int = 100000) -> TiltDifficulty:
	var out: TiltDifficulty = TiltDifficulty.new()
	if start.is_won():
		return out
	var seen: Dictionary = {start.key(): true}
	var layer: Array[TiltBoard] = [start.copy()]
	var chance: PackedFloat64Array = PackedFloat64Array([1.0])
	var paths: Array[PackedInt32Array] = [PackedInt32Array()]
	var won: float = 0.0
	var depth: int = 0
	while not layer.is_empty() and depth < max_depth:
		out.states += layer.size()
		var next_layer: Array[TiltBoard] = []
		var next_chance: PackedFloat64Array = PackedFloat64Array()
		var next_paths: Array[PackedInt32Array] = []
		var slot: Dictionary = {}
		for i: int in range(layer.size()):
			var moves: Array[TiltBoard] = []
			var dirs: PackedInt32Array = PackedInt32Array()
			for dir: int in range(4):
				var next: TiltBoard = layer[i].copy()
				if next.tilt(dir).changed():
					moves.append(next)
					dirs.append(dir)
			if moves.is_empty():
				continue
			var share: float = chance[i] / moves.size()
			for k: int in range(moves.size()):
				var next: TiltBoard = moves[k]
				if next.lost:
					out.risk += share
					continue
				if next.is_won():
					won += share
					if out.path.is_empty():
						out.path = paths[i].duplicate()
						out.path.append(dirs[k])
					continue
				var key: String = next.key()
				if slot.has(key):
					next_chance[int(slot[key])] += share
					continue
				if seen.has(key):
					continue
				seen[key] = true
				slot[key] = next_layer.size()
				next_layer.append(next)
				next_chance.append(share)
				var step: PackedInt32Array = paths[i].duplicate()
				step.append(dirs[k])
				next_paths.append(step)
			if seen.size() > limit:
				return TiltDifficulty.new()
		depth += 1
		if won > 0.0:
			out.par = depth
			out.bits = -log(won) / log(2.0)
			return out
		layer = next_layer
		chance = next_chance
		paths = next_paths
	return TiltDifficulty.new()

func solved() -> bool:
	return par > 0

## At equal bits, the level with more positions closer than par is the harder (MATH.md section 5).
func easier_than(other: TiltDifficulty) -> bool:
	if bits != other.bits:
		return bits < other.bits
	return states < other.states

## The order levels ship in from TiltGenerator.BY_PAR_FROM on, so bits may start lower again each time
## par steps up (MATH.md section 10).
func before(other: TiltDifficulty) -> bool:
	if par != other.par:
		return par < other.par
	return easier_than(other)

## Whether two levels are equally hard in that order, which RUN limits.
func same_as(other: TiltDifficulty, by_par: bool) -> bool:
	return bits == other.bits and (not by_par or par == other.par)
