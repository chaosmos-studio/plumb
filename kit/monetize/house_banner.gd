class_name HouseBanner
extends Control

## The house ads' banner: one of the studio's other games in its own colours, its icon, name and line, and a
## little of it moving. A tap opens its store page. It moves on to the next game every so often.

## Seconds before the next game, while the banner stays on screen.
const TURN: float = 24.0
## How far a press may move and still be a tap.
const SLOP: float = 18.0

var game: Dictionary = {}
var _look: Dictionary = {}
var _icon: Texture2D
var _clock: float = 0.0
var _shown_at: float = 0.0
var _from: Vector2 = Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func show_game(next: Dictionary) -> void:
	game = next
	_look = HouseGames.style(String(next["name"]))
	_icon = UI.rounded(load(String(next["icon"])) as Texture2D)
	_shown_at = _clock
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	if is_visible_in_tree() and _clock - _shown_at > TURN:
		show_game(HouseAds.next_game())
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if press.pressed:
		_from = press.position
	elif press.position.distance_to(_from) < SLOP and not game.is_empty():
		Analytics.event(&"house_ad", {"game": String(game["name"]), "what": "banner"})
		OS.shell_open(Studio.link(game))
	accept_event()

func _draw() -> void:
	if game.is_empty():
		return
	var h: float = size.y
	var w: float = size.x
	var ink: Color = _look["ink"]
	var accent: Color = _look["accent"]
	draw_rect(Rect2(Vector2.ZERO, size), _look["bg"])
	_motif(Rect2(w * 0.55, 0.0, w * 0.24, h))
	draw_rect(Rect2(0.0, 0.0, w, 3.0), Color(accent, 0.85))
	var side: float = h * 0.66
	var at: Vector2 = Vector2(18.0, (h - side) * 0.5)
	draw_texture_rect(_icon, Rect2(at, Vector2(side, side)), false)
	var x: float = at.x + side + 16.0
	draw_string(UI.display_font(), Vector2(x, h * 0.48), String(game["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, ink)
	draw_string(UI.ui_font(), Vector2(x, h * 0.48 + 30.0), String(_look["tag"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
		_look["muted"])
	var pill: Rect2 = Rect2(Vector2(w - 132.0, h * 0.27), Vector2(114.0, h * 0.46))
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = accent
	box.set_corner_radius_all(int(pill.size.y * 0.5))
	box.anti_aliasing = true
	draw_style_box(box, pill)
	var font: Font = UI.ui_font()
	var ts: Vector2 = font.get_string_size("Get", HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	draw_string(font, Vector2(pill.get_center().x - ts.x * 0.5, pill.get_center().y + 9.0), "Get", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 26, _look["bg"])

## A few seconds of the game, on a loop, in the space between the words and the pill.
func _motif(r: Rect2) -> void:
	var t: float = _clock
	var pieces: Array = _look["pieces"]
	var mid: float = r.get_center().y
	match String(game["name"]):
		"Plumb":
			var hole: Vector2 = Vector2(r.end.x - 18.0, mid + 8.0)
			draw_circle(hole, 14.0, Color(_look["ink"], 0.85), true, -1.0, true)
			for i: int in range(3):
				var run: float = fposmod(t * 0.45 + i / 3.0, 1.0)
				var p: Vector2 = Vector2(r.position.x + 10.0, mid - 14.0).lerp(hole, run)
				p.y += sin(run * PI) * -10.0
				var colour: Color = pieces[i % pieces.size()]
				draw_circle(p, 11.0 * (1.0 - smoothstep(0.86, 1.0, run)), colour, true, -1.0, true)
		"Carillon":
			var phase: float = fposmod(t, 2.6)
			for k: int in range(5):
				var p: Vector2 = Vector2(r.position.x + 14.0 + k * (r.size.x - 28.0) / 4.0, mid + sin(k * 1.7) * 18.0)
				var colour: Color = pieces[k % pieces.size()]
				var age: float = phase - k * 0.22
				if age >= 0.0 and age < 0.6:
					draw_arc(p, 6.0 + age * 60.0, 0.0, TAU, 32, Color(colour, 0.6 * (1.0 - age / 0.6)), 2.0, true)
				draw_circle(p, 8.0 if age < 0.0 or age > 0.6 else 8.0 + 4.0 * sin(age / 0.6 * PI), colour, true, -1.0, true)
		"Apsis":
			var centre: Vector2 = r.get_center()
			draw_arc(centre, r.size.y * 0.32, 0.0, TAU, 48, Color(_look["muted"], 0.4), 1.5, true)
			for k: int in range(3):
				var a: float = k * TAU / 3.0 + 0.4
				var run: float = fposmod(t * 0.5 + k / 3.0, 1.0)
				var way: Vector2 = Vector2.from_angle(a)
				var p: Vector2 = centre + way * (r.size.y * 0.32 + run * run * r.size.x * 0.6)
				var colour: Color = Color(pieces[k % pieces.size()], 1.0 - run)
				var side: Vector2 = way.orthogonal()
				draw_colored_polygon(PackedVector2Array([p + way * 10.0, p - way * 6.0 + side * 8.0, p - way * 2.0,
					p - way * 6.0 - side * 8.0]), colour)
		_:
			# One knot swings out past the far side and back, so its strand crosses another and then clears.
			var home: Array[Vector2] = [Vector2(0.18, 0.28), Vector2(0.82, 0.28), Vector2(0.82, 0.74), Vector2(0.18, 0.74)]
			var swing: float = 0.5 + 0.5 * sin(t * 1.4)
			var pts: Array[Vector2] = []
			for k: int in range(4):
				pts.append(r.position + home[k] * r.size)
			pts[3] = r.position + home[3].lerp(Vector2(0.97, 0.5), swing) * r.size
			var edges: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0), Vector2i(0, 2)]
			for e: Vector2i in edges:
				var crossed: bool = false
				for f: Vector2i in edges:
					if e.x != f.x and e.x != f.y and e.y != f.x and e.y != f.y \
							and Geometry2D.segment_intersects_segment(pts[e.x], pts[e.y], pts[f.x], pts[f.y]) != null:
						crossed = true
				draw_line(pts[e.x], pts[e.y], pieces[1] if crossed else pieces[0], 3.0, true)
			for p: Vector2 in pts:
				draw_circle(p, 8.0, Color.WHITE, true, -1.0, true)
				draw_arc(p, 7.0, 0.0, TAU, 24, pieces[0], 2.5, true)
