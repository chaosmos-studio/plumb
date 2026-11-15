class_name TiltNaive
extends RefCounted

## Two players who do not plan, for checking that a level asks for thought (MATH.md section 16): one tilts at random,
## one always takes the tilt that looks best right now. A level either of them clears in par most of the time is a
## level that needs no thinking.

## Whether greed clears `start` in `par` tilts: each tilt drops the most marbles it can, and between equals leaves
## the marbles nearest their holes. A tilt that loses a marble is never taken.
static func greedy(start: TiltBoard, par: int) -> bool:
	var board: TiltBoard = start.copy()
	for move: int in range(par):
		var best: TiltBoard = null
		var best_score: Vector2i = Vector2i.ZERO
		for dir: int in range(4):
			var next: TiltBoard = board.copy()
			if not next.tilt(dir).changed() or next.lost:
				continue
			var score: Vector2i = Vector2i(board.marbles_left() - next.marbles_left(), -distance(next))
			if best == null or score.x > best_score.x or (score.x == best_score.x and score.y > best_score.y):
				best = next
				best_score = score
		if best == null:
			return false
		board = best
		if board.is_won():
			return true
	return false

## Of `tries` random players, how many clear `start` in `par` tilts, each taking any tilt that moves something.
static func lucky(start: TiltBoard, par: int, tries: int, rng: RandomNumberGenerator) -> int:
	var wins: int = 0
	for t: int in range(tries):
		var board: TiltBoard = start.copy()
		for move: int in range(par):
			var moves: Array[TiltBoard] = []
			for dir: int in range(4):
				var next: TiltBoard = board.copy()
				if next.tilt(dir).changed():
					moves.append(next)
			if moves.is_empty():
				break
			board = moves[rng.randi_range(0, moves.size() - 1)]
			if board.lost or board.is_won():
				break
		wins += 1 if board.is_won() and not board.lost else 0
	return wins

## The sum over the marbles still rolling of the steps, walls ignored, to the nearest hole of their colour.
static func distance(board: TiltBoard) -> int:
	var total: int = 0
	for m: int in range(board.marble_cell.size()):
		if board.marble_cell[m] == TiltBoard.GONE or board.is_stone(m):
			continue
		var at: Vector2i = board.coords(board.marble_cell[m])
		var nearest: int = board.width + board.height
		for i: int in range(board.holes.size()):
			if board.holes[i] == board.marble_colour[m]:
				var hole: Vector2i = board.coords(i)
				nearest = mini(nearest, absi(hole.x - at.x) + absi(hole.y - at.y))
		total += nearest
	return total
