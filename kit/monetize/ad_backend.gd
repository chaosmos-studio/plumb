class_name AdBackend
extends Node

## What the Ads facade asks of an ad network. This base has no ads at all, which is every build but
## Android's; the AdMob backend (android/admob.gd) and the test robots' mock fill it in. It lives in the
## tree for as long as the app runs, since the plugin calls back into it.

## The loaded banner's height in design pixels, or 0 once there is none. Whether it shows is `set_banner`.
signal banner_changed(height: float)
## A full-screen ad is over: whether it showed, and for a video whether it was watched to the reward.
## Emitted once for every `present`, and never from inside it.
signal finished(kind: StringName, shown: bool, earned: bool)

const INTERSTITIAL: StringName = &"interstitial"
const REWARDED: StringName = &"rewarded"

func ready_to_show(_kind: StringName) -> bool:
	return false

func present(kind: StringName) -> void:
	finished.emit.call_deferred(kind, false, false)

## Shows the banner, loading it first if need be, or hides it.
func set_banner(_on: bool) -> void:
	pass

func privacy_required() -> bool:
	return false

func open_privacy() -> void:
	pass

## A Supporter: nothing more is loaded or shown.
func stop() -> void:
	pass

## The pack is no longer owned: back to loading ads.
func resume() -> void:
	pass
