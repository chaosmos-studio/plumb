class_name MoreGames
extends RefCounted

const CARD_SIZE: Vector2 = Vector2(0, 156)
const ICON_SIZE: float = 112.0

static func title() -> String:
	return "More from %s" % Studio.NAME

static func open(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title(title(), 52))
	c.add_child(UI.spacer(6))
	for game: Dictionary in Studio.others():
		c.add_child(_card(game))
	c.add_child(UI.spacer(6))
	var all: Button = UI.button("Every game at chaosmos.studio", UI.Style.GHOST)
	all.pressed.connect(func() -> void: OS.shell_open(Studio.GAMES_PAGE))
	c.add_child(all)
	return sheet

static func _card(game: Dictionary) -> Button:
	var card: Button = UI.card(CARD_SIZE)
	card.pressed.connect(func() -> void: OS.shell_open(Studio.link(game)))
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22.0
	row.offset_right = -22.0
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.texture = UI.rounded(load(String(game["icon"])) as Texture2D)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words: VBoxContainer = VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading: Label = UI.title(String(game["name"]), 40)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.add_child(heading)
	var line: Label = UI.label(String(game["line"]), 24, Brand.MUTED)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(line)
	row.add_child(words)
	return card
