extends StoreBackend

## Google Play billing through the Godot Foundation's plugin, loaded by Supporter on Android only: the
## one non-consumable product, its price for the sheet, every purchase acknowledged as Play requires (it
## refunds one left unacknowledged for three days), and what the account owns asked again at each launch.

const PURCHASED: int = 1
const PENDING: int = 2

var _client: BillingClient
var _listed: bool = false
var _loud_restore: bool = false

func _ready() -> void:
	_client = BillingClient.new()
	add_child(_client)
	_client.connected.connect(_on_connected)
	_client.query_product_details_response.connect(_on_details)
	_client.query_purchases_response.connect(_on_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.start_connection()

func _on_connected() -> void:
	_client.query_purchases(BillingClient.ProductType.INAPP)
	_ask_price()

func _ask_price() -> void:
	_client.query_product_details(PackedStringArray([GameMonetize.SUPPORTER_ID]), BillingClient.ProductType.INAPP)

func _on_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	for entry: Variant in response.get("product_details", []):
		var details: Dictionary = entry
		var offer: Variant = details.get("one_time_purchase_offer_details")
		if String(details.get("product_id", "")) == GameMonetize.SUPPORTER_ID and offer is Dictionary:
			Supporter.price = String((offer as Dictionary).get("formatted_price", ""))
			_listed = true
			changed.emit()

func buy() -> void:
	if not _client.is_ready():
		_client.start_connection()
		Supporter.say("Google Play is not reachable right now")
		return
	if not _listed:
		_ask_price()
		Supporter.say("The Supporter pack is not in the store yet")
		return
	var result: Dictionary = _client.purchase(GameMonetize.SUPPORTER_ID)
	var code: int = int(result.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		restore(false)
	elif code != BillingClient.BillingResponseCode.OK:
		Supporter.say("Google Play could not start the purchase")

func restore(quiet: bool) -> void:
	_loud_restore = not quiet
	if not _client.is_ready():
		_client.start_connection()
		if not quiet:
			Supporter.say("Google Play is not reachable right now")
		return
	_client.query_purchases(BillingClient.ProductType.INAPP)

func _on_purchase_updated(response: Dictionary) -> void:
	match int(response.get("response_code", -1)):
		BillingClient.BillingResponseCode.OK:
			var state: int = _take(response.get("purchases", []))
			if state == PURCHASED:
				Supporter.grant(true)
				Supporter.say("Thank you for supporting %s" % Brand.NAME)
				changed.emit()
			elif state == PENDING:
				Supporter.say("The purchase is pending. The pack turns on once it goes through")
		BillingClient.BillingResponseCode.USER_CANCELED:
			pass
		BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
			restore(false)
		_:
			Supporter.say("The purchase did not go through")

## What Play says the account owns, at launch or from Restore. A clean answer without the pack takes it
## away again, which is how a refund reaches the game.
func _on_purchases(response: Dictionary) -> void:
	var loud: bool = _loud_restore
	_loud_restore = false
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		if loud:
			Supporter.say("Google Play is not reachable right now")
		return
	var owned: bool = _take(response.get("purchases", [])) == PURCHASED
	Supporter.grant(owned)
	changed.emit()
	if loud:
		Supporter.say("Supporter pack restored. Thank you" if owned else "This Google account has no Supporter pack")

## The pack's state among `purchases`, acknowledging it if Play is still waiting for that. 0 when absent.
func _take(purchases: Variant) -> int:
	var state: int = 0
	if not purchases is Array:
		return state
	for entry: Variant in purchases:
		var purchase: Dictionary = entry
		var products: Array = Array(purchase.get("product_ids", []))
		if not products.has(GameMonetize.SUPPORTER_ID):
			continue
		var this_state: int = int(purchase.get("purchase_state", 0))
		if this_state == PURCHASED:
			state = PURCHASED
			if not bool(purchase.get("is_acknowledged", false)):
				_client.acknowledge_purchase(String(purchase.get("purchase_token", "")))
		elif this_state == PENDING and state != PURCHASED:
			state = PENDING
	return state
