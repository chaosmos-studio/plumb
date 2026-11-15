class_name ChapterCard
extends CanvasLayer

## Never holds up play: the first touch sends it away early and still reaches the game.

const LAYER: int = 45
const FADE: float = 0.3
const HOLD: float = 2.8
const WIDTH: float = 640.0
## Where the card's centre sits, as a share of the screen's height.
const AT: float = 0.3

## Off in the tools that stage and film the game, so no capture shows it.
static var enabled: bool = true

var chapter: int = 0
var _card: PanelContainer
var _leaving: bool = false

static func show_for(host: Node, chapter_index: int) -> void:
	if not enabled:
		return
	var card: ChapterCard = ChapterCard.new()
	card.chapter = chapter_index
	host.add_child(card)

func _ready() -> void:
	layer = LAYER
	var root: Control = Control.new()
	root.theme = UI.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint: Color = ChapterStyle.tint(chapter)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Brand.SURFACE
	style.border_color = tint
	style.border_width_top = 8
	style.set_corner_radius_all(40)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 26
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 26
	style.content_margin_bottom = 30
	style.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	column.add_child(UI.caption("Chapter %d" % Shown.chapter(chapter), 20, tint))
	column.add_child(UI.title(Pack.chapter_name(chapter), 50))
	var line: Label = UI.label(Pack.chapter_line(chapter), 28, Brand.MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = WIDTH - 80.0
	column.add_child(line)
	root.add_child(_card)
	# Anchored rather than measured, since the card is laid out only after this frame.
	_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card.anchor_top = AT
	_card.anchor_bottom = AT
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.offset_left = 0.0
	_card.offset_right = 0.0
	_card.offset_top = 16.0
	_card.offset_bottom = 16.0
	_card.modulate.a = 0.0
	var t: Tween = create_tween()
	t.tween_property(_card, "modulate:a", 1.0, FADE)
	t.parallel().tween_property(_card, "offset_top", 0.0, FADE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_card, "offset_bottom", 0.0, FADE).set_ease(Tween.EASE_OUT)
	t.tween_interval(HOLD)
	t.tween_callback(_leave)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_leave()

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var t: Tween = create_tween()
	t.tween_property(_card, "modulate:a", 0.0, FADE)
	t.tween_callback(queue_free)
