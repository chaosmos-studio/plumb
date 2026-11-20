class_name StreetRewards
extends RefCounted

## What Street gives and what its shop asks (REVAMP_PLAN.md section 4.7), as pure functions of the door, so the map,
## the parcel, the milestone and the tests all agree. Every number is a constant here, for Shravan to tune. Rewards
## are generous: help is given freely and never sold as power.

## Coins for a win: a base, more for each star, and more for a clean solve (no undo, restart or hint).
const WIN_BASE: int = 10
const WIN_PER_STAR: int = 5
const WIN_CLEAN: int = 5
## Coins for the day's puzzle.
const DAILY: int = 30

## A parcel waits after every PARCEL_EVERY doors, and a milestone, a new family's house, after every
## MILESTONE_EVERY, in place of that door's parcel.
const PARCEL_EVERY: int = 5
const MILESTONE_EVERY: int = 20
## A later parcel's coins, and how many of its booster.
const PARCEL_COINS: int = 60
const PARCEL_BOOSTERS: int = 1
## A milestone's coins, and how many of each booster it brings.
const MILESTONE_COINS: int = 200
const MILESTONE_BOOSTERS: int = 1

## The three helpers (section 4.7): their ids, the door each first arrives at in a parcel, and how many come then.
enum Booster { FOOTPRINTS, GHOSTS, SPARE_STEP }
const BOOSTER_IDS: PackedStringArray = ["footprints", "ghosts", "spare_step"]
const BOOSTER_AT: PackedInt32Array = [5, 10, 15]
const BOOSTER_FIRST: int = 3

## The shop's prices, in coins.
const PRICE_HAT: int = 20
const PRICE_MARBLES: int = 40
const PRICE_BOOSTER: int = 30

## The hats there are to own, worn one per cast member.
const HATS: int = 4
## The families, in the order their houses arrive, each with its house.
const FAMILIES: PackedStringArray = ["bakers", "millers", "clockkeepers", "tree_housers"]
const FAMILY_HOUSES: PackedStringArray = ["milestone_bakery", "milestone_windmill", "milestone_clock_tower",
	"milestone_tree_house"]

## Coins for winning a board with `stars`, clean when no undo, restart or hint was used.
static func win_coins(stars: int, clean: bool) -> int:
	return WIN_BASE + WIN_PER_STAR * clampi(stars, 0, 3) + (WIN_CLEAN if clean else 0)

## Whether a win earns the golden knocker: par or better, with no hint and no restart. A spare step never counts, so
## the knocker always means par by the board's own measure.
static func knocker(moves: int, par: int, hinted: bool, restarted: bool) -> bool:
	return moves <= par and not hinted and not restarted

## The stars a win earns (Stars.earned), with the spare step's one move of leeway when one is used.
static func stars(moves: int, par: int, spare: bool) -> int:
	return Stars.earned(maxi(moves - (1 if spare else 0), 0), par)

## Whether door `n` is a milestone, a family's house.
static func is_milestone(n: int) -> bool:
	return n > 0 and n % MILESTONE_EVERY == 0

## Whether winning door `n` brings a parcel (every PARCEL_EVERY doors, except where a milestone stands).
static func has_parcel(n: int) -> bool:
	return n > 0 and n % PARCEL_EVERY == 0 and not is_milestone(n)

## The family whose house stands at milestone door `n`: they come round in turn.
static func family_of(n: int) -> int:
	@warning_ignore("integer_division")
	return posmod(n / MILESTONE_EVERY - 1, FAMILIES.size())

## The booster a door first unlocks, or -1.
static func unlocks(n: int) -> int:
	return BOOSTER_AT.find(n)

## Whether booster `b` is open by the time the player stands at door `n`.
static func booster_open(b: int, n: int) -> bool:
	return n > BOOSTER_AT[b]

## What the parcel after door `n` holds: {"coins", "booster", "count", "hat"} (booster and hat are -1 when absent).
## The first three each bring a new helper, three of it. Later ones bring coins and, in turn, one helper or a hat.
static func parcel(n: int) -> Dictionary:
	var first: int = unlocks(n)
	if first >= 0:
		return {"coins": 0, "booster": first, "count": BOOSTER_FIRST, "hat": -1}
	@warning_ignore("integer_division")
	var k: int = n / PARCEL_EVERY
	if k % 3 == 2:
		return {"coins": PARCEL_COINS, "booster": -1, "count": 0, "hat": posmod(k, HATS)}
	return {"coins": PARCEL_COINS, "booster": posmod(k, BOOSTER_IDS.size()), "count": PARCEL_BOOSTERS, "hat": -1}

## What a milestone at door `n` brings: {"coins", "boosters"} (boosters: how many of each), and its family.
static func milestone(n: int) -> Dictionary:
	return {"coins": MILESTONE_COINS, "boosters": MILESTONE_BOOSTERS, "family": family_of(n)}
