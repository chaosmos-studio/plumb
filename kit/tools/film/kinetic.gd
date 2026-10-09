class_name Kinetic
extends Control

const STAGGER: float = 0.065
const RISE: float = 26.0
const IN_TIME: float = 0.42
const OUT_TIME: float = 0.28

var _flow: HFlowContainer
var _words: Array[Control] = []

## `align` is "center" or "left". `style` is "accent" or "marker", which puts key words on a highlighter pill.
func _init(text: String, size_px: int, width: float, align: String = "center", colour: Color = Brand.INK,
		style: String = "accent") -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(width, 0)
	_flow = HFlowContainer.new()
	_flow.alignment = FlowContainer.ALIGNMENT_CENTER if align == "center" else FlowContainer.ALIGNMENT_BEGIN
	_flow.add_theme_constant_override("h_separation", int(size_px * 0.28))
	_flow.add_theme_constant_override("v_separation", int(size_px * 0.02 if style == "marker" else size_px * -0.08))
	_flow.custom_minimum_size = Vector2(width, 0)
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flow)
	# Key words are wrapped in asterisks, and a key phrase may run over several words: "*solve it*?".
	var open: bool = false
	for raw: String in text.split(" ", false):
		var word: String = raw
		var starts: bool = word.begins_with("*")
		if starts:
			word = word.substr(1)
		var core: String = word.rstrip("!?.,")
		var ends: bool = core.ends_with("*")
		if ends:
			word = core.substr(0, core.length() - 1) + word.substr(core.length())
		var accent: bool = open or starts
		open = accent and not ends
		if accent and style == "marker":
			var mark: _Marked = _Marked.new(word, size_px)
			mark.modulate.a = 0.0
			_flow.add_child(mark)
			_words.append(mark)
		else:
			var l: Label = UI.title(word, size_px, Brand.ACCENT if accent else colour)
			l.modulate.a = 0.0
			_flow.add_child(l)
			_words.append(l)

func _ready() -> void:
	await get_tree().process_frame
	size = _flow.size
	custom_minimum_size.y = _flow.size.y

func play_in() -> void:
	await get_tree().process_frame
	for k: int in range(_words.size()):
		var w: Control = _words[k]
		var home: float = w.position.y
		w.position.y = home + RISE
		w.pivot_offset = w.size * 0.5
		w.scale = Vector2(0.92, 0.92)
		var t: Tween = create_tween().set_parallel(true)
		t.tween_interval(k * STAGGER)
		t.chain().tween_property(w, "modulate:a", 1.0, IN_TIME * 0.6)
		t.parallel().tween_property(w, "position:y", home, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(w, "scale", Vector2.ONE, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if w is _Marked:
			(w as _Marked).sweep(k * STAGGER + IN_TIME * 0.5)

func play_out() -> void:
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, OUT_TIME)
	t.tween_property(self, "position:y", position.y - RISE * 0.6, OUT_TIME).set_ease(Tween.EASE_IN)
	await t.finished
	queue_free()

class _Marked extends Control:
	var grow: float = 0.0:
		set(value):
			grow = value
			queue_redraw()
	var _label: Label
	var _pad: Vector2

	func _init(word: String, size_px: int) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pad = Vector2(size_px * 0.22, size_px * 0.02)
		_label = UI.title(word, size_px, Brand.ACCENT_INK)
		_label.position = _pad
		add_child(_label)

	func _ready() -> void:
		await get_tree().process_frame
		custom_minimum_size = _label.size + _pad * 2.0
		size = custom_minimum_size

	func sweep(delay: float) -> void:
		create_tween().tween_property(self, "grow", 1.0, 0.32).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		if grow <= 0.0:
			return
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Brand.ACCENT
		box.set_corner_radius_all(int(size.y * 0.24))
		box.anti_aliasing = true
		var h: float = size.y * 0.86
		draw_style_box(box, Rect2(0.0, (size.y - h) * 0.5, size.x * grow, h))
