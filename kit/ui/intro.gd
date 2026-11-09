class_name Intro
extends CanvasLayer

## A game with a studio beat opens on it: the Chaosmos wordmark told in the game's own look (res://intro/, made
## in studio/chaosmos-intro and installed by its tools/install.sh, which writes res://intro/beat.gd). It plays
## straight over the title as the app starts, in the player's light or dark, with the game's music held until
## it ends, and fades into the title, so nothing else stands between the launch and the title. A tap skips it.
##
## A game without one opens on its icon instead, which never holds up input: a tap goes straight through to
## the title. The kit expects from the game: tools/make_icons.py writing the icon's parts to
## assets/branding/intro/, each full frame and drawn where it sits in the icon (ground.png and whatever else),
## and res://intro.gd with `static func play(stage: Control, host: Node) -> float`, which lays the parts on
## `stage` with `part`, finds where they sit with `centre`, sets them moving and answers how long that takes.
## `host` is the screen that started the intro. Without them the whole icon simply settles in.

const LAYER: int = 90
## The icon's side as a share of the screen's width, close to Android's launch icon.
const START_SHARE: float = 0.42
const OUT_TIME: float = 0.42
const PARTS: String = "res://assets/branding/intro/"
const GAME: String = "res://intro.gd"
const BEAT: String = "res://intro/beat.gd"
const BEAT_PLAYER: String = "res://intro/chaosmos_intro.gd"
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

## Mipmapped, since the parts are drawn at the icon's full size and shown at a fraction of it, where curved
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

static func has_beat() -> bool:
	return ResourceLoader.exists(BEAT) and ResourceLoader.exists(BEAT_PLAYER)

## Loaded by path, so the kit runs the same in a game that has no res://intro/. False when the player cannot be
## made (a script error, such as a name a game's own class hides), and the icon plays instead.
func _play_beat() -> bool:
	var player: GDScript = load(BEAT_PLAYER) as GDScript
	if player == null or not player.can_instantiate():
		return false
	var beat: Control = player.new() as Control
	beat.set("style_name", BEAT)
	beat.set("dark", Appearance.dark)
	beat.set("reveal", true)
	beat.set("muted", not Save.sound_on)
	add_child(beat)
	beat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hold_music(true)
	beat.connect("finished", func() -> void:
		_hold_music(false)
		queue_free())
	return true

## A game whose Audio has `hold_music(on)` keeps its music back while the beat plays.
static func _hold_music(on: bool) -> void:
	if Audio.has_method("hold_music"):
		Audio.call("hold_music", on)

func _ready() -> void:
	layer = LAYER
	if has_beat() and _play_beat():
		return
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
