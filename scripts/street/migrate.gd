class_name StreetMigrate
extends RefCounted

## Save layout 3 (REVAMP_PLAN.md section 4.6): Street's street and rating join the save. Pure, on a ConfigFile, so the
## save, the cloud copy and the migration suite in the tests all go through the same steps.
##
## The main path's and the Hard levels' stars stay where they were, in their arrays by position, since a board's
## position there is its id (main-0042 is stars[41], hard-0001 is hard[180]); every other board's stars (extras, feed
## boards, recycled boards) go in `progress/best` by id. So Classic reads its levels as before, and a board solved in
## either look shows solved in the other.

const LAYOUT: int = 3
## The welcome purse for a player who was already playing: this many coins a star (open question 16).
const PURSE_PER_STAR: int = 5
## The rating a migrated player starts from: the rating of their furthest board plus this, and how sure that is.
const START_ABOVE: float = 50.0
const START_PHI: float = 200.0

## Brings `file` to layout 3 in place, if it is older (HardShelf brings a layout 1 file to 2 first). True when it
## changed. Running it again changes nothing.
static func upgrade(file: ConfigFile, pool: StreetPool) -> bool:
	if int(file.get_value("progress", "layout", 1)) >= LAYOUT:
		return false
	var stars: PackedByteArray = _bytes(file.get_value("progress", "stars", PackedByteArray()))
	var hard: PackedByteArray = _bytes(file.get_value("progress", "hard", PackedByteArray()))
	var opened: PackedInt32Array = _ints(file.get_value("progress", "opened", PackedInt32Array()))
	if not file.has_section_key("street", "state"):
		file.set_value("street", "state", state_from(stars, opened, pool))
		# The doors already behind the player: their parcels and milestones count as opened, with the first helpers.
		var solved_to: int = furthest(stars, PackedInt32Array())
		file.set_value("street", "gifts", past_gifts(PackedInt32Array(file.get_value("street", "gifts",
			PackedInt32Array())), solved_to))
		var helpers: Variant = file.get_value("street", "boosters", {})
		file.set_value("street", "boosters", first_helpers(helpers if helpers is Dictionary else {}, solved_to))
	# The welcome purse, once, for a player with stars to their name.
	var total: int = 0
	for s: int in stars:
		total += s
	for s: int in hard:
		total += s
	if total > 0 and not bool(file.get_value("street", "welcomed", false)):
		file.set_value("street", "coins", int(file.get_value("street", "coins", 0)) + PURSE_PER_STAR * total)
		file.set_value("street", "welcomed", true)
	if not file.has_section_key("progress", "best"):
		file.set_value("progress", "best", {})
	file.set_value("progress", "layout", LAYOUT)
	return true

## The street a player already playing starts from: doors 1 to K are main-0001 to main-K, where K is the furthest main
## level solved or opened (a gap skipped with a key stays an open, unlit door to come back to), the climb at K, the
## floor at the hardest of them solved, and the rating at board K's plus START_ABOVE, with START_PHI.
static func state_from(stars: PackedByteArray, opened: PackedInt32Array, pool: StreetPool) -> Dictionary:
	var state: Dictionary = StreetPicker.fresh()
	var k: int = furthest(stars, opened)
	var hardest: float = 0.0
	var solved: int = 0
	for i: int in range(k):
		var id: String = "main-%04d" % (i + 1)
		StreetPicker.record(state, pool, {"id": id, "d": pool.d_of(id), "par": pool.par_of(id), "step": "migrated"})
		if i < stars.size() and stars[i] > 0:
			hardest = maxf(hardest, pool.d_of(id))
			solved += 1
	state["p"] = maxf(float(k), 1.0)
	state["floor"] = hardest
	state["solved"] = solved
	if k > 0:
		state["mu"] = StreetRating.board_rating(pool.d_of("main-%04d" % k)) + START_ABOVE
		state["phi"] = START_PHI
		state["target"] = minf(pool.ref_d(float(k)), StreetPicker.CEIL_TOP)
	return state

## Every parcel and milestone door up to `solved_to` counts as opened, so a player arriving from Classic does not find
## a street of unopened parcels and unbroken ribbons behind them: the welcome purse stands for those, and the families
## of those milestones already live there.
static func past_gifts(gifts: PackedInt32Array, solved_to: int) -> PackedInt32Array:
	var out: PackedInt32Array = gifts.duplicate()
	for n: int in range(StreetRewards.PARCEL_EVERY, solved_to + 1, StreetRewards.PARCEL_EVERY):
		if not out.has(n):
			out.append(n)
	return out

## The helpers the first parcels bring (StreetRewards.BOOSTER_AT), for each parcel door up to `solved_to`, so a
## player arriving with those doors behind them has every helper in hand, as one who walked there would.
static func first_helpers(boosters: Dictionary, solved_to: int) -> Dictionary:
	var out: Dictionary = boosters.duplicate()
	for b: int in range(StreetRewards.BOOSTER_IDS.size()):
		var id: String = StreetRewards.BOOSTER_IDS[b]
		if StreetRewards.BOOSTER_AT[b] <= solved_to:
			out[id] = maxi(int(out.get(id, 0)), StreetRewards.BOOSTER_FIRST)
	return out

## The furthest main level solved or opened, as a count: 0 for a new player.
static func furthest(stars: PackedByteArray, opened: PackedInt32Array) -> int:
	var k: int = 0
	for i: int in range(stars.size()):
		if stars[i] > 0:
			k = i + 1
	for i: int in opened:
		k = maxi(k, i + 1)
	return k

static func _bytes(v: Variant) -> PackedByteArray:
	return v if v is PackedByteArray else PackedByteArray()

static func _ints(v: Variant) -> PackedInt32Array:
	return v if v is PackedInt32Array else PackedInt32Array()

## Two streets join to the one with more doors solved, and on a tie the one with more doors, so the copy with more
## progress brings its doors and its rating together (4.6).
static func join_street(a: Variant, b: Variant) -> Variant:
	if not (a is Dictionary):
		return b
	if not (b is Dictionary):
		return a
	var sa: int = int((a as Dictionary).get("solved", 0))
	var sb: int = int((b as Dictionary).get("solved", 0))
	if sa != sb:
		return b if sb > sa else a
	var da: int = ((a as Dictionary).get("doors", PackedStringArray()) as PackedStringArray).size()
	var db: int = ((b as Dictionary).get("doors", PackedStringArray()) as PackedStringArray).size()
	return b if db > da else a

## Numbers by key (stars by board id, helpers by kind) join to the larger of each: the better stars, and for the
## helpers the generous side.
static func join_most_each(a: Variant, b: Variant) -> Dictionary:
	var out: Dictionary = (a as Dictionary).duplicate() if a is Dictionary else {}
	if b is Dictionary:
		for key: Variant in b:
			out[key] = maxi(int(out.get(key, 0)), int((b as Dictionary)[key]))
	return out

## Words in either list.
static func join_words(a: Variant, b: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(a) if a is PackedStringArray else PackedStringArray()
	if b is PackedStringArray:
		for w: String in b:
			if not out.has(w):
				out.append(w)
	return out
