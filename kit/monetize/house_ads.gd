class_name HouseAds
extends AdBackend

## The studio's own ads: a banner for another of its games where an ad's banner would be, and nothing else. No
## interstitials and no stand-in for a video, since a reward with no video to play is simply given (Ads.rewarded).
## They stand in for AdMob while it is switched off (GameMonetize.ADMOB false), and fill the banner's strip under
## it whenever it has none to give. Standing in on Android, they still ask Google's consent service whether this
## phone needs consent, since Analytics waits on that answer before it counts.

## The game the next banner shows: they take turns.
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

func ready_to_show(_kind: StringName) -> bool:
	return false

func present(kind: StringName) -> void:
	finished.emit.call_deferred(kind, false, false)

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
