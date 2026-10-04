class_name ShareCard
extends Control

## A card of a solved level to send to a friend: the level as it was set, the stars, the words on the win,
## the moves against par, and where to get the game. It is drawn offscreen at a portrait size that suits
## chats and stories, then handed to the phone's share sheet on Android (through the FileProvider every
## Godot app has), to the browser's share sheet or a download on the web, and saved to the user folder
## anywhere else.
##
## The kit expects from the game: `GameShare.stage(holder, level, centre, room)`, which puts the level's
## board, as it starts, in `holder` (a Node2D already in the card), centred on `centre` and fitted to
## `room`; and `GameShare.LINK`, the game's web address.

const SIZE: Vector2i = Vector2i(1080, 1350)
const MARGIN: float = 72.0
const BOARD: Rect2 = Rect2(90.0, 230.0, 900.0, 700.0)

var moment: Result.Moment
var earned: int = 0
var heading: String = ""

## Makes the card for `moment` and shares it. Says so when it cannot.
static func share(host: Node, moment_won: Result.Moment, stars: int, title: String) -> void:
	var image: Image = await render(host, moment_won, stars, title)
	if image == null or image.is_empty():
		Toast.say(host, "Could not make the card here")
		return
	var file_name: String = "%s-level-%d.png" % [Brand.NAME.to_lower(), moment_won.level + 1]
	var said: String = moment_won.summary.left(1).to_lower() + moment_won.summary.substr(1)
	var text: String = "%s, level %d: %s. Can you match it? %s" % [Brand.NAME, moment_won.level + 1, said, GameShare.LINK]
	if OS.has_feature("web"):
		_web(image.save_png_to_buffer(), file_name, text)
		return
	var folder: String = "user://share"
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = "%s/%s" % [folder, file_name]
	if image.save_png(path) != OK:
		Toast.say(host, "Could not save the card")
		return
	if OS.has_feature("android"):
		if not _android(ProjectSettings.globalize_path(path), text):
			Toast.say(host, "Sharing is not available here")
		return
	Toast.say(host, "Card saved to %s" % ProjectSettings.globalize_path(path))

## Draws the card offscreen and reads it back, or null where nothing is drawn (a headless run).
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
		var at: Vector2 = Vector2(size.x * 0.5 + (k - 1) * 104.0, 1000.0)
		_star(at, 40.0, Brand.GOLD if k < earned else Color(Brand.MUTED, 0.3))
	_centre(display, heading, 1122.0, 84, Brand.INK)
	_centre(ui, moment.summary, 1184.0, 36, Brand.MUTED)
	draw_rect(Rect2(MARGIN, 1236.0, size.x - MARGIN * 2.0, 2.0), Brand.LINE)
	_centre(ui, "Can you match it?   %s" % GameShare.LINK.trim_prefix("https://").trim_suffix("/"), 1296.0, 30, Brand.INK)

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

## The Android share sheet for the PNG at `path`, offered through the app's FileProvider, with `text`.
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

## The browser's share sheet where it can send files, otherwise a download.
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
