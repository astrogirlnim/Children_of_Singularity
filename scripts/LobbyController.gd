# LobbyController.gd
# WebSocket Client Manager for 2D Trading Lobby
# Autoload singleton that handles real-time multiplayer connections

extends Node

## Signal emitted when successfully connected to lobby WebSocket
signal connected_to_lobby()

## Signal emitted when disconnected from lobby WebSocket
signal disconnected_from_lobby()

## Signal emitted when connection fails
signal connection_failed(reason: String)

## Signal emitted when a remote player joins the lobby
signal remote_player_joined(player_data: Dictionary)

## Signal emitted when a remote player leaves the lobby
signal remote_player_left(player_id: String)

## Signal emitted when a remote player's position updates
signal remote_player_position_updated(player_id: String, position: Vector2)

## Signal emitted when we receive our welcome message with lobby state
signal lobby_state_received(lobby_players: Array)

## Signal emitted when connection status changes
signal connection_status_changed(status: String)

# WebSocket connection
var websocket_client: WebSocketPeer
var is_connected: bool = false
var is_connecting: bool = false
var connection_timeout: float = 10.0
var reconnect_delay: float = 2.0
var max_retry_attempts: int = 3
var current_retry_attempt: int = 0

# Configuration
var lobby_config: Dictionary = {}
var websocket_url: String = ""
var position_broadcast_interval: float = 0.2
var enable_debug_logs: bool = true

# Player data
var local_player_id: String = ""
var remote_players: Dictionary = {}  # player_id -> player_data
var last_position_sent: Vector2 = Vector2.ZERO
var position_broadcast_timer: float = 0.0

# Connection state
var connection_timer: float = 0.0
var auto_reconnect: bool = true

func _ready() -> void:
	print("[LobbyController] Initializing WebSocket lobby client")
	_load_lobby_configuration()
	_initialize_websocket()
	_setup_local_player_id()
	print("[LobbyController] WebSocket lobby client ready")

func _process(delta: float) -> void:
	# Handle WebSocket polling
	if websocket_client:
		websocket_client.poll()
		_handle_websocket_state()
		_handle_websocket_messages()

	# Handle connection timeout
	if is_connecting:
		connection_timer += delta
		if connection_timer >= connection_timeout:
			_handle_connection_timeout()

	# Handle position broadcasting timer
	if is_connected:
		position_broadcast_timer += delta

func _load_lobby_configuration() -> void:
	"""Load lobby configuration with environment variable precedence"""
	print("[LobbyController] Loading lobby configuration with environment precedence")

	# Step 1: Try to load from environment variables (highest priority)
	_load_from_environment_variables()

	# Step 2: Try to load from .env file if environment vars not found
	if websocket_url.is_empty():
		_load_from_env_file()

	# Step 3: Try to load from JSON config files if still not found
	if websocket_url.is_empty():
		_load_from_config_files()

	# Step 4: Use hardcoded defaults as last resort
	if websocket_url.is_empty():
		print("[LobbyController] All configuration sources failed, using hardcoded defaults")
		_use_default_configuration()
	else:
		# Apply any loaded configuration
		_apply_loaded_configuration()
		print("[LobbyController] Configuration loaded successfully")
		print("[LobbyController] WebSocket URL: %s" % websocket_url)

func _load_from_environment_variables() -> void:
	"""Load configuration from OS environment variables (12-factor app approach)"""
	print("[LobbyController] Checking OS environment variables...")

	# Try to get WebSocket URL from environment
	var env_websocket_url = OS.get_environment("WEBSOCKET_URL")
	if not env_websocket_url.is_empty():
		websocket_url = env_websocket_url
		print("[LobbyController] ✅ Found WEBSOCKET_URL in environment: %s" % websocket_url)

		# Load other optional environment configs
		var env_timeout = OS.get_environment("LOBBY_CONNECTION_TIMEOUT")
		if not env_timeout.is_empty():
			connection_timeout = float(env_timeout)

		var env_broadcast_interval = OS.get_environment("LOBBY_BROADCAST_INTERVAL")
		if not env_broadcast_interval.is_empty():
			position_broadcast_interval = float(env_broadcast_interval)

		var env_debug = OS.get_environment("LOBBY_DEBUG_LOGS")
		if not env_debug.is_empty():
			enable_debug_logs = env_debug.to_lower() in ["true", "1", "yes"]

		var env_max_retries = OS.get_environment("LOBBY_MAX_RETRIES")
		if not env_max_retries.is_empty():
			max_retry_attempts = int(env_max_retries)

		print("[LobbyController] Environment configuration loaded")
		return

	print("[LobbyController] No environment variables found")

func _load_from_env_file() -> void:
	"""Load configuration from .env file"""
	print("[LobbyController] Checking for .env file...")

	# Try different .env file locations
	var env_paths = [
		"user://lobby.env",  # User-specific lobby config
		"user://.env",       # User-specific general config
		"res://lobby.env",   # Project root lobby.env
		"res://infrastructure_setup.env",  # Project infrastructure config
		"res://.env"         # Project root .env
	]

	for env_path in env_paths:
		if FileAccess.file_exists(env_path):
			print("[LobbyController] Found .env file at: %s" % env_path)
			if _parse_env_file(env_path):
				print("[LobbyController] ✅ Successfully loaded configuration from .env file")
				return
			else:
				print("[LobbyController] ⚠️ Failed to parse .env file, trying next location")

	print("[LobbyController] No valid .env file found")

func _parse_env_file(env_path: String) -> bool:
	"""Parse environment file and extract configuration"""
	var file = FileAccess.open(env_path, FileAccess.READ)
	if not file:
		return false

	var line_number = 0
	while not file.eof_reached():
		line_number += 1
		var line = file.get_line().strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		# Parse KEY=VALUE format
		if "=" in line:
			var parts = line.split("=", false, 1)
			if parts.size() == 2:
				var key = parts[0].strip_edges()
				var value = parts[1].strip_edges()

				# Remove quotes if present
				if (value.begins_with('"') and value.ends_with('"')) or (value.begins_with("'") and value.ends_with("'")):
					value = value.substr(1, value.length() - 2)

				# Map environment variables to configuration
				match key:
					"WEBSOCKET_URL":
						websocket_url = value
						print("[LobbyController] Found WEBSOCKET_URL in .env: %s" % value)
					"LOBBY_CONNECTION_TIMEOUT":
						connection_timeout = float(value)
					"LOBBY_BROADCAST_INTERVAL":
						position_broadcast_interval = float(value)
					"LOBBY_DEBUG_LOGS":
						enable_debug_logs = value.to_lower() in ["true", "1", "yes"]
					"LOBBY_MAX_RETRIES":
						max_retry_attempts = int(value)

	file.close()

	# Return true if we found at least the WebSocket URL
	return not websocket_url.is_empty()

func _load_from_config_files() -> void:
	"""Load configuration from JSON files (existing approach)"""
	print("[LobbyController] Checking JSON configuration files...")

	# Try to load from user://lobby_config.json first (runtime config)
	var config_path = "user://lobby_config.json"
	var file = FileAccess.open(config_path, FileAccess.READ)

	if not file:
		# Fallback to project config
		config_path = "res://infrastructure/lobby_config.json"
		file = FileAccess.open(config_path, FileAccess.READ)

	if file:
		var json_string = file.get_as_text()
		file.close()

		var json_parser = JSON.new()
		var parse_result = json_parser.parse(json_string)

		if parse_result == OK:
			lobby_config = json_parser.data
			websocket_url = lobby_config.get("websocket_url", "")
			if not websocket_url.is_empty():
				print("[LobbyController] ✅ Found WebSocket URL in JSON config: %s" % websocket_url)
				print("[LobbyController] Configuration loaded from: %s" % config_path)
			else:
				print("[LobbyController] ⚠️ JSON config found but no websocket_url specified")
		else:
			print("[LobbyController] ERROR: Failed to parse lobby config JSON")
	else:
		print("[LobbyController] No JSON configuration files found")

func _apply_loaded_configuration() -> void:
	"""Apply configuration that was loaded from environment or files"""
	# Apply values from lobby_config if they weren't set by environment variables
	if lobby_config.has("connection_timeout") and connection_timeout == 10.0:
		connection_timeout = lobby_config.get("connection_timeout", 10.0)

	if lobby_config.has("position_broadcast_interval") and position_broadcast_interval == 0.2:
		position_broadcast_interval = lobby_config.get("position_broadcast_interval", 0.2)

	if lobby_config.has("enable_debug_logs") and enable_debug_logs == true:
		enable_debug_logs = lobby_config.get("enable_debug_logs", true)

	if lobby_config.has("max_retry_attempts") and max_retry_attempts == 3:
		max_retry_attempts = lobby_config.get("max_retry_attempts", 3)

	if lobby_config.has("reconnect_delay") and reconnect_delay == 2.0:
		reconnect_delay = lobby_config.get("reconnect_delay", 2.0)

	# Development mode check
	var dev_config = lobby_config.get("development", {})
	if dev_config.get("use_local_server", false):
		websocket_url = dev_config.get("local_websocket_url", "ws://localhost:8080")
		print("[LobbyController] Development mode: Using local WebSocket server: %s" % websocket_url)

	print("[LobbyController] Final configuration:")
	print("[LobbyController]   WebSocket URL: %s" % websocket_url)
	print("[LobbyController]   Connection timeout: %.1fs" % connection_timeout)
	print("[LobbyController]   Broadcast interval: %.1fs" % position_broadcast_interval)
	print("[LobbyController]   Debug logs: %s" % enable_debug_logs)
	print("[LobbyController]   Max retries: %d" % max_retry_attempts)

func _use_default_configuration() -> void:
	"""Use default configuration when no config file is found"""
	websocket_url = "wss://bktpsfy4rb.execute-api.us-east-2.amazonaws.com/prod"
	connection_timeout = 10.0
	position_broadcast_interval = 0.2
	enable_debug_logs = true
	max_retry_attempts = 3
	reconnect_delay = 2.0
	print("[LobbyController] Using default configuration")

func _initialize_websocket() -> void:
	"""Initialize WebSocket client"""
	websocket_client = WebSocketPeer.new()
	print("[LobbyController] WebSocket client initialized")

func _setup_local_player_id() -> void:
	"""Setup local player ID from LocalPlayerData"""
	if LocalPlayerData:
		local_player_id = LocalPlayerData.get_player_id()
		print("[LobbyController] Local player ID: %s" % local_player_id)
	else:
		# Generate fallback ID
		local_player_id = "player_%d" % Time.get_unix_time_from_system()
		print("[LobbyController] Generated fallback player ID: %s" % local_player_id)

## Public API Methods

func connect_to_lobby() -> void:
	"""Connect to the lobby WebSocket server"""
	if is_connected or is_connecting:
		print("[LobbyController] Already connected or connecting to lobby")
		return

	if websocket_url.is_empty():
		print("[LobbyController] ERROR: No WebSocket URL configured")
		connection_failed.emit("No WebSocket URL configured")
		return

	print("[LobbyController] Connecting to lobby: %s" % websocket_url)
	is_connecting = true
	connection_timer = 0.0
	current_retry_attempt += 1

	# Build connection URL with player ID
	var connection_url = "%s?pid=%s" % [websocket_url, local_player_id]

	var error = websocket_client.connect_to_url(connection_url)
	if error != OK:
		print("[LobbyController] ERROR: Failed to initiate WebSocket connection: %s" % error)
		is_connecting = false
		connection_failed.emit("Failed to initiate connection")
	else:
		connection_status_changed.emit("connecting")

func disconnect_from_lobby() -> void:
	"""Disconnect from the lobby WebSocket server"""
	print("[LobbyController] Disconnecting from lobby")

	if websocket_client:
		websocket_client.close()

	_reset_connection_state()
	disconnected_from_lobby.emit()
	connection_status_changed.emit("disconnected")

func send_position_update(position: Vector2) -> void:
	"""Send player position update to the lobby"""
	if not is_connected:
		return

	# Rate limiting - only send if enough time has passed
	if position_broadcast_timer < position_broadcast_interval:
		return

	# Only send if position changed significantly
	var distance_moved = last_position_sent.distance_to(position)
	if distance_moved < 5.0:  # Minimum movement threshold
		return

	var message = {
		"action": "pos",
		"x": position.x,
		"y": position.y
	}

	_send_message(message)
	last_position_sent = position
	position_broadcast_timer = 0.0

	if enable_debug_logs:
		print("[LobbyController] Sent position update: (%.1f, %.1f)" % [position.x, position.y])

func get_remote_players() -> Dictionary:
	"""Get dictionary of all remote players"""
	return remote_players.duplicate()

func is_lobby_connected() -> bool:
	"""Check if connected to lobby"""
	return is_connected

func get_connection_status() -> String:
	"""Get current connection status"""
	if is_connected:
		return "connected"
	elif is_connecting:
		return "connecting"
	else:
		return "disconnected"

## Private Methods

func _handle_websocket_state() -> void:
	"""Handle WebSocket connection state changes"""
	var state = websocket_client.get_ready_state()

	match state:
		WebSocketPeer.STATE_CONNECTING:
			# Still connecting, handled by timer
			pass

		WebSocketPeer.STATE_OPEN:
			if is_connecting:
				_on_connection_established()

		WebSocketPeer.STATE_CLOSING:
			print("[LobbyController] WebSocket connection closing")

		WebSocketPeer.STATE_CLOSED:
			if is_connected or is_connecting:
				_on_connection_lost()

func _handle_websocket_messages() -> void:
	"""Handle incoming WebSocket messages"""
	while websocket_client.get_available_packet_count() > 0:
		var packet = websocket_client.get_packet()
		var message_text = packet.get_string_from_utf8()

		if enable_debug_logs:
			print("[LobbyController] Received message: %s" % message_text)

		_process_message(message_text)

func _process_message(message_text: String) -> void:
	"""Process incoming WebSocket message"""
	var json_parser = JSON.new()
	var parse_result = json_parser.parse(message_text)

	if parse_result != OK:
		print("[LobbyController] ERROR: Failed to parse message JSON: %s" % message_text)
		return

	var message = json_parser.data
	var message_type = message.get("type", "unknown")

	match message_type:
		"welcome":
			_handle_welcome_message(message)
		"join":
			_handle_player_join_message(message)
		"leave":
			_handle_player_leave_message(message)
		"pos":
			_handle_position_update_message(message)
		"error":
			_handle_error_message(message)
		_:
			print("[LobbyController] WARNING: Unknown message type: %s" % message_type)

func _handle_welcome_message(message: Dictionary) -> void:
	"""Handle welcome message with current lobby state"""
	print("[LobbyController] Received welcome message")

	var your_id = message.get("your_id", local_player_id)
	var lobby_players = message.get("lobby_players", [])

	# Update local player ID if server assigned one
	if your_id != local_player_id:
		local_player_id = your_id
		print("[LobbyController] Server assigned player ID: %s" % local_player_id)

	# Process existing lobby players
	remote_players.clear()
	for player_data in lobby_players:
		var player_id = player_data.get("id", "")
		if player_id != local_player_id and not player_id.is_empty():
			remote_players[player_id] = player_data
			print("[LobbyController] Found existing player: %s at (%.1f, %.1f)" % [
				player_id, player_data.get("x", 0), player_data.get("y", 0)
			])

	lobby_state_received.emit(lobby_players)

func _handle_player_join_message(message: Dictionary) -> void:
	"""Handle remote player joining lobby"""
	var player_id = message.get("id", "")
	var x = message.get("x", 0.0)
	var y = message.get("y", 0.0)

	if player_id.is_empty() or player_id == local_player_id:
		return

	var player_data = {
		"id": player_id,
		"x": x,
		"y": y,
		"position": Vector2(x, y)
	}

	remote_players[player_id] = player_data
	print("[LobbyController] Player joined: %s at (%.1f, %.1f)" % [player_id, x, y])

	remote_player_joined.emit(player_data)

func _handle_player_leave_message(message: Dictionary) -> void:
	"""Handle remote player leaving lobby"""
	var player_id = message.get("id", "")

	if player_id.is_empty() or player_id == local_player_id:
		return

	if player_id in remote_players:
		remote_players.erase(player_id)
		print("[LobbyController] Player left: %s" % player_id)

		remote_player_left.emit(player_id)

func _handle_position_update_message(message: Dictionary) -> void:
	"""Handle remote player position update"""
	var player_id = message.get("id", "")
	var x = message.get("x", 0.0)
	var y = message.get("y", 0.0)

	if player_id.is_empty() or player_id == local_player_id:
		return

	var new_position = Vector2(x, y)

	# Update player data
	if player_id in remote_players:
		remote_players[player_id]["x"] = x
		remote_players[player_id]["y"] = y
		remote_players[player_id]["position"] = new_position
	else:
		# Player not in our list yet, add them
		var player_data = {
			"id": player_id,
			"x": x,
			"y": y,
			"position": new_position
		}
		remote_players[player_id] = player_data

		# Emit join signal for visual spawning (missed join message case)
		print("[LobbyController] Auto-spawning player from position update: %s" % player_id)
		remote_player_joined.emit(player_data)

	if enable_debug_logs:
		print("[LobbyController] Player %s moved to (%.1f, %.1f)" % [player_id, x, y])

	remote_player_position_updated.emit(player_id, new_position)

func _handle_error_message(message: Dictionary) -> void:
	"""Handle error message from server"""
	var error_text = message.get("message", "Unknown error")
	print("[LobbyController] Server error: %s" % error_text)

func _send_message(message: Dictionary) -> void:
	"""Send message to WebSocket server"""
	if not is_connected:
		print("[LobbyController] WARNING: Attempted to send message while disconnected")
		return

	var json_string = JSON.stringify(message)
	var error = websocket_client.send_text(json_string)

	if error != OK:
		print("[LobbyController] ERROR: Failed to send message: %s" % error)

func _on_connection_established() -> void:
	"""Handle successful WebSocket connection"""
	print("[LobbyController] ✅ Connected to lobby WebSocket")
	is_connecting = false
	is_connected = true
	connection_timer = 0.0
	current_retry_attempt = 0

	connected_to_lobby.emit()
	connection_status_changed.emit("connected")

func _on_connection_lost() -> void:
	"""Handle WebSocket connection loss"""
	print("[LobbyController] ❌ Connection to lobby lost")

	var was_connected = is_connected
	_reset_connection_state()

	if was_connected:
		disconnected_from_lobby.emit()
	else:
		connection_failed.emit("Connection lost during handshake")

	connection_status_changed.emit("disconnected")

	# Auto-reconnect if enabled and we haven't exceeded retry limit
	if auto_reconnect and current_retry_attempt < max_retry_attempts:
		print("[LobbyController] Attempting auto-reconnect in %.1fs (attempt %d/%d)" % [
			reconnect_delay, current_retry_attempt + 1, max_retry_attempts
		])
		get_tree().create_timer(reconnect_delay).timeout.connect(connect_to_lobby)

func _handle_connection_timeout() -> void:
	"""Handle connection timeout"""
	print("[LobbyController] ⏰ Connection timeout")
	websocket_client.close()
	is_connecting = false
	connection_failed.emit("Connection timeout")
	connection_status_changed.emit("failed")

func _reset_connection_state() -> void:
	"""Reset connection state variables"""
	is_connected = false
	is_connecting = false
	connection_timer = 0.0
	position_broadcast_timer = 0.0
	last_position_sent = Vector2.ZERO
	remote_players.clear()

## Utility Methods

func get_lobby_player_count() -> int:
	"""Get total number of players in lobby (including local player)"""
	return remote_players.size() + (1 if is_connected else 0)

func force_reconnect() -> void:
	"""Force disconnect and reconnect"""
	print("[LobbyController] Forcing reconnect")
	disconnect_from_lobby()
	await get_tree().create_timer(1.0).timeout
	connect_to_lobby()

func set_auto_reconnect(enabled: bool) -> void:
	"""Enable or disable auto-reconnect"""
	auto_reconnect = enabled
	print("[LobbyController] Auto-reconnect %s" % ("enabled" if enabled else "disabled"))

func reset_retry_count() -> void:
	"""Reset retry attempt counter"""
	current_retry_attempt = 0

## Debug Methods

func get_connection_info() -> Dictionary:
	"""Get detailed connection information for debugging"""
	return {
		"is_connected": is_connected,
		"is_connecting": is_connecting,
		"websocket_url": websocket_url,
		"local_player_id": local_player_id,
		"remote_player_count": remote_players.size(),
		"remote_players": remote_players.keys(),
		"retry_attempt": current_retry_attempt,
		"max_retries": max_retry_attempts,
		"auto_reconnect": auto_reconnect
	}

func _exit_tree() -> void:
	"""Cleanup on exit"""
	if is_connected:
		disconnect_from_lobby()
