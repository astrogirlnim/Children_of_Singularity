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
# PHASE 1.2: Purchase state management signal
signal purchase_state_changed(new_state: int, data: Dictionary)

# PHASE 1.2: Purchase State Management
enum PurchaseState {
	IDLE,
	VALIDATING,
	SENDING_REQUEST,
	PROCESSING,
	COMPLETED,
	FAILED,
	TIMED_OUT
}

var current_purchase_state: PurchaseState = PurchaseState.IDLE
var purchase_state_data: Dictionary = {}

# PHASE 1.1: HTTP Request Management & Timeouts
var request_timeout: float = 15.0  # Default, will be loaded from config
var pending_requests: Dictionary = {}  # Track active requests
var timeout_timer: Timer
var request_id_counter: int = 0
var current_request_id: String = ""  # Track current request for completion

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

	# PHASE 1.1: Setup timeout management with configuration
	_setup_timeout_management()

	# Get reference to local player data
	local_player_data = get_node("/root/LocalPlayerData") if get_node_or_null("/root/LocalPlayerData") else null
	if not local_player_data:
		print("[TradingMarketplace] Warning: LocalPlayerData not found")

# CORE API METHODS

## Get all active trading listings
func get_listings() -> void:
	print("[TradingMarketplace] Fetching trading listings from API")

	# PHASE 1.1: Track this request
	current_request_id = _track_request("get_listings")

	var url = TradingConfig.get_full_listings_url()
	var headers = ["Content-Type: application/json"]

	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		_complete_request(current_request_id)
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

	# PHASE 1.1: Track this request
	current_request_id = _track_request("post_listing", {
		"item_type": item_type,
		"quantity": quantity,
		"price_per_unit": price_per_unit
	})

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
		_complete_request(current_request_id)
		emit_signal("api_error", "Failed to send POST request: " + str(error))
		return

## Remove a listing posted by the current player
func remove_listing(listing_id: String) -> void:
	print("[TradingMarketplace] Removing listing: %s" % listing_id)

	# Validate player data is available
	if not local_player_data:
		emit_signal("api_error", "Local player data not available")
		return

	# PHASE 1.1: Track this request
	current_request_id = _track_request("remove_listing", {
		"listing_id": listing_id
	})

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
		_complete_request(current_request_id)
		emit_signal("api_error", "Failed to send removal request: " + str(error))
		return

## Purchase an item from another player with concurrency protection
func purchase_item(listing_id: String, _seller_id: String, item_name: String, quantity: int, total_price: int) -> void:
	print("[TradingMarketplace] Attempting to purchase: %s x%d for %d credits (listing %s)" % [item_name, quantity, total_price, listing_id])

	# PHASE 1.2: Check if a purchase is already in progress
	if is_purchase_in_progress():
		emit_signal("api_error", "Purchase already in progress. Please wait.")
		return

	# PHASE 1.2: Start purchase validation state
	_set_purchase_state(PurchaseState.VALIDATING, {
		"listing_id": listing_id,
		"item_name": item_name,
		"quantity": quantity,
		"total_price": total_price
	})

	# Validate player has enough credits locally
	if not local_player_data:
		emit_signal("api_error", "Local player data not available")
		_set_purchase_state(PurchaseState.FAILED, {"error": "Local player data not available"})
		return

	var current_credits = local_player_data.get_credits()
	if current_credits < total_price:
		emit_signal("api_error", "Insufficient credits. Need %d, have %d" % [total_price, current_credits])
		_set_purchase_state(PurchaseState.FAILED, {
			"error": "Insufficient credits",
			"required": total_price,
			"available": current_credits
		})
		return

	# PHASE 1.2: Move to sending request state
	_set_purchase_state(PurchaseState.SENDING_REQUEST, {
		"listing_id": listing_id,
		"item_name": item_name,
		"quantity": quantity,
		"total_price": total_price,
		"original_credits": current_credits
	})

	# Optimistic credit hold to prevent double-spending during API call
	print("[TradingMarketplace] Temporarily holding %d credits for purchase" % total_price)
	if not local_player_data.add_credits(-total_price):
		emit_signal("api_error", "Failed to hold credits for purchase")
		_set_purchase_state(PurchaseState.FAILED, {"error": "Failed to hold credits for purchase"})
		return

	# PHASE 1.1: Track this request with credit info for rollback
	current_request_id = _track_request("purchase", {
		"listing_id": listing_id,
		"item_name": item_name,
		"quantity": quantity,
		"total_price": total_price,
		"original_credits": current_credits
	})

	# PHASE 1.2: Move to processing state
	_set_purchase_state(PurchaseState.PROCESSING, {
		"listing_id": listing_id,
		"item_name": item_name,
		"quantity": quantity,
		"total_price": total_price,
		"original_credits": current_credits,
		"held_credits": total_price,
		"request_id": current_request_id
	})

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
		_complete_request(current_request_id)
		_set_purchase_state(PurchaseState.FAILED, {"error": "Failed to send purchase request: " + str(error)})
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

	# PHASE 1.1: Complete the current tracked request on any response
	if current_request_id != "":
		_complete_request(current_request_id)
		current_request_id = ""

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

	# PHASE 1.1: Complete the current tracked request
	if current_request_id != "":
		_complete_request(current_request_id)
		current_request_id = ""

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

		# PHASE 1.2: Set purchase completed state
		_set_purchase_state(PurchaseState.COMPLETED, {
			"item_name": item_name,
			"quantity": quantity,
			"total_price": total_price,
			"trade_data": _trade,
			"completion_time": Time.get_unix_time_from_system()
		})

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

		# PHASE 1.3: Use enhanced error handling
		var error_code = data.get("error_code", 0)
		var error_category = _categorize_error(error_message, error_code)

		# Set purchase failed state with enhanced error details
		_set_purchase_state(PurchaseState.FAILED, {
			"error": error_message,
			"error_code": error_code,
			"error_category": error_category,
			"error_time": Time.get_unix_time_from_system(),
			"rollback_attempted": false,
			"recovery_suggestions": get_error_recovery_suggestions(error_category)
		})

		# Enhanced rollback logic
		var rollback_successful = false
		if error_message.find("Price changed") != -1 or error_message.find("already sold") != -1 or error_message.find("purchased by another player") != -1:
			# Rollback the credit hold for failed purchases
			var held_amount = data.get("expected_price", 0)  # May not be available, but try
			if held_amount <= 0 and purchase_state_data.has("held_credits"):
				held_amount = purchase_state_data.get("held_credits", 0)

			if held_amount > 0 and local_player_data:
				var credits_before = local_player_data.get_credits()
				local_player_data.add_credits(held_amount)
				var credits_after = local_player_data.get_credits()

				print("[TradingMarketplace] Rolled back %d credits from failed purchase" % held_amount)
				rollback_successful = true

				# Log the credit transaction
				_log_credit_transaction("failed_purchase_rollback", held_amount, {
					"error": error_message,
					"error_category": error_category,
					"from_credits": credits_before,
					"to_credits": credits_after
				})

				# Update state to indicate rollback was successful
				purchase_state_data["rollback_attempted"] = true
				purchase_state_data["rollback_amount"] = held_amount
				purchase_state_data["rollback_successful"] = true

		# Attempt automatic recovery
		var auto_recovery_attempted = attempt_automatic_recovery(error_category)
		purchase_state_data["auto_recovery_attempted"] = auto_recovery_attempted

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

	# Verify the listing exists and get comprehensive validation info
	var verification = verify_listing_exists(listing_id)

	# Safety check: ensure verification has the expected structure
	if not verification or not verification.has("exists"):
		print("[TradingMarketplace] Verification method failed to return proper structure")
		emit_signal("api_error", "Internal error during listing verification. Please try again.")
		return false

	if not verification.exists:
		print("[TradingMarketplace] Listing verification failed: %s" % verification.get("error", "Unknown error"))

		# Print debug info to help troubleshoot
		if verification.has("debug_info") and verification.debug_info:
			print("[TradingMarketplace] Debug info: %s" % str(verification.debug_info))

		# Suggest refreshing if cache is stale
		var debug_info = verification.get("debug_info", {})
		var cache_age = debug_info.get("cache_age_seconds", 0)
		if cache_age > listings_cache_duration:
			emit_signal("api_error", "Listing not found - marketplace data may be stale. Please refresh and try again.")
		else:
			emit_signal("api_error", "Listing not found. Please refresh marketplace.")

		return false

	var listing_details = verification.listing
	print("[TradingMarketplace] Found listing: %s x%d for %d credits" % [
		listing_details.get("item_name", "Unknown"),
		listing_details.get("quantity", 0),
		listing_details.get("total_price", 0)
	])

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
	print("[TradingMarketplace] Finding listing by ID: %s" % listing_id)

	# Search through cached listings first (most recent data)
	for listing in cached_listings:
		if listing.get("listing_id", "") == listing_id:
			print("[TradingMarketplace] Found listing in cache: %s" % listing.get("item_name", "Unknown"))
			return listing

	# If not found in cache, search through player's active listings
	for listing in player_active_listings:
		if listing.get("listing_id", "") == listing_id:
			print("[TradingMarketplace] Found listing in player active listings: %s" % listing.get("item_name", "Unknown"))
			return listing

	# If still not found, check if we have fresh listings data by looking at cache age
	var current_time = Time.get_unix_time_from_system()
	var cache_age = current_time - listings_cache_timestamp

	if cache_age > listings_cache_duration:
		print("[TradingMarketplace] WARNING: Listing cache is stale (%.1f seconds old), listing may have been removed" % cache_age)

	print("[TradingMarketplace] Listing %s not found in any cached data" % listing_id)
	return {}

# DEBUG AND TROUBLESHOOTING METHODS

## Get current marketplace state for debugging
func get_marketplace_debug_info() -> Dictionary:
	"""Get comprehensive debug information about marketplace state"""
	var current_time = Time.get_unix_time_from_system()
	var cache_age = current_time - listings_cache_timestamp

	return {
		"cached_listings_count": cached_listings.size(),
		"player_active_listings_count": player_active_listings.size(),
		"cache_age_seconds": cache_age,
		"cache_is_valid": cache_age <= listings_cache_duration,
		"cached_listing_ids": cached_listings.map(func(listing): return listing.get("listing_id", "NO_ID")),
		"purchase_state": _state_to_string(current_purchase_state),
		"pending_requests_count": pending_requests.size(),
		"sample_cached_listing": cached_listings[0] if cached_listings.size() > 0 else {}
	}

## Print marketplace debug information to console
func debug_print_marketplace_state() -> void:
	"""Print detailed marketplace state to console for debugging"""
	var debug_info = get_marketplace_debug_info()
	print("[TradingMarketplace] === MARKETPLACE DEBUG INFO ===")
	print("[TradingMarketplace] Cached listings: %d" % debug_info.cached_listings_count)
	print("[TradingMarketplace] Player active listings: %d" % debug_info.player_active_listings_count)
	print("[TradingMarketplace] Cache age: %.1f seconds (valid: %s)" % [debug_info.cache_age_seconds, debug_info.cache_is_valid])
	print("[TradingMarketplace] Purchase state: %s" % debug_info.purchase_state)
	print("[TradingMarketplace] Pending requests: %d" % debug_info.pending_requests_count)
	print("[TradingMarketplace] Available listing IDs: %s" % str(debug_info.cached_listing_ids))

	if debug_info.sample_cached_listing:
		print("[TradingMarketplace] Sample listing structure: %s" % str(debug_info.sample_cached_listing))

	print("[TradingMarketplace] === END DEBUG INFO ===")

## Verify that a listing exists before attempting purchase
func verify_listing_exists(listing_id: String) -> Dictionary:
	"""Verify a listing exists and return its details with validation info"""
	var result = {
		"exists": false,
		"listing": {},
		"error": "",
		"debug_info": {}
	}

	# Ensure listing_id is valid
	if listing_id == null or listing_id.strip_edges() == "":
		result.error = "Invalid listing ID provided"
		return result

	# Get the listing with error checking
	var listing = _find_listing_by_id(listing_id)
	if listing == null or listing.is_empty():
		result.error = "Listing %s not found in cached data" % listing_id
		result.debug_info = get_marketplace_debug_info()
		return result

	# Verify listing is still active
	var status = listing.get("status", "unknown")
	if status != "unknown" and status != "active":
		result.error = "Listing %s is not active (status: %s)" % [listing_id, status]
		result.listing = listing
		return result

	# Check if listing has required fields for purchase
	var required_fields = ["item_name", "quantity", "asking_price", "seller_id"]
	var missing_fields = []

	for field in required_fields:
		var field_value = listing.get(field, null)
		var is_missing = false

		# Check based on field type
		if field_value == null:
			is_missing = true
		elif field in ["item_name", "seller_id"]:
			# String fields - check for empty string
			is_missing = (field_value == "" or str(field_value).strip_edges() == "")
		elif field in ["quantity", "asking_price"]:
			# Numeric fields - check for zero or negative values
			is_missing = (field_value <= 0)
		else:
			# Unknown field type - just check for null/empty
			is_missing = (field_value == null or field_value == "")

		if not listing.has(field) or is_missing:
			missing_fields.append(field)

	if missing_fields.size() > 0:
		result.error = "Listing %s missing required fields: %s" % [listing_id, str(missing_fields)]
		result.listing = listing
		return result

	# Calculate total price (may be missing from listing)
	var asking_price = listing.get("asking_price", 0)
	var quantity = listing.get("quantity", 1)
	if not listing.has("total_price"):
		listing["total_price"] = asking_price * quantity
		print("[TradingMarketplace] Added missing total_price to listing: %d" % listing["total_price"])

	result.exists = true
	result.listing = listing
	return result

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

# PHASE 1.4: Signal Connection Verification & Auto-Recovery
func verify_signal_connections() -> Dictionary:
	"""Verify all signal connections are working properly"""
	var connection_status = {
		"timestamp": Time.get_unix_time_from_system(),
		"all_connected": true,
		"connection_details": {},
		"missing_connections": [],
		"recommendations": []
	}

	print("[TradingMarketplace] Verifying signal connections...")

	# Check each signal that should be connected
	var expected_signals = [
		"listings_received",
		"listing_posted",
		"listing_removed",
		"item_purchased",
		"trade_completed",
		"api_error",
		"purchase_state_changed"
	]

	for signal_name in expected_signals:
		var signal_obj = get_signal_list().filter(func(s): return s.name == signal_name)
		if signal_obj.size() > 0:
			var connections = get_signal_connection_list(signal_name)
			connection_status.connection_details[signal_name] = {
				"exists": true,
				"connection_count": connections.size(),
				"connections": connections
			}

			if connections.size() == 0:
				connection_status.all_connected = false
				connection_status.missing_connections.append(signal_name)
				print("[TradingMarketplace] WARNING: Signal '%s' has no connections" % signal_name)
		else:
			connection_status.connection_details[signal_name] = {
				"exists": false,
				"connection_count": 0,
				"connections": []
			}
			connection_status.all_connected = false
			connection_status.missing_connections.append(signal_name)
			print("[TradingMarketplace] ERROR: Signal '%s' does not exist" % signal_name)

	# Generate recommendations
	if not connection_status.all_connected:
		connection_status.recommendations.append("Call connect_to_ui() to establish UI connections")
		connection_status.recommendations.append("Verify LobbyZone2D is properly initialized")
		connection_status.recommendations.append("Check for signal connection failures in logs")

	print("[TradingMarketplace] Signal verification complete - All connected: %s" % connection_status.all_connected)
	return connection_status

func connect_to_ui(ui_node: Node) -> bool:
	"""Connect marketplace signals to UI node with verification"""
	if not ui_node:
		print("[TradingMarketplace] ERROR: UI node is null")
		return false

	print("[TradingMarketplace] Connecting signals to UI node: %s" % ui_node.name)

	var connection_map = {
		"listings_received": "_on_marketplace_listings_received",
		"listing_posted": "_on_item_posting_result",
		"listing_removed": "_on_listing_removal_result",
		"item_purchased": "_on_item_purchase_result",
		"api_error": "_on_marketplace_api_error",
		"purchase_state_changed": "_on_purchase_state_changed"
	}

	var all_connected = true
	var successful_connections = 0

	for signal_name in connection_map:
		var method_name = connection_map[signal_name]

		# Check if signal is already connected
		if is_connected(signal_name, Callable(ui_node, method_name)):
			print("[TradingMarketplace] Signal '%s' already connected" % signal_name)
			successful_connections += 1
			continue

		# Check if method exists on UI node
		if not ui_node.has_method(method_name):
			print("[TradingMarketplace] ERROR: UI node does not have method '%s'" % method_name)
			all_connected = false
			continue

		# Attempt connection
		var connect_result = connect(signal_name, Callable(ui_node, method_name))
		if connect_result == OK:
			print("[TradingMarketplace] Successfully connected '%s' -> '%s'" % [signal_name, method_name])
			successful_connections += 1
		else:
			print("[TradingMarketplace] ERROR: Failed to connect '%s' -> '%s' (error: %d)" % [signal_name, method_name, connect_result])
			all_connected = false

	print("[TradingMarketplace] Connection summary: %d/%d successful" % [successful_connections, connection_map.size()])
	return all_connected

func attempt_signal_recovery() -> bool:
	"""Attempt to recover failed signal connections"""
	print("[TradingMarketplace] Attempting signal connection recovery...")

	# Try to find LobbyZone2D node
	var lobby_node = get_tree().get_first_node_in_group("lobby_zone_2d")
	if not lobby_node:
		# Try alternative paths
		lobby_node = get_node_or_null("/root/LobbyZone2D")
		if not lobby_node:
			lobby_node = get_tree().current_scene

	if lobby_node:
		print("[TradingMarketplace] Found UI node for recovery: %s" % lobby_node.name)
		return connect_to_ui(lobby_node)
	else:
		print("[TradingMarketplace] ERROR: Could not find UI node for signal recovery")
		return false

func get_connection_health_report() -> Dictionary:
	"""Get comprehensive connection health report"""
	var verification = verify_signal_connections()
	var health_report = {
		"overall_health": "healthy" if verification.all_connected else "degraded",
		"connection_verification": verification,
		"recommendations": [],
		"last_check": Time.get_unix_time_from_system()
	}

	if not verification.all_connected:
		health_report.overall_health = "degraded"
		health_report.recommendations.extend(verification.recommendations)
		health_report.recommendations.append("Consider calling attempt_signal_recovery()")

		# Check if this is affecting functionality
		if "item_purchased" in verification.missing_connections:
			health_report.overall_health = "critical"
			health_report.recommendations.append("CRITICAL: Purchase signals not connected - UI will not update")

	return health_report

# PHASE 1.1: Timeout Management System
func _setup_timeout_management():
	"""Setup timeout management for HTTP requests"""
	# Load timeout configuration from TradingConfig
	request_timeout = TradingConfig.get_request_timeout()

	timeout_timer = Timer.new()
	timeout_timer.wait_time = 1.0  # Check every second
	timeout_timer.timeout.connect(_check_request_timeouts)
	timeout_timer.autostart = true
	add_child(timeout_timer)

	print("[TradingMarketplace] Timeout management initialized - timeout: %.1fs" % request_timeout)

	# Log configuration summary
	var config_summary = TradingConfig.get_config_summary()
	print("[TradingMarketplace] Configuration: %s" % str(config_summary))

func _check_request_timeouts():
	"""Check for and handle timed out requests"""
	var current_time = Time.get_unix_time_from_system()
	var timed_out_requests = []

	for request_id in pending_requests:
		var request_data = pending_requests[request_id]
		if current_time - request_data.start_time > request_timeout:
			timed_out_requests.append(request_id)

	# Handle timed out requests
	for request_id in timed_out_requests:
		_handle_request_timeout(request_id)

func _track_request(operation_type: String, operation_data: Dictionary = {}) -> String:
	"""Track a new request and return its ID"""
	request_id_counter += 1
	var request_id = "req_%d_%s" % [request_id_counter, operation_type]

	pending_requests[request_id] = {
		"operation_type": operation_type,
		"start_time": Time.get_unix_time_from_system(),
		"operation_data": operation_data
	}

	print("[TradingMarketplace] Tracking request %s: %s" % [request_id, operation_type])
	return request_id

func _complete_request(request_id: String):
	"""Mark a request as completed"""
	if request_id in pending_requests:
		var request_data = pending_requests[request_id]
		var duration = Time.get_unix_time_from_system() - request_data.start_time
		print("[TradingMarketplace] Request %s completed in %.2f seconds" % [request_id, duration])
		pending_requests.erase(request_id)

func _handle_request_timeout(request_id: String):
	"""Handle a request that has timed out"""
	if not request_id in pending_requests:
		return

	var request_data = pending_requests[request_id]
	var operation_type = request_data.operation_type

	print("[TradingMarketplace] Request timed out: %s (%s)" % [request_id, operation_type])

	# Handle specific timeout scenarios
	match operation_type:
		"purchase":
			_handle_purchase_timeout(request_data)
		"post_listing":
			_handle_post_timeout(request_data)
		"remove_listing":
			_handle_removal_timeout(request_data)
		"get_listings":
			_handle_listings_timeout(request_data)
		_:
			emit_signal("api_error", "Request timed out: %s" % operation_type)

	# Remove from pending requests
	pending_requests.erase(request_id)

func _handle_purchase_timeout(request_data: Dictionary):
	"""Handle purchase request timeout with credit rollback"""
	var operation_data = request_data.operation_data
	var total_price = operation_data.get("total_price", 0)

	print("[TradingMarketplace] Purchase timed out - rolling back %d credits" % total_price)

	# PHASE 1.2: Set timed out state
	_set_purchase_state(PurchaseState.TIMED_OUT, {
		"error": "Purchase request timed out",
		"timeout_time": Time.get_unix_time_from_system(),
		"rollback_attempted": false,
		"operation_data": operation_data
	})

	# Rollback optimistic credit hold
	if local_player_data and total_price > 0:
		local_player_data.add_credits(total_price)
		print("[TradingMarketplace] Rolled back %d credits from timed out purchase" % total_price)

		# Update state to indicate rollback was successful
		purchase_state_data["rollback_attempted"] = true
		purchase_state_data["rollback_amount"] = total_price

	emit_signal("item_purchased", false, "")
	emit_signal("api_error", "Purchase request timed out. Credits have been restored.")

func _handle_post_timeout(request_data: Dictionary):
	"""Handle listing post timeout"""
	print("[TradingMarketplace] Listing post timed out")
	emit_signal("listing_posted", false, "")
	emit_signal("api_error", "Failed to post item - request timed out. Please try again.")

func _handle_removal_timeout(request_data: Dictionary):
	"""Handle listing removal timeout"""
	print("[TradingMarketplace] Listing removal timed out")
	emit_signal("listing_removed", false, "")
	emit_signal("api_error", "Failed to remove listing - request timed out. Please try again.")

func _handle_listings_timeout(request_data: Dictionary):
	"""Handle listings fetch timeout"""
	print("[TradingMarketplace] Listings fetch timed out")
	emit_signal("api_error", "Failed to load marketplace listings - connection timed out.")

# PHASE 1.2: Purchase State Management Methods
func _set_purchase_state(new_state: PurchaseState, data: Dictionary = {}):
	"""Set purchase state and emit signal"""
	var old_state = current_purchase_state
	current_purchase_state = new_state
	purchase_state_data = data

	print("[TradingMarketplace] State: %s -> %s" % [_state_to_string(old_state), _state_to_string(new_state)])

	# Add state change timestamp
	purchase_state_data["state_change_time"] = Time.get_unix_time_from_system()
	purchase_state_data["previous_state"] = old_state

	emit_signal("purchase_state_changed", new_state, purchase_state_data)

func _state_to_string(state: PurchaseState) -> String:
	"""Convert purchase state enum to readable string"""
	match state:
		PurchaseState.IDLE:
			return "IDLE"
		PurchaseState.VALIDATING:
			return "VALIDATING"
		PurchaseState.SENDING_REQUEST:
			return "SENDING_REQUEST"
		PurchaseState.PROCESSING:
			return "PROCESSING"
		PurchaseState.COMPLETED:
			return "COMPLETED"
		PurchaseState.FAILED:
			return "FAILED"
		PurchaseState.TIMED_OUT:
			return "TIMED_OUT"
		_:
			return "UNKNOWN"

func get_current_purchase_state() -> PurchaseState:
	"""Get current purchase state"""
	return current_purchase_state

func get_purchase_state_data() -> Dictionary:
	"""Get current purchase state data"""
	return purchase_state_data

func is_purchase_in_progress() -> bool:
	"""Check if a purchase is currently in progress"""
	return current_purchase_state in [PurchaseState.VALIDATING, PurchaseState.SENDING_REQUEST, PurchaseState.PROCESSING]

func reset_purchase_state():
	"""Reset purchase state to IDLE"""
	_set_purchase_state(PurchaseState.IDLE)

# PHASE 1.3: Enhanced Error Recovery & Credit Rollback
func _handle_purchase_failure(reason: String, error_code: int = 0, additional_data: Dictionary = {}):
	"""Enhanced purchase failure handling with comprehensive rollback"""
	print("[TradingMarketplace] Purchase failed: %s (code: %d)" % [reason, error_code])

	# Rollback credit hold if it exists
	if purchase_state_data.has("held_credits") and purchase_state_data.has("original_credits"):
		var held_amount = purchase_state_data.get("held_credits", 0)
		var original_credits = purchase_state_data.get("original_credits", 0)

		# Verify current credits and restore if needed
		var current_credits = local_player_data.get_credits() if local_player_data else 0
		var expected_credits = original_credits - held_amount  # What credits should be after hold

		if current_credits != original_credits and current_credits == expected_credits:
			# Credits are held, need to restore them
			local_player_data.set_credits(original_credits)
			print("[TradingMarketplace] Rolled back %d credits (restored to %d)" % [held_amount, original_credits])

			# Log the credit transaction
			_log_credit_transaction("rollback", held_amount, {
				"reason": reason,
				"error_code": error_code,
				"from_credits": current_credits,
				"to_credits": original_credits
			})

	# Set failed state with comprehensive error data
	_set_purchase_state(PurchaseState.FAILED, {
		"error": reason,
		"error_code": error_code,
		"error_category": _categorize_error(reason, error_code),
		"additional_data": additional_data,
		"rollback_successful": true
	})

	emit_signal("item_purchased", false, "")
	emit_signal("api_error", reason)

func _categorize_error(error_message: String, error_code: int) -> String:
	"""Categorize errors for better handling"""
	# Network/connectivity errors
	if error_code == 0 or error_message.find("Failed to send") != -1:
		return "network_error"

	# Server errors
	if error_code >= 500:
		return "server_error"

	# Client errors
	if error_code >= 400 and error_code < 500:
		if error_message.find("insufficient") != -1:
			return "insufficient_credits"
		elif error_message.find("already sold") != -1 or error_message.find("purchased by another player") != -1:
			return "item_already_sold"
		elif error_message.find("Price changed") != -1:
			return "price_changed"
		else:
			return "client_error"

	# Timeout errors
	if error_message.find("timed out") != -1:
		return "timeout_error"

	# API configuration errors
	if error_message.find("configuration") != -1 or error_message.find("unavailable") != -1:
		return "api_configuration"

	return "unknown_error"

func _log_credit_transaction(transaction_type: String, amount: int, metadata: Dictionary = {}):
	"""Log credit transactions for audit trail"""
	if not local_player_data:
		return

	var transaction_log = {
		"timestamp": Time.get_unix_time_from_system(),
		"datetime": Time.get_datetime_string_from_system(),
		"type": transaction_type,
		"amount": amount,
		"player_id": local_player_data.get_player_id(),
		"credits_before": metadata.get("from_credits", 0),
		"credits_after": metadata.get("to_credits", 0),
		"metadata": metadata
	}

	print("[TradingMarketplace] Credit Transaction: %s" % str(transaction_log))

	# Could be extended to store in local file or send to analytics

func get_error_recovery_suggestions(error_category: String) -> Array[String]:
	"""Get recovery suggestions based on error category"""
	match error_category:
		"network_error":
			return [
				"Check your internet connection",
				"Try refreshing the marketplace",
				"Wait a moment and try again"
			]
		"insufficient_credits":
			return [
				"Sell items to earn more credits",
				"Check your current credit balance",
				"Try purchasing a less expensive item"
			]
		"item_already_sold":
			return [
				"Refresh the marketplace listings",
				"Look for similar items",
				"Try a different listing"
			]
		"price_changed":
			return [
				"Refresh to see current prices",
				"The seller may have updated their price",
				"Try the purchase again with updated price"
			]
		"timeout_error":
			return [
				"Check your internet connection",
				"Try again in a few moments",
				"Contact support if this persists"
			]
		"api_configuration":
			return [
				"Contact support",
				"Check if the marketplace is under maintenance",
				"Try again later"
			]
		_:
			return [
				"Try again in a few moments",
				"Contact support if this problem persists"
			]

func attempt_automatic_recovery(error_category: String) -> bool:
	"""Attempt automatic recovery based on error type"""
	match error_category:
		"network_error", "timeout_error":
			# For network issues, we could implement retry logic
			print("[TradingMarketplace] Network error detected - automatic retry could be implemented")
			return false  # Not implemented yet
		"item_already_sold":
			# Refresh listings automatically
			print("[TradingMarketplace] Item already sold - refreshing listings")
			get_listings()
			return true
		"price_changed":
			# Refresh listings to show current prices
			print("[TradingMarketplace] Price changed - refreshing listings")
			get_listings()
			return true
		_:
			return false
