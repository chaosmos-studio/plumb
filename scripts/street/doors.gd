class_name StreetDoors
extends RefCounted

## The street's doors over a picker state (StreetPicker.fresh) and the stars won (REVAMP_PLAN.md section 4.5). Pure:
## the stars come from a Callable that takes a board id and answers its best stars, Save.best_of in the game.
##
## Every door with a board is open. The lit one, where the cast stands, is the door after the furthest one solved, so a
## door skipped with a key before 2.0 stays an open, unlit door to come back to. Only the lit door is ever picked new.

## The furthest door solved, 0 for none.
static func furthest_solved(state: Dictionary, best: Callable) -> int:
	var doors: PackedStringArray = state["doors"]
	for n: int in range(doors.size(), 0, -1):
		if int(best.call(doors[n - 1])) > 0:
			return n
	return 0

## The lit door: the one after the furthest solved.
static func current(state: Dictionary, best: Callable) -> int:
	return furthest_solved(state, best) + 1

## The board on door `n`, or "" before it is picked.
static func id_of(state: Dictionary, n: int) -> String:
	var doors: PackedStringArray = state["doors"]
	return doors[n - 1] if n >= 1 and n <= doors.size() else ""

## The highest main level on the street, as a count (main-0042 is 42), 0 for none.
static func highest_main(state: Dictionary) -> int:
	var top: int = 0
	for id: String in state["doors"]:
		if id.begins_with("main-") and not id.contains("~"):
			top = maxi(top, int(id.substr(5)))
	return top

## Classic to Street: every main board solved in Classic past the street's highest main board joins the street, in
## order, and the climb rises to at least its position. So a Classic player at level 127 who switches sees doors 1 to
## 127 and goes on from there. True when the street changed.
static func absorb_classic(state: Dictionary, stars: PackedByteArray, pool: StreetPool) -> bool:
	var changed: bool = false
	for i: int in range(highest_main(state), stars.size()):
		if stars[i] == 0:
			continue
		var id: String = "main-%04d" % (i + 1)
		if not pool.has(id):
			continue
		state["p"] = maxf(float(state["p"]), float(i + 1))
		StreetPicker.record(state, pool, {"id": id, "d": pool.d_of(id), "par": pool.par_of(id), "step": "classic"})
		state["solved"] = int(state.get("solved", 0)) + 1
		changed = true
	return changed

## Street to Classic: every main level up to the street's highest main board not solved yet, to open in Classic, so
## nothing reached on the street is locked there. Classic's indices, from 0.
static func open_in_classic(state: Dictionary, stars: PackedByteArray) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in range(highest_main(state)):
		if i >= stars.size() or stars[i] == 0:
			out.append(i)
	return out

## Boards solved off the street that the picker should not offer as new: main and Hard boards with stars.
static func solved_off_street(stars: PackedByteArray, hard: PackedByteArray, hard_from: int) -> Dictionary:
	var out: Dictionary = {}
	for i: int in range(stars.size()):
		if stars[i] > 0:
			out["main-%04d" % (i + 1)] = true
	for i: int in range(hard_from, hard.size()):
		if hard[i] > 0:
			out["hard-%04d" % (i - hard_from + 1)] = true
	return out

## Rates a finished attempt into the state: the rest since the last rating widens the deviation first, then the
## outcome moves the estimate. `now` in Unix seconds.
static func rate(state: Dictionary, d: float, outcome: float, now: int) -> void:
	var phi: float = float(state["phi"])
	var at: int = int(state.get("rated_at", 0))
	if at > 0 and now > at:
		phi = StreetRating.rested(phi, float(now - at) / 86400.0)
	var next: PackedFloat64Array = StreetRating.after(float(state["mu"]), phi, d, outcome)
	state["mu"] = next[0]
	state["phi"] = next[1]
	state["rated_at"] = now
