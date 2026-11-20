class_name LookChooser
extends Control

## The one-tap choice between the two looks, on the first launch of 2.0 (REVAMP_PLAN.md section 3.3, decision 3): two
## live previews side by side, no words and no default. The chosen card grows to fill the screen and becomes the game.

const SCENE: String = AppLook.CHOOSER_SCENE
## A card's share of the screen's width, and the gap between the two.
const CARD_SHARE: float = 0.455
const GAP: float = 0.03
## The grass along the foot of the screen, as a share of its height, and the cards' middle.
const GRASS: float = 0.2
const CARDS_AT: float = 0.47
## The row of houses stands this far below the horizon, on the grass's top edge.
const HOUSES_SINK: float = 30.0
## The title's top and its width.
const TITLE_TOP: float = 60.0
const TITLE_WIDTH: float = 600.0
const RIM: int = 8
## On a wide screen, a card's height as a share of the screen's.
const WIDE_CARD_HEIGHT: float = 0.66
const WIDE_CARDS_AT: float = 0.42
## The design size each preview is drawn at before it is scaled into its card.
const PREVIEW: Vector2i = Vector2i(720, 1602)
const GROW_TIME: float = 0.5
const BOB: float = 6.0
const BOB_SPEED: float = 1.6

var _cards: Array[Control] = []
var _looks: PackedStringArray = [AppLook.STREET, AppLook.CLASSIC]
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
	get_viewport().size_changed.connect(_layout)
	_layout()
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
		StreetMap.preview = true
		view.add_child((load(StreetMap.SCENE) as PackedScene).instantiate())
		StreetMap.preview = false
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
			_choose(look))
	return frame

func _layout() -> void:
	var size: Vector2 = get_viewport_rect().size
	var w: float = size.x * CARD_SHARE
	var h: float = w * float(PREVIEW.y) / float(PREVIEW.x)
	if StreetLayout.wide(size):
		# On a wide screen the height sets the cards' size, and they stand side by side in the middle.
		h = size.y * WIDE_CARD_HEIGHT
		w = h * float(PREVIEW.x) / float(PREVIEW.y)
	var ground: float = size.y * (1.0 - GRASS)
	_sky.horizon_y = ground - HOUSES_SINK
	_sky.queue_redraw()
	_scene.ground = ground
	_scene.queue_redraw()
	_front.queue_redraw()
	if StreetLayout.wide(size):
		# Wide, the title sits in the sky's top-left corner, clear of the cards.
		_title.place(Vector2(size.x * 0.4, size.y), 24.0, TITLE_WIDTH * 0.75)
	else:
		_title.place(size, float(UI.safe_margins(get_viewport())["top"]) + TITLE_TOP, TITLE_WIDTH)
	_sky.clear_bottom = _title.foot()
	_cast.position = Vector2(size.x * 0.5, size.y * (1.0 - GRASS * 0.42))
	_cast.look_toward(Vector2(size.x * 0.5, 0.0))
	for i: int in range(_cards.size()):
		var card: Control = _cards[i]
		card.size = Vector2(w, h)
		card.position = Vector2(size.x * 0.5 + (float(i) - 0.5) * (w + size.x * GAP) - w * 0.5, _card_top(h))
		card.pivot_offset = card.size * 0.5
		var holder: SubViewportContainer = card.get_child(0)
		holder.scale = Vector2.ONE * (w / float(PREVIEW.x))

func _process(delta: float) -> void:
	_t += delta
	if _chosen:
		return
	for i: int in range(_cards.size()):
		_cards[i].position.y = _card_top(_cards[i].size.y) + sin(_t * BOB_SPEED + i * PI) * BOB

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

func _card_top(h: float) -> float:
	var size: Vector2 = get_viewport_rect().size
	return maxf(10.0, size.y * (WIDE_CARDS_AT if StreetLayout.wide(size) else CARDS_AT) - h * 0.5)

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
	var grow: float = size.x / card.size.x
	var t: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(card, "position", (size - card.size) * 0.5, GROW_TIME)
	t.tween_property(card, "scale", Vector2(grow, grow), GROW_TIME)
	t.tween_property(other, "position:x", other.position.x + (size.x if i == 0 else -size.x), GROW_TIME * 0.8)
	t.chain().tween_callback(func() -> void:
		Save.set_app_look(look)
		if look == AppLook.CLASSIC:
			Appearance.apply(Save.theme)
		AppLook.use(look)
		Screens.go(AppLook.home_scene(look)))


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
