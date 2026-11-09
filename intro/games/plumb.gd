extends ChaosmosIntroStyle

# Plumb: the screen is Plumb's board and the word is laid out on it by one tilt. On warm paper stand a coral
# hole, the last s and a few of Plumb's marbles. The board tips right and every marble rolls at once, Plumb's
# rule: the coral one on the right rolls until the s stops it, in the second o's place, the coral one on the
# left rolls into the hole and drops in, and the hole fills with its coral water and becomes the ring. The
# letters rise behind the two as they pass, and the other marbles roll on off the board.

const LIGHT_PAPER: Color = Color("f4efe7")
const LIGHT_INK: Color = Color("2f333d")
const LIGHT_WELL: Color = Color("2c3140")
const DARK_PAPER: Color = Color("1b1d22")
const DARK_INK: Color = Color("f1ece3")
const DARK_WELL: Color = Color("111217")
# Plumb's teal, amber and violet marbles, by day and by night.
const LIGHT_MARBLES: Array[Color] = [Color("22b5a6"), Color("ffb020"), Color("7b6cf6")]
const DARK_MARBLES: Array[Color] = [Color("2cc4b4"), Color("ffbb33"), Color("8f82ff")]
const SHADOW: Color = Color(0.2, 0.16, 0.1, 0.18)

# The marbles that roll off the board: x and y of their middles in font units, and their colour.
const FIELD: Array[Vector3] = [
	Vector3(-300.0, 1760.0, 0.0), Vector3(1950.0, 1700.0, 2.0), Vector3(4050.0, 1780.0, 1.0),
	Vector3(800.0, -1180.0, 1.0), Vector3(3050.0, -1240.0, 0.0),
]
# Where the two coral marbles start, in font units along the word's line.
const A_FROM: float = -260.0
const B_FROM: float = 2650.0

const POP_FROM: float = 0.04
const POP_STAGGER: float = 0.04
const POP: float = 0.26
const TIP_AT: float = 0.42
const TIP_IN: float = 0.09
const TIP_BACK: float = 0.42
const TIP_DEGREES: float = 3.0
const ROLL_AT: float = 0.44
# A marble sets off at once, as Plumb's do, and gathers speed down the tipped board: font units a second, and
# font units a second each second.
const LAUNCH: float = 2500.0
const GRAVITY: float = 12000.0
const LETTER_RISE: float = 0.26
const SINK: float = 0.18
const RIPPLE: float = 0.45
const RING_DRAW: float = 0.36
const FILL: float = 0.3
const CALM: float = 0.85
const SQUASH: Vector2 = Vector2(0.84, 1.14)
const FLATTEN_AFTER: float = 0.22
const FLATTEN: float = 0.3
# Plumb draws a hole's rim at 0.41 of a cell, so the ring's outer edge sets the cell.
const CELL: float = 270.0 / 0.41

var _pivot: Vector2 = Vector2.ZERO
var _angle: float = 0.0
var _dark: bool = false


func title() -> String:
	return "Plumb"


func settle() -> float:
	return maxf(_sink_at() + CALM, _home_at() + FLATTEN_AFTER + FLATTEN) + 0.02


func sting() -> String:
	return "res://intro/sounds/plumb.wav"


func background() -> Color:
	return DARK_PAPER if _is_dark() else LIGHT_PAPER


func _is_dark() -> bool:
	return paper.get_luminance() < 0.5


func _ink() -> Color:
	return DARK_INK if _dark else LIGHT_INK


# How far a marble that has `distance` to go has rolled at time t, falling down the tipped board.
static func _rolled(t: float, distance: float) -> float:
	var tau: float = maxf(t - ROLL_AT, 0.0)
	return minf(LAUNCH * tau + 0.5 * GRAVITY * tau * tau, distance)


static func _speed(t: float, distance: float) -> float:
	var tau: float = maxf(t - ROLL_AT, 0.0)
	return 0.0 if _rolled(t, distance) >= distance else LAUNCH + GRAVITY * tau


static func _arrive(distance: float) -> float:
	return ROLL_AT + (sqrt(LAUNCH * LAUNCH + 2.0 * GRAVITY * maxf(distance, 0.0)) - LAUNCH) / GRAVITY


func _sink_at() -> float:
	return _arrive(ChaosmosWordmark.RING_X - A_FROM)


func _home_at() -> float:
	return _arrive(ChaosmosWordmark.DISC_X - B_FROM)


# The tray's tip: quickly over toward the tilt, then back past level and home, as Plumb's board does.
func _tip(t: float) -> float:
	var tip: float = deg_to_rad(TIP_DEGREES)
	if t < TIP_AT + TIP_IN:
		return tip * out_cubic(span(t, TIP_AT, TIP_AT + TIP_IN))
	return tip * (1.0 - out_back(span(t, TIP_AT + TIP_IN, TIP_AT + TIP_IN + TIP_BACK), 2.2))


# A point of the board in font units, on screen with the board tipped.
func _place(x: float, y: float) -> Vector2:
	return _pivot + (word.at(x, y) - _pivot).rotated(_angle)


func _letter_x(index: int) -> float:
	var letter: Dictionary = ChaosmosWordmark.LETTERS[index]
	return float(letter["x"]) + (float(letter["left"]) + float(letter["right"])) * 0.5


# When letter `index` starts to rise: once the marble that crosses it has rolled past its middle.
func _rise_at(index: int) -> float:
	var radius: float = ChaosmosWordmark.O_RADIUS
	match index:
		0, 1, 2:
			return _arrive(_letter_x(index) + radius - A_FROM)
		3, 4:
			return _arrive(_letter_x(index) + radius - B_FROM)
	return POP_FROM


func draw(canvas: CanvasItem, t: float, view: Vector2) -> void:
	_dark = _is_dark()
	_pivot = view * 0.5
	_angle = _tip(t)
	var ink_colour: Color = _ink()
	if t >= settle():
		_draw_word(canvas, ink_colour)
		return
	var radius: float = ChaosmosWordmark.O_RADIUS
	# The marbles that roll away, under everything on the word's line.
	var exit: float = (view.x - word.origin.x) / word.unit + radius * 3.0 + 600.0
	var marbles: Array[Color] = DARK_MARBLES if _dark else LIGHT_MARBLES
	# On a tall phone the rows stand further from the word, into the room above and below it.
	var spread: float = clampf(view.y / view.x * 0.75, 1.0, 1.4)
	for k: int in range(FIELD.size()):
		var spot: Vector3 = FIELD[k]
		spot.y = ChaosmosWordmark.O_Y + (spot.y - ChaosmosWordmark.O_Y) * spread
		var pop: float = span(t, POP_FROM + POP_STAGGER * float(k + 2), POP_FROM + POP_STAGGER * float(k + 2) + POP)
		var go: float = exit - spot.x
		var x: float = spot.x + _rolled(t, go)
		if pop <= 0.0 or x >= exit:
			continue
		_draw_marble(canvas, _place(x, spot.y), marbles[int(spot.z)], out_back(pop), _speed(t, go), Vector2.ONE, 0.0)
	_draw_ripple(canvas, t)
	# The letters, rising behind the marbles, and the last s, which stands from the start and stops the o.
	var home: float = _home_at()
	for index: int in range(ChaosmosWordmark.LETTERS.size()):
		var rise: float = span(t, _rise_at(index), _rise_at(index) + LETTER_RISE)
		if rise <= 0.0:
			continue
		var x: float = _letter_x(index)
		if index == 5:
			var knock: float = span(t, home, home + 0.2)
			x += 26.0 * sin(knock * PI) * (1.0 - knock)
		var size: float = lerpf(0.45, 1.0, out_back(rise, 1.9))
		word.draw_letter(canvas, index, _place(x, ChaosmosWordmark.X_HEIGHT * 0.5), Color(ink_colour, minf(rise * 7.0, 1.0)), _angle, Vector2(size, size))
	_draw_hole(canvas, t, ink_colour)
	# The coral marble that drops into the hole.
	var sink: float = _sink_at()
	var a_go: float = ChaosmosWordmark.RING_X - A_FROM
	var a_pop: float = out_back(span(t, POP_FROM, POP_FROM + POP))
	if t < sink + SINK and a_pop > 0.0:
		var down: float = span(t, sink, sink + SINK)
		var colour: Color = coral.lerp(coral.darkened(0.25), down)
		colour.a = 1.0 - span(t, sink + SINK * 0.5, sink + SINK)
		_draw_marble(canvas, _place(A_FROM + _rolled(t, a_go), ChaosmosWordmark.O_Y), colour, a_pop * lerpf(1.0, 0.15, down * down), _speed(t, a_go), Vector2.ONE, 0.0)
	# The coral marble that rolls home: a squash against the s, then it flattens into the brand's disc.
	var b_go: float = ChaosmosWordmark.DISC_X - B_FROM
	var b_pop: float = out_back(span(t, POP_FROM + POP_STAGGER, POP_FROM + POP_STAGGER + POP))
	if b_pop > 0.0:
		var squash: Vector2 = Vector2.ONE
		if t >= home:
			squash = Vector2.ONE.lerp(SQUASH, span(t, home, home + 0.05))
			squash = squash.lerp(Vector2.ONE, out_elastic(span(t, home + 0.05, home + 0.3)))
		var flat: float = in_out_cubic(span(t, home + FLATTEN_AFTER, home + FLATTEN_AFTER + FLATTEN))
		_draw_marble(canvas, _place(B_FROM + _rolled(t, b_go), ChaosmosWordmark.O_Y), coral, b_pop, _speed(t, b_go), squash, flat)


# The first o: a coral hole in Plumb's way (a rim in its colour round a dark well) until its marble drops in.
# Then the well fills with the marble's coral, the rest of it clears, and the ink ring draws itself round over
# the coral rim: the brand's ring.
func _draw_hole(canvas: CanvasItem, t: float, ink_colour: Color) -> void:
	var pop: float = span(t, 0.0, POP)
	if pop <= 0.0:
		return
	var size: float = lerpf(0.4, 1.0, out_back(pop, 1.9))
	var centre: Vector2 = _place(ChaosmosWordmark.RING_X, ChaosmosWordmark.O_Y)
	var sink: float = _sink_at()
	# The well clears while the sinking marble still covers it.
	var clear: float = span(t, sink, sink + SINK * 0.6)
	var rim: float = out_cubic(span(t, sink + 0.04, sink + RING_DRAW))
	var inner: float = (ChaosmosWordmark.O_RADIUS - ChaosmosWordmark.RING_STROKE) * word.unit * size + 1.5
	var well: Color = DARK_WELL if _dark else LIGHT_WELL
	if clear < 1.0:
		canvas.draw_circle(centre, inner, Color(well, 1.0 - clear), true, -1.0, true)
		canvas.draw_circle(centre + Vector2(0, 0.045 * CELL * word.unit * size), inner * 0.76, Color(well.darkened(0.45), 1.0 - clear), true, -1.0, true)
	var calm: float = span(t, sink + 0.1, sink + CALM)
	var wobble: float = 1.0 + 2.4 * pow(1.0 - calm, 2.0) * cos((t - sink) * 15.0)
	var phase: float = 0.18 * pow(1.0 - calm, 2.0) * sin((t - sink) * 9.0)
	word.draw_water(canvas, centre, coral, size, out_cubic(span(t, sink + 0.04, sink + 0.04 + FILL)), phase, wobble)
	if rim < 1.0:
		word.draw_ring(canvas, centre, coral, size)
	word.draw_ring(canvas, centre, ink_colour, size, rim)


# Plumb's sink ripple, in the marble's colour, spreading from the hole under the letters.
func _draw_ripple(canvas: CanvasItem, t: float) -> void:
	var ring: float = span(t, _sink_at(), _sink_at() + RIPPLE)
	if ring <= 0.0 or ring >= 1.0:
		return
	var centre: Vector2 = _place(ChaosmosWordmark.RING_X, ChaosmosWordmark.O_Y)
	var reach: float = lerpf(0.3, 0.78, ease(ring, 0.4)) * CELL * word.unit
	canvas.draw_arc(centre, reach, 0.0, TAU, 64, Color(coral, 0.8 * (1.0 - ring)), lerpf(0.08, 0.015, ring) * CELL * word.unit, true)


# One of Plumb's marbles: its shadow, a darker rim, its face and its gloss, and a tail while it rolls fast.
# `flat` takes away the shading, so a coral marble at rest becomes the brand's flat disc.
func _draw_marble(canvas: CanvasItem, centre: Vector2, colour: Color, size: float, speed: float, squash: Vector2, flat: float) -> void:
	var r: float = ChaosmosWordmark.O_RADIUS * word.unit * size
	if r <= 0.5:
		return
	var shade: float = 1.0 - flat
	var along: Vector2 = Vector2.RIGHT.rotated(_angle)
	var tail_length: float = minf(speed * word.unit * 0.045, r * 1.6)
	if tail_length > r * 0.1:
		var side: Vector2 = along.orthogonal() * r * 0.8
		var tail: PackedVector2Array = PackedVector2Array([centre + side, centre - along * (r * 0.2 + tail_length), centre - side])
		canvas.draw_colored_polygon(tail, Color(colour, 0.28 * colour.a))
	canvas.draw_set_transform(centre, 0.0, squash)
	if shade > 0.0:
		canvas.draw_circle(Vector2(r * 0.08, r * 0.22), r * 0.98, Color(SHADOW, SHADOW.a * shade * colour.a), true, -1.0, true)
	canvas.draw_circle(Vector2.ZERO, r, colour.lerp(colour.darkened(0.22), shade), true, -1.0, true)
	canvas.draw_circle(Vector2(-r * 0.06, -r * 0.08), r * 0.88, colour, true, -1.0, true)
	if shade > 0.0:
		canvas.draw_circle(Vector2(-r * 0.3, -r * 0.34), r * 0.3, Color(1, 1, 1, 0.5 * shade * colour.a), true, -1.0, true)
		canvas.draw_circle(Vector2(-r * 0.36, -r * 0.4), r * 0.13, Color(1, 1, 1, 0.85 * shade * colour.a), true, -1.0, true)
	canvas.draw_set_transform(Vector2.ZERO)


# The word as the brand draws it, in Plumb's ink.
func _draw_word(canvas: CanvasItem, ink_colour: Color) -> void:
	for index: int in range(ChaosmosWordmark.LETTERS.size()):
		word.draw_letter(canvas, index, word.letter_centre(index), ink_colour)
	word.draw_water(canvas, word.ring_centre(), coral)
	word.draw_ring(canvas, word.ring_centre(), ink_colour)
	word.draw_disc(canvas, word.disc_centre(), coral)
