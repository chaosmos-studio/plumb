class_name StreetAtlas
extends RefCounted

## Bakes every StreetPieces piece into one texture, once, so the map draws each stand-in as a rectangle of it, the
## way it will draw the painted cut-outs (REVAMP_PLAN.md section 10). Pieces are drawn at SCALE times their near-edge
## size, since the near edge shows design pixels about 1.5 times larger on a 1080-pixel-wide phone.

const SCALE: float = 1.5
const SIZE: Vector2i = Vector2i(2048, 2048)
const PAD: int = 6

static var texture: Texture2D
## Piece name to [its box in the atlas, its base point inside that box], both in atlas pixels.
static var regions: Dictionary = {}

static func bake(host: Node) -> void:
	if texture != null:
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(viewport)
	# Drawn with premultiplied blending onto a clear target, a piece's colours are stored as they are, not darkened by
	# their own alpha, so the map's ordinary blending shows them right.
	var straight: CanvasItemMaterial = CanvasItemMaterial.new()
	straight.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	var x: int = PAD
	var y: int = PAD
	var shelf: int = 0
	for piece: String in StreetPieces.PIECES:
		var spec: Array = StreetPieces.PIECES[piece]
		var box: Vector2 = (spec[0] as Vector2) * SCALE
		var w: int = ceili(box.x)
		var h: int = ceili(box.y)
		if x + w + PAD > SIZE.x:
			x = PAD
			y += shelf + PAD
			shelf = 0
		var base: Vector2 = (spec[1] as Vector2) * SCALE
		var painter: _Painter = _Painter.new()
		painter.piece = piece
		painter.material = straight
		painter.position = Vector2(x, y) + base
		painter.scale = Vector2(SCALE, SCALE)
		viewport.add_child(painter)
		regions[piece] = [Rect2(x, y, w, h), base]
		x += w + PAD
		shelf = maxi(shelf, h)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	image.fix_alpha_edges()
	image.generate_mipmaps()
	texture = ImageTexture.create_from_image(image)
	viewport.queue_free()

## Draws `piece` on `ci` with its base at `at`, at the near-edge size.
static func draw(ci: CanvasItem, piece: String, at: Vector2) -> void:
	var spec: Array = regions[piece]
	var region: Rect2 = spec[0]
	var base: Vector2 = spec[1]
	ci.draw_texture_rect_region(texture, Rect2(at - base / SCALE, region.size / SCALE), region)


class _Painter extends Node2D:
	var piece: String = ""

	func _draw() -> void:
		StreetPieces.draw(self, piece)
