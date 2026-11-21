extends SceneTree

## Writes levels/meta.json: each bundled board's metadata by its id (REVAMP_PLAN.md section 4.1), measured once here
## and never on the phone. For every board of the main path (main-0001 on), the Hard levels (hard-0001 on) and the
## generated extras (x-0001 on, levels/pool.json): `d` (its difficulty in bits, MATH.md section 5, a board with the
## turning lock scaled up to the four-way measure, section 16), `par`, `w`, `h`, `marble_count`, `colours`, `set`
## (the rules on it), `need` (the rule its chapter teaches, "" for none), `positions` (the tie-break) and `feel`
## (roomy or tight, from marbles per cell).
##
## Measuring every board takes a while, so it splits: `godot --headless --path . -s res://tools/level_meta.gd --
## part=K/N` measures every Nth board from K into user://meta_part_K.json, and `-- merge=N` joins the N parts into the
## file. tools/level_meta.sh runs the parts side by side.

const OUT: String = "res://levels/meta.json"
const POOL: String = "res://levels/pool.json"
## The deepest search a board is measured with, and the one a board too deep for it is measured again with.
const LIMIT: int = 400000
## A board is tight from this many marbles a cell.
const TIGHT: float = 0.1

func _initialize() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=")
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	if args.has("merge"):
		_merge(int(args["merge"]))
	else:
		var spec: PackedStringArray = str(args.get("part", "0/1")).split("/")
		_measure(int(spec[0]), int(spec[1]))
	quit()

## Every bundled board as [id, board dict, chapter rule].
static func boards() -> Array:
	var out: Array = []
	var main: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))
	var levels: Array = main["levels"]
	for i: int in range(levels.size()):
		out.append(["main-%04d" % (i + 1), levels[i], _rule(TiltGenerator.chapter_at(i))])
	var hard: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/hard.json"))
	var first: int = int(hard["first"])
	var hard_levels: Array = hard["levels"]
	# The Hard levels are the old climb from its chapter 10 on, made before the later chapters were added, so their
	# chapters are the ones not marked after_hard, in order.
	var old: Array = []
	for c: int in range(TiltGenerator.CHAPTERS.size()):
		if not bool(TiltGenerator.CHAPTERS[c].get("after_hard", false)):
			old.append(c)
	for j: int in range(hard_levels.size()):
		out.append(["hard-%04d" % (j + 1), hard_levels[j], _rule(_old_chapter(old, first + j))])
	if FileAccess.file_exists(POOL):
		var pool: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(POOL))
		for entry: Variant in pool["boards"]:
			var b: Dictionary = entry
			out.append([str(b["id"]), b, str(b.get("need", ""))])
	return out

static func _rule(c: int) -> String:
	return str(TiltGenerator.CHAPTERS[c]["rule"])

## The chapter of the old climb (chapters `old`, in order) that its level `i` sat in.
static func _old_chapter(old: Array, i: int) -> int:
	var end: int = 0
	for c: int in old:
		end += TiltGenerator.chapter_size(c)
		if i < end:
			return c
	return old[-1]

## The metadata of one board.
static func measure(level: Dictionary, need: String) -> Dictionary:
	var board: TiltBoard = TiltBoard.from_dict(level)
	var par: int = int(level["par"])
	var m: TiltDifficulty = TiltDifficulty.of(board, par, LIMIT)
	var rules: PackedStringArray = TiltGenerator.rules_on(board)
	var bits: float = m.bits if m.solved() else -1.0
	# With one way locked a random player has three tilts, so the board's bits are put on the four-way scale.
	var d: float = bits / (log(3.0) / log(4.0)) if rules.has(TiltGenerator.THREE_WAY) and bits > 0.0 else bits
	var colours: Dictionary = {}
	var count: int = 0
	for k: int in range(board.marble_colour.size()):
		if board.marble_colour[k] != TiltBoard.STONE:
			colours[board.marble_colour[k]] = true
			count += 1
	return {"d": snappedf(d, 0.0001), "par": par, "w": board.width, "h": board.height, "marble_count": count,
		"colours": colours.size(), "set": Array(rules), "need": need, "positions": m.states,
		"feel": "tight" if float(count) / float(board.width * board.height) >= TIGHT else "roomy"}

func _measure(k: int, n: int) -> void:
	var all: Array = boards()
	var out: Dictionary = {}
	for i: int in range(k, all.size(), n):
		var entry: Array = all[i]
		out[entry[0]] = measure(entry[1], entry[2])
	var file: FileAccess = FileAccess.open("user://meta_part_%d.json" % k, FileAccess.WRITE)
	file.store_string(JSON.stringify(out))
	print("LEVEL_META part %d of %d: %d boards" % [k, n, out.size()])

func _merge(n: int) -> void:
	var out: Dictionary = {}
	for k: int in range(n):
		var part: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://meta_part_%d.json" % k))
		out.merge(part)
	var ids: Array = out.keys()
	ids.sort()
	var ordered: Dictionary = {}
	for id: String in ids:
		ordered[id] = out[id]
	var file: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": 1, "boards": ordered}, " ", false) + "\n")
	var unsolved: int = 0
	for id: String in ids:
		unsolved += 1 if float((ordered[id] as Dictionary)["d"]) < 0.0 else 0
	print("LEVEL_META merged %d boards, %d unmeasured" % [ids.size(), unsolved])
