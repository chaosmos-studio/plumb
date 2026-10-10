class_name Band
extends Control

## The studio's caption look: lower-case words on yellow bands with ink text, one band per line. With word
## times, the word being said turns yellow on an ink chip from the moment it is said. A band fades in while
## it rises a little and leaves faster than it came; a hook is drawn whole from its first frame.

var _font: Font
var _size_px: int
var _band: Color
var _ink: Color
var _lines: Array = []
var _timed: bool = false
var _t: float = 0.0
var _in: float = 0.0
var _out: float = 0.0
var _rise: float = 0.0
var _pad: Vector2
var _line_h: float

## `words` is [[text, start, end], ...] in seconds from when the band appears, or empty for a still line.
func _init(text: String, font: Font, size_px: int, max_width: float, band: Color, ink: Color, words: Array = []) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = font
	_size_px = size_px
	_band = band
	_ink = ink
	_pad = Vector2(size_px * 0.34, size_px * 0.14)
	_line_h = font.get_height(size_px) + _pad.y * 2.0 + size_px * 0.12
	_timed = not words.is_empty()
	var items: Array = []
	if _timed:
		for w: Variant in words:
			var row: Array = w as Array
			items.append([String(row[0]).to_lower(), float(row[1]), float(row[2])])
	else:
		for w: String in text.replace("*", "").split(" ", false):
			items.append([w.to_lower(), -1.0, -1.0])
	var gap: float = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var limit: float = max_width - _pad.x * 2.0
	var line: Array = []
	var width: float = 0.0
	for item: Array in items:
		var w: float = font.get_string_size(String(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		if not line.is_empty() and width + gap + w > limit:
			_lines.append([line, width])
			line = []
			width = 0.0
		var x: float = width + (gap if not line.is_empty() else 0.0)
		line.append([item[0], x, w, item[1]])
		width = x + w
	if not line.is_empty():
		_lines.append([line, width])
	size = Vector2(max_width, _line_h * _lines.size())

func band_height() -> float:
	return size.y

## Arrives over the motion language's base time, or is simply there when `still`.
func play(still: bool = false) -> void:
	_rise = get_viewport_rect().size.y * FilmMotion.text_rise
	if still:
		_in = 1.0
		return
	create_tween().tween_method(func(k: float) -> void: _in = FilmMotion.arrive(k), 0.0, 1.0, FilmMotion.base)

func leave() -> void:
	var t: Tween = create_tween()
	t.tween_method(func(k: float) -> void: _out = FilmMotion.leave(k), 0.0, 1.0, FilmMotion.leave_time(FilmMotion.base))
	t.tween_callback(queue_free)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var alpha: float = clampf(_in, 0.0, 1.0) * (1.0 - _out)
	if alpha <= 0.0:
		return
	var dy: float = _rise * (1.0 - _in) - _rise * _out
	var ascent: float = _font.get_ascent(_size_px)
	for li: int in range(_lines.size()):
		var row: Array = _lines[li][0]
		var width: float = float(_lines[li][1])
		var left: float = (size.x - width) * 0.5
		var top: float = li * _line_h + dy
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(_band, alpha)
		box.set_corner_radius_all(int(_size_px * 0.3))
		box.anti_aliasing = true
		draw_style_box(box, Rect2(left - _pad.x, top, width + _pad.x * 2.0, _font.get_height(_size_px) + _pad.y * 2.0))
		for k: int in range(row.size()):
			var item: Array = row[k]
			var at: Vector2 = Vector2(left + float(item[1]), top + _pad.y + ascent)
			var colour: Color = _ink
			if _timed and _is_current(li, k):
				var chip: StyleBoxFlat = StyleBoxFlat.new()
				chip.bg_color = Color(_ink, alpha)
				chip.set_corner_radius_all(int(_size_px * 0.22))
				chip.anti_aliasing = true
				var pad: float = _size_px * 0.12
				draw_style_box(chip, Rect2(at.x - pad, top + _pad.y * 0.4, float(item[2]) + pad * 2.0,
					_font.get_height(_size_px) + _pad.y * 1.2))
				colour = _band
			draw_string(_font, at, String(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, _size_px, Color(colour, alpha))

## The word being said: the last one whose start has passed, until the next one starts.
func _is_current(li: int, k: int) -> bool:
	var start: float = float(_lines[li][0][k][3])
	if _t < start:
		return false
	var flat: Array = []
	for line: Variant in _lines:
		flat.append_array((line as Array)[0])
	var index: int = flat.find(_lines[li][0][k])
	return index == flat.size() - 1 or _t < float(flat[index + 1][3])
