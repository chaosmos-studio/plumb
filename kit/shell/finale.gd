class_name Finale
extends Control

## The ending, once every level is solved: the game's own mechanic in miniature, playing out alone on its
## plain ground, then one line for the moment and the way back. Kept minimal on purpose, so everything else
## (the note, rating, the other games, the Supporter pack) waits in small buttons under it.
##
## The kit expects from the game GameCredits.ENDING (its line, like "Every marble home."), NOTE, SIGNED,
## SUPPORT_LINE_PLAY, SUPPORT_LINE_WEB and THANKS_LINE, and optionally a Control at MOTIF with `play()`:
## its mechanic in miniature, which the ending plays once. Without one, the app icon stands in.

const LAYER: int = 65
const MOTIF: String = "res://scenes/shell/ending_motif.gd"
const MOTIF_SIZE: float = 460.0
## The words come once the motif has played out.
const WORDS_AT: float = 2.6
const WORDS_TIME: float = 0.7

var _words: Control

## Ask before the result is recorded: this solve is the last level still unsolved, wherever it sits.
static func due(level: int) -> bool:
	return Save.best(level) == 0 and Ads.solved() == Pack.count() - 1

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
	# Centred on a tall phone, and scrolling on a short one.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = view
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	scroll.add_child(column)
	var motif: Control = _motif()
	column.add_child(UI.centred(motif))
	var words: VBoxContainer = VBoxContainer.new()
	words.add_theme_constant_override("separation", 12)
	words.modulate.a = 0.0
	_words = words
	column.add_child(words)
	words.add_child(UI.spacer(28))
	words.add_child(UI.caption("Every level solved", 22))
	words.add_child(UI.title(GameCredits.ENDING, 68))
	words.add_child(UI.label("More levels are on the way.", 28, Brand.MUTED))
	words.add_child(UI.spacer(30))
	var back: Button = UI.button("Back to levels", UI.Style.PRIMARY)
	back.custom_minimum_size.x = 460.0
	back.pressed.connect(func() -> void:
		var t: Tween = create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.25)
		await t.finished
		on_done.call()
		RatePrompt.at_end()
		get_parent().queue_free())
	words.add_child(UI.centred(back))
	words.add_child(UI.spacer(18))
	words.add_child(UI.centred(_extras()))
	var show: Tween = create_tween()
	show.tween_property(self, "modulate:a", 1.0, 0.5)
	show.tween_callback(func() -> void:
		if motif.has_method("play"):
			motif.call("play"))
	show.tween_interval(WORDS_AT)
	show.tween_property(words, "modulate:a", 1.0, WORDS_TIME)

func _motif() -> Control:
	if ResourceLoader.exists(MOTIF):
		var motif: Control = (load(MOTIF) as GDScript).new()
		motif.custom_minimum_size = Vector2(MOTIF_SIZE, MOTIF_SIZE)
		return motif
	return UI.app_icon(180)

## Small and side by side, so the ending stays one line and one button.
func _extras() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	row.add_child(UI.action(&"info", "Note", _open_note))
	if RatePrompt.open_to_asking():
		# The lambda is made before its button exists, so it reaches the button through a shared array.
		var made: Array[VBoxContainer] = []
		made.append(UI.action(&"heart", "Rate", func() -> void:
			RatePrompt.rate()
			(made[0].get_child(0) as IconButton).disabled = true))
		row.add_child(made[0])
	row.add_child(UI.action(&"levels", "Games", func() -> void: MoreGames.open(self)))
	if support_button() != "":
		row.add_child(UI.action(&"shop", "Support", _support))
	return row

## The maker's note, the signature and the support line, for whoever wants them.
func _open_note() -> void:
	var sheet: Sheet = Sheet.open(self)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Thank you", 64))
	var note: Label = UI.label(GameCredits.NOTE, 28)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = Sheet.room()
	c.add_child(note)
	c.add_child(UI.title(GameCredits.SIGNED, 40))
	c.add_child(UI.caption(String(GameCredits.TEAM[0]["role"]), 18))
	var line: Label = UI.label(support_line(), 26, Brand.MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = Sheet.room()
	c.add_child(line)
	var offer: String = support_button()
	if offer != "":
		var give: Button = UI.button(offer, UI.Style.PRIMARY)
		give.pressed.connect(func() -> void:
			sheet.close()
			_support())
		c.add_child(give)

func _support() -> void:
	if Supporter.on_play:
		Supporter.open(self)
	else:
		OS.shell_open(GameCredits.SPONSOR)

## Shown at once, words and all: the robots and a second look need no wait.
func skip() -> void:
	modulate.a = 1.0
	_words.modulate.a = 1.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Brand.BG)
