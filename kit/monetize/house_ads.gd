class_name HouseAds
extends AdBackend

## The studio's own ads: a banner for another of its games where an ad's banner would be, a tiny playable taste
## of one in place of a rewarded video, which the player may close at once and still earns the reward, and no
## interstitials at all. Nothing is fetched, so both are always ready. They stand in for AdMob while it is
## switched off (GameMonetize.ADMOB false), and fill in under it whenever it has nothing to give. Standing in
## on Android, they still ask Google's consent service whether this phone needs consent, since Analytics waits
## on that answer before it counts.

## The game the next banner or playable shows: they take turns.
static var _turn: int = 0

## False when filling in under AdMob, which asks for consent itself.
var consent: bool = true
var _layer: CanvasLayer
var _banner: HouseBanner
var _height: float = 0.0
var _pending: bool = false

func _ready() -> void:
	if consent and OS.has_feature("android") and Engine.has_singleton("PoingGodotAdMob"):
		add_child(load("res://kit/monetize/android/consent.gd").new() as Node)

func ready_to_show(kind: StringName) -> bool:
	return kind == REWARDED and not Studio.others().is_empty()

func present(kind: StringName) -> void:
	var host: Node = get_tree().current_scene
	if not ready_to_show(kind) or host == null:
		finished.emit.call_deferred(kind, false, false)
		return
	var sheet: Sheet = playable(host, next_game())
	await sheet.closed
	finished.emit(kind, true, true)

## Each screen that shows the banner shows the next game.
func set_banner(on: bool) -> void:
	# Ads attaches the backend a frame late, and the title asks for its banner in that frame: the banner waits
	# until this node is in the tree, where it has a screen to measure.
	if not is_inside_tree():
		_pending = on
		if not tree_entered.is_connected(_enter_with_banner):
			tree_entered.connect(_enter_with_banner, CONNECT_ONE_SHOT)
		return
	if Studio.others().is_empty() or (_layer == null and not on):
		return
	if _layer == null:
		_make_banner()
	elif on and not _layer.visible:
		_banner.show_game(next_game())
	_layer.visible = on

func _enter_with_banner() -> void:
	set_banner.call_deferred(_pending)

func stop() -> void:
	_pending = false
	if _layer != null:
		_layer.queue_free()
	_layer = null
	_banner = null
	if _height > 0.0:
		_height = 0.0
		banner_changed.emit(0.0)

static func next_game() -> Dictionary:
	var games: Array[Dictionary] = Studio.others()
	var game: Dictionary = games[_turn % games.size()]
	_turn += 1
	return game

func _make_banner() -> void:
	_height = Ads.banner_height(self)
	_layer = CanvasLayer.new()
	_layer.layer = Ads.BANNER_LAYER
	add_child(_layer)
	_banner = HouseBanner.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Clear of the system navigation and its gesture area, where a swipe home would otherwise land on it.
	_banner.offset_bottom = -Ads.banner_bottom(self)
	_banner.offset_top = _banner.offset_bottom - _height
	_layer.add_child(_banner)
	_banner.show_game(next_game())
	banner_changed.emit(_height)

## The playable in a sheet: the game's name and icon, its board, what it asks, a way to get it, and Close,
## there from the start.
static func playable(host: Node, game: Dictionary) -> Sheet:
	var name: String = game["name"]
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	var head: HBoxContainer = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	var icon: TextureRect = TextureRect.new()
	icon.texture = UI.rounded(load(String(game["icon"])) as Texture2D)
	icon.custom_minimum_size = Vector2(76, 76)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.add_child(icon)
	var names: VBoxContainer = VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	var title: Label = UI.title(name, 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	names.add_child(title)
	var by: Label = UI.caption("Another game from %s" % Studio.NAME, 22)
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	names.add_child(by)
	head.add_child(names)
	c.add_child(head)
	var board: Control = HouseGames.make(name)
	c.add_child(UI.centred(board))
	var ask: Label = UI.label(String(HouseGames.style(name)["ask"]), 26, Brand.MUTED)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(ask)
	board.connect("solved", func() -> void:
		ask.text = "Nicely done. There's plenty more where that came from."
		Analytics.event(&"house_ad", {"game": name, "what": "solved"}))
	var get: Button = UI.button("Get %s" % name, UI.Style.PRIMARY)
	get.pressed.connect(func() -> void:
		Analytics.event(&"house_ad", {"game": name, "what": "get"})
		OS.shell_open(Studio.link(game)))
	c.add_child(get)
	var close: Button = UI.button("Close", UI.Style.GHOST)
	close.pressed.connect(sheet.close)
	c.add_child(close)
	Analytics.event(&"house_ad", {"game": name, "what": "play"})
	return sheet
