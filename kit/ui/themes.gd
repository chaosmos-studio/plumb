class_name Themes
extends RefCounted

## Colour themes beyond the game's own light and dark. Each is a family with a light and a dark variant,
## and each variant is a seed of four colours: the background, the surface that sheets and cards sit on,
## the ink, and an accent. The rest of the kit's colours are worked out from those four (the way
## DrawShare builds its themes), and the game works out its own (Brand.use_theme). Light, Dark and Auto
## still choose the variant. The game's own look comes first and is always free; the rest come with the
## Themes pack (or the Complete pack) on Google Play, and are all open in every other build, which sells
## nothing (Shop).
##
## The kit expects from the game: `Brand.use_theme(colours, dark)`, which takes what `colours` works out
## and sets the kit's colours and the game's own from it; `Brand.LIGHT` and `Brand.DARK`, its own two
## palettes, for the first card; and `Save.palette` with `Save.set_palette(id)`.

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

## The saved theme, or the game's own if the save names one this build does not have or may not use.
static func current() -> String:
	return Save.palette if ids().has(Save.palette) and is_open(Save.palette) else OWN

## The seed of theme `id` in light or dark: [background, surface, ink, accent], or [] for the game's own.
static func seed_of(id: String, dark: bool) -> Array[Color]:
	var out: Array[Color] = []
	for f: Array in FAMILIES:
		if String(f[0]) == id:
			for hex: Variant in f[3 if dark else 2]:
				out.append(Color(String(hex)))
	return out

## Every colour the kit reads, worked out from the seed of theme `id`, or {} for the game's own. Lines
## and muted text are the ink let down toward the background, the scrim is the ink by day and a deeper
## background by night, and the accent's own text is dark or white, whichever reads.
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

## The player's pick: saved, applied, and the screen rebuilt around it.
static func choose(id: String, tree: SceneTree, reopen: Callable = Callable()) -> void:
	if not is_open(id) or id == current():
		return
	Save.set_palette(id)
	Appearance.apply(Save.theme)
	await Appearance.rebuild(tree, reopen)

## A card for each theme, two to a row: its light and dark variants side by side and its name, ringed
## when it is the one in use, with a lock on any the pack has not opened. A locked card offers the pack.
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

	## One variant as a tiny screen: its background, a surface card with two lines of ink, an accent dot.
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
		var card: StyleBoxFlat = StyleBoxFlat.new()
		card.bg_color = Color(s[1], fade)
		card.set_corner_radius_all(7)
		card.anti_aliasing = true
		draw_style_box(card, Rect2(r.position + Vector2(7, 8), Vector2(r.size.x - 14, 28)))
		draw_line(r.position + Vector2(13, 17), r.position + Vector2(r.size.x - 13, 17), Color(s[2], fade), 3.0, true)
		draw_line(r.position + Vector2(13, 26), r.position + Vector2(r.size.x - 22, 26), Color(s[2], 0.5 * fade), 3.0, true)
		draw_circle(r.position + Vector2(r.size.x * 0.5, r.size.y - 13), 7.0, Color(s[3], fade), true, -1.0, true)
