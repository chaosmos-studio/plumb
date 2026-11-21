extends SceneTree

## The pool's coverage report (REVAMP_PLAN.md section 4.2): how many boards Street can pick from per rule set and per
## quarter bit, with the main path's own count beside each quarter, so a thin stretch of the climb shows before a slow
## climber finds it. Run: godot --headless --path . -s res://tools/pool_coverage.gd

func _initialize() -> void:
	var pool: StreetPool = StreetPool.bundled()
	var report: Dictionary = pool.coverage()
	var main: Dictionary = {}
	for id: String in pool.ids:
		if id.begins_with("main-"):
			var q: String = "%.2f" % (floor(pool.d_of(id) * 4.0) / 4.0)
			main[q] = int(main.get(q, 0)) + 1
	print("POOL %d boards: %d main, %d Hard, %d extras" % [pool.ids.size(), _count(pool, "main-"),
		_count(pool, "hard-"), _count(pool, "x-")])
	print("POOL by quarter bit (all / main):")
	var quarters: Array = (report["quarters"] as Dictionary).keys()
	quarters.sort_custom(func(a: String, b: String) -> bool: return float(a) < float(b))
	for q: String in quarters:
		print("  %6s  %4d  %4d" % [q, int(report["quarters"][q]), int(main.get(q, 0))])
	print("POOL by rule set:")
	var sets: Array = (report["sets"] as Dictionary).keys()
	sets.sort_custom(func(a: String, b: String) -> bool: return int(report["sets"][a]) > int(report["sets"][b]))
	for s: String in sets:
		print("  %4d  %s" % [int(report["sets"][s]), s])
	quit()

func _count(pool: StreetPool, prefix: String) -> int:
	var n: int = 0
	for id: String in pool.ids:
		n += 1 if id.begins_with(prefix) else 0
	return n
