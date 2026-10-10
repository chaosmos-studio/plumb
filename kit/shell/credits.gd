class_name Credits
extends RefCounted

## A person in GameCredits.TEAM may have a "site", which their name opens, and a "site_on_play" for the
## Google Play build, which may only open pages with no sponsor links, since Play does not let an app lead
## to a way to pay outside its billing. Without one there, the name opens nothing.

const MAX_HEIGHT: float = 0.6
const RADIUS: int = 28

static func open(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.centred(UI.app_icon(84)))
	c.add_child(UI.title("Credits", 56))
	var version: String = Changelog.version()
	c.add_child(UI.caption("%s   version %s" % [Brand.NAME, version] if version != "" else Brand.NAME, 20))
	c.add_child(UI.spacer(6))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var height: float = host.get_viewport().get_visible_rect().size.y * MAX_HEIGHT
	scroll.custom_minimum_size = Vector2(0, height)
	c.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	list.add_child(_makers())
	for section: Dictionary in GameCredits.SECTIONS:
		list.add_child(_section(String(section["title"]), section["items"]))
	var thanks: Label = UI.label("Thank you for playing.", 26, Brand.MUTED)
	list.add_child(UI.spacer(4))
	list.add_child(thanks)
	list.add_child(UI.spacer(12))
	return sheet

static func _makers() -> PanelContainer:
	var card: PanelContainer = _panel(Brand.SURFACE.lerp(Brand.ACCENT, 0.09), Brand.ACCENT.lerp(Brand.LINE, 0.7))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	box.add_child(UI.caption("Made by", 20))
	for person: Dictionary in GameCredits.TEAM:
		box.add_child(name_of(person, 40, HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(UI.label(String(person["role"]), 24, Brand.MUTED))
	if GameCredits.HELP != "":
		box.add_child(UI.spacer(6))
		box.add_child(_rule())
		box.add_child(UI.spacer(4))
		var help: Label = UI.label(GameCredits.HELP, 22, Brand.MUTED)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(help)
	return card

static func _section(title: String, items: Array) -> PanelContainer:
	var panel: PanelContainer = _panel(Brand.BG.lerp(Brand.SURFACE, 0.35), Brand.LINE)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_dot(12.0))
	var name_label: Label = UI.caption(title, 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(name_label)
	box.add_child(head)
	box.add_child(UI.spacer(2))
	for i: int in items.size():
		var item: Dictionary = items[i]
		if i > 0:
			box.add_child(UI.spacer(4))
			box.add_child(_rule())
			box.add_child(UI.spacer(4))
		var item_name: Control = name_of(item, 28, HORIZONTAL_ALIGNMENT_LEFT)
		if item_name is Label:
			(item_name as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(item_name)
		var detail: Label = UI.label(String(item["detail"]), 22, Brand.MUTED)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(detail)
	return panel

static func _panel(fill: Color, edge: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A panel stops the mouse by default, and then a drag that starts on it never scrolls the list.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(RADIUS)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 26
	style.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func _rule() -> ColorRect:
	var rule: ColorRect = ColorRect.new()
	rule.color = Brand.LINE
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

static func _dot(side: float) -> CenterContainer:
	var dot: Panel = Panel.new()
	dot.custom_minimum_size = Vector2(side, side)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Brand.ACCENT
	style.set_corner_radius_all(int(side))
	style.anti_aliasing = true
	dot.add_theme_stylebox_override("panel", style)
	return UI.centred(dot)

static func site(person: Dictionary) -> String:
	return String(person.get("site_on_play" if Supporter.on_play else "site", ""))

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
