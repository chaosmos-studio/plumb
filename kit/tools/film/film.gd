extends Node2D

## Films a promo from a spec: a list of timed beats (title, play, card, challenge, end) with captions,
## camera moves, game actions and the finger that performs them. The game itself runs in an offscreen
## viewport through the game's Director, so every frame of play is the real game; the motion graphics are
## drawn here in the game's own fonts and colours. Rendered offline by Movie Maker, so timing is exact
## and the planner's audio lines up. The film writes cues (beats, transitions, captions, countdown
## ticks, the QR reveal) that the mixer turns into sound effects.
##
## Run (the promo pipeline does this): godot --path . --write-movie out.avi --fixed-fps 60
##   res://kit/tools/film/film.tscn -- spec=res://build/promo/<id>/spec.json cues=res://build/promo/<id>/cues.json
## with an override.cfg setting the viewport to the film's size and stretch mode "viewport".

## Reels render the game this much larger than the frame, so a slow push-in never upscales.
const SUPERSAMPLE: float = 1.25
const DESIGN_WIDTH: float = 720.0
## Where Reels, Shorts and TikTok keep their own buttons and captions, as fractions of the frame: text
## and the QR code stay inside. Measured guides agree on roughly 250 px at the top, 420 at the bottom
## and 130 at the right of a 1080x1920 frame.
const SAFE_TOP: float = 0.13
const SAFE_BOTTOM: float = 0.78
## The landscape phone's height as a fraction of the frame, and how far it rocks while it floats.
const PHONE_HEIGHT: float = 0.9
const PHONE_ROCK: float = 1.6

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
var _design: Vector2
var _caption_style: String = "accent"
var _shade: _Shade

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
	if "film" in director:
		director.set("film", self)
	var style: Dictionary = spec.get("style", {})
	_caption_style = String(style.get("caption", "accent"))
	_build()
	_wipe.mode = String(style.get("transition", "circle"))
	await get_tree().process_frame
	var beats: Array = spec["beats"]
	for i: int in range(beats.size()):
		var beat: Dictionary = beats[i]
		if i > 0:
			_cue("transition", {"mode": _wipe.mode})
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
	if reel:
		_design = Vector2(DESIGN_WIDTH, round(DESIGN_WIDTH * frame.y / frame.x))
		_game_view.size = Vector2i(frame * SUPERSAMPLE)
	else:
		# The game is laid out for the phone's own screen shape, and rendered at twice its size on film.
		_design = Vector2(DESIGN_WIDTH, round(DESIGN_WIDTH * Device.ASPECT))
		var body: Vector2 = Device.body_for_height(frame.y * PHONE_HEIGHT)
		_game_view.size = Vector2i(Vector2(body.x, body.x * Device.ASPECT) * 2.0)
	_game_view.size_2d_override = Vector2i(_design)
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
		_device.size = Device.body_for_height(frame.y * PHONE_HEIGHT)
		_device.pivot_offset = _device.size * 0.5
		_stage.add_child(_device)
	_shade = _Shade.new()
	_shade.size = frame
	_shade.modulate.a = 0.0
	root.add_child(_shade)
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
	_shade.modulate.a = 0.0
	_bg.card = 0.0
	_bg.card_of = null
	if _screen != null:
		_screen.scale = Vector2.ONE
		_screen.material = null
		_screen.pivot_offset = frame * Vector2(0.5, 0.55)
	if _device != null:
		_device.rotation = 0.0

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
		"challenge":
			await _challenge(beat)
		"card":
			_card(String(beat.get("text", "")), String(beat.get("sub", "")))
		"end":
			_end(beat)

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
	if reel and String(beat["kind"]) == "challenge":
		_screen.scale = Vector2.ONE
	elif reel:
		_screen.scale = Vector2.ONE * float(zoom[0])
		if _wipe.mode == "flash":
			_screen.scale *= 1.07
			create_tween().tween_property(_screen, "scale", Vector2.ONE * float(zoom[0]), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(_screen, "scale", Vector2.ONE * float(zoom[1]), dur).set_trans(Tween.TRANS_SINE).set_delay(0.28 if _wipe.mode == "flash" else 0.0)
	else:
		var side: String = String(beat.get("side", "left"))
		var home: Vector2 = Vector2(frame.x * (0.3 if side == "left" else 0.7) - _device.size.x * 0.5, (frame.y - _device.size.y) * 0.5)
		var lean: float = deg_to_rad(PHONE_ROCK) * (1.0 if side == "left" else -1.0)
		_device.position = home + Vector2(0.0, frame.y * 0.04)
		_device.rotation = lean * 2.0
		_device.scale = Vector2.ONE * float(zoom[0])
		var t: Tween = create_tween().set_parallel(true)
		t.tween_property(_device, "position", home, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_device, "rotation", lean, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_device, "scale", Vector2.ONE * float(zoom[1]), dur).set_trans(Tween.TRANS_SINE)
		t.chain().tween_property(_device, "rotation", -lean * 0.5, maxf(0.5, dur - 0.6)).set_trans(Tween.TRANS_SINE)
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
	var width: float = frame.x * (0.8 if reel else 0.38)
	var size_px: int = int(frame.x * (0.07 if reel else 0.046))
	var k: Kinetic = Kinetic.new(String(c["text"]), size_px, width, "center" if reel else "left", Brand.INK, _caption_style)
	_fx.add_child(k)
	await get_tree().process_frame
	if reel:
		k.position = Vector2((frame.x - width) * 0.5, frame.y * SAFE_TOP)
		create_tween().tween_property(_shade, "modulate:a", 1.0, 0.25)
	else:
		var side: String = String(beat.get("side", "left"))
		k.position = Vector2(frame.x * (0.56 if side == "left" else 0.07), frame.y * 0.5 - k.size.y * 0.5)
	_cue("caption", {"text": c["text"]})
	Audio.play(&"tap", -14.0, 1.2)
	k.play_in()
	await get_tree().create_timer(float(c.get("dur", 2.4))).timeout
	if is_instance_valid(k):
		if reel and not bool(c.get("stay", false)):
			create_tween().tween_property(_shade, "modulate:a", 0.0, 0.3)
		if not bool(c.get("stay", false)):
			k.play_out()

## Shows where the player acts: a tap, or a swipe from `at` to `to`, both in the game's own coordinates
## (its 720-wide design space). The Director calls this as it performs, so the finger and the game move
## on the same frame.
func touch(kind: String, at: Vector2, to: Vector2 = Vector2.ZERO) -> void:
	var rect: TextureRect = _screen if reel else _device.screen()
	if rect == null or not _stage.visible:
		return
	var k: float = rect.size.x / _design.x
	var xf: Transform2D = rect.get_global_transform()
	var tint: Color = Color.WHITE if Brand.INK.get_luminance() > 0.5 else Brand.INK
	var r: float = rect.size.x * rect.scale.x * 0.05
	if kind == "swipe":
		Touch.swipe(_fx, xf * (at * k), xf * (to * k), r, tint)
	else:
		Touch.tap(_fx, xf * (at * k), r, tint)
	_cue("touch", {"kind": kind})

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

## An unsolved level left for the viewer. In a reel the game lifts into a rounded card on the brand
## backdrop, which makes room under the board for a ring that counts down; nothing is played, so the
## last thing on screen before the call to action is a puzzle waiting for them.
func _challenge(beat: Dictionary) -> void:
	await _play(beat)
	var ring_r: float = frame.x * (0.05 if reel else 0.03)
	var ring: _Countdown = _Countdown.new(int(beat.get("count", 3)), ring_r)
	if reel:
		_bg.visible = true
		_screen.pivot_offset = frame * Vector2(0.5, 0.47)
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = _round_shader()
		m.set_shader_parameter("rect_size", frame)
		m.set_shader_parameter("radius", 0.0)
		_screen.material = m
		var lift: Tween = create_tween().set_parallel(true)
		lift.tween_property(_screen, "scale", Vector2.ONE * 0.74, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		lift.tween_method(func(r: float) -> void: m.set_shader_parameter("radius", r), 0.0, frame.x * 0.07, 0.6)
		lift.tween_property(_bg, "card", 1.0, 0.6)
		lift.chain().tween_property(_screen, "scale", Vector2.ONE * 0.76, maxf(0.5, float(beat.get("dur", 4.0)) - 0.6)).set_trans(Tween.TRANS_SINE)
		_bg.card_of = _screen
		ring.position = Vector2(frame.x * 0.5, frame.y * 0.74)
	else:
		var side: String = String(beat.get("side", "left"))
		ring.position = Vector2(frame.x * (0.56 if side == "left" else 0.07) + ring_r, frame.y * 0.72)
	_fx.add_child(ring)
	_count_down(ring, int(beat.get("count", 3)))

## Runs on its own, so the beat is revealed while the ring is still counting.
func _count_down(ring: _Countdown, count: int) -> void:
	await get_tree().create_timer(0.7).timeout
	for k: int in range(count):
		if not is_instance_valid(ring):
			return
		_cue("tick", {"n": count - k})
		ring.tick(count - k)
		await get_tree().create_timer(1.0).timeout
	if is_instance_valid(ring):
		_cue("tick", {"n": 0})
		ring.tick(0)

## The last beat: the call to action over a QR code that opens the store listing. In a reel everything
## sits inside the safe zone, and the code holds still long enough for a phone to read it off a screen.
func _end(beat: Dictionary) -> void:
	var text: String = String(beat.get("text", Brand.WORDMARK))
	var sub: String = String(beat.get("sub", "Free on Google Play"))
	var cta: String = String(beat.get("cta", ""))
	var qr: Dictionary = beat.get("qr", {})
	if qr.is_empty():
		_end_plain(text, sub, cta)
	else:
		_end_qr(text, sub, cta, qr, String(beat.get("scan", "Scan to play")))
	Audio.play(&"win", -10.0)

func _end_qr(text: String, sub: String, cta: String, qr: Dictionary, scan: String) -> void:
	var card: QrCard = QrCard.new()
	card.rows = PackedStringArray(qr.get("rows", []))
	card.icon = load("res://assets/branding/icon.png")
	card.ink = Color(String(qr.get("ink", "1d2030")))
	# A demo plays on a monitor or a TV, farther from the phone that scans it, so its code is bigger.
	var side: float = frame.x * 0.5 if reel else frame.y * 0.62
	card.size = Vector2(side, side)
	var brand: HBoxContainer = HBoxContainer.new()
	brand.add_theme_constant_override("separation", int(frame.x * (0.025 if reel else 0.012)))
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/branding/icon.png")
	var icon_side: float = frame.x * (0.1 if reel else 0.06)
	icon.custom_minimum_size = Vector2(icon_side, icon_side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.add_child(icon)
	var mark: Label = UI.title(text, int(frame.x * (0.08 if reel else 0.05)))
	brand.add_child(mark)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.add_theme_constant_override("separation", int(frame.y * 0.004))
	lines.add_child(UI.caption(scan, int(frame.x * (0.034 if reel else 0.02)), Brand.ACCENT))
	lines.add_child(UI.label(sub, int(frame.x * (0.04 if reel else 0.022)), Brand.MUTED))
	var head: Kinetic = null
	if cta != "":
		head = Kinetic.new(cta, int(frame.x * (0.075 if reel else 0.05)), frame.x * (0.8 if reel else 0.4),
			"center" if reel else "left", Brand.INK, _caption_style)
	for c: Control in [card, brand, lines]:
		_fx.add_child(c)
	if head != null:
		_fx.add_child(head)
	await get_tree().process_frame
	if reel:
		if head != null:
			head.position = Vector2((frame.x - head.size.x) * 0.5, frame.y * SAFE_TOP)
		card.position = Vector2((frame.x - side) * 0.5, frame.y * 0.3)
		brand.position = Vector2((frame.x - brand.size.x) * 0.5, card.position.y + side + frame.y * 0.035)
		lines.alignment = BoxContainer.ALIGNMENT_CENTER
		for l: Node in lines.get_children():
			(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lines.size.x = frame.x
		lines.position = Vector2(0.0, brand.position.y + brand.size.y + frame.y * 0.012)
	else:
		var left: float = frame.x * 0.1
		brand.position = Vector2(left, frame.y * 0.24)
		if head != null:
			head.position = Vector2(left, brand.position.y + brand.size.y + frame.y * 0.05)
		lines.position = Vector2(left, frame.y * 0.62)
		card.position = Vector2(frame.x * 0.585, (frame.y - side) * 0.5)
	for c: Control in [brand, lines]:
		c.modulate.a = 0.0
		create_tween().tween_property(c, "modulate:a", 1.0, 0.45).set_delay(0.55)
	if head != null:
		head.play_in()
	await get_tree().create_timer(0.3).timeout
	_cue("qr", {})
	card.play()

func _end_plain(text: String, sub: String, cta: String) -> void:
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

func _centre_box() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.size = frame
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(frame.y * 0.018))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(box)
	return box

func _round_shader() -> Shader:
	var sh: Shader = Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec2 rect_size = vec2(1080.0, 1920.0);
uniform float radius = 0.0;
void fragment() {
	vec2 p = UV * rect_size;
	vec2 q = abs(p - rect_size * 0.5) - (rect_size * 0.5 - vec2(radius));
	float d = length(max(q, vec2(0.0))) - radius;
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(-1.0, 1.0, d);
}
"""
	return sh

## A soft band of the background behind a reel's top caption, so the words read over any board.
class _Shade extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var steps: int = 32
		var h: float = size.y * 0.34
		for i: int in range(steps):
			var k: float = float(i) / steps
			draw_rect(Rect2(0.0, h * k, size.x, h / steps + 1.0), Color(Brand.BG, 0.82 * (1.0 - k * k)))

## A ring that empties once a second around the number left, then shows a question mark.
class _Countdown extends Node2D:
	var radius: float
	var _left: int
	var _sweep: float = 1.0
	var _label: Label

	func _init(count: int, r: float) -> void:
		radius = r
		_left = count
		_label = UI.title(str(count), int(r * 1.05), Brand.INK)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.size = Vector2(r * 2.0, r * 2.0)
		_label.position = -Vector2(r, r)
		_label.pivot_offset = Vector2(r, r)
		add_child(_label)

	func tick(n: int) -> void:
		_left = n
		_label.text = str(n) if n > 0 else "?"
		_label.scale = Vector2(1.35, 1.35)
		create_tween().tween_property(_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if n > 0:
			_sweep = 1.0
			create_tween().tween_property(self, "_sweep", 0.0, 1.0)
		queue_redraw()

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(Brand.SURFACE, 0.92), true, -1.0, true)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(Brand.INK, 0.12), radius * 0.12, true)
		if _left > 0:
			draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * _sweep, 64, Brand.ACCENT, radius * 0.12, true)
		else:
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Brand.ACCENT, radius * 0.12, true)

## The brand's background: a quiet vertical gradient, and the shadow under the game when it lifts into a
## card, so the lift reads even where the game's own background matches this one.
class _Backdrop extends Control:
	var card: float = 0.0:
		set(value):
			card = value
			queue_redraw()
	var card_of: Control = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if card > 0.0:
			queue_redraw()

	func _draw() -> void:
		var steps: int = 48
		var top: Color = Brand.BG.lerp(Color.WHITE, 0.3) if Brand.INK.get_luminance() < 0.5 else Brand.BG.lerp(Color.WHITE, 0.05)
		var bottom: Color = Brand.BG if Brand.INK.get_luminance() < 0.5 else Brand.BG.lerp(Color.BLACK, 0.3)
		for i: int in range(steps):
			var y0: float = size.y * i / steps
			draw_rect(Rect2(0, y0, size.x, size.y / steps + 1.0), top.lerp(bottom, float(i) / (steps - 1)))
		if card > 0.0 and card_of != null:
			var at: Vector2 = card_of.position + card_of.pivot_offset * (Vector2.ONE - card_of.scale)
			var box: StyleBoxFlat = StyleBoxFlat.new()
			box.bg_color = Color(0, 0, 0, 0)
			box.set_corner_radius_all(int(size.x * 0.07))
			box.shadow_color = Color(0, 0, 0, 0.28 * card)
			box.shadow_size = int(size.x * 0.05)
			box.shadow_offset = Vector2(0, size.x * 0.02)
			draw_style_box(box, Rect2(at, card_of.size * card_of.scale))

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
