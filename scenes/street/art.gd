class_name StreetArt
extends RefCounted

## The street's painted art, packed by tools/pack_street.py (REVAMP_PLAN.md section 10), and the type Street's numbers
## are set in. The map's pieces share one atlas, so they batch, and the screens' pieces have a page of their own. Pieces
## are drawn at their size at the street's near edge, in design pixels: an atlas pixel is one screen pixel on a
## 1084-pixel-wide phone, which shows 720 design pixels across.

## The pages, each a texture and its index: the map's atlas, then the screens'.
const PAGES: PackedStringArray = ["res://assets/street/atlas", "res://assets/street/ui"]
const PLAY_BACKDROP: String = "res://assets/street/play_backdrop.png"
const WIN_BACKDROP: String = "res://assets/street/win_backdrop.png"

## A whole-screen backdrop for a screen of this shape: its wide painting (`<name>_wide.png`) on a wide screen, where
## there is one.
static func backdrop(path: String, wide: bool) -> Texture2D:
	var wide_path: String = path.trim_suffix(".png") + "_wide.png"
	return load(wide_path if wide and ResourceLoader.exists(wide_path) else path)
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
static var _number_font: Font

## The map's atlas, loading both pages on first use.
static func texture() -> Texture2D:
	if _textures.is_empty():
		for page: int in range(PAGES.size()):
			_textures.append(load(PAGES[page] + ".png"))
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PAGES[page] + ".json"))
			if data is Dictionary:
				var pieces: Dictionary = (data as Dictionary)["pieces"]
				for name: String in pieces:
					var record: Dictionary = pieces[name]
					record["page"] = page
					_pieces[name] = record
	return _textures[0]

static func has(piece: String) -> bool:
	texture()
	return _pieces.has(piece)

## The page a piece is on.
static func texture_of(piece: String) -> Texture2D:
	texture()
	return _textures[int((_pieces[piece] as Dictionary)["page"])]

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

## A house's door, relative to its base point at near-edge size: centre and radius.
static func door(house: String) -> Vector3:
	texture()
	var d: Array = (_pieces[house] as Dictionary)["door"]
	return Vector3(float(d[0]), float(d[1]), float(d[2])) * DESIGN_PER_PIXEL

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

static func house_of(n: int) -> String:
	return "house_%s_%d" % [COLOURS[colour_of(n)], 1 + StreetPath.mix(n * 13 + 3) % SHAPES]

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

## The same, drawn as a signed distance field for the doors, which the map scales every frame.
static func number_font() -> Font:
	if _number_font == null:
		var msdf: FontFile = (load(FONT) as FontFile).duplicate() as FontFile
		msdf.multichannel_signed_distance_field = true
		msdf.msdf_pixel_range = 16
		msdf.msdf_size = 64
		var variation: FontVariation = FontVariation.new()
		variation.base_font = msdf
		variation.variation_opentype = {_weight_tag(): WEIGHT}
		_number_font = variation
	return _number_font
