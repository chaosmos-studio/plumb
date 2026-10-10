class_name QrCard
extends Control

## Once it has settled nothing moves inside the code, so a phone held up to the screen reads it.
##
## `rows` comes from Qr.rows, without its quiet zone and at error correction level H: the icon covers well
## under the 30 percent that level can lose. The finder eyes are rounded by under a module: at a full
## module OpenCV's detector stops finding them, and phone readers are built on the same finder search.

const QUIET: float = 4.0
const REVEAL: float = 0.9
const POP: float = 0.22
## The icon's side as a fraction of the code's side.
const LOGO: float = 0.22

var rows: PackedStringArray = PackedStringArray()
var ink: Color = Color("1d2030")
var icon: Texture2D
var _n: int = 0
var _t: float = -1.0
var _sheen: float = -1.0
var _brackets: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_n = rows.size()

## The finished code at once, for a caller that fades it in: it holds still from then on, and only the
## corner brackets, outside the code, keep breathing.
func show_whole() -> void:
	_t = REVEAL + POP
	var b: Tween = create_tween().set_loops()
	b.tween_property(self, "_brackets", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	b.tween_property(self, "_brackets", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

func play() -> void:
	_t = 0.0
	var t: Tween = create_tween()
	t.tween_property(self, "_t", REVEAL + POP, REVEAL + POP)
	t.tween_property(self, "_sheen", 1.0, 0.7).from(0.0).set_trans(Tween.TRANS_SINE)
	var b: Tween = create_tween().set_loops()
	b.tween_property(self, "_brackets", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	b.tween_property(self, "_brackets", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _n == 0 or _t < 0.0:
		return
	var side: float = minf(size.x, size.y)
	var m: float = side / (_n + QUIET * 2.0)
	var origin: Vector2 = Vector2(m * QUIET, m * QUIET)
	var card: StyleBoxFlat = StyleBoxFlat.new()
	card.bg_color = Color.WHITE
	card.set_corner_radius_all(int(side * 0.08))
	card.corner_detail = 12
	card.shadow_color = Color(0, 0, 0, 0.22)
	card.shadow_size = int(side * 0.05)
	card.shadow_offset = Vector2(0, side * 0.02)
	card.anti_aliasing = true
	var appear: float = clampf(_t / 0.25, 0.0, 1.0)
	var grow: float = 0.9 + 0.1 * _ease(appear)
	var card_rect: Rect2 = Rect2(Vector2(side, side) * (1.0 - grow) * 0.5, Vector2(side, side) * grow)
	draw_style_box(card, card_rect)
	var centre: Vector2 = Vector2(_n, _n) * 0.5
	var logo_half: float = _n * LOGO * 0.5 + 0.8
	var reach: float = centre.length()
	for y: int in range(_n):
		var row: String = rows[y]
		for x: int in range(_n):
			if row[x] != "1" or _in_finder(x, y):
				continue
			var cell: Vector2 = Vector2(x + 0.5, y + 0.5)
			if absf(cell.x - centre.x) < logo_half and absf(cell.y - centre.y) < logo_half:
				continue
			var delay: float = REVEAL * (cell - centre).length() / reach
			var k: float = _ease(clampf((_t - delay) / POP, 0.0, 1.0))
			if k <= 0.0:
				continue
			var s: float = m * 0.92 * k
			var at: Vector2 = origin + cell * m - Vector2(s, s) * 0.5
			_round_rect(Rect2(at, Vector2(s, s)), s * 0.32, ink)
	var eye: float = _ease(clampf(_t / 0.35, 0.0, 1.0))
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(_n - 7, 0), Vector2i(0, _n - 7)]:
		_finder(origin + Vector2(corner) * m, m, eye)
	if icon != null:
		var logo: float = _n * LOGO * m
		var lk: float = _ease(clampf((_t - REVEAL * 0.3) / 0.3, 0.0, 1.0))
		var ls: float = logo * lk
		var lat: Vector2 = origin + centre * m - Vector2(ls, ls) * 0.5
		_round_rect(Rect2(lat - Vector2(m, m) * 0.5, Vector2(ls, ls) + Vector2(m, m)), ls * 0.26, Color.WHITE)
		draw_texture_rect(icon, Rect2(lat, Vector2(ls, ls)), false)
	if _sheen > 0.0 and _sheen < 1.0:
		var x: float = lerpf(-side * 0.4, side * 1.4, _sheen)
		var band: PackedVector2Array = PackedVector2Array([
			Vector2(x, 0.0), Vector2(x + side * 0.16, 0.0), Vector2(x - side * 0.14, side), Vector2(x - side * 0.3, side)])
		var inset: float = side * 0.03
		var box: PackedVector2Array = PackedVector2Array([Vector2(inset, inset), Vector2(side - inset, inset),
			Vector2(side - inset, side - inset), Vector2(inset, side - inset)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(band, box):
			draw_colored_polygon(piece, Color(1, 1, 1, 0.35))
	if _t >= REVEAL:
		_draw_brackets(side)

func _in_finder(x: int, y: int) -> bool:
	return (x < 7 and y < 7) or (x >= _n - 7 and y < 7) or (x < 7 and y >= _n - 7)

func _finder(at: Vector2, m: float, k: float) -> void:
	if k <= 0.0:
		return
	var outer: Rect2 = Rect2(at, Vector2(7, 7) * m)
	var centre: Vector2 = outer.get_center()
	var scaled: Rect2 = Rect2(centre - outer.size * 0.5 * k, outer.size * k)
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_color = ink
	ring.set_border_width_all(int(round(m * k)))
	ring.set_corner_radius_all(int(m * 0.8 * k))
	ring.corner_detail = 10
	ring.anti_aliasing = true
	draw_style_box(ring, scaled)
	var inner: float = 3.0 * m * k
	_round_rect(Rect2(centre - Vector2(inner, inner) * 0.5, Vector2(inner, inner)), m * 0.4 * k, ink)

func _draw_brackets(side: float) -> void:
	var pad: float = side * (0.035 + 0.012 * _brackets)
	var len: float = side * 0.12
	var c: Color = Color(Brand.ACCENT, 0.95)
	var w: float = maxf(4.0, side * 0.012)
	var box: Rect2 = Rect2(Vector2(-pad, -pad), Vector2(side, side) + Vector2(pad, pad) * 2.0)
	for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		var sx: float = 1.0 if corner.x < box.get_center().x else -1.0
		var sy: float = 1.0 if corner.y < box.get_center().y else -1.0
		draw_polyline(PackedVector2Array([corner + Vector2(0, sy * len), corner, corner + Vector2(sx * len, 0)]), c, w, true)

func _round_rect(r: Rect2, radius: float, colour: Color) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(int(maxf(1.0, radius)))
	box.corner_detail = 6
	box.anti_aliasing = true
	draw_style_box(box, r)

static func _ease(k: float) -> float:
	var c: float = 1.7
	var p: float = k - 1.0
	return 1.0 + (c + 1.0) * p * p * p + c * p * p
