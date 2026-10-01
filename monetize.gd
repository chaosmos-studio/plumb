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
## A one-time product in Play Console, under Monetize with Play, Products, In-app products.
const SUPPORTER_ID: String = "supporter"
