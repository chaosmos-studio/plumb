class_name Credits
extends RefCounted

## The credits sheet: the team, then every section of the game's GameCredits, scrolling when it is taller
## than the screen allows.

const MAX_HEIGHT: float = 0.62

static func open(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Credits", 56))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var height: float = host.get_viewport().get_visible_rect().size.y * MAX_HEIGHT
	scroll.custom_minimum_size = Vector2(0, height)
	c.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	_section(list, "Made by", GameCredits.TEAM.map(func(p: Dictionary) -> Dictionary: return {"name": p["name"], "detail": p["role"]}))
	for section: Dictionary in GameCredits.SECTIONS:
		_section(list, String(section["title"]), section["items"])
	return sheet

static func _section(list: VBoxContainer, title: String, items: Array) -> void:
	list.add_child(UI.spacer(14))
	var head: Label = UI.caption(title, 20)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(head)
	for entry: Variant in items:
		var item: Dictionary = entry
		var name_label: Label = UI.label(String(item["name"]), 30)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(name_label)
		var detail: Label = UI.label(String(item["detail"]), 24, Brand.MUTED)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(detail)
