extends Node2D

## Films a promo from a spec: a list of timed beats (title, play, card, end) with captions, camera
## moves and game actions. The game itself runs in an offscreen viewport through the game's Director,
## so every frame of play is the real game; the motion graphics are drawn here in the game's own fonts
## and colours. Rendered offline by Movie Maker, so timing is exact and the planner's audio lines up.
##
## Run (the promo pipeline does this): godot --path . --write-movie out.avi --fixed-fps 60
##   res://kit/tools/film/film.tscn -- spec=res://build/promo/<id>/spec.json cues=res://build/promo/<id>/cues.json
## with an override.cfg setting the viewport to the film's size and stretch mode "viewport".

## Reels render the game this much larger than the frame, so a slow push-in never upscales.
const SUPERSAMPLE: float = 1.25
const DESIGN_WIDTH: float = 720.0

var spec: Dictionary
var frame: Vector2
var reel: bool = true
var director: Object
var cues: Array[Dictionary] = []

var _frames: int = 0
var _game_view: SubViewport
var _stage: Control
var _screen: TextureRect
var _device: Device
var _fx: Control
var _wipe: Wipe
var _bg: _Backdrop
var _game: Node
var _cues_path: String = "res://build/promo/cues.json"

func _ready() -> void:
	var spec_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("spec="):
			spec_path = arg.substr(5)
		elif arg.begins_with("cues="):
			_cues_path = arg.substr(5)
	spec = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	frame = Vector2(float(spec["size"][0]), float(spec["size"][1]))
	reel = String(spec.get("format", "reel")) == "reel"
	Save.path = "user://film.cfg"
	Save.stars = PackedByteArray()
	Save.music_on = false
	EventBus.settings_changed.emit()
	director = load("res://tools/director.gd").new()
	_build()
	await get_tree().process_frame
	var beats: Array = spec["beats"]
	for i: int in range(beats.size()):
		var beat: Dictionary = beats[i]
		if i > 0 and String(spec.get("transition", "wipe")) == "wipe":
			await _wipe.cover(_wipe_origin(i))
			_clear()
			_cue("beat", {"kind": beat["kind"], "index": i})
			await _enter(beat)
			_wipe.reveal()
		else:
			_clear()
			_cue("beat", {"kind": beat["kind"], "index": i})
			await _enter(beat)
		await _hold(beat)
	_cue("end", {})
	_save_cues()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://film.cfg"))
	get_tree().quit()

func _process(_delta: float) -> void:
	_frames += 1

func _cue(name: String, data: Dictionary) -> void:
	var entry: Dictionary = {"t": snappedf(float(_frames) / 60.0, 0.001), "name": name}
	entry.merge(data)
	cues.append(entry)

func _save_cues() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_cues_path.get_base_dir()))
	var f: FileAccess = FileAccess.open(_cues_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"id": spec.get("id", ""), "frames": _frames, "fps": 60, "cues": cues}, "\t"))
	f.close()

# --- Stage --------------------------------------------------------------------------------------------

func _build() -> void:
	var root: Control = Control.new()
	root.size = frame
	root.theme = UI.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_bg = _Backdrop.new()
	_bg.size = frame
	root.add_child(_bg)
	_game_view = SubViewport.new()
	var portrait: Vector2 = frame if reel else Vector2(1080, 1920)
	var scale: float = SUPERSAMPLE if reel else 1.0
	_game_view.size = Vector2i(int(portrait.x * scale), int(portrait.y * scale))
	_game_view.size_2d_override = Vector2i(int(DESIGN_WIDTH), int(round(DESIGN_WIDTH * portrait.y / portrait.x)))
	_game_view.size_2d_override_stretch = true
	_game_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_game_view)
	_stage = Control.new()
	_stage.size = frame
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stage)
	if reel:
		_screen = TextureRect.new()
		_screen.texture = _game_view.get_texture()
		_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_screen.stretch_mode = TextureRect.STRETCH_SCALE
		_screen.size = frame
		_screen.pivot_offset = frame * Vector2(0.5, 0.55)
		_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(_screen)
	else:
		_device = Device.new()
		_device.texture = _game_view.get_texture()
		var h: float = frame.y * 0.86
		_device.size = Vector2(h * 9.0 / 16.0, h)
		_device.pivot_offset = _device.size * 0.5
		_stage.add_child(_device)
	_fx = Control.new()
	_fx.size = frame
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fx)
	_wipe = Wipe.new()
	root.add_child(_wipe)

func _clear() -> void:
	for child: Node in _game_view.get_children():
		child.queue_free()
	for child: Node in _fx.get_children():
		child.queue_free()
	_game = null
	_stage.visible = false
	_bg.visible = true
	if _screen != null:
		_screen.scale = Vector2.ONE

func _wipe_origin(i: int) -> Vector2:
	var corners: Array[Vector2] = [Vector2(0.15, 0.85), Vector2(0.85, 0.2), Vector2(0.5, 1.0), Vector2(0.9, 0.9)]
	return frame * corners[i % corners.size()]

# --- Beats --------------------------------------------------------------------------------------------

## Sets a beat up. Anything that plays out over the beat is started here and not awaited.
func _enter(beat: Dictionary) -> void:
	match String(beat["kind"]):
		"title":
			_title(String(beat.get("text", Brand.WORDMARK)), String(beat.get("sub", Brand.TAGLINE)))
		"play":
			await _play(beat)
		"card":
			_card(String(beat.get("text", "")), String(beat.get("sub", "")))
		"end":
			_end(String(beat.get("text", Brand.WORDMARK)), String(beat.get("sub", "Free on Google Play")),
				String(beat.get("cta", "")))

func _hold(beat: Dictionary) -> void:
	await get_tree().create_timer(float(beat.get("dur", 3.0))).timeout

func _play(beat: Dictionary) -> void:
	_stage.visible = true
	_bg.visible = not reel
	await director.call("stage", String(beat["action"]), _game_view, false)
	_game = _game_view.get_child(_game_view.get_child_count() - 1)
	if not bool(beat.get("hud", false)):
		for child: Node in _game.get_children():
			if child is CanvasLayer:
				(child as CanvasLayer).visible = false
	var dur: float = float(beat.get("dur", 4.0))
	var zoom: Array = beat.get("zoom", [1.0, 1.0])
	if reel:
		_screen.scale = Vector2.ONE * float(zoom[0])
		create_tween().tween_property(_screen, "scale", Vector2.ONE * float(zoom[1]), dur).set_trans(Tween.TRANS_SINE)
	else:
		var side: String = String(beat.get("side", "left"))
		_device.position = Vector2(frame.x * (0.3 if side == "left" else 0.7) - _device.size.x * 0.5, (frame.y - _device.size.y) * 0.5)
		_device.scale = Vector2.ONE * float(zoom[0])
		create_tween().tween_property(_device, "scale", Vector2.ONE * float(zoom[1]), dur).set_trans(Tween.TRANS_SINE)
	for p: Variant in beat.get("perform", []):
		_perform(p as Dictionary)
	var caption: Variant = beat.get("caption", null)
	if caption is Dictionary:
		_caption(caption as Dictionary, beat)

func _perform(p: Dictionary) -> void:
	await get_tree().create_timer(float(p.get("at", 0.0))).timeout
	if _game == null or not is_instance_valid(_game):
		return
	_cue("perform", {"verb": p.get("verb", "")})
	await director.call("perform", _game, String(p.get("verb", "")), p.get("arg", 0))

func _caption(c: Dictionary, beat: Dictionary) -> void:
	await get_tree().create_timer(float(c.get("at", 0.2))).timeout
	var width: float = frame.x * (0.84 if reel else 0.38)
	var size_px: int = int(frame.x * (0.075 if reel else 0.048))
	var k: Kinetic = Kinetic.new(String(c["text"]), size_px, width, "center" if reel else "left")
	_fx.add_child(k)
	await get_tree().process_frame
	if reel:
		var top: bool = String(c.get("pos", "top")) == "top"
		k.position = Vector2((frame.x - width) * 0.5, frame.y * (0.08 if top else 0.8))
	else:
		var side: String = String(beat.get("side", "left"))
		k.position = Vector2(frame.x * (0.56 if side == "left" else 0.07), frame.y * 0.5 - k.size.y * 0.5)
	_cue("caption", {"text": c["text"]})
	Audio.play(&"tap", -14.0, 1.2)
	k.play_in()
	await get_tree().create_timer(float(c.get("dur", 2.4))).timeout
	if is_instance_valid(k):
		k.play_out()

func _title(text: String, sub: String) -> void:
	var box: VBoxContainer = _centre_box()
	var mark: HBoxContainer = HBoxContainer.new()
	mark.alignment = BoxContainer.ALIGNMENT_CENTER
	mark.add_theme_constant_override("separation", 0)
	box.add_child(mark)
	var size_px: int = int(frame.x * (0.2 if reel else 0.12))
	var letters: Array[Label] = []
	for ch: String in text.split(""):
		var l: Label = UI.title(ch, size_px)
		l.modulate.a = 0.0
		mark.add_child(l)
		letters.append(l)
	var line: _Line = _Line.new()
	line.custom_minimum_size = Vector2(frame.x * (0.28 if reel else 0.16), 8)
	box.add_child(UI.centred(line))
	var tag: Label = UI.caption(sub, int(frame.x * (0.036 if reel else 0.022)))
	tag.modulate.a = 0.0
	box.add_child(tag)
	_reveal_letters(letters, line, tag)

func _reveal_letters(letters: Array[Label], line: _Line, tag: Label) -> void:
	await get_tree().process_frame
	for k: int in range(letters.size()):
		var l: Label = letters[k]
		var home: float = l.position.y
		l.position.y = home + 40.0
		var t: Tween = create_tween().set_parallel(true)
		t.tween_interval(0.1 + k * 0.06)
		t.chain().tween_property(l, "modulate:a", 1.0, 0.3)
		t.parallel().tween_property(l, "position:y", home, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var d: float = 0.2 + letters.size() * 0.06
	create_tween().tween_property(line, "grow", 1.0, 0.6).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(tag, "modulate:a", 1.0, 0.5).set_delay(d + 0.25)

func _card(text: String, sub: String) -> void:
	var box: VBoxContainer = _centre_box()
	var k: Kinetic = Kinetic.new(text, int(frame.x * (0.11 if reel else 0.07)), frame.x * 0.86)
	box.add_child(k)
	k.play_in()
	if sub != "":
		var s: Label = UI.caption(sub, int(frame.x * (0.036 if reel else 0.022)))
		s.modulate.a = 0.0
		box.add_child(s)
		create_tween().tween_property(s, "modulate:a", 1.0, 0.4).set_delay(0.45)
	Audio.play(&"star", -12.0, 0.9)

func _end(text: String, sub: String, cta: String) -> void:
	var box: VBoxContainer = _centre_box()
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/branding/icon.png")
	var side: float = frame.x * (0.26 if reel else 0.12)
	icon.custom_minimum_size = Vector2(side, side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.pivot_offset = Vector2(side, side) * 0.5
	icon.scale = Vector2(0.6, 0.6)
	icon.modulate.a = 0.0
	box.add_child(UI.centred(icon))
	create_tween().tween_property(icon, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(icon, "modulate:a", 1.0, 0.3)
	var mark: Label = UI.title(text, int(frame.x * (0.14 if reel else 0.08)))
	box.add_child(mark)
	var s: Label = UI.label(sub, int(frame.x * (0.048 if reel else 0.026)), Brand.MUTED)
	box.add_child(s)
	var fades: Array[Control] = [mark, s]
	if cta != "":
		var pill: Button = UI.button(cta, UI.Style.PRIMARY)
		pill.add_theme_font_size_override("font_size", int(frame.x * (0.052 if reel else 0.026)))
		pill.custom_minimum_size = Vector2(frame.x * (0.5 if reel else 0.24), frame.x * (0.13 if reel else 0.06))
		box.add_child(UI.spacer(int(frame.y * 0.012)))
		var holder: Control = UI.centred(pill)
		box.add_child(holder)
		fades.append(holder)
	for k: int in range(fades.size()):
		fades[k].modulate.a = 0.0
		create_tween().tween_property(fades[k], "modulate:a", 1.0, 0.4).set_delay(0.3 + k * 0.18)
	Audio.play(&"win", -10.0)

func _centre_box() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.size = frame
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(frame.y * 0.018))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(box)
	return box

## The brand's background: a quiet vertical gradient.
class _Backdrop extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var steps: int = 48
		var top: Color = Brand.BG.lerp(Color.WHITE, 0.3) if Brand.INK.get_luminance() < 0.5 else Brand.BG.lerp(Color.WHITE, 0.05)
		var bottom: Color = Brand.BG if Brand.INK.get_luminance() < 0.5 else Brand.BG.lerp(Color.BLACK, 0.3)
		for i: int in range(steps):
			var y0: float = size.y * i / steps
			draw_rect(Rect2(0, y0, size.x, size.y / steps + 1.0), top.lerp(bottom, float(i) / (steps - 1)))

## A thin accent line that grows out from its centre.
class _Line extends Control:
	var grow: float = 0.0:
		set(value):
			grow = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x * grow
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Brand.ACCENT
		box.set_corner_radius_all(4)
		draw_style_box(box, Rect2((size.x - w) * 0.5, 0, w, size.y))
