class_name StoreBackend
extends Node

## What the Supporter class asks of a store. This base sells nothing, which is every build but Android's;
## Play billing (android/play_billing.gd) fills it in. It lives in the tree while the app runs, since the
## plugin calls back into it.

## Something the Supporter sheet shows has changed: the price arrived, or the pack was bought.
signal changed

func buy() -> void:
	pass

## Asks the store what this account owns. `quiet` for the check at every launch; the Restore button
## tells the player what it found.
func restore(_quiet: bool) -> void:
	pass
