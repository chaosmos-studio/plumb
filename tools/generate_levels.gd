extends SceneTree

## Writes levels/levels.json: every level of every chapter, each proven solvable with its par, needing its
## chapter's rule, new to the set, and no easier than the one before it, with the chapter list beside them.
## Run: godot --headless --path . -s res://tools/generate_levels.gd [-- seed=2026 out=user://try.json
##   chapters=6]
## `chapters` stops after that many chapters, for trying a schedule out. The same seed always writes the
## same file, so the levels are a build product of the generator.

const OUT: String = "res://levels/levels.json"

func _initialize() -> void:
	var seed_value: int = 2026
	var out: String = OUT
	var chapters: int = TiltGenerator.CHAPTERS.size()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			seed_value = int(arg.substr(5))
		elif arg.begins_with("out="):
			out = arg.substr(4)
		elif arg.begins_with("chapters="):
			chapters = mini(int(arg.substr(9)), chapters)
	var gen: TiltGenerator = TiltGenerator.new(seed_value)
	var started: int = Time.get_ticks_msec()
	for c: int in range(chapters):
		var phases: Array = TiltGenerator.CHAPTERS[c]["phases"]
		for p: int in range(phases.size()):
			var first: int = gen.levels.size()
			if not gen.add_phase(c, p):
				push_error("chapter %d phase %d: a pool of %d in %d attempts cannot fill a run of %d" % [c + 1, p,
					gen.pooled, gen.attempts, int(phases[p][0])])
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
	var listed: Array = TiltGenerator.chapter_list().slice(0, chapters)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": seed_value, "chapters": listed, "levels": gen.levels}, "\t"))
	file.close()
	print("wrote %d levels in %d chapters to %s" % [gen.levels.size(), listed.size(), out])
	quit(0)
