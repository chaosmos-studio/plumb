class_name StreetPieces
extends RefCounted

## The M1 stand-ins for the painted street (REVAMP_PLAN.md section 10), drawn in code once into an atlas
## (StreetAtlas), so the map draws them the way it will draw the painted cut-outs: as rectangles of one texture, which
## the renderer batches. Each piece is drawn with its base point at the origin, at the size it has at the near edge.

const ROOFS: Array[Color] = [Color("f0584c"), Color("22b5a6"), Color("ff9a3c"), Color("8c6cf0"), Color("ffc23a")]
const WALL: Color = Color("fff3df")
const WALL_SHADE: Color = Color("f1dcbd")
const WOOD: Color = Color("6e412b")
const INK: Color = Color("fff6e8")
const WINDOW: Color = Color("8fc3e6")
const WINDOW_LIT: Color = Color("ffd86a")
const OUTLINE: Color = Color(0.36, 0.22, 0.14, 0.55)
const SHADOW: Color = Color(0.2, 0.3, 0.1, 0.22)
const LEAF: Array[Color] = [Color("5fb83a"), Color("4aa52f"), Color("7ccd4a")]
const BLOOM: Array[Color] = [Color("ff6f91"), Color("ffd23f"), Color("ffffff"), Color("b388ff")]
const GOLD: Color = Color("ffc23a")

## A house's measures, which the map's door overlays use: its width and wall height, the door's centre and radius,
## and its two windows' centres.
const HOUSE_W: float = 196.0
const HOUSE_H: float = 150.0
const DOOR_CENTRE: Vector2 = Vector2(0, -58)
const DOOR_R: float = 52.0
const WINDOWS: Array[Vector2] = [Vector2(-58.8, -108), Vector2(58.8, -108)]

## Every piece: its size in the atlas at the near edge and its base point inside that box.
const PIECES: Dictionary = {
	"house_0": [Vector2(280, 300), Vector2(140, 292)],
	"house_1": [Vector2(280, 300), Vector2(140, 292)],
	"house_2": [Vector2(280, 300), Vector2(140, 292)],
	"house_3": [Vector2(280, 300), Vector2(140, 292)],
	"house_4": [Vector2(280, 300), Vector2(140, 292)],
	"tree_0": [Vector2(220, 300), Vector2(110, 292)],
	"tree_1": [Vector2(220, 330), Vector2(110, 322)],
	"bush_0": [Vector2(160, 110), Vector2(80, 102)],
	"bush_1": [Vector2(160, 110), Vector2(80, 102)],
	"lamp": [Vector2(84, 250), Vector2(42, 244)],
	"fence": [Vector2(170, 86), Vector2(85, 80)],
	"flowers_0": [Vector2(120, 60), Vector2(60, 52)],
	"flowers_1": [Vector2(120, 60), Vector2(60, 52)],
	"glow": [Vector2(192, 192), Vector2(96, 96)],
	"window_lit": [Vector2(40, 40), Vector2(20, 20)],
	"star_on": [Vector2(24, 24), Vector2(12, 12)],
	"star_off": [Vector2(24, 24), Vector2(12, 12)],
	"padlock": [Vector2(56, 56), Vector2(28, 30)],
}

static func draw(ci: CanvasItem, piece: String) -> void:
	var variant: int = int(piece.get_slice("_", 1)) if piece.contains("_") and piece.get_slice("_", 1).is_valid_int() else 0
	match piece.get_slice("_", 0):
		"house":
			_house(ci, ROOFS[variant])
		"tree":
			_tree(ci, 1.0 + 0.3 * float(variant))
		"bush":
			_bush(ci, variant == 1)
		"lamp":
			_lamp(ci)
		"fence":
			_fence(ci)
		"flowers":
			_flowers(ci, variant)
		"glow":
			for i: int in range(6):
				ci.draw_circle(Vector2.ZERO, 92.0 - i * 9.0, Color(1.0, 0.86, 0.35, 0.09))
		"window":
			ci.draw_circle(Vector2.ZERO, 17.0, WINDOW_LIT)
			ci.draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 24, OUTLINE, 3.0, true)
		"star":
			_star(ci, Vector2.ZERO, 11.0, GOLD if piece == "star_on" else Color(1, 1, 1, 0.3))
		"padlock":
			ci.draw_arc(Vector2(0, -12), 13.0, PI, TAU, 16, INK, 6.0, true)
			ci.draw_rect(Rect2(-18, -12, 36, 28), INK)

static func _house(ci: CanvasItem, roof: Color) -> void:
	var w: float = HOUSE_W
	var h: float = HOUSE_H
	_ellipse(ci, Vector2(0, 2), Vector2(w * 0.62, 14), SHADOW)
	var body: Rect2 = Rect2(-w * 0.5, -h, w, h)
	ci.draw_rect(body, WALL)
	ci.draw_rect(Rect2(body.position.x, body.end.y - 18, w, 18), WALL_SHADE)
	ci.draw_rect(body, OUTLINE, false, 3.0)
	var eave: float = 24.0
	var points: PackedVector2Array = PackedVector2Array([Vector2(-w * 0.5 - eave, -h + 6), Vector2(0, -h - 104),
		Vector2(w * 0.5 + eave, -h + 6)])
	ci.draw_rect(Rect2(w * 0.22, -h - 92, 26, 46), roof.darkened(0.15))
	ci.draw_colored_polygon(points, roof)
	ci.draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), OUTLINE, 3.0, true)
	for at: Vector2 in WINDOWS:
		ci.draw_circle(at, 17.0, WINDOW)
		ci.draw_arc(at, 17.0, 0.0, TAU, 24, OUTLINE, 3.0, true)
	var c: Vector2 = DOOR_CENTRE
	var r: float = DOOR_R
	ci.draw_circle(c, r + 9.0, roof)
	ci.draw_rect(Rect2(c.x - r - 9, c.y, (r + 9) * 2, -c.y), roof)
	ci.draw_circle(c, r, WOOD)
	ci.draw_rect(Rect2(c.x - r, c.y, r * 2, -c.y), WOOD)
	ci.draw_rect(Rect2(-r - 16, -6, (r + 16) * 2, 8), WALL_SHADE.darkened(0.15))

static func _tree(ci: CanvasItem, tall: float) -> void:
	_ellipse(ci, Vector2(0, 2), Vector2(70, 12), SHADOW)
	ci.draw_rect(Rect2(-11, -90 * tall, 22, 90 * tall), Color("8a5a3b"))
	var top: float = -90.0 * tall
	ci.draw_circle(Vector2(-36, top - 10), 50.0, LEAF[1])
	ci.draw_circle(Vector2(36, top - 6), 48.0, LEAF[1])
	ci.draw_circle(Vector2(0, top - 52), 62.0, LEAF[0])
	ci.draw_circle(Vector2(-18, top - 70), 26.0, LEAF[2])

static func _bush(ci: CanvasItem, blooming: bool) -> void:
	_ellipse(ci, Vector2(0, 2), Vector2(56, 10), SHADOW)
	ci.draw_circle(Vector2(-30, -26), 30.0, LEAF[1])
	ci.draw_circle(Vector2(30, -24), 28.0, LEAF[1])
	ci.draw_circle(Vector2(0, -40), 36.0, LEAF[0])
	if blooming:
		for i: int in range(4):
			ci.draw_circle(Vector2(-30 + i * 20, -40 + (i % 2) * 18), 6.0, BLOOM[i % BLOOM.size()])

static func _lamp(ci: CanvasItem) -> void:
	_ellipse(ci, Vector2(0, 2), Vector2(22, 6), SHADOW)
	ci.draw_rect(Rect2(-6, -170, 12, 170), Color("3b3f4a"))
	ci.draw_rect(Rect2(-14, -12, 28, 12), Color("3b3f4a"))
	ci.draw_circle(Vector2(0, -186), 32.0, Color(1.0, 0.86, 0.4, 0.3))
	ci.draw_rect(Rect2(-16, -204, 32, 36), Color("ffe08a"))
	ci.draw_rect(Rect2(-20, -212, 40, 10), Color("3b3f4a"))

static func _fence(ci: CanvasItem) -> void:
	for i: int in range(4):
		var x: float = -66.0 + i * 44.0
		ci.draw_rect(Rect2(x - 7, -58, 14, 58), Color.WHITE)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 7, -58), Vector2(x, -68), Vector2(x + 7, -58)]),
			Color.WHITE)
	ci.draw_rect(Rect2(-74, -44, 148, 9), Color("f2ede4"))
	ci.draw_rect(Rect2(-74, -20, 148, 9), Color("f2ede4"))

static func _flowers(ci: CanvasItem, variant: int) -> void:
	_ellipse(ci, Vector2(0, -6), Vector2(46, 14), LEAF[1])
	for i: int in range(6):
		var at: Vector2 = Vector2(-36 + i * 14, -12 - float((variant + i * 7) % 3) * 6.0)
		ci.draw_circle(at, 7.0, BLOOM[(variant + i) % BLOOM.size()])
		ci.draw_circle(at, 2.5, Color("ffd23f"))

static func _star(ci: CanvasItem, at: Vector2, r: float, colour: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(10):
		var a: float = -PI * 0.5 + TAU * float(i) / 10.0
		points.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(points, colour)

static func _ellipse(ci: CanvasItem, centre: Vector2, radii: Vector2, colour: Color) -> void:
	ci.draw_set_transform(centre, 0.0, Vector2(1.0, radii.y / radii.x))
	ci.draw_circle(Vector2.ZERO, radii.x, colour)
	ci.draw_set_transform(Vector2.ZERO)
