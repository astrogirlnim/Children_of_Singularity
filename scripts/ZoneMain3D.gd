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
@onready var camera_3d: Camera3D = $Camera3D
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var debris_container: Node3D = $DebrisContainer
@onready var npc_hub_container: Node3D = $NPCHubContainer

# System nodes (shared with 2D version)
@onready var hud: Control = $UILayer/HUD
@onready var debug_label: Label = $UILayer/HUD/DebugLabel
@onready var log_label: Label = $UILayer/HUD/LogLabel
@onready var api_client: Node = $APIClient
@onready var upgrade_system: Node = $UpgradeSystem
@onready var ai_communicator: Node = $AICommunicator
@onready var network_manager: Node = $NetworkManager

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

	# Configure camera
	if camera_3d:
		camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera_3d.size = 10.0
		camera_3d.position = Vector3(0, 10, 10)
		camera_3d.look_at(Vector3.ZERO, Vector3.UP)
		_log_message("ZoneMain3D: Camera3D configured with orthogonal projection")

	# Configure lighting
	if directional_light:
		directional_light.light_energy = 0.8
		directional_light.shadow_enabled = true
		_log_message("ZoneMain3D: DirectionalLight3D configured with shadows")

	# Initialize HUD
	if debug_label:
		debug_label.text = "Children of the Singularity - %s [3D DEBUG]" % zone_name

	_log_message("ZoneMain3D: 3D zone initialization complete")

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
