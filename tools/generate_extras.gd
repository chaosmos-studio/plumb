extends SceneTree

## Writes levels/pool.json: Street's bundled extras, x-0001 on (REVAMP_PLAN.md section 4.2). The main path has one
## board at each step of the climb; a slow climber meets more doors at each step, so the pool needs more boards along
## the ramp than the main path holds (the simulated players in the tests ran dry within 60 doors without them). For
## each main level of the ramp, from OPENING_END to RAMP_END, this makes PER_LEVEL more boards like it, by the
## generator's own rules (TiltGenerator.batch): its chapter's phase and rule, its par range and a window of bits around
## the level's own. The plateau needs none: every band board with taught rules serves there, and the band holds flat.
## Every extra is new: none replays a main level, a Hard level or another extra (TiltNovelty.clash).
##
## It takes a while, so it splits like tools/level_meta.gd: `-- part=K/N` makes the extras for every Nth main level
## from K into user://extras_part_K.json, and `-- merge=N` joins them, drops any two that clash across parts, numbers
## them in main-level order and writes the file. tools/generate_extras.sh runs the parts side by side. Then
## tools/level_meta.sh measures them into levels/meta.json.

const OUT: String = "res://levels/pool.json"
const SEED: int = 20261121
## Main levels before this one get no extras: the opening is fixed and the first chapter is tiny. The ramp ends where
## the plateau begins, and each of its levels gets this many extras.
const OPENING_END: int = 6
const RAMP_END: int = 180
const PER_LEVEL: int = 3
## The bits window around a ramp level, below and above it.
const BELOW: float = 0.25
const ABOVE: float = 0.75
## How many batches of proposals a level may use before it gives up.
const MAX_BATCHES: int = 90

var _avoid: Array[TiltNovelty.Views] = []

func _initialize() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=")
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	if args.has("merge"):
		_merge(int(args["merge"]))
	else:
		var spec: PackedStringArray = str(args.get("part", "0/1")).split("/")
		_make(int(spec[0]), int(spec[1]))
	quit()

## The views of every main and Hard level, which no extra may replay.
func _reserve() -> Array:
	var levels: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json")) as Dictionary)["levels"]
	var hard: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://levels/hard.json")) as Dictionary)["levels"]
	for level: Variant in levels + hard:
		var board: TiltBoard = TiltBoard.from_dict(level as Dictionary)
		_avoid.append(TiltNovelty.views(board, TiltSolver.new().solve(board, 200000)))
	return levels

func _clashes(v: TiltNovelty.Views, others: Array[TiltNovelty.Views]) -> bool:
	for other: TiltNovelty.Views in others:
		if TiltNovelty.clash(other, v) != "":
			return true
	return false

## The phase of its chapter that main level `i` (0-based) was made in.
static func phase_index(i: int) -> int:
	var c: int = TiltGenerator.chapter_at(i)
	var k: int = i - TiltGenerator.chapter_start(c)
	var phases: Array = TiltGenerator.CHAPTERS[c]["phases"]
	for p: int in range(phases.size()):
		k -= int(phases[p][0])
		if k < 0:
			return p
	return phases.size() - 1

func _make(k: int, n: int) -> void:
	var levels: Array = _reserve()
	var made: Array = []
	var mine: Array[TiltNovelty.Views] = []
	for i: int in range(OPENING_END - 1 + k, RAMP_END, n):
		var c: int = TiltGenerator.chapter_at(i)
		var level: Dictionary = levels[i]
		var board: TiltBoard = TiltBoard.from_dict(level)
		var bits: float = TiltDifficulty.of(board, int(level["par"]), 400000).bits
		var job: Dictionary = {"chapter": c, "phase": phase_index(i), "seed": hash([SEED, i]), "last": {},
			"lo": bits - BELOW, "hi": bits + ABOVE, "by_par": false}
		job["cap"] = int(TiltGenerator.phase_of(c, int(job["phase"]))[8])
		var found: int = 0
		for b: int in range(MAX_BATCHES):
			for cand: TiltGenerator.Candidate in TiltGenerator.batch(job, b):
				if found >= PER_LEVEL or _clashes(cand.views, _avoid) or _clashes(cand.views, mine):
					continue
				mine.append(cand.views)
				var entry: Dictionary = cand.board.to_dict()
				entry["par"] = cand.measure.par
				entry["after"] = i + 1
				entry["need"] = str(TiltGenerator.CHAPTERS[c]["rule"])
				entry["path"] = Array(cand.measure.path)
				made.append(entry)
				found += 1
			if found >= PER_LEVEL:
				break
		print("GENERATE_EXTRAS level %d: %d of %d" % [i + 1, found, PER_LEVEL])
	var file: FileAccess = FileAccess.open("user://extras_part_%d.json" % k, FileAccess.WRITE)
	file.store_string(JSON.stringify(made))

func _merge(n: int) -> void:
	var all: Array = []
	for k: int in range(n):
		var part: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://extras_part_%d.json" % k))
		if part is Array:
			all.append_array(part as Array)
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["after"]) < int(b["after"]))
	var kept: Array = []
	var views: Array[TiltNovelty.Views] = []
	for entry: Variant in all:
		var e: Dictionary = entry
		var board: TiltBoard = TiltBoard.from_dict(e)
		var v: TiltNovelty.Views = TiltNovelty.views(board, PackedInt32Array(e["path"]))
		if _clashes(v, views):
			continue
		views.append(v)
		e.erase("path")
		e["id"] = "x-%04d" % (kept.size() + 1)
		e["rev"] = 1
		kept.append(e)
	var file: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": 1, "seed": SEED, "boards": kept}) + "\n")
	print("GENERATE_EXTRAS merged %d extras from %d made" % [kept.size(), all.size()])
