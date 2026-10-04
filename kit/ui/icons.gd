class_name Icons
extends RefCounted

## Line icons drawn with canvas calls: crisp at every size, recoloured for free, and no image files.
## Every icon fits a square of side `s` around `c`, drawn with stroke `w`. Round caps come from a dot at
## each end of a stroke, which is all a line icon needs to look finished.

const NAMES: Array[StringName] = [&"back", &"close", &"next", &"undo", &"restart", &"hint", &"settings",
	&"sound", &"sound_off", &"music", &"music_off", &"haptics", &"haptics_off", &"theme", &"play", &"levels",
	&"lock", &"check", &"heart", &"shop", &"share", &"watch", &"key", &"palette", &"help", &"info", &"looks", &"people",
	&"save", &"reel"]

static func draw(ci: CanvasItem, icon: StringName, c: Vector2, s: float, colour: Color, w: float = -1.0) -> void:
	if w < 0.0:
		w = maxf(2.0, s * 0.085)
	match icon:
		&"back":
			_stroke(ci, [c + Vector2(0.1, -0.28) * s, c + Vector2(-0.16, 0.0) * s, c + Vector2(0.1, 0.28) * s], colour, w)
		&"next":
			_stroke(ci, [c + Vector2(-0.1, -0.28) * s, c + Vector2(0.16, 0.0) * s, c + Vector2(-0.1, 0.28) * s], colour, w)
		&"close":
			_stroke(ci, [c + Vector2(-0.22, -0.22) * s, c + Vector2(0.22, 0.22) * s], colour, w)
			_stroke(ci, [c + Vector2(0.22, -0.22) * s, c + Vector2(-0.22, 0.22) * s], colour, w)
		&"undo":
			var r: float = 0.17 * s
			var o: Vector2 = c + Vector2(0.06, 0.05) * s
			var pts: Array[Vector2] = [c + Vector2(-0.24, -0.12) * s]
			for k: int in range(13):
				var a: float = -PI * 0.5 + PI * k / 12.0
				pts.append(o + Vector2(cos(a), sin(a)) * r)
			pts.append(c + Vector2(-0.12, 0.22) * s)
			_stroke(ci, pts, colour, w)
			_stroke(ci, [c + Vector2(-0.12, -0.24) * s, c + Vector2(-0.24, -0.12) * s, c + Vector2(-0.12, 0.0) * s], colour, w)
		&"restart":
			var r2: float = 0.24 * s
			var start: float = deg_to_rad(-55.0)
			var sweep: float = deg_to_rad(290.0)
			var arc: Array[Vector2] = []
			for k: int in range(25):
				var a2: float = start + sweep * k / 24.0
				arc.append(c + Vector2(cos(a2), sin(a2)) * r2)
			_stroke(ci, arc, colour, w)
			var tip: Vector2 = arc[0]
			var tangent: Vector2 = Vector2(sin(start), -cos(start))
			var side: Vector2 = tangent.orthogonal()
			_stroke(ci, [tip + (-tangent * 0.13 + side * 0.13) * s, tip, tip + (-tangent * 0.13 - side * 0.13) * s], colour, w)
		&"hint":
			var bulb: Vector2 = c + Vector2(0, -0.07) * s
			var rb: float = 0.2 * s
			ci.draw_arc(bulb, rb, deg_to_rad(140.0), deg_to_rad(400.0), 28, colour, w, true)
			var left: Vector2 = bulb + Vector2(cos(deg_to_rad(140.0)), sin(deg_to_rad(140.0))) * rb
			var right: Vector2 = bulb + Vector2(cos(deg_to_rad(40.0)), sin(deg_to_rad(40.0))) * rb
			_stroke(ci, [left, left + Vector2(0.03, 0.1) * s, right + Vector2(-0.03, 0.1) * s, right], colour, w)
			_stroke(ci, [c + Vector2(-0.09, 0.3) * s, c + Vector2(0.09, 0.3) * s], colour, w)
		&"settings":
			var knobs: Array[float] = [-0.1, 0.12, -0.02]
			for k: int in range(3):
				var y: float = (-0.18 + 0.18 * k) * s
				_stroke(ci, [c + Vector2(-0.26 * s, y), c + Vector2(0.26 * s, y)], colour, w)
				ci.draw_circle(c + Vector2(knobs[k] * s, y), 0.065 * s, colour, true, -1.0, true)
		&"sound", &"sound_off":
			_speaker(ci, c + Vector2(-0.08, 0) * s, s, colour)
			if icon == &"sound":
				ci.draw_arc(c + Vector2(-0.02, 0) * s, 0.16 * s, -0.8, 0.8, 16, colour, w, true)
				ci.draw_arc(c + Vector2(-0.02, 0) * s, 0.28 * s, -0.8, 0.8, 20, colour, w, true)
			else:
				_stroke(ci, [c + Vector2(0.1, -0.1) * s, c + Vector2(0.28, 0.1) * s], colour, w)
				_stroke(ci, [c + Vector2(0.28, -0.1) * s, c + Vector2(0.1, 0.1) * s], colour, w)
		&"music", &"music_off":
			var head: Vector2 = c + Vector2(-0.1, 0.17) * s
			_ellipse(ci, head, Vector2(0.11, 0.08) * s, -0.35, colour)
			var stem_x: float = head.x + 0.09 * s
			_stroke(ci, [Vector2(stem_x, head.y - 0.02 * s), Vector2(stem_x, c.y - 0.27 * s)], colour, w)
			_stroke(ci, [Vector2(stem_x, c.y - 0.27 * s), c + Vector2(0.2, -0.14) * s, c + Vector2(0.2, -0.04) * s], colour, w)
			if icon == &"music_off":
				_stroke(ci, [c + Vector2(-0.28, -0.28) * s, c + Vector2(0.28, 0.28) * s], colour, w)
		&"haptics", &"haptics_off":
			var box: Rect2 = Rect2(c - Vector2(0.12, 0.22) * s, Vector2(0.24, 0.44) * s)
			_round_rect(ci, box, 0.05 * s, colour, w)
			for side2: float in [-1.0, 1.0]:
				_stroke(ci, [c + Vector2(side2 * 0.22, -0.1) * s, c + Vector2(side2 * 0.22, 0.1) * s], colour, w)
				_stroke(ci, [c + Vector2(side2 * 0.31, -0.05) * s, c + Vector2(side2 * 0.31, 0.05) * s], colour, w)
			if icon == &"haptics_off":
				_stroke(ci, [c + Vector2(-0.3, -0.3) * s, c + Vector2(0.3, 0.3) * s], colour, w)
		&"theme":
			var r3: float = 0.25 * s
			ci.draw_arc(c, r3, 0.0, TAU, 40, colour, w, true)
			var half: PackedVector2Array = PackedVector2Array()
			for k: int in range(17):
				var a3: float = -PI * 0.5 + PI * k / 16.0
				half.append(c + Vector2(cos(a3), sin(a3)) * r3)
			_fill(ci, half, colour)
		&"play":
			var tri: PackedVector2Array = PackedVector2Array([c + Vector2(-0.14, -0.24) * s, c + Vector2(0.24, 0.0) * s,
				c + Vector2(-0.14, 0.24) * s])
			_fill(ci, tri, colour)
		&"levels":
			for k: int in range(4):
				var cell: Vector2 = c + Vector2(-0.13 if k % 2 == 0 else 0.13, -0.13 if k < 2 else 0.13) * s
				_round_rect(ci, Rect2(cell - Vector2(0.09, 0.09) * s, Vector2(0.18, 0.18) * s), 0.04 * s, colour, w * 0.9)
		&"lock":
			ci.draw_arc(c + Vector2(0, -0.08) * s, 0.12 * s, PI, TAU, 16, colour, w, true)
			_stroke(ci, [c + Vector2(-0.12, -0.08) * s, c + Vector2(-0.12, 0.0) * s], colour, w)
			_stroke(ci, [c + Vector2(0.12, -0.08) * s, c + Vector2(0.12, 0.0) * s], colour, w)
			var body: StyleBoxFlat = StyleBoxFlat.new()
			body.bg_color = colour
			body.set_corner_radius_all(int(0.05 * s))
			body.anti_aliasing = true
			ci.draw_style_box(body, Rect2(c + Vector2(-0.19, -0.02) * s, Vector2(0.38, 0.28) * s))
		&"check":
			_stroke(ci, [c + Vector2(-0.22, 0.02) * s, c + Vector2(-0.06, 0.18) * s, c + Vector2(0.24, -0.14) * s], colour, w)
		&"heart":
			# The classic heart curve, which spans 32 by 29 units with its tip at y = -17.
			var outline: Array[Vector2] = []
			for k: int in range(41):
				var t: float = TAU * k / 40.0
				var hx: float = 16.0 * pow(sin(t), 3.0)
				var hy: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				outline.append(c + Vector2(hx, -hy - 2.5) * (0.0155 * s))
			_stroke(ci, outline, colour, w)
		&"shop":
			# A shopping bag: a body that widens a little toward the bottom, and a handle over it.
			_stroke(ci, [c + Vector2(-0.2, -0.1) * s, c + Vector2(0.2, -0.1) * s, c + Vector2(0.24, 0.26) * s,
				c + Vector2(-0.24, 0.26) * s, c + Vector2(-0.2, -0.1) * s], colour, w)
			ci.draw_arc(c + Vector2(0, -0.1) * s, 0.11 * s, PI, TAU, 16, colour, w, true)
		&"share":
			# Three nodes joined: the sign every phone uses for sending something on.
			var hub: Vector2 = c + Vector2(-0.16, 0.0) * s
			var top: Vector2 = c + Vector2(0.16, -0.19) * s
			var low: Vector2 = c + Vector2(0.16, 0.19) * s
			_stroke(ci, [top, hub, low], colour, w)
			for node: Vector2 in [hub, top, low]:
				ci.draw_circle(node, 0.085 * s, colour, true, -1.0, true)
		&"watch":
			# Fast forward: two arrowheads running right.
			for k: int in range(2):
				var x: float = -0.25 + 0.24 * k
				_fill(ci, PackedVector2Array([c + Vector2(x, -0.2) * s, c + Vector2(x + 0.24, 0.0) * s,
					c + Vector2(x, 0.2) * s]), colour)
		&"key":
			var bow: Vector2 = c + Vector2(-0.15, 0.0) * s
			ci.draw_arc(bow, 0.12 * s, 0.0, TAU, 28, colour, w, true)
			_stroke(ci, [bow + Vector2(0.12, 0.0) * s, c + Vector2(0.3, 0.0) * s], colour, w)
			_stroke(ci, [c + Vector2(0.2, 0.0) * s, c + Vector2(0.2, 0.11) * s], colour, w)
			_stroke(ci, [c + Vector2(0.29, 0.0) * s, c + Vector2(0.29, 0.08) * s], colour, w)
		&"palette":
			# A painter's palette: a round board with a thumb notch and three dabs of paint.
			var rim: Array[Vector2] = []
			for k: int in range(29):
				var a4: float = deg_to_rad(35.0 + 300.0 * k / 28.0)
				rim.append(c + Vector2(cos(a4), sin(a4)) * 0.27 * s)
			rim.append(c + Vector2(0.1, 0.06) * s)
			rim.append(rim[0])
			_stroke(ci, rim, colour, w)
			for dab: Vector2 in [Vector2(-0.12, -0.1), Vector2(0.04, -0.15), Vector2(-0.14, 0.08)]:
				ci.draw_circle(c + dab * s, 0.045 * s, colour, true, -1.0, true)
		&"help":
			ci.draw_arc(c + Vector2(0, -0.1) * s, 0.13 * s, PI * 1.05, PI * 2.35, 20, colour, w, true)
			var hook: Vector2 = c + Vector2(cos(PI * 2.35), sin(PI * 2.35)) * 0.13 * s + Vector2(0, -0.1) * s
			_stroke(ci, [hook, c + Vector2(0.0, 0.06) * s, c + Vector2(0.0, 0.1) * s], colour, w)
			ci.draw_circle(c + Vector2(0, 0.24) * s, w * 0.75, colour, true, -1.0, true)
		&"info":
			ci.draw_arc(c, 0.28 * s, 0.0, TAU, 40, colour, w, true)
			ci.draw_circle(c + Vector2(0, -0.13) * s, w * 0.75, colour, true, -1.0, true)
			_stroke(ci, [c + Vector2(0, -0.02) * s, c + Vector2(0, 0.15) * s], colour, w)
		&"looks":
			# A marble: a ball with a highlight, for a game's set of looks.
			ci.draw_arc(c, 0.25 * s, 0.0, TAU, 40, colour, w, true)
			ci.draw_arc(c, 0.14 * s, deg_to_rad(195.0), deg_to_rad(265.0), 12, colour, w, true)
		&"save":
			# Down into a tray: keep a copy.
			_stroke(ci, [c + Vector2(0, -0.27) * s, c + Vector2(0, 0.07) * s], colour, w)
			_stroke(ci, [c + Vector2(-0.12, -0.05) * s, c + Vector2(0, 0.07) * s, c + Vector2(0.12, -0.05) * s], colour, w)
			_stroke(ci, [c + Vector2(-0.25, 0.08) * s, c + Vector2(-0.25, 0.25) * s, c + Vector2(0.25, 0.25) * s,
				c + Vector2(0.25, 0.08) * s], colour, w)
		&"reel":
			# A phone-shaped frame with a play mark: the solve as a short film.
			_round_rect(ci, Rect2(c - Vector2(0.17, 0.28) * s, Vector2(0.34, 0.56) * s), 0.07 * s, colour, w)
			_fill(ci, PackedVector2Array([c + Vector2(-0.06, -0.1) * s, c + Vector2(0.1, 0.0) * s,
				c + Vector2(-0.06, 0.1) * s]), colour)
		&"people":
			# Two people side by side, for the credits.
			for side3: float in [-1.0, 1.0]:
				var head: Vector2 = c + Vector2(side3 * 0.13, -0.12) * s
				ci.draw_arc(head, 0.08 * s, 0.0, TAU, 20, colour, w, true)
				ci.draw_arc(head + Vector2(0, 0.3) * s, 0.15 * s, PI * 1.08, PI * 1.92, 16, colour, w, true)

## A polyline with round caps and joins: a dot at every vertex covers the notches a thick line leaves.
static func _stroke(ci: CanvasItem, points: Array[Vector2], colour: Color, w: float) -> void:
	ci.draw_polyline(PackedVector2Array(points), colour, w, true)
	for p: Vector2 in points:
		ci.draw_circle(p, w * 0.5, colour, true, -1.0, true)

## A filled polygon with its edge traced antialiased, since filled polygons are not.
static func _fill(ci: CanvasItem, points: PackedVector2Array, colour: Color) -> void:
	ci.draw_colored_polygon(points, colour)
	var loop: PackedVector2Array = points.duplicate()
	loop.append(points[0])
	ci.draw_polyline(loop, colour, 1.5, true)

static func _speaker(ci: CanvasItem, c: Vector2, s: float, colour: Color) -> void:
	_fill(ci, PackedVector2Array([c + Vector2(-0.14, -0.08) * s, c + Vector2(-0.04, -0.08) * s,
		c + Vector2(0.08, -0.2) * s, c + Vector2(0.08, 0.2) * s, c + Vector2(-0.04, 0.08) * s,
		c + Vector2(-0.14, 0.08) * s]), colour)

static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, angle: float, colour: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in range(24):
		var a: float = TAU * k / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(angle))
	_fill(ci, pts, colour)

static func _round_rect(ci: CanvasItem, rect: Rect2, radius: float, colour: Color, w: float) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = colour
	box.set_border_width_all(int(maxf(1.0, w)))
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	ci.draw_style_box(box, rect)
