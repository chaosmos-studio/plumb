class_name TiltSolver
extends RefCounted

## Breadth-first search over tilts. Every tilt that changes the board is one move, so the first solved
## state reached is a shortest solution: its length is the level's par, and its first move is the hint.
##
## The state is only where the live marbles are. Walls, holes and pits never change, and a state with a
## marble lost down a pit is a dead end, never expanded.

const DEFAULT_LIMIT: int = 60000

var explored: int = 0

## The shortest list of directions that clears the board in at most `depth` moves, or an empty array if
## there is none within `limit` states (check `exhausted` to tell "none" from "gave up").
func solve(start: TiltBoard, limit: int = DEFAULT_LIMIT, depth: int = 1 << 30) -> PackedInt32Array:
	explored = 0
	if start.is_won():
		return PackedInt32Array()
	var seen: Dictionary = {start.key(): true}
	var frontier: Array[TiltBoard] = [start.copy()]
	var paths: Array[PackedInt32Array] = [PackedInt32Array()]
	var head: int = 0
	while head < frontier.size():
		var board: TiltBoard = frontier[head]
		var path: PackedInt32Array = paths[head]
		head += 1
		if path.size() >= depth:
			break
		for dir: int in range(4):
			var next: TiltBoard = board.copy()
			if not next.tilt(dir).changed() or next.lost:
				continue
			var step: PackedInt32Array = path.duplicate()
			step.append(dir)
			if next.is_won():
				return step
			var k: String = next.key()
			if seen.has(k):
				continue
			seen[k] = true
			explored += 1
			if explored >= limit:
				return PackedInt32Array()
			frontier.append(next)
			paths.append(step)
	return PackedInt32Array()

## Whether the search ran out of states to explore, so an empty answer really means no solution in reach.
func exhausted(limit: int = DEFAULT_LIMIT) -> bool:
	return explored < limit
