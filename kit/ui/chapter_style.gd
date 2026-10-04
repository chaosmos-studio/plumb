class_name ChapterStyle
extends RefCounted

## Each chapter's own colour and pattern, so turning a page of the level grid feels like arriving somewhere
## new, and the card that opens a chapter in play wears the same. The hues are spread evenly round the
## circle, one per chapter, starting at the game's accent, and visited by a stride of about a third of a
## turn that shares no factor with the number of chapters: every chapter gets a hue of its own and the
## next one is always far off. Lightness and chroma are held in a band that reads on the theme's
## background and on its cards. The pattern is one of a dozen motifs, turned and spaced for the chapter,
## drawn faint behind the grid. A game without chapters gets the same per page of the grid.

## The share of a turn the stride between chapters comes closest to.
const STRIDE: float = 0.3
const PER_PAGE: int = 20
const STROKE: float = 3.0

enum Motif { DOTS, RINGS, WAVES, STRIPES, CROSSES, TRIANGLES, HEXES, ZIGZAG, SPARKS, SCALES, DIAMONDS, PETALS }

## The chapter's colour in the theme in use.
static func tint(chapter: int) -> Color:
	var accent: Color = Brand.ACCENT
	var n: int = count()
	var hue: float = fposmod(accent.ok_hsl_h + float(posmod(chapter * stride(n), n)) / n, 1.0)
	var chroma: float = clampf(accent.ok_hsl_s, 0.62, 0.9)
	var light: float = clampf(accent.ok_hsl_l, 0.7, 0.78) if Appearance.dark else clampf(accent.ok_hsl_l, 0.46, 0.52)
	return Color.from_ok_hsl(hue, chroma, light)

## The chapters, or for a game without them the pages of the level grid.
static func count() -> int:
	return Pack.chapters.size() if not Pack.chapters.is_empty() else maxi(1, ceili(Pack.count() / float(PER_PAGE)))

## The step round `n` evenly spread hues: the one nearest STRIDE of a turn that shares no factor with `n`,
## so stepping by it visits every hue once before coming back.
static func stride(n: int) -> int:
	var best: int = 1
	for k: int in range(1, n):
		if _coprime(k, n) and absf(float(k) / n - STRIDE) < absf(float(best) / n - STRIDE):
			best = k
	return best

static func _coprime(a: int, b: int) -> bool:
	while b != 0:
		var r: int = a % b
		a = b
		b = r
	return a == 1

static func motif(chapter: int) -> Motif:
	return (chapter % Motif.size()) as Motif

## Covers `rect` of `ci` with the chapter's motif in `colour`, turned and spaced for the chapter.
static func pattern(ci: CanvasItem, chapter: int, rect: Rect2, colour: Color) -> void:
	var kind: Motif = motif(chapter)
	var step: float = 78.0 + float((chapter * 7) % 4) * 10.0
	var angle: float = deg_to_rad(float((chapter * 23) % 60) - 30.0)
	var reach: float = rect.size.length() * 0.5 + step
	var count: int = int(ceil(reach / step))
	ci.draw_set_transform(rect.get_center(), angle, Vector2.ONE)
	for row: int in range(-count, count + 1):
		var y: float = row * step
		match kind:
			Motif.WAVES, Motif.ZIGZAG, Motif.STRIPES:
				_line(ci, kind, Vector2(-reach, y), reach * 2.0, step, colour)
			_:
				var shift: float = step * 0.5 if row % 2 != 0 else 0.0
				for col: int in range(-count, count + 1):
					_glyph(ci, kind, Vector2(col * step + shift, y), step * 0.2, colour)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The chapter's motif once, about `size` across, as its emblem.
static func emblem(ci: CanvasItem, chapter: int, centre: Vector2, size: float, colour: Color) -> void:
	var kind: Motif = motif(chapter)
	match kind:
		Motif.WAVES, Motif.ZIGZAG, Motif.STRIPES:
			for k: int in range(-1, 2):
				_line(ci, kind, centre + Vector2(-size * 0.5, k * size * 0.3), size, size * 0.6, colour)
		_:
			_glyph(ci, kind, centre, size * 0.4, colour)

## One mark of the pattern around `p`, `u` its unit of size.
static func _glyph(ci: CanvasItem, kind: Motif, p: Vector2, u: float, colour: Color) -> void:
	match kind:
		Motif.DOTS:
			ci.draw_circle(p, u * 0.4, colour, true, -1.0, true)
		Motif.RINGS:
			ci.draw_arc(p, u * 0.65, 0.0, TAU, 24, colour, STROKE, true)
		Motif.CROSSES:
			ci.draw_line(p + Vector2(-u * 0.6, 0.0), p + Vector2(u * 0.6, 0.0), colour, STROKE, true)
			ci.draw_line(p + Vector2(0.0, -u * 0.6), p + Vector2(0.0, u * 0.6), colour, STROKE, true)
		Motif.TRIANGLES:
			ci.draw_polyline(_ring(p, u * 0.75, 3, -PI * 0.5), colour, STROKE, true)
		Motif.HEXES:
			ci.draw_polyline(_ring(p, u * 0.8, 6, 0.0), colour, STROKE, true)
		Motif.SPARKS:
			var star: PackedVector2Array = PackedVector2Array()
			for k: int in range(8):
				var a: float = k * PI / 4.0
				star.append(p + Vector2(cos(a), sin(a)) * (u * 0.8 if k % 2 == 0 else u * 0.22))
			ci.draw_colored_polygon(star, colour)
		Motif.SCALES:
			ci.draw_arc(p, u * 2.5, 0.0, PI, 24, colour, STROKE, true)
		Motif.DIAMONDS:
			ci.draw_polyline(_ring(p, u * 0.75, 4, 0.0), colour, STROKE, true)
		Motif.PETALS:
			for k: int in range(5):
				var a2: float = -PI * 0.5 + k * TAU / 5.0
				ci.draw_circle(p + Vector2(cos(a2), sin(a2)) * u * 0.55, u * 0.2, colour, true, -1.0, true)

## A pattern that runs as lines: a wave, a zigzag or a pair of stripes from `from`, `length` long.
static func _line(ci: CanvasItem, kind: Motif, from: Vector2, length: float, step: float, colour: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	match kind:
		Motif.WAVES:
			var n: int = int(length / 10.0)
			for k: int in range(n + 1):
				var x: float = k * 10.0
				points.append(from + Vector2(x, sin(x / step * TAU) * step * 0.12))
		Motif.ZIGZAG:
			var n2: int = int(length / (step * 0.5))
			for k: int in range(n2 + 1):
				points.append(from + Vector2(k * step * 0.5, step * 0.12 * (1.0 if k % 2 == 0 else -1.0)))
		Motif.STRIPES:
			ci.draw_line(from + Vector2(0.0, step * 0.25), from + Vector2(length, step * 0.25), colour, STROKE, true)
			points.append(from)
			points.append(from + Vector2(length, 0.0))
	ci.draw_polyline(points, colour, STROKE, true)

## A closed regular polygon of `sides` around `p`.
static func _ring(p: Vector2, r: float, sides: int, turn: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in range(sides + 1):
		var a: float = turn + k * TAU / sides
		out.append(p + Vector2(cos(a), sin(a)) * r)
	return out

## The chapter's ground for a whole screen: a wash of its colour from the top, and its pattern, faint.
class Ground extends Control:
	const WASH: float = 0.14
	const PATTERN: float = 0.07

	var chapter: int = 0:
		set(value):
			if value == chapter and _drawn:
				return
			chapter = value
			_drawn = true
			queue_redraw()
			if is_inside_tree():
				modulate.a = 0.3
				create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	var _drawn: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var colour: Color = ChapterStyle.tint(chapter)
		var deep: float = size.y * 0.5
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, deep), Vector2(0.0, deep)]),
			PackedColorArray([Color(colour, WASH), Color(colour, WASH), Color(colour, 0.0), Color(colour, 0.0)]))
		ChapterStyle.pattern(self, chapter, Rect2(Vector2.ZERO, size), Color(colour, PATTERN))
