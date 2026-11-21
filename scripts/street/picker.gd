class_name StreetPicker
extends RefCounted

## Which board goes on the next door (REVAMP_PLAN.md section 4.3, MATH.md section 29). Pure and seeded by the player's
## id and the door's number, so a door's board is reproducible and, once picked, is saved on the street for good.
##
## The player has a climb position `p` on the main path, the curriculum: the rules taught by `p` are the ones its
## chapters have taught by then, and its reference difficulty is the main path's there, made never to fall. After a
## solve `p` moves on by the pace, which comes from the rating's gap to the reference. Difficulty never drops: the
## target for the next door is never below the last one's, no board is easier than the hardest door so far, and par
## never falls, until the comfort ceiling, where boards stay in the band and never fall below its floor.

## Doors that always open the street: the opening chosen to be remembered.
const OPENING: int = 5
## The pace, in main levels a door, and the gap that doubles it.
const PACE_MIN: float = 0.6
const PACE_MAX: float = 2.5
const PACE_DOUBLING: float = 200.0
## The comfort ceiling: today's plateau band (MATH.md section 16), its par and its largest boards.
const CEIL_FLOOR: float = 18.85
const CEIL_TOP: float = 20.35
const CEIL_PAR: int = 12
const CEIL_W: int = 7
const CEIL_H: int = 8
const CEIL_MARBLES: int = 5
## How far above the target a board may be, normally and widened.
const WINDOW: float = 0.6
const WIDE: float = 1.6
## What raising par by one move costs a candidate, in bits of distance from the target. Without it, simulated players
## below 1700 ran 3 to 5 bits above their target by door 60: par ratchets too, and every raise shuts out the boards
## at the floor with a lower par.
const PAR_COST: float = 0.5
## A new rule's first doors, which prefer boards that need it.
const TEACH_DOORS: int = 4
## How many recent doors' layouts a board may not repeat.
const RECENT: int = 2

## The steps that can choose a board, recorded for analytics (`pick`), each giving up one more wish: first the feel's
## alternation and the layout's change, then the new rule's preference, and only then the window upward. Widening
## first, as the plan once said, sent boards racing ahead of a slow climber on a thin pool, and since no door may be
## easier than the last, a door too hard stays that hard: the simulated players showed it.
const STEPS: PackedStringArray = ["opening", "fit", "any_feel", "any_need", "wide", "recycle"]

## The state a pick reads: the doors so far, each door's board id, difficulty and par when played, the climb position,
## the last target and the floor (the hardest door so far, which no new door goes below). The rating rides along, with
## when it last moved and how many doors are solved, so a cloud copy brings all of it together. A Dictionary, so the
## save keeps it as it is.
static func fresh() -> Dictionary:
	return {"doors": PackedStringArray(), "door_d": PackedFloat64Array(), "door_par": PackedInt32Array(),
		"door_pick": PackedStringArray(), "p": 1.0, "target": 0.0, "floor": 0.0, "mu": StreetRating.START_MU,
		"phi": StreetRating.START_PHI, "rated_at": 0, "solved": 0}

## The pace after a solve, in main levels a door: 1 is the main path's own. From the gap between the player's rating
## and the reference board's, centred where the player is expected to do as well as the target success.
static func pace(mu: float, ref_d: float) -> float:
	var gap: float = mu - StreetRating.board_rating(ref_d) - StreetRating.target_gap()
	return clampf(pow(2.0, gap / PACE_DOUBLING), PACE_MIN, PACE_MAX)

## Moves the climb position on after a solve. It never goes back.
static func climbed(state: Dictionary, pool: StreetPool) -> float:
	var p: float = float(state["p"])
	return p + pace(float(state["mu"]), pool.ref_d(p))

## The target difficulty for the next door: the reference at `p`, never below the last target, and never above the
## ceiling's top once it gets there.
static func target(state: Dictionary, pool: StreetPool) -> float:
	var ref: float = minf(pool.ref_d(float(state["p"])), CEIL_TOP)
	return maxf(ref, float(state["target"]))

## Picks door `door`'s board: {"id", "d", "par", "step"}. `door` is 1 for the first door. `skip` holds boards already
## solved off the street (in Classic), which are not offered again as new.
static func pick(pool: StreetPool, state: Dictionary, door: int, player: String, skip: Dictionary = {}) -> Dictionary:
	if door <= OPENING:
		var id: String = "main-%04d" % door
		return {"id": id, "d": pool.d_of(id), "par": pool.par_of(id), "step": "opening"}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s/%d" % [player, door])
	var doors: PackedStringArray = state["doors"]
	var door_d: PackedFloat64Array = state["door_d"]
	var door_par: PackedInt32Array = state["door_par"]
	var last_d: float = maxf(door_d[-1] if not door_d.is_empty() else 0.0, float(state.get("floor", 0.0)))
	var last_par: int = door_par[-1] if not door_par.is_empty() else 0
	var aim: float = target(state, pool)
	var at_ceiling: bool = last_d >= CEIL_FLOOR or aim >= CEIL_TOP
	# Never an easier board than the last door's, nor a lower par; in the band, never below its floor.
	var floor_d: float = minf(last_d, CEIL_FLOOR) if at_ceiling else last_d
	var floor_par: int = mini(last_par, CEIL_PAR) if at_ceiling else last_par
	var p: float = float(state["p"])
	# A floor ahead of the climb already plays boards from further along, so their rules count as taught too: else
	# the few boards at the floor with only the climb's rules are used up one a door, and the floor runs on ahead.
	var taught: Dictionary = pool.taught(maxf(maxf(p, float(pool.level_at(floor_d))), float(OPENING)))
	var newest: Array = pool.newest(p)
	var teaching: bool = str(newest[0]) != "" and p - float(newest[1]) < float(TEACH_DOORS)
	var played: Dictionary = skip.duplicate()
	for id: String in doors:
		played[StreetPool.base_of(id)] = true
	var recent: Array[String] = []
	for k: int in range(maxi(doors.size() - RECENT, 0), doors.size()):
		recent.append(_bucket(pool.info(doors[k])))
	var last_feel: String = str(pool.info(doors[-1]).get("feel", "")) if not doors.is_empty() else ""
	var top: float = maxf(aim, floor_d)
	for step: int in range(1, STEPS.size() - 1):
		var wide: bool = STEPS[step] == "wide"
		var hi: float = (CEIL_TOP if at_ceiling else top + (WIDE if wide else WINDOW))
		var best: String = ""
		var best_cost: float = INF
		for id: String in pool.ids:
			if played.has(id) or pool.retired.has(id):
				continue
			var m: Dictionary = pool.meta[id]
			var d: float = float(m.get("d", -1.0))
			var par: int = int(m.get("par", 0))
			if d < floor_d or d > hi or par < floor_par:
				continue
			if not _taught(m, taught):
				continue
			if at_ceiling and (int(m.get("w", 0)) > CEIL_W or int(m.get("h", 0)) > CEIL_H
					or int(m.get("marble_count", 0)) > CEIL_MARBLES or par > CEIL_PAR + 1):
				continue
			# The fit step keeps every wish; any_feel lets the feel and layout repeat; any_need drops the new rule's
			# preference; wide reaches further up.
			if step < 2 and recent.has(_bucket(m)):
				continue
			if step < 2 and last_feel != "" and str(m.get("feel", "")) == last_feel:
				continue
			var needs_new: bool = teaching and str(m.get("need", "")) == str(newest[0])
			if teaching and step < 3 and not needs_new:
				continue
			# Par never falls, so a board that raises it narrows every pick after: each step up costs PAR_COST.
			var cost: float = absf(d - aim) + PAR_COST * float(par - floor_par) + rng.randf() * 0.001
			if cost < best_cost:
				best_cost = cost
				best = id
		if best != "":
			return {"id": best, "d": pool.d_of(best), "par": pool.par_of(best), "step": STEPS[step]}
	return _recycle(pool, state, floor_d, floor_par, rng)

## The last resort, so the street never runs out offline: the least recently played board at or above the floor,
## turned by one of the seven other symmetries with its colours permuted, as an id no door has had.
static func _recycle(pool: StreetPool, state: Dictionary, floor_d: float, floor_par: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var doors: PackedStringArray = state["doors"]
	var used: Dictionary = {}
	for id: String in doors:
		used[id] = true
	# Doors from the oldest: the first that qualifies is the least recently played.
	for k: int in range(doors.size()):
		var base: String = StreetPool.base_of(doors[k])
		if pool.d_of(base) < floor_d or pool.par_of(base) < floor_par:
			continue
		for attempt: int in range(16):
			var s: int = 1 + rng.randi_range(0, 6)
			var perm: int = rng.randi_range(0, 23)
			var id: String = "%s~%d%d" % [base, s, perm]
			if not used.has(id):
				return {"id": id, "d": pool.d_of(base), "par": pool.par_of(base), "step": "recycle"}
	# Nothing played yet qualifies: the hardest board the pool has, turned.
	var hardest: String = ""
	for id: String in pool.ids:
		if hardest == "" or pool.d_of(id) > pool.d_of(hardest):
			hardest = id
	var turned: String = "%s~%d%d" % [hardest, 1 + rng.randi_range(0, 6), rng.randi_range(0, 23)]
	return {"id": turned, "d": pool.d_of(hardest), "par": pool.par_of(hardest), "step": "recycle"}

## A board's rules are all taught by now.
static func _taught(m: Dictionary, taught: Dictionary) -> bool:
	for rule: Variant in m.get("set", []):
		if not taught.has(str(rule)):
			return false
	return true

## The layout bucket a board falls in: its size and marble count, so neighbouring doors look different.
static func _bucket(m: Dictionary) -> String:
	return "%dx%d-%d" % [int(m.get("w", 0)), int(m.get("h", 0)), int(m.get("marble_count", 0))]

## Records door `door`'s pick on the street: its id, difficulty and par, and the target it was picked for.
static func record(state: Dictionary, pool: StreetPool, picked: Dictionary) -> void:
	# Packed arrays are values, so each is changed and put back.
	var doors: PackedStringArray = state["doors"]
	doors.append(str(picked["id"]))
	state["doors"] = doors
	var door_d: PackedFloat64Array = state["door_d"]
	door_d.append(float(picked["d"]))
	state["door_d"] = door_d
	var door_par: PackedInt32Array = state["door_par"]
	door_par.append(int(picked["par"]))
	state["door_par"] = door_par
	var door_pick: PackedStringArray = state.get("door_pick", PackedStringArray())
	door_pick.append(str(picked.get("step", "")))
	state["door_pick"] = door_pick
	state["floor"] = maxf(float(state.get("floor", 0.0)), float(picked["d"]))
	state["target"] = maxf(float(state["target"]), minf(target(state, pool), CEIL_TOP))
