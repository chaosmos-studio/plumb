extends SceneTree

## Writes levels/levels.json: the chapter list and every level of every chapter with its par.
## Run: godot --headless --path . -s res://tools/generate_levels.gd [-- seed=2026 out=user://try.json
##   chapters=6 resume=10 workers=8 opening shelve climb]
## Chapters are made in TiltGenerator.making_order, which puts a chapter added after the Hard levels last, and
## written in the game's order. `chapters` stops after that many chapters made, for trying a schedule out.
## `resume` keeps that many chapters made from the file already written and makes only the ones after them: the
## file keeps the generator's random state after every chapter made, so the result is the same as a full run's.
## Resuming after every chapter (`resume=26 chapters=26`) makes nothing and writes the file again, which is how a
## chapter's name or line changes. `workers` is how many
## worker processes the batched chapters (TiltGenerator.PARALLEL_FROM) spread over. GDScript threads gain
## little, separate processes scale with the cores. `opening` makes only the opening (TiltShowcase) again,
## in the file already written, and leaves every other byte of it as it was. The same seed always writes
## the same file, whatever `workers` is, so the levels are a build product of the generator.
## `shelve` copies the levels from TiltGenerator.PLATEAU_FROM on, as the file holds them, into levels/hard.json,
## once, before those chapters are made again on the plateau: they are the Hard levels (MATH.md section 16), and
## no level made after may replay one. `climb` makes every chapter on the ramp, as the Hard levels were made.

const OUT: String = "res://levels/levels.json"
const HARD: String = "res://levels/hard.json"
## How often a lane that stops before its batches are done is started again before the run gives up.
const RESTARTS: int = 3

## Lane k works batches k, k + lanes, ... in order, writing one JSON line per batch to its own file.
## Workers run this script with `work=`.
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

	## Only whole lines: a line still being written has no newline yet.
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
	var shelve: bool = false
	var climb: bool = false
	var work: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg == "opening":
			opening = true
		elif arg == "shelve":
			shelve = true
		elif arg == "climb":
			climb = true
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
	if shelve:
		_shelve(seed_value)
		return
	var gen: TiltGenerator = TiltGenerator.new(seed_value)
	if workers > 1:
		gen.farm = Workers.new(workers)
	gen.plateau = not climb
	# Chapters are made, kept and resumed in making order (TiltGenerator.making_order), and written in the game's.
	var order: PackedInt32Array = TiltGenerator.making_order()
	var hard: Variant = null
	if gen.plateau and Array(order.slice(kept, chapters)).any(func(c: int) -> bool: return c >= TiltGenerator.PLATEAU_FROM):
		hard = JSON.parse_string(FileAccess.get_file_as_string(HARD)) if FileAccess.file_exists(HARD) else null
		if typeof(hard) != TYPE_DICTIONARY:
			push_error("the plateau makes chapter %d on again: shelve the Hard levels first" % (TiltGenerator.PLATEAU_FROM + 1))
			quit(1)
			return
	var states: PackedStringArray = PackedStringArray()
	if kept > 0:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		var problem: String = _resumable(data, kept, seed_value)
		if problem != "":
			push_error("cannot resume after %d chapters: %s" % [kept, problem])
			quit(1)
			return
		var shipped: Dictionary = data
		var made: Array = []
		var places: PackedInt32Array = PackedInt32Array()
		for step: int in range(kept):
			var c: int = order[step]
			var at: int = _offset(shipped["chapters"], String(TiltGenerator.CHAPTERS[c]["name"]))
			made.append_array((shipped["levels"] as Array).slice(at, at + TiltGenerator.chapter_size(c)))
			for k: int in range(TiltGenerator.chapter_size(c)):
				places.append(TiltGenerator.chapter_start(c) + k)
			states.append(String((shipped["rng_states"] as Array)[step]))
		gen.resume(made, places, String(states[kept - 1]).to_int())
		print("kept %d levels in %d chapters" % [made.size(), kept])
	if hard != null:
		var known: bool = gen.levels.size() >= TiltGenerator.PLATEAU_LEVEL
		var deepest: int = int(gen.floor_level()["par"]) + TiltGenerator.PLATEAU_PARS if known else 1 << 30
		gen.reserve((hard as Dictionary)["levels"], deepest)
		print("kept clear of %d Hard levels" % ((hard as Dictionary)["levels"] as Array).size())
	var started: int = Time.get_ticks_msec()
	for step: int in range(kept, chapters):
		var c: int = order[step]
		var phases: Array = TiltGenerator.CHAPTERS[c]["phases"]
		for p: int in range(phases.size()):
			var first: int = gen.levels.size()
			if not gen.add_phase(c, p):
				var whole: bool = gen.plateau and c >= TiltGenerator.PLATEAU_FROM
				push_error("chapter %d phase %d: a pool of %d in %d attempts cannot fill a run of %d" % [c + 1, p,
					gen.pooled, gen.attempts, TiltGenerator.chapter_size(c) if whole else int(phases[p][0])])
				if step > 0:
					print("the first %d chapters made are in %s; resume=%d continues from there" % [step, out, step])
				quit(1)
				return
			var made: Array[TiltDifficulty] = gen.made()
			if made.size() == first:
				print("chapter %d phase %d: pool %d from %d attempts, held for the chapter's run  (%.1fs)" % [c + 1, p,
					gen.pooled, gen.attempts, (Time.get_ticks_msec() - started) / 1000.0])
				continue
			var pars: PackedStringArray = PackedStringArray()
			var bits: PackedStringArray = PackedStringArray()
			for i: int in range(first, made.size()):
				pars.append(str(made[i].par))
				bits.append("%.1f" % made[i].bits)
			print("chapter %d phase %d: levels %d-%d, pool %d from %d attempts, par %s, bits %s  (%.1fs)" % [c + 1,
				p, gen.placed[first] + 1, gen.placed[made.size() - 1] + 1, gen.pooled, gen.attempts, " ".join(pars),
				" ".join(bits), (Time.get_ticks_msec() - started) / 1000.0])
		if c == 0:
			if not gen.open():
				push_error("the showcase found no opening under level %d" % (TiltShowcase.SLOTS.size() + 1))
				quit(1)
				return
			_report_opening(gen.made())
		states.append(str(gen.rng.state))
		# Written after every chapter, with the random state at its end, so a run that stops for any reason,
		# or fails on a chapter that needs retuning, resumes after the last chapter finished.
		_write(out, seed_value, order.slice(0, step + 1), states, gen.shipped())
	# Keeping every chapter made writes the file again as it is, with the chapters' names and lines as they are now.
	if kept >= chapters:
		_write(out, seed_value, order.slice(0, chapters), states, gen.shipped())
	print("wrote %d levels in %d chapters to %s" % [gen.levels.size(), chapters, out])
	quit(0)

## Where chapter `name` starts in a level file's list of chapters, which holds only the chapters made so far.
static func _offset(listed: Array, name: String) -> int:
	var at: int = 0
	for entry: Variant in listed:
		if String((entry as Dictionary)["name"]) == name:
			return at
		at += int((entry as Dictionary)["count"])
	return -1

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
	var places: PackedInt32Array = PackedInt32Array()
	for k: int in range((shipped["levels"] as Array).size()):
		places.append(k)
	gen.resume(shipped["levels"], places, 0)
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

## Once only: a second shelve would copy the plateau over the Hard levels.
func _shelve(seed_value: int) -> void:
	if FileAccess.file_exists(HARD):
		push_error("%s already holds the Hard levels" % HARD)
		quit(1)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT))
	var problem: String = _resumable(data, TiltGenerator.CHAPTERS.size(), seed_value)
	if problem != "":
		push_error("cannot shelve the Hard levels: %s" % problem)
		quit(1)
		return
	var first: int = TiltGenerator.chapter_start(TiltGenerator.PLATEAU_FROM)
	var shelved: Array = ((data as Dictionary)["levels"] as Array).slice(first)
	var file: FileAccess = FileAccess.open(HARD, FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": seed_value, "first": first, "levels": shelved}, "\t"))
	file.close()
	print("shelved levels %d-%d as the Hard levels in %s" % [first + 1, first + shelved.size(), HARD])
	quit(0)

static func _report_opening(made: Array[TiltDifficulty]) -> void:
	for k: int in range(TiltShowcase.SLOTS.size()):
		print("opening level %d: par %d, bits %.2f, %s" % [k + 1, made[k].par, made[k].bits,
			", ".join(PackedStringArray(TiltShowcase.SLOTS[k]["traits"]))])

## Writes `fresh` as _write would, so every other byte of `text` stays as it was.
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

## `made` names the chapters made so far, which are listed in the game's order, and `states` holds the random
## state after each, in the order they were made.
static func _write(out: String, seed_value: int, made: PackedInt32Array, states: PackedStringArray, levels: Array) -> void:
	var listed: Array = []
	var all: Array = TiltGenerator.chapter_list()
	for c: int in range(all.size()):
		if made.has(c):
			listed.append(all[c])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": seed_value, "chapters": listed, "rng_states": states.slice(0, made.size()),
		"levels": levels}, "\t"))
	file.close()

## Why the file written before cannot be resumed after the first `kept` chapters made, or "" if it can.
static func _resumable(data: Variant, kept: int, seed_value: int) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "no level file"
	var shipped: Dictionary = data
	if int(shipped.get("seed", -1)) != seed_value:
		return "it was made from another seed"
	var listed: Array = shipped.get("chapters", [])
	var states: Array = shipped.get("rng_states", [])
	if states.size() < kept:
		return "it holds no random state after chapter %d made" % kept
	var order: PackedInt32Array = TiltGenerator.making_order()
	for step: int in range(kept):
		var c: int = order[step]
		var found: bool = false
		for entry: Variant in listed:
			var a: Dictionary = entry
			found = found or (a.get("name") == TiltGenerator.CHAPTERS[c]["name"]
				and int(a.get("count", -1)) == TiltGenerator.chapter_size(c))
		if not found:
			return "chapter %d is missing or has changed" % (c + 1)
	return ""
