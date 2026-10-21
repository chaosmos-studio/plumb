class_name CloudSave
extends RefCounted

## Joins this phone's save with the copy in the player's Google account, key by key, so progress made on
## either is never lost: the best stars of each level, every level opened, every daily solved. Settings stay
## this phone's own, and purchases come from Play itself, so neither is copied.

## "section/key" in Save's file, to how two values become one.
const RULES: Dictionary = {
	"progress/stars": &"best_each",
	"progress/opened": &"union",
	"progress/tutorial_seen": &"either",
	"monetize/keys": &"most",
	"monetize/tips": &"most",
	"daily/record": &"daily",
}

static func pack() -> String:
	var file: ConfigFile = ConfigFile.new()
	file.load(Save.path)
	return file.encode_to_text()

## Play keeps the copy with the most progress when two phones save at once, so this only ever grows.
static func progress() -> int:
	return Save.total_stars() * 1000 + Daily.solves()

static func absorb(text: String) -> void:
	var theirs: ConfigFile = ConfigFile.new()
	if text == "" or theirs.parse(text) != OK:
		return
	var mine: ConfigFile = ConfigFile.new()
	mine.load(Save.path)
	merge(mine, theirs)
	mine.save(Save.path)
	Save.restore()
	EventBus.settings_changed.emit()

static func merge(mine: ConfigFile, theirs: ConfigFile) -> void:
	for at: String in RULES:
		var section: String = at.get_slice("/", 0)
		var key: String = at.get_slice("/", 1)
		if not theirs.has_section_key(section, key):
			continue
		var ours: Variant = mine.get_value(section, key, null)
		mine.set_value(section, key, join(RULES[at], ours, theirs.get_value(section, key)))

static func join(rule: StringName, a: Variant, b: Variant) -> Variant:
	if typeof(a) == TYPE_NIL:
		return b
	match rule:
		&"best_each":
			var x: PackedByteArray = a if a is PackedByteArray else PackedByteArray()
			var y: PackedByteArray = b if b is PackedByteArray else PackedByteArray()
			var out: PackedByteArray = x.duplicate()
			out.resize(maxi(x.size(), y.size()))
			for i: int in range(y.size()):
				out[i] = maxi(out[i], y[i])
			return out
		&"union":
			var out2: PackedInt32Array = PackedInt32Array(a) if a is PackedInt32Array else PackedInt32Array()
			if b is PackedInt32Array:
				for v: int in b:
					if not out2.has(v):
						out2.append(v)
			return out2
		&"either":
			return bool(a) or bool(b)
		&"most":
			return maxi(int(a), int(b))
		&"daily":
			return join_daily(a if a is Dictionary else {}, b if b is Dictionary else {})
	return a

## Each day keeps its faster first solve, which was late only if it was late on every phone that solved it.
static func join_daily(a: Dictionary, b: Dictionary) -> Dictionary:
	var ta: Dictionary = a.get("times", {})
	var tb: Dictionary = b.get("times", {})
	var la: Array = a.get("late", [])
	var lb: Array = b.get("late", [])
	var times: Dictionary = ta.duplicate()
	for d: Variant in tb:
		var t: int = int(tb[d])
		times[d] = mini(int(times[d]), t) if times.has(d) else t
	var late: Array = []
	for d: Variant in times:
		if (not ta.has(d) or la.has(d)) and (not tb.has(d) or lb.has(d)):
			late.append(d)
	var opened: Array = (a.get("open", []) as Array).duplicate()
	for d: Variant in b.get("open", []):
		if not opened.has(d):
			opened.append(d)
	var clock: Dictionary = (a.get("clock", {}) as Dictionary).duplicate()
	for d: Variant in b.get("clock", {}):
		clock[d] = maxi(int(clock.get(d, 0)), int((b["clock"] as Dictionary)[d]))
	for d: Variant in times:
		clock.erase(d)
	return {"times": times, "late": late, "open": opened, "clock": clock}
