extends AdBackend

## Unity LevelPlay through the Intermission plugin (addons/intermission), with Unity Ads as its network. Test ads
## only, unless this is a release build on a phone without the tester switch (TestAds.active), so our own phones
## never add a view or a click to the ad account. Consent comes first where the law asks for it (Consent). The
## studio's house banner holds the strip until a real one loads, and Ads gives a reward anyway when no video
## is ready.

## Seconds before a failed load or start tries again, doubling each time up to the cap.
const RETRY_FIRST: float = 30.0
const RETRY_CAP: float = 600.0
## An ad that has neither shown nor failed this long after `present` is given up on.
const SHOW_TIMEOUT: float = 5.0
## A full-screen ad still up after this long is reported as trouble: a rewarded video and its end card fit in it.
const OVERLONG: float = 75.0
const BANNER_DP: float = 50.0
const PLACEMENTS: Dictionary[StringName, String] = {INTERSTITIAL: "next_level", REWARDED: "reward", &"banner": "screen_foot"}

## Stands in for the Android plugin in tests.
var plugin: Object = null
var _ads: Intermission
var _house: HouseAds
var _starting: bool = false
var _sdk_ready: bool = false
var _stopped: bool = false
var _banner_on: bool = false
var _banner_asked: bool = false
var _banner_loaded: bool = false
var _banner_height: float = 0.0
var _loading: Dictionary[StringName, bool] = {}
var _retry: Dictionary[StringName, float] = {}
var _showing: StringName = &""
## Counts presents, so a give-up timer only ever ends the one it was started for.
var _shows: int = 0
var _shown: bool = false
var _earned: bool = false
## The network that filled the ad on screen, for the trouble report.
var _network: String = ""

func _ready() -> void:
	_house = HouseAds.new()
	add_child(_house)
	_house.banner_changed.connect(func(height: float) -> void:
		if not _banner_loaded:
			banner_changed.emit(height))
	if _banner_on:
		_house.set_banner(true)
	_ads = Intermission.new(plugin)
	add_child(_ads)
	_ads.initialized.connect(_on_initialized)
	_ads.ad_loaded.connect(_on_loaded)
	_ads.ad_failed_to_load.connect(_on_load_failed)
	_ads.ad_shown.connect(_on_shown)
	_ads.ad_failed_to_show.connect(_on_show_failed)
	_ads.ad_closed.connect(_on_closed)
	_ads.app_left.connect(_on_app_left)
	_ads.ad_overlong.connect(_on_overlong)
	_ads.banner_loaded.connect(_on_banner_loaded)
	_ads.banner_failed_to_load.connect(_on_banner_failed)
	_ads.set_overlong_seconds(OVERLONG)
	Consent.ask_if_needed(self, _start_sdk)

## Every way through the consent sheet ends here, so Analytics learns each new answer.
func _start_sdk() -> void:
	Analytics.refresh()
	if _sdk_ready or _starting or _stopped:
		return
	_starting = true
	_apply_consent()
	_ads.set_child_directed(false)
	_ads.initialize(GameMonetize.LEVELPLAY_APP_KEY, TestAds.test_mode())

## The consent answer, sent only where consent is asked for, so the SDK never treats a player elsewhere as having
## refused, and everyone's US choice not to have data sold or shared. Before the SDK starts, and on every change.
func _apply_consent() -> void:
	match Consent.status():
		Consent.Status.GRANTED:
			_ads.set_gdpr_consent(true)
		Consent.Status.DENIED, Consent.Status.UNKNOWN:
			_ads.set_gdpr_consent(false)
	_ads.set_us_privacy_opt_out(Consent.us_opt_out())

func _on_initialized(ok: bool, _error: Intermission.AdError, _code: int, _message: String) -> void:
	_starting = false
	if not ok:
		_later(&"sdk", _start_sdk)
		return
	_sdk_ready = true
	_retry.erase(&"sdk")
	if _stopped:
		return
	_load(INTERSTITIAL)
	_load(REWARDED)
	if _banner_on:
		set_banner(true)

static func _format(kind: StringName) -> Intermission.Format:
	return Intermission.Format.REWARDED if kind == REWARDED else Intermission.Format.INTERSTITIAL

static func _kind(format: int) -> StringName:
	return REWARDED if format == Intermission.Format.REWARDED else INTERSTITIAL

## Test mode asks LevelPlay's demo app whatever the unit, so a unit not yet made in the dashboard still works there.
func _unit(kind: StringName) -> String:
	var unit: String = ""
	match kind:
		INTERSTITIAL:
			unit = GameMonetize.LEVELPLAY_INTERSTITIAL_ID
		REWARDED:
			unit = GameMonetize.LEVELPLAY_REWARDED_ID
		_:
			unit = GameMonetize.LEVELPLAY_BANNER_ID
	return unit if unit != "" else "test_" + String(kind)

func _load(kind: StringName) -> void:
	if not _sdk_ready or _stopped or _loading.get(kind, false) or _ads.is_ad_ready(_unit(kind)):
		return
	_loading[kind] = true
	_ads.load_ad(_format(kind), _unit(kind))

func _on_loaded(format: Intermission.Format, _unit_id: String) -> void:
	var kind: StringName = _kind(format)
	_loading[kind] = false
	_retry.erase(kind)

func _on_load_failed(format: Intermission.Format, _unit_id: String, _error: Intermission.AdError, _code: int,
		_message: String) -> void:
	var kind: StringName = _kind(format)
	_loading[kind] = false
	_later(kind, _load.bind(kind))

## Waits RETRY_FIRST, then twice as long each time, up to RETRY_CAP.
func _later(what: StringName, run: Callable) -> void:
	var wait: float = _retry.get(what, RETRY_FIRST)
	_retry[what] = minf(wait * 2.0, RETRY_CAP)
	get_tree().create_timer(wait).timeout.connect(run)

func ready_to_show(kind: StringName) -> bool:
	return _sdk_ready and not _stopped and _showing == &"" and _ads.is_ad_ready(_unit(kind))

func video_ready() -> bool:
	return ready_to_show(REWARDED)

func present(kind: StringName) -> void:
	if not ready_to_show(kind):
		finished.emit.call_deferred(kind, false, false)
		return
	_showing = kind
	_shown = false
	_earned = false
	_shows += 1
	_ads.show_ad(_unit(kind), PLACEMENTS[kind])
	get_tree().create_timer(SHOW_TIMEOUT).timeout.connect(_give_up.bind(kind, _shows))

func _give_up(kind: StringName, show: int) -> void:
	if show == _shows and _showing == kind and not _shown:
		_end(kind)

func _on_shown(format: Intermission.Format, _unit_id: String, network: String) -> void:
	if _showing == _kind(format):
		_shown = true
		_network = network

func _on_show_failed(format: Intermission.Format, _unit_id: String, _error: Intermission.AdError, _code: int,
		_message: String) -> void:
	_end(_kind(format))

## The plugin waits a moment after a rewarded close for a late reward, so `rewarded` is the answer.
func _on_closed(format: Intermission.Format, _unit_id: String, rewarded: bool) -> void:
	var kind: StringName = _kind(format)
	if kind == REWARDED and rewarded:
		_earned = true
	_end(kind)

func _end(kind: StringName) -> void:
	if _showing != kind:
		return
	_showing = &""
	await get_tree().process_frame
	finished.emit(kind, _shown, _earned)
	_load(kind)

## About the app's health, never advertising: an ad that sent the player away by itself, or one that never ends.
## Such an ad between levels also pauses them for this player (Ads.pause_interstitials).
func _on_app_left(format: Intermission.Format, _unit_id: String, clicked: bool) -> void:
	if not clicked:
		_trouble("left_app", format, 0.0)

func _on_overlong(format: Intermission.Format, _unit_id: String, seconds: float) -> void:
	_trouble("overlong", format, seconds)

func _trouble(what: String, format: Intermission.Format, seconds: float) -> void:
	var formats: PackedStringArray = ["interstitial", "rewarded", "banner"]
	Analytics.event(&"ad_trouble", {"kind": what, "format": formats[format] if format >= 0 else "unknown",
		"network": _network, "seconds": int(seconds), "test": int(_ads.is_test_mode())})
	if format == Intermission.Format.INTERSTITIAL:
		Ads.pause_interstitials()

func set_banner(on: bool) -> void:
	_banner_on = on and not _stopped
	# Asked before _ready, as the title does in the frame before Ads attaches this node: _ready applies it.
	if _house == null:
		return
	_house.set_banner(_banner_on and not _banner_loaded)
	if not _sdk_ready:
		return
	if not _banner_on:
		_ads.hide_banner()
		return
	if not _banner_asked:
		_banner_asked = true
		_ads.load_banner(_unit(&"banner"), Intermission.BannerSize.BANNER, PLACEMENTS[&"banner"])
	_ads.show_banner(Intermission.Anchor.BOTTOM, _clear_dp())

func _on_banner_loaded(_unit_id: String, size_dp: Vector2) -> void:
	_retry.erase(&"banner")
	var height: float = _design_height(maxf(size_dp.y, BANNER_DP))
	if _banner_loaded and is_equal_approx(height, _banner_height):
		return
	var first: bool = not _banner_loaded
	_banner_loaded = true
	_banner_height = height
	if first:
		_house.set_banner(false)
	banner_changed.emit(height)

## A refresh that fails keeps the banner already there.
func _on_banner_failed(_unit_id: String, _error: Intermission.AdError, _code: int, _message: String) -> void:
	if _banner_loaded:
		return
	_banner_asked = false
	_later(&"banner", _retry_banner)

func _retry_banner() -> void:
	if _banner_on and not _banner_asked:
		set_banner(true)

## The banner's bottom, in dp above the screen's foot: the system navigation inset and Ads.gap_dp above it, so a
## swipe home or back never starts on the ad.
func _clear_dp() -> float:
	var density: float = DisplayServer.screen_get_dpi() / 160.0
	if density <= 0.0:
		return Ads.FLOOR_DP
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	var inset_dp: float = maxf(0.0, float(screen.y - safe.end.y)) / density
	return inset_dp + Ads.gap_dp(inset_dp)

## dp to design pixels.
func _design_height(height_dp: float) -> float:
	var pixels: float = height_dp * DisplayServer.screen_get_dpi() / 160.0
	var view: float = get_viewport().get_visible_rect().size.y
	var window: float = float(DisplayServer.window_get_size().y)
	return pixels * view / window if window > 0.0 else pixels

## Privacy choices on every phone with LevelPlay's ads: the US choice is everyone's to make.
func privacy_required() -> bool:
	return true

func open_privacy() -> void:
	Consent.choices(get_tree().root, func() -> void:
		_apply_consent()
		Analytics.refresh())

func stop() -> void:
	_stopped = true
	_banner_on = false
	_house.stop()
	_ads.destroy_banner()
	_banner_asked = false
	if _banner_loaded:
		_banner_loaded = false
		_banner_height = 0.0
		banner_changed.emit(0.0)

func resume() -> void:
	if not _stopped:
		return
	_stopped = false
	if _sdk_ready:
		_load(INTERSTITIAL)
		_load(REWARDED)
	else:
		_start_sdk()
