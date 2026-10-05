class_name Replay
extends CanvasLayer

## Watching a solve again. The game plays its own recorded moves from the start between `opening()` and
## `closing()`, calls `beat()` as each move lands, and `finish()` at the end. This sets the game clock's
## pace, puts the screen's controls and the banner away, gives the board a kick on every beat, and reads a
## tap as a wish to skip, which the game sees in `skipping` between moves. The clock, the board and the
## controls come back when it finishes or the screen goes.
##
## Plain, it is a quick look: a Replay mark at the top, and a tap skips to the end. Given the win's Moment
## it is a reel, a short film of the solve to show someone: a title card with the game's name, the level
## and its chapter in the chapter's colour; the moves at an easier pace under a progress bar, framed by the
## game's name and the score; and an end card with the stars, the words on the win, and a QR code to the
## game on Google Play. A tap skips to the end card and another closes it, as does a long enough look.
##
## On Android the end card can save the reel as a video: `closing()` then answers true, the game plays the
## reel once more, and this time every frame goes to a ReelVideo, the sound off and the clock slowed so each
## frame is 1/FPS of the reel. The film is kept in Movies, and nothing else is written.

const SPEED: float = 2.2
const REEL_SPEED: float = 1.5
const LAYER: int = 50
const TITLE_HOLD: float = 1.4
const END_HOLD: float = 8.0
## How long the end card waits when it offers Save video, long enough to find the button.
const END_OFFER: float = 14.0
## How long the end card stays in a saved film.
const END_FILM: float = 3.5
## How far the board is thrown on a beat, in pixels, and how long the kick takes to die away.
const KICK: float = 8.0
const KICK_REEL: float = 13.0
const KICK_TIME: float = 0.34
const BAND: float = 230.0

var skipping: bool = false
var moment: Result.Moment
var moves: int = 0
var _hidden: Array[CanvasLayer] = []
var _root: Control
var _bar: _Progress
var _beats: int = 0
var _kick: float = 0.0
var _clock: float = 0.0
var _canvas: Transform2D = Transform2D.IDENTITY
var _closed: bool = false
## How fast the reel runs; the clock is this, slowed further while recording.
var _pace: float = 1.0
## Set by the end card's Save video; the film being made, and the frames a second it takes them at.
var _wants_film: bool = false
var _film: ReelVideo
var _max_fps: int = 0

## Starts a replay over `host`: a reel when `won` is given, with `count` moves to come.
static func begin(host: Node, won: Result.Moment = null, count: int = 0) -> Replay:
	var replay: Replay = Replay.new()
	replay.moment = won
	replay.moves = count
	host.add_child(replay)
	return replay

func _ready() -> void:
	layer = LAYER
	_canvas = get_viewport().canvas_transform
	# Controls sit on layers from 1 up; a backdrop under the board, on a lower layer, stays.
	for child: Node in get_parent().get_children():
		if child is CanvasLayer and child != self and (child as CanvasLayer).visible and (child as CanvasLayer).layer >= 1:
			(child as CanvasLayer).visible = false
			_hidden.append(child)
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)
	if moment == null:
		_mark()
	else:
		_frame()
	Ads.cover(true)

func _exit_tree() -> void:
	if _film != null:
		var film: ReelVideo = _film
		_stop_film()
		film.cancel()
	Engine.time_scale = 1.0
	get_viewport().canvas_transform = _canvas
	_show_controls()
	Ads.cover(false)

## Before the first move: a short pause, or for a reel the title card, then the clock runs at the replay's
## pace.
func opening() -> void:
	if moment == null:
		_set_pace(SPEED)
		await get_tree().create_timer(0.45).timeout
		return
	_set_pace(1.0)
	var title: _Card = _Card.new(moment, false)
	_root.add_child(title)
	await _hold(TITLE_HOLD)
	if not is_inside_tree():
		return
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(title, "position:y", -title.size.y * 0.25, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(title, "modulate:a", 0.0, 0.4)
	await t.finished
	title.queue_free()
	_set_pace(REEL_SPEED)

## A move has landed: the board takes a kick, and a reel's progress bar steps on.
func beat() -> void:
	_beats += 1
	_kick = 1.0
	if _bar != null:
		_bar.value = float(_beats) / maxf(1.0, float(moves))

## After the last move: for a reel, the end card, until a tap or a long enough look. True when the player
## asked to save the reel as a video: the game then plays it once more, and that time is filmed.
func closing() -> bool:
	_set_pace(1.0)
	_kick = 0.0
	get_viewport().canvas_transform = _canvas
	if moment == null or not is_inside_tree():
		return false
	if _bar != null:
		_bar.value = 1.0
	var filming: bool = _film != null
	var offer: Callable = _ask_film if not filming and ReelVideo.available() else Callable()
	var end: _Card = _Card.new(moment, true, offer, filming)
	end.modulate.a = 0.0
	_root.add_child(end)
	create_tween().tween_property(end, "modulate:a", 1.0, 0.3)
	end.play()
	await _hold(END_FILM if filming else END_OFFER if offer.is_valid() else END_HOLD)
	if not is_inside_tree():
		return false
	if filming:
		_end_film()
		return false
	if not _wants_film:
		return false
	_wants_film = false
	end.queue_free()
	return _start_film()

func finish() -> void:
	queue_free()

func _process(delta: float) -> void:
	if _kick <= 0.0:
		return
	_clock += delta
	_kick = maxf(0.0, _kick - delta / KICK_TIME)
	var reach: float = (KICK_REEL if moment != null else KICK) * _kick * _kick
	var zoom: float = 1.0 + 0.018 * _kick
	var centre: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var offset: Vector2 = Vector2(sin(_clock * 61.0), cos(_clock * 47.0)) * reach
	get_viewport().canvas_transform = _canvas * Transform2D(0.0, Vector2(zoom, zoom), 0.0, centre - centre * zoom + offset)

## The clock at `pace`, and while filming slowed so each frame handed over is 1/FPS of the reel.
func _set_pace(pace: float) -> void:
	_pace = pace
	Engine.time_scale = pace * (_film.rate / ReelVideo.FPS if _film != null else 1.0)

## Waits `seconds` of the reel's own time at an even pace, which is real time unless filming, or until
## the next tap.
func _hold(seconds: float) -> void:
	var waited: float = 0.0
	_closed = false
	while waited < seconds and not _closed and is_inside_tree():
		await get_tree().process_frame
		waited += get_process_delta_time() / maxf(_pace, 0.001)

func _on_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if not pressed or _film != null:
		return
	skipping = true
	_closed = true

func _ask_film() -> void:
	_wants_film = true
	_closed = true

## Starts the film: how long a frame takes to hand over sets the pace, then the recorder starts, the
## sound goes off and every drawn frame is sent on. False, with a note, when the phone cannot.
func _start_film() -> bool:
	# The frame's size comes from a frame: the texture's own size is scaled by the stretch on 4.7.
	var view: Vector2i = Vector2i.ZERO
	var cost: float = 0.0
	for k: int in range(2):
		var started: int = Time.get_ticks_usec()
		var probe: Image = get_viewport().get_texture().get_image()
		view = probe.get_size()
		probe.convert(Image.FORMAT_RGBA8)
		var fitted: Vector2i = ReelVideo.size_for(view)
		probe.resize(fitted.x, fitted.y, Image.INTERPOLATE_BILINEAR)
		probe.get_data()
		cost = maxf(cost, (Time.get_ticks_usec() - started) / 1000.0)
	print("%s: a frame of %s takes %.0f ms to hand over" % [Brand.NAME, view, cost])
	var film: ReelVideo = ReelVideo.new()
	if not film.begin(view, ReelVideo.rate_for(cost)):
		Gallery.say("This phone cannot make a video here")
		return false
	_film = film
	_max_fps = Engine.max_fps
	Engine.max_fps = int(film.rate)
	AudioServer.set_bus_mute(0, true)
	RenderingServer.frame_post_draw.connect(_capture)
	skipping = false
	_beats = 0
	if _bar != null:
		_bar.reset()
	Gallery.say("Making your video")
	return true

func _capture() -> void:
	if _film != null:
		_film.add(get_viewport().get_texture().get_image())

## The film is done: kept in Movies, and said so.
func _end_film() -> void:
	var film: ReelVideo = _film
	_stop_film()
	var file_name: String = "%s-level-%d.mp4" % [Brand.NAME.to_lower(), moment.level + 1]
	print("%s: the reel is %d frames" % [Brand.NAME, film.frames])
	if film.finish() and film.keep(file_name):
		Gallery.say("Saved to Movies")
	else:
		film.cancel()
		Gallery.say("Could not save the video")

func _stop_film() -> void:
	if RenderingServer.frame_post_draw.is_connected(_capture):
		RenderingServer.frame_post_draw.disconnect(_capture)
	_film = null
	Engine.max_fps = _max_fps
	AudioServer.set_bus_mute(0, false)
	_set_pace(_pace)

func _show_controls() -> void:
	for hidden: CanvasLayer in _hidden:
		if is_instance_valid(hidden):
			hidden.visible = true
	_hidden.clear()

## The plain replay's mark: the fast-forward sign and the word on a pill, and how to skip.
func _mark() -> void:
	var mark: VBoxContainer = VBoxContainer.new()
	mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mark.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mark.offset_top = Hud.TOP + float(UI.safe_margins(get_viewport())["top"]) + 6.0
	mark.add_theme_constant_override("separation", 4)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_child(UI.centred(_Pill.new()))
	mark.add_child(UI.caption("Tap to skip", 18))
	_root.add_child(mark)

## A reel's frame while the moves play: the game's name and the level over the board, with the progress
## bar, and the score under it, each on a band that fades into the board.
func _frame() -> void:
	var safe: Dictionary = UI.safe_margins(get_viewport())
	var chapter: int = maxi(Pack.chapter_of(moment.level), 0)
	var tint: Color = ChapterStyle.tint(chapter)
	var top: _Band = _Band.new(true)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = BAND + float(safe["top"])
	_root.add_child(top)
	_bar = _Progress.new()
	_bar.tint = tint
	_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_left = 32.0
	_bar.offset_right = -32.0
	_bar.offset_top = 26.0 + float(safe["top"])
	_bar.offset_bottom = _bar.offset_top + 8.0
	_root.add_child(_bar)
	var head: HBoxContainer = HBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 32.0
	head.offset_right = -32.0
	head.offset_top = _bar.offset_bottom + 24.0
	head.offset_bottom = head.offset_top + 72.0
	head.add_theme_constant_override("separation", 18)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UI.app_icon(72.0))
	var wordmark: Label = UI.title(Brand.NAME, 52)
	wordmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(wordmark)
	var level: VBoxContainer = VBoxContainer.new()
	level.alignment = BoxContainer.ALIGNMENT_CENTER
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number: Label = UI.caption("Level %d" % (moment.level + 1), 24, tint)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level.add_child(number)
	if not Pack.chapters.is_empty():
		var named: Label = UI.label(Pack.chapter_name(chapter), 24, Brand.MUTED)
		named.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		level.add_child(named)
	head.add_child(level)
	_root.add_child(head)
	var bottom: _Band = _Band.new(false)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BAND - float(safe["bottom"])
	_root.add_child(bottom)
	var score: VBoxContainer = VBoxContainer.new()
	score.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	score.offset_bottom = -64.0 - float(safe["bottom"])
	score.offset_top = score.offset_bottom - 96.0
	score.alignment = BoxContainer.ALIGNMENT_CENTER
	score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score.add_child(UI.title(moment.summary, 40))
	score.add_child(UI.caption("Can you match it?", 22))
	_root.add_child(score)

## A whole-screen card in the chapter's colours: the title before the moves, or the end after them.
class _Card extends Control:
	var moment: Result.Moment
	var end: bool = false
	## The end card's Save video, where the phone can make one; and whether this card is being filmed,
	## which leaves out everything that asks for a tap.
	var on_film: Callable = Callable()
	var filming: bool = false
	var _stars: Array[StarIcon] = []
	var _qr: QrCard

	func _init(won: Result.Moment, is_end: bool, save_video: Callable = Callable(), in_film: bool = false) -> void:
		moment = won
		end = is_end
		on_film = save_video
		filming = in_film
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var column: VBoxContainer = VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 18)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var centre: CenterContainer = UI.centred(column)
		centre.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(centre)
		var chapter: int = maxi(Pack.chapter_of(moment.level), 0)
		var tint: Color = ChapterStyle.tint(chapter)
		if not end:
			var icon: TextureRect = UI.app_icon(200.0)
			icon.pivot_offset = Vector2(100.0, 100.0)
			column.add_child(UI.centred(icon))
			column.add_child(UI.title(Brand.NAME, 104))
			column.add_child(UI.caption("Level %d" % (moment.level + 1), 30, tint))
			if not Pack.chapters.is_empty():
				column.add_child(UI.label(Pack.chapter_name(chapter), 36, Brand.MUTED))
			icon.scale = Vector2(0.2, 0.2)
			create_tween().tween_property(icon, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			return
		var head: HBoxContainer = HBoxContainer.new()
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_theme_constant_override("separation", 16)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(UI.app_icon(64.0))
		head.add_child(UI.title(Brand.NAME, 52))
		column.add_child(head)
		column.add_child(UI.spacer(8))
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k: int in range(3):
			var star: StarIcon = StarIcon.new(76.0, false)
			row.add_child(star)
			_stars.append(star)
		column.add_child(row)
		var words: String = moment.words[0] if not moment.words.is_empty() else "Solved"
		column.add_child(UI.title(words, 72))
		column.add_child(UI.label(moment.summary, 30, Brand.MUTED))
		column.add_child(UI.spacer(10))
		_qr = QrCard.new()
		_qr.rows = Qr.rows(GameShare.STORE)
		_qr.icon = UI.icon_texture()
		_qr.custom_minimum_size = Vector2(320.0, 320.0)
		column.add_child(UI.centred(_qr))
		column.add_child(UI.caption("Scan to play", 22))
		column.add_child(UI.title("Get %s on Google Play" % Brand.NAME, 40))
		if filming:
			return
		column.add_child(UI.spacer(10))
		if on_film.is_valid():
			var save: Button = UI.button("Save video", UI.Style.PRIMARY)
			save.pressed.connect(on_film)
			column.add_child(UI.centred(save))
		column.add_child(UI.caption("Tap to close", 18))

	## The end card's stars landing one by one, then the code popping in.
	func play() -> void:
		await get_tree().create_timer(0.35).timeout
		for k: int in range(mini(moment.stars, 3)):
			if not is_inside_tree():
				return
			var star: StarIcon = _stars[k]
			star.filled = true
			star.pivot_offset = star.size * 0.5
			star.scale = Vector2(0.3, 0.3)
			star.create_tween().tween_property(star, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Audio.play(&"star", -6.0, 1.0 + 0.08 * k)
			Audio.buzz(10)
			await get_tree().create_timer(0.2).timeout
		if is_inside_tree():
			_qr.play()

	func _draw() -> void:
		var chapter: int = maxi(Pack.chapter_of(moment.level), 0)
		var tint: Color = ChapterStyle.tint(chapter)
		draw_rect(Rect2(Vector2.ZERO, size), Brand.BG)
		var deep: float = size.y * 0.6
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, deep), Vector2(0.0, deep)]),
			PackedColorArray([Color(tint, 0.2), Color(tint, 0.2), Color(tint, 0.0), Color(tint, 0.0)]))
		ChapterStyle.pattern(self, chapter, Rect2(Vector2.ZERO, size), Color(tint, 0.07))

## A band of the background behind a reel's heading or score, fading into the board.
class _Band extends Control:
	var _top: bool = true

	func _init(at_top: bool) -> void:
		_top = at_top
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var solid: Color = Brand.BG
		var clear: Color = Color(Brand.BG, 0.0)
		var a: Color = solid if _top else clear
		var b: Color = clear if _top else solid
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
			PackedColorArray([a, a, b, b]))

## A reel's progress: a thin track that fills in the chapter's colour as the moves land.
class _Progress extends Control:
	var tint: Color = Color.WHITE
	var value: float = 0.0:
		set(v):
			var to: float = clampf(v, 0.0, 1.0)
			if is_inside_tree():
				create_tween().tween_property(self, "_shown", to, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			value = to
	var _shown: float = 0.0:
		set(v):
			_shown = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Back to empty at once, for the reel played again.
	func reset() -> void:
		value = 0.0
		_shown = 0.0

	func _draw() -> void:
		var r: float = size.y * 0.5
		_bar(Vector2(r, r), Vector2(size.x - r, r), Color(Brand.INK, 0.16))
		if _shown > 0.0:
			_bar(Vector2(r, r), Vector2(lerpf(r, size.x - r, _shown), r), tint)

	func _bar(from: Vector2, to: Vector2, colour: Color) -> void:
		draw_line(from, to, colour, size.y, true)
		draw_circle(from, size.y * 0.5, colour, true, -1.0, true)
		draw_circle(to, size.y * 0.5, colour, true, -1.0, true)

## The Replay mark: the fast-forward sign and the word, on a pill in the accent colour.
class _Pill extends Control:
	const HEIGHT: float = 64.0

	func _init() -> void:
		custom_minimum_size = Vector2(212.0, HEIGHT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Brand.ACCENT
		box.set_corner_radius_all(int(HEIGHT * 0.5))
		box.anti_aliasing = true
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		Icons.draw(self, &"watch", Vector2(44.0, size.y * 0.5), 40.0, Brand.ACCENT_INK)
		var font: Font = UI.ui_font()
		draw_string(font, Vector2(76.0, size.y * 0.5 + 11.0), "Replay", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Brand.ACCENT_INK)
