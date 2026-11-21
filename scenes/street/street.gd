class_name Street
extends RefCounted

## The street over the save (REVAMP_PLAN.md sections 4.3 to 4.5): which board each door holds, the door to play next,
## what a solve or a quit does to the rating and the climb, and the switch between the looks. The rules are pure, in
## StreetPicker, StreetDoors and StreetRating; this only reads and writes Save.

static func pool() -> StreetPool:
	return StreetPool.shared()

## The lit door, where the cast stands: the one after the furthest solved.
static func current() -> int:
	return StreetDoors.current(Save.street, Save.best_of)

## The board on door `n`, "" before it is picked.
static func id_of(n: int) -> String:
	return StreetDoors.id_of(Save.street, n)

static func stars(n: int) -> int:
	var id: String = id_of(n)
	return Save.best_of(id) if id != "" else 0

## Every door with a board is open, and so is the lit one.
static func is_open(n: int) -> bool:
	return n <= (Save.street["doors"] as PackedStringArray).size() or n == current()

## Door `n`'s board id, picked now if it is the lit door and has none yet, and kept on the street for good.
static func board_id(n: int) -> String:
	var id: String = id_of(n)
	if id != "":
		return id
	var state: Dictionary = Save.street.duplicate(true)
	var doors: int = (state["doors"] as PackedStringArray).size()
	# Only the next door is ever picked, so the street has no holes.
	if n != doors + 1:
		return ""
	var skip: Dictionary = StreetDoors.solved_off_street(Save.stars, Save.hard_stars, HardShelf.FIRST)
	var picked: Dictionary = StreetPicker.pick(pool(), state, n, Save.player_id, skip)
	StreetPicker.record(state, pool(), picked)
	Save.set_street(state)
	return str(picked["id"])

static func board(n: int) -> TiltBoard:
	return pool().board(board_id(n))

## The par door `n` was picked with.
static func par(n: int) -> int:
	var pars: PackedInt32Array = Save.street["door_par"]
	return pars[n - 1] if n >= 1 and n <= pars.size() else pool().par_of(board_id(n))

## The difficulty door `n` was picked with, in bits.
static func difficulty(n: int) -> float:
	var ds: PackedFloat64Array = Save.street["door_d"]
	return ds[n - 1] if n >= 1 and n <= ds.size() else 0.0

## How the board on door `n` was chosen, for analytics: a step of the picker (StreetPicker.STEPS), "migrated" or
## "classic" for a door brought from before Street or from Classic, or "".
static func pick_of(n: int) -> String:
	var steps: PackedStringArray = Save.street.get("door_pick", PackedStringArray())
	return steps[n - 1] if n >= 1 and n <= steps.size() else ""

## The player's rating now.
static func rating() -> float:
	return float(Save.street["mu"])

## What analytics hears about door `n` while it is played (REVAMP_PLAN.md section 5.2): its board, the path, the
## board's difficulty, the player's rating as it began, how the board was picked and whether it is a replay.
static func analytics(n: int) -> Dictionary:
	return {"board": id_of(n), "path": "street", "difficulty": difficulty(n), "rating": rating(), "pick": pick_of(n),
		"replay": "yes" if stars(n) > 0 else "no"}

## Classic's level `level` of the section in play, the same way.
static func classic_analytics(level: int) -> Dictionary:
	var id: String = Pack.id_of(level)
	return {"board": id, "path": "hard" if Pack.is_hard(level) else "main", "difficulty": pool().d_of(id),
		"rating": rating(), "replay": "yes" if Save.best(level) > 0 else "no"}

## The furthest level as analytics names it (user property furthest_level): the furthest door solved in Street, the
## furthest main level solved in Classic.
static func furthest_level() -> int:
	if Save.app_look == AppLook.STREET:
		return StreetDoors.furthest_solved(Save.street, Save.best_of)
	for i: int in range(Save.stars.size() - 1, -1, -1):
		if Save.stars[i] > 0:
			return i + 1
	return 0

## Sets the user properties that follow play (5.1): the rating's band and the furthest level.
static func tell_analytics() -> void:
	Analytics.user_property("rating_band", StreetRating.band(rating()))
	Analytics.user_property("furthest_level", str(furthest_level()))

## A solve on door `n`: its stars, and on a first solve the rating moves by how it went and, if it was the furthest
## door yet, the climb moves on by the pace. Replays change nothing but the stars. Answers whether it was a first solve.
static func won(n: int, earned: int, moves: int, hints: int, helpers: int, restarts: int, seconds: float) -> bool:
	var id: String = id_of(n)
	if id == "":
		return false
	var first: bool = Save.best_of(id) == 0
	var furthest: int = StreetDoors.furthest_solved(Save.street, Save.best_of)
	Save.record_id(id, earned)
	if not first:
		return false
	var state: Dictionary = Save.street.duplicate(true)
	var outcome: float = StreetRating.outcome(true, moves, par(n), hints, helpers, restarts, seconds)
	StreetDoors.rate(state, difficulty(n), outcome, _now())
	state["solved"] = int(state.get("solved", 0)) + 1
	if n > furthest:
		state["p"] = StreetPicker.climbed(state, pool())
	Save.set_street(state)
	return true

## Leaving door `n` unsolved: a loss for the rating after real play on a door not solved yet, nothing otherwise.
static func quit(n: int, moves: int, seconds: float) -> void:
	var id: String = id_of(n)
	if id == "" or Save.best_of(id) > 0 or not StreetRating.counts_as_quit(moves, seconds):
		return
	rate(difficulty(n), 0.0)

## An attempt in Classic, whose play moves the same rating (decision 4): on board `id`, never solved before it, a solve
## by how it went or a quit after real play. Replays change nothing.
static func rate_classic(id: String, unsolved_before: bool, solved: bool, moves: int, par_moves: int, hints: int,
		restarts: int, seconds: float) -> void:
	if not unsolved_before or (not solved and not StreetRating.counts_as_quit(moves, seconds)):
		return
	rate(pool().d_of(id), StreetRating.outcome(solved, moves, par_moves, hints, 0, restarts, seconds))

## A rated attempt on a board of difficulty `d`, by its outcome.
static func rate(d: float, outcome: float) -> void:
	var state: Dictionary = Save.street.duplicate(true)
	StreetDoors.rate(state, d, outcome, _now())
	Save.set_street(state)

## Classic to Street: the main boards solved in Classic past the street's join it (StreetDoors.absorb_classic).
static func absorb_classic() -> void:
	var state: Dictionary = Save.street.duplicate(true)
	if StreetDoors.absorb_classic(state, Save.stars, pool()):
		Save.set_street(state)

## Street to Classic: every main level up to the street's highest is opened there.
static func open_in_classic() -> void:
	for i: int in StreetDoors.open_in_classic(Save.street, Save.stars):
		if not Save.opened.has(i):
			Save.opened.append(i)
	Save.store()

static func _now() -> int:
	return int(Time.get_unix_time_from_system())
