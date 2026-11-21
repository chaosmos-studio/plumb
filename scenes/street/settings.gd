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

## MORE is not a tab but the board's second page, which More opens: How to play, About, Credits, Privacy choices
## and Reset, in Street's own rows (M6 step 2), where they used to be the kit's Classic sheet.
enum Tab { GENERAL, ACCESSIBILITY, MORE }
enum Row { SOUND, MUSIC, FACES, PETS, TILT, STREET, MORE, MOTION, COLOUR, HAPTICS, HELP, ABOUT, CREDITS, PRIVACY, RESET }

## The composition, in the painting's pixels: the arch and its bow, the bunting under it, the cast's middle line and
## size, the board's corner and width, the tabs, the first row and the step between rows, a row's size and the toggle's
## middle along it.
const FRAME: Vector2 = Vector2(1084.0, 2412.0)
const ARCH_AT: Vector2 = Vector2(120.0, 253.0)
const BOW_AT: Vector2 = Vector2(386.0, 230.0)
const BUNTING: Rect2 = Rect2(264.0, 430.0, 556.0, 96.0)
## The cast stands large on the path under the arch, as in the concept, its feet at the arch's foot.
const CAST_D: float = 190.0
const ARCH_FOOT: float = 880.0
const CAST_Y: float = ARCH_FOOT - CAST_D - 6.0
const BOARD_AT: Vector2 = Vector2(62.0, 776.0)
const BOARD_W: float = 960.0
const TABS_AT: Vector2 = Vector2(112.0, 874.0)
## The tabs, about 1.4 times the painting's, as chunky as the concept's, and the track holding them.
const TAB_SIZE: Vector2 = Vector2(410.0, 174.0)
const TRACK_SIZE: Vector2 = Vector2(860.0, 206.0)
const ROWS_Y: float = 1119.0
const ROW_STEP: float = 178.0
## Rows span the board's width, as the concept's do: the painted row's pill keeps its 62 px of soft shadow each side.
const ROW_SIZE: Vector2 = Vector2(960.0, 154.0)
const ROW_X: float = 0.0
## The row art's pill, inside its 860 px piece (the rest is its soft shadow): every label and toggle stays inside it.
const PILL_LEFT: float = 62.0
const PILL_RIGHT: float = ROW_SIZE.x - 63.0
const LABEL_X: float = PILL_LEFT + 40.0
const TOGGLE_W: float = 208.0
const TOGGLE_X: float = PILL_RIGHT - 34.0 - TOGGLE_W * 0.5
## The smallest a label shrinks to, to fit its pill.
const LABEL_MIN: int = 40
## Colour help's little picture, its size and its middle's distance left of the toggle's.
const SAMPLE_SCALE: float = 0.8
const SAMPLE_X: float = 180.0
## The picture's width at full size (a marble and a hole, from 108 left of its middle to 86 right), and the smallest it
## shrinks to beside long words.
const SAMPLE_W: float = 194.0
const SAMPLE_MIN: float = 0.75
const KNOB: float = 74.0
const KNOB_SHIFT: float = 57.0
const LABEL_SIZE: int = 60
const TAB_LABEL_SIZE: int = 80
## The board's foot below its last row.
const BOARD_FOOT: float = 70.0
## The board fills the screen as the concept does (build/review/revamp2/7-settings.png): 94% of a portrait screen's
## width, from under the cast to near the foot, and the same height on every page. Its rows share the room: a short page
## gets taller rows, up to ROW_GROW times the painting's, and centres them if they still do not fill it.
const PANEL_WIDTH: float = 0.94
const PANEL_TOP: float = 0.315
const PANEL_FOOT: float = 0.035
const ROW_GROW: float = 2.0
## Every toggle's size against the painting's.
const TOGGLE_GROW: float = 1.35
## A row's share of its step, the rest being the gap to the next.
const ROW_FILL: float = 0.88
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
var _reset_armed: bool = false
var _reset_done: bool = false

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
	# Settings covers the street, so the banner steps away until it closes and never sits over a row.
	Ads.cover(true)
	# The board drops in from the top with an overshoot, as the start card does.
	if Save.reduce_motion:
		_root.modulate.a = 0.0
		_root.create_tween().tween_property(_root, "modulate:a", 1.0, 0.2)
	else:
		var rest: float = _board.position.y
		_board.position.y = -_board.height() * _board.scale.y
		_board.create_tween().tween_property(_board, "position:y", rest, DROP_TIME).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)

func _exit_tree() -> void:
	Ads.cover(false)
	StreetArt.release(StreetArt.ROOMS)

## The rows a tab shows, in order.
func rows_of(tab: Tab) -> Array[Row]:
	if tab == Tab.MORE:
		var more: Array[Row] = [Row.HELP, Row.ABOUT, Row.CREDITS]
		if Ads.privacy_options_required():
			more.append(Row.PRIVACY)
		more.append_array([Row.STREET, Row.RESET])
		return more
	var out: Array[Row] = [Row.MOTION, Row.COLOUR, Row.HAPTICS]
	if tab == Tab.ACCESSIBILITY:
		return out
	out = [Row.SOUND, Row.MUSIC, Row.FACES, Row.PETS]
	if PhoneTilt.can_feel():
		out.append(Row.TILT)
	out.append(Row.MORE)
	return out

## The most rows any page shows, which sets the board's height.
func most_rows() -> int:
	return maxi(maxi(rows_of(Tab.GENERAL).size(), rows_of(Tab.ACCESSIBILITY).size()), rows_of(Tab.MORE).size())

func _layout() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var wide: bool = StreetLayout.wide(size)
	var safe: Dictionary = UI.safe_margins(get_viewport())
	_backdrop.size = size
	_backdrop.texture = StreetArt.backdrop(StreetArt.SETTINGS_BACKDROP, wide)
	var top: float = float(safe["top"])
	var foot: float = size.y - float(safe["bottom"]) - size.y * PANEL_FOOT
	# The arch's part of the painting, from the bow's top to the cast's feet, in its own pixels.
	var arch_h: float = ARCH_FOOT - BOW_AT.y + 10.0
	if wide:
		# The board on the right, from near the top to near the foot, clear of the close button; the arch and the cast on
		# the left, as large as their half allows.
		var right: float = size.x - float(safe["right"]) - _close.size.x - 44.0
		var panel_top: float = top + size.y * 0.04
		var board_s: float = minf((right - size.x * 0.47) / BOARD_W, (foot - panel_top) / _board.least())
		_board.scale = Vector2.ONE * board_s
		_board.panel_h = (foot - panel_top) / board_s
		_board.position = Vector2(right - BOARD_W * board_s, panel_top)
		var arch_s: float = minf(size.x * 0.44 / 844.0, (size.y - top) * 0.86 / arch_h)
		_top.scale = Vector2.ONE * arch_s
		_top.position = Vector2(size.x * 0.24 - FRAME.x * 0.5 * arch_s,
			top + (size.y - top) * 0.5 - (BOW_AT.y + arch_h * 0.5) * arch_s)
	else:
		var panel_top: float = maxf(top + size.y * PANEL_TOP, top + 300.0)
		var board_s: float = minf(size.x * PANEL_WIDTH / BOARD_W, (foot - panel_top) / _board.least())
		var panel_w: float = BOARD_W * board_s
		_board.scale = Vector2.ONE * board_s
		_board.panel_h = (foot - panel_top) / board_s
		_board.position = Vector2((size.x - panel_w) * 0.5, panel_top)
		# The arch above, its cast standing on the path just over the board.
		var arch_s: float = minf(size.x * 0.84 / 844.0, (panel_top - top + 12.0) / arch_h)
		_top.scale = Vector2.ONE * arch_s
		_top.position = Vector2(size.x * 0.5 - FRAME.x * 0.5 * arch_s, panel_top + 12.0 - ARCH_FOOT * arch_s)
	_board.queue_redraw()
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
	# On More's page the track is one back button, to General.
	if _tab == Tab.MORE:
		if _board.track_rect().has_point(at):
			_choose_tab(Tab.GENERAL)
			return
	else:
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
	_reset_armed = false
	Audio.play(&"tap", -6.0)
	Audio.buzz(StreetWobbler.BUZZ_MS, StreetWobbler.BUZZ)
	_board.slide_tab(tab)

## A tap on a row: its toggle flips, More turns to its page, and More's rows open what they name.
func _flip(row: Row, i: int) -> void:
	match row:
		Row.MORE:
			_choose_tab(Tab.MORE)
			return
		Row.HELP:
			Audio.play(&"tap", -6.0)
			StreetPlay.show_how_to_play()
			return
		Row.ABOUT:
			Audio.play(&"tap", -6.0)
			About.open(self)
			return
		Row.CREDITS:
			Audio.play(&"tap", -6.0)
			Credits.open(self)
			return
		Row.PRIVACY:
			Audio.play(&"tap", -6.0)
			Ads.open_privacy_options()
			return
		Row.RESET:
			# Twice, as the kit's sheet asked: the first tap says what a second one does.
			Audio.play(&"tap", -6.0)
			if _reset_armed:
				Save.reset()
				_reset_done = true
			_reset_armed = true
			_board.queue_redraw()
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
		"Colour help", "Haptic feedback", "How to play", "About", "Credits", "Privacy choices", "Reset progress"][row]

## Reset's words: what it is, then what a second tap does, then done.
func reset_label() -> String:
	if _reset_done:
		return "Progress reset"
	return "Tap again to reset" if _reset_armed else "Reset progress"

## A row's parts for a row `h` board pixels tall, grown from the painting's 154 px row: the label's left and size,
## the toggle's width, middle and knob, Colour help's picture's place and scale, and the chevron's middle and size.
static func row_parts(h: float) -> Dictionary:
	var k: float = clampf(h / ROW_SIZE.y, 1.0, ROW_GROW)
	# One toggle size on every page, as large as the shortest row allows, so General's match Accessibility's.
	var kt: float = TOGGLE_GROW
	var toggle_w: float = TOGGLE_W * kt
	return {"label_x": LABEL_X + 14.0 * (k - 1.0), "label_size": int(LABEL_SIZE * minf(k, 1.5)), "toggle_w": toggle_w,
		"toggle_x": PILL_RIGHT - 34.0 - toggle_w * 0.5, "knob": KNOB * kt, "knob_shift": KNOB_SHIFT * kt,
		"sample_x": SAMPLE_X * kt, "sample_scale": SAMPLE_SCALE * kt, "chevron_r": 44.0 * kt,
		"chevron_x": PILL_RIGHT - 34.0 - 44.0 * kt}

## The room a row's words have, from the label's left to whatever sits at their right.
static func label_room(row: Row, h: float) -> float:
	var p: Dictionary = row_parts(h)
	var right: float = float(p["toggle_x"]) - float(p["toggle_w"]) * 0.5 - 24.0
	if row == Row.COLOUR:
		# Colour help's picture follows its words, as small as SAMPLE_MIN when the row is tight.
		right -= SAMPLE_W * SAMPLE_MIN + 20.0
	elif opens(row):
		right = float(p["chevron_x"]) - float(p["chevron_r"]) - 24.0
	return right - float(p["label_x"])

## Whether a row opens something rather than flipping a toggle.
static func opens(row: Row) -> bool:
	return row in [Row.MORE, Row.HELP, Row.ABOUT, Row.CREDITS, Row.PRIVACY, Row.RESET]

## The largest size up to `size` at which `text` fits `width`, never below LABEL_MIN.
static func fitted(font: Font, text: String, width: float, size: int) -> int:
	var s: int = size
	while s > LABEL_MIN and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		s -= 2
	return s


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
	## The rows the panel is drawn tall enough for, easing to the current tab's count as tabs change.
	var _rows_drawn: float = 0.0
	## The board's height in its own pixels, which the screen sets (StreetSettings._layout).
	var panel_h: float = 0.0

	func _ready() -> void:
		_rows_drawn = float(settings.rows_of(settings._tab).size())
		_sync()

	## The board's height in its pixels for `rows` rows, by default the most rows a tab shows, which sets its scale.
	## The board's height in its own pixels: the room the screen gives it (StreetSettings._layout), the same on every
	## page, and at least what its longest page needs at the painting's row size.
	func height(_rows: float = -1.0) -> float:
		return maxf(panel_h, least())

	## The least height that holds the longest page at the painting's row size.
	func least() -> float:
		return StreetSettings.ROWS_Y - StreetSettings.BOARD_AT.y + float(settings.most_rows()) * StreetSettings.ROW_STEP \
			+ StreetSettings.BOARD_FOOT

	## The rows' step on the current page: the room shared out, never more than ROW_GROW times the painting's.
	func step() -> float:
		var n: float = maxf(float(settings.rows_of(settings._tab).size()), 1.0)
		var room: float = height() - (StreetSettings.ROWS_Y - StreetSettings.BOARD_AT.y) - StreetSettings.BOARD_FOOT
		return minf(room / n, StreetSettings.ROW_STEP * StreetSettings.ROW_GROW)

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
		return Rect2(track + Vector2(10.0 + float(tab) * 430.0, 16.0), StreetSettings.TAB_SIZE)

	## The whole tab track, which on More's page is its Back.
	func track_rect() -> Rect2:
		return Rect2(StreetSettings.TABS_AT - StreetSettings.BOARD_AT, StreetSettings.TRACK_SIZE)

	func row_rect(i: int) -> Rect2:
		var s: float = step()
		# Under the tabs, a short page's rows growing to fill the board rather than floating in its middle.
		var y: float = StreetSettings.ROWS_Y - StreetSettings.BOARD_AT.y + float(i) * s
		var h: float = maxf(s * StreetSettings.ROW_FILL, StreetSettings.ROW_SIZE.y * 0.9)
		return Rect2(Vector2(StreetSettings.ROW_X, y), Vector2(StreetSettings.ROW_SIZE.x, h))

	## The tab pill slides to `tab`, its rows come in, and the board grows or shrinks to hold them.
	func slide_tab(tab: int) -> void:
		_sync()
		var rows: float = float(settings.rows_of(tab as StreetSettings.Tab).size())
		# More's page has no pill of its own: the pill rests on General, where Back returns.
		var pill_to: float = 0.0 if tab == StreetSettings.Tab.MORE else float(tab)
		if Save.reduce_motion:
			_tab_at = pill_to
			_rows_drawn = rows
			queue_redraw()
			return
		var slide: Callable = func(v: float) -> void:
			_tab_at = v
			queue_redraw()
		create_tween().tween_method(slide, _tab_at, pill_to, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var grow: Callable = func(v: float) -> void:
			_rows_drawn = v
			queue_redraw()
		create_tween().tween_method(grow, _rows_drawn, rows, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
		StreetArt.draw_nine(self, "settings_panel", Rect2(Vector2.ZERO, Vector2(StreetSettings.BOARD_W,
			height(_rows_drawn))), px)
		var track: Vector2 = StreetSettings.TABS_AT - StreetSettings.BOARD_AT
		StreetArt.draw_nine(self, "settings_tab_track", Rect2(track, StreetSettings.TRACK_SIZE), px)
		var font: Font = StreetArt.font()
		if settings._tab == StreetSettings.Tab.MORE:
			# More's page: the whole track is Back, its arrow in the pill and the page's name beside it.
			var back: Rect2 = tab_rect(0)
			back.size.x = 150.0
			StreetArt.draw_nine(self, "settings_tab_selected", back, px)
			StreetUI.glyph(self, &"undo", back.get_center(), 70.0)
			var title: Rect2 = Rect2(back.end.x + 20.0, back.position.y, 860.0 - back.size.x - 60.0, back.size.y)
			draw_string(font, Vector2(title.position.x, title.get_center().y + StreetSettings.TAB_LABEL_SIZE * 0.36),
				"More", HORIZONTAL_ALIGNMENT_CENTER, title.size.x, StreetSettings.TAB_LABEL_SIZE, StreetSettings.DARK)
		else:
			var pill: Rect2 = tab_rect(0)
			pill.position.x += _tab_at * 430.0
			StreetArt.draw_nine(self, "settings_tab_selected", pill, px)
			for tab: int in range(2):
				var r: Rect2 = tab_rect(tab)
				var lit: float = 1.0 - absf(_tab_at - float(tab))
				var ink: Color = StreetSettings.DARK.lerp(Color.WHITE, clampf(lit, 0.0, 1.0))
				var words: String = ["General", "Accessibility"][tab]
				var size: int = StreetSettings.fitted(font, words, r.size.x - 40.0, StreetSettings.TAB_LABEL_SIZE)
				draw_string(font, Vector2(r.position.x, r.get_center().y + size * 0.36), words,
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, ink)
		var rows: Array[StreetSettings.Row] = settings.rows_of(settings._tab)
		for i: int in range(rows.size()):
			var r: Rect2 = row_rect(i)
			StreetArt.draw_nine(self, "settings_row", r, px)
			var row: StreetSettings.Row = rows[i]
			# Everything in a row grows with it (row_parts), and the label fills the pill up to what sits at its right: a
			# toggle, Colour help's picture, or a chevron (label_room).
			var p: Dictionary = StreetSettings.row_parts(r.size.y)
			var c: Vector2 = Vector2(r.position.x + float(p["toggle_x"]), r.get_center().y)
			var words: String = settings.reset_label() if row == StreetSettings.Row.RESET else StreetSettings.label_of(row)
			var left: float = r.position.x + float(p["label_x"])
			var size: int = StreetSettings.fitted(font, words, StreetSettings.label_room(row, r.size.y), p["label_size"])
			var ink: Color = StreetSettings.DARK
			if row == StreetSettings.Row.RESET and settings._reset_armed and not settings._reset_done:
				ink = Color("c0392b")
			draw_string(font, Vector2(left, r.get_center().y + size * 0.36), words, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				ink)
			if StreetSettings.opens(row):
				if row != StreetSettings.Row.RESET or not settings._reset_done:
					var chevron_r: float = p["chevron_r"]
					var chevron: Vector2 = Vector2(r.position.x + float(p["chevron_x"]), r.get_center().y)
					StreetUI.gloss_circle(self, chevron, chevron_r, StreetUI.RED if row == StreetSettings.Row.RESET \
						else StreetUI.TEAL)
					StreetUI.glyph(self, &"play", chevron + Vector2(chevron_r * 0.09, 0.0), chevron_r * 1.23)
				continue
			if row == StreetSettings.Row.COLOUR:
				# In the middle of the room between the words and the toggle, as large as that room allows.
				var from: float = left + font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 20.0
				var to: float = c.x - float(p["toggle_w"]) * 0.5 - 24.0
				var k: float = clampf((to - from) / StreetSettings.SAMPLE_W, StreetSettings.SAMPLE_MIN, p["sample_scale"])
				var mid: float = (from + to) * 0.5 + (108.0 - 97.0) * k
				_colour_sample(Vector2(mid, c.y), k)
			_toggle(c, _knobs[i], _pops[i], p)

	## A toggle at `c`, its knob `v` of the way from off to on, its icon popping by `pop`, sized for its row (`p`).
	func _toggle(c: Vector2, v: float, pop: float, p: Dictionary) -> void:
		var px: float = 1.0 / StreetArt.DESIGN_PER_PIXEL
		var w: float = p["toggle_w"]
		var knob_d: float = p["knob"]
		var shift: float = p["knob_shift"]
		var k: float = w / 220.0 * px
		var on: bool = v >= 0.5
		var track: String = "toggle_on" if on else "toggle_off"
		StreetArt.draw(self, track, c, k)
		var knob: Vector2 = c + Vector2(lerpf(-shift, shift, v), 0.0)
		StreetArt.draw(self, "toggle_thumb", knob, knob_d / 88.0 * px)
		var icon: String = "icon_tick" if on else "icon_close"
		var grow: float = 1.0 + 0.35 * sin(pop * PI)
		StreetArt.draw(self, icon, knob, knob_d * 0.65 * grow / StreetArt.size(icon).x,
			Color("559e21") if on else Color("ed554e"))

	## Colour help's little picture: a red marble with its triangle and a teal hole with its square.
	func _colour_sample(c: Vector2, scale_by: float) -> void:
		# Drawn a little smaller than full size, so its row's label keeps the others' size.
		draw_set_transform(c, 0.0, Vector2.ONE * scale_by)
		c = Vector2.ZERO
		var marble: Vector2 = c + Vector2(-62.0, 0.0)
		StreetArt.draw(self, "marble_red", marble, 92.0 / StreetArt.size("marble_red").x)
		ColourHelp.draw(self, 0, marble + Vector2(0.0, 18.0), 34.0, Palette.marble(0).darkened(0.55))
		var hole: Vector2 = c + Vector2(40.0, 0.0)
		draw_circle(hole, 46.0, Palette.marble(1), true, -1.0, true)
		draw_circle(hole, 32.0, Palette.HOLE, true, -1.0, true)
		ColourHelp.draw(self, 1, hole, 30.0)
		draw_set_transform(Vector2.ZERO)
