class_name Intro
extends CanvasLayer

## The launch flourish, once each time the app starts: the game's icon in the middle of a plain screen,
## much where the phone's own launch screen showed it, spinning twice as it shrinks away while the title
## fades in behind it. It never holds up input: a tap goes straight through to the title.

const LAYER: int = 90
const TIME: float = 1.3
## The icon's side at the start as a share of the screen's width, close to Android's launch icon.
const START_SHARE: float = 0.42
const TURNS: float = 2.0
## The part of TIME the icon spins in place before it starts to shrink and the screen to clear.
const HOLD_SHARE: float = 0.28

## Off in the tools that stage and film the game, so no capture opens on it.
static var enabled: bool = true
static var _played: bool = false

static func play(host: Node) -> void:
	if _played or not enabled:
		return
	_played = true
	host.add_child(Intro.new())

func _ready() -> void:
	layer = LAYER
	var view: Vector2 = get_viewport().get_visible_rect().size
	var veil: ColorRect = ColorRect.new()
	veil.color = Brand.BG
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var side: float = view.x * START_SHARE
	var icon: TextureRect = UI.app_icon(side)
	icon.size = Vector2(side, side)
	icon.pivot_offset = icon.size * 0.5
	icon.position = (view - icon.size) * 0.5
	add_child(icon)
	var after: float = TIME * HOLD_SHARE
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(icon, "rotation", TAU * TURNS, TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(icon, "scale", Vector2.ZERO, TIME - after).set_delay(after) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(veil, "color:a", 0.0, (TIME - after) * 0.6).set_delay(after).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(queue_free)
