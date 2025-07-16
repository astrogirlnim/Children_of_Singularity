# NetworkManager.gd
# ENet networking manager for Children of the Singularity
# Handles server-authoritative multiplayer networking

class_name NetworkManager
extends Node

## Signal emitted when successfully connected to server
signal connected_to_server()

## Signal emitted when disconnected from server
signal disconnected_from_server()

## Signal emitted when a player joins the zone
signal player_joined(player_id: int, player_data: Dictionary)

## Signal emitted when a player leaves the zone
signal player_left(player_id: int)

## Signal emitted when server state is updated
signal server_state_updated(state_data: Dictionary)

## Signal emitted when player position is updated
signal player_position_updated(player_id: int, position: Vector2)

## Signal emitted when debris is collected by any player
signal debris_collected_by_player(player_id: int, debris_id: String, debris_type: String)

var multiplayer_peer: ENetMultiplayerPeer
var is_server: bool = false
var is_client: bool = false
var is_network_connected: bool = false
var server_port: int = 12345
var max_players: int = 32
var current_players: Dictionary = {}
var player_positions: Dictionary = {}
var zone_debris: Dictionary = {}

func _ready() -> void:
	_log_message("NetworkManager: Initializing ENet networking system")
	multiplayer_peer = ENetMultiplayerPeer.new()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_log_message("NetworkManager: ENet networking system ready")

func start_server() -> bool:
	##Start the game server
	_log_message("NetworkManager: Starting ENet server on port %d" % server_port)

	var error = multiplayer_peer.create_server(server_port, max_players)
	if error != OK:
		_log_message("NetworkManager: Failed to start server - Error: %s" % error)
		return false

	multiplayer.multiplayer_peer = multiplayer_peer
	is_server = true
	is_network_connected = true
	_log_message("NetworkManager: ENet server started successfully")
	return true

func connect_to_server(server_address: String, port: int = 12345) -> bool:
	##Connect to a game server
	_log_message("NetworkManager: Connecting to ENet server at %s:%d" % [server_address, port])

	var error = multiplayer_peer.create_client(server_address, port)
	if error != OK:
		_log_message("NetworkManager: Failed to connect to server - Error: %s" % error)
		return false

	multiplayer.multiplayer_peer = multiplayer_peer
	is_client = true
	_log_message("NetworkManager: Connection attempt initiated")
	return true

func disconnect_from_server() -> void:
	##Disconnect from the current server
	_log_message("NetworkManager: Disconnecting from server")

	if multiplayer_peer:
		multiplayer_peer.close()

	multiplayer.multiplayer_peer = null
	is_network_connected = false
	is_client = false
	is_server = false
	current_players.clear()
	player_positions.clear()
	zone_debris.clear()
	_log_message("NetworkManager: Disconnected from server")
	disconnected_from_server.emit()

func send_player_update(player_data: Dictionary) -> void:
	##Send player state update to server
	if not is_network_connected:
		_log_message("NetworkManager: Cannot send update - not connected")
		return

	var player_id = multiplayer.get_unique_id()
	var position = player_data.get("position", Vector3.ZERO)
	var inventory = player_data.get("inventory", [])

	_log_message("NetworkManager: Sending player update - ID: %d, Position: %s, Inventory: %d items" % [player_id, position, inventory.size()])

	if is_server:
		# Server processes update locally
		_update_player_state(player_id, player_data)
	else:
		# Client sends update to server
		rpc_id(1, "_receive_player_update", player_id, player_data)

func sync_zone_state(zone_data: Dictionary) -> void:
	##Sync zone state with server (server-only)
	if not is_server:
		_log_message("NetworkManager: Cannot sync zone - not server")
		return

	var zone_id = zone_data.get("zone_id", "unknown")
	var debris_count = zone_data.get("debris_count", 0)

	_log_message("NetworkManager: Syncing zone state - Zone: %s, Debris: %d" % [zone_id, debris_count])

	# Update zone debris data
	zone_debris = zone_data.get("debris", {})

	# Broadcast zone state to all clients
	rpc("_receive_zone_state", zone_data)

func request_zone_join(zone_id: String) -> bool:
	##Request to join a specific zone
	_log_message("NetworkManager: Requesting to join zone: %s" % zone_id)

	if is_server:
		# Server approves join immediately
		_log_message("NetworkManager: Zone join approved (server)")
		return true
	else:
		# Client requests join from server
		rpc_id(1, "_request_zone_join", multiplayer.get_unique_id(), zone_id)
		return true

func collect_debris(debris_id: String, debris_type: String) -> void:
	##Handle debris collection (server-authoritative)
	var player_id = multiplayer.get_unique_id()
	_log_message("NetworkManager: Player %d attempting to collect debris %s (%s)" % [player_id, debris_id, debris_type])

	if is_server:
		# Server processes collection
		_process_debris_collection(player_id, debris_id, debris_type)
	else:
		# Client requests collection from server
		rpc_id(1, "_request_debris_collection", player_id, debris_id, debris_type)

func get_network_info() -> Dictionary:
	##Get current network status information
	return {
		"is_server": is_server,
		"is_client": is_client,
		"is_connected": is_network_connected,
		"server_port": server_port,
		"max_players": max_players,
		"current_players": current_players.size(),
		"player_positions": player_positions.size(),
		"zone_debris": zone_debris.size()
	}

# Network event handlers
func _on_peer_connected(id: int) -> void:
	_log_message("NetworkManager: Peer %d connected" % id)

	if is_server:
		var player_data = {
			"player_id": id,
			"position": Vector3(randf_range(-500, 500), 2.0, randf_range(-500, 500)),
			"inventory": [],
			"credits": 0,
			"connected_time": Time.get_ticks_msec()
		}

		current_players[id] = player_data
		player_positions[id] = player_data.position

		# Notify all clients of new player
		rpc("_on_player_joined", id, player_data)

		# Send current game state to new player
		rpc_id(id, "_receive_initial_state", current_players, zone_debris)

	player_joined.emit(id, current_players.get(id, {}))

func _on_peer_disconnected(id: int) -> void:
	_log_message("NetworkManager: Peer %d disconnected" % id)

	if is_server:
		current_players.erase(id)
		player_positions.erase(id)

		# Notify all clients of player leaving
		rpc("_on_player_left", id)

	player_left.emit(id)

func _on_connected_to_server() -> void:
	_log_message("NetworkManager: Successfully connected to server")
	is_network_connected = true
	connected_to_server.emit()

func _on_connection_failed() -> void:
	_log_message("NetworkManager: Connection to server failed")
	is_network_connected = false
	is_client = false

func _on_server_disconnected() -> void:
	_log_message("NetworkManager: Server disconnected")
	is_network_connected = false
	is_client = false
	current_players.clear()
	player_positions.clear()
	zone_debris.clear()
	disconnected_from_server.emit()

# RPC functions
@rpc("any_peer", "call_local", "reliable")
func _receive_player_update(player_id: int, player_data: Dictionary) -> void:
	##Receive player update from client (server-only)
	if not is_server:
		return

	_update_player_state(player_id, player_data)

@rpc("authority", "call_local", "reliable")
func _receive_zone_state(zone_data: Dictionary) -> void:
	##Receive zone state from server (clients-only)
	if is_server:
		return

	_log_message("NetworkManager: Received zone state update")
	zone_debris = zone_data.get("debris", {})
	server_state_updated.emit(zone_data)

@rpc("any_peer", "call_local", "reliable")
func _request_zone_join(player_id: int, zone_id: String) -> void:
	##Handle zone join request (server-only)
	if not is_server:
		return

	_log_message("NetworkManager: Player %d requesting to join zone %s" % [player_id, zone_id])
	# For MVP, approve all zone join requests
	rpc_id(player_id, "_zone_join_approved", zone_id)

@rpc("authority", "call_local", "reliable")
func _zone_join_approved(zone_id: String) -> void:
	##Receive zone join approval from server
	_log_message("NetworkManager: Zone join approved for zone %s" % zone_id)

@rpc("any_peer", "call_local", "reliable")
func _request_debris_collection(player_id: int, debris_id: String, debris_type: String) -> void:
	##Handle debris collection request (server-only)
	if not is_server:
		return

	_process_debris_collection(player_id, debris_id, debris_type)

@rpc("authority", "call_local", "reliable")
func _on_player_joined(player_id: int, player_data: Dictionary) -> void:
	##Notification of new player joining
	if player_id not in current_players:
		current_players[player_id] = player_data
		player_positions[player_id] = player_data.get("position", Vector3.ZERO)
		_log_message("NetworkManager: Player %d joined the game" % player_id)

@rpc("authority", "call_local", "reliable")
func _on_player_left(player_id: int) -> void:
	##Notification of player leaving
	current_players.erase(player_id)
	player_positions.erase(player_id)
	_log_message("NetworkManager: Player %d left the game" % player_id)

@rpc("authority", "call_local", "reliable")
func _receive_initial_state(players: Dictionary, debris: Dictionary) -> void:
	##Receive initial game state from server (new clients only)
	current_players = players
	zone_debris = debris

	for player_id in players:
		player_positions[player_id] = players[player_id].get("position", Vector3.ZERO)

	_log_message("NetworkManager: Received initial state - %d players, %d debris" % [players.size(), debris.size()])

@rpc("authority", "call_local", "reliable")
func _debris_collected_notification(player_id: int, debris_id: String, debris_type: String) -> void:
	##Notification of debris collection
	_log_message("NetworkManager: Player %d collected debris %s (%s)" % [player_id, debris_id, debris_type])
	debris_collected_by_player.emit(player_id, debris_id, debris_type)

# Helper functions
func _update_player_state(player_id: int, player_data: Dictionary) -> void:
	##Update player state on server
	if player_id in current_players:
		current_players[player_id].merge(player_data)

		var position = player_data.get("position", Vector3.ZERO)
		if position != Vector3.ZERO:
			player_positions[player_id] = position
			# Broadcast position update to all clients
			rpc("_player_position_update", player_id, position)

@rpc("authority", "call_local", "unreliable")
func _player_position_update(player_id: int, position: Vector3) -> void:
	##Receive player position update
	if player_id in player_positions:
		player_positions[player_id] = position
		player_position_updated.emit(player_id, position)

func _process_debris_collection(player_id: int, debris_id: String, debris_type: String) -> void:
	##Process debris collection on server
	if debris_id in zone_debris:
		# Remove debris from zone
		zone_debris.erase(debris_id)

		# Add to player inventory (if space available)
		if player_id in current_players:
			var inventory = current_players[player_id].get("inventory", [])
			inventory.append({"type": debris_type, "value": 1})
			current_players[player_id]["inventory"] = inventory

		# Notify all clients
		rpc("_debris_collected_notification", player_id, debris_id, debris_type)

		_log_message("NetworkManager: Debris %s collected by player %d" % [debris_id, player_id])
	else:
		_log_message("NetworkManager: Debris %s not found or already collected" % debris_id)

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
