# TradingHubManager3D.gd
# Manages 3D trading hub construction in Children of the Singularity
# Handles only mechanical trading devices (NOT space stations)

class_name TradingHubManager3D
extends Node3D

## Signal emitted when a new trading hub is created
signal hub_created(hub: Node3D)

## Signal emitted when player enters any hub
signal player_entered_hub(hub_type: String, hub: Node3D)

## Signal emitted when player exits any hub
signal player_exited_hub(hub_type: String, hub: Node3D)

## Export properties for configuration
@export var hub_container: Node3D
@export var zone_bounds: Vector3 = Vector3(100, 50, 100)
@export var hub_count: int = 1  # Number of trading hubs per zone
@export var modules_per_hub: int = 1  # Number of modules per hub
@export var hub_spacing: float = 20.0
@export var hub_separation: float = 30.0

## Hub layouts and configurations
var hub_templates: Array[Dictionary] = [
	{
		"name": "Trading Hub Alpha",
		"type": "trading",
		"modules": [
			{"type": "trading", "position": Vector3(0, 0, 0)}
		]
	}
]

## Internal state
var active_hubs: Array[Dictionary] = []
var all_hubs: Array[Node3D] = []
var hub_positions: Array[Vector3] = []

func _ready() -> void:
	_log_message("TradingHubManager3D: Initializing trading hub management system")
	_setup_hub_container()
	_calculate_hub_positions()
	await _generate_trading_hubs()
	_log_message("TradingHubManager3D: Generated %d trading hubs" % active_hubs.size())

func _setup_hub_container() -> void:
	"""Set up the container for trading hubs"""
	if not hub_container:
		hub_container = Node3D.new()
		hub_container.name = "TradingHubsContainer"
		add_child(hub_container)
		_log_message("TradingHubManager3D: Created hub container")

func _calculate_hub_positions() -> void:
	"""Calculate positions for trading hubs near player spawn, avoiding space stations"""
	_log_message("TradingHubManager3D: Calculating trading hub positions away from space stations")
	hub_positions.clear()

	# Player spawn position is at (0, 2, 0) - place hubs nearby but away from space stations
	var player_spawn_position = Vector3(0, 2, 0)
	var min_distance_from_player = 15.0   # Increased minimum distance from player for larger sprites
	var max_distance_from_player = 22.0  # Increased maximum distance from player
	var min_distance_from_stations = 30.0  # Increased minimum distance from space stations

	for i in range(hub_count):
		var position: Vector3
		var attempts = 0
		var max_attempts = 30

		# Try to find a good position away from space stations
		while attempts < max_attempts:
			# Generate position around player spawn
			var angle = (PI * 2 * i / hub_count) + randf_range(-PI/2, PI/2)  # Spread hubs around player
			var distance = randf_range(min_distance_from_player, max_distance_from_player)

			position = Vector3(
				player_spawn_position.x + cos(angle) * distance,
				player_spawn_position.y + 0.5,  # Just above floor level
				player_spawn_position.z + sin(angle) * distance
			)

			# Check distance from space stations (if they exist)
			var valid_position = true
			var space_station_manager = get_node_or_null("../SpaceStationManager3D")
			if space_station_manager and space_station_manager.has_method("get_all_modules"):
				var station_modules = space_station_manager.get_all_modules()
				for station_module in station_modules:
					if position.distance_to(station_module.global_position) < min_distance_from_stations:
						valid_position = false
						break

			if valid_position:
				break

			attempts += 1

		# If no valid position found, place it on opposite side of player
		if attempts >= max_attempts:
			_log_message("TradingHubManager3D: No ideal position found, using fallback")
			position = Vector3(-12, player_spawn_position.y + 0.5, -12)

		hub_positions.append(position)
		_log_message("TradingHubManager3D: Trading hub %d positioned at: %s (distance from player: %.1f)" % [i, position, position.distance_to(player_spawn_position)])

func _generate_trading_hubs() -> void:
	"""Generate all trading hubs using templates"""
	_log_message("TradingHubManager3D: Generating trading hubs")

	for i in range(hub_count):
		var hub_position = hub_positions[i]
		var template = hub_templates[i % hub_templates.size()]

		var hub_data = await _create_trading_hub(template, hub_position, i)
		active_hubs.append(hub_data)

		_log_message("TradingHubManager3D: Created trading hub '%s' at %s" % [template.name, hub_position])

func _create_trading_hub(template: Dictionary, position: Vector3, hub_id: int) -> Dictionary:
	"""Create a single trading hub from a template"""
	# Load the TradingHub3D scene
	var trading_hub_scene = preload("res://scenes/objects/TradingHub3D.tscn")
	if not trading_hub_scene:
		_log_message("TradingHubManager3D: ERROR - Could not load TradingHub3D scene")
		return {}

	# Instantiate the trading hub
	var trading_hub = trading_hub_scene.instantiate()
	if not trading_hub:
		_log_message("TradingHubManager3D: ERROR - Could not instantiate TradingHub3D")
		return {}

	# Configure the hub
	trading_hub.name = "TradingHub_%d_%s" % [hub_id, template.name.replace(" ", "_")]
	trading_hub.global_position = position
	trading_hub.hub_type = template.get("type", "trading")

	# Add to container
	hub_container.add_child(trading_hub)

	# Connect signals if they exist
	if trading_hub.has_signal("hub_entered"):
		trading_hub.hub_entered.connect(_on_hub_entered)
	if trading_hub.has_signal("hub_exited"):
		trading_hub.hub_exited.connect(_on_hub_exited)

	all_hubs.append(trading_hub)

	var hub_data = {
		"id": hub_id,
		"name": template.name,
		"type": template.get("type", "trading"),
		"position": position,
		"node": trading_hub,
		"template": template
	}

	hub_created.emit(trading_hub)
	return hub_data

func _on_hub_entered(hub_type: String, hub: Node3D) -> void:
	"""Handle player entering any trading hub"""
	_log_message("TradingHubManager3D: Player entered %s hub" % hub_type)
	player_entered_hub.emit(hub_type, hub)

func _on_hub_exited(hub_type: String, hub: Node3D) -> void:
	"""Handle player exiting any trading hub"""
	_log_message("TradingHubManager3D: Player exited %s hub" % hub_type)
	player_exited_hub.emit(hub_type, hub)

func get_all_hubs() -> Array[Node3D]:
	"""Get all trading hubs"""
	return all_hubs

func get_hub_count() -> int:
	"""Get the number of active trading hubs"""
	return active_hubs.size()

func get_hub_data() -> Array[Dictionary]:
	"""Get data for all trading hubs"""
	var hub_data: Array[Dictionary] = []

	for hub in active_hubs:
		hub_data.append({
			"id": hub.id,
			"name": hub.name,
			"type": hub.type,
			"position": hub.position
		})

	return hub_data

func _log_message(message: String) -> void:
	"""Log a message with timestamp"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
