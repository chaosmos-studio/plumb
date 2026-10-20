class_name Ads
extends RefCounted

## An ad that is not loaded simply does not show, so the game never waits for one.
##
## The kit expects from the game:
## - `GameMonetize` (res://monetize.gd) with ADMOB, APP_ID, BANNER_ID, INTERSTITIAL_ID, REWARDED_ID and
##   SUPPORTER_ID. Debug builds use Google's test units whatever it says. With ADMOB false the studio's own
##   house ads stand in (HouseAds), one line to switch back. With it on they still fill in, under AdMob,
##   whenever AdMob has no banner or video to give.
## - The AdMob plugin in addons/admob, enabled, with the project setting admob/general/android/app_id
##   equal to GameMonetize.APP_ID, since the plugin writes that setting into the manifest.
## - Save._ready calling `Supporter.start()` and then `Ads.start()` once progress is restored.
## - `EventBus.level_won` on every solve, `Save.best`, `Pack.count`, and `Save.sound_on`, since ads start
##   muted for a player who turned sound off.
## - The play screen calling `RatePrompt.or_ad` on its Next level path and nowhere else, and routing its
##   hint through HintGate.

## Any phone in portrait gets about the same adaptive banner, so the stand-in assumes one width.
const PREVIEW_WIDTH_DP: float = 360.0

## Desktop captures only: shows a stand-in banner at the real adaptive size.
static var preview: bool = false
## Lets a robot skip the pacing gaps without waiting.
static var skew: float = 0.0

static var _backend: AdBackend
static var _since: int = 0
static var _last_fullscreen: float = -1.0
static var _busy: bool = false
static var _wanted: bool = false
static var _covers: int = 0
static var _height: float = 0.0
static var _on_height: Callable = Callable()
static var _stand_in: CanvasLayer

## Supporter calls this again when Play says the pack is no longer owned.
static func start() -> void:
	if not EventBus.level_won.is_connected(_on_solved):
		EventBus.level_won.connect(_on_solved)
	if Supporter.active():
		return
	if is_instance_valid(_backend):
		_backend.resume()
		return
	if not OS.has_feature("android"):
		return
	if not GameMonetize.ADMOB:
		_attach(HouseAds.new(), true)
		return
	if not Engine.has_singleton("PoingGodotAdMob"):
		return
	var admob: GDScript = load("res://kit/monetize/android/admob.gd")
	_attach(admob.new(), true)

## How a reward is earned, for the buttons that offer one: a video when AdMob has one ready, and otherwise a
## game of the studio's.
static func watch() -> String:
	return "Watch a video" if video_ready() else "Try a quick game"

static func with_one() -> String:
	return "with a video" if video_ready() else "with a quick game"

static func video_ready() -> bool:
	return live() and _backend.video_ready()

static func use(backend: AdBackend) -> void:
	if is_instance_valid(_backend):
		_backend.queue_free()
	_backend = null
	_since = 0
	_last_fullscreen = -1.0
	_busy = false
	_height = 0.0
	if backend != null:
		_attach(backend, false)

static func live() -> bool:
	return is_instance_valid(_backend) and not Supporter.active()

static func rewards() -> bool:
	return live()

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0 + skew

static func solved() -> int:
	var n: int = 0
	for i: int in range(Pack.count()):
		if Save.best(i) > 0:
			n += 1
	return n

## `on_height` hears the banner height in design pixels on every change, and 0 when it goes.
static func show_banner(host: Node, on_height: Callable) -> void:
	_wanted = AdPacing.banner_due(solved(), Supporter.active()) and (preview or live())
	_on_height = on_height
	if not _wanted:
		return
	if preview:
		_show_stand_in(host)
		return
	if _height > 0.0:
		on_height.call(_height)
	_backend.set_banner(_covers == 0)

## A play screen reserves this from its first frame, so its board never jumps when the ad arrives.
static func expected_banner_height(host: Node) -> float:
	if not AdPacing.banner_due(solved(), Supporter.active()) or not (preview or live()):
		return 0.0
	if _height > 0.0:
		return _height
	return banner_height(host)

## The height a phone's adaptive banner takes, in design pixels.
static func banner_height(host: Node) -> float:
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var dpi: float = float(DisplayServer.screen_get_dpi())
	var width_dp: float = window.x * 160.0 / dpi if dpi > 0.0 and window.x > 0.0 else PREVIEW_WIDTH_DP
	var per_dp: float = view.x / width_dp
	return adaptive_height_dp(width_dp, view.y / per_dp) * per_dp

static func hide_banner() -> void:
	_wanted = false
	_on_height = Callable()
	if is_instance_valid(_stand_in):
		_stand_in.queue_free()
	_stand_in = null
	if live():
		_backend.set_banner(false)

## The banner's height while it is on screen, else 0: what a Sheet that keeps the banner leaves clear below it.
static func banner_room() -> float:
	return _height if _wanted and _covers == 0 and (preview or live()) else 0.0

## A Sheet calls this as it opens and closes, so the banner is never on screen with one, except one that keeps
## it in a strip of its own below the panel (Sheet.keeps_banner).
static func cover(on: bool) -> void:
	_covers = maxi(_covers + (1 if on else -1), 0)
	if is_instance_valid(_stand_in):
		_stand_in.visible = _covers == 0
	if _wanted and live():
		_backend.set_banner(_covers == 0)

## Google's anchored adaptive banner height: in proportion to a 320 by 50 banner, never under 50 dp, and
## never over 90 dp or 15% of the screen.
static func adaptive_height_dp(width: float, height: float) -> float:
	var most: float = maxf(50.0, minf(90.0, roundf(height * 0.15)))
	return clampf(roundf(width * 50.0 / 320.0), 50.0, most)

static func maybe_interstitial(on_done: Callable, after_guide: bool = false) -> void:
	if after_guide or _busy or not live() or not interstitial_due() \
			or not _backend.ready_to_show(AdBackend.INTERSTITIAL):
		on_done.call()
		return
	_busy = true
	_backend.present(AdBackend.INTERSTITIAL)
	var result: Array = await _backend.finished
	_busy = false
	if bool(result[1]):
		_last_fullscreen = now()
		_since = 0
	if on_done.is_valid():
		on_done.call()

static func interstitial_due() -> bool:
	return AdPacing.interstitial_due(solved(), _since, now(), _last_fullscreen, Supporter.active())

## `on_unavailable` runs when no video can play (offline, no fill, consent refused). A video closed early
## runs neither callback.
static func rewarded(on_reward: Callable, on_unavailable: Callable) -> void:
	if _busy or not live() or not _backend.ready_to_show(AdBackend.REWARDED):
		on_unavailable.call()
		return
	_busy = true
	_backend.present(AdBackend.REWARDED)
	var result: Array = await _backend.finished
	_busy = false
	var shown: bool = result[1]
	if shown:
		_last_fullscreen = now()
	if bool(result[2]):
		if on_reward.is_valid():
			on_reward.call()
	elif not shown and on_unavailable.is_valid():
		on_unavailable.call()

## UMP says whether the player must be able to change their consent. Settings shows Privacy choices only
## then.
static func privacy_options_required() -> bool:
	return live() and _backend.privacy_required()

static func open_privacy_options() -> void:
	if live():
		_backend.open_privacy()

static func stop() -> void:
	if is_instance_valid(_backend):
		_backend.stop()
	if is_instance_valid(_stand_in):
		_stand_in.queue_free()
	_stand_in = null
	_on_banner(0.0)
	_wanted = false

static func _attach(backend: AdBackend, deferred: bool) -> void:
	_backend = backend
	backend.banner_changed.connect(_on_banner)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if deferred:
		tree.root.add_child.call_deferred(backend)
	else:
		tree.root.add_child(backend)

static func _on_banner(height: float) -> void:
	_height = height
	if _wanted and _on_height.is_valid():
		_on_height.call(height)

static func _on_solved(_level: int, _count: int, _stars: int) -> void:
	_since += 1

static func _show_stand_in(host: Node) -> void:
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	var per_dp: float = view.x / PREVIEW_WIDTH_DP
	var height: float = adaptive_height_dp(PREVIEW_WIDTH_DP, view.y / per_dp) * per_dp
	_stand_in = CanvasLayer.new()
	_stand_in.layer = 55
	_stand_in.visible = _covers == 0
	host.add_child(_stand_in)
	# With AdMob off the stand-in is the house banner itself, as a phone would show it.
	var box: Control = _StandIn.new() if GameMonetize.ADMOB or Studio.others().is_empty() else HouseBanner.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -height
	_stand_in.add_child(box)
	if box is HouseBanner:
		(box as HouseBanner).show_game(HouseAds.next_game())
	_on_banner(height)

## A real ad's neutral colours, whatever the theme.
class _StandIn extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("f1f1f1"))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 2.0)), Color("d6d6d6"))
		var font: Font = UI.ui_font()
		var text: String = "Test ad"
		var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		draw_string(font, Vector2((size.x - ts.x) * 0.5, size.y * 0.5 + 9.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
			Color("8a8a8a"))
