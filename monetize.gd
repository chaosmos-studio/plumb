class_name GameMonetize
extends RefCounted

## Ids ship inside the app, so none of them is a secret. Debug builds and testers' phones ask for test ads
## whatever they say (TestAds).

## Unity LevelPlay's ads, with the studio's own house banner filling the strip whenever LevelPlay has no banner to
## give, and every reward free while it has no video. With false, the house banner alone.
const ADS: bool = true
## Plumb's app and ad units in LevelPlay (platform.ironsrc.com, Shravan's account).
const LEVELPLAY_APP_KEY: String = "29be3810d"
const LEVELPLAY_BANNER_ID: String = "tcj6tlx7qhb23bln"
const LEVELPLAY_INTERSTITIAL_ID: String = "byvlmfgnvbcz3uyz"
## Its reward in the dashboard is "Hints", 3, as AdPacing.VIDEO_HINTS gives.
const LEVELPLAY_REWARDED_ID: String = "5s41z91uj1rfif7x"
## Unity Ads, the network LevelPlay calls, from the Unity dashboard. They are entered in LevelPlay when it
## connects Unity Ads, never passed to the SDK: its bidding placements are filled only through LevelPlay.
const UNITY_GAME_ID: String = "800447033"
const UNITY_ORGANIZATION_CORE_ID: String = "13470005808211"
const UNITY_PLACEMENTS: PackedStringArray = ["BP_Banner_Android", "BP_Interstitial_Android", "BP_Rewarded_Android"]
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
