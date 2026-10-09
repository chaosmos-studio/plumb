class_name Finale
extends Control

## The words are the game's (GameCredits.NOTE, SIGNED, SUPPORT_LINE_PLAY, SUPPORT_LINE_WEB and
## THANKS_LINE), so each game can speak for itself.

const LAYER: int = 65
const DRIFTERS: int = 18
const COLUMN_WIDTH: float = 600.0
## Room above and below the words, so scrolled to either end they still clear the screen's edge.
const EDGE: float = 48.0

var _drift: Array[Vector4] = []
var _t: float = 0.0
var _column: Control

## Ask before the result is recorded.
static func due(level: int) -> bool:
	return level + 1 >= Pack.count() and Save.best(level) == 0

## Google Play treats a donation link in an app as a payment outside its billing, so the Play build offers
## the Supporter pack and never GitHub Sponsors.
static func support_line() -> String:
	if Supporter.active():
		return GameCredits.THANKS_LINE
	return GameCredits.SUPPORT_LINE_PLAY if Supporter.on_play else GameCredits.SUPPORT_LINE_WEB

static func support_button() -> String:
	if Supporter.active():
		return ""
	return "Supporter pack" if Supporter.on_play else "Sponsor on GitHub"

static func open(host: Node, on_done: Callable) -> Finale:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = LAYER
	host.add_child(canvas)
	var finale: Finale = Finale.new()
	canvas.add_child(finale)
	finale._build(on_done)
	return finale

## A banner is a native view drawn over the whole game, so the ending hides it as a Sheet does.
func _enter_tree() -> void:
	Ads.cover(true)

func _exit_tree() -> void:
	Ads.cover(false)

func _build(on_done: Callable) -> void:
	# Already in the tree, where anchors alone would keep the zero rect it started with.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	modulate.a = 0.0
	var view: Vector2 = get_viewport_rect().size
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for k: int in range(DRIFTERS):
		_drift.append(Vector4(rng.randf() * view.x, rng.randf() * view.y, rng.randf_range(4.0, 11.0), rng.randf_range(10.0, 26.0)))
	# Centred on a tall phone, and scrolling on a short one, where the note and buttons outgrow the screen.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	_column = column
	column.custom_minimum_size = view
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	column.add_child(UI.spacer(EDGE))
	column.add_child(UI.centred(UI.app_icon(132)))
	column.add_child(UI.spacer(6))
	column.add_child(UI.caption("Every level solved", 22))
	column.add_child(UI.title("Thank you", 88))
	column.add_child(UI.spacer(10))
	var note: Label = UI.label(GameCredits.NOTE, 30)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = minf(COLUMN_WIDTH, view.x - 100.0)
	column.add_child(UI.centred(note))
	column.add_child(UI.spacer(8))
	column.add_child(UI.title(GameCredits.SIGNED, 44))
	column.add_child(UI.caption(String(GameCredits.TEAM[0]["role"]), 18))
	column.add_child(UI.spacer(26))
	var line: Label = UI.label(support_line(), 26, Brand.MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = minf(COLUMN_WIDTH, view.x - 100.0)
	column.add_child(UI.centred(line))
	var offer: String = support_button()
	if offer != "":
		column.add_child(UI.spacer(10))
		var give: Button = UI.button(offer, UI.Style.PRIMARY)
		give.custom_minimum_size.x = 460.0
		give.pressed.connect(func() -> void:
			if Supporter.on_play:
				Supporter.open(self)
			else:
				OS.shell_open(GameCredits.SPONSOR))
		column.add_child(UI.centred(give))
	column.add_child(UI.spacer(4))
	column.add_child(UI.centred(_extras()))
	var back: Button = UI.button("Back to levels", UI.Style.GHOST if offer != "" else UI.Style.PRIMARY)
	back.custom_minimum_size.x = 460.0
	back.pressed.connect(func() -> void:
		var t: Tween = create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.25)
		await t.finished
		on_done.call()
		get_parent().queue_free())
	column.add_child(UI.centred(back))
	column.add_child(UI.spacer(EDGE))
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)

## Side by side, to keep the column short.
func _extras() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	if RatePrompt.open_to_asking():
		var rate: Button = UI.button(RatePrompt.button_text(), UI.Style.SECONDARY)
		rate.custom_minimum_size.x = 300.0
		rate.pressed.connect(func() -> void:
			RatePrompt.rate()
			rate.disabled = true)
		row.add_child(rate)
	var more: Button = UI.button(MoreGames.title(), UI.Style.SECONDARY)
	more.custom_minimum_size.x = 300.0
	more.pressed.connect(func() -> void: MoreGames.open(self))
	row.add_child(more)
	return row

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Brand.BG)
	# The motes fade out before they reach the words.
	var words: Rect2 = _content_rect().grow(40.0)
	for k: int in range(_drift.size()):
		var d: Vector4 = _drift[k]
		var at: Vector2 = Vector2(d.x + sin(_t * 0.4 + k) * 14.0, fposmod(d.y - _t * d.w, size.y + 40.0) - 20.0)
		var clear: float = clampf(maxf(words.position.y - at.y, at.y - words.end.y) / 60.0, 0.0, 1.0)
		if clear <= 0.0:
			continue
		var colour: Color = Brand.ACCENT if k % 3 == 0 else (Brand.GOLD if k % 3 == 1 else Brand.MUTED)
		draw_circle(at, d.z, Color(colour, 0.24 * clear), true, -1.0, true)

## Where the words and buttons are on screen, as scrolled, since the column itself is at least the
## screen's size. The bare spacers between them are left out.
func _content_rect() -> Rect2:
	var box: Rect2 = Rect2()
	for child: Node in _column.get_children():
		var c: Control = child as Control
		if c == null or c.get_class() == "Control" or c.size.y <= 0.0:
			continue
		var r: Rect2 = c.get_global_rect()
		box = r if box.size == Vector2.ZERO else box.merge(r)
	return Rect2(box.position - global_position, box.size)
