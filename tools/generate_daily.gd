extends SceneTree

## Writes levels/daily.json: a level for each day from FIRST, for the daily puzzle (kit/daily).
## Run: godot --headless --path . -s res://tools/generate_daily.gd [-- days=400 workers=8 out=user://try.json]
## Each day is made from its own seed, so a day comes out the same whatever `workers` is and however many
## days are asked for, and more days can be added later without changing the ones already played.
##
## The daily opens once the first two chapters are solved, so its boards use only what they teach: marbles,
## up to three colours, walls. The week climbs from Monday to Sunday by board size and par, and every board
## is measured by the solver like a campaign level, its par the fewest tilts that solve it.

const OUT: String = "res://levels/daily.json"
const CAMPAIGN: String = "res://levels/levels.json"
## The day the games went live on Google Play, so the calendar has a few weeks to look back on from the start.
const FIRST: String = "2026-10-19"
const OPENS_AFTER: int = 40
const SEED: int = 7031
const DAYS: int = 400
## A phase as TiltGenerator reads it (count, width, height, colours, marbles, wall density, pits, par min,
## par max, marks), one for each weekday from Sunday.
const WEEK: Array = [
	[1, 8, 8, 3, 5, 0.16, 0, 9, 12, {}],
	[1, 6, 6, 3, 3, 0.15, 0, 5, 7, {}],
	[1, 6, 7, 3, 4, 0.15, 0, 6, 8, {}],
	[1, 7, 7, 3, 4, 0.15, 0, 6, 9, {}],
	[1, 7, 7, 3, 4, 0.16, 0, 7, 10, {}],
	[1, 7, 8, 3, 5, 0.16, 0, 8, 11, {}],
	[1, 8, 8, 3, 5, 0.16, 0, 8, 12, {}],
]
const LIMIT: int = 12000
const TRIES: int = 200000

func _initialize() -> void:
	var days: int = DAYS
	var workers: int = 8
	var out: String = OUT
	var part: int = -1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("days="):
			days = int(arg.substr(5))
		elif arg.begins_with("workers="):
			workers = maxi(1, int(arg.substr(8)))
		elif arg.begins_with("out="):
			out = arg.substr(4)
		elif arg.begins_with("part="):
			part = int(arg.substr(5))
	if part >= 0:
		_work(part, workers, days, out)
		quit(0)
		return
	var started: int = Time.get_ticks_msec()
	var dir: String = ProjectSettings.globalize_path("user://daily")
	DirAccess.make_dir_recursive_absolute(dir)
	var pids: PackedInt32Array = PackedInt32Array()
	for k: int in range(workers):
		var lane: String = dir.path_join("part_%d.jsonl" % k)
		DirAccess.remove_absolute(lane)
		pids.append(OS.create_process(OS.get_executable_path(), ["--headless", "--quiet", "--path",
			ProjectSettings.globalize_path("res://"), "-s", "res://tools/generate_daily.gd", "--", "part=%d" % k,
			"workers=%d" % workers, "days=%d" % days, "out=" + lane]))
	for pid: int in pids:
		while OS.is_process_running(pid):
			OS.delay_msec(250)
	# Each worker's line is the day, a tab and the level's JSON as written, which is kept as it is: parsing it
	# back would turn every number into a float.
	var by_day: Dictionary = {}
	for k: int in range(workers):
		for line: String in FileAccess.get_file_as_string(dir.path_join("part_%d.jsonl" % k)).split("\n", false):
			by_day[line.get_slice("\t", 0).to_int()] = line.get_slice("\t", 1)
	var campaign: Dictionary = {}
	for level: Variant in (JSON.parse_string(FileAccess.get_file_as_string(CAMPAIGN)) as Dictionary)["levels"]:
		campaign[_shape(level as Dictionary)] = true
	var levels: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for i: int in range(days):
		if not by_day.has(i):
			push_error("day %d was not made" % i)
			quit(1)
			return
		var shape: String = _shape(JSON.parse_string(String(by_day[i])))
		if campaign.has(shape) or seen.has(shape):
			push_error("day %d repeats a level" % i)
			quit(1)
			return
		seen[shape] = true
		levels.append(String(by_day[i]))
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	file.store_string('{"first": "%s", "opens_after": %d, "seed": %d, "levels": [\n%s\n]}\n' % [FIRST, OPENS_AFTER,
		SEED, ",\n".join(levels)])
	file.close()
	print("wrote %d days to %s in %.1fs" % [days, out, (Time.get_ticks_msec() - started) / 1000.0])
	quit(0)

func _work(part: int, workers: int, days: int, out: String) -> void:
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	var first: int = DailyDays.from_date(FIRST)
	for i: int in range(part, days, workers):
		var level: Dictionary = make(i, int(DailyDays.date(first + i)["weekday"]))
		if level.is_empty():
			printerr("day %d: nothing in %d tries" % [i, TRIES])
			continue
		file.store_line("%d\t%s" % [i, JSON.stringify(level, "", true)])
		file.flush()
	file.close()

## The level for day `i` of the bank, whose weekday is `weekday`.
static func make(i: int, weekday: int) -> Dictionary:
	var phase: Array = WEEK[weekday]
	var gen: TiltGenerator = TiltGenerator.new(hash([SEED, i]))
	for t: int in range(TRIES):
		var c: TiltGenerator.Candidate = TiltGenerator._try(gen._propose(phase), phase, "", LIMIT, -1.0, 1e9, null)
		if c != null and c.measure.par <= int(phase[8]):
			var level: Dictionary = c.board.to_dict()
			level["par"] = c.measure.par
			return level
	return {}

static func _shape(level: Dictionary) -> String:
	var copy: Dictionary = level.duplicate()
	copy.erase("par")
	return JSON.stringify(copy, "", true)
