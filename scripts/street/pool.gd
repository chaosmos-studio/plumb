class_name StreetPool
extends RefCounted

## Every board Street can put on a door, by id (REVAMP_PLAN.md section 4.2): the main path (main-0001 on), the Hard
## levels (hard-0001 on), the generated extras (x-0001 on), then verified feed boards, which replace a bundled one
## only with a higher `rev`, minus retired ids. Each board has its metadata (levels/meta.json for the bundled sets),
## measured by a tool and never on the phone. Pure: the tests build pools of their own.

const LEVELS: String = "res://levels/levels.json"
const HARD: String = "res://levels/hard.json"
const EXTRAS: String = "res://levels/pool.json"
const META: String = "res://levels/meta.json"

## Each board's dict (TiltBoard.to_dict with "par"), its metadata and its revision, by id.
var boards: Dictionary = {}
var meta: Dictionary = {}
var revs: Dictionary = {}
## Ids in the order they were added: the main path's first.
var ids: PackedStringArray = PackedStringArray()
## Ids taken out of future picks.
var retired: Dictionary = {}
## The main path's difficulty at each level, made never to fall: the curriculum's reference (4.3).
var main_ref: PackedFloat64Array = PackedFloat64Array()
## The rule each main level's chapter teaches, "" for none, and the rules each main level shows.
var main_need: PackedStringArray = PackedStringArray()
var main_sets: Array = []

static var _shared: StreetPool = null
static var _warming: StreetPool = null
static var _task: int = -1

## The game's own pool, read once and kept: the bundled boards, then the feed's as it merges them. If warm() is still
## reading it, this waits for it.
static func shared() -> StreetPool:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _shared == null:
			_shared = _warming
		_warming = null
	if _shared == null:
		_shared = bundled()
	return _shared

## Starts reading the pool on a worker thread, so the first door's card never waits for it.
static func warm() -> void:
	if _shared != null or _task >= 0:
		return
	_task = WorkerThreadPool.add_task(func() -> void: StreetPool._warming = StreetPool.bundled(), false, "street pool")

## The bundled pool, read from the game's files.
static func bundled() -> StreetPool:
	var pool: StreetPool = StreetPool.new()
	var info: Dictionary = {}
	if FileAccess.file_exists(META):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(META))
		if data is Dictionary:
			info = (data as Dictionary).get("boards", {})
	var main: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVELS))
	var levels: Array = main["levels"]
	for i: int in range(levels.size()):
		var id: String = "main-%04d" % (i + 1)
		pool.add(id, levels[i], info.get(id, {}), 1)
	var hard: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HARD))
	var hard_levels: Array = hard["levels"]
	for j: int in range(hard_levels.size()):
		var id: String = "hard-%04d" % (j + 1)
		pool.add(id, hard_levels[j], info.get(id, {}), 1)
	if FileAccess.file_exists(EXTRAS):
		var extras: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXTRAS))
		if extras is Dictionary:
			for entry: Variant in (extras as Dictionary)["boards"]:
				var b: Dictionary = entry
				pool.add(str(b["id"]), b, info.get(str(b["id"]), b), int(b.get("rev", 1)))
	pool.refresh()
	return pool

## Adds or replaces board `id`: a board already here is replaced only by a higher revision.
func add(id: String, board: Dictionary, info: Dictionary, rev: int = 1) -> bool:
	if boards.has(id) and rev <= int(revs.get(id, 0)):
		return false
	if not boards.has(id):
		ids.append(id)
	boards[id] = board
	revs[id] = rev
	var m: Dictionary = info.duplicate()
	if not m.has("par"):
		m["par"] = int(board.get("par", 0))
	meta[id] = m
	return true

## Takes ids out of future picks. A board already on a street stays playable there.
func retire(gone: Array) -> void:
	for id: Variant in gone:
		retired[str(id)] = true

## Applies re-scored difficulties (id to bits), for future picks only.
func rescore(scores: Dictionary) -> void:
	for id: Variant in scores:
		if meta.has(str(id)):
			(meta[str(id)] as Dictionary)["d"] = float(scores[id])

## Works out the main path's reference difficulty and teaching order from the boards' metadata.
func refresh() -> void:
	main_ref = PackedFloat64Array()
	main_need = PackedStringArray()
	main_sets = []
	var top: float = 0.0
	var i: int = 1
	while meta.has("main-%04d" % i):
		var m: Dictionary = meta["main-%04d" % i]
		top = maxf(top, float(m.get("d", 0.0)))
		main_ref.append(top)
		main_need.append(str(m.get("need", "")))
		main_sets.append(m.get("set", []))
		i += 1

func has(id: String) -> bool:
	return boards.has(base_of(id))

## A board's difficulty in bits, par and other metadata. A recycled id reads its source's.
func d_of(id: String) -> float:
	return float((meta.get(base_of(id), {}) as Dictionary).get("d", 0.0))

func par_of(id: String) -> int:
	return int((meta.get(base_of(id), {}) as Dictionary).get("par", 0))

func info(id: String) -> Dictionary:
	return meta.get(base_of(id), {})

## The board on a door: its own, or for a recycled id `<id>~<s><p>`, its source turned by symmetry `s` with its
## colours permuted by `p` (4.3).
func board(id: String) -> TiltBoard:
	var source: TiltBoard = TiltBoard.from_dict(boards[base_of(id)])
	if not id.contains("~"):
		return source
	var tail: String = id.get_slice("~", 1)
	var turned: TiltBoard = TiltNovelty.transform(source, int(tail.substr(0, 1)))
	return permuted(turned, int(tail.substr(1)))

## The id a recycled id was made from.
static func base_of(id: String) -> String:
	return id.get_slice("~", 0)

## `board` with its marble colours (and their holes) renamed by permutation number `p` of its colours, so a recycled
## board looks new while playing the same.
static func permuted(board: TiltBoard, p: int) -> TiltBoard:
	var colours: Array[int] = []
	for c: int in board.marble_colour:
		if c != TiltBoard.STONE and not colours.has(c):
			colours.append(c)
	colours.sort()
	var order: Array[int] = colours.duplicate()
	# The p-th permutation, by the factorial number system.
	var left: Array[int] = colours.duplicate()
	var k: int = p
	order.clear()
	for n: int in range(colours.size(), 0, -1):
		var f: int = 1
		for m: int in range(1, n):
			f *= m
		@warning_ignore("integer_division")
		var pick: int = (k / f) % n
		order.append(left[pick])
		left.remove_at(pick)
	var swap: Dictionary = {}
	for i: int in range(colours.size()):
		swap[colours[i]] = order[i]
	var out: TiltBoard = board.copy()
	for m: int in range(out.marble_colour.size()):
		if swap.has(out.marble_colour[m]):
			out.marble_colour[m] = swap[out.marble_colour[m]]
	for cell: int in range(out.holes.size()):
		if swap.has(out.holes[cell]):
			out.holes[cell] = swap[out.holes[cell]]
		# Tiles that name a colour (a door's, a paint pot's, a key's and its locks') follow the marbles' new names.
		if out.tiles[cell] in [TiltBoard.Tile.DOOR, TiltBoard.Tile.PAINT, TiltBoard.Tile.KEY, TiltBoard.Tile.LOCK] \
				and swap.has(out.tile_value[cell]):
			out.tile_value[cell] = swap[out.tile_value[cell]]
	return out

## The main path's reference difficulty at climb position `p` (in main levels, 1 at the first), between levels.
func ref_d(p: float) -> float:
	if main_ref.is_empty():
		return 0.0
	var at: float = clampf(p, 1.0, float(main_ref.size()))
	var lo: int = int(floor(at)) - 1
	var hi: int = mini(lo + 1, main_ref.size() - 1)
	return lerpf(main_ref[lo], main_ref[hi], at - floor(at))

## The furthest main level whose reference difficulty is at most `d`: where on the climb a board of `d` bits belongs.
func level_at(d: float) -> int:
	var lo: int = 0
	var hi: int = main_ref.size()
	while lo < hi:
		@warning_ignore("integer_division")
		var mid: int = (lo + hi) / 2
		if main_ref[mid] <= d + 0.0001:
			lo = mid + 1
		else:
			hi = mid
	return lo

## The rules the main path has shown by climb position `p`: every rule on its boards up to there.
func taught(p: float) -> Dictionary:
	var out: Dictionary = {}
	for i: int in range(mini(int(floor(p)), main_sets.size())):
		for rule: Variant in main_sets[i]:
			out[str(rule)] = true
	return out

## The rule taught at climb position `p`, and the position its teaching began, as [rule, start].
func newest(p: float) -> Array:
	var i: int = clampi(int(floor(p)) - 1, 0, main_need.size() - 1)
	var rule: String = main_need[i]
	var start: int = i
	while start > 0 and main_need[start - 1] == rule:
		start -= 1
	return [rule, start + 1]

## The coverage report (4.2): how many boards there are per rule set and per quarter bit, to show where slow climbers
## would run short.
func coverage() -> Dictionary:
	var by_set: Dictionary = {}
	var by_quarter: Dictionary = {}
	for id: String in ids:
		if retired.has(id):
			continue
		var m: Dictionary = meta[id]
		var rules: Array = m.get("set", [])
		var key: String = "+".join(PackedStringArray(rules)) if not rules.is_empty() else "plain"
		by_set[key] = int(by_set.get(key, 0)) + 1
		var q: String = "%.2f" % (floor(float(m.get("d", 0.0)) * 4.0) / 4.0)
		by_quarter[q] = int(by_quarter.get(q, 0)) + 1
	return {"sets": by_set, "quarters": by_quarter}
