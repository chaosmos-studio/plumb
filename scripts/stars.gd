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

static func leeway(par: int) -> int:
	return maxi(2, int(ceil(par * 0.5)))
