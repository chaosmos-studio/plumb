class_name Stars
extends RefCounted

## How many stars a finished level earns. Par is the solver's shortest solution, so three stars means
## the player found a perfect route, and the leeway for two grows with the level, because a few extra
## moves on a thirteen-move board is a good solve.

static func earned(moves: int, par: int) -> int:
	if moves <= par:
		return 3
	if moves <= par + leeway(par):
		return 2
	return 1

## The most a level part played can still earn, for the play screen's meter. A board not yet won needs
## at least one move more, so the third star goes out as soon as the goal can no longer be met.
static func possible(moves: int, par: int, won: bool) -> int:
	return earned(moves if won else moves + 1, par)

static func leeway(par: int) -> int:
	return maxi(2, int(ceil(par * 0.5)))
