# APIClient.gd
# HTTP client for communicating with the Children of the Singularity backend API
# Handles all REST API calls for player data, inventory, and transactions

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

# Request tracking
var pending_requests: Dictionary = {}
var request_id_counter: int = 0

# Retry logic for upgrade purchases
var max_retries: int = 3
var retry_delay: float = 1.0

func _ready() -> void:
	_log_message("APIClient: Initializing HTTP client")
	request_completed.connect(_on_request_completed)
	request_timeout = 30.0

	# Validate the default player ID
	if not _is_valid_uuid(player_id):
		_log_message("APIClient: WARNING - Default player_id is not a valid UUID: %s" % player_id)

	_log_message("APIClient: HTTP client ready")

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

## Load player data from the backend
func load_player_data(target_player_id: String = "") -> void:
	if target_player_id.is_empty():
		target_player_id = self.player_id

	# Validate UUID format before making request
	if not _is_valid_uuid(target_player_id):
		var error_msg = "Invalid UUID format for player ID: %s" % target_player_id
		_log_message("APIClient: %s" % error_msg)
		api_error.emit(error_msg)
		return

	var url = "%s/players/%s" % [base_url, target_player_id]
	_log_message("APIClient: Loading player data from %s" % url)

	var request_id = _make_request(url, HTTPClient.METHOD_GET, [], "load_player_data")
	if request_id == -1:
		api_error.emit("Failed to initiate player data load request")

## Save player data to the backend
func save_player_data(player_data: Dictionary) -> void:
	# Validate UUID format before making request
	if not _is_valid_uuid(player_id):
		var error_msg = "Invalid UUID format for player ID: %s" % player_id
		_log_message("APIClient: %s" % error_msg)
		api_error.emit(error_msg)
		return

	var url = "%s/players/%s" % [base_url, player_id]
	_log_message("APIClient: Saving player data to %s" % url)

	var json_data = JSON.stringify(player_data)
	var headers = ["Content-Type: application/json"]
	var request_id = _make_request(url, HTTPClient.METHOD_POST, headers, "save_player_data", json_data)
	if request_id == -1:
		api_error.emit("Failed to initiate player data save request")

## Load inventory from the backend
func load_inventory(target_player_id: String = "") -> void:
	if target_player_id.is_empty():
		target_player_id = self.player_id

	# Validate UUID format before making request
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

## Add item to inventory via backend
func add_inventory_item(item_data: Dictionary) -> void:
	# Validate UUID format before making request
	if not _is_valid_uuid(player_id):
		var error_msg = "Invalid UUID format for player ID: %s" % player_id
		_log_message("APIClient: %s" % error_msg)
		api_error.emit(error_msg)
		return

	var url = "%s/players/%s/inventory" % [base_url, player_id]
	_log_message("APIClient: Adding inventory item to %s" % url)

	var json_data = JSON.stringify(item_data)
	var headers = ["Content-Type: application/json"]
	var request_id = _make_request(url, HTTPClient.METHOD_POST, headers, "add_inventory_item", json_data)
	if request_id == -1:
		api_error.emit("Failed to initiate inventory add request")

## Clear inventory (sell all items)
func clear_inventory() -> void:
	# Validate UUID format before making request
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

## Clear all upgrades (reset to defaults)
func clear_upgrades() -> void:
	# Validate UUID format before making request
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

## Update credits
func update_credits(credits_change: int) -> void:
	# Validate UUID format before making request
	if not _is_valid_uuid(player_id):
		var error_msg = "Invalid UUID format for player ID: %s" % player_id
		_log_message("APIClient: %s" % error_msg)
		api_error.emit(error_msg)
		return

	var url = "%s/players/%s/credits" % [base_url, player_id]
	_log_message("APIClient: Updating credits at %s" % url)

	var data = {"credits_change": credits_change}
	var json_data = JSON.stringify(data)
	var headers = ["Content-Type: application/json"]
	var request_id = _make_request(url, HTTPClient.METHOD_POST, headers, "update_credits", json_data)
	if request_id == -1:
		api_error.emit("Failed to initiate credits update request")

## Check backend health
func check_health() -> void:
	var url = "%s/health" % base_url
	_log_message("APIClient: Checking backend health at %s" % url)

	var request_id = _make_request(url, HTTPClient.METHOD_GET, [], "check_health")
	if request_id == -1:
		api_error.emit("Failed to initiate health check request")

## Purchase an upgrade for the player
func purchase_upgrade(target_player_id: String, upgrade_type: String, expected_cost: int) -> void:
	_log_message("APIClient: Initiating upgrade purchase - Type: %s, Expected Cost: %d, Player: %s" % [upgrade_type, expected_cost, target_player_id])

	# Validate input parameters
	if target_player_id.is_empty():
		target_player_id = self.player_id

	# Validate UUID format before making request
	if not _is_valid_uuid(target_player_id):
		var error_msg = "Invalid UUID format for player ID: %s" % target_player_id
		_log_message("APIClient: %s" % error_msg)
		upgrade_purchase_failed.emit(error_msg, upgrade_type)
		return

	if upgrade_type.is_empty():
		var error_msg = "Invalid upgrade type: cannot be empty"
		_log_message("APIClient: %s" % error_msg)
		upgrade_purchase_failed.emit(error_msg, upgrade_type)
		return

	if expected_cost < 0:
		var error_msg = "Invalid expected cost: cannot be negative (%d)" % expected_cost
		_log_message("APIClient: %s" % error_msg)
		upgrade_purchase_failed.emit(error_msg, upgrade_type)
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
