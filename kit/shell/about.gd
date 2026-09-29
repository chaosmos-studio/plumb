class_name About
extends RefCounted

## The about sheet: the game, its version, the people who made it, and links to its website and privacy
## policy. Reads the game's GameCredits (res://credits.gd).

static func open(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/branding/icon.png")
	icon.custom_minimum_size = Vector2(128, 128)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c.add_child(UI.centred(icon))
	c.add_child(UI.title(Brand.NAME, 60))
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	c.add_child(UI.caption("%s   version %s" % [Brand.TAGLINE, version] if version != "" else Brand.TAGLINE, 20))
	c.add_child(UI.spacer(8))
	c.add_child(UI.caption("Made by", 20))
	for person: Dictionary in GameCredits.TEAM:
		var name_label: Label = UI.label(String(person["name"]), 34)
		c.add_child(name_label)
		var role: Label = UI.label(String(person["role"]), 24, Brand.MUTED)
		c.add_child(role)
	c.add_child(UI.spacer(8))
	var links: HBoxContainer = HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 20)
	var site: Button = UI.button("Website", UI.Style.SECONDARY)
	site.pressed.connect(func() -> void: OS.shell_open(GameCredits.WEBSITE))
	links.add_child(site)
	var privacy: Button = UI.button("Privacy", UI.Style.GHOST)
	privacy.pressed.connect(func() -> void: OS.shell_open(GameCredits.PRIVACY))
	links.add_child(privacy)
	c.add_child(links)
	return sheet
