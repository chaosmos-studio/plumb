class_name FilmMotion
extends RefCounted

## The Chaosmos motion language, from the pipeline's motion.json, which the spec carries: a few durations,
## an arrive curve that lands softly and a shorter leave curve that accelerates away, both cubic-bezier.
## Text only ever fades and rises a little. Overshoot belongs to things that are physical in the games.

static var fast: float = 0.12
static var base: float = 0.3
static var large: float = 0.5
static var fill: float = 0.6
static var arrive_curve: PackedFloat32Array = PackedFloat32Array([0.05, 0.7, 0.1, 1.0])
static var leave_curve: PackedFloat32Array = PackedFloat32Array([0.3, 0.0, 0.8, 0.15])
static var leave_ratio: float = 0.6
static var text_rise: float = 0.008
static var ball_cover: float = 0.36
static var ball_reveal: float = 0.3

static func use(m: Dictionary) -> void:
	if m.is_empty():
		return
	var d: Dictionary = m.get("durations", {})
	fast = float(d.get("fast", fast))
	base = float(d.get("base", base))
	large = float(d.get("large", large))
	fill = float(d.get("fill", fill))
	arrive_curve = _curve(m.get("arrive", []), arrive_curve)
	leave_curve = _curve(m.get("leave", []), leave_curve)
	leave_ratio = float(m.get("leave_ratio", leave_ratio))
	text_rise = float(m.get("text_rise", text_rise))
	var b: Dictionary = m.get("ball", {})
	ball_cover = float(b.get("cover", ball_cover))
	ball_reveal = float(b.get("reveal", ball_reveal))

static func arrive(k: float) -> float:
	return _bezier(clampf(k, 0.0, 1.0), arrive_curve)

static func leave(k: float) -> float:
	return _bezier(clampf(k, 0.0, 1.0), leave_curve)

## How long something takes to leave when it took `arrive_time` to arrive.
static func leave_time(arrive_time: float) -> float:
	return arrive_time * leave_ratio

static func _curve(v: Variant, fallback: PackedFloat32Array) -> PackedFloat32Array:
	if v is Array and (v as Array).size() == 4:
		return PackedFloat32Array(v as Array)
	return fallback

## The curve's y at x, found by bisecting on t: Newton's step stalls on the steep start of the arrive curve.
static func _bezier(x: float, c: PackedFloat32Array) -> float:
	var lo: float = 0.0
	var hi: float = 1.0
	var t: float = x
	for i: int in range(24):
		t = (lo + hi) * 0.5
		if _cubic(t, c[0], c[2]) < x:
			lo = t
		else:
			hi = t
	return _cubic(t, c[1], c[3])

static func _cubic(t: float, a: float, b: float) -> float:
	var u: float = 1.0 - t
	return 3.0 * u * u * t * a + 3.0 * u * t * t * b + t * t * t
