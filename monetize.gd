class_name GameMonetize
extends RefCounted

## Plumb's AdMob app and ad units and its Supporter pack product, read by the kit's Ads and Supporter.
## Ids ship inside the app, so none of them is a secret; debug builds load Google's test units instead.
## Keep the project setting admob/general/android/app_id equal to APP_ID: the AdMob plugin writes that
## setting into the manifest, and a test checks the two agree.

const APP_ID: String = "ca-app-pub-3135321730568420~4276024954"
const BANNER_ID: String = "ca-app-pub-3135321730568420/4401816337"
const INTERSTITIAL_ID: String = "ca-app-pub-3135321730568420/1199928764"
const REWARDED_ID: String = "ca-app-pub-3135321730568420/9789874380"
## One-time products in Play Console, under Monetize with Play, Products, One-time products: the Supporter
## pack, Every level, the Looks pack (Plumb's marble sets), the Themes pack (the kit's colour themes) and
## the Complete pack, which holds all four.
const SUPPORTER_ID: String = "supporter"
const LEVELS_ID: String = "all_levels"
const LOOKS_ID: String = "looks"
const THEMES_ID: String = "themes"
const COMPLETE_ID: String = "complete"
## The tip jar, smallest first: one-time products too, but consumed after each purchase so they can be
## bought again. Named for their intended US prices: 0.99, 1.99, 4.99, 9.99, 19.99 and 49.99.
const TIP_IDS: PackedStringArray = ["tip_1", "tip_2", "tip_5", "tip_10", "tip_20", "tip_50"]
## Level keys, consumed the same way: one key, and five for less. Each opens any one locked level for good.
const KEY_IDS: PackedStringArray = ["level_key", "level_keys_5"]
const KEY_COUNTS: PackedInt32Array = [1, 5]
