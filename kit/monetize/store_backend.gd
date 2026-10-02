class_name StoreBackend
extends Node

## What the Shop asks of a store. This base sells nothing, which is every build but Android's; Play
## billing (android/play_billing.gd) fills it in. It lives in the tree while the app runs, since the plugin
## calls back into it.

## Something a shop sheet shows has changed: a price arrived, or something was bought.
signal changed

## Starts buying product `id` (GameMonetize).
func buy(_id: String) -> void:
	pass

## Asks the store what this account owns. `quiet` for the check at every launch; the Restore button
## tells the player what it found.
func restore(_quiet: bool) -> void:
	pass
