class_name Themes
extends RefCounted

## The kit expects from the game:
## - `Brand.use_theme(colours, dark)`, which sets the kit's colours and the game's own from what `colours`
##   works out.
## - `Brand.LIGHT` and `Brand.DARK`, its own two palettes, for the first card.
## - `Save.palette` with `Save.set_palette(id)`.

const OWN: String = "own"
const OWN_NAME: String = "Original"
## id, name, then [background, surface, ink, accent] for the light variant and for the dark one.
const FAMILIES: Array = [
	["sepia", "Sepia", ["f6edd6", "fdf8ea", "47392a", "9a6431"], ["29231b", "373024", "ecdfc6", "d9a35f"]],
	["solarized", "Solarized", ["fdf6e3", "fffbef", "34454b", "1f7cc4"], ["002b36", "063542", "c9d3d1", "4ba3e3"]],
	["gruvbox", "Gruvbox", ["fbf1c7", "fdf8e1", "3c3836", "a8650a"], ["282828", "3a3634", "ebdbb2", "fabd2f"]],
	["nord", "Nord", ["e9edf3", "f8f9fb", "2e3440", "4c6f9e"], ["2e3440", "3b4252", "eceff4", "88c0d0"]],
	["dracula", "Dracula", ["fbf8ef", "ffffff", "232129", "6a4bc6"], ["282a36", "363948", "f8f8f2", "bd93f9"]],
	["tokyo", "Tokyo Night", ["e4e6ee", "f3f4f8", "2b3456", "2e6fd9"], ["1a1b26", "262a40", "c0caf5", "7aa2f7"]],
	["catppuccin", "Catppuccin", ["eff1f5", "ffffff", "4c4f69", "8233e6"], ["1e1e2e", "313244", "cdd6f4", "cba6f7"]],
	["one", "One", ["f7f7f8", "ffffff", "383a42", "3b6fe0"], ["282c34", "323843", "c5cbd6", "61afef"]],
	["ocean", "Ocean", ["eef4fc", "ffffff", "0f1d36", "1f5fd6"], ["0c1628", "16233b", "e2e9f4", "5ea3f8"]],
	["forest", "Forest", ["eef6f0", "ffffff", "10261b", "0b7d58"], ["0e1a14", "182a20", "e1efe6", "3bd19a"]],
	["rose", "Rose", ["fbf0f3", "ffffff", "2b1a20", "c81d4a"], ["1f1418", "2d1e25", "f5e4e9", "fb7c96"]],
	["grape", "Grape", ["f5f1fc", "ffffff", "1f1733", "6d35d6"], ["171226", "241b3a", "ece6f8", "b197fc"]],
]

static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray([OWN])
	for f: Array in FAMILIES:
		out.append(String(f[0]))
	return out

static func name_of(id: String) -> String:
	for f: Array in FAMILIES:
		if String(f[0]) == id:
			return String(f[1])
	return OWN_NAME

static func is_open(id: String) -> bool:
	return id == OWN or Shop.themes_open()

static func current() -> String:
	return Save.palette if ids().has(Save.palette) and is_open(Save.palette) else OWN

static func seed_of(id: String, dark: bool) -> Array[Color]:
	var out: Array[Color] = []
	for f: Array in FAMILIES:
		if String(f[0]) == id:
			for hex: Variant in f[3 if dark else 2]:
				out.append(Color(String(hex)))
	return out

## The accent's own text is dark or white, whichever reads on it.
static func colours(id: String, dark: bool) -> Dictionary:
	var s: Array[Color] = seed_of(id, dark)
	if s.is_empty():
		return {}
	var bg: Color = s[0]
	var surface: Color = s[1]
	var ink: Color = s[2]
	var accent: Color = s[3]
	return {
		"bg": bg,
		"surface": surface,
		"line": Color(ink, 0.12 if dark else 0.1),
		"ink": ink,
		"muted": ink.lerp(bg, 0.36),
		"accent": accent,
		"accent_ink": Color("15171c") if accent.get_luminance() > 0.55 else Color.WHITE,
		"shadow": Color(0, 0, 0, 0.3) if dark else Color(ink.darkened(0.2), 0.1),
		"scrim": bg.darkened(0.6) if dark else ink,
	}

static func choose(id: String, tree: SceneTree, reopen: Callable = Callable()) -> void:
	if not is_open(id) or id == current():
		return
	Save.set_palette(id)
	Appearance.apply(Save.theme)
	await Appearance.rebuild(tree, reopen)

static func open(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Colours", 56))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	for id: String in ids():
		var card: _Card = _Card.new(id, id == current(), is_open(id))
		card.pressed.connect(func() -> void:
			sheet.close()
			if not is_open(id):
				Shop.offer(host, GameMonetize.THEMES_ID)
				return
			choose(id, host.get_tree(), func(scene: Node) -> void: Themes.open(scene)))
		grid.add_child(card)
	c.add_child(UI.centred(grid))
	if not Shop.themes_open():
		var every: Button = UI.button("Get the Themes pack", UI.Style.SECONDARY)
		every.pressed.connect(func() -> void:
			sheet.close()
			Shop.offer(host, GameMonetize.THEMES_ID))
		c.add_child(every)
	return sheet

class _Card extends BaseButton:
	## Two to a row inside the sheet's margins on a 720 wide screen, and short enough that thirteen fit.
	const SIZE: Vector2 = Vector2(296, 104)

	var id: String = ""
	var chosen: bool = false
	var open: bool = true

	func _init(theme: String, in_use: bool, available: bool) -> void:
		id = theme
		chosen = in_use
		open = available
		custom_minimum_size = SIZE
		focus_mode = Control.FOCUS_NONE
		UI.press_feedback(self)

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.set_corner_radius_all(26)
		box.anti_aliasing = true
		box.bg_color = Brand.SURFACE
		box.border_color = Brand.ACCENT if chosen else Brand.LINE
		box.set_border_width_all(4 if chosen else 2)
		draw_style_box(box, rect)
		var fade: float = 1.0 if open else 0.5
		for k: int in range(2):
			var tile: Rect2 = Rect2(rect.position + Vector2(16 + k * 50, 18), Vector2(44, 62))
			_tile(tile, k == 1, fade)
		var font: Font = UI.ui_font()
		var text: String = Themes.name_of(id)
		var ink: Color = Brand.INK if open else Brand.MUTED
		draw_string(font, Vector2(rect.position.x + 122, rect.get_center().y + 9), text, HORIZONTAL_ALIGNMENT_LEFT,
			rect.size.x - 150, 25, ink)
		if not open:
			Icons.draw(self, &"lock", rect.position + Vector2(rect.size.x - 26.0, 26.0), 24.0, Brand.MUTED)

	func _tile(r: Rect2, dark: bool, fade: float) -> void:
		var s: Array[Color] = Themes.seed_of(id, dark)
		if s.is_empty():
			var own: Dictionary = Brand.DARK if dark else Brand.LIGHT
			s.assign([own["bg"], own["surface"], own["ink"], own["accent"]])
		var back: StyleBoxFlat = StyleBoxFlat.new()
		back.bg_color = Color(s[0], fade)
		back.border_color = Color(s[2], 0.18 * fade)
		back.set_border_width_all(2)
		back.set_corner_radius_all(12)
		back.anti_aliasing = true
		draw_style_box(back, r)
		_emblem(r.position + Vector2(r.size.x * 0.5, 24.0), 30.0, Color(s[3], fade), Color(s[0], fade))
		var card: StyleBoxFlat = StyleBoxFlat.new()
		card.bg_color = Color(s[1], fade)
		card.set_corner_radius_all(6)
		card.anti_aliasing = true
		draw_style_box(card, Rect2(r.position + Vector2(6, 44), Vector2(r.size.x - 12, 12)))
		draw_line(r.position + Vector2(11, 50), r.position + Vector2(r.size.x - 15, 50), Color(s[2], 0.7 * fade), 2.0, true)

	func _emblem(c: Vector2, s: float, ink: Color, ground: Color) -> void:
		var h: float = s * 0.5
		match id:
			Themes.OWN:
				draw_texture_rect(UI.icon_texture(), Rect2(c - Vector2(h, h) * 0.9, Vector2(s, s) * 0.9), false, Color(1, 1, 1, ink.a))
			"sepia":
				var page: PackedVector2Array = PackedVector2Array([c + Vector2(-h * 0.6, -h * 0.8), c + Vector2(h * 0.25, -h * 0.8),
					c + Vector2(h * 0.6, -h * 0.45), c + Vector2(h * 0.6, h * 0.8), c + Vector2(-h * 0.6, h * 0.8), c + Vector2(-h * 0.6, -h * 0.8)])
				draw_polyline(page, ink, 2.0, true)
				for k: int in range(3):
					draw_line(c + Vector2(-h * 0.35, -h * 0.25 + k * h * 0.35), c + Vector2(h * 0.35, -h * 0.25 + k * h * 0.35), ink, 1.6, true)
			"solarized":
				draw_circle(c, h * 0.42, ink, true, -1.0, true)
				for k: int in range(8):
					var a: float = k * TAU / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * h * 0.62, c + Vector2(cos(a), sin(a)) * h * 0.9, ink, 2.0, true)
			"gruvbox":
				var sun: PackedVector2Array = PackedVector2Array()
				for k: int in range(17):
					var a2: float = PI + PI * k / 16.0
					sun.append(c + Vector2(0.0, h * 0.35) + Vector2(cos(a2), sin(a2)) * h * 0.85)
				draw_colored_polygon(sun, ink)
				for k: int in range(2):
					draw_rect(Rect2(c + Vector2(-h, h * (0.02 - k * 0.3)), Vector2(s, h * 0.1)), ground)
			"nord":
				for k: int in range(3):
					var d: Vector2 = Vector2.from_angle(PI * 0.5 + k * PI / 3.0) * h * 0.85
					draw_line(c - d, c + d, ink, 2.0, true)
					for end: Vector2 in [d, -d]:
						var tip: Vector2 = c + end * 0.62
						draw_line(tip, tip + end.rotated(0.7) * 0.3, ink, 1.6, true)
						draw_line(tip, tip + end.rotated(-0.7) * 0.3, ink, 1.6, true)
			"dracula":
				draw_circle(c, h * 0.72, ink, true, -1.0, true)
				draw_circle(c + Vector2(h * 0.38, -h * 0.26), h * 0.62, ground, true, -1.0, true)
			"tokyo":
				var heights: Array[float] = [0.9, 1.4, 0.7, 1.15]
				for k: int in range(4):
					var w: float = s * 0.2
					var tall: float = h * heights[k] * 0.75
					draw_rect(Rect2(c + Vector2(-h * 0.95 + k * (w + 2.0), h * 0.8 - tall), Vector2(w, tall)), ink)
				draw_circle(c + Vector2(h * 0.6, -h * 0.65), h * 0.18, ink, true, -1.0, true)
			"catppuccin":
				draw_arc(c + Vector2(0.0, h * 0.15), h * 0.6, 0.0, TAU, 24, ink, 2.0, true)
				for side: float in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([c + Vector2(side * h * 0.55, -h * 0.15),
						c + Vector2(side * h * 0.62, -h * 0.85), c + Vector2(side * h * 0.12, -h * 0.42)]), ink)
					draw_circle(c + Vector2(side * h * 0.24, h * 0.1), h * 0.09, ink, true, -1.0, true)
			"one":
				for k: int in range(3):
					var ring: PackedVector2Array = PackedVector2Array()
					for j: int in range(33):
						var a3: float = TAU * j / 32.0
						ring.append(c + Vector2(cos(a3) * h * 0.9, sin(a3) * h * 0.32).rotated(k * PI / 3.0))
					draw_polyline(ring, ink, 1.6, true)
				draw_circle(c, h * 0.16, ink, true, -1.0, true)
			"ocean":
				for k: int in range(2):
					var wave: PackedVector2Array = PackedVector2Array()
					for j: int in range(21):
						var x: float = -h + s * j / 20.0
						wave.append(c + Vector2(x, -h * 0.2 + k * h * 0.55 + sin(x / h * PI * 1.5) * h * 0.18))
					draw_polyline(wave, ink, 2.2, true)
			"forest":
				for k: int in range(3):
					var top: float = -h * 0.95 + k * h * 0.42
					draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, top), c + Vector2(h * (0.38 + k * 0.17), top + h * 0.62),
						c + Vector2(-h * (0.38 + k * 0.17), top + h * 0.62)]), ink)
				draw_rect(Rect2(c + Vector2(-h * 0.1, h * 0.5), Vector2(h * 0.2, h * 0.35)), ink)
			"rose":
				var bud: PackedVector2Array = PackedVector2Array()
				for j: int in range(41):
					var t: float = j / 40.0
					var a4: float = t * TAU * 2.2
					bud.append(c + Vector2(0.0, -h * 0.15) + Vector2(cos(a4), sin(a4)) * h * (0.08 + 0.55 * t))
				draw_polyline(bud, ink, 1.8, true)
				draw_line(c + Vector2(0.0, h * 0.45), c + Vector2(0.0, h * 0.95), ink, 2.0, true)
			"grape":
				var spots: Array[Vector2] = [Vector2(-0.5, -0.35), Vector2(0.0, -0.35), Vector2(0.5, -0.35), Vector2(-0.25, 0.12),
					Vector2(0.25, 0.12), Vector2(0.0, 0.58)]
				for spot: Vector2 in spots:
					draw_circle(c + spot * h, h * 0.24, ink, true, -1.0, true)
				draw_line(c + Vector2(0.0, -h * 0.6), c + Vector2(h * 0.25, -h * 0.95), ink, 1.8, true)
