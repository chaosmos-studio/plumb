class_name ShareCard
extends Control

## The QR code is for anyone who sees the card in a story or a chat, where a link cannot be tapped.
##
## The kit expects from the game: `GameShare.stage(holder, level, centre, room)`, which puts the level's
## board, as it starts, in `holder` (a Node2D already in the card), centred on `centre` and fitted to
## `room`. Also `GameShare.LINK`, the game's web address, and `GameShare.GET`, its get link.

## A portrait size that suits chats and stories.
const SIZE: Vector2i = Vector2i(1080, 1350)
const MARGIN: float = 72.0
const BOARD: Rect2 = Rect2(90.0, 220.0, 900.0, 650.0)
## The code in the card's corner, quiet zone included, and the two-module margin a reader needs round it.
## Wide enough for four pixels a module even at version 6, which the longest game's link needs.
const QR_SIDE: float = 184.0
const QR_QUIET: int = 2
## The code dark on white in every theme, since a reader needs the contrast.
const QR_INK: Color = Color("1d2030")

var moment: Result.Moment
var earned: int = 0
var heading: String = ""
var _qr: PackedStringArray = PackedStringArray()

static func send(host: Node, image: Image, moment_won: Result.Moment) -> void:
	var said: String = moment_won.summary.left(1).to_lower() + moment_won.summary.substr(1)
	var text: String = "%s, level %d: %s. Can you match it? %s?from=share" % [Brand.NAME, moment_won.level + 1, said,
		GameShare.GET]
	if OS.has_feature("web"):
		_web(image.save_png_to_buffer(), _file_name(moment_won), text)
		return
	# One file, written over at each share, so sharing never piles cards up on the phone.
	var path: String = _write(image, "card.png")
	if path == "":
		Toast.say(host, "Could not save the card")
	elif OS.has_feature("android"):
		if not _android(ProjectSettings.globalize_path(path), text):
			Toast.say(host, "Sharing is not available here")
	else:
		Toast.say(host, "Card saved to %s" % ProjectSettings.globalize_path(path))

## Words alone, for the daily's time. Where nothing can share them they are copied instead.
static func send_text(host: Node, text: String) -> void:
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("!!navigator.share", true)):
		JavaScriptBridge.eval("navigator.share({text: %s}).catch(function () {})" % JSON.stringify(text), true)
		return
	if OS.has_feature("android") and _android_text(text):
		return
	DisplayServer.clipboard_set(text)
	Toast.say(host, "Copied to the clipboard")

static func save(host: Node, image: Image, moment_won: Result.Moment) -> void:
	var png: PackedByteArray = image.save_png_to_buffer()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(png, _file_name(moment_won), "image/png")
		return
	if OS.has_feature("android"):
		if Gallery.keep(png, _file_name(moment_won), "image/png"):
			Toast.say(host, "Saved to Pictures")
		else:
			send(host, image, moment_won)
		return
	var path: String = _write(image, _file_name(moment_won))
	Toast.say(host, "Card saved to %s" % ProjectSettings.globalize_path(path) if path != "" else "Could not save the card")

static func _file_name(moment_won: Result.Moment) -> String:
	return "%s-level-%d.png" % [Brand.NAME.to_lower(), moment_won.level + 1]

static func _write(image: Image, file_name: String) -> String:
	var folder: String = "user://share"
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = "%s/%s" % [folder, file_name]
	return path if image.save_png(path) == OK else ""

static func render(host: Node, moment_won: Result.Moment, stars: int, title: String) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var view: SubViewport = SubViewport.new()
	view.size = SIZE
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var card: ShareCard = ShareCard.new()
	card.moment = moment_won
	card.earned = stars
	card.heading = title
	view.add_child(card)
	host.add_child(view)
	var holder: Node2D = Node2D.new()
	card.add_child(holder)
	GameShare.stage(holder, moment_won.level, BOARD.get_center(), BOARD.size)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	view.queue_free()
	return image

func _ready() -> void:
	size = Vector2(SIZE)
	theme = UI.theme()
	var icon: TextureRect = UI.app_icon(100.0)
	icon.position = Vector2(MARGIN, 66.0)
	icon.size = Vector2(100.0, 100.0)
	add_child(icon)
	_qr = Qr.rows(GameShare.GET + "?from=card")

func _draw() -> void:
	var chapter: int = maxi(Pack.chapter_of(moment.level), 0)
	var tint: Color = ChapterStyle.tint(chapter)
	draw_rect(Rect2(Vector2.ZERO, size), Brand.BG)
	var deep: float = size.y * 0.55
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, deep), Vector2(0.0, deep)]),
		PackedColorArray([Color(tint, 0.18), Color(tint, 0.18), Color(tint, 0.0), Color(tint, 0.0)]))
	ChapterStyle.pattern(self, chapter, Rect2(Vector2.ZERO, size), Color(tint, 0.06))
	var display: Font = UI.display_font()
	var ui: Font = UI.ui_font()
	draw_string(display, Vector2(MARGIN + 124.0, 136.0), Brand.NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Brand.INK)
	var level_text: String = "LEVEL %d" % (moment.level + 1)
	_right(UI.caption_font(), level_text, 112.0, 30, tint)
	if not Pack.chapters.is_empty() and Pack.chapter_of(moment.level) >= 0:
		_right(ui, Pack.chapter_name(chapter), 156.0, 28, Brand.MUTED)
	for k: int in range(3):
		var at: Vector2 = Vector2(size.x * 0.5 + (k - 1) * 104.0, 922.0)
		_star(at, 40.0, Brand.GOLD if k < earned else Color(Brand.MUTED, 0.3))
	_centre(display, heading, 1044.0, 84, Brand.INK)
	_centre(ui, moment.summary, 1098.0, 36, Brand.MUTED)
	draw_rect(Rect2(MARGIN, 1136.0, size.x - MARGIN * 2.0, 2.0), Brand.LINE)
	draw_string(display, Vector2(MARGIN, 1214.0), "Can you match it?", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Brand.INK)
	draw_string(UI.caption_font(), Vector2(MARGIN, 1258.0), "SCAN TO GET %s" % Brand.NAME.to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 24, Brand.MUTED)
	draw_string(ui, Vector2(MARGIN, 1300.0), GameShare.LINK.trim_prefix("https://").trim_suffix("/"), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 30, Brand.MUTED)
	_code(Rect2(size.x - MARGIN - QR_SIDE, 1150.0, QR_SIDE, QR_SIDE))

func _code(at: Rect2) -> void:
	if _qr.is_empty():
		return
	var tile: StyleBoxFlat = StyleBoxFlat.new()
	tile.bg_color = Color.WHITE
	tile.set_corner_radius_all(14)
	tile.anti_aliasing = true
	draw_style_box(tile, at)
	var n: int = _qr.size()
	# Whole pixels a module, so neighbouring modules meet without a seam.
	var module: float = floorf(at.size.x / float(n + QR_QUIET * 2))
	var origin: Vector2 = at.position + Vector2.ONE * floorf((at.size.x - module * n) * 0.5)
	for y: int in n:
		var row: String = _qr[y]
		for x: int in n:
			if row[x] == "1":
				draw_rect(Rect2(origin + Vector2(x, y) * module, Vector2.ONE * module), QR_INK)

func _centre(font: Font, text: String, baseline: float, font_size: int, colour: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - w) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)

func _right(font: Font, text: String, baseline: float, font_size: int, colour: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(size.x - MARGIN - w, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)

func _star(c: Vector2, r: float, colour: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for k: int in range(10):
		var a: float = -PI * 0.5 + k * PI / 5.0
		points.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(points, colour)
	points.append(points[0])
	draw_polyline(points, colour, 2.0, true)

## Through the FileProvider every Godot Android app has.
static func _android(path: String, text: String) -> bool:
	if not Engine.has_singleton("AndroidRuntime"):
		return false
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Object = runtime.call("getActivity")
	var intents: Object = JavaClassWrapper.wrap("android.content.Intent")
	var files: Object = JavaClassWrapper.wrap("java.io.File")
	var provider: Object = JavaClassWrapper.wrap("androidx.core.content.FileProvider")
	var clips: Object = JavaClassWrapper.wrap("android.content.ClipData")
	if activity == null or intents == null or provider == null:
		return false
	var authority: String = String(activity.call("getPackageName")) + ".fileprovider"
	var uri: Object = provider.call("getUriForFile", activity, authority, files.call("File", path))
	if uri == null or JavaClassWrapper.get_exception() != null:
		return false
	var send: Object = intents.call("Intent", intents.get("ACTION_SEND"))
	send.call("setType", "image/png")
	send.call("putExtra", intents.get("EXTRA_STREAM"), uri)
	send.call("putExtra", intents.get("EXTRA_TEXT"), text)
	send.call("setClipData", clips.call("newRawUri", "", uri))
	send.call("addFlags", intents.get("FLAG_GRANT_READ_URI_PERMISSION"))
	var chooser: Object = intents.call("createChooser", send, "Share")
	if chooser == null or JavaClassWrapper.get_exception() != null:
		return false
	activity.call("runOnUiThread", runtime.call("createRunnableFromGodotCallable", func() -> void:
		activity.call("startActivity", chooser)))
	return true

static func _android_text(text: String) -> bool:
	if not Engine.has_singleton("AndroidRuntime"):
		return false
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Object = runtime.call("getActivity")
	var intents: Object = JavaClassWrapper.wrap("android.content.Intent")
	if activity == null or intents == null:
		return false
	var send: Object = intents.call("Intent", intents.get("ACTION_SEND"))
	send.call("setType", "text/plain")
	send.call("putExtra", intents.get("EXTRA_TEXT"), text)
	var chooser: Object = intents.call("createChooser", send, "Share")
	if chooser == null or JavaClassWrapper.get_exception() != null:
		return false
	activity.call("runOnUiThread", runtime.call("createRunnableFromGodotCallable", func() -> void:
		activity.call("startActivity", chooser)))
	return true

static func _web(png: PackedByteArray, file_name: String, text: String) -> void:
	var can: Variant = JavaScriptBridge.eval("!!(navigator.canShare && navigator.canShare({files: [new File([new Uint8Array(1)], 'a.png', {type: 'image/png'})]}))", true)
	if not bool(can):
		JavaScriptBridge.download_buffer(png, file_name, "image/png")
		return
	var js: String = """(function () {
		const bin = atob('%s');
		const bytes = new Uint8Array(bin.length);
		for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
		const file = new File([bytes], '%s', {type: 'image/png'});
		navigator.share({files: [file], text: %s}).catch(function () {});
	})()""" % [Marshalls.raw_to_base64(png), file_name, JSON.stringify(text)]
	JavaScriptBridge.eval(js, true)
