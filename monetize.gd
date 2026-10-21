class_name GameMonetize
extends RefCounted

## Ids ship inside the app, so none of them is a secret. Debug builds load Google's test units instead.
## Keep the project setting admob/general/android/app_id equal to APP_ID: the AdMob plugin writes that
## setting into the manifest, and a test checks the two agree.

## AdMob's ads, with the studio's own house ads (banners and playable tastes of its other games) filling in
## whenever AdMob has nothing to give, as before the account is approved. With false, house ads alone.
const ADMOB: bool = true
const APP_ID: String = "ca-app-pub-3135321730568420~4276024954"
const BANNER_ID: String = "ca-app-pub-3135321730568420/4401816337"
const INTERSTITIAL_ID: String = "ca-app-pub-3135321730568420/1199928764"
const REWARDED_ID: String = "ca-app-pub-3135321730568420/9789874380"
## Each must match a one-time product in Play Console (Monetize with Play, Products, One-time products).
## The Complete pack holds the other four.
const SUPPORTER_ID: String = "supporter"
const LEVELS_ID: String = "all_levels"
const LOOKS_ID: String = "looks"
const THEMES_ID: String = "themes"
const COMPLETE_ID: String = "complete"
## Consumed after each purchase, like the tips: each one keeps one missed daily puzzle for the streak.
const STREAK_ID: String = "streak_keeper"
## Smallest first, and consumed after each purchase so they can be bought again. Named for their intended
## US prices: 0.99, 1.99, 4.99, 9.99, 19.99 and 49.99.
const TIP_IDS: PackedStringArray = ["tip_1", "tip_2", "tip_5", "tip_10", "tip_20", "tip_50"]
## Consumed the same way. Each key opens any one locked level for good.
const KEY_IDS: PackedStringArray = ["level_key", "level_keys_5"]
const KEY_COUNTS: PackedInt32Array = [1, 5]
