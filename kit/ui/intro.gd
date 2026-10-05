class_name Intro
extends CanvasLayer

## The launch flourish, once each time the app starts. The game's icon sits in the middle of a plain screen,
## much where the phone's own launch screen showed it, and comes alive: the game's res://intro.gd moves the
## icon's parts the way the game moves its pieces. Then the icon shrinks away as the title fades in behind
## it. It never holds up input: a tap goes straight through to the title.
##
## The kit expects from the game: tools/make_icons.py writing the icon's parts to assets/branding/intro/,
## each full frame and drawn where it sits in the icon (ground.png and whatever else), and res://intro.gd
## with `static func play(stage: Control, host: Node) -> float`, which lays the parts on `stage` with
## `part`, finds where they sit with `centre`, sets them moving and answers how long that takes. `host` is
## the screen that started the intro, for an intro that hands something on to it. Without them the whole
## icon simply settles in.

const LAYER: int = 90
## The icon's side as a share of the screen's width, close to Android's launch icon.
const START_SHARE: float = 0.42
## How long the icon takes to shrink away once its parts are done.
const OUT_TIME: float = 0.42
const PARTS: String = "res://assets/branding/intro/"
const GAME: String = "res://intro.gd"
## A pixel at least this opaque counts as part of a piece when finding its centre, which leaves out the soft
## shadows and glows round it.
const SOLID: float = 0.78

## Off in the tools that stage and film the game, so no capture opens on it.
static var enabled: bool = true
static var _played: bool = false
static var _centres: Dictionary = {}
static var _textures: Dictionary = {}

static func play(host: Node) -> void:
	if _played or not enabled:
		return
	_played = true
	host.add_child(Intro.new())

## Part `name` of the icon over the whole of `stage`, behind whatever is added after it. Its texture carries
## mipmaps, since the parts are drawn at the icon's full size and shown at a fraction of it, where curved
## edges would otherwise shimmer as they move.
static func part(stage: Control, name: String) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	if not _textures.has(name):
		var img: Image = (load(PARTS + name + ".png") as Texture2D).get_image()
		img.decompress()
		img.generate_mipmaps()
		_textures[name] = ImageTexture.create_from_image(img)
	rect.texture = _textures[name]
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = stage.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(rect)
	return rect

## Where the solid middle of part `name` sits on `stage`: the centre of the box round its opaque pixels.
static func centre(stage: Control, name: String) -> Vector2:
	if not _centres.has(name):
		var img: Image = (load(PARTS + name + ".png") as Texture2D).get_image()
		img.decompress()
		img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
		var lo: Vector2i = Vector2i(128, 128)
		var hi: Vector2i = Vector2i(-1, -1)
		for y: int in range(128):
			for x: int in range(128):
				if img.get_pixel(x, y).a >= SOLID:
					lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
					hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
		_centres[name] = (Vector2(lo + hi) + Vector2.ONE) * 0.5 / 128.0 if hi.x >= 0 else Vector2(0.5, 0.5)
	return (_centres[name] as Vector2) * stage.size

static func has_parts() -> bool:
	return ResourceLoader.exists(GAME) and ResourceLoader.exists(PARTS + "ground.png")

func _ready() -> void:
	layer = LAYER
	var view: Vector2 = get_viewport().get_visible_rect().size
	var veil: ColorRect = ColorRect.new()
	veil.color = Brand.BG
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var side: float = view.x * START_SHARE
	# Anchored to the middle rather than placed, since a phone may hand over its final size a frame late.
	var stage: Control = Control.new()
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.offset_left = -side * 0.5
	stage.offset_top = -side * 0.5
	stage.offset_right = side * 0.5
	stage.offset_bottom = side * 0.5
	stage.pivot_offset = Vector2(side, side) * 0.5
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	stage.size = Vector2(side, side)
	var busy: float = 0.0
	if has_parts():
		part(stage, "ground")
		busy = float((load(GAME) as GDScript).call("play", stage, get_parent()))
	else:
		var icon: TextureRect = UI.app_icon(side)
		icon.size = stage.size
		stage.add_child(icon)
		stage.scale = Vector2(0.92, 0.92)
		create_tween().tween_property(stage, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		busy = 0.35
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(stage, "scale", Vector2(0.6, 0.6), OUT_TIME).set_delay(busy).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(stage, "modulate:a", 0.0, OUT_TIME).set_delay(busy).set_ease(Tween.EASE_IN)
	t.tween_property(veil, "color:a", 0.0, OUT_TIME).set_delay(busy).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(queue_free)
