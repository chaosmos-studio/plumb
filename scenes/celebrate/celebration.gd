class_name Celebration
extends RefCounted

## Every win is a small party (MATH.md section 23). On the board: confetti cannons from the tray, the board hops, one
## word of praise pops, and with faces on the marbles come back out in hats and jump. On the sheet: the stars slam in
## with a burst each, the star total counts up and the chapter's bar fills, and Next wiggles. A finished chapter gets
## a moment of its own. On Levels a new level pops open, solved ones shine and the next breathes. Screens change
## through a growing red circle, and Home's Play wiggles while confetti puffs from the seesaw.

## One word of praise, by stars.
const PRAISE: Array = [["Solved", "Done"], ["Great", "Nice", "Smooth"], ["Perfect", "Flawless", "Brilliant"]]
## How long the board's party plays before the sheet.
const BOARD_TIME: float = 1.6
## Overlays the party puts up, which a tap clears at once (hush).
const GROUP: StringName = &"celebration"

## The level a win has just opened, which pops open when the Levels screen next shows it.
static var just_opened: int = -1
static var _installed: bool = false
static var _veil: Flourish.Veil

## Hooks the sheet's stars and the Levels tiles, once.
static func install(tree: SceneTree) -> void:
	if _installed:
		return
	_installed = true
	Result.award = _award
	tree.node_added.connect(_on_node_added)

static func praise(earned: int) -> String:
	var words: Array = PRAISE[clampi(earned, 1, 3) - 1]
	return String(words[randi() % words.size()])

## Clears whatever the party has on screen, for a tap that skips to the sheet.
static func hush(tree: SceneTree) -> void:
	tree.call_group(GROUP, "queue_free")

static func _palette() -> Array[Color]:
	var colours: Array[Color] = []
	colours.assign(Palette.MARBLES)
	colours.append(Brand.GOLD)
	return colours

static func _confetti(count: int, speed: float, size: float) -> Flourish.Burst:
	var burst: Flourish.Burst = Flourish.Burst.new()
	burst.count = count
	burst.speed = speed
	burst.size = size
	burst.colours = _palette()
	return burst

## Calls `call` after `seconds`, unless `host` is gone by then: the wait is a tween of the host's own, so it dies with
## the node it acts on rather than firing into a freed one.
static func _after(host: Node, seconds: float, call: Callable) -> void:
	var t: Tween = host.create_tween()
	t.tween_interval(seconds)
	t.tween_callback(call)

## Haptic ticks as (delay, milliseconds, strength), so a moment builds.
static func _ticks(host: Node, pattern: Array) -> void:
	for step: Vector3 in pattern:
		_after(host, step.x, func() -> void: Audio.buzz(int(step.y), step.z))

## The board's party, after the last marble's drop and chord. Returns how long it plays.
static func board_win(game: Node, view: BoardView, earned: int, word: String) -> float:
	var tray: Rect2 = view.bounds()
	var centre: Vector2 = view.get_global_transform_with_canvas() * tray.get_center()
	for side: float in [-1.0, 1.0]:
		var cannon: Flourish.Burst = _confetti(30, view.cell * 13.0, view.cell * 0.2)
		cannon.aim = -PI * 0.5 - side * 0.42
		cannon.spread = 0.7
		cannon.gravity = view.cell * 16.0
		cannon.drag = 1.4
		cannon.life = 1.7
		cannon.position = Vector2(tray.get_center().x + side * tray.size.x * 0.42, tray.end.y)
		view.add_child(cannon)
	Audio.play(&"cannon", -8.0, 1.0)
	_after(game, 0.07, func() -> void: Audio.play(&"cannon", -10.0, 1.12))
	var hop: Tween = view.create_tween()
	hop.tween_property(view, "position", view.home + Vector2(0, -22), 0.12).set_ease(Tween.EASE_OUT)
	hop.tween_property(view, "position", view.home, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# The word sits over the board, a little above its middle, clear of the level and moves above it.
	_after(game, 0.12, func() -> void:
		var layer: CanvasLayer = _layer(game, 40)
		var pop: Flourish.Word = Flourish.Word.new()
		pop.text = word
		pop.colour = Brand.GOLD
		pop.size = Vector2(640, 140)
		pop.position = centre + Vector2(0, -tray.size.y * 0.12) - pop.size * 0.5
		layer.add_child(pop)
		pop.tree_exited.connect(layer.queue_free)
		Audio.play(&"pop", -10.0)
		Audio.play(&"fanfare", -9.0))
	if Save.faces and earned == 3:
		_after(view, 0.15, view.party)
		_after(view, 0.75, _jump.bind(view))
	_ticks(game, [Vector3(0.0, 18, 0.6), Vector3(0.07, 22, 0.7), Vector3(0.14, 30, 0.9)])
	return BOARD_TIME

static func _layer(host: Node, at: int) -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = at
	layer.add_to_group(GROUP)
	host.add_child(layer)
	return layer

## The marbles back out of their holes jump twice, one after another.
static func _jump(view: BoardView) -> void:
	var k: int = 0
	for child: Node in view.get_children():
		var marble: Marble = child as Marble
		if marble == null or not marble.visible or marble.scale.x < 0.5:
			continue
		var rest: float = marble.position.y
		var t: Tween = marble.create_tween()
		t.tween_interval(k * 0.05)
		for j: int in range(2):
			t.tween_property(marble, "position:y", rest - view.cell * 0.32, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(marble, "position:y", rest, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		k += 1

## The numbers the chapter's dots count through, as the player sees its levels (Shown), then the chapter's own.
static func ticks(chapter: int) -> PackedInt32Array:
	var numbers: PackedInt32Array = PackedInt32Array()
	var first: int = Pack.chapter_first(chapter)
	for i: int in range(first, first + int(Pack.chapters[chapter]["count"])):
		numbers.append(Shown.level(i))
	numbers.append(Shown.chapter(chapter))
	return numbers

## A chapter just finished: a dot for each of its levels lights round a ring while the number in the middle runs
## through their numbers, then lands on the chapter's, under the word CHAPTER, and the cannons fire. A tap calls
## `skip`. Returns how long it plays.
static func chapter_moment(game: Node, chapter: int, skip: Callable) -> float:
	var numbers: PackedInt32Array = ticks(chapter)
	var count: int = numbers.size() - 1
	var stage: _ChapterStage = _ChapterStage.new()
	stage.count = count
	stage.tint = ChapterStyle.tint(chapter)
	stage.number = str(numbers[0])
	stage.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_pressed():
			skip.call())
	var layer: CanvasLayer = _layer(game, 55)
	layer.add_child(stage)
	var fill: float = 0.9
	for k: int in range(count):
		var shown: String = str(numbers[k])
		_after(layer, 0.35 + fill * k / count, func() -> void:
			stage.light(k + 1, shown)
			Audio.play(&"tap", -16.0, 1.0 + 0.04 * k)
			if k % 4 == 3:
				Audio.buzz(8, 0.3 + 0.03 * k))
	var peak: float = 0.35 + fill + 0.05
	var centre: Vector2 = stage.get_viewport_rect().size * 0.5
	var title: String = str(numbers[count])
	_after(layer, peak, func() -> void:
		for side: float in [-1.0, 1.0]:
			var cannon: Flourish.Burst = _confetti(46, 1500.0, 22.0)
			cannon.aim = -PI * 0.5 - side * 0.35
			cannon.spread = 0.6
			cannon.gravity = 1700.0
			cannon.drag = 1.3
			cannon.life = 2.0
			cannon.position = Vector2(centre.x * (1.0 + side * 0.95), centre.y * 2.0)
			stage.add_child(cannon)
		stage.land(title)
		Audio.play(&"cannon", -6.0)
		Audio.play(&"fanfare", -7.0, 0.94)
		_ticks(layer, [Vector3(0.0, 30, 0.8), Vector3(0.12, 40, 1.0)]))
	var length: float = peak + 1.4
	_after(stage, length - 0.3, func() -> void:
		stage.create_tween().tween_property(stage, "modulate:a", 0.0, 0.3))
	_after(layer, length, layer.queue_free)
	return length

class _ChapterStage extends Control:
	const RING: float = 230.0
	var count: int = 20
	var tint: Color = Color.WHITE
	var number: String = "1"
	var _lit: int = 0
	var _num: Label
	var _word: Label

	func _ready() -> void:
		# Under a CanvasLayer there is no parent rect for anchors to follow, so the stage takes the screen's size.
		size = get_viewport_rect().size
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
		_num = _centred(number, 150, tint, Vector2(0, 10))
		_word = _centred("CHAPTER", 30, Brand.MUTED, Vector2(0, -92))
		_word.modulate.a = 0.0

	func _centred(text: String, font_size: int, colour: Color, offset: Vector2) -> Label:
		var label: Label = UI.title(text, font_size, colour)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(420, 220)
		label.position = size * 0.5 - label.size * 0.5 + offset
		label.pivot_offset = label.size * 0.5
		add_child(label)
		return label

	## Dot `lit` lights, and the middle shows that level's number.
	func light(lit: int, shown: String) -> void:
		_lit = lit
		_num.text = shown
		queue_redraw()

	## The count ends on the chapter's own number, with a pop, and the word over it.
	func land(chapter: String) -> void:
		_num.text = chapter
		_num.scale = Vector2(0.6, 0.6)
		create_tween().tween_property(_num, "scale", Vector2(1.25, 1.25), 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(_word, "modulate:a", 1.0, 0.2)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Brand.BG, 0.9))
		var c: Vector2 = size * 0.5
		for k: int in range(count):
			var at: Vector2 = c + Vector2.from_angle(-PI * 0.5 + TAU * k / count) * RING
			if k < _lit:
				draw_circle(at, 15.0, tint, true, -1.0, true)
				draw_circle(at + Vector2(-4, -4), 5.0, Color(1, 1, 1, 0.6), true, -1.0, true)
			else:
				draw_circle(at, 13.0, Color(tint, 0.18), true, -1.0, true)

## The result sheet: a star tally counting up and the chapter's bar filling under the stars, and Next made the
## obvious button.
static func dress_sheet(host: Node, sheet: Sheet, earned: int, level: int, total_before: int, first_solve: bool,
		next_text: String) -> void:
	if not is_instance_valid(sheet):
		return
	var content: VBoxContainer = sheet.content
	var tally: Flourish.Tally = Flourish.Tally.new()
	tally.from = total_before
	tally.to = Save.total_stars()
	content.add_child(tally)
	content.move_child(tally, 3)
	var chapter: int = Pack.chapter_of(level)
	var bar: Flourish.ChapterBar = null
	if chapter >= 0:
		var first: int = Pack.chapter_first(chapter)
		var count: int = int(Pack.chapters[chapter]["count"])
		var solved: int = 0
		for i: int in range(first, first + count):
			solved += 1 if Save.best(i) > 0 else 0
		bar = Flourish.ChapterBar.new()
		bar.tint = ChapterStyle.tint(chapter)
		bar.after = float(solved) / count
		bar.before = float(solved - (1 if first_solve else 0)) / count
		bar.shown = bar.before
		content.add_child(bar)
		content.move_child(bar, 4)
	var next: Button = null
	for b: Node in content.find_children("*", "Button", true, false):
		if (b as Button).text == next_text:
			next = b
	var start: float = 0.35 + earned * 0.24 + 0.25
	if sheet.held:
		await sheet.rising
	if not is_instance_valid(sheet):
		return
	_after(tally, start, tally.count.bind(0.5))
	if bar != null:
		_after(bar, start, bar.fill.bind(0.7))
	if next != null:
		_after(next, start + 0.6, _invite.bind(next))

## A button that wiggles now and then until it is pressed: Next on the sheet, Play on Home.
static func _invite(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.pivot_offset = button.size * 0.5
	var t: Tween = button.create_tween().set_loops()
	t.tween_property(button, "rotation", 0.035, 0.07)
	t.tween_property(button, "rotation", -0.035, 0.14)
	t.tween_property(button, "rotation", 0.0, 0.07)
	t.tween_interval(1.4)
	button.button_down.connect(func() -> void:
		t.kill()
		button.rotation = 0.0)

## The sheet's stars slam in from twice their size with a burst of confetti each, on the notes of the win chord, the
## row giving a little shake (Result.award).
static func _award(_host: Node, icons: Array[StarIcon], earned: int) -> void:
	for k: int in range(earned):
		var star: StarIcon = icons[k]
		var last: bool = k == earned - 1 and earned == 3
		_after(star, 0.35 + k * 0.24, _slam.bind(star, k, last))

static func _slam(star: StarIcon, k: int, last: bool) -> void:
	star.filled = true
	star.pivot_offset = star.size * 0.5
	star.scale = Vector2(2.4, 2.4)
	star.create_tween().tween_property(star, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var row: Control = star.get_parent()
	var rest: float = row.position.x
	var shake: Tween = row.create_tween()
	for j: int in range(3):
		shake.tween_property(row, "position:x", rest + (5.0 if j % 2 == 0 else -5.0), 0.035).set_delay(0.2 if j == 0 else 0.0)
	shake.tween_property(row, "position:x", rest, 0.04)
	var burst: Flourish.Burst = _confetti(22 if last else 12, 520.0, 12.0)
	burst.gravity = 900.0
	burst.life = 1.0
	burst.position = star.size * 0.5
	star.add_child(burst)
	Audio.play(&"star", -6.0, Audio.STAR_NOTES[k])
	Audio.play(&"pop", -14.0, 0.8 + 0.1 * k)
	Audio.buzz(14 + 8 * k, 0.5 + 0.2 * k)

## A Levels tile as it arrives: a shine on solved tiles, a breathing ring round the next, a pop for a new one.
static func _on_node_added(node: Node) -> void:
	var tile: LevelTile = node as LevelTile
	if tile != null:
		tile.ready.connect(func() -> void: _dress_tile(tile), CONNECT_ONE_SHOT)

static func _dress_tile(tile: LevelTile) -> void:
	if tile.locked:
		return
	var glow: Flourish.TileGlow = Flourish.TileGlow.new()
	glow.solved = tile.stars > 0
	glow.next = tile.is_next
	glow.ring_colour = Brand.GOLD
	tile.add_child(glow)
	if tile.level != just_opened:
		return
	just_opened = -1
	_after(tile, 0.45, func() -> void:
		tile.pivot_offset = tile.size * 0.5
		tile.scale = Vector2(0.4, 0.4)
		tile.create_tween().tween_property(tile, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var burst: Flourish.Burst = _confetti(18, 520.0, 12.0)
		burst.gravity = 900.0
		burst.position = tile.size * 0.5
		tile.add_child(burst)
		Audio.play(&"pop", -9.0)
		Audio.buzz(20, 0.7))

## Home: Play wiggles now and then, and every few seconds confetti puffs up from the seesaw.
static func dress_title(title: Node2D) -> void:
	for b: Node in title.find_children("*", "Button", true, false):
		if (b as Button).text == "Play":
			var play: Button = b
			_after(play, 0.8, _invite.bind(play))
	var every: Timer = Timer.new()
	every.wait_time = 5.0
	every.autostart = true
	title.add_child(every)
	every.timeout.connect(func() -> void:
		var burst: Flourish.Burst = _confetti(14, 600.0, 14.0)
		burst.spread = 1.2
		burst.gravity = 900.0
		burst.drag = 1.6
		burst.life = 1.6
		var view: Vector2 = title.get_viewport_rect().size
		burst.position = Vector2(view.x * 0.5, view.y * 0.42)
		title.add_child(burst))
	every.timeout.emit.call_deferred()

## Screens change under a red circle that grows from the middle and shrinks away (Screens.go).
static func cover(screens: CanvasLayer) -> void:
	if _veil == null or not is_instance_valid(_veil):
		_veil = Flourish.Veil.new()
		screens.add_child(_veil)
	_veil.colour = Brand.ACCENT
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var t: Tween = _veil.create_tween()
	t.tween_property(_veil, "cover", 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished

static func uncover() -> void:
	var t: Tween = _veil.create_tween()
	t.tween_property(_veil, "cover", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
