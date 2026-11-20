extends RefCounted

## Stands in for the Intermission plugin's Android singleton (addons/intermission): its method names and its
## signals, with the plain arguments the Kotlin side sends. A test plays the SDK's part with emit_signal.

signal initialized(ok: bool, error: String, code: int, message: String)
signal ad_loaded(format: String, ad_unit_id: String)
signal ad_failed_to_load(format: String, ad_unit_id: String, error: String, code: int, message: String)
signal ad_shown(format: String, ad_unit_id: String, network: String)
signal ad_failed_to_show(format: String, ad_unit_id: String, error: String, code: int, message: String)
signal ad_clicked(format: String, ad_unit_id: String)
signal ad_rewarded(ad_unit_id: String, reward_name: String, amount: int)
signal ad_closed(format: String, ad_unit_id: String, rewarded: bool)
signal app_left(format: String, ad_unit_id: String, clicked: bool)
signal ad_overlong(format: String, ad_unit_id: String, seconds: float)
signal banner_loaded(ad_unit_id: String, width_dp: int, height_dp: int)
signal banner_failed_to_load(ad_unit_id: String, error: String, code: int, message: String)
signal banner_shown(ad_unit_id: String, network: String)
signal banner_clicked(ad_unit_id: String)

var calls: PackedStringArray = []
var ready_units: PackedStringArray = []
var test_mode: bool = false

func initialize(app_key: String, test: bool) -> void:
	test_mode = test
	calls.append("initialize %s %s" % [app_key, test])

func isInitialized() -> bool:
	return calls.has("initialize")

func isTestMode() -> bool:
	return test_mode

func providerName() -> String:
	return "levelplay"

func sdkVersion() -> String:
	return "9.8.0"

func setGdprConsent(granted: bool) -> void:
	calls.append("gdpr %s" % granted)

func setUsPrivacyOptOut(opted_out: bool) -> void:
	calls.append("ccpa %s" % opted_out)

func setChildDirected(child: bool) -> void:
	calls.append("coppa %s" % child)

func loadAd(format: String, ad_unit_id: String) -> void:
	calls.append("load %s %s" % [format, ad_unit_id])

func isAdReady(ad_unit_id: String) -> bool:
	return ready_units.has(ad_unit_id)

func showAd(ad_unit_id: String, placement: String) -> void:
	calls.append("show %s %s" % [ad_unit_id, placement])
	if ready_units.has(ad_unit_id):
		ready_units.remove_at(ready_units.find(ad_unit_id))

func loadBanner(ad_unit_id: String, size: String, placement: String) -> void:
	calls.append("banner %s %s %s" % [ad_unit_id, size, placement])

func showBanner(anchor: String, _x_dp: float, _y_dp: float) -> void:
	calls.append("show banner %s" % anchor)

func hideBanner() -> void:
	calls.append("hide banner")

func destroyBanner() -> void:
	calls.append("destroy banner")

func bannerSizeDp() -> PackedInt32Array:
	return PackedInt32Array([320, 50])

func setOverlongSeconds(seconds: float) -> void:
	calls.append("overlong %s" % seconds)

func enableTestSuite() -> void:
	calls.append("test suite")

func openTestSuite() -> void:
	calls.append("open test suite")

## Plays a load answered by the SDK.
func fill(format: String, ad_unit_id: String) -> void:
	ready_units.append(ad_unit_id)
	ad_loaded.emit(format, ad_unit_id)
