class_name GameMonetize
extends RefCounted

## Plumb's AdMob app and ad units and its Supporter pack product, read by the kit's Ads and Supporter.
## These are Google's official test ids until the real ones are made in AdMob; ids ship inside the app,
## so none of them is a secret. Keep the project setting admob/general/android/app_id equal to APP_ID:
## the AdMob plugin writes that setting into the manifest, and a test checks the two agree.

const APP_ID: String = "ca-app-pub-3940256099942544~3347511713"
const BANNER_ID: String = "ca-app-pub-3940256099942544/9214589741"
const INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/1033173712"
const REWARDED_ID: String = "ca-app-pub-3940256099942544/5224354917"
## A one-time product in Play Console, under Monetize with Play, Products, In-app products.
const SUPPORTER_ID: String = "supporter"
