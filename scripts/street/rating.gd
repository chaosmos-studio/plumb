class_name StreetRating
extends RefCounted

## How good a player is, and how hard a board is, on one scale (REVAMP_PLAN.md section 4.4, MATH.md section 29):
## Glicko-1, one rating period per board attempt. A board's rating comes from its difficulty in bits and has a fixed
## deviation; a player's has a mean `mu` and a deviation `phi` that shrinks with play and grows slowly while away.
## Pure, so the picker, the save and the simulated players in the tests all use the same sums.

## A board's rating: R(d) = BOARD_BASE + BOARD_PER_BIT * d, and how sure that is.
const BOARD_BASE: float = 1000.0
const BOARD_PER_BIT: float = 50.0
const BOARD_PHI: float = 60.0
## Where a new player starts, and the most a deviation may grow to.
const START_MU: float = 1100.0
const START_PHI: float = 350.0
const MAX_PHI: float = 350.0
## The least a deviation shrinks to, so a long-time player still moves when they get better.
const MIN_PHI: float = 50.0
## How much a deviation grows a day away (Glicko's c, per day).
const PHI_PER_DAY: float = 8.0
## The outcome a board aims at: the player is expected to do this well on a board at the target.
const TARGET_SUCCESS: float = 0.75
## The least an outcome is when a board is solved at all, and what each help costs it.
const SOLVED_FLOOR: float = 0.1
const PER_MOVE_OVER: float = 0.12
const PER_HINT: float = 0.2
const PER_BOOSTER: float = 0.15
const PER_RESTART: float = 0.1
const PER_SLOW_DOUBLING: float = 0.1
## A board's expected time: a base plus this much a move of par.
const EXPECTED_BASE: float = 6.0
const EXPECTED_PER_MOVE: float = 4.0

const Q: float = 0.0057564627 # ln(10) / 400

## A board of difficulty `d` bits, as a rating.
static func board_rating(d: float) -> float:
	return BOARD_BASE + BOARD_PER_BIT * d

## The bits a rating stands for, the inverse of board_rating.
static func board_bits(rating: float) -> float:
	return (rating - BOARD_BASE) / BOARD_PER_BIT

static func g(phi: float) -> float:
	return 1.0 / sqrt(1.0 + 3.0 * Q * Q * phi * phi / (PI * PI))

## The expected outcome of a player at `mu` against an opponent at `r` with deviation `phi`.
static func expected(mu: float, r: float, phi: float) -> float:
	return 1.0 / (1.0 + pow(10.0, -g(phi) * (mu - r) / 400.0))

## One rating period against `games`, each [opponent rating, its deviation, outcome 0 to 1]: the new [mu, phi].
static func update(mu: float, phi: float, games: Array) -> PackedFloat64Array:
	if games.is_empty():
		return PackedFloat64Array([mu, phi])
	var inv_d2: float = 0.0
	var sum: float = 0.0
	for game: Array in games:
		var gj: float = g(float(game[1]))
		var e: float = expected(mu, float(game[0]), float(game[1]))
		inv_d2 += Q * Q * gj * gj * e * (1.0 - e)
		sum += gj * (float(game[2]) - e)
	var denom: float = 1.0 / (phi * phi) + inv_d2
	var new_mu: float = mu + Q / denom * sum
	var new_phi: float = maxf(sqrt(1.0 / denom), MIN_PHI)
	return PackedFloat64Array([new_mu, new_phi])

## A player's deviation after `days` away: it grows back toward MAX_PHI, so a long absence lets the next doors move
## the estimate again.
static func rested(phi: float, days: float) -> float:
	return minf(sqrt(phi * phi + PHI_PER_DAY * PHI_PER_DAY * maxf(days, 0.0)), MAX_PHI)

## One attempt at a board of `d` bits: the player's new [mu, phi].
static func after(mu: float, phi: float, d: float, outcome: float) -> PackedFloat64Array:
	return update(mu, phi, [[board_rating(d), BOARD_PHI, clampf(outcome, 0.0, 1.0)]])

## How well an attempt went, 0 to 1: a solve at par with no help and in about the expected time is 1; moves over par,
## hints, helpers, restarts and much longer times take it down to no less than SOLVED_FLOOR. A quit is 0.
static func outcome(solved: bool, moves: int, par: int, hints: int, boosters: int, restarts: int,
		seconds: float) -> float:
	if not solved:
		return 0.0
	var score: float = 1.0
	score -= PER_MOVE_OVER * maxi(moves - par, 0)
	score -= PER_HINT * hints + PER_BOOSTER * boosters + PER_RESTART * restarts
	var expected_time: float = EXPECTED_BASE + EXPECTED_PER_MOVE * par
	if seconds > expected_time:
		score -= PER_SLOW_DOUBLING * log(seconds / expected_time) / log(2.0)
	return clampf(score, SOLVED_FLOOR, 1.0)

## Whether leaving a board unsolved counts as a loss: only after some real play, so leaving at once costs nothing.
static func counts_as_quit(moves: int, seconds: float) -> bool:
	return moves >= 3 or seconds >= 30.0

## The gap above a board at which a player is expected to reach TARGET_SUCCESS on it.
static func target_gap() -> float:
	return -log(1.0 / TARGET_SUCCESS - 1.0) / log(10.0) * 400.0 / g(BOARD_PHI)

## The difficulty in bits a player at `mu` is expected to manage at TARGET_SUCCESS.
static func comfortable_bits(mu: float) -> float:
	return board_bits(mu - target_gap())

## The analytics band: mu rounded down to a hundred, as text.
static func band(mu: float) -> String:
	return str(int(floor(mu / 100.0)) * 100)
