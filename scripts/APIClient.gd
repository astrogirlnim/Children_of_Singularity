# APIClient.gd
# Hybrid API client that supports both backend and local-only modes
# Development: Uses HTTP backend at localhost:8000
# Release: Falls back to LocalPlayerData.gd for offline functionality

class_name APIClient
extends HTTPRequest

## Signal emitted when player data is loaded
signal player_data_loaded(player_data: Dictionary)

## Signal emitted when inventory is updated
signal inventory_updated(inventory_data: Array)

## Signal emitted when credits are updated
signal credits_updated(credits: int)

## Signal emitted when API request fails
signal api_error(error_message: String)

## Signal emitted when upgrade purchase is successful
signal upgrade_purchased(result: Dictionary)

## Signal emitted when upgrade purchase fails
signal upgrade_purchase_failed(reason: String, upgrade_type: String)

## Signal emitted when upgrades are cleared
signal upgrades_cleared(cleared_data: Dictionary)

# API configuration
var base_url: String = "http://localhost:8000/api/v1"
var player_id: String = "550e8400-e29b-41d4-a716-446655440000"
var request_timeout: float = 30.0

# Fallback mode for releases
var use_local_storage: bool = false
var local_player_data: LocalPlayerData

# Request tracking
var pending_requests: Dictionary = {}
var request_id_counter: int = 0

# Retry logic for upgrade purchases
var max_retries: int = 3
var retry_delay: float = 1.0

func _ready() -> void:
	_log_message("APIClient: === INITIALIZING HTTP CLIENT ===")
	_log_message("APIClient: Initializing HTTP client")

	# Initialize reference to LocalPlayerData autoload singleton
	local_player_data = LocalPlayerData
	_log_message("APIClient: LocalPlayerData reference obtained - is_initialized: %s" % local_player_data.is_initialized)

	# Wait for LocalPlayerData to be fully loaded before proceeding
	if not local_player_data.is_initialized:
		_log_message("APIClient: LocalPlayerData not ready, waiting for player_data_loaded signal...")
		await local_player_data.player_data_loaded
		_log_message("APIClient: LocalPlayerData ready signal received, proceeding with initialization")
		_log_message("APIClient: LocalPlayerData now reports is_initialized: %s" % local_player_data.is_initialized)
	else:
		_log_message("APIClient: LocalPlayerData already initialized, proceeding immediately")

	# Check if we should use local storage mode
	_log_message("APIClient: Detecting storage mode...")
	await _detect_storage_mode()

	# NOW check the mode AFTER detection is complete
	if not use_local_storage:
		request_completed.connect(_on_request_completed)
		request_timeout = 30.0
		_log_message("APIClient: Backend mode enabled")
	else:
		_log_message("APIClient: Local storage mode enabled")

	# Validate the default player ID
	if not _is_valid_uuid(player_id):
		_log_message("APIClient: WARNING - Default player_id is not a valid UUID: %s" % player_id)

	_log_message("APIClient: === CLIENT READY IN %s MODE ===" % ("local" if use_local_storage else "backend"))
	_log_message("APIClient: Client ready in %s mode" % ("local" if use_local_storage else "backend"))

## Check if APIClient is using local storage mode
func is_using_local_storage() -> bool:
	"""Return true if APIClient is operating in local storage mode"""
	return use_local_storage

## Validate UUID format
func _is_valid_uuid(uuid_string: String) -> bool:
	"""Validate that a string is a properly formatted UUID"""
	if uuid_string.is_empty():
		return false

	# UUID format: 8-4-4-4-12 characters (36 total with hyphens)
	# Example: 550e8400-e29b-41d4-a716-446655440000
	var uuid_regex = RegEx.new()
	uuid_regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

	var result = uuid_regex.search(uuid_string)
	var is_valid = result != null

	if not is_valid:
		_log_message("APIClient: Invalid UUID format detected: %s" % uuid_string)

	return is_valid

## Detect whether to use backend or local storage
func _detect_storage_mode() -> void:
	_log_message("APIClient: Testing backend connectivity...")

	# Try to connect to backend with short timeout
	var test_request = HTTPRequest.new()
	add_child(test_request)
	test_request.timeout = 2.0  # Very short timeout

	var url = base_url + "/health"
	var error = test_request.request(url)

	if error != OK:
		_log_message("APIClient: Failed to send test request, using local storage mode")
		use_local_storage = true
		test_request.queue_free()
		return

	# Wait for response or timeout
	var response = await test_request.request_completed
	test_request.queue_free()

	# Check if we got a successful response
	var response_code = response[1]
	if response_code == 200:
		_log_message("APIClient: Backend available (health check returned %d)" % response_code)
		use_local_storage = false
	else:
		_log_message("APIClient: Backend not available (health check failed: %d), using local storage mode" % response_code)
		use_local_storage = true

## Load player data (unified interface)
func load_player_data(target_player_id: String = "") -> void:
	if target_player_id.is_empty():
		target_player_id = self.player_id

	if use_local_storage:
		_load_player_data_local(target_player_id)
	else:
		_load_player_data_backend(target_player_id)

## Local storage implementation
func _load_player_data_local(target_player_id: String) -> void:
	_log_message("APIClient: === LOADING PLAYER DATA FROM LOCAL STORAGE ===")
	_log_message("APIClient: Loading player data from local storage")
	_log_message("APIClient: Target player ID: %s" % target_player_id)

	# Ensure LocalPlayerData is fully initialized
	if not local_player_data.is_initialized:
		_log_message("APIClient: LocalPlayerData not ready, waiting...")
		await local_player_data.player_data_loaded
		_log_message("APIClient: LocalPlayerData is now ready")

	_log_message("APIClient: Accessing LocalPlayerData - is_initialized: %s" % local_player_data.is_initialized)
	_log_message("APIClient: LocalPlayerData.player_data: %s" % local_player_data.player_data)
	_log_message("APIClient: LocalPlayerData.player_upgrades: %s" % local_player_data.player_upgrades)

	# Use LocalPlayerData singleton
	var player_data = {
		"id": target_player_id,
		"name": local_player_data.get_player_name(),
		"credits": local_player_data.get_credits(),
		"upgrades": local_player_data.player_upgrades,
		"progression": local_player_data.player_data.get("progression", {}),
		"position": local_player_data.player_data.get("position", {"x": 0, "y": 0, "z": 0})
	}

	_log_message("APIClient: Constructed player data: %s" % player_data)
	_log_message("APIClient: Loaded local player data - Credits: %d, Upgrades: %s" % [player_data["credits"], player_data["upgrades"]])

	# Emit signal with local data
	player_data_loaded.emit(player_data)
	_log_message("APIClient: === PLAYER DATA LOADED AND EMITTED ===")

## Backend implementation (existing code)
func _load_player_data_backend(target_player_id: String) -> void:
	if not _is_valid_uuid(target_player_id):
		var error_msg = "APIClient: Cannot load player data - invalid UUID: %s" % target_player_id
		_log_message(error_msg)
		return

	var url = "%s/players/%s" % [base_url, target_player_id]
	_log_message("APIClient: Loading player data from %s" % url)

	var request_id = _make_request(url, HTTPClient.METHOD_GET, [], "load_player_data")
	if request_id == -1:
		api_error.emit("Failed to initiate player data load request")

## Save player data (unified interface)
func save_player_data(player_data: Dictionary) -> void:
	if use_local_storage:
		_save_player_data_local(player_data)
	else:
		_save_player_data_backend(player_data)

## Local save implementation
func _save_player_data_local(player_data: Dictionary) -> void:
	_log_message("APIClient: Saving player data to local storage")

	# Update LocalPlayerData with provided data
	if player_data.has("credits"):
		local_player_data.set_credits(player_data["credits"])

	if player_data.has("name"):
		local_player_data.set_player_name(player_data["name"])

	if player_data.has("upgrades"):
		local_player_data.player_upgrades = player_data["upgrades"]
		local_player_data.save_upgrades()

	if player_data.has("progression"):
		local_player_data.player_data["progression"] = player_data["progression"]
		local_player_data.save_player_data()

	_log_message("APIClient: Player data saved to local storage")

## Backend save implementation
func _save_player_data_backend(player_data: Dictionary) -> void:
	if not _is_valid_uuid(player_id):
		var error_msg = "Invalid UUID format for player ID: %s" % player_id
		_log_message("APIClient: %s" % error_msg)
		api_error.emit(error_msg)
		return

	var url = "%s/players/%s" % [base_url, player_id]
	_log_message("APIClient: Saving player data to %s" % url)

	var json_data = JSON.stringify(player_data)
	var headers = ["Content-Type: application/json"]
	var request_id = _make_request(url, HTTPClient.METHOD_POST, headers, json_data)
	if request_id == -1:
		api_error.emit("Failed to initiate player data save request")

## Load inventory (unified interface)
func load_inventory(target_player_id: String = "") -> void:
	if target_player_id.is_empty():
		target_player_id = self.player_id

	if use_local_storage:
		_load_inventory_local(target_player_id)
	else:
		_load_inventory_backend(target_player_id)

## Local inventory loading
func _load_inventory_local(target_player_id: String) -> void:
	_log_message("APIClient: === LOADING INVENTORY FROM LOCAL STORAGE ===")
	_log_message("APIClient: Loading inventory from local storage")

	# Ensure LocalPlayerData is fully initialized
	if not local_player_data.is_initialized:
		_log_message("APIClient: LocalPlayerData not ready for inventory, waiting...")
		await local_player_data.player_data_loaded

	# Get inventory from LocalPlayerData
	var inventory_data = local_player_data.player_inventory

	_log_message("APIClient: Raw inventory from LocalPlayerData: %s" % inventory_data)
	_log_message("APIClient: Loaded local inventory - %d items" % inventory_data.size())

	# Emit signal with inventory data
	inventory_updated.emit(inventory_data)
	_log_message("APIClient: === INVENTORY LOADED AND EMITTED ===")

## Backend inventory loading
func _load_inventory_backend(target_player_id: String) -> void:
	if not _is_valid_uuid(target_player_id):
		var error_msg = "Invalid UUID format for player ID: %s" % target_player_id
		_log_message("APIClient: %s" % error_msg)
		api_error.emit(error_msg)
		return

	var url = "%s/players/%s/inventory" % [base_url, target_player_id]
	_log_message("APIClient: Loading inventory from %s" % url)

	var request_id = _make_request(url, HTTPClient.METHOD_GET, [], "load_inventory")
	if request_id == -1:
		api_error.emit("Failed to initiate inventory load request")

## Add inventory item (unified interface)
func add_inventory_item(item_data: Dictionary) -> void:
	if use_local_storage:
		_add_inventory_item_local(item_data)
	else:
		_add_inventory_item_backend(item_data)

## Local inventory addition
func _add_inventory_item_local(item_data: Dictionary) -> void:
	_log_message("APIClient: Adding item to local inventory: %s" % item_data)

	# Add item to LocalPlayerData inventory
	local_player_data.player_inventory.append(item_data)
	local_player_data.save_inventory()

	# Emit inventory updated signal
	inventory_updated.emit(local_player_data.player_inventory)

## Backend inventory addition
func _add_inventory_item_backend(item_data: Dictionary) -> void:
	if not _is_valid_uuid(player_id):
		var error_msg = "Invalid UUID format for player ID: %s" % player_id
		_log_message("APIClient: %s" % error_msg)
		api_error.emit(error_msg)
		return

	var url = "%s/players/%s/inventory" % [base_url, player_id]
	_log_message("APIClient: Adding inventory item to %s" % url)

	var json_data = JSON.stringify(item_data)
	var headers = ["Content-Type: application/json"]
	var request_id = _make_request(url, HTTPClient.METHOD_POST, headers, json_data)
	if request_id == -1:
		api_error.emit("Failed to initiate inventory add request")

## Clear inventory (unified interface)
func clear_inventory() -> void:
	if use_local_storage:
		_clear_inventory_local()
	else:
		_clear_inventory_backend()

## Local inventory clearing
func _clear_inventory_local() -> void:
	_log_message("APIClient: Clearing local inventory")

	local_player_data.player_inventory.clear()
	local_player_data.save_inventory()

	# Emit signal
	inventory_updated.emit([])

## Backend inventory clearing
func _clear_inventory_backend() -> void:
	if not _is_valid_uuid(player_id):
		var error_msg = "Invalid UUID format for player ID: %s" % player_id
		_log_message("APIClient: %s" % error_msg)
		api_error.emit(error_msg)
		return

	var url = "%s/players/%s/inventory" % [base_url, player_id]
	_log_message("APIClient: Clearing inventory at %s" % url)

	var request_id = _make_request(url, HTTPClient.METHOD_DELETE, [], "clear_inventory")
	if request_id == -1:
		api_error.emit("Failed to initiate inventory clear request")

## Clear upgrades (unified interface)
func clear_upgrades() -> void:
	if use_local_storage:
		_clear_upgrades_local()
	else:
		_clear_upgrades_backend()

## Local upgrades clearing
func _clear_upgrades_local() -> void:
	_log_message("APIClient: Clearing local upgrades")

	local_player_data.player_upgrades.clear()
	local_player_data.save_upgrades()

	# Emit signal
	upgrades_cleared.emit({"success": true})

## Backend upgrades clearing
func _clear_upgrades_backend() -> void:
	if not _is_valid_uuid(player_id):
		var error_msg = "Invalid UUID format for player ID: %s" % player_id
		_log_message("APIClient: %s" % error_msg)
		api_error.emit(error_msg)
		return

	var url = "%s/players/%s/upgrades" % [base_url, player_id]
	_log_message("APIClient: Clearing all upgrades at %s" % url)

	var request_id = _make_request(url, HTTPClient.METHOD_DELETE, [], "clear_upgrades")
	if request_id == -1:
		api_error.emit("Failed to initiate upgrades clear request")

## Update credits (unified interface)
func update_credits(credit_change: int) -> void:
	if use_local_storage:
		_update_credits_local(credit_change)
	else:
		_update_credits_backend(credit_change)

## Local credits update
func _update_credits_local(credit_change: int) -> void:
	_log_message("APIClient: Updating credits locally by %d" % credit_change)

	local_player_data.add_credits(credit_change)
	var new_credits = local_player_data.get_credits()

	_log_message("APIClient: Credits updated to %d" % new_credits)

## Backend credits update
func _update_credits_backend(credit_change: int) -> void:
	var credit_data = {"credit_change": credit_change}

	var url = "%s/players/%s/credits" % [base_url, player_id]
	_log_message("APIClient: Updating credits at %s" % url)

	var json_data = JSON.stringify(credit_data)
	var headers = ["Content-Type: application/json"]
	var request_id = _make_request(url, HTTPClient.METHOD_POST, headers, json_data)
	if request_id == -1:
		api_error.emit("Failed to initiate credits update request")

## Health check (unified interface)
func check_backend_health() -> void:
	if use_local_storage:
		_check_health_local()
	else:
		_check_health_backend()

## Local health check (always succeeds)
func _check_health_local() -> void:
	_log_message("APIClient: Local storage health check - always healthy")
	# Emit success signal immediately
	call_deferred("_emit_health_success")

func _emit_health_success() -> void:
	# Simulate successful health check response
	pass

## Backend health check
func _check_health_backend() -> void:
	var url = "%s/health" % base_url
	_log_message("APIClient: Checking backend health at %s" % url)

	var request_id = _make_request(url, HTTPClient.METHOD_GET, [], "health_check")
	if request_id == -1:
		api_error.emit("Failed to initiate health check request")

## Unified upgrade purchase interface
func purchase_upgrade(upgrade_type: String, expected_cost: int, target_player_id: String = "") -> void:
	if target_player_id.is_empty():
		target_player_id = self.player_id

	if use_local_storage:
		_purchase_upgrade_local(upgrade_type, expected_cost, target_player_id)
	else:
		_purchase_upgrade_backend(upgrade_type, expected_cost, target_player_id)

## Local upgrade purchase
func _purchase_upgrade_local(upgrade_type: String, expected_cost: int, target_player_id: String) -> void:
	_log_message("APIClient: Processing local upgrade purchase - Type: %s, Cost: %d" % [upgrade_type, expected_cost])

	# Check if player has enough credits
	var current_credits = local_player_data.get_credits()
	if current_credits < expected_cost:
		_log_message("APIClient: Insufficient credits for upgrade - Have: %d, Need: %d" % [current_credits, expected_cost])
		# Emit failure signal with proper parameters
		var error_message = "Insufficient credits. Need: %d, Have: %d" % [expected_cost, current_credits]
		upgrade_purchase_failed.emit(error_message, upgrade_type)
		return

	# Deduct credits
	local_player_data.add_credits(-expected_cost)

	# Apply upgrade
	var current_level = local_player_data.player_upgrades.get(upgrade_type, 0)
	var new_level = current_level + 1
	local_player_data.player_upgrades[upgrade_type] = new_level
	local_player_data.save_upgrades()

	var new_credits = local_player_data.get_credits()
	_log_message("APIClient: Local upgrade successful - Type: %s, Level: %d, Credits remaining: %d" % [upgrade_type, new_level, new_credits])

	# Emit success signal with the same format as backend
	var result = {
		"upgrade_type": upgrade_type,
		"new_level": new_level,
		"cost": expected_cost,
		"remaining_credits": new_credits,
		"success": true
	}

	upgrade_purchased.emit(result)

## Backend upgrade purchase
func _purchase_upgrade_backend(upgrade_type: String, expected_cost: int, target_player_id: String) -> void:
	_log_message("APIClient: Initiating backend upgrade purchase - Type: %s, Expected Cost: %d, Player: %s" % [upgrade_type, expected_cost, target_player_id])

	# Validate input parameters
	if not _is_valid_uuid(target_player_id):
		var error_msg = "Invalid UUID format for player ID: %s" % target_player_id
		_log_message("APIClient: %s" % error_msg)
		return

	if upgrade_type.is_empty():
		var error_msg = "Invalid upgrade type: cannot be empty"
		_log_message("APIClient: %s" % error_msg)
		return

	if expected_cost < 0:
		var error_msg = "Invalid expected cost: cannot be negative (%d)" % expected_cost
		_log_message("APIClient: %s" % error_msg)
		return

	# Make the upgrade purchase request
	_make_upgrade_purchase_request(target_player_id, upgrade_type, expected_cost, 1)

func _make_upgrade_purchase_request(target_player_id: String, upgrade_type: String, expected_cost: int, attempt: int) -> void:
	##Internal method to make upgrade purchase request with retry logic
	var url = "%s/players/%s/upgrades/purchase" % [base_url, target_player_id]
	_log_message("APIClient: Making upgrade purchase request (attempt %d/%d) to %s" % [attempt, max_retries, url])

	# Prepare request body
	var request_data = {
		"upgrade_type": upgrade_type,
		"expected_cost": expected_cost
	}
	var json_data = JSON.stringify(request_data)
	var headers = ["Content-Type: application/json"]

	# Track request with upgrade-specific information
	var request_id = _make_request(url, HTTPClient.METHOD_POST, headers, "purchase_upgrade", json_data)
	if request_id == -1:
		if attempt < max_retries:
			_log_message("APIClient: Request failed, retrying in %f seconds (attempt %d/%d)" % [retry_delay, attempt + 1, max_retries])
			await get_tree().create_timer(retry_delay).timeout
			_make_upgrade_purchase_request(target_player_id, upgrade_type, expected_cost, attempt + 1)
		else:
			var error_msg = "Failed to initiate upgrade purchase request after %d attempts" % max_retries
			_log_message("APIClient: %s" % error_msg)
			upgrade_purchase_failed.emit(error_msg, upgrade_type)
	else:
		# Store additional context for this request
		if request_id in pending_requests:
			pending_requests[request_id]["upgrade_type"] = upgrade_type
			pending_requests[request_id]["expected_cost"] = expected_cost
			pending_requests[request_id]["attempt"] = attempt
			pending_requests[request_id]["target_player_id"] = target_player_id
		_log_message("APIClient: Upgrade purchase request sent successfully (ID: %d)" % request_id)

func _make_request(url: String, method: HTTPClient.Method, headers: Array, request_type: String, body: String = "") -> int:
	##Make an HTTP request and track it
	var request_id = request_id_counter
	request_id_counter += 1

	pending_requests[request_id] = {
		"type": request_type,
		"url": url,
		"timestamp": Time.get_unix_time_from_system()
	}

	var error = request(url, headers, method, body)
	if error != OK:
		_log_message("APIClient: HTTP request failed with error: %s" % error)
		pending_requests.erase(request_id)
		return -1

	return request_id

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	##Handle HTTP request completion
	var response_text = body.get_string_from_utf8()
	_log_message("APIClient: Request completed - Code: %d, Response: %s" % [response_code, response_text])

	# Parse JSON response
	var json = JSON.new()
	var parse_result = json.parse(response_text)
	var response_data = {}

	if parse_result == OK:
		response_data = json.data
	else:
		_log_message("APIClient: Failed to parse JSON response")
		api_error.emit("Failed to parse server response")
		return

	# Try to find the matching pending request to get context
	var request_context = _find_and_remove_matching_request(response_data, response_code)

	# Handle different response codes
	if response_code >= 200 and response_code < 300:
		_handle_successful_response(response_data, request_context)
	else:
		_handle_error_response(response_code, response_data, request_context)

func _find_and_remove_matching_request(response_data: Dictionary, response_code: int) -> Dictionary:
	##Find and remove the matching pending request to get context
	var context = {}

	# For now, we'll use a simple approach: find the most recent upgrade request
	# In a more sophisticated implementation, we could use request IDs or timestamps
	for request_id in pending_requests.keys():
		var request_info = pending_requests[request_id]
		if request_info.get("type") == "purchase_upgrade":
			context = request_info.duplicate()
			pending_requests.erase(request_id)
			_log_message("APIClient: Found matching upgrade purchase request context - Type: %s" % context.get("upgrade_type", "unknown"))
			break

	return context

func _handle_successful_response(response_data: Dictionary, request_context: Dictionary = {}) -> void:
	##Handle successful API responses
	_log_message("APIClient: Successful response received")

	# Determine response type based on content
	if "status" in response_data and response_data.status == "healthy":
		_log_message("APIClient: Backend health check passed")
	elif response_data.has("success") and response_data.has("new_level") and response_data.has("cost"):
		# This is an upgrade purchase response
		_handle_upgrade_purchase_response(response_data, request_context)
	elif response_data is Dictionary and "player_id" in response_data and "credits" in response_data:
		_log_message("APIClient: Player data received")
		player_data_loaded.emit(response_data)
	elif response_data is Dictionary and "inventory" in response_data:
		_log_message("APIClient: Inventory data received")
		var inventory_data = response_data.get("inventory", [])
		inventory_updated.emit(inventory_data)
	elif response_data is Dictionary and "cleared_upgrades" in response_data:
		_log_message("APIClient: Upgrades cleared successfully")
		upgrades_cleared.emit(response_data)
	elif response_data is Dictionary and "credits" in response_data:
		_log_message("APIClient: Credits updated")
		credits_updated.emit(response_data.credits)
	else:
		_log_message("APIClient: Generic success response")

func _handle_upgrade_purchase_response(response_data: Dictionary, request_context: Dictionary = {}) -> void:
	##Handle upgrade purchase specific responses
	var success = response_data.get("success", false)
	var upgrade_type = request_context.get("upgrade_type", "unknown")
	var error_message = response_data.get("error_message", "")

	if success:
		var new_level = response_data.get("new_level", 0)
		var cost = response_data.get("cost", 0)
		var remaining_credits = response_data.get("remaining_credits", 0)
		var expected_cost = request_context.get("expected_cost", 0)

		_log_message("APIClient: Upgrade purchase successful - Type: %s, Level: %d, Cost: %d (expected: %d), Remaining Credits: %d" % [upgrade_type, new_level, cost, expected_cost, remaining_credits])

		# Prepare result dictionary for signal emission
		var result = {
			"success": true,
			"new_level": new_level,
			"cost": cost,
			"remaining_credits": remaining_credits,
			"upgrade_type": upgrade_type,
			"expected_cost": expected_cost,
			"error_message": ""
		}

		upgrade_purchased.emit(result)

		# Also emit credits_updated signal for UI consistency
		credits_updated.emit(remaining_credits)

	else:
		_log_message("APIClient: Upgrade purchase failed - Type: %s, Error: %s" % [upgrade_type, error_message])
		upgrade_purchase_failed.emit(error_message, upgrade_type)

func _handle_error_response(response_code: int, response_data: Dictionary, request_context: Dictionary = {}) -> void:
	##Handle API error responses
	var error_message = "API Error %d" % response_code
	var upgrade_type = request_context.get("upgrade_type", "unknown")

	if "detail" in response_data:
		error_message += ": %s" % response_data.detail
	elif "message" in response_data:
		error_message += ": %s" % response_data.message
	elif "error_message" in response_data:
		error_message += ": %s" % response_data.error_message

	_log_message("APIClient: %s" % error_message)

	# Check if this is an upgrade purchase error
	if request_context.get("type") == "purchase_upgrade":
		_log_message("APIClient: Detected upgrade purchase error response for type: %s" % upgrade_type)
		upgrade_purchase_failed.emit(error_message, upgrade_type)
	elif response_data.has("success") and not response_data.success:
		# This is likely an upgrade purchase error based on response structure
		_log_message("APIClient: Detected upgrade purchase error response")
		upgrade_purchase_failed.emit(error_message, upgrade_type)
	else:
		# Generic API error
		api_error.emit(error_message)

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)

## Sell all inventory items (unified interface)
func sell_all_inventory() -> void:
	if use_local_storage:
		_sell_all_inventory_local()
	else:
		_sell_all_inventory_backend()

## Local sell all implementation
func _sell_all_inventory_local() -> void:
	_log_message("APIClient: Selling all inventory items locally")

	# Get current inventory to calculate total value
	var inventory_items = local_player_data.player_inventory
	if inventory_items.is_empty():
		_log_message("APIClient: No items to sell")
		return

	# Calculate total value of all items
	var total_value = 0
	var items_sold = 0
	for item in inventory_items:
		if item.has("value") and item.has("quantity"):
			total_value += item["value"] * item["quantity"]
			items_sold += item["quantity"]
		elif item.has("value"):
			total_value += item["value"]
			items_sold += 1

	# Clear inventory and get what was cleared
	var cleared_items = local_player_data.clear_inventory()

	# Add credits to player
	local_player_data.add_credits(total_value)

	_log_message("APIClient: Sold %d items for %d credits" % [items_sold, total_value])

	# Emit signals for UI updates
	inventory_updated.emit([])  # Empty inventory
	# Note: credits update will be handled by LocalPlayerData signals

## Backend sell all implementation
func _sell_all_inventory_backend() -> void:
	_log_message("APIClient: Selling all inventory via backend")

	# Get current inventory first to calculate value
	var url = base_url + "/players/" + player_id + "/inventory"
	request(url, PackedStringArray(), HTTPClient.METHOD_GET)

	var response = await request_completed
	var response_code = response[1]
	var response_body = response[3].get_string_from_utf8()

	if response_code != 200:
		_log_message("APIClient: Failed to get inventory for selling - Code: %d" % response_code)
		return

	var json = JSON.new()
	var parse_result = json.parse(response_body)
	if parse_result != OK:
		_log_message("APIClient: Failed to parse inventory response")
		return

	var inventory_data = json.data
	if not inventory_data.has("inventory"):
		_log_message("APIClient: No inventory data in response")
		return

	# Calculate total value
	var total_value = 0
	var items_sold = 0
	for item in inventory_data["inventory"]:
		if item.has("value") and item.has("quantity"):
			total_value += item["value"] * item["quantity"]
			items_sold += item["quantity"]
		elif item.has("value"):
			total_value += item["value"]
			items_sold += 1

	# Clear inventory via backend
	request(url, PackedStringArray(), HTTPClient.METHOD_DELETE)
	response = await request_completed
	response_code = response[1]

	if response_code != 200:
		_log_message("APIClient: Failed to clear inventory - Code: %d" % response_code)
		return

	# Add credits to player
	var credits_data = {"credits": total_value}
	var credits_json = JSON.stringify(credits_data)
	var headers = PackedStringArray(["Content-Type: application/json"])

	var credits_url = base_url + "/players/" + player_id + "/credits"
	request(credits_url, headers, HTTPClient.METHOD_POST, credits_json)
	response = await request_completed

	_log_message("APIClient: Sold %d items for %d credits via backend" % [items_sold, total_value])

	# Emit signals for UI updates
	inventory_updated.emit([])  # Empty inventory
