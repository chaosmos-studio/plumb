class_name Looks
extends RefCounted

## Other looks for the game: its own `GameLooks`, such as Plumb's marble sets or Carillon's instruments.
## The first is the one the game was made in and always free; the rest come with the Looks pack (or the
## Complete pack) on Google Play, and are all open in every other build, which sells nothing (Shop). A look
## only changes what the game itself draws or plays, never the kit's colours, so light and dark still both
## work under every look.
##
## The kit expects from the game: `GameLooks.LOOKS`, an Array of {"id", "name"} with the free one first;
## `GameLooks.use(id)`, which makes the next `Brand.use` paint (or the next note play) in that look;
## `GameLooks.swatch(id)`, the colours its card shows; `GameLooks.sample(id, colour, radius)`, a node that
## shows one of those colours as that look really draws it (a marble in its finish), or null for a plain
## disc; `GameLooks.preview(id)`, anything a card does when tapped beyond picking, such as a few notes;
## `GameLooks.TITLE`, `PACK`, `PACK_LINE` and `PACK_ROW`; and `Save.look` with `Save.set_look(id)`.

static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for look: Dictionary in GameLooks.LOOKS:
		out.append(String(look["id"]))
	return out

static func free_id() -> String:
	return ids()[0]

## The saved look, or the free one if the save names a look this build does not have or may not use.
static func current() -> String:
	return Save.look if ids().has(Save.look) and is_open(Save.look) else free_id()

static func is_open(id: String) -> bool:
	return id == free_id() or Shop.looks_open()

static func name_of(id: String) -> String:
	for look: Dictionary in GameLooks.LOOKS:
		if String(look["id"]) == id:
			return String(look["name"])
	return ""

## At launch, before the first palette is chosen.
static func use_saved() -> void:
	GameLooks.use(current())

## The player's pick: saved, applied, and the screen rebuilt around it.
static func choose(id: String, tree: SceneTree, reopen: Callable = Callable()) -> void:
	if not is_open(id) or id == current():
		return
	Save.set_look(id)
	GameLooks.use(id)
	Appearance.apply(Save.theme)
	await Appearance.rebuild(tree, reopen)

## A card for each look, two to a row: its colours and its name, ringed when it is the one in use, with
## a lock on any the pack has not opened. A locked card plays its preview and offers the pack.
static func open(host: Node) -> Sheet:
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title(GameLooks.TITLE, 56))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for id: String in ids():
		var card: _Card = _Card.new(id, id == current(), is_open(id))
		card.pressed.connect(func() -> void:
			GameLooks.preview(id)
			if not is_open(id):
				sheet.close()
				Shop.offer(host, GameMonetize.LOOKS_ID)
				return
			sheet.close()
			choose(id, host.get_tree(), func(scene: Node) -> void: Looks.open(scene)))
		grid.add_child(card)
	c.add_child(UI.centred(grid))
	if not Shop.looks_open():
		var every: Button = UI.button("Get the %s" % GameLooks.PACK, UI.Style.SECONDARY)
		every.pressed.connect(func() -> void:
			sheet.close()
			Shop.offer(host, GameMonetize.LOOKS_ID))
		c.add_child(every)
	return sheet

class _Card extends BaseButton:
	## Two to a row with the gap between them, inside the sheet's margins on a 720 wide screen.
	const SIZE: Vector2 = Vector2(296, 150)
	const SWATCH: float = 18.0
	const SWATCH_GAP: float = 10.0

	var id: String = ""
	var chosen: bool = false
	var open: bool = true
	## The colours drawn as plain discs because the look gave no sample for them.
	var _discs: Array = []

	func _init(look: String, in_use: bool, available: bool) -> void:
		id = look
		chosen = in_use
		open = available
		custom_minimum_size = SIZE
		focus_mode = Control.FOCUS_NONE
		UI.press_feedback(self)
		var colours: Array = GameLooks.swatch(id)
		for k: int in range(colours.size()):
			var sample: Node2D = GameLooks.sample(id, colours[k] as Color, SWATCH)
			if sample == null:
				_discs.append(k)
				continue
			sample.position = _spot(k, colours.size())
			sample.modulate.a = 1.0 if open else 0.45
			add_child(sample)

	## Where the k-th of n swatches sits, centred in a row near the top of the card.
	static func _spot(k: int, n: int) -> Vector2:
		var width: float = n * SWATCH * 2.0 + (n - 1) * SWATCH_GAP
		return Vector2(SIZE.x * 0.5 - width * 0.5 + SWATCH + k * (SWATCH * 2.0 + SWATCH_GAP), 3.0 + 50.0)

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.set_corner_radius_all(30)
		box.anti_aliasing = true
		box.bg_color = Brand.SURFACE
		box.border_color = Brand.ACCENT if chosen else Brand.LINE
		box.set_border_width_all(4 if chosen else 2)
		draw_style_box(box, rect)
		var colours: Array = GameLooks.swatch(id)
		for k: int in _discs:
			draw_circle(_spot(k, colours.size()), SWATCH, Color(colours[k] as Color, 1.0 if open else 0.45), true, -1.0, true)
		var font: Font = UI.ui_font()
		var text: String = Looks.name_of(id)
		var ink: Color = Brand.INK if open else Brand.MUTED
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var baseline: float = rect.position.y + 118.0
		draw_string(font, Vector2(rect.get_center().x - w * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)
		if not open:
			Icons.draw(self, &"lock", rect.position + Vector2(rect.size.x - 30.0, 30.0), 28.0, Brand.MUTED)
