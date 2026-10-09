class_name Stars
extends RefCounted

## The leeway for two stars grows with par, because a few extra moves on a thirteen-move board is still a
## good solve (MATH.md section 7).

static func earned(moves: int, par: int) -> int:
	if moves <= par:
		return 3
	if moves <= par + leeway(par):
		return 2
	return 1

## A board not yet won needs at least one move more, so a star goes out as soon as it can no longer be earned.
static func possible(moves: int, par: int, won: bool) -> int:
	return earned(moves if won else moves + 1, par)

static func leeway(par: int) -> int:
	return maxi(2, int(ceil(par * 0.5)))
