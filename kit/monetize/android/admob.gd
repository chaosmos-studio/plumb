extends AdBackend

## Google AdMob through the Poing Studios plugin, loaded by Ads on Android only: Google's consent message
## (UMP) first, then the Mobile Ads SDK with ads rated PG at most, then one interstitial and one rewarded
## ad kept loaded. The banner is made the first time a screen wants it and kept for the session.
## Debug builds always ask for Google's test units, so a phone under test never sees a real ad.

const TEST_BANNER: String = "ca-app-pub-3940256099942544/9214589741"
const TEST_INTERSTITIAL: String = "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED: String = "ca-app-pub-3940256099942544/5224354917"
## A failed load waits this long before trying again, doubling each time up to the cap.
const RETRY_FIRST: float = 30.0
const RETRY_CAP: float = 600.0
## A loaded full-screen ad is good for an hour; one older than this is loaded again rather than shown.
const STALE: float = 3300.0
## An ad that has neither shown nor failed this long after `present` is given up on.
const SHOW_TIMEOUT: float = 5.0

var _sdk_ready: bool = false
var _stopped: bool = false
var _banner: AdView
var _banner_on: bool = false
var _banner_loaded: bool = false
var _loaded: Dictionary = {}
var _loaded_at: Dictionary = {}
var _loading: Dictionary = {}
var _retry: Dictionary = {}
var _showing: StringName = &""
var _shown: bool = false
var _earned: bool = false

func _ready() -> void:
	var request: ConsentRequestParameters = ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(request, _on_consent_info, func(_error: FormError) -> void: _start_sdk())
	EventBus.settings_changed.connect(_match_sound)

func _on_consent_info() -> void:
	var info: ConsentInformation = UserMessagingPlatform.consent_information
	if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED and info.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(
			func(form: ConsentForm) -> void: form.show(func(_error: FormError) -> void: _start_sdk()),
			func(_error: FormError) -> void: _start_sdk())
	else:
		_start_sdk()

## What UMP's canRequestAds() answers: a choice made, or none needed. After a failed update this is the
## choice kept from the last session.
func _can_request() -> bool:
	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	return status == ConsentInformation.ConsentStatus.OBTAINED or status == ConsentInformation.ConsentStatus.NOT_REQUIRED

func _start_sdk() -> void:
	if _sdk_ready or _stopped or not _can_request():
		return
	var listener: OnInitializationCompleteListener = OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void: _on_sdk_ready()
	MobileAds.initialize(listener)

func _on_sdk_ready() -> void:
	if _sdk_ready:
		return
	_sdk_ready = true
	var config: RequestConfiguration = RequestConfiguration.new()
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_PG
	MobileAds.set_request_configuration(config)
	_match_sound()
	_load(INTERSTITIAL)
	_load(REWARDED)
	if _banner_on:
		_make_banner()

func _match_sound() -> void:
	if _sdk_ready:
		MobileAds.set_app_muted(not Save.sound_on)

func _unit(kind: StringName) -> String:
	var debug: bool = OS.is_debug_build()
	match kind:
		INTERSTITIAL:
			return TEST_INTERSTITIAL if debug else GameMonetize.INTERSTITIAL_ID
		REWARDED:
			return TEST_REWARDED if debug else GameMonetize.REWARDED_ID
	return TEST_BANNER if debug else GameMonetize.BANNER_ID

# --- Full-screen ads ----------------------------------------------------------------------------------

func _load(kind: StringName) -> void:
	if not _sdk_ready or _stopped or _loading.get(kind, false) or _loaded.has(kind):
		return
	_loading[kind] = true
	if kind == INTERSTITIAL:
		var callback: InterstitialAdLoadCallback = InterstitialAdLoadCallback.new()
		callback.on_ad_loaded = func(ad: InterstitialAd) -> void: _on_loaded(kind, ad)
		callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void: _on_failed(kind)
		InterstitialAdLoader.new().load(_unit(kind), AdRequest.new(), callback)
	else:
		var reward_callback: RewardedAdLoadCallback = RewardedAdLoadCallback.new()
		reward_callback.on_ad_loaded = func(ad: RewardedAd) -> void: _on_loaded(kind, ad)
		reward_callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void: _on_failed(kind)
		RewardedAdLoader.new().load(_unit(kind), AdRequest.new(), reward_callback)

func _on_loaded(kind: StringName, ad: Object) -> void:
	_loading[kind] = false
	_retry[kind] = RETRY_FIRST
	if _stopped:
		ad.call("destroy")
		return
	_loaded[kind] = ad
	_loaded_at[kind] = Time.get_ticks_msec() / 1000.0
	var callback: FullScreenContentCallback = ad.get("full_screen_content_callback")
	callback.on_ad_showed_full_screen_content = func() -> void: _shown = true
	callback.on_ad_dismissed_full_screen_content = func() -> void: _end(kind)
	callback.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void: _end(kind)

func _on_failed(kind: StringName) -> void:
	_loading[kind] = false
	var wait: float = _retry.get(kind, RETRY_FIRST)
	_retry[kind] = minf(wait * 2.0, RETRY_CAP)
	get_tree().create_timer(wait).timeout.connect(func() -> void: _load(kind))

func ready_to_show(kind: StringName) -> bool:
	if not _loaded.has(kind) or _showing != &"":
		return false
	var age: float = Time.get_ticks_msec() / 1000.0 - float(_loaded_at.get(kind, 0.0))
	if age > STALE:
		_drop(kind)
		_load(kind)
		return false
	return true

func present(kind: StringName) -> void:
	if not ready_to_show(kind):
		finished.emit.call_deferred(kind, false, false)
		return
	_showing = kind
	_shown = false
	_earned = false
	var ad: Object = _loaded[kind]
	if kind == REWARDED:
		var listener: OnUserEarnedRewardListener = OnUserEarnedRewardListener.new()
		listener.on_user_earned_reward = func(_item: RewardedItem) -> void: _earned = true
		(ad as RewardedAd).show(listener)
	else:
		(ad as InterstitialAd).show()
	await get_tree().create_timer(SHOW_TIMEOUT).timeout
	if _showing == kind and not _shown:
		_end(kind)

## The ad closed or never showed. The reward callback can land just after the close, so this waits a
## frame before reporting.
func _end(kind: StringName) -> void:
	if _showing != kind:
		return
	_showing = &""
	_drop(kind)
	await get_tree().process_frame
	finished.emit(kind, _shown, _earned)
	_load(kind)

func _drop(kind: StringName) -> void:
	var ad: Object = _loaded.get(kind, null)
	_loaded.erase(kind)
	if ad != null:
		ad.call("destroy")

# --- Banner -------------------------------------------------------------------------------------------

func set_banner(on: bool) -> void:
	_banner_on = on and not _stopped
	if _banner == null:
		if _banner_on:
			_make_banner()
		return
	if _banner_on and _banner_loaded:
		_banner.show()
	else:
		_banner.hide()

func _make_banner() -> void:
	if not _sdk_ready or _banner != null:
		return
	var size: AdSize = AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_banner = AdView.new(_unit(&"banner"), size, AdPosition.BOTTOM)
	_banner.hide()
	var listener: AdListener = AdListener.new()
	listener.on_ad_loaded = _on_banner_loaded
	listener.on_ad_failed_to_load = func(_error: LoadAdError) -> void: _on_banner_failed()
	_banner.ad_listener = listener
	_banner.load_ad(AdRequest.new())

func _on_banner_loaded() -> void:
	_retry[&"banner"] = RETRY_FIRST
	var first: bool = not _banner_loaded
	_banner_loaded = true
	set_banner(_banner_on)
	if first:
		banner_changed.emit(_design_height())

func _on_banner_failed() -> void:
	if _banner_loaded:
		return
	_banner.destroy()
	_banner = null
	var wait: float = _retry.get(&"banner", RETRY_FIRST)
	_retry[&"banner"] = minf(wait * 2.0, RETRY_CAP)
	get_tree().create_timer(wait).timeout.connect(func() -> void:
		if _banner_on:
			_make_banner())

## The banner's height in the game's design pixels, which every layout in the kit is written in: its size
## in dp at the screen's density, or the laid-out view if that is taller, so it is never underestimated.
func _design_height() -> float:
	var pixels: float = maxf(float(_banner.ad_size.height), 50.0) * DisplayServer.screen_get_dpi() / 160.0
	pixels = maxf(pixels, float(_banner.get_height_in_pixels()))
	var view: float = get_viewport().get_visible_rect().size.y
	var window: float = float(DisplayServer.window_get_size().y)
	return pixels * view / window if window > 0.0 else pixels

# --- Privacy and the Supporter pack -------------------------------------------------------------------

func privacy_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

func open_privacy() -> void:
	UserMessagingPlatform.show_privacy_options_form(func(_error: FormError) -> void: _start_sdk())

func stop() -> void:
	_stopped = true
	_banner_on = false
	if _banner != null:
		_banner.destroy()
		_banner = null
	if _banner_loaded:
		_banner_loaded = false
		banner_changed.emit(0.0)
	for kind: StringName in [INTERSTITIAL, REWARDED]:
		if _showing != kind:
			_drop(kind)

func resume() -> void:
	if not _stopped:
		return
	_stopped = false
	if _sdk_ready:
		_load(INTERSTITIAL)
		_load(REWARDED)
	else:
		_start_sdk()
