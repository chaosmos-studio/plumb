class_name LookChooser
extends Control

## The choice between the two looks, on the first launch of 2.0 (REVAMP_PLAN.md section 3.3): two live previews side by
## side, Classic on the left and Street on the right, Street picked to begin with, and one Continue (Shravan, 21
## November). A tap on a card picks it, with a gold rim and a tick, and Continue makes it the game: the picked card
## grows to fill the screen.

const SCENE: String = AppLook.CHOOSER_SCENE
## A card's share of the screen's width at most, and the gap between the two.
const CARD_SHARE: float = 0.455
const GAP: float = 0.03
## The grass along the foot of the screen, as a share of its height.
const GRASS: float = 0.2
## The row of houses stands this far below the horizon, on the grass's top edge.
const HOUSES_SINK: float = 30.0
## The title's top and its width.
const TITLE_TOP: float = 60.0
const TITLE_WIDTH: float = 600.0
const RIM: int = 8
## The picked card's rim, and the tick on its corner.
const PICKED_RIM: int = 14
const TICK: float = 46.0
## The picked card stands a little larger and the other a little smaller and dimmer.
const PICKED_SCALE: float = 1.03
const OTHER_SCALE: float = 0.94
const OTHER_TINT: Color = Color(0.9, 0.9, 0.9)
const PICK_TIME: float = 0.22
## Continue, the clear space round it, and what the cast needs above its middle.
const BUTTON: Vector2 = Vector2(400.0, 118.0)
## Narrower beside the cards on a wide screen, where the row has to fit right of the title.
const BUTTON_WIDE: Vector2 = Vector2(320.0, 110.0)
const BUTTON_GAP: float = 46.0
const CAST_CLEAR: float = 100.0
const EDGE: float = 36.0
## On a wide screen, a card's height as a share of the screen's at most, and the cards' middle.
const WIDE_CARD_HEIGHT: float = 0.64
const WIDE_CARDS_AT: float = 0.4
## The design size each preview is drawn at before it is scaled into its card.
const PREVIEW: Vector2i = Vector2i(720, 1602)
const GROW_TIME: float = 0.5
const BOB: float = 6.0
const BOB_SPEED: float = 1.6

## The look a tap has picked: Street until the player picks Classic.
var picked: String = AppLook.STREET
var _cards: Array[Control] = []
var _marks: Array[_Mark] = []
var _looks: PackedStringArray = [AppLook.CLASSIC, AppLook.STREET]
var _continue: _Continue
var _card_y: float = 0.0
var _chosen: bool = false
var _t: float = 0.0
var _sky: StreetSky
var _cast: StreetCast
var _scene: _Scene
var _front: _Front
var _title: StreetTitle
var _wobbler: StreetWobbler

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky = StreetSky.new()
	add_child(_sky)
	var grass: TextureRect = TextureRect.new()
	grass.texture = load("res://assets/street/grass.png")
	grass.stretch_mode = TextureRect.STRETCH_TILE
	grass.anchor_left = 0.0
	grass.anchor_right = 1.0
	grass.anchor_top = 1.0 - GRASS
	grass.anchor_bottom = 1.0
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grass)
	# The street's own world behind the cards: a row of houses and greenery on the grass, the title in the sky, and the
	# map's framing foreground, with the cast waiting in front, looking up at the two cards.
	_scene = _Scene.new()
	add_child(_scene)
	_front = _Front.new()
	add_child(_front)
	_title = StreetTitle.new()
	add_child(_title)
	_cast = StreetCast.new()
	add_child(_cast)
	_wobbler = StreetWobbler.new()
	add_child(_wobbler)
	for i: int in range(2):
		var card: Control = _card(_looks[i])
		add_child(card)
		_cards.append(card)
		var mark: _Mark = _Mark.new()
		add_child(mark)
		_marks.append(mark)
	_continue = _Continue.new()
	_continue.pressed.connect(func() -> void: _choose(picked))
	add_child(_continue)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_pick(false)
	Intro.play(self)

func _card(look: String) -> Control:
	var frame: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(36)
	style.shadow_color = Color(0.1, 0.25, 0.4, 0.22)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	frame.add_theme_stylebox_override("panel", style)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var holder: SubViewportContainer = SubViewportContainer.new()
	holder.stretch = false
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view: SubViewport = SubViewport.new()
	view.size = PREVIEW
	view.handle_input_locally = false
	view.gui_disable_input = true
	holder.add_child(view)
	frame.add_child(holder)
	if look == AppLook.STREET:
		var map: Node = (load(StreetMap.SCENE) as PackedScene).instantiate()
		map.set("preview_only", true)
		view.add_child(map)
	else:
		view.add_child(_ClassicPreview.new())
	# A white rim over the preview, so each card reads as a card against the sky.
	var rim: Panel = Panel.new()
	var rim_style: StyleBoxFlat = StyleBoxFlat.new()
	rim_style.draw_center = false
	rim_style.border_color = Color.WHITE
	rim_style.set_border_width_all(RIM)
	rim_style.set_corner_radius_all(36)
	rim.add_theme_stylebox_override("panel", rim_style)
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(rim)
	frame.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			pick(look))
	return frame

func _layout() -> void:
	var size: Vector2 = get_viewport_rect().size
	var wide: bool = StreetLayout.wide(size)
	var aspect: float = float(PREVIEW.y) / float(PREVIEW.x)
	var ground: float = size.y * (1.0 - GRASS)
	_sky.horizon_y = ground - HOUSES_SINK
	_sky.queue_redraw()
	_scene.ground = ground
	_scene.queue_redraw()
	_front.queue_redraw()
	var top: float = float(UI.safe_margins(get_viewport())["top"])
	if wide:
		# Wide, the title sits in the sky's top-left corner, clear of the cards.
		_title.place(Vector2(size.x * 0.4, size.y), 24.0, TITLE_WIDTH * 0.75)
	else:
		_title.place(size, top + TITLE_TOP, TITLE_WIDTH)
	_sky.clear_bottom = _title.foot()
	_cast.position = Vector2(size.x * 0.5, size.y * (1.0 - GRASS * 0.42))
	_cast.look_toward(Vector2(size.x * 0.5, 0.0))
	# The cards and Continue share the band between the title and the cast. Portrait, Continue stands under the pair.
	# Wide, whichever of two rows gives the larger cards: the pair and Continue side by side right of the title (a
	# turned phone, a wide desktop), or the pair below the title with Continue under it (a squarer screen).
	var band_bottom: float = _cast.position.y - CAST_CLEAR
	var gap: float = size.x * GAP
	var beside: bool = false
	var button: Vector2 = BUTTON
	var w: float = size.x * CARD_SHARE
	var h: float = minf(w * aspect, band_bottom - _title.foot() - 24.0 - BUTTON_GAP - BUTTON.y)
	var pair_left: float = 0.0
	if wide:
		var title_right: float = size.x * 0.2 + TITLE_WIDTH * 0.375 + 16.0
		var row_top: float = top + 24.0
		var under_top: float = _title.foot() + 24.0
		var room: float = size.x - EDGE - title_right
		var h_beside: float = minf(minf(size.y * WIDE_CARD_HEIGHT, band_bottom - row_top),
			(room - gap - BUTTON_GAP - BUTTON_WIDE.x) * 0.5 * aspect)
		var h_under: float = minf(size.y * WIDE_CARD_HEIGHT, band_bottom - under_top - BUTTON_GAP - BUTTON.y)
		beside = h_beside >= h_under
		h = h_beside if beside else h_under
		w = h / aspect
		var pair: float = 2.0 * w + gap
		if beside:
			button = BUTTON_WIDE
			# The pair in the screen's middle where that clears the title and leaves Continue room, else the row in
			# the middle of the room right of the title.
			pair_left = size.x * 0.5 - pair * 0.5
			if pair_left < title_right or size.x * 0.5 + pair * 0.5 + BUTTON_GAP + button.x > size.x - EDGE:
				pair_left = title_right + (room - pair - BUTTON_GAP - button.x) * 0.5
			_card_y = clampf(size.y * WIDE_CARDS_AT - h * 0.5, row_top, band_bottom - h)
		else:
			pair_left = size.x * 0.5 - pair * 0.5
			_card_y = under_top + (band_bottom - under_top - h - BUTTON_GAP - button.y) * 0.5
	else:
		w = h / aspect
		pair_left = size.x * 0.5 - w - gap * 0.5
		var band_top: float = _title.foot() + 24.0
		_card_y = band_top + (band_bottom - band_top - h - BUTTON_GAP - button.y) * 0.5
	for i: int in range(_cards.size()):
		var card: Control = _cards[i]
		card.size = Vector2(w, h)
		card.position = Vector2(pair_left + float(i) * (w + gap), _card_y)
		card.pivot_offset = card.size * 0.5
		var holder: SubViewportContainer = card.get_child(0)
		holder.scale = Vector2.ONE * (w / float(PREVIEW.x))
	_continue.size = button
	_continue.pivot_offset = button * 0.5
	if beside:
		_continue.position = Vector2(pair_left + 2.0 * w + gap + BUTTON_GAP, _card_y + (h - button.y) * 0.5)
	else:
		_continue.position = Vector2(pair_left + w + gap * 0.5 - button.x * 0.5, _card_y + h + BUTTON_GAP)
	_follow()

func _process(delta: float) -> void:
	_t += delta
	if _chosen:
		_follow()
		return
	for i: int in range(_cards.size()):
		var bob: float = 0.0 if Save.reduce_motion else sin(_t * BOB_SPEED + i * PI) * BOB
		_cards[i].position.y = _card_y + bob
	_follow()

## Each card's rim and tick ride with it.
func _follow() -> void:
	for i: int in range(_cards.size()):
		var card: Control = _cards[i]
		var mark: _Mark = _marks[i]
		mark.size = card.size
		mark.position = card.position
		mark.pivot_offset = card.pivot_offset
		mark.scale = card.scale

## Picks a look, as a tap on its card does. Continue makes it the game.
func pick(look: String) -> void:
	if _chosen or look == picked:
		return
	picked = look
	Audio.play(&"tap", -6.0)
	Audio.buzz(10, 0.3)
	_show_pick(true)

func _show_pick(animate: bool) -> void:
	for i: int in range(_cards.size()):
		var on: bool = _looks[i] == picked
		var scale_to: Vector2 = Vector2.ONE * ((PICKED_SCALE if on else OTHER_SCALE) if not Save.reduce_motion else 1.0)
		var tint: Color = Color.WHITE if on else OTHER_TINT
		_marks[i].on = on
		_marks[i].queue_redraw()
		if not animate:
			_cards[i].scale = scale_to
			_cards[i].modulate = tint
			continue
		var t: Tween = _cards[i].create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_cards[i], "scale", scale_to, PICK_TIME)
		t.tween_property(_cards[i], "modulate", tint, PICK_TIME)

## A tap anywhere but the cards: the title, a cast member, the sun or a cloud wobbles.
func _unhandled_input(event: InputEvent) -> void:
	if _chosen or not (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		return
	var at: Vector2 = (event as InputEventScreenTouch).position
	if _title.hit(at):
		_title.poke()
		return
	var member: int = _cast.member_at(at)
	if member >= 0:
		_cast.poke(member)
		return
	if _sky.poke(at):
		Audio.play(&"clink", -12.0, randf_range(1.0, 1.3))

func _choose(look: String) -> void:
	if _chosen:
		return
	_chosen = true
	var i: int = _looks.find(look)
	var card: Control = _cards[i]
	var other: Control = _cards[1 - i]
	var size: Vector2 = get_viewport_rect().size
	Audio.play(&"chord", -8.0)
	Audio.buzz(14, 0.4)
	move_child(card, -1)
	_marks[i].on = false
	_marks[i].queue_redraw()
	var grow: float = maxf(size.x / card.size.x, size.y / card.size.y)
	var t: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(card, "position", (size - card.size) * 0.5, GROW_TIME)
	t.tween_property(card, "scale", Vector2(grow, grow), GROW_TIME)
	t.tween_property(other, "position:x", other.position.x + (size.x if i == 0 else -size.x), GROW_TIME * 0.8)
	t.tween_property(_continue, "modulate:a", 0.0, GROW_TIME * 0.4)
	t.chain().tween_callback(func() -> void:
		Save.set_app_look(look)
		if look == AppLook.CLASSIC:
			Appearance.apply(Save.theme)
		AppLook.use(look)
		Screens.go(AppLook.home_scene(look)))


## The picked card's gold rim and the tick on its corner, drawn over the card (whose own drawing is clipped to it).
class _Mark extends Control:
	var on: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not on:
			return
		var rim: StyleBoxFlat = StyleBoxFlat.new()
		rim.draw_center = false
		rim.border_color = StreetUI.YELLOW
		rim.set_border_width_all(LookChooser.PICKED_RIM)
		rim.set_corner_radius_all(36)
		rim.anti_aliasing = true
		draw_style_box(rim, Rect2(Vector2.ZERO, size))
		# On the middle of its top edge, where neither preview has anything of its own.
		var c: Vector2 = Vector2(size.x * 0.5, 0.0)
		StreetUI.gloss_circle(self, c, LookChooser.TICK * 0.5, Color("4caf3a"))
		StreetArt.draw(self, "icon_tick", c, LookChooser.TICK * 0.62 / StreetArt.size("icon_tick").x)


## Continue: the street's red pill, with the one word.
class _Continue extends Button:
	var _spring: Jiggle = Jiggle.new()

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		button_down.connect(func() -> void:
			Audio.play(&"tap", -10.0)
			if not Save.reduce_motion:
				_spring.kick(1.2))

	func _process(delta: float) -> void:
		_spring.step(delta)
		scale = _spring.squash()
		rotation = _spring.tilt()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		StreetUI.sparks(self, r, 40.0)
		StreetArt.draw_nine(self, "pill_play", r, size.y / StreetArt.size("pill_play").y)
		var font: Font = StreetArt.font()
		var fs: int = int(size.y * 0.4)
		var text: String = "Continue"
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at: Vector2 = Vector2((size.x - w) * 0.5, size.y * 0.46 + fs * 0.34)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, StreetUI.RED.darkened(0.35))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, StreetUI.CREAM)


## A row of the street's houses along the grass's top edge, greenery between them, behind the cards.
class _Scene extends Node2D:
	const HOUSES: PackedStringArray = ["house_red_1", "house_teal_3", "house_yellow_4", "house_purple_1", "house_red_3"]
	const SCALE: float = 0.62
	const GAP: float = 0.92

	var ground: float = 1200.0

	func _draw() -> void:
		var w: float = get_viewport_rect().size.x
		var step: float = StreetArt.size("house_red_1").x * SCALE * GAP
		var count: int = ceili(w / step) + 1
		var left: float = w * 0.5 - float(count - 1) * 0.5 * step
		# Trees behind, between the houses.
		for i: int in range(count + 1):
			StreetArt.draw(self, "tree_%d" % (1 + i % 3), Vector2(left + (float(i) - 0.5) * step, ground - 40.0), 0.9)
		for i: int in range(count):
			var house: String = HOUSES[i % HOUSES.size()]
			var at: Vector2 = Vector2(left + float(i) * step, ground)
			StreetArt.draw(self, "shadow", at, StreetArt.size(house).x * SCALE * 1.05 / StreetArt.size("shadow").x)
			StreetArt.draw(self, house, at, SCALE)
			var d: Vector3 = StreetArt.door(house) * SCALE
			StreetArt.draw(self, "door_" + house.split("_")[1], at + Vector2(d.x, d.y), SCALE)
			StreetArt.draw(self, "flowerbed_%d" % (1 + i % 3), at + Vector2(-step * 0.42, 8.0), 0.7)
			StreetArt.draw(self, "bush_big_%d" % (1 + i % 2), at + Vector2(step * 0.46, 12.0), 0.55)


## The map's framing along the foot: the leafy corners and the grass strip.
class _Front extends Node2D:
	const GRASS_HEIGHT: float = 130.0
	const CORNER_WIDTH: float = 260.0

	func _draw() -> void:
		var size: Vector2 = get_viewport_rect().size
		var grass_k: float = GRASS_HEIGHT / StreetArt.size("grass_front").y
		var step: float = StreetArt.size("grass_front").x * grass_k
		var x: float = 0.0
		while x < size.x:
			StreetArt.draw_at(self, "grass_front", Vector2(x, size.y - GRASS_HEIGHT), grass_k)
			x += step - 1.0
		var corner_k: float = CORNER_WIDTH / StreetArt.size("front_left").x
		var corner: Vector2 = StreetArt.size("front_left") * corner_k
		StreetArt.draw_at(self, "front_left", Vector2(0.0, size.y - corner.y), corner_k)
		StreetArt.draw_at(self, "front_right", Vector2(size.x - corner.x, size.y - corner.y), corner_k)


## Today's title in miniature: the paper, the wordmark and the seesaw of marbles.
class _ClassicPreview extends Node2D:
	func _ready() -> void:
		var bg: ColorRect = ColorRect.new()
		bg.color = Brand.LIGHT["bg"]
		bg.size = Vector2(LookChooser.PREVIEW)
		add_child(bg)
		var word: Label = Label.new()
		word.text = Brand.WORDMARK
		word.add_theme_font_override("font", load(Brand.FONT_DISPLAY))
		word.add_theme_font_size_override("font_size", 200)
		word.add_theme_color_override("font_color", Brand.LIGHT["ink"])
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word.size = Vector2(LookChooser.PREVIEW.x, 260)
		word.position = Vector2(0, 380)
		add_child(word)
		var seesaw: Seesaw = Seesaw.new()
		seesaw.position = Vector2(LookChooser.PREVIEW.x * 0.5, 860)
		add_child(seesaw)
		var play: Control = Control.new()
		play.draw.connect(func() -> void:
			var r: Rect2 = Rect2(LookChooser.PREVIEW.x * 0.5 - 230, 1060, 460, 104)
			var pill: StyleBoxFlat = StyleBoxFlat.new()
			pill.bg_color = Brand.LIGHT["accent"]
			pill.set_corner_radius_all(52)
			play.draw_style_box(pill, r))
		add_child(play)
