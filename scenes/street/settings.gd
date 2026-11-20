class_name StreetSettings
extends CanvasLayer

## Street's Settings (REVAMP_PLAN.md section 3.1, concept build/review/revamp2/7-settings.png): the cast under a
## bowed arch, and below them a notice board with two tabs, General and Accessibility, each a column of rows with a
## toggle. The board drops like the start card, the tab pill slides, and toggles slide with an overshoot as their tick
## and cross swap with a pop (moment 20). Help, About, Credits, privacy and the reset are one level down, on the kit's
## own sheet, reached from General's last row.
##
## Laid out in the painting's pixels (Codex's 1084 x 2412 composition, build/review/art/d2-settings.png): in portrait
## the arch above the board, on a wide screen the arch on the left and the board on the right, each scaled to fit.

signal closed

enum Tab { GENERAL, ACCESSIBILITY }
enum Row { SOUND, MUSIC, FACES, PETS, TILT, STREET, MORE, MOTION, COLOUR, HAPTICS }

## The composition, in the painting's pixels: the arch and its bow, the bunting under it, the cast's middle line and
## size, the board's corner and width, the tabs, the first row and the step between rows, a row's size and the toggle's
## middle along it.
const FRAME: Vector2 = Vector2(1084.0, 2412.0)
const ARCH_AT: Vector2 = Vector2(120.0, 253.0)
const BOW_AT: Vector2 = Vector2(386.0, 230.0)
const BUNTING: Rect2 = Rect2(264.0, 430.0, 556.0, 96.0)
const CAST_Y: float = 705.0
const CAST_D: float = 176.0
const BOARD_AT: Vector2 = Vector2(62.0, 776.0)
const BOARD_W: float = 960.0
const TABS_AT: Vector2 = Vector2(112.0, 874.0)
const TAB_SIZE: Vector2 = Vector2(410.0, 124.0)
const ROWS_Y: float = 1060.0
const ROW_STEP: float = 178.0
const ROW_SIZE: Vector2 = Vector2(860.0, 154.0)
const TOGGLE_X: float = 714.0
const TOGGLE_W: float = 208.0
const KNOB: float = 74.0
const KNOB_SHIFT: float = 57.0
const LABEL_SIZE: int = 52
const TAB_LABEL_SIZE: int = 54
## The board's foot below its last row.
const BOARD_FOOT: float = 70.0
## The board's drop, and a toggle's slide.
const DROP_TIME: float = 0.45
const SLIDE_TIME: float = 0.28
const DARK: Color = Color("173a43")

var _root: Control
var _backdrop: TextureRect
var _top: _Arch
var _board: _Board
var _cast: StreetCast
var _close: StreetUI.RoundButton
var _tab: Tab = Tab.GENERAL
var _leaving: bool = false

func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)
	_backdrop = TextureRect.new()
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_backdrop)
	_top = _Arch.new()
	_root.add_child(_top)
	_cast = StreetCast.new()
	_cast.scale = Vector2.ONE * CAST_D / StreetCast.body_width()
	_cast.position = Vector2(FRAME.x * 0.5, CAST_Y + CAST_D * 0.5)
	_top.add_child(_cast)
	_board = _Board.new()
	_board.settings = self
	_root.add_child(_board)
	_close = StreetUI.RoundButton.new(StreetUI.RED, &"close", 104.0)
	_close.pressed.connect(close)
	_root.add_child(_close)
	_layout()
	get_viewport().size_changed.connect(_layout)
	# The board drops in from the top with an overshoot, as the start card does.
	if Save.reduce_motion:
		_root.modulate.a = 0.0
		_root.create_tween().tween_property(_root, "modulate:a", 1.0, 0.2)
	else:
		var rest: float = _board.position.y
		_board.position.y = -_board.height() * _board.scale.y
		_board.create_tween().tween_property(_board, "position:y", rest, DROP_TIME).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)

## The rows a tab shows, in order.
func rows_of(tab: Tab) -> Array[Row]:
	var out: Array[Row] = [Row.MOTION, Row.COLOUR, Row.HAPTICS]
	if tab == Tab.ACCESSIBILITY:
		return out
	out = [Row.SOUND, Row.MUSIC, Row.FACES, Row.PETS]
	if PhoneTilt.can_feel():
		out.append(Row.TILT)
	out.append_array([Row.STREET, Row.MORE])
	return out

## The most rows either tab shows, which sets the board's height.
func most_rows() -> int:
	return maxi(rows_of(Tab.GENERAL).size(), rows_of(Tab.ACCESSIBILITY).size())

func _layout() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var wide: bool = StreetLayout.wide(size)
	var safe: Dictionary = UI.safe_margins(get_viewport())
	_backdrop.size = size
	_backdrop.texture = StreetArt.backdrop(StreetArt.SETTINGS_BACKDROP, wide)
	var top: float = float(safe["top"])
	if wide:
		# The arch on the left, the board on the right, each as large as the height allows.
		var board_s: float = (size.y - top - float(safe["bottom"]) - 40.0) / _board.height()
		_board.scale = Vector2.ONE * board_s
		_board.position = Vector2(size.x * 0.72 - BOARD_W * 0.5 * board_s, top + 20.0)
		var arch_s: float = minf(size.x * 0.42 / FRAME.x, size.y * 0.9 / 900.0)
		_top.scale = Vector2.ONE * arch_s
		_top.position = Vector2(size.x * 0.27 - FRAME.x * 0.5 * arch_s, size.y * 0.5 - 520.0 * arch_s)
	else:
		var s: float = minf(size.x / FRAME.x, (size.y - top) / (BOARD_AT.y + _board.height() + 40.0))
		_top.scale = Vector2.ONE * s
		_top.position = Vector2(size.x * 0.5 - FRAME.x * 0.5 * s, top)
		_board.scale = Vector2.ONE * s
		_board.position = _top.position + BOARD_AT * s
	_close.position = Vector2(size.x - float(safe["right"]) - 22.0 - _close.size.x, top + 16.0)

func close() -> void:
	if _leaving:
		return
	_leaving = true
	var t: Tween = _root.create_tween()
	if not Save.reduce_motion:
		t.tween_property(_board, "position:y", -_board.height() * _board.scale.y, 0.28).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_IN)
	t.tween_property(_root, "modulate:a", 0.0, 0.18)
	t.tween_callback(func() -> void:
		closed.emit()
		queue_free())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		close()

func _on_input(event: InputEvent) -> void:
	if _leaving or not (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		return
	var screen: Vector2 = (event as InputEventScreenTouch).position
	var at: Vector2 = _board.get_global_transform_with_canvas().affine_inverse() * screen
	for tab: int in range(2):
		if _board.tab_rect(tab).has_point(at):
			_choose_tab(tab)
			return
	var rows: Array[Row] = rows_of(_tab)
	for i: int in range(rows.size()):
		if _board.row_rect(i).has_point(at):
			_flip(rows[i], i)
			return
	var on_arch: Vector2 = _top.get_global_transform_with_canvas().affine_inverse() * screen
	var member: int = _cast.member_at(screen)
	if member >= 0:
		_cast.poke(member)
	elif Rect2(ARCH_AT, Vector2(844.0, 496.0)).has_point(on_arch):
		_top.poke()

func _choose_tab(tab: int) -> void:
	if tab == _tab:
		return
	_tab = tab as Tab
	Audio.play(&"tap", -6.0)
	Audio.buzz(StreetWobbler.BUZZ_MS, StreetWobbler.BUZZ)
	_board.slide_tab(tab)

## A tap on a row: its toggle flips, or More opens the kit's sheet with the rest.
func _flip(row: Row, i: int) -> void:
	if row == Row.MORE:
		Audio.play(&"tap", -6.0)
		Settings.open(self)
		return
	var on: bool = not value_of(row)
	match row:
		Row.SOUND:
			Save.set_sound(on)
		Row.MUSIC:
			Save.set_music(on)
		Row.FACES:
			Save.set_faces(on)
		Row.PETS:
			Save.set_pets(on)
		Row.TILT:
			Save.set_phone_tilt(on)
		Row.MOTION:
			Save.set_reduce_motion(on)
		Row.COLOUR:
			Save.set_colour_help(on)
		Row.HAPTICS:
			Save.set_haptics(on)
		Row.STREET:
			# Classic takes over at once, on the same progress (REVAMP_PLAN.md section 3.3).
			Save.set_app_look(AppLook.CLASSIC)
			Appearance.apply(Save.theme)
			AppLook.use(Save.app_look)
			Screens.go(AppLook.home_scene(Save.app_look))
			return
	Audio.play(&"pop", -6.0, 1.2 if on else 0.9)
	Audio.buzz(StreetWobbler.BUZZ_MS, StreetWobbler.BUZZ)
	_board.flip(i)

## A row's toggle: on or off.
func value_of(row: Row) -> bool:
	match row:
		Row.SOUND:
			return Save.sound_on
		Row.MUSIC:
			return Save.music_on
		Row.FACES:
			return Save.faces
		Row.PETS:
			return Save.pets
		Row.TILT:
			return Save.phone_tilt
		Row.STREET:
			return Save.app_look == AppLook.STREET
		Row.MOTION:
			return Save.reduce_motion
		Row.COLOUR:
			return Save.colour_help
		Row.HAPTICS:
			return Save.haptics_on
	return false

static func label_of(row: Row) -> String:
	return ["Sound", "Music", "Faces", "Pets", "Tilt your phone", "Street look", "More", "Reduce motion",
		"Colour help", "Haptic feedback"][row]


## The arch over the cast: its bow and the bunting under it. A tap swings the bow.
class _Arch extends Node2D:
	var _spring: Jiggle = Jiggle.new()

	func poke() -> void:
		Audio.play(&"boing", StreetWobbler.VOICE_DB, randf_range(0.95, 1.15))
		if not Save.reduce_motion:
			_spring.kick(1.4)

	func _process(delta: float) -> void:
		_spring.step(delta)
		queue_redraw()

	func _draw() -> void:
		var px: float = 1.0 / StreetArt.DESIGN_PER_PIXEL
		StreetArt.draw_at(self, "settings_arch", StreetSettings.ARCH_AT, px)
		var bunting_k: float = StreetSettings.BUNTING.size.x / (StreetArt.size("bunting").x / StreetArt.DESIGN_PER_PIXEL)
		StreetArt.draw_at(self, "bunting", StreetSettings.BUNTING.position, bunting_k * px)
		var bow: Vector2 = StreetSettings.BOW_AT + Vector2(156.0, 78.0)
		draw_set_transform(bow, _spring.tilt() * 2.0, _spring.squash())
		StreetArt.draw_at(self, "settings_bow", Vector2(-156.0, -78.0), px)
		draw_set_transform(Vector2.ZERO)


## The notice board: its tabs and the current tab's rows, in the painting's pixels from the board's corner.
class _Board extends Node2D:
	var settings: StreetSettings
	## The selected tab pill's place, 0 for General and 1 for Accessibility, sliding between.
	var _tab_at: float = 0.0
	## Each row's knob, 0 off to 1 on, sliding with an overshoot.
	var _knobs: PackedFloat32Array = PackedFloat32Array()
	var _pops: PackedFloat32Array = PackedFloat32Array()
	var _t: float = 0.0

	func _ready() -> void:
		_sync()

	## The board's height in its pixels, for the most rows a tab shows.
	func height() -> float:
		return StreetSettings.ROWS_Y - StreetSettings.BOARD_AT.y + float(settings.most_rows() - 1) \
			* StreetSettings.ROW_STEP + StreetSettings.ROW_SIZE.y + StreetSettings.BOARD_FOOT

	func _sync() -> void:
		var rows: Array[StreetSettings.Row] = settings.rows_of(settings._tab)
		_knobs.resize(rows.size())
		_pops.resize(rows.size())
		for i: int in range(rows.size()):
			_knobs[i] = 1.0 if settings.value_of(rows[i]) else 0.0
			_pops[i] = 0.0
		queue_redraw()

	func tab_rect(tab: int) -> Rect2:
		var track: Vector2 = StreetSettings.TABS_AT - StreetSettings.BOARD_AT
		return Rect2(track + Vector2(10.0 + float(tab) * 430.0, 11.0), StreetSettings.TAB_SIZE)

	func row_rect(i: int) -> Rect2:
		return Rect2(Vector2(StreetSettings.TABS_AT.x - StreetSettings.BOARD_AT.x, StreetSettings.ROWS_Y
			- StreetSettings.BOARD_AT.y + float(i) * StreetSettings.ROW_STEP), StreetSettings.ROW_SIZE)

	## The tab pill slides to `tab`, and its rows come in.
	func slide_tab(tab: int) -> void:
		_sync()
		if Save.reduce_motion:
			_tab_at = float(tab)
			queue_redraw()
			return
		var slide: Callable = func(v: float) -> void:
			_tab_at = v
			queue_redraw()
		create_tween().tween_method(slide, _tab_at, float(tab), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## Row `i`'s toggle slides to its new place with an overshoot, and its tick and cross swap with a pop.
	func flip(i: int) -> void:
		var rows: Array[StreetSettings.Row] = settings.rows_of(settings._tab)
		var to: float = 1.0 if settings.value_of(rows[i]) else 0.0
		if Save.reduce_motion:
			_knobs[i] = to
			queue_redraw()
			return
		_pops[i] = 1.0
		var slide: Callable = func(v: float) -> void:
			_knobs[i] = v
			queue_redraw()
		create_tween().tween_method(slide, _knobs[i], to, StreetSettings.SLIDE_TIME).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_t += delta
		var any: bool = false
		for i: int in range(_pops.size()):
			if _pops[i] > 0.0:
				_pops[i] = maxf(_pops[i] - delta * 4.0, 0.0)
				any = true
		if any:
			queue_redraw()

	func _draw() -> void:
		var px: float = 1.0 / StreetArt.DESIGN_PER_PIXEL
		StreetArt.draw_nine(self, "settings_panel", Rect2(Vector2.ZERO, Vector2(StreetSettings.BOARD_W, height())), px)
		var track: Vector2 = StreetSettings.TABS_AT - StreetSettings.BOARD_AT
		StreetArt.draw_nine(self, "settings_tab_track", Rect2(track, Vector2(860.0, 148.0)), px)
		var pill: Rect2 = tab_rect(0)
		pill.position.x += _tab_at * 430.0
		StreetArt.draw_nine(self, "settings_tab_selected", pill, px)
		var font: Font = StreetArt.font()
		for tab: int in range(2):
			var r: Rect2 = tab_rect(tab)
			var lit: float = 1.0 - absf(_tab_at - float(tab))
			var ink: Color = StreetSettings.DARK.lerp(Color.WHITE, clampf(lit, 0.0, 1.0))
			draw_string(font, Vector2(r.position.x, r.get_center().y + StreetSettings.TAB_LABEL_SIZE * 0.36),
				["General", "Accessibility"][tab], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, StreetSettings.TAB_LABEL_SIZE,
				ink)
		var rows: Array[StreetSettings.Row] = settings.rows_of(settings._tab)
		for i: int in range(rows.size()):
			var r: Rect2 = row_rect(i)
			StreetArt.draw_nine(self, "settings_row", r, px)
			var row: StreetSettings.Row = rows[i]
			draw_string(font, Vector2(r.position.x + 44.0, r.get_center().y + StreetSettings.LABEL_SIZE * 0.36),
				StreetSettings.label_of(row), HORIZONTAL_ALIGNMENT_LEFT, -1, StreetSettings.LABEL_SIZE,
				StreetSettings.DARK)
			var c: Vector2 = Vector2(r.position.x + StreetSettings.TOGGLE_X, r.get_center().y)
			if row == StreetSettings.Row.MORE:
				StreetUI.gloss_circle(self, c + Vector2(40.0, 0.0), 44.0, StreetUI.TEAL)
				StreetUI.glyph(self, &"play", c + Vector2(44.0, 0.0), 54.0)
				continue
			if row == StreetSettings.Row.COLOUR:
				_colour_sample(c + Vector2(-210.0, 0.0))
			_toggle(c, _knobs[i], _pops[i])

	## A toggle at `c`, its knob `v` of the way from off to on, its icon popping by `pop`.
	func _toggle(c: Vector2, v: float, pop: float) -> void:
		var px: float = 1.0 / StreetArt.DESIGN_PER_PIXEL
		var k: float = StreetSettings.TOGGLE_W / 220.0 * px
		var on: bool = v >= 0.5
		var track: String = "toggle_on" if on else "toggle_off"
		StreetArt.draw(self, track, c, k)
		var knob: Vector2 = c + Vector2(lerpf(-StreetSettings.KNOB_SHIFT, StreetSettings.KNOB_SHIFT, v), 0.0)
		StreetArt.draw(self, "toggle_thumb", knob, StreetSettings.KNOB / 88.0 * px)
		var icon: String = "icon_tick" if on else "icon_close"
		var grow: float = 1.0 + 0.35 * sin(pop * PI)
		StreetArt.draw(self, icon, knob, 48.0 * grow / StreetArt.size(icon).x,
			Color("559e21") if on else Color("ed554e"))

	## Colour help's little picture: a red marble with its triangle and a teal hole with its square.
	func _colour_sample(c: Vector2) -> void:
		var marble: Vector2 = c + Vector2(-62.0, 0.0)
		StreetArt.draw(self, "marble_red", marble, 92.0 / StreetArt.size("marble_red").x)
		ColourHelp.draw(self, 0, marble + Vector2(0.0, 18.0), 34.0, Palette.marble(0).darkened(0.55))
		var hole: Vector2 = c + Vector2(40.0, 0.0)
		draw_circle(hole, 46.0, Palette.marble(1), true, -1.0, true)
		draw_circle(hole, 32.0, Palette.HOLE, true, -1.0, true)
		ColourHelp.draw(self, 1, hole, 30.0)
