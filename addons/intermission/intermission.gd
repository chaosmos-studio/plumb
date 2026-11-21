class_name Intermission
extends Node

## Ads from Unity LevelPlay, with Unity Ads, on Android.
##
## Add one to the tree (or as an autoload), connect its signals, then [method initialize]. Every call returns at
## once, and every answer comes back as a signal on Godot's thread.
## [br][br]
## Off Android, or in a build without the plugin, [method available] is false and every request answers with
## [constant NOT_AVAILABLE] on the next frame, just as a network with no ads would, so a game needs no second path.

enum Format { INTERSTITIAL, REWARDED, BANNER }
enum BannerSize { BANNER, LARGE, MEDIUM_RECTANGLE, LEADERBOARD, ADAPTIVE }
enum Anchor { TOP, BOTTOM }
enum AdError {
	NONE,
	## The plugin is not in this build, or this is not Android.
	NOT_AVAILABLE,
	NOT_INITIALIZED,
	INIT_FAILED,
	INVALID_ARGUMENT,
	NOT_LOADED,
	ALREADY_SHOWING,
	NO_ACTIVITY,
	NO_FILL,
	NO_CONNECTION,
	TIMEOUT,
	CAPPED,
	EXPIRED,
	## Anything else the SDK reported, with its own code and message beside it.
	PROVIDER,
}

## The format a signal carries for an ad unit that was never loaded.
const UNKNOWN_FORMAT: int = -1

## [param error] is [constant NONE] when [param ok].
signal initialized(ok: bool, error: AdError, provider_code: int, message: String)
signal ad_loaded(format: Format, ad_unit_id: String)
signal ad_failed_to_load(format: Format, ad_unit_id: String, error: AdError, provider_code: int, message: String)
## [param network] names the ad network that filled the ad.
signal ad_shown(format: Format, ad_unit_id: String, network: String)
signal ad_failed_to_show(format: Format, ad_unit_id: String, error: AdError, provider_code: int, message: String)
signal ad_clicked(format: Format, ad_unit_id: String)
## The full-screen ad is gone. [param rewarded] is true once a rewarded ad has earned its reward.
signal ad_closed(format: Format, ad_unit_id: String, rewarded: bool)
## Again on every refresh.
signal banner_loaded(ad_unit_id: String, size_dp: Vector2)
signal banner_failed_to_load(ad_unit_id: String, error: AdError, provider_code: int, message: String)
## Something outside the app (a store page, another app, the home screen) covered an ad. With [param clicked] false,
## nobody tapped the ad first: it sent the player away by itself, or the player left.
signal app_left(format: Format, ad_unit_id: String, clicked: bool)
## A full-screen ad is still up after the time set with [method set_overlong_seconds].
signal ad_overlong(format: Format, ad_unit_id: String, seconds: float)

const _SINGLETON: String = "IntermissionAndroid"
const _FORMATS: PackedStringArray = ["interstitial", "rewarded", "banner"]
const _SIZES: PackedStringArray = ["banner", "large", "medium_rectangle", "leaderboard", "adaptive"]
const _ANCHORS: PackedStringArray = ["top", "bottom"]
const _ERRORS: PackedStringArray = [
	"none", "not_available", "not_initialized", "init_failed", "invalid_argument", "not_loaded", "already_showing",
	"no_activity", "no_fill", "no_connection", "timeout", "capped", "expired", "provider",
]
const _NOT_AVAILABLE: String = "Intermission runs only in an Android build with the plugin enabled."

var _plugin: Object

## [param plugin] stands in for the Android singleton, for tests.
func _init(plugin: Object = null) -> void:
	_plugin = plugin
	if _plugin == null and Engine.has_singleton(_SINGLETON):
		_plugin = Engine.get_singleton(_SINGLETON)
	if _plugin != null:
		_listen()

func available() -> bool:
	return _plugin != null

## In test mode every ad comes from LevelPlay's public demo app, never your own, and [param app_key] may be empty.
func initialize(app_key: String, test_mode: bool = false) -> void:
	if _plugin == null:
		initialized.emit.call_deferred(false, AdError.NOT_AVAILABLE, 0, _NOT_AVAILABLE)
		return
	_plugin.call(&"initialize", app_key, test_mode)

func is_initialized() -> bool:
	return _plugin != null and bool(_plugin.call(&"isInitialized"))

func is_test_mode() -> bool:
	return _plugin != null and bool(_plugin.call(&"isTestMode"))

func sdk_version() -> String:
	return String(_plugin.call(&"sdkVersion")) if _plugin != null else ""

## Consent for personalised ads where a law asks for it (the EEA, the UK, Switzerland). Set it before
## [method initialize], and again whenever the player changes it.
func set_gdpr_consent(granted: bool) -> void:
	if _plugin != null:
		_plugin.call(&"setGdprConsent", granted)

## A US player's choice not to have their data sold or shared.
func set_us_privacy_opt_out(opted_out: bool) -> void:
	if _plugin != null:
		_plugin.call(&"setUsPrivacyOptOut", opted_out)

## For apps directed at children.
func set_child_directed(child: bool) -> void:
	if _plugin != null:
		_plugin.call(&"setChildDirected", child)

## Interstitial and rewarded ads, one loaded ad per ad unit. Loads asked for before the SDK is ready wait for it.
func load_ad(format: Format, ad_unit_id: String) -> void:
	if _plugin == null:
		ad_failed_to_load.emit.call_deferred(format, ad_unit_id, AdError.NOT_AVAILABLE, 0, _NOT_AVAILABLE)
		return
	_plugin.call(&"loadAd", _wire(_FORMATS, format), ad_unit_id)

func is_ad_ready(ad_unit_id: String) -> bool:
	return _plugin != null and bool(_plugin.call(&"isAdReady", ad_unit_id))

## [param placement] names the moment in the dashboard's reports. It may be empty.
func show_ad(ad_unit_id: String, placement: String = "") -> void:
	if _plugin == null:
		ad_failed_to_show.emit.call_deferred(UNKNOWN_FORMAT, ad_unit_id, AdError.NOT_AVAILABLE, 0, _NOT_AVAILABLE)
		return
	_plugin.call(&"showAd", ad_unit_id, placement)

## One banner at a time: loading another replaces it. It stays hidden until [method show_banner].
func load_banner(ad_unit_id: String, size: BannerSize = BannerSize.BANNER, placement: String = "") -> void:
	if _plugin == null:
		banner_failed_to_load.emit.call_deferred(ad_unit_id, AdError.NOT_AVAILABLE, 0, _NOT_AVAILABLE)
		return
	_plugin.call(&"loadBanner", ad_unit_id, _wire(_SIZES, size), placement)

## Centred at the top or the bottom, [param margin_dp] in from that edge. A hidden banner does not refresh.
func show_banner(anchor: Anchor = Anchor.BOTTOM, margin_dp: float = 0.0) -> void:
	if _plugin != null:
		_plugin.call(&"showBanner", _wire(_ANCHORS, anchor), margin_dp)

func hide_banner() -> void:
	if _plugin != null:
		_plugin.call(&"hideBanner")

func destroy_banner() -> void:
	if _plugin != null:
		_plugin.call(&"destroyBanner")

## Turns on [signal ad_overlong] for full-screen ads up longer than [param seconds]. Off (0) by default.
func set_overlong_seconds(seconds: float) -> void:
	if _plugin != null:
		_plugin.call(&"setOverlongSeconds", seconds)

## LevelPlay's integration test suite, in debug builds and test mode, once initialized.
func open_test_suite() -> void:
	if _plugin != null:
		_plugin.call(&"openTestSuite")

func _listen() -> void:
	_plugin.connect(&"initialized", _on_initialized)
	_plugin.connect(&"ad_loaded", _on_ad_loaded)
	_plugin.connect(&"ad_failed_to_load", _on_ad_failed_to_load)
	_plugin.connect(&"ad_shown", _on_ad_shown)
	_plugin.connect(&"ad_failed_to_show", _on_ad_failed_to_show)
	_plugin.connect(&"ad_clicked", _on_ad_clicked)
	_plugin.connect(&"ad_closed", _on_ad_closed)
	_plugin.connect(&"banner_loaded", _on_banner_loaded)
	_plugin.connect(&"banner_failed_to_load", _on_banner_failed_to_load)
	_plugin.connect(&"app_left", _on_app_left)
	_plugin.connect(&"ad_overlong", _on_ad_overlong)

func _on_initialized(ok: bool, error: String, code: int, message: String) -> void:
	initialized.emit(ok, _error(error), code, message)

func _on_ad_loaded(format: String, ad_unit_id: String) -> void:
	ad_loaded.emit(_format(format), ad_unit_id)

func _on_ad_failed_to_load(format: String, ad_unit_id: String, error: String, code: int, message: String) -> void:
	ad_failed_to_load.emit(_format(format), ad_unit_id, _error(error), code, message)

func _on_ad_shown(format: String, ad_unit_id: String, network: String) -> void:
	ad_shown.emit(_format(format), ad_unit_id, network)

func _on_ad_failed_to_show(format: String, ad_unit_id: String, error: String, code: int, message: String) -> void:
	ad_failed_to_show.emit(_format(format), ad_unit_id, _error(error), code, message)

func _on_ad_clicked(format: String, ad_unit_id: String) -> void:
	ad_clicked.emit(_format(format), ad_unit_id)

func _on_ad_closed(format: String, ad_unit_id: String, rewarded: bool) -> void:
	ad_closed.emit(_format(format), ad_unit_id, rewarded)

func _on_banner_loaded(ad_unit_id: String, width_dp: int, height_dp: int) -> void:
	banner_loaded.emit(ad_unit_id, Vector2(width_dp, height_dp))

func _on_banner_failed_to_load(ad_unit_id: String, error: String, code: int, message: String) -> void:
	banner_failed_to_load.emit(ad_unit_id, _error(error), code, message)

func _on_app_left(format: String, ad_unit_id: String, clicked: bool) -> void:
	app_left.emit(_format(format), ad_unit_id, clicked)

func _on_ad_overlong(format: String, ad_unit_id: String, seconds: float) -> void:
	ad_overlong.emit(_format(format), ad_unit_id, seconds)

static func _wire(names: PackedStringArray, value: int) -> String:
	return names[value] if value >= 0 and value < names.size() else ""

static func _format(wire: String) -> int:
	return _FORMATS.find(wire)

static func _error(wire: String) -> AdError:
	var index: int = _ERRORS.find(wire)
	return AdError.PROVIDER if index < 0 else index as AdError
