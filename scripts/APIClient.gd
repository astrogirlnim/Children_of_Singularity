# APIClient.gd
# HTTP client for communicating with the Children of the Singularity backend API
# Handles all REST API calls for player data, inventory, and transactions

class_name APIClient
extends HTTPRequest

## Signal emitted when player data is loaded
signal player_data_loaded(player_data: Dictionary)

## Signal emitted when player data save is complete
signal player_data_saved(success: bool)

## Signal emitted when inventory is updated
signal inventory_updated(inventory_data: Array)

## Signal emitted when credits are updated
signal credits_updated(credits: int)

## Signal emitted when API request fails
signal api_error(error_message: String)

# API configuration
var base_url: String = "http://localhost:8000/api/v1"
var player_id: String = "player_001"
var request_timeout: float = 30.0

# Request tracking
var pending_requests: Dictionary = {}
var request_id_counter: int = 0

func _ready() -> void:
	_log_message("APIClient: Initializing HTTP client")
	request_completed.connect(_on_request_completed)
	request_timeout = 30.0
	_log_message("APIClient: HTTP client ready")

## Load player data from the backend
func load_player_data(player_id: String = "") -> void:
	if player_id.is_empty():
		player_id = self.player_id

	var url = "%s/players/%s" % [base_url, player_id]
	_log_message("APIClient: Loading player data from %s" % url)

	var request_id = _make_request(url, HTTPClient.METHOD_GET, [], "load_player_data")
	if request_id == -1:
		api_error.emit("Failed to initiate player data load request")

## Save player data to the backend
func save_player_data(player_data: Dictionary) -> void:
	var url = "%s/players/%s" % [base_url, player_id]
	_log_message("APIClient: Saving player data to %s" % url)

	var json_data = JSON.stringify(player_data)
	var headers = ["Content-Type: application/json"]
	var request_id = _make_request(url, HTTPClient.METHOD_POST, headers, "save_player_data", json_data)
	if request_id == -1:
		api_error.emit("Failed to initiate player data save request")

## Load inventory from the backend
func load_inventory() -> void:
	var url = "%s/players/%s/inventory" % [base_url, player_id]
	_log_message("APIClient: Loading inventory from %s" % url)

	var request_id = _make_request(url, HTTPClient.METHOD_GET, [], "load_inventory")
	if request_id == -1:
		api_error.emit("Failed to initiate inventory load request")

## Add item to inventory via backend
func add_inventory_item(item_data: Dictionary) -> void:
	var url = "%s/players/%s/inventory" % [base_url, player_id]
	_log_message("APIClient: Adding inventory item to %s" % url)

	var json_data = JSON.stringify(item_data)
	var headers = ["Content-Type: application/json"]
	var request_id = _make_request(url, HTTPClient.METHOD_POST, headers, "add_inventory_item", json_data)
	if request_id == -1:
		api_error.emit("Failed to initiate inventory add request")

## Clear inventory (sell all items)
func clear_inventory() -> void:
	var url = "%s/players/%s/inventory" % [base_url, player_id]
	_log_message("APIClient: Clearing inventory at %s" % url)

	var request_id = _make_request(url, HTTPClient.METHOD_DELETE, [], "clear_inventory")
	if request_id == -1:
		api_error.emit("Failed to initiate inventory clear request")

## Update credits
func update_credits(credits_change: int) -> void:
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

func _make_request(url: String, method: HTTPClient.Method, headers: Array, request_type: String, body: String = "") -> int:
	"""Make an HTTP request and track it"""
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

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Handle HTTP request completion"""
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

	# Handle different response codes
	if response_code >= 200 and response_code < 300:
		_handle_successful_response(response_data)
	else:
		_handle_error_response(response_code, response_data)

func _handle_successful_response(response_data: Dictionary) -> void:
	"""Handle successful API responses"""
	_log_message("APIClient: Successful response received")

	# Determine response type based on content (since we don't have request tracking)
	if "status" in response_data and response_data.status == "healthy":
		_log_message("APIClient: Backend health check passed")
	elif response_data is Dictionary and "player_id" in response_data and "credits" in response_data:
		_log_message("APIClient: Player data received")
		player_data_loaded.emit(response_data)
	elif (response_data is Dictionary and "inventory" in response_data) or (response_data is Array):
		_log_message("APIClient: Inventory data received")
		var inventory_data: Array = response_data.get("inventory", []) if response_data is Dictionary else response_data
		inventory_updated.emit(inventory_data)
	elif response_data is Dictionary and "credits" in response_data:
		_log_message("APIClient: Credits updated")
		credits_updated.emit(response_data.credits)
	else:
		_log_message("APIClient: Generic success response")

func _handle_error_response(response_code: int, response_data: Dictionary) -> void:
	"""Handle API error responses"""
	var error_message = "API Error %d" % response_code
	if "detail" in response_data:
		error_message += ": %s" % response_data.detail
	elif "message" in response_data:
		error_message += ": %s" % response_data.message

	_log_message("APIClient: %s" % error_message)
	api_error.emit(error_message)

func _log_message(message: String) -> void:
	"""Log a message with timestamp"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
