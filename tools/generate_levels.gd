extends SceneTree

## Writes levels/levels.json: every level of every chapter, each proven solvable with its par, needing its
## chapter's rule, new to the set, and no easier than the one before it, with the chapter list beside them.
## Run: godot --headless --path . -s res://tools/generate_levels.gd [-- seed=2026 out=user://try.json
##   chapters=6 resume=10 workers=8 opening]
## `chapters` stops after that many chapters, for trying a schedule out. `resume` keeps that many chapters
## from the file already written and makes only the ones after them: the file keeps the generator's random
## state at the end of every chapter, so the result is the same as a full run's. `workers` is how many
## worker processes the batched chapters (TiltGenerator.PARALLEL_FROM) spread over; GDScript threads gain
## little, separate processes scale with the cores. `opening` makes only the opening (TiltShowcase) again,
## in the file already written, and leaves every other byte of it as it was: the other levels, the chapters
## and the random states. The same seed always writes the same file, whatever `workers` is, so the levels
## are a build product of the generator.

const OUT: String = "res://levels/levels.json"
## How often a lane that stops before its batches are done is started again before the run gives up.
const RESTARTS: int = 3

## Spreads a batched phase over worker processes: lane k works batches k, k + lanes, ... in order, writing
## one JSON line per batch to its own file, and `take` waits for the batch it is asked for. Workers run
## this script with `work=`.
class Workers:
	extends TiltGenerator.Farm
	var lanes: int
	var _dir: String
	var _pids: PackedInt32Array = PackedInt32Array()
	var _restarts: PackedInt32Array = PackedInt32Array()
	var _done: Dictionary = {}

	func _init(n: int) -> void:
		lanes = n
		_dir = ProjectSettings.globalize_path("user://farm")
		DirAccess.make_dir_recursive_absolute(_dir)

	func start(job: Dictionary) -> void:
		super.start(job)
		_done.clear()
		var file: FileAccess = FileAccess.open(_dir.path_join("job.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(job, "", true, true))
		file.close()
		_pids.resize(lanes)
		_restarts.resize(lanes)
		_restarts.fill(0)
		for k: int in range(lanes):
			_spawn(k, k)

	func take(b: int) -> Array[TiltGenerator.Candidate]:
		var k: int = b % lanes
		_read(k)
		while not _done.has(b):
			if not OS.is_process_running(_pids[k]):
				_read(k)
				if _done.has(b):
					break
				_restarts[k] += 1
				if _restarts[k] > RESTARTS:
					printerr("worker lane %d keeps stopping before batch %d; giving up" % [k, b])
					stop()
					OS.kill(OS.get_process_id())
				_spawn(k, b)
			OS.delay_msec(200)
			_read(k)
		return TiltGenerator.batch_from_json(_done[b])

	func stop() -> void:
		for k: int in range(_pids.size()):
			if OS.is_process_running(_pids[k]):
				OS.kill(_pids[k])
			DirAccess.remove_absolute(_lane(k))

	func _lane(k: int) -> String:
		return _dir.path_join("lane_%d.jsonl" % k)

	func _spawn(k: int, from: int) -> void:
		_pids[k] = OS.create_process(OS.get_executable_path(), ["--headless", "--quiet", "--path",
			ProjectSettings.globalize_path("res://"), "-s", "res://tools/generate_levels.gd", "--",
			"work=" + _dir.path_join("job.json"), "lane=%d" % k, "lanes=%d" % lanes, "from=%d" % from,
			"out=" + _lane(k)])

	## Every whole line a lane has written so far; a line still being written has no newline yet.
	func _read(k: int) -> void:
		if not FileAccess.file_exists(_lane(k)):
			return
		var lines: PackedStringArray = FileAccess.get_file_as_string(_lane(k)).split("\n")
		for line: String in lines.slice(0, lines.size() - 1):
			var entry: Dictionary = JSON.parse_string(line)
			_done[int(entry["b"])] = entry["found"]

func _initialize() -> void:
	var seed_value: int = 2026
	var out: String = OUT
	var chapters: int = TiltGenerator.CHAPTERS.size()
	var kept: int = 0
	var workers: int = 8
	var opening: bool = false
	var work: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg == "opening":
			opening = true
		elif arg.begins_with("seed="):
			seed_value = int(arg.substr(5))
		elif arg.begins_with("out="):
			out = arg.substr(4)
		elif arg.begins_with("chapters="):
			chapters = mini(int(arg.substr(9)), chapters)
		elif arg.begins_with("resume="):
			kept = int(arg.substr(7))
		elif arg.begins_with("workers="):
			workers = maxi(1, int(arg.substr(8)))
		elif arg.contains("="):
			work[arg.get_slice("=", 0)] = arg.substr(arg.find("=") + 1)
	if work.has("work"):
		_work(work, out)
		return
	if opening:
		_reopen(seed_value, out)
		return
	var gen: TiltGenerator = TiltGenerator.new(seed_value)
	if workers > 1:
		gen.farm = Workers.new(workers)
	var states: PackedStringArray = PackedStringArray()
	if kept > 0:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		var problem: String = _resumable(data, kept, seed_value)
		if problem != "":
			push_error("cannot resume after chapter %d: %s" % [kept, problem])
			quit(1)
			return
		var shipped: Dictionary = data
		var count: int = 0
		for c: int in range(kept):
			count += TiltGenerator.chapter_size(c)
			states.append(String((shipped["rng_states"] as Array)[c]))
		gen.resume((shipped["levels"] as Array).slice(0, count), String(states[kept - 1]).to_int())
		print("kept %d levels in %d chapters" % [count, kept])
	var started: int = Time.get_ticks_msec()
	for c: int in range(kept, chapters):
		var phases: Array = TiltGenerator.CHAPTERS[c]["phases"]
		for p: int in range(phases.size()):
			var first: int = gen.levels.size()
			if not gen.add_phase(c, p):
				push_error("chapter %d phase %d: a pool of %d in %d attempts cannot fill a run of %d" % [c + 1, p,
					gen.pooled, gen.attempts, int(phases[p][0])])
				if c > 0:
					print("the first %d chapters are in %s; resume=%d continues from there" % [c, out, c])
				quit(1)
				return
			var made: Array[TiltDifficulty] = gen.made()
			var pars: PackedStringArray = PackedStringArray()
			var bits: PackedStringArray = PackedStringArray()
			for i: int in range(first, made.size()):
				pars.append(str(made[i].par))
				bits.append("%.1f" % made[i].bits)
			print("chapter %d phase %d: levels %d-%d, pool %d from %d attempts, par %s, bits %s  (%.1fs)" % [c + 1,
				p, first + 1, made.size(), gen.pooled, gen.attempts, " ".join(pars), " ".join(bits),
				(Time.get_ticks_msec() - started) / 1000.0])
		if c == 0:
			if not gen.open():
				push_error("the showcase found no opening under level %d" % (TiltShowcase.SLOTS.size() + 1))
				quit(1)
				return
			_report_opening(gen.made())
		states.append(str(gen.rng.state))
		# Written after every chapter, with the random state at its end, so a run that stops for any reason,
		# or fails on a chapter that needs retuning, resumes after the last chapter finished.
		_write(out, seed_value, c + 1, states, gen.levels)
	print("wrote %d levels in %d chapters to %s" % [gen.levels.size(), chapters, out])
	quit(0)

## A worker process: every lanes-th batch of the job, from batch `from` on, one JSON line each.
func _work(args: Dictionary, out: String) -> void:
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(args["work"])))
	var lanes: int = int(args["lanes"])
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	var b: int = int(args["from"])
	while b < int(job["batches"]):
		var found: Array[TiltGenerator.Candidate] = TiltGenerator.batch(job, b)
		file.store_line(JSON.stringify({"b": b, "found": TiltGenerator.batch_to_json(found)}, "", true, true))
		file.flush()
		b += lanes
	file.close()
	quit(0)

## Makes the opening again in the file already written: the levels after it are measured as they are, the
## showcase picks the opening under them, and only the opening's text is replaced in the file.
func _reopen(seed_value: int, out: String) -> void:
	var text: String = FileAccess.get_file_as_string(OUT)
	var data: Variant = JSON.parse_string(text)
	var problem: String = _resumable(data, 1, seed_value)
	if problem != "":
		push_error("cannot make the opening again: %s" % problem)
		quit(1)
		return
	var shipped: Dictionary = data
	var gen: TiltGenerator = TiltGenerator.new(seed_value)
	gen.resume(shipped["levels"], 0)
	if not gen.open():
		push_error("the showcase found no opening under level %d" % (TiltShowcase.SLOTS.size() + 1))
		quit(1)
		return
	var count: int = TiltShowcase.SLOTS.size()
	var made: String = splice(text, gen.levels.slice(0, count))
	if not _kept(shipped, JSON.parse_string(made), gen.levels.slice(0, count)):
		push_error("the new opening did not splice cleanly into %s" % OUT)
		quit(1)
		return
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	file.store_string(made)
	file.close()
	_report_opening(gen.made())
	print("wrote a new opening of %d levels to %s" % [count, out])
	quit(0)

static func _report_opening(made: Array[TiltDifficulty]) -> void:
	for k: int in range(TiltShowcase.SLOTS.size()):
		print("opening level %d: par %d, bits %.2f, %s" % [k + 1, made[k].par, made[k].bits,
			", ".join(PackedStringArray(TiltShowcase.SLOTS[k]["traits"]))])

## `text`, a level file, with its first levels' text replaced by `fresh`, written as _write writes them.
static func splice(text: String, fresh: Array) -> String:
	var start: int = text.find("{", text.find("\"levels\": ["))
	var end: int = start
	for k: int in range(fresh.size()):
		end = _close(text, text.find("{", end))
	var parts: PackedStringArray = PackedStringArray()
	for level: Dictionary in fresh:
		parts.append(JSON.stringify(level, "\t").replace("\n", "\n\t\t"))
	return text.left(start) + ",\n\t\t".join(parts) + text.substr(end)

## Where the JSON object that opens at `from` ends, just past its closing brace.
static func _close(text: String, from: int) -> int:
	var depth: int = 0
	var quoted: bool = false
	var i: int = from
	while i < text.length():
		var ch: String = text[i]
		if quoted:
			if ch == "\\":
				i += 1
			elif ch == "\"":
				quoted = false
		elif ch == "\"":
			quoted = true
		elif ch == "{" or ch == "[":
			depth += 1
		elif ch == "}" or ch == "]":
			depth -= 1
			if depth == 0:
				return i + 1
		i += 1
	return text.length()

## Whether `now`, read back, holds `fresh` as its first levels and everything else as `was` had it.
static func _kept(was: Dictionary, now: Variant, fresh: Array) -> bool:
	if typeof(now) != TYPE_DICTIONARY:
		return false
	var read: Dictionary = now
	var levels: Array = read["levels"]
	var count: int = fresh.size()
	for k: int in range(count):
		var level: Dictionary = levels[k]
		var made: Dictionary = fresh[k]
		if TiltBoard.from_dict(level).to_dict() != TiltBoard.from_dict(made).to_dict() \
				or int(level["par"]) != int(made["par"]):
			return false
	return read["seed"] == was["seed"] and read["chapters"] == was["chapters"] \
		and read["rng_states"] == was["rng_states"] and levels.slice(count) == (was["levels"] as Array).slice(count)

static func _write(out: String, seed_value: int, chapters: int, states: PackedStringArray, levels: Array) -> void:
	var listed: Array = TiltGenerator.chapter_list().slice(0, chapters)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": seed_value, "chapters": listed, "rng_states": states.slice(0, chapters),
		"levels": levels}, "\t"))
	file.close()

## Why the file written before cannot be resumed after `kept` chapters, or "" if it can: it must be from
## the same seed, hold those chapters as they are planned now, and keep the random state after each.
static func _resumable(data: Variant, kept: int, seed_value: int) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "no level file"
	var shipped: Dictionary = data
	if int(shipped.get("seed", -1)) != seed_value:
		return "it was made from another seed"
	var listed: Array = shipped.get("chapters", [])
	var states: Array = shipped.get("rng_states", [])
	if listed.size() < kept or states.size() < kept:
		return "it holds fewer chapters, or no random states"
	var planned: Array = TiltGenerator.chapter_list()
	for c: int in range(kept):
		var a: Dictionary = listed[c]
		var b: Dictionary = planned[c]
		if a.get("name") != b["name"] or int(a.get("count", -1)) != int(b["count"]):
			return "chapter %d has changed" % (c + 1)
	return ""
