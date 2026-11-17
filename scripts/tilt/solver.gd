class_name TiltSolver
extends RefCounted

## Breadth-first, so the first solved state reached is a shortest solution: its length is par and its first
## move the hint (MATH.md section 2). A state with a marble down a pit is never expanded, since only undo
## escapes it.

const DEFAULT_LIMIT: int = 60000

var explored: int = 0
## The way home from the position `way_back` found.
var route: PackedInt32Array = PackedInt32Array()

## Empty when there is no solution within `depth` moves or the search gave up at `limit` states. `exhausted`
## tells which.
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

func exhausted(limit: int = DEFAULT_LIMIT) -> bool:
	return explored < limit

## How many tilts back the latest position with a way home is, or -1 if none has one. `history` is the boards
## before the one in play, oldest first, as the game keeps them for undo (MATH.md section 24).
func way_back(history: Array[TiltBoard], limit: int = DEFAULT_LIMIT) -> int:
	for back: int in range(1, history.size() + 1):
		route = solve(history[history.size() - back], limit)
		if not route.is_empty():
			return back
	route = PackedInt32Array()
	return -1
