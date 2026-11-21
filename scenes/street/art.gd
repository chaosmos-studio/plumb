class_name StreetArt
extends RefCounted

## The street's painted art, packed by tools/pack_street.py (REVAMP_PLAN.md section 10), and the type Street's numbers
## are set in. The map's pieces share one atlas, so they batch, and the screens' pieces have a page of their own. Pieces
## are drawn at their size at the street's near edge, in design pixels: an atlas pixel is one screen pixel on a
## 1084-pixel-wide phone, which shows 720 design pixels across.

## The pages, each a texture and its index: the map's atlas, the screens', the town's (what the rewards bring) and the
## rooms' (the shop and Settings). Every index is read at once, and each texture loads the first time one of its
## pieces is drawn, so the rooms' page costs nothing until a room opens.
const PAGES: PackedStringArray = ["res://assets/street/atlas", "res://assets/street/ui", "res://assets/street/town",
	"res://assets/street/rooms"]
const PLAY_BACKDROP: String = "res://assets/street/play_backdrop.png"
const WIN_BACKDROP: String = "res://assets/street/win_backdrop.png"
const GIFT_BACKDROP: String = "res://assets/street/gift_backdrop.png"
const SHOP_BACKDROP: String = "res://assets/street/shop_backdrop.png"
const SETTINGS_BACKDROP: String = "res://assets/street/settings_backdrop.png"

## A whole-screen backdrop for a screen of this shape: its wide painting (`<name>_wide.png`) on a wide screen, where
## there is one.
static func backdrop(path: String, wide: bool) -> Texture2D:
	return fetched(backdrop_path(path, wide)) as Texture2D

static func backdrop_path(path: String, wide: bool) -> String:
	var wide_path: String = path.trim_suffix(".png") + "_wide.png"
	return wide_path if wide and ResourceLoader.exists(wide_path) else path

## Resources asked for ahead on a loading thread, by path, while the street is idle (`prefetch`), so the screen that
## needs them next finds them loaded instead of reading them from disk in the frame it opens.
static var _fetching: Dictionary = {}

## Starts loading `path` on a thread, unless it is loaded or on its way.
static func prefetch(path: String) -> void:
	if _fetching.has(path) or ResourceLoader.has_cached(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_fetching[path] = true

## Starts loading a page ahead, unless it is in memory.
static func prefetch_page(page: int) -> void:
	texture()
	if _textures[page] == null:
		prefetch(PAGES[page] + ".png")

## Starts loading a backdrop ahead for a screen of this shape.
static func prefetch_backdrop(path: String, wide: bool) -> void:
	prefetch(backdrop_path(path, wide))

## `path`, taken from its thread if it was asked for ahead (waiting for it if it is still loading), else loaded now.
static func fetched(path: String) -> Resource:
	if _fetching.has(path):
		_fetching.erase(path)
		var got: Resource = ResourceLoader.load_threaded_get(path)
		if got != null:
			return got
	return load(path)
const DESIGN_PER_PIXEL: float = 720.0 / 1084.0
const FONT: String = "res://assets/fonts/Baloo2.ttf"
## Baloo 2's heaviest weight, the concepts' chunky numbers.
const WEIGHT: int = 800
const COLOURS: PackedStringArray = ["red", "teal", "yellow", "purple"]
## House shapes painted so far (house_<colour>_<shape>.png): a cottage, a tall house, a shop-house and an attic house.
const SHAPES: int = 4

static var _textures: Array[Texture2D] = []
## Each piece's record from its page's index, with the page's number added as "page".
static var _pieces: Dictionary = {}
static var _nines: Dictionary = {}
static var _font: Font

## The map's atlas, reading every page's index on first use.
static func texture() -> Texture2D:
	if _textures.is_empty():
		for page: int in range(PAGES.size()):
			_textures.append(null)
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PAGES[page] + ".json"))
			if data is Dictionary:
				var pieces: Dictionary = (data as Dictionary)["pieces"]
				for name: String in pieces:
					var record: Dictionary = pieces[name]
					record["page"] = page
					_pieces[name] = record
	return _page(0)

static func _page(page: int) -> Texture2D:
	if _textures[page] == null:
		_textures[page] = fetched(PAGES[page] + ".png") as Texture2D
	return _textures[page]

## The town's and the rooms' pages, by number, which a screen lets go of when it closes.
const TOWN: int = 2
const ROOMS: int = 3

## Lets go of page `page` (its nine-patches too), so its memory goes once nothing draws from it: the rooms' page
## when the shop or Settings closes, the town's when the street is left. The next piece drawn from it loads it again.
static func release(page: int) -> void:
	if _textures.size() <= page or _textures[page] == null:
		return
	var texture: Texture2D = _textures[page]
	_textures[page] = null
	for piece: Variant in _nines.keys():
		if (_nines[piece] as StyleBoxTexture).texture == texture:
			_nines.erase(piece)

static func has(piece: String) -> bool:
	texture()
	return _pieces.has(piece)

## The page a piece is on.
static func texture_of(piece: String) -> Texture2D:
	texture()
	return _page(int((_pieces[piece] as Dictionary)["page"]))

## The piece's box on its page.
static func rect(piece: String) -> Rect2:
	texture()
	var r: Array = (_pieces[piece] as Dictionary)["rect"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))

## Its base point inside its box, in atlas pixels.
static func anchor(piece: String) -> Vector2:
	texture()
	var a: Array = (_pieces[piece] as Dictionary)["anchor"]
	return Vector2(float(a[0]), float(a[1]))

## A screen piece's layout record from Codex (a box such as "face", or points such as "hooks"), in its own pixels.
static func meta(piece: String, key: String) -> Array:
	texture()
	var out: Array = (_pieces[piece] as Dictionary).get(key, [])
	return out

## A box record ([x, y, w, h], in the piece's pixels) as a Rect2.
static func meta_rect(piece: String, key: String) -> Rect2:
	var r: Array = meta(piece, key)
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))

## The piece's size at the near edge, in design pixels.
static func size(piece: String) -> Vector2:
	return rect(piece).size * _k(piece)

## Design pixels per packed pixel at near-edge size: a piece packed smaller than painted is drawn back at full size.
static func _k(piece: String) -> float:
	texture()
	return DESIGN_PER_PIXEL / float((_pieces[piece] as Dictionary).get("scale", 1.0))

## Draws `piece` on `ci` with its base point at `at`, `scale` times its near-edge size.
static func draw(ci: CanvasItem, piece: String, at: Vector2, scale: float = 1.0, tint: Color = Color.WHITE) -> void:
	var box: Rect2 = rect(piece)
	var k: float = _k(piece) * scale
	ci.draw_texture_rect_region(texture_of(piece), Rect2(at - anchor(piece) * k, box.size * k), box, tint)

## Draws `piece` with its top-left corner at `at`, `scale` times its near-edge size: for screen pieces, whose layout
## records are measured from their corner.
static func draw_at(ci: CanvasItem, piece: String, at: Vector2, scale: float = 1.0, tint: Color = Color.WHITE) -> void:
	var box: Rect2 = rect(piece)
	ci.draw_texture_rect_region(texture_of(piece), Rect2(at, box.size * _k(piece) * scale), box, tint)

## Stretches a screen piece over `area` by its nine-slice record: the corners keep their shape at `scale` times their
## near-edge size, and only the middles stretch. One draw call, as a nine-patch.
static func draw_nine(ci: CanvasItem, piece: String, area: Rect2, scale: float = 1.0, tint: Color = Color.WHITE) -> void:
	if not _nines.has(piece):
		var box: StyleBoxTexture = StyleBoxTexture.new()
		box.texture = texture_of(piece)
		box.region_rect = rect(piece)
		var nine: Array = meta(piece, "nine")
		box.texture_margin_left = float(nine[0])
		box.texture_margin_top = float(nine[1])
		box.texture_margin_right = float(nine[2])
		box.texture_margin_bottom = float(nine[3])
		_nines[piece] = box
	var style: StyleBoxTexture = _nines[piece]
	style.modulate_color = tint
	var k: float = _k(piece) * scale
	# A nine-patch draws its margins at their pixel size, so it is drawn in the piece's own pixels and scaled.
	ci.draw_set_transform(area.position, 0.0, Vector2(k, k))
	ci.draw_style_box(style, Rect2(Vector2.ZERO, area.size / k))
	ci.draw_set_transform(Vector2.ZERO)

## Draws the number `n` in the atlas's digits, centred on `centre`, its digits `height` tall: a door's number batches
## with its house instead of breaking the run with text.
static func draw_number(ci: CanvasItem, n: int, centre: Vector2, height: float, tint: Color = Color.WHITE) -> void:
	var text: String = str(n)
	var k: float = height / size("digit_0").y
	var width: float = 0.0
	for c: String in text:
		width += _advance("digit_" + c)
	width *= _k("digit_0") * k
	var x: float = centre.x - width * 0.5
	for c: String in text:
		var piece: String = "digit_" + c
		var step: float = _advance(piece) * _k(piece) * k
		draw(ci, piece, Vector2(x + step * 0.5, centre.y), k, tint)
		x += step

static func _advance(piece: String) -> float:
	texture()
	return float((_pieces[piece] as Dictionary).get("advance", rect(piece).size.x))

## A house's door, relative to its base point at near-edge size: centre and radius.
static func door(house: String) -> Vector3:
	texture()
	var d: Array = (_pieces[house] as Dictionary)["door"]
	return Vector3(float(d[0]), float(d[1]), float(d[2])) * DESIGN_PER_PIXEL

## The size to draw a door piece at for `house`'s doorway, as a share of its near-edge size: the families' houses
## have wider doorways than the street's.
static func door_scale(house: String) -> float:
	return door(house).z / door("house_red_1").z

## A point a piece records (a sail's "hub", a prop's "offset"), from its base point at near-edge size.
static func point(piece: String, key: String) -> Vector2:
	var p: Array = meta(piece, key)
	return Vector2(float(p[0]), float(p[1])) * _k(piece) if p.size() == 2 else Vector2.ZERO

static func windows(house: String) -> Array[Rect2]:
	texture()
	var out: Array[Rect2] = []
	for w: Variant in (_pieces[house] as Dictionary)["windows"]:
		var r: Array = w
		out.append(Rect2(Vector2(float(r[0]), float(r[1])) * DESIGN_PER_PIXEL,
			Vector2(float(r[2]), float(r[3])) * DESIGN_PER_PIXEL))
	return out

## Door `n`'s colour index (StreetArt.COLOURS), never the same as its neighbour's. Doors come in blocks of four that
## step through the four colours one way or the other from an even start, so each step inside a block changes colour,
## and a block always ends on an odd colour where the next begins on an even one.
static func colour_of(n: int) -> int:
	@warning_ignore("integer_division")
	var block: int = (n - 1) / 4
	var step: int = (n - 1) % 4
	var start: int = 2 * (StreetPath.mix(block * 5 + 1) % 2)
	var direction: int = 1 if StreetPath.mix(block * 5 + 2) % 2 == 0 else -1
	return posmod(start + direction * step, COLOURS.size())

## A door's house: the cottage, the shop-house or the attic house, the concepts' wide shapes. The tall house (shape 2)
## stands only at the street's edges, where it reads as a neighbour's.
const DOOR_SHAPES: PackedInt32Array = [1, 3, 4, 1]

static func house_of(n: int) -> String:
	var shape: int = DOOR_SHAPES[StreetPath.mix(n * 13 + 3) % DOOR_SHAPES.size()]
	return "house_%s_%d" % [COLOURS[colour_of(n)], shape]

## Street's type: Baloo 2 at its heaviest.
static func font() -> Font:
	if _font == null:
		var variation: FontVariation = FontVariation.new()
		variation.base_font = load(FONT)
		variation.variation_opentype = {_weight_tag(): WEIGHT}
		_font = variation
	return _font

## Godot keys a variable font's axes by their OpenType tag as a number.
static func _weight_tag() -> int:
	return TextServerManager.get_primary_interface().name_to_tag("wght")
