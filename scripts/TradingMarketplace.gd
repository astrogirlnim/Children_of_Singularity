extends Node

# TradingMarketplace autoload singleton for Children of the Singularity
# Trading API configuration is managed by TradingConfig singleton
# The actual API endpoint is loaded from user://trading_config.json
# which can be configured based on your AWS deployment

# HTTP client for API requests
var http_request: HTTPRequest

# Signals for trading events
signal listings_received(listings: Array)
signal listing_posted(success: bool, listing_id: String)
signal item_purchased(success: bool, item_name: String)
signal trade_completed(success: bool, details: Dictionary)
signal api_error(error_message: String)

# Local player data reference
var local_player_data: LocalPlayerData

func _ready():
	print("[TradingMarketplace] Initializing trading marketplace client")

	# Set up HTTP request node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

	# Get reference to local player data
	local_player_data = get_node("/root/LocalPlayerData") if get_node_or_null("/root/LocalPlayerData") else null
	if not local_player_data:
		print("[TradingMarketplace] Warning: LocalPlayerData not found")

# CORE API METHODS

## Get all active trading listings
func get_listings() -> void:
	print("[TradingMarketplace] Fetching trading listings from API")

	var url = TradingConfig.get_full_listings_url()
	var headers = ["Content-Type: application/json"]

	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		emit_signal("api_error", "Failed to send GET request: " + str(error))
		return

## Post a new item for sale
func post_listing(item_name: String, quantity: int, price_per_unit: int, description: String = "") -> void:
	print("[TradingMarketplace] Posting listing: %s x%d for %d credits each" % [item_name, quantity, price_per_unit])

	# Validate player has the item locally
	if not local_player_data:
		emit_signal("api_error", "Local player data not available")
		return

	var player_inventory = local_player_data.get_inventory()
	var available_quantity = _get_inventory_quantity(player_inventory, item_name)
	if available_quantity < quantity:
		emit_signal("api_error", "Insufficient %s in inventory. Have %d, need %d" % [item_name, available_quantity, quantity])
		return

	# Create listing data
	var listing_data = {
		"seller_id": local_player_data.get_player_id(),
		"seller_name": local_player_data.get_player_name(),
		"item_name": item_name,
		"quantity": quantity,
		"price_per_unit": price_per_unit,
		"total_price": quantity * price_per_unit,
		"description": description,
		"posted_at": Time.get_datetime_string_from_system()
	}

	var url = TradingConfig.get_full_listings_url()
	var headers = ["Content-Type: application/json"]
	var json_body = JSON.stringify(listing_data)

	print("[TradingMarketplace] Sending POST request with data: %s" % json_body)

	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		emit_signal("api_error", "Failed to send POST request: " + str(error))
		return

## Purchase an item from another player with concurrency protection
func purchase_item(listing_id: String, seller_id: String, item_name: String, quantity: int, total_price: int) -> void:
	print("[TradingMarketplace] Attempting to purchase: %s x%d for %d credits (listing %s)" % [item_name, quantity, total_price, listing_id])

	# Validate player has enough credits locally
	if not local_player_data:
		emit_signal("api_error", "Local player data not available")
		return

	var current_credits = local_player_data.get_credits()
	if current_credits < total_price:
		emit_signal("api_error", "Insufficient credits. Need %d, have %d" % [total_price, current_credits])
		return

	# Optimistic credit hold to prevent double-spending during API call
	print("[TradingMarketplace] Temporarily holding %d credits for purchase" % total_price)
	if not local_player_data.add_credits(-total_price):
		emit_signal("api_error", "Failed to hold credits for purchase")
		return

	# Create purchase data with expected price validation
	var purchase_data = {
		"buyer_id": local_player_data.get_player_id(),
		"buyer_name": local_player_data.get_player_name(),
		"listing_id": listing_id,
		"quantity": quantity,
		"expected_price": total_price,  # Price validation to prevent race conditions
		"purchased_at": Time.get_datetime_string_from_system()
	}

	var url = TradingConfig.get_api_base_url() + TradingConfig.get_listings_endpoint() + "/" + listing_id + "/buy"
	var headers = ["Content-Type: application/json"]
	var json_body = JSON.stringify(purchase_data)

	print("[TradingMarketplace] Sending purchase request with price validation: %s" % json_body)

	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		# Rollback credit hold on request failure
		local_player_data.add_credits(total_price)
		emit_signal("api_error", "Failed to send purchase request: " + str(error))
		return

## Get trading history for current player
func get_player_trade_history() -> void:
	print("[TradingMarketplace] Fetching trade history")

	if not local_player_data:
		emit_signal("api_error", "Local player data not available")
		return

	var player_id = local_player_data.get_player_id()
	var url = TradingConfig.get_api_base_url() + "/history/" + player_id
	var headers = ["Content-Type: application/json"]

	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		emit_signal("api_error", "Failed to fetch trade history: " + str(error))
		return

# HTTP REQUEST HANDLER

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response_text = body.get_string_from_utf8()
	print("[TradingMarketplace] API Response - Code: %d, Body: %s" % [response_code, response_text])

	# Handle HTTP errors
	if response_code < 200 or response_code >= 300:
		var error_msg = "API request failed with code %d: %s" % [response_code, response_text]
		print("[TradingMarketplace] ERROR: %s" % error_msg)
		emit_signal("api_error", error_msg)
		return

	# Parse JSON response
	var json = JSON.new()
	var parse_result = json.parse(response_text)
	if parse_result != OK:
		var error_msg = "Failed to parse JSON response: %s" % response_text
		print("[TradingMarketplace] ERROR: %s" % error_msg)
		emit_signal("api_error", error_msg)
		return

	var data = json.data
	print("[TradingMarketplace] Parsed API response: %s" % str(data))

	# Route response based on endpoint
	_handle_api_response(data, response_code)

func _handle_api_response(data: Dictionary, response_code: int):
	print("[TradingMarketplace] Handling API response: %s" % str(data))

	# Handle listings response (GET /listings)
	if data.has("listings"):
		var listings = data.get("listings", [])
		var total = data.get("total", 0)
		print("[TradingMarketplace] Received %d listings" % total)
		emit_signal("listings_received", listings)
		return

	# Handle successful listing post (POST /listings)
	if data.has("listing_id") and data.has("success"):
		var listing_id = data.get("listing_id", "")
		var success = data.get("success", false)
		print("[TradingMarketplace] Listing posted - Success: %s, ID: %s" % [success, listing_id])

		if success:
			# Remove item from local inventory since it's now for sale
			var item_name = data.get("item_name", "")
			var quantity = data.get("quantity", 0)
			if local_player_data and item_name != "":
				_remove_items_from_inventory(item_name, quantity)
				print("[TradingMarketplace] Removed %d %s from local inventory" % [quantity, item_name])

		emit_signal("listing_posted", success, listing_id)
		return

	# Handle successful purchase (POST /listings/{id}/buy)
	if data.has("success") and data.get("success", false) and data.has("trade"):
		var trade = data.get("trade", {})
		var item = data.get("item", {})
		var item_name = item.get("item_name", "")
		var quantity = item.get("quantity", 0)
		var total_price = item.get("price_paid", 0)

		print("[TradingMarketplace] Purchase successful: %s x%d for %d credits" % [item_name, quantity, total_price])

		# Add item to local inventory (credits already deducted optimistically)
		if local_player_data and item_name != "":
			local_player_data.add_inventory_item(item_name, "", quantity, 0)
			print("[TradingMarketplace] Added %d %s to inventory (credits already deducted)" % [quantity, item_name])

		emit_signal("item_purchased", true, item_name)
		emit_signal("trade_completed", true, data)
		return

	# Handle purchase failure - rollback credit hold
	if data.has("error"):
		var error_message = data.get("error", "Unknown error")
		print("[TradingMarketplace] Purchase failed: %s" % error_message)

		# Check if this was a price validation error or item already sold
		if error_message.find("Price changed") != -1 or error_message.find("already sold") != -1 or error_message.find("purchased by another player") != -1:
			# Rollback the credit hold for failed purchases
			var held_amount = data.get("expected_price", 0)  # May not be available, but try
			if held_amount > 0 and local_player_data:
				local_player_data.add_credits(held_amount)
				print("[TradingMarketplace] Rolled back %d credits from failed purchase" % held_amount)

		emit_signal("item_purchased", false, "")
		emit_signal("api_error", "Purchase failed: " + error_message)
		return

	# Handle trade history response
	if data.has("trade_history"):
		print("[TradingMarketplace] Received trade history")
		# This could be extended to show trade history in UI
		return

	# Handle generic success/error responses
	if data.has("success"):
		var success = data.get("success", false)
		var message = data.get("message", "Unknown response")

		if not success:
			emit_signal("api_error", message)
		else:
			print("[TradingMarketplace] Success: %s" % message)
		return

	# Unknown response format
	var error_msg = "Unknown API response format: %s" % str(data)
	print("[TradingMarketplace] WARNING: %s" % error_msg)

# UTILITY METHODS

## Check if trading API is available
func ping_api() -> void:
	print("[TradingMarketplace] Pinging trading API")
	get_listings()

## Get formatted listing for UI display
func format_listing_for_ui(listing: Dictionary) -> String:
	var seller = listing.get("seller_name", "Unknown")
	var item = listing.get("item_name", "Unknown Item")
	var qty = listing.get("quantity", 0)
	var price = listing.get("price_per_unit", 0)
	var total = listing.get("total_price", 0)

	return "%s x%d - %d credits each (%d total) - Seller: %s" % [item, qty, price, total, seller]

## Validate if player can afford a listing
func can_afford_listing(listing: Dictionary) -> bool:
	if not local_player_data:
		return false

	var total_price = listing.get("total_price", 0)
	var current_credits = local_player_data.get_credits()

	return current_credits >= total_price

## Get listings filtered by item type
func filter_listings_by_item(listings: Array, item_name: String) -> Array:
	var filtered = []
	for listing in listings:
		if listing.get("item_name", "") == item_name:
			filtered.append(listing)

	return filtered

## Sort listings by price (ascending)
func sort_listings_by_price(listings: Array) -> Array:
	var sorted_listings = listings.duplicate()
	sorted_listings.sort_custom(func(a, b): return a.get("price_per_unit", 0) < b.get("price_per_unit", 0))
	return sorted_listings

# INVENTORY HELPER METHODS (for LocalPlayerData integration)

## Get total quantity of an item type in inventory
func _get_inventory_quantity(inventory: Array, item_name: String) -> int:
	var total_quantity = 0
	for item in inventory:
		if item.get("type", "") == item_name:
			total_quantity += item.get("quantity", 0)
	return total_quantity

## Remove specific quantity of items from inventory
func _remove_items_from_inventory(item_name: String, quantity_to_remove: int) -> void:
	if not local_player_data:
		return

	var inventory = local_player_data.get_inventory()
	var remaining_to_remove = quantity_to_remove

	# Find and remove items by quantity needed
	var items_to_remove = []
	for i in range(inventory.size()):
		if inventory[i].get("type", "") == item_name and remaining_to_remove > 0:
			var item_quantity = inventory[i].get("quantity", 0)
			if item_quantity <= remaining_to_remove:
				# Remove entire item
				items_to_remove.append(inventory[i].get("item_id", ""))
				remaining_to_remove -= item_quantity
			else:
				# Reduce quantity (Note: LocalPlayerData doesn't have a reduce method, so we'll remove and re-add)
				var item_id = inventory[i].get("item_id", "")
				var new_quantity = item_quantity - remaining_to_remove
				var item_value = inventory[i].get("value", 0)

				# Remove old item and add new one with reduced quantity
				local_player_data.remove_inventory_item(item_id)
				local_player_data.add_inventory_item(item_name, "", new_quantity, item_value)
				remaining_to_remove = 0
				break

	# Remove items that need to be completely removed
	for item_id in items_to_remove:
		local_player_data.remove_inventory_item(item_id)
