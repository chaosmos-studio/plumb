class_name About
extends RefCounted

## The about sheet: the game, its version, the people who made it, and its links. The web build links to
## the website and the privacy policy. The Google Play build links only to the privacy policy and the
## support page, the two pages of the site with no sponsor links, since Play does not let an app lead to
## a way to pay outside its billing. Reads the game's GameCredits (res://credits.gd): WEBSITE, PRIVACY and
## SUPPORT.

static func open(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.centred(UI.app_icon(128)))
	c.add_child(UI.title(Brand.NAME, 60))
	var version: String = Changelog.version()
	c.add_child(UI.caption("%s   version %s" % [Brand.TAGLINE, version] if version != "" else Brand.TAGLINE, 20))
	c.add_child(UI.spacer(8))
	c.add_child(UI.caption("Made by", 20))
	for person: Dictionary in GameCredits.TEAM:
		var name_label: Label = UI.label(String(person["name"]), 34)
		c.add_child(name_label)
		var role: Label = UI.label(String(person["role"]), 24, Brand.MUTED)
		c.add_child(role)
	if Supporter.active():
		c.add_child(UI.label("Thank you for being a Supporter", 26, Brand.MUTED))
	c.add_child(UI.spacer(8))
	var links: HBoxContainer = HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 20)
	if Supporter.on_play:
		links.add_child(_link("Privacy", GameCredits.PRIVACY, UI.Style.SECONDARY))
		links.add_child(_link("Support", GameCredits.SUPPORT, UI.Style.GHOST))
	else:
		links.add_child(_link("Website", GameCredits.WEBSITE, UI.Style.SECONDARY))
		links.add_child(_link("Privacy", GameCredits.PRIVACY, UI.Style.GHOST))
	c.add_child(links)
	return sheet

static func _link(text: String, url: String, style: UI.Style) -> Button:
	var b: Button = UI.button(text, style)
	b.pressed.connect(func() -> void: OS.shell_open(url))
	return b
