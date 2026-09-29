extends SceneTree

## Writes levels/levels.json: every level of every tier, each proven solvable with its par.
## Run: godot --headless --path . -s res://tools/generate_levels.gd [-- seed=2026]
## The same seed always writes the same file, so the levels are a build product of the generator.

const OUT: String = "res://levels/levels.json"

func _initialize() -> void:
	var seed_value: int = 2026
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			seed_value = int(arg.substr(5))
	var gen: TiltGenerator = TiltGenerator.new(seed_value)
	var levels: Array = []
	var seen: Dictionary = {}
	var started: int = Time.get_ticks_msec()
	for t: int in range(TiltGenerator.TIERS.size()):
		var tier: Array = TiltGenerator.TIERS[t]
		var made: Array = []
		for k: int in range(int(tier[0])):
			var level: Dictionary = gen.make(tier, seen)
			if level.is_empty():
				push_error("tier %d: no level found for slot %d" % [t, k])
				quit(1)
				return
			made.append(level)
		# Within a tier, easier first: shortest par, then fewest marbles.
		made.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["par"]) < int(b["par"]))
		levels.append_array(made)
		print("tier %d: %d levels, par %s  (%.1fs)" % [t, made.size(),
			str(made.map(func(l: Dictionary) -> int: return int(l["par"]))), (Time.get_ticks_msec() - started) / 1000.0])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels"))
	var file: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": seed_value, "levels": levels}, "\t"))
	file.close()
	print("wrote %d levels to %s" % [levels.size(), OUT])
	quit(0)
