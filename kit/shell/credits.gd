class_name Credits
extends RefCounted

## The credits sheet: the team, then every section of the game's GameCredits, scrolling when it is taller
## than the screen allows. A person in GameCredits.TEAM may have a "site", which their name opens, and a
## "site_on_play" for the Google Play build, which may only open pages with no sponsor links, since Play
## does not let an app lead to a way to pay outside its billing. Without one there, the name opens nothing.

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
	_section(list, "Made by", GameCredits.TEAM.map(func(p: Dictionary) -> Dictionary: return p.merged({"detail": p["role"]})))
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
		var name_label: Control = name_of(item, 30, HORIZONTAL_ALIGNMENT_LEFT)
		if name_label is Label:
			(name_label as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(name_label)
		var detail: Label = UI.label(String(item["detail"]), 24, Brand.MUTED)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(detail)

## The page `person`'s name opens in this build, or "".
static func site(person: Dictionary) -> String:
	return String(person.get("site_on_play" if Supporter.on_play else "site", ""))

## `person`'s name at `size`: an underlined link to their site where they have one for this build, else
## plain text.
static func name_of(person: Dictionary, size: int, align: HorizontalAlignment) -> Control:
	var text: String = String(person["name"])
	var url: String = site(person)
	if url == "":
		var plain: Label = UI.label(text, size)
		plain.horizontal_alignment = align
		return plain
	var link: LinkButton = LinkButton.new()
	link.text = text
	link.uri = url
	link.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	link.focus_mode = Control.FOCUS_NONE
	link.add_theme_font_size_override("font_size", size)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		link.add_theme_color_override(state, Brand.INK)
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if align == HORIZONTAL_ALIGNMENT_CENTER else Control.SIZE_SHRINK_BEGIN
	UI.press_feedback(link)
	return link
