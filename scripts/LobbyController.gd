# LobbyController.gd
# WebSocket Client Manager for 2D Trading Lobby
# Autoload singleton that handles real-time multiplayer connections

class_name LobbyController
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
	"""Load lobby configuration from JSON file"""
	print("[LobbyController] Loading lobby configuration")

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
			_apply_configuration()
			print("[LobbyController] Configuration loaded from: %s" % config_path)
		else:
			print("[LobbyController] ERROR: Failed to parse lobby config JSON")
			_use_default_configuration()
	else:
		print("[LobbyController] WARNING: No lobby config found, using defaults")
		_use_default_configuration()

func _apply_configuration() -> void:
	"""Apply loaded configuration settings"""
	websocket_url = lobby_config.get("websocket_url", "")
	connection_timeout = lobby_config.get("connection_timeout", 10.0)
	position_broadcast_interval = lobby_config.get("position_broadcast_interval", 0.2)
	enable_debug_logs = lobby_config.get("enable_debug_logs", true)
	max_retry_attempts = lobby_config.get("max_retry_attempts", 3)
	reconnect_delay = lobby_config.get("reconnect_delay", 2.0)

	# Development mode check
	var dev_config = lobby_config.get("development", {})
	if dev_config.get("use_local_server", false):
		websocket_url = dev_config.get("local_websocket_url", "ws://localhost:8080")
		print("[LobbyController] Using development WebSocket server: %s" % websocket_url)

	print("[LobbyController] WebSocket URL: %s" % websocket_url)
	print("[LobbyController] Position broadcast interval: %.1fs" % position_broadcast_interval)

func _use_default_configuration() -> void:
	"""Use default configuration when no config file is found"""
	websocket_url = "wss://37783owd23.execute-api.us-east-2.amazonaws.com/prod"
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
		remote_players[player_id] = {
			"id": player_id,
			"x": x,
			"y": y,
			"position": new_position
		}

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
