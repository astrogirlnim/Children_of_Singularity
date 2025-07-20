extends Node

# TradingMarketplace autoload singleton for Children of the Singularity
# Trading API configuration is managed by TradingConfig singleton
# The actual API endpoint is loaded from user://trading_config.json
# which can be configured based on your AWS deployment

# HTTP client for API requests
var http_request: HTTPRequest

# Signals for trading events
signal listings_received(listings: Array[Dictionary])
signal listing_posted(success: bool, listing_id: String)
signal listing_removed(success: bool, listing_id: String)
signal item_purchased(success: bool, item_name: String)
signal trade_completed(success: bool, details: Dictionary)
signal api_error(error_message: String)

# Local player data reference
var local_player_data: LocalPlayerData

# INVENTORY VALIDATION ENHANCEMENT - Prevent Over-Listing
var cached_listings: Array[Dictionary] = []  # Cache of current marketplace listings
var player_active_listings: Array[Dictionary] = []  # Player's own active listings
var listings_cache_timestamp: float = 0.0  # When listings were last cached
var listings_cache_duration: float = 30.0  # Cache duration in seconds
var pending_listing_requests: Dictionary = {}  # Track pending listing requests
var last_listing_request_time: float = 0.0  # Debouncing for listing requests
var listing_request_cooldown: float = 2.0  # Minimum seconds between listing requests

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
func post_listing(item_type: String, quantity: int, price_per_unit: int, description: String = "") -> void:
	print("[TradingMarketplace] Posting listing: %s x%d for %d credits each" % [item_type, quantity, price_per_unit])

	# INVENTORY VALIDATION ENHANCEMENT: Check request debouncing
	var debounce_result = can_make_listing_request()
	if not debounce_result.success:
		emit_signal("api_error", debounce_result.error_message)
		return

	# INVENTORY VALIDATION ENHANCEMENT: Use enhanced validation that accounts for already-listed items
	var validation_result = can_sell_item_enhanced(item_type, quantity)
	if not validation_result.success:
		emit_signal("api_error", validation_result.error_message)
		# Log detailed validation report for debugging
		var report = get_inventory_validation_report(item_type)
		print("[TradingMarketplace] VALIDATION FAILED - Report: %s" % str(report))
		return

	# Mark request as made for debouncing
	mark_listing_request_made()

	# Basic validation for LocalPlayerData availability
	if not local_player_data:
		emit_signal("api_error", "Local player data not available")
		return

	# Create listing data - API expects both item_type and item_name, plus asking_price
	var listing_data = {
		"seller_id": local_player_data.get_player_id(),
		"seller_name": local_player_data.get_player_name(),
		"item_type": item_type,  # API expects snake_case value (e.g., "broken_satellite")
		"item_name": _format_item_name(item_type),  # API expects formatted name (e.g., "Broken Satellite")
		"quantity": quantity,
		"asking_price": price_per_unit,  # API expects asking_price (not price_per_item or price_per_unit)
		"description": description
	}

	var url = TradingConfig.get_full_listings_url()
	var headers = ["Content-Type: application/json"]
	var json_body = JSON.stringify(listing_data)

	print("[TradingMarketplace] Sending POST request with data: %s" % json_body)

	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		emit_signal("api_error", "Failed to send POST request: " + str(error))
		return

## Remove a listing posted by the current player
func remove_listing(listing_id: String) -> void:
	print("[TradingMarketplace] Removing listing: %s" % listing_id)

	# Validate player data is available
	if not local_player_data:
		emit_signal("api_error", "Local player data not available")
		return

	# Create removal data with seller validation
	var removal_data = {
		"seller_id": local_player_data.get_player_id(),
		"seller_name": local_player_data.get_player_name(),
		"removed_at": Time.get_datetime_string_from_system()
	}

	var url = TradingConfig.get_api_base_url() + TradingConfig.get_listings_endpoint() + "/" + listing_id
	var headers = ["Content-Type: application/json"]
	var json_body = JSON.stringify(removal_data)

	print("[TradingMarketplace] Sending DELETE request for listing %s: %s" % [listing_id, json_body])

	var error = http_request.request(url, headers, HTTPClient.METHOD_DELETE, json_body)
	if error != OK:
		emit_signal("api_error", "Failed to send removal request: " + str(error))
		return

## Purchase an item from another player with concurrency protection
func purchase_item(listing_id: String, _seller_id: String, item_name: String, quantity: int, total_price: int) -> void:
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

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
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

func _handle_api_response(data: Dictionary, _response_code: int):
	print("[TradingMarketplace] Handling API response: %s" % str(data))

	# Handle listings response (GET /listings)
	if data.has("listings"):
		var listings_data = data.get("listings", [])
		var listings: Array[Dictionary] = []

		# Ensure each item is a Dictionary and add to typed array
		for item in listings_data:
			if item is Dictionary:
				listings.append(item as Dictionary)

		var total = data.get("total", 0)
		print("[TradingMarketplace] Received %d listings" % total)

		# INVENTORY VALIDATION ENHANCEMENT: Update listings cache and player's active listings
		_update_listings_cache(listings)
		_update_player_active_listings(listings)

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

			# INVENTORY VALIDATION ENHANCEMENT: Refresh cache after successful listing creation
			print("[TradingMarketplace] Refreshing cache after listing creation to update validation")
			refresh_listings_for_validation()

		emit_signal("listing_posted", success, listing_id)
		return

	# Handle successful listing removal (DELETE /listings/{id})
	if data.has("listing_id") and data.has("message") and data.get("message", "").find("removed") != -1:
		var listing_id = data.get("listing_id", "")
		var success = data.get("success", false)
		print("[TradingMarketplace] Listing removed - Success: %s, ID: %s" % [success, listing_id])

		if success:
			# Return item to local inventory since it's no longer for sale
			var removed_listing = data.get("removed_listing", {})
			var item_name = removed_listing.get("item_name", "")
			var quantity = removed_listing.get("quantity", 0)

			if local_player_data and item_name != "":
				# Convert display name back to item type for inventory
				var item_type = _convert_display_name_to_type(item_name)
				local_player_data.add_inventory_item(item_type, "", quantity, 0)
				print("[TradingMarketplace] Returned %d %s to inventory after removal" % [quantity, item_type])

			# INVENTORY VALIDATION ENHANCEMENT: Refresh cache after successful listing removal
			print("[TradingMarketplace] Refreshing cache after listing removal to update validation")
			refresh_listings_for_validation()

		emit_signal("listing_removed", success, listing_id)
		return

	# Handle successful purchase (POST /listings/{id}/buy)
	if data.has("success") and data.get("success", false) and data.has("trade"):
		var _trade = data.get("trade", {})
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

# MARKETPLACE-SPECIFIC METHODS - Phase 1.2 Implementation

## Get marketplace listings specifically for the lobby UI
func get_marketplace_listings() -> void:
	print("[TradingMarketplace] Getting marketplace listings for lobby interface")
	get_listings()  # Use existing method, same API endpoint

## Check if player can sell a specific item in marketplace (ENHANCED)
func can_sell_item(item_type: String, item_name: String, quantity: int) -> bool:
	print("[TradingMarketplace] Validating if player can sell %d x %s (ENHANCED)" % [quantity, item_name])

	# Use enhanced validation that accounts for already-listed items
	var validation_result = can_sell_item_enhanced(item_type, quantity)

	if validation_result.success:
		print("[TradingMarketplace] Can sell %d x %s (available: %d)" % [quantity, item_name, validation_result.available_to_list])
		return true
	else:
		print("[TradingMarketplace] Cannot sell - %s" % validation_result.error_message)
		return false

## Post item for sale in marketplace (wrapper for existing post_listing method)
func post_item_for_sale(item_type: String, item_name: String, quantity: int, asking_price: int) -> void:
	print("[TradingMarketplace] Posting item for sale: %s x%d for %d credits each" % [item_name, quantity, asking_price])

	# Enhanced validation before posting (no debouncing check here)
	if not can_sell_item(item_type, item_name, quantity):
		emit_signal("api_error", "Cannot sell item - enhanced validation failed")
		# Log detailed validation report for debugging
		var report = get_inventory_validation_report(item_type)
		print("[TradingMarketplace] ENHANCED VALIDATION FAILED - Report: %s" % str(report))
		return

	# Validate asking price is reasonable (not too low or too high) - use actual inventory value
	var inventory = local_player_data.get_inventory()
	var item_value = _get_actual_item_value(inventory, item_type)
	var min_price = max(1, item_value * 0.5)  # Minimum 50% of actual value
	var max_price = item_value * 3.0  # Maximum 300% of actual value

	if asking_price < min_price:
		emit_signal("api_error", "Asking price too low. Minimum: %d credits" % min_price)
		return

	if asking_price > max_price:
		emit_signal("api_error", "Asking price too high. Maximum: %d credits" % max_price)
		return

	# INVENTORY VALIDATION ENHANCEMENT: Check request debouncing right before API call
	var debounce_result = can_make_listing_request()
	if not debounce_result.success:
		emit_signal("api_error", debounce_result.error_message)
		return

	# Use existing post_listing method with item_type (not item_name) and proper description
	var description = "High-quality %s from player inventory" % item_name.replace("_", " ")
	post_listing(item_type, quantity, asking_price, description)  # Pass item_type (snake_case) not item_name (formatted)

## Purchase item from marketplace (wrapper for existing purchase_item method)
func purchase_marketplace_item(listing_id: String, seller_id: String) -> bool:
	print("[TradingMarketplace] Attempting to purchase marketplace item: %s from %s" % [listing_id, seller_id])

	# Find the listing in current marketplace_listings to get details
	var listing_details = _find_listing_by_id(listing_id)
	if listing_details.is_empty():
		emit_signal("api_error", "Listing not found. Please refresh marketplace.")
		return false

	# Validate purchase
	var validation_result = validate_marketplace_purchase(listing_details)
	if not validation_result.success:
		emit_signal("api_error", validation_result.error_message)
		return false

	# Use existing purchase_item method
	var item_name = listing_details.get("item_name", "")
	var quantity = listing_details.get("quantity", 1)
	var total_price = listing_details.get("total_price", 0)

	purchase_item(listing_id, seller_id, item_name, quantity, total_price)
	return true

## Validate marketplace purchase before attempting
func validate_marketplace_purchase(listing: Dictionary) -> Dictionary:
	print("[TradingMarketplace] Validating marketplace purchase: %s" % listing)

	var result = {"success": false, "error_message": ""}

	# Check if LocalPlayerData is available
	if not local_player_data:
		result.error_message = "Player data not available"
		return result

	# Check if player has enough credits
	var total_price = listing.get("total_price", 0)
	var current_credits = local_player_data.get_credits()

	if current_credits < total_price:
		result.error_message = "Insufficient credits. Need %d, have %d" % [total_price, current_credits]
		return result

	# Check if player is not trying to buy their own item
	var seller_id = listing.get("seller_id", "")
	var player_id = local_player_data.get_player_id()

	if seller_id == player_id:
		result.error_message = "Cannot purchase your own items"
		return result

	# Check inventory space (if applicable)
	var inventory = local_player_data.get_inventory()
	var inventory_capacity = _get_inventory_capacity()

	if inventory.size() >= inventory_capacity:
		result.error_message = "Inventory full. Cannot purchase item."
		return result

	result.success = true
	print("[TradingMarketplace] Purchase validation successful")
	return result

## Get actual value of an item type from player inventory
func _get_actual_item_value(inventory: Array[Dictionary], item_type: String) -> int:
	# Find the first item of this type in inventory and return its actual value
	for item in inventory:
		if item.get("type", "") == item_type:
			return item.get("value", 0)

	# Fallback to default values only if item not found in inventory
	var default_values = {
		"scrap_metal": 10,
		"broken_satellite": 150,
		"ai_component": 150,
		"unknown_artifact": 500,
		"quantum_core": 1000
	}
	return default_values.get(item_type, 50)

## Format item type to display name for API
func _format_item_name(item_type: String) -> String:
	# Convert snake_case item types to proper display names
	var formatted_names = {
		"scrap_metal": "Scrap Metal",
		"broken_satellite": "Broken Satellite",
		"ai_component": "AI Component",
		"bio_waste": "Bio Waste",
		"unknown_artifact": "Unknown Artifact",
		"quantum_core": "Quantum Core"
	}

	return formatted_names.get(item_type, item_type.replace("_", " ").capitalize())

## Convert display name back to item type for inventory storage
func _convert_display_name_to_type(display_name: String) -> String:
	# Convert display names back to snake_case item types
	var type_mappings = {
		"Scrap Metal": "scrap_metal",
		"Broken Satellite": "broken_satellite",
		"AI Component": "ai_component",
		"Bio Waste": "bio_waste",
		"Unknown Artifact": "unknown_artifact",
		"Quantum Core": "quantum_core"
	}

	return type_mappings.get(display_name, display_name.to_lower().replace(" ", "_"))

## Find listing by ID in current marketplace listings
func _find_listing_by_id(listing_id: String) -> Dictionary:
	# This would need to be implemented by storing current listings
	# For now, return empty dict as placeholder
	print("[TradingMarketplace] Finding listing by ID: %s" % listing_id)
	return {}

## Get player inventory capacity for validation
func _get_inventory_capacity() -> int:
	if local_player_data:
		var upgrades = local_player_data.get_all_upgrades()
		var inventory_level = upgrades.get("inventory_expansion", 0)
		return 10 + (inventory_level * 5)  # Base 10 + 5 per upgrade level
	return 10

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

# INVENTORY VALIDATION ENHANCEMENT METHODS - Prevent Over-Listing

## Update listings cache with fresh data from API
func _update_listings_cache(listings: Array[Dictionary]) -> void:
	print("[TradingMarketplace] Updating listings cache with %d listings" % listings.size())
	cached_listings = listings.duplicate()
	listings_cache_timestamp = Time.get_unix_time_from_system()

## Extract and cache player's own active listings
func _update_player_active_listings(listings: Array[Dictionary]) -> void:
	if not local_player_data:
		return

	var player_id = local_player_data.get_player_id()
	player_active_listings.clear()

	for listing in listings:
		if listing.get("seller_id", "") == player_id and listing.get("status", "") == "active":
			player_active_listings.append(listing)

	print("[TradingMarketplace] Player has %d active listings" % player_active_listings.size())

## Get total quantity of an item type that player has already listed
func get_player_listed_quantity(item_type: String) -> int:
	var total_listed = 0

	# Check if cache is still valid
	var current_time = Time.get_unix_time_from_system()
	if current_time - listings_cache_timestamp > listings_cache_duration:
		print("[TradingMarketplace] WARNING: Listings cache expired, validation may be inaccurate")
		return 0  # Conservative approach: assume nothing listed if cache expired

	# Count quantities in player's active listings
	for listing in player_active_listings:
		if listing.get("item_type", "") == item_type:
			total_listed += listing.get("quantity", 0)

	print("[TradingMarketplace] Player has %d %s already listed" % [total_listed, item_type])
	return total_listed

## Enhanced can_sell_item that accounts for already-listed quantities
func can_sell_item_enhanced(item_type: String, quantity_to_list: int) -> Dictionary:
	var result = {"success": false, "error_message": "", "available_to_list": 0}

	print("[TradingMarketplace] Enhanced validation for listing %d x %s" % [quantity_to_list, item_type])

	if not local_player_data:
		result.error_message = "Player data not available"
		return result

	# Get inventory quantity
	var inventory = local_player_data.get_inventory()
	var inventory_quantity = _get_inventory_quantity(inventory, item_type)

	# Get already-listed quantity
	var listed_quantity = get_player_listed_quantity(item_type)

	# Calculate available quantity for new listings
	var available_to_list = inventory_quantity - listed_quantity
	result.available_to_list = available_to_list

	if available_to_list < quantity_to_list:
		result.error_message = "Insufficient %s available for listing. Have %d in inventory, %d already listed, %d available to list (need %d)" % [
			item_type, inventory_quantity, listed_quantity, available_to_list, quantity_to_list
		]
		return result

	# Check minimum value requirement
	var item_value = _get_actual_item_value(inventory, item_type)
	if item_value < 100:
		result.error_message = "Item value too low (%d credits). Minimum 100 credits required." % item_value
		return result

	result.success = true
	print("[TradingMarketplace] Enhanced validation passed: %d %s available to list" % [available_to_list, item_type])
	return result

## Request debouncing to prevent spam-clicking
func can_make_listing_request() -> Dictionary:
	var result = {"success": false, "error_message": "", "cooldown_remaining": 0.0}

	var current_time = Time.get_unix_time_from_system()
	var time_since_last = current_time - last_listing_request_time

	if time_since_last < listing_request_cooldown:
		var remaining = listing_request_cooldown - time_since_last
		result.cooldown_remaining = remaining
		result.error_message = "Please wait %.1f seconds before making another listing request" % remaining
		return result

	result.success = true
	return result

## Mark that a listing request is being made (for debouncing)
func mark_listing_request_made() -> void:
	last_listing_request_time = Time.get_unix_time_from_system()
	print("[TradingMarketplace] Listing request timestamp updated for debouncing")

## Force refresh of listings cache for accurate validation
func refresh_listings_for_validation() -> void:
	print("[TradingMarketplace] Refreshing listings cache for accurate validation")
	get_listings()  # This will trigger cache update when response is received

## Get comprehensive listing validation report for debugging
func get_inventory_validation_report(item_type: String) -> Dictionary:
	var report = {
		"item_type": item_type,
		"timestamp": Time.get_datetime_string_from_system(),
		"inventory_quantity": 0,
		"listed_quantity": 0,
		"available_to_list": 0,
		"cache_age_seconds": 0.0,
		"cache_valid": false,
		"player_active_listings_count": player_active_listings.size()
	}

	if not local_player_data:
		report["error"] = "LocalPlayerData not available"
		return report

	var inventory = local_player_data.get_inventory()
	report.inventory_quantity = _get_inventory_quantity(inventory, item_type)
	report.listed_quantity = get_player_listed_quantity(item_type)
	report.available_to_list = report.inventory_quantity - report.listed_quantity

	var current_time = Time.get_unix_time_from_system()
	report.cache_age_seconds = current_time - listings_cache_timestamp
	report.cache_valid = report.cache_age_seconds <= listings_cache_duration

	print("[TradingMarketplace] Validation report for %s: %s" % [item_type, str(report)])
	return report
