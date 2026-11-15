class_name Flourish
extends RefCounted

## The pieces the party (Celebration) is built from: confetti, the praise word, the sheet's star tally and chapter
## bar, a level tile's shine, and the red circle screens change under. All are drawn in code from arrays made once,
## so nothing compiles or allocates while they play.

## A one-shot burst of confetti.
class Burst extends Node2D:
	var count: int = 12
	## Pixels a second at the start, the spread of directions in radians around `aim`, and the pull down.
	var speed: float = 420.0
	var aim: float = -PI * 0.5
	var spread: float = TAU
	var gravity: float = 0.0
	var drag: float = 2.5
	var life: float = 0.8
	var size: float = 10.0
	var colours: Array[Color] = [Color.WHITE]
	var _t: float = 0.0
	var _at: PackedVector2Array = PackedVector2Array()
	var _v: PackedVector2Array = PackedVector2Array()
	var _spin: PackedFloat32Array = PackedFloat32Array()
	var _scale: PackedFloat32Array = PackedFloat32Array()

	func _ready() -> void:
		var dice: RandomNumberGenerator = RandomNumberGenerator.new()
		dice.seed = get_instance_id()
		for k: int in range(count):
			_at.append(Vector2.ZERO)
			_v.append(Vector2.from_angle(aim + dice.randf_range(-0.5, 0.5) * spread) * speed * dice.randf_range(0.55, 1.0))
			_spin.append(dice.randf_range(-10.0, 10.0))
			_scale.append(dice.randf_range(0.6, 1.2))

	func _process(delta: float) -> void:
		_t += delta / life
		if _t >= 1.0:
			queue_free()
			return
		for k: int in range(_at.size()):
			var v: Vector2 = _v[k] * exp(-drag * delta)
			v.y += gravity * delta
			_v[k] = v
			_at[k] += v * delta
		queue_redraw()

	## Each piece is a little card that spins and flips as it falls.
	func _draw() -> void:
		var fade: float = 1.0 - _t * _t
		for k: int in range(_at.size()):
			var s: float = size * _scale[k]
			draw_set_transform(_at[k], _spin[k] * _t * 3.0, Vector2(1.0, 0.3 + 0.7 * absf(cos(_spin[k] * _t * 4.0))))
			draw_rect(Rect2(-s * 0.5, -s * 0.3, s, s * 0.6), Color(colours[k % colours.size()], fade))
		draw_set_transform(Vector2.ZERO)

## The praise word over the board: one word, big, popping in with a wobble.
class Word extends Control:
	var text: String = ""
	var colour: Color = Color.WHITE
	var font_size: int = 96
	var hold: float = 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label: Label = UI.title(text, font_size, colour)
		label.add_theme_color_override("font_outline_color", Color(Brand.INK, 0.35))
		label.add_theme_constant_override("outline_size", 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(label)
		pivot_offset = size * 0.5
		scale = Vector2(0.2, 0.2)
		rotation = -0.12
		var t: Tween = create_tween()
		t.tween_property(self, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "rotation", 0.04, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.tween_interval(hold)
		t.tween_property(self, "modulate:a", 0.0, 0.25)
		t.tween_callback(queue_free)

## The star total on the result sheet, counting up from before the win to after it.
class Tally extends HBoxContainer:
	var from: int = 0
	var to: int = 0
	var _label: Label

	func _ready() -> void:
		alignment = BoxContainer.ALIGNMENT_CENTER
		add_theme_constant_override("separation", 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(StarIcon.new(30.0, true))
		_label = UI.label(str(from), 30, Brand.MUTED)
		add_child(_label)

	## Counts up over `seconds`, ticking softly as it goes, and pops when it arrives.
	func count(seconds: float) -> void:
		var t: Tween = create_tween()
		t.tween_method(_show, float(from), float(to), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_callback(func() -> void:
			_label.add_theme_color_override("font_color", Brand.INK)
			_label.pivot_offset = _label.size * 0.5
			var pop: Tween = create_tween()
			pop.tween_property(_label, "scale", Vector2(1.25, 1.25), 0.08)
			pop.tween_property(_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

	func _show(value: float) -> void:
		var shown: String = str(roundi(value))
		if shown != _label.text:
			_label.text = shown
			Audio.play(&"tap", -20.0, 1.4 + 0.02 * (roundi(value) - from))

## How much of the chapter is solved, as a bar in the chapter's colour that fills from before the win to after.
class ChapterBar extends Control:
	var tint: Color = Color.WHITE
	var before: float = 0.0
	var after: float = 0.0
	var shown: float = 0.0:
		set(value):
			shown = value
			queue_redraw()
	var _box: StyleBoxFlat = StyleBoxFlat.new()

	func _init() -> void:
		custom_minimum_size = Vector2(360, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.set_corner_radius_all(7)
		_box.anti_aliasing = true

	func fill(seconds: float) -> void:
		shown = before
		create_tween().tween_property(self, "shown", after, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var bar: Rect2 = Rect2(Vector2((size.x - custom_minimum_size.x) * 0.5, 0.0), custom_minimum_size)
		_box.bg_color = Color(tint, 0.18)
		draw_style_box(_box, bar)
		if shown > 0.0:
			_box.bg_color = tint
			draw_style_box(_box, Rect2(bar.position, Vector2(maxf(bar.size.y, bar.size.x * shown), bar.size.y)))

## A level tile's own life on the Levels screen: a slow shine across a solved tile and a breathing ring round the next
## one. A solved tile draws again only while its shine passes.
class TileGlow extends Control:
	var solved: bool = false
	var next: bool = false
	var shine_every: float = 3.6
	var ring_colour: Color = Color.WHITE
	var _t: float = 0.0
	var _offset: float = 0.0
	var _shining: bool = false
	var _ring: StyleBoxFlat = StyleBoxFlat.new()
	var _band: PackedVector2Array = PackedVector2Array()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		_offset = randf() * shine_every
		_ring.bg_color = Color(0, 0, 0, 0)
		_ring.set_corner_radius_all(38)
		_ring.anti_aliasing = true
		_band.resize(4)
		set_process(solved or next)

	func _process(delta: float) -> void:
		_t += delta
		var shining: bool = solved and _phase() < 1.0
		if next or shining or _shining:
			queue_redraw()
		_shining = shining

	func _phase() -> float:
		return fposmod(_t + _offset, shine_every) / 0.7

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2(4, 4), size - Vector2(8, 8))
		if next:
			var breath: float = 0.5 + 0.5 * sin(_t * 2.6)
			_ring.border_color = Color(ring_colour, 0.25 + 0.35 * breath)
			_ring.set_border_width_all(int(3 + 3 * breath))
			draw_style_box(_ring, rect.grow(4.0 + 4.0 * breath))
		if solved and _phase() < 1.0:
			var phase: float = _phase()
			var inner: Rect2 = rect.grow(-10.0)
			var x: float = lerpf(inner.position.x - 30.0, inner.end.x, phase)
			_band[0] = Vector2(clampf(x + 30.0, inner.position.x, inner.end.x), inner.position.y)
			_band[1] = Vector2(clampf(x + 46.0, inner.position.x, inner.end.x), inner.position.y)
			_band[2] = Vector2(clampf(x + 16.0, inner.position.x, inner.end.x), inner.end.y)
			_band[3] = Vector2(clampf(x, inner.position.x, inner.end.x), inner.end.y)
			if _band[1].x - _band[0].x > 0.5 and _band[2].x - _band[3].x > 0.5:
				draw_colored_polygon(_band, Color(1, 1, 1, 0.5 * sin(PI * phase)))

## The circle a screen change happens under: it grows from the middle to cover the screen, and shrinks away.
class Veil extends Control:
	var colour: Color = Color.WHITE
	## 0 clear, 1 covering the screen.
	var cover: float = 0.0:
		set(value):
			cover = value
			queue_redraw()

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if cover > 0.0:
			draw_circle(size * 0.5, size.length() * 0.55 * cover, colour, true, -1.0, true)
