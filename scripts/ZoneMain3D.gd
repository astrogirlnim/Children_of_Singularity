# ZoneMain3D.gd
# 3D version of the main zone controller for Children of the Singularity
# Manages the primary gameplay zone where players explore and collect debris in 3D

class_name ZoneMain3D
extends Node3D

## Signal emitted when zone is fully loaded and ready for gameplay
signal zone_ready()

## Signal emitted when debris is collected
signal debris_collected(debris_type: String, value: int)

## Signal emitted when player enters NPC hub area
signal npc_hub_entered()

# Core system references
@onready var camera_controller: Node3D = $CameraController3D
@onready var camera_3d: Camera3D = $CameraController3D/Camera3D
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var debris_container: Node3D = $DebrisContainer
@onready var npc_hub_container: Node3D = $NPCHubContainer
@onready var player_ship: CharacterBody3D = $PlayerShip3D

# System nodes (shared with 2D version)
@onready var hud: Control = $UILayer/HUD
@onready var debug_label: Label = $UILayer/HUD/DebugLabel
@onready var log_label: Label = $UILayer/HUD/LogLabel
@onready var api_client: Node = $APIClient
@onready var upgrade_system: Node = $UpgradeSystem
@onready var ai_communicator: Node = $AICommunicator
@onready var network_manager: Node = $NetworkManager

# Preloaded scripts for 3D systems
const SpaceStationModule3DScript = preload("res://scripts/SpaceStationModule3D.gd")
const SpaceStationManager3DScript = preload("res://scripts/SpaceStationManager3D.gd")

# 3D Debris system
var debris_manager_3d: ZoneDebrisManager3D

# 3D Space Station system
var space_station_manager: Node3D

# Zone properties
var zone_name: String = "Zone Alpha 3D"
var zone_id: String = "zone_alpha_3d_01"
var zone_bounds: Vector3 = Vector3(100, 50, 100)  # 3D bounds
var game_logs: Array[String] = []

func _ready() -> void:
	_log_message("ZoneMain3D: Initializing 3D zone controller")
	_initialize_3d_zone()
	_update_debug_display()
	_log_message("ZoneMain3D: 3D Zone ready for gameplay")
	zone_ready.emit()

func _initialize_3d_zone() -> void:
	"""Initialize the 3D zone with basic settings"""
	_log_message("ZoneMain3D: Setting up 3D zone environment")

	# Ensure player ship is at the expected spawn position
	_ensure_player_spawn_position()

	# Configure camera controller
	if camera_controller and player_ship:
		camera_controller.set_target(player_ship)
		_log_message("ZoneMain3D: CameraController3D configured to follow player")

	# Configure lighting
	if directional_light:
		directional_light.light_energy = 0.8
		directional_light.shadow_enabled = true
		_log_message("ZoneMain3D: DirectionalLight3D configured with shadows")

	# Connect player signals
	if player_ship:
		player_ship.debris_collected.connect(_on_debris_collected)
		player_ship.npc_hub_entered.connect(_on_npc_hub_entered)
		player_ship.npc_hub_exited.connect(_on_npc_hub_exited)
		_log_message("ZoneMain3D: Player ship signals connected")

	# Initialize 3D debris manager
	_initialize_debris_manager_3d()

	# Initialize NPC hubs (space stations near player spawn)
	await _initialize_npc_hubs()

	# Initialize HUD
	if debug_label:
		debug_label.text = "Children of the Singularity - %s [3D DEBUG]" % zone_name

	_log_message("ZoneMain3D: 3D zone initialization complete")

func _ensure_player_spawn_position() -> void:
	"""Ensure the player ship spawns at the expected position for space station coordination"""
	var expected_spawn_position = Vector3(0, 2, 0)

	if player_ship:
		player_ship.global_position = expected_spawn_position
		_log_message("ZoneMain3D: Player ship positioned at spawn point: %s" % expected_spawn_position)
	else:
		_log_message("ZoneMain3D: WARNING - Player ship not found, cannot set spawn position")

func _initialize_debris_manager_3d() -> void:
	"""Initialize the 3D debris manager"""
	_log_message("ZoneMain3D: Initializing 3D debris manager")

	# Create debris manager instance
	debris_manager_3d = ZoneDebrisManager3D.new()
	debris_manager_3d.name = "ZoneDebrisManager3D"

	# Set debris container reference
	debris_manager_3d.debris_container = debris_container

	# Set zone bounds
	debris_manager_3d.zone_bounds = zone_bounds

	# Set player reference
	if player_ship:
		debris_manager_3d.set_player_reference(player_ship)

	# Connect debris manager signals
	debris_manager_3d.debris_collected.connect(_on_debris_collected)
	debris_manager_3d.debris_count_changed.connect(_on_debris_count_changed)
	debris_manager_3d.debris_spawned.connect(_on_debris_spawned)

	# Add to scene
	add_child(debris_manager_3d)

	_log_message("ZoneMain3D: 3D debris manager initialized and ready")

func _initialize_npc_hubs() -> void:
	"""Initialize the 3D NPC hub system with dynamically spawned space stations near player"""
	_log_message("ZoneMain3D: Initializing 3D space station system near player spawn")

	# Wait a frame for the scene to fully load
	await get_tree().process_frame

	# Remove old static hubs that are positioned far from player
	_remove_old_static_hubs()

	# Create and initialize the SpaceStationManager3D system
	await _initialize_space_station_manager()

	_log_message("ZoneMain3D: 3D space station system initialized with stations near player spawn")

func _remove_old_static_hubs() -> void:
	"""Remove the old static trading and upgrade hubs that are positioned far from player"""
	_log_message("ZoneMain3D: Removing old static hubs positioned far from player")

	# Remove old trading hub
	var old_trading_hub = npc_hub_container.get_node_or_null("TradingHub")
	if old_trading_hub:
		_log_message("ZoneMain3D: Removing old TradingHub at position: %s" % old_trading_hub.global_position)
		old_trading_hub.queue_free()

	# Remove old upgrade hub
	var old_upgrade_hub = npc_hub_container.get_node_or_null("UpgradeHub")
	if old_upgrade_hub:
		_log_message("ZoneMain3D: Removing old UpgradeHub at position: %s" % old_upgrade_hub.global_position)
		old_upgrade_hub.queue_free()

	_log_message("ZoneMain3D: Old static hubs removed")

func _initialize_space_station_manager() -> void:
	"""Initialize the SpaceStationManager3D system to spawn stations near player"""
	_log_message("ZoneMain3D: Creating SpaceStationManager3D system for single trading station")

	# Create the space station manager instance
	space_station_manager = SpaceStationManager3DScript.new()
	space_station_manager.name = "SpaceStationManager3D"

	# Set up station container reference
	space_station_manager.station_container = npc_hub_container

	# Configure station spawning parameters for exactly 1 trading station
	space_station_manager.zone_bounds = zone_bounds
	space_station_manager.station_count = 1  # Exactly 1 space station
	space_station_manager.modules_per_station = 1  # 1 trading module per station

	# Connect space station manager signals
	space_station_manager.module_created.connect(_on_module_created)
	space_station_manager.player_entered_module.connect(_on_player_entered_module)
	space_station_manager.player_exited_module.connect(_on_player_exited_module)

	# Add to scene tree
	add_child(space_station_manager)

	# Wait for initialization to complete
	await get_tree().process_frame
	await get_tree().process_frame

	_log_message("ZoneMain3D: SpaceStationManager3D initialized - 1 trading station will spawn near player at (0, 2, 0)")

	# Log station position for debugging
	var station_positions = space_station_manager.station_positions
	if station_positions.size() > 0:
		var pos = station_positions[0]
		var distance_from_player = pos.distance_to(Vector3(0, 2, 0))
		_log_message("ZoneMain3D: Trading station will be at %s (%.1f units from player spawn)" % [pos, distance_from_player])
	else:
		_log_message("ZoneMain3D: WARNING - No station positions calculated")

func _update_debug_display() -> void:
	"""Update the debug information display"""
	if debug_label:
		debug_label.text = "Children of the Singularity - %s [3D DEBUG] | Environment: 3D" % zone_name

func _log_message(message: String) -> void:
	"""Add a message to the game log and display it"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]

	print(formatted_message)
	game_logs.append(formatted_message)

	# Keep only last 10 log entries for display
	if game_logs.size() > 10:
		game_logs.pop_front()

	# Update log display
	if log_label:
		log_label.text = "Console Log (3D):\n" + "\n".join(game_logs)

## Get the current zone information
func get_zone_info() -> Dictionary:
	return {
		"zone_name": zone_name,
		"zone_id": zone_id,
		"bounds": zone_bounds,
		"is_3d": true
	}

## Simple test method to verify 3D functionality
func test_3d_functionality() -> void:
	_log_message("ZoneMain3D: Testing 3D functionality")

	if camera_3d:
		_log_message("ZoneMain3D: Camera3D is present and functional")

	if directional_light:
		_log_message("ZoneMain3D: DirectionalLight3D is present and functional")

	if world_environment:
		_log_message("ZoneMain3D: WorldEnvironment is present and functional")

	_log_message("ZoneMain3D: 3D functionality test complete")

## Signal handlers for player ship events
func _on_debris_collected(debris_type: String, value: int) -> void:
	"""Handle debris collection from player ship"""
	_log_message("ZoneMain3D: Player collected debris - %s (Value: %d)" % [debris_type, value])
	debris_collected.emit(debris_type, value)

func _on_npc_hub_entered(hub_type: String) -> void:
	"""Handle player entering NPC hub"""
	_log_message("ZoneMain3D: Player entered NPC hub - %s" % hub_type)
	npc_hub_entered.emit()

func _on_npc_hub_exited() -> void:
	"""Handle player exiting NPC hub"""
	_log_message("ZoneMain3D: Player exited NPC hub")

## Camera and player access methods
func get_player_ship() -> CharacterBody3D:
	"""Get reference to the player ship"""
	return player_ship

func get_camera_controller() -> Node3D:
	"""Get reference to the camera controller"""
	return camera_controller

func shake_camera(intensity: float, duration: float) -> void:
	"""Apply camera shake effect"""
	if camera_controller and camera_controller.has_method("shake"):
		camera_controller.shake(intensity, duration)
		_log_message("ZoneMain3D: Camera shake applied - Intensity: %.2f, Duration: %.2f" % [intensity, duration])

func set_camera_zoom(zoom_level: float) -> void:
	"""Set camera zoom level"""
	if camera_controller and camera_controller.has_method("set_zoom"):
		camera_controller.set_zoom(zoom_level)
		_log_message("ZoneMain3D: Camera zoom set to %.1f" % zoom_level)

## Signal handlers for debris manager
func _on_debris_count_changed(count: int) -> void:
	"""Handle debris count changes"""
	_log_message("ZoneMain3D: Debris count changed - Current: %d" % count)

func _on_debris_spawned(debris: DebrisObject3D) -> void:
	"""Handle debris spawning"""
	if debris:
		_log_message("ZoneMain3D: Debris spawned - Type: %s, Position: %s" % [debris.get_debris_type(), debris.global_position])

## Signal handlers for NPC hubs
func _on_hub_entered(hub_type: String, hub: Node3D) -> void:
	"""Handle player entering NPC hub"""
	_log_message("ZoneMain3D: Player entered %s hub" % hub_type)
	npc_hub_entered.emit()

func _on_hub_exited(hub_type: String, hub: Node3D) -> void:
	"""Handle player exiting NPC hub"""
	_log_message("ZoneMain3D: Player exited %s hub" % hub_type)

## Signal handlers for space station manager (legacy - may be unused now)
func _on_player_entered_module(module_type: String, module: Node3D) -> void:
	"""Handle player entering space station module"""
	_log_message("ZoneMain3D: Player entered space station module - %s" % module_type)
	npc_hub_entered.emit()

func _on_player_exited_module(module_type: String, module: Node3D) -> void:
	"""Handle player exiting space station module"""
	_log_message("ZoneMain3D: Player exited space station module - %s" % module_type)

func _on_module_created(module: Node3D) -> void:
	"""Handle space station module creation"""
	_log_message("ZoneMain3D: Space station module created at %s" % module.global_position)

## Debris manager access methods
func get_debris_manager() -> ZoneDebrisManager3D:
	"""Get reference to the debris manager"""
	return debris_manager_3d

func get_debris_count() -> int:
	"""Get current debris count"""
	if debris_manager_3d:
		return debris_manager_3d.get_debris_count()
	return 0

func get_debris_stats() -> Dictionary:
	"""Get debris statistics"""
	if debris_manager_3d:
		return debris_manager_3d.get_debris_stats()
	return {}

## Space station manager access methods
func get_space_station_manager() -> Node3D:
	"""Get reference to the space station manager"""
	return space_station_manager

func get_station_count() -> int:
	"""Get the number of space stations"""
	if space_station_manager and space_station_manager.has_method("get_station_count"):
		return space_station_manager.get_station_count()
	return 0

func get_module_count() -> int:
	"""Get the total number of station modules"""
	if space_station_manager and space_station_manager.has_method("get_module_count"):
		return space_station_manager.get_module_count()
	return 0

func get_trading_modules() -> Array:
	"""Get all trading modules for compatibility with existing systems"""
	if space_station_manager and space_station_manager.has_method("get_trading_modules"):
		return space_station_manager.get_trading_modules()
	return []

func get_station_data() -> Array[Dictionary]:
	"""Get comprehensive data about all space stations"""
	if space_station_manager and space_station_manager.has_method("get_station_data"):
		return space_station_manager.get_station_data()
	return []
