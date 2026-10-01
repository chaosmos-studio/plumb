class_name Ads
extends RefCounted

## The ads, in the Android build only: one banner at the foot of the level grid, now and then an ad
## between levels, and a short video for a hint once the day's free ones are used. AdPacing decides when;
## this runs them and never makes the game wait, because an ad that is not loaded simply does not show.
## In every other build, and for a Supporter, each call answers "not available" at once.
##
## The kit expects from the game:
## - `GameMonetize` (res://monetize.gd) with APP_ID, BANNER_ID, INTERSTITIAL_ID, REWARDED_ID and
##   SUPPORTER_ID. Debug builds ask for Google's test units whatever it says.
## - The AdMob plugin in addons/admob, enabled, and the project setting admob/general/android/app_id equal
##   to GameMonetize.APP_ID, since the plugin writes that setting into the manifest.
## - Save._ready calling `Supporter.start()` and then `Ads.start()` once progress is restored.
## - `EventBus.level_won(index, count, stars)` on every solve, `Save.best` and `Pack.count` to count the
##   levels solved, and `Save.sound_on`, since ads start muted for a player who turned sound off.
## - The play screen calling `maybe_interstitial` on its Next level path and nowhere else, and routing its
##   hint through HintGate. The Levels screen and every Sheet already do their part.

## The phone the stand-in banner assumes, in dp. Any phone in portrait gets about the same banner.
const PREVIEW_WIDTH_DP: float = 360.0

## Captures on a desktop only: the Levels screen gets a stand-in banner of the real adaptive size.
static var preview: bool = false
## Seconds added to the session clock, so a robot need not wait out the pacing gaps.
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

## Consent, then the SDK, then one ad of each kind loaded. On Android only, and not for a Supporter; the
## Supporter class calls it again if Play says the pack is no longer owned.
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
	if not Engine.has_singleton("PoingGodotAdMob"):
		return
	var admob: GDScript = load("res://kit/monetize/android/admob.gd")
	_attach(admob.new(), true)

## Puts another backend in place with a fresh session, for the robots' mock; null leaves none.
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

## Whether any ad could show here, for this player.
static func live() -> bool:
	return is_instance_valid(_backend) and not Supporter.active()

## Whether a hint may ask for a video. Where it cannot, every hint is free.
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

# --- Banner -------------------------------------------------------------------------------------------

## The Levels screen's banner, once enough levels are solved. `on_height` hears its height in design
## pixels whenever that changes, and 0 when it goes, so the screen can lift its controls clear of it.
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

## The banner's height in design pixels if a screen asking now would get one: the real one once a banner
## has loaded this session, Google's adaptive height for this screen before that, and 0 when none is
## due. A play screen reserves this from its first frame, so its board never jumps when the ad arrives.
static func expected_banner_height(host: Node) -> float:
	if not AdPacing.banner_due(solved(), Supporter.active()) or not (preview or live()):
		return 0.0
	if _height > 0.0:
		return _height
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

## Every Sheet calls this as it opens and closes, so the banner is never on screen with one.
static func cover(on: bool) -> void:
	_covers = maxi(_covers + (1 if on else -1), 0)
	if is_instance_valid(_stand_in):
		_stand_in.visible = _covers == 0
	if _wanted and live():
		_backend.set_banner(_covers == 0)

## The height Google gives an anchored adaptive banner `width` dp wide on a screen `height` dp tall: in
## proportion to a 320 by 50 banner, never under 50 dp, and never over 90 dp or 15% of the screen.
static func adaptive_height_dp(width: float, height: float) -> float:
	var most: float = maxf(50.0, minf(90.0, roundf(height * 0.15)))
	return clampf(roundf(width * 50.0 / 320.0), 50.0, most)

# --- Full-screen ads ----------------------------------------------------------------------------------

## The Next level path: an ad between levels if AdPacing allows one and one is loaded, then `on_done`,
## which otherwise runs at once. `after_guide` is true when the level just solved was guided.
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

## A short video for a hint. `on_reward` runs once it is watched through and `on_unavailable` when none
## can play (offline, no fill, consent refused). A video closed early runs neither.
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

# --- Privacy and the Supporter pack -------------------------------------------------------------------

## Whether the consent message says the player must be able to change their choices: Settings then shows
## Privacy choices.
static func privacy_options_required() -> bool:
	return live() and _backend.privacy_required()

static func open_privacy_options() -> void:
	if live():
		_backend.open_privacy()

## The Supporter pack was bought: the banner goes, and nothing more is loaded.
static func stop() -> void:
	if is_instance_valid(_backend):
		_backend.stop()
	if is_instance_valid(_stand_in):
		_stand_in.queue_free()
	_stand_in = null
	_on_banner(0.0)
	_wanted = false

# --- Internals ----------------------------------------------------------------------------------------

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
	var box: _StandIn = _StandIn.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -height
	_stand_in.add_child(box)
	_on_banner(height)

## A plain box where the banner would be, drawn in a real ad's neutral colours on either theme.
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
