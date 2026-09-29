class_name Kinetic
extends Control

## Kinetic type: a line of words that arrive one by one, each rising a little and settling with a soft
## overshoot, then leave together. Words wrapped in *asterisks* in the text are set in the accent colour.

const STAGGER: float = 0.065
const RISE: float = 26.0
const IN_TIME: float = 0.42
const OUT_TIME: float = 0.28

var _flow: HFlowContainer
var _words: Array[Label] = []

## `align` is "center" or "left". `width` wraps the line; `size_px` is the type size.
func _init(text: String, size_px: int, width: float, align: String = "center", colour: Color = Brand.INK) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(width, 0)
	_flow = HFlowContainer.new()
	_flow.alignment = FlowContainer.ALIGNMENT_CENTER if align == "center" else FlowContainer.ALIGNMENT_BEGIN
	_flow.add_theme_constant_override("h_separation", int(size_px * 0.28))
	_flow.add_theme_constant_override("v_separation", int(size_px * -0.08))
	_flow.custom_minimum_size = Vector2(width, 0)
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flow)
	for raw: String in text.split(" ", false):
		var accent: bool = raw.begins_with("*") and raw.ends_with("*") and raw.length() > 2
		var word: String = raw.substr(1, raw.length() - 2) if accent else raw
		var l: Label = UI.title(word, size_px, Brand.ACCENT if accent else colour)
		l.modulate.a = 0.0
		_flow.add_child(l)
		_words.append(l)

func _ready() -> void:
	await get_tree().process_frame
	size = _flow.size
	custom_minimum_size.y = _flow.size.y

## Brings the words in, one after another.
func play_in() -> void:
	await get_tree().process_frame
	for k: int in range(_words.size()):
		var w: Label = _words[k]
		var home: float = w.position.y
		w.position.y = home + RISE
		w.pivot_offset = w.size * 0.5
		w.scale = Vector2(0.92, 0.92)
		var t: Tween = create_tween().set_parallel(true)
		t.tween_interval(k * STAGGER)
		t.chain().tween_property(w, "modulate:a", 1.0, IN_TIME * 0.6)
		t.parallel().tween_property(w, "position:y", home, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(w, "scale", Vector2.ONE, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func play_out() -> void:
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, OUT_TIME)
	t.tween_property(self, "position:y", position.y - RISE * 0.6, OUT_TIME).set_ease(Tween.EASE_IN)
	await t.finished
	queue_free()
