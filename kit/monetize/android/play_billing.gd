extends StoreBackend

## Google Play billing through the Godot Foundation's plugin, loaded by Shop on Android only: every
## product's price for the shop, each one-time product acknowledged as Play requires (it refunds one left
## unacknowledged for three days), each tip consumed so it can be given again, and what the account owns
## asked again at each launch.

const PURCHASED: int = 1
const PENDING: int = 2

var _client: BillingClient
## Products Play has listed, by id.
var _listed: Dictionary = {}
var _loud_restore: bool = false
## Tips sent to be consumed and not yet answered, by purchase token, so each is thanked once.
var _consuming: Dictionary = {}

func _ready() -> void:
	_client = BillingClient.new()
	add_child(_client)
	_client.connected.connect(_on_connected)
	_client.query_product_details_response.connect(_on_details)
	_client.query_purchases_response.connect(_on_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.consume_purchase_response.connect(_on_consumed)
	_client.start_connection()

func _on_connected() -> void:
	_client.query_purchases(BillingClient.ProductType.INAPP)
	_ask_prices()

func _ask_prices() -> void:
	_client.query_product_details(Shop.all_ids(), BillingClient.ProductType.INAPP)

func _on_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	for entry: Variant in response.get("product_details", []):
		var details: Dictionary = entry
		var id: String = String(details.get("product_id", ""))
		var offer: Variant = details.get("one_time_purchase_offer_details")
		if Shop.all_ids().has(id) and offer is Dictionary:
			var shown: String = String((offer as Dictionary).get("formatted_price", ""))
			if id == GameMonetize.SUPPORTER_ID:
				Supporter.price = shown
			else:
				Shop.prices[id] = shown
			_listed[id] = true
	changed.emit()

func buy(id: String) -> void:
	if not _client.is_ready():
		_client.start_connection()
		Supporter.say("Google Play is not reachable right now")
		return
	if not _listed.has(id):
		_ask_prices()
		Supporter.say("%s is not in the store yet" % Shop.title(id))
		return
	var result: Dictionary = _client.purchase(id)
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
			var states: Dictionary = _take(response.get("purchases", []))
			for id: String in states:
				if int(states[id]) == PURCHASED and not Shop.is_tip(id):
					Shop.grant(id, true)
					Supporter.say(_thanks(id))
				elif int(states[id]) == PENDING:
					Supporter.say("The purchase is pending. It turns on once it goes through")
			changed.emit()
		BillingClient.BillingResponseCode.USER_CANCELED:
			pass
		BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
			restore(false)
		_:
			Supporter.say("The purchase did not go through")

## What Play says the account owns, at launch or from Restore. A clean answer without a product takes it
## away again, which is how a refund reaches the game. A tip still waiting to be consumed is consumed now.
func _on_purchases(response: Dictionary) -> void:
	var loud: bool = _loud_restore
	_loud_restore = false
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		if loud:
			Supporter.say("Google Play is not reachable right now")
		return
	var states: Dictionary = _take(response.get("purchases", []))
	var found: int = 0
	for id: String in Shop.one_time_ids():
		var owned: bool = int(states.get(id, 0)) == PURCHASED
		Shop.grant(id, owned)
		found += 1 if owned else 0
	changed.emit()
	if loud:
		Supporter.say("Purchases restored. Thank you" if found > 0 else "This Google account has no purchases here yet")

## Each product's state among `purchases`: one-time products acknowledged if Play is still waiting for
## that, tips sent to be consumed. A product left out is not owned.
func _take(purchases: Variant) -> Dictionary:
	var states: Dictionary = {}
	if not purchases is Array:
		return states
	for entry: Variant in purchases:
		var purchase: Dictionary = entry
		var state: int = int(purchase.get("purchase_state", 0))
		var token: String = String(purchase.get("purchase_token", ""))
		for product: Variant in Array(purchase.get("product_ids", [])):
			var id: String = String(product)
			if not Shop.all_ids().has(id):
				continue
			if state == PURCHASED:
				states[id] = PURCHASED
				if Shop.is_tip(id):
					if not _consuming.has(token):
						_consuming[token] = true
						_client.consume_purchase(token)
				elif not bool(purchase.get("is_acknowledged", false)):
					_client.acknowledge_purchase(token)
			elif state == PENDING and int(states.get(id, 0)) != PURCHASED:
				states[id] = PENDING
	return states

## A tip used up, so it can be given again: that is when it counts.
func _on_consumed(response: Dictionary) -> void:
	var token: String = String(response.get("purchase_token", ""))
	_consuming.erase(token)
	if int(response.get("response_code", -1)) == BillingClient.BillingResponseCode.OK:
		Shop.tipped()
		changed.emit()

func _thanks(id: String) -> String:
	if id == GameMonetize.LEVELS_ID:
		return "Every level is open. Thank you"
	if id == GameMonetize.LOOKS_ID:
		return "Every look is yours, in Settings. Thank you"
	if id == GameMonetize.COMPLETE_ID:
		return "Everything is yours. Thank you"
	return "Thank you for supporting %s" % Brand.NAME
