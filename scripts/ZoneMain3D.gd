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
@onready var skybox_manager_3d: Node3D = $SkyboxManager3D

# System nodes (shared with 2D version)
@onready var hud: Control = $UILayer/HUD
@onready var debug_label: Label = $UILayer/HUD/DebugLabel
@onready var log_label: Label = $UILayer/HUD/LogLabel
@onready var inventory_status: Label = $UILayer/HUD/InventoryPanel/InventoryStatus
@onready var inventory_grid: GridContainer = $UILayer/HUD/InventoryPanel/InventoryGrid
@onready var credits_label: Label = $UILayer/HUD/StatsPanel/CreditsLabel
@onready var debris_count_label: Label = $UILayer/HUD/StatsPanel/DebrisCountLabel
@onready var api_client: Node = $APIClient
@onready var upgrade_system: Node = $UpgradeSystem
@onready var ai_communicator: Node = $AICommunicator
@onready var network_manager: Node = $NetworkManager

# Trading interface UI elements
@onready var trading_interface: Panel = $UILayer/HUD/TradingInterface
@onready var trading_title: Label = $UILayer/HUD/TradingInterface/TradingTitle
@onready var trading_content: VBoxContainer = $UILayer/HUD/TradingInterface/TradingContent
@onready var trading_result: Label = $UILayer/HUD/TradingInterface/TradingContent/TradingResult
@onready var sell_all_button: Button = $UILayer/HUD/TradingInterface/TradingContent/SellAllButton
@onready var trading_close_button: Button = $UILayer/HUD/TradingInterface/TradingCloseButton

# Selective trading UI elements (will be created dynamically)
var debris_selection_container: ScrollContainer
var debris_selection_list: VBoxContainer
var selection_summary_label: Label
var sell_selected_button: Button
var selected_debris: Dictionary = {}  # Store selected quantities per debris type

# Preloaded scripts for 3D systems
const SpaceStationModule3DScript = preload("res://scripts/SpaceStationModule3D.gd")
const SpaceStationManager3DScript = preload("res://scripts/SpaceStationManager3D.gd")
const ZoneBoundaryManager3DScript = preload("res://scripts/ZoneBoundaryManager3D.gd")

# 3D Debris system
var debris_manager_3d: ZoneDebrisManager3D

# 3D Space Station system (UFO structures only)
var space_station_manager: Node3D

# 3D Trading Hub system (mechanical trading devices only)
var trading_hub_manager: Node3D

# 3D Zone Boundary system (invisible collision walls)
var zone_boundary_manager: ZoneBoundaryManager3D

# 3D Background system (layered background elements with parallax)
var background_manager: BackgroundManager3D

# Zone properties
var zone_name: String = "Zone Alpha 3D"
var zone_id: String = "zone_alpha_3d_01"
var zone_bounds: Vector3 = Vector3(400, 50, 400)  # 3D bounds - expanded playable area
var game_logs: Array[String] = []

# Position sync system for backend integration
var position_sync_timer: float = 0.0
var position_sync_interval: float = 5.0  # Sync position every 5 seconds
var last_synced_position: Vector3 = Vector3.ZERO

# Inventory display tracking
var inventory_items: Array[Control] = []
var last_inventory_size: int = 0
var last_inventory_hash: String = ""

func _ready() -> void:
	_log_message("ZoneMain3D: Initializing 3D zone controller")
	_initialize_3d_zone()
	_update_debug_display()
	_log_message("ZoneMain3D: 3D Zone ready for gameplay")
	zone_ready.emit()

func _process(delta: float) -> void:
	##Handle periodic updates including position sync
	# Handle position sync timer
	position_sync_timer += delta
	if position_sync_timer >= position_sync_interval:
		position_sync_timer = 0.0
		_sync_player_position_to_backend()

func _initialize_3d_zone() -> void:
	##Initialize the 3D zone with basic settings
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

	# Initialize trading interface UI connections
	_initialize_trading_interface()

	# Initialize 3D debris manager
	_initialize_debris_manager_3d()

	# Initialize NPC hubs (space stations near player spawn)
	_initialize_npc_hubs()

	# Initialize zone boundaries (invisible collision walls)
	_initialize_zone_boundaries()

	# Initialize background system (layered background elements with parallax)
	# BackgroundManager3D disabled for skybox revamp Phase 0
	# _initialize_background_system()

	# Initialize HUD
	if debug_label:
		debug_label.text = "Children of the Singularity - %s [3D DEBUG]" % zone_name

	# Initialize inventory display with any existing items
	if player_ship and player_ship.current_inventory.size() > 0:
		_update_grouped_inventory_display(player_ship.current_inventory)
		_log_message("ZoneMain3D: Initialized inventory display with %d existing items" % player_ship.current_inventory.size())

	_log_message("ZoneMain3D: 3D zone initialization complete")

func _ensure_player_spawn_position() -> void:
	##Ensure the player ship spawns at the expected position for space station coordination
	var expected_spawn_position = Vector3(0, 2, 0)

	if player_ship:
		player_ship.global_position = expected_spawn_position
		_log_message("ZoneMain3D: Player ship positioned at spawn point: %s" % expected_spawn_position)
	else:
		_log_message("ZoneMain3D: WARNING - Player ship not found, cannot set spawn position")

func _initialize_debris_manager_3d() -> void:
	##Initialize the 3D debris manager
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
	##Initialize the 3D NPC hub system with separate managers for space stations and trading hubs
	_log_message("ZoneMain3D: Initializing 3D space station and trading hub systems with proper separation")

	# Remove old static hubs that are positioned far from player
	_remove_old_static_hubs()

	# Create and initialize the SpaceStationManager3D system (for UFO-like space stations ONLY)
	_initialize_space_station_manager()

	# Create and initialize the TradingHubManager3D system (for mechanical trading devices ONLY)
	_initialize_trading_hub_manager()

	_log_message("ZoneMain3D: Both space station (UFO) and trading hub (mechanical) systems initialized with proper separation")

func _remove_old_static_hubs() -> void:
	##Remove the old static trading and upgrade hubs that are positioned far from player
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
	##Initialize the SpaceStationManager3D system to spawn stations near player
	_log_message("ZoneMain3D: Creating SpaceStationManager3D system for single space station")

	# Create the space station manager instance
	space_station_manager = SpaceStationManager3DScript.new()
	space_station_manager.name = "SpaceStationManager3D"

	# Set up station container reference
	space_station_manager.station_container = npc_hub_container

	# Configure station spawning parameters for exactly 1 space station
	space_station_manager.zone_bounds = zone_bounds
	space_station_manager.station_count = 1  # Exactly 1 space station
	space_station_manager.modules_per_station = 1  # 1 module per station

	# Connect space station manager signals
	space_station_manager.module_created.connect(_on_module_created)
	space_station_manager.player_entered_module.connect(_on_player_entered_module)
	space_station_manager.player_exited_module.connect(_on_player_exited_module)

	# Add to scene tree
	add_child(space_station_manager)

	_log_message("ZoneMain3D: SpaceStationManager3D initialized - 1 space station will spawn near player at (0, 2, 0)")

	# Log station position for debugging (deferred to next frame)
	call_deferred("_log_space_station_positions")

func _initialize_trading_hub_manager() -> void:
	##Initialize the TradingHubManager3D system to spawn trading hubs near player
	_log_message("ZoneMain3D: Creating TradingHubManager3D system for single trading hub")

	# Create the trading hub manager instance
	trading_hub_manager = preload("res://scripts/TradingHubManager3D.gd").new()
	trading_hub_manager.name = "TradingHubManager3D"

	# Set up hub container reference
	trading_hub_manager.hub_container = npc_hub_container

	# Configure hub spawning parameters for exactly 1 trading hub
	trading_hub_manager.zone_bounds = zone_bounds
	trading_hub_manager.hub_count = 1  # Exactly 1 trading hub

	# Connect hub manager signals
	trading_hub_manager.hub_created.connect(_on_hub_created)
	trading_hub_manager.player_entered_hub.connect(_on_player_entered_hub)
	trading_hub_manager.player_exited_hub.connect(_on_player_exited_hub)

	# Add to scene tree
	add_child(trading_hub_manager)

	_log_message("ZoneMain3D: TradingHubManager3D initialized - 1 trading hub will spawn near player at (0, 2, 0)")

	# Log hub position for debugging (deferred to next frame)
	call_deferred("_log_trading_hub_positions")

func _initialize_zone_boundaries() -> void:
	##Initialize the 3D zone boundary system with invisible collision walls
	_log_message("ZoneMain3D: Initializing 3D zone boundary system")

	# Create the zone boundary manager instance
	zone_boundary_manager = ZoneBoundaryManager3DScript.new()
	zone_boundary_manager.name = "ZoneBoundaryManager3D"

	# Configure boundary settings
	zone_boundary_manager.zone_bounds = zone_bounds
	zone_boundary_manager.warning_distance = 20.0
	zone_boundary_manager.enable_warnings = true
	zone_boundary_manager.enable_visual_indicators = false  # Set to true for debugging

	# Set player reference for boundary checking
	if player_ship:
		zone_boundary_manager.set_player_reference(player_ship)

	# Connect boundary manager signals
	zone_boundary_manager.boundary_warning.connect(_on_boundary_warning)
	zone_boundary_manager.boundary_collision.connect(_on_boundary_collision)
	zone_boundary_manager.boundary_safe.connect(_on_boundary_safe)

	# Add to scene tree
	add_child(zone_boundary_manager)

	_log_message("ZoneMain3D: Zone boundary system initialized - Invisible walls created around zone bounds: %s" % zone_bounds)

func _initialize_background_system() -> void:
	##Initialize the 3D background system with layered elements and parallax scrolling
	_log_message("ZoneMain3D: Initializing background system for enhanced depth perception")

	# Create and configure background manager
	background_manager = BackgroundManager3D.new()
	background_manager.name = "BackgroundManager3D"

	# Configure background manager properties
	background_manager.parallax_strength = 0.1
	background_manager.enable_parallax = true
	background_manager.enable_performance_culling = true
	background_manager.max_background_distance = 500.0

	# Set camera reference for parallax calculations
	if camera_3d:
		background_manager.set_camera_reference(camera_3d)
		_log_message("ZoneMain3D: Camera reference set for background parallax")
	else:
		_log_message("ZoneMain3D: Warning - Camera3D not found for background system")

	# Add background manager to scene (position at origin, behind everything)
	background_manager.position = Vector3.ZERO
	add_child(background_manager)

	# Connect background manager signals
	background_manager.background_ready.connect(_on_background_ready)
	background_manager.layer_visibility_changed.connect(_on_background_layer_visibility_changed)

	_log_message("ZoneMain3D: Background system initialized with layered elements")

func _on_background_ready() -> void:
	##Handle background system ready signal
	_log_message("ZoneMain3D: Background system fully loaded with %d layers" % background_manager.get_layer_count())

	# Update debug display to show background info
	_update_debug_display()

func _on_background_layer_visibility_changed(layer_name: String, layer_visible: bool) -> void:
	##Handle background layer visibility changes for performance monitoring
	_log_message("ZoneMain3D: Background layer '%s' visibility changed to %s" % [layer_name, layer_visible])

func _update_debug_display() -> void:
	##Update the debug information display
	if debug_label:
		var bg_info = ""
		if background_manager:
			bg_info = " | BG Layers: %d" % background_manager.get_layer_count()
		debug_label.text = "Children of the Singularity - %s [3D DEBUG] | Environment: 3D%s" % [zone_name, bg_info]

func _input(event):
	## Handle input events, including skybox visibility toggle for testing
	if event is InputEventKey and event.pressed:
		# Toggle skybox visibility with F9 key (for testing skybox interference)
		if event.keycode == KEY_F9:
			if skybox_manager_3d:
				# Toggle between visible and invisible
				var current_visible = skybox_manager_3d.active_layers.size() > 0 and skybox_manager_3d.active_layers[0].visible
				skybox_manager_3d.toggle_skybox_visibility(not current_visible)
				var state_text = "HIDDEN" if current_visible else "VISIBLE"
				_log_message("ZoneMain3D: Skybox toggled - Now %s (F9 to toggle)" % state_text)

func _log_message(message: String) -> void:
	##Add a message to the game log and display it
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
	##Handle debris collection from player ship
	_log_message("ZoneMain3D: Player collected debris - %s (Value: %d)" % [debris_type, value])

	# Immediately update inventory UI when debris is collected (don't wait for timer)
	if player_ship and inventory_status:
		var current_size = player_ship.current_inventory.size()
		var max_size = player_ship.inventory_capacity
		inventory_status.text = "%d/%d Items" % [current_size, max_size]

		# Color code based on fullness
		if current_size >= max_size:
			inventory_status.modulate = Color.RED
		elif current_size >= max_size * 0.8:
			inventory_status.modulate = Color.YELLOW
		else:
			inventory_status.modulate = Color.WHITE

		# Update grouped inventory display
		_update_grouped_inventory_display(player_ship.current_inventory)

		_log_message("ZoneMain3D: Inventory UI updated immediately - %d/%d items with grouped display" % [current_size, max_size])

	# Update credits display if available
	if player_ship and credits_label:
		credits_label.text = "Credits: %d" % player_ship.credits

	debris_collected.emit(debris_type, value)

func _on_npc_hub_entered(hub_type: String) -> void:
	##Handle player entering NPC hub
	_log_message("ZoneMain3D: Player entered NPC hub - %s" % hub_type)
	npc_hub_entered.emit()

func _on_npc_hub_exited() -> void:
	##Handle player exiting NPC hub
	_log_message("ZoneMain3D: Player exited NPC hub")

## Camera and player access methods
func get_player_ship() -> CharacterBody3D:
	##Get reference to the player ship
	return player_ship

func get_camera_controller() -> Node3D:
	##Get reference to the camera controller
	return camera_controller

func shake_camera(intensity: float, duration: float) -> void:
	##Apply camera shake effect
	if camera_controller and camera_controller.has_method("shake"):
		camera_controller.shake(intensity, duration)
		_log_message("ZoneMain3D: Camera shake applied - Intensity: %.2f, Duration: %.2f" % [intensity, duration])

func set_camera_zoom(zoom_level: float) -> void:
	##Set camera zoom level
	if camera_controller and camera_controller.has_method("set_zoom"):
		camera_controller.set_zoom(zoom_level)
		_log_message("ZoneMain3D: Camera zoom set to %.1f" % zoom_level)

## Signal handlers for debris manager
func _on_debris_count_changed(count: int) -> void:
	##Handle debris count changes
	_log_message("ZoneMain3D: Debris count changed - Current: %d" % count)

func _on_debris_spawned(debris: DebrisObject3D) -> void:
	##Handle debris spawning
	if debris:
		_log_message("ZoneMain3D: Debris spawned - Type: %s, Position: %s" % [debris.get_debris_type(), debris.global_position])

## Signal handlers for NPC hubs
func _on_hub_entered(hub_type: String, _hub: Node3D) -> void:
	##Handle player entering NPC hub
	_log_message("ZoneMain3D: Player entered %s hub" % hub_type)
	npc_hub_entered.emit()

func _on_hub_exited(hub_type: String, _hub: Node3D) -> void:
	##Handle player exiting NPC hub
	_log_message("ZoneMain3D: Player exited %s hub" % hub_type)

## Signal handlers for space station manager (legacy - may be unused now)
func _on_player_entered_module(module_type: String, _module: Node3D) -> void:
	##Handle player entering space station module
	_log_message("ZoneMain3D: Player entered space station module - %s" % module_type)
	npc_hub_entered.emit()

func _on_player_exited_module(module_type: String, _module: Node3D) -> void:
	##Handle player exiting space station module
	_log_message("ZoneMain3D: Player exited space station module - %s" % module_type)

func _on_module_created(module: Node3D) -> void:
	##Handle space station module creation
	_log_message("ZoneMain3D: Space station module created at %s" % module.global_position)

func _on_hub_created(hub: Node3D) -> void:
	##Handle trading hub creation
	_log_message("ZoneMain3D: Trading hub created at %s" % hub.global_position)

func _on_player_entered_hub(hub_type: String, _hub: Node3D) -> void:
	##Handle player entering trading hub
	_log_message("ZoneMain3D: Player entered trading hub: %s" % hub_type)
	npc_hub_entered.emit()

func _on_player_exited_hub(hub_type: String, _hub: Node3D) -> void:
	##Handle player exiting trading hub
	_log_message("ZoneMain3D: Player exited trading hub: %s" % hub_type)

func _log_space_station_positions() -> void:
	##Log space station positions after initialization
	if space_station_manager and space_station_manager.has_method("get_station_count"):
		var station_positions = space_station_manager.station_positions
		if station_positions.size() > 0:
			var pos = station_positions[0]
			var distance_from_player = pos.distance_to(Vector3(0, 2, 0))
			_log_message("ZoneMain3D: Space station positioned at %s (%.1f units from player spawn)" % [pos, distance_from_player])
		else:
			_log_message("ZoneMain3D: WARNING - No station positions calculated")

func _log_trading_hub_positions() -> void:
	##Log trading hub positions after initialization
	if trading_hub_manager and trading_hub_manager.has_method("get_hub_count"):
		var hub_positions = trading_hub_manager.hub_positions
		if hub_positions.size() > 0:
			var pos = hub_positions[0]
			var distance_from_player = pos.distance_to(Vector3(0, 2, 0))
			_log_message("ZoneMain3D: Trading hub positioned at %s (%.1f units from player spawn)" % [pos, distance_from_player])
		else:
			_log_message("ZoneMain3D: WARNING - No trading hub positions calculated")

## Signal handlers for zone boundaries

func _on_boundary_warning(distance: float, direction: String) -> void:
	##Handle boundary warning when player approaches zone edge
	_log_message("ZoneMain3D: BOUNDARY WARNING - %.1f units from %s boundary" % [distance, direction])

	# Display warning message to player (could be integrated with UI system)
	if hud:
		var warning_message = "WARNING: Approaching zone boundary (%s) - %.1f units remaining" % [direction.to_upper(), distance]
		# This could be expanded to show a visual warning in the UI
		_log_message("ZoneMain3D: Warning displayed to player: %s" % warning_message)

func _on_boundary_collision(collision_position: Vector3, boundary_type: String) -> void:
	##Handle boundary collision when player hits zone wall
	_log_message("ZoneMain3D: BOUNDARY COLLISION - Player hit %s at position %s" % [boundary_type, collision_position])

	# Optional: Add camera shake or other feedback
	if camera_controller and camera_controller.has_method("shake"):
		camera_controller.shake(2.0, 0.3)

func _on_boundary_safe() -> void:
	##Handle when player returns to safe zone area
	_log_message("ZoneMain3D: Player returned to safe zone area")

## Debris manager access methods
func get_debris_manager() -> ZoneDebrisManager3D:
	##Get reference to the debris manager
	return debris_manager_3d

func get_debris_count() -> int:
	##Get current debris count
	if debris_manager_3d:
		return debris_manager_3d.get_debris_count()
	return 0

func get_debris_stats() -> Dictionary:
	##Get debris statistics
	if debris_manager_3d:
		return debris_manager_3d.get_debris_stats()
	return {}

## Zone boundary manager access methods
func get_boundary_manager() -> ZoneBoundaryManager3D:
	##Get reference to the zone boundary manager
	return zone_boundary_manager

func get_boundary_info() -> Dictionary:
	##Get zone boundary information
	if zone_boundary_manager:
		return zone_boundary_manager.get_boundary_info()
	return {}

func is_position_in_bounds(check_position: Vector3) -> bool:
	##Check if a position is within zone boundaries
	if zone_boundary_manager:
		return zone_boundary_manager.is_position_in_bounds(check_position)
	return true

func enable_visual_boundaries(enabled: bool) -> void:
	##Enable or disable visual boundary indicators for debugging
	if zone_boundary_manager:
		zone_boundary_manager.enable_visual_boundaries(enabled)
		_log_message("ZoneMain3D: Visual boundaries %s" % ("enabled" if enabled else "disabled"))

## Space station manager access methods
func get_space_station_manager() -> Node3D:
	##Get reference to the space station manager
	return space_station_manager

func get_station_count() -> int:
	##Get the number of space stations
	if space_station_manager and space_station_manager.has_method("get_station_count"):
		return space_station_manager.get_station_count()
	return 0

func get_module_count() -> int:
	##Get the total number of station modules
	if space_station_manager and space_station_manager.has_method("get_module_count"):
		return space_station_manager.get_module_count()
	return 0

func get_trading_modules() -> Array:
	##Get all trading modules for compatibility with existing systems
	if space_station_manager and space_station_manager.has_method("get_trading_modules"):
		return space_station_manager.get_trading_modules()
	return []

func get_station_data() -> Array[Dictionary]:
	##Get comprehensive data about all space stations
	if space_station_manager and space_station_manager.has_method("get_station_data"):
		return space_station_manager.get_station_data()
	return []

func _sync_player_position_to_backend() -> void:
	##Sync player 3D position to backend via APIClient
	if not player_ship or not api_client:
		return

	var current_position = player_ship.global_position

	# Only sync if position has changed significantly (avoid unnecessary API calls)
	if current_position.distance_to(last_synced_position) < 1.0:
		return

	_log_message("ZoneMain3D: Syncing 3D position to backend: %s" % current_position)

	# Get complete player data for backend sync
	var player_info = player_ship.get_player_info()

	# Convert Vector3 position to the format expected by backend
	var player_data = {
		"player_id": player_info.player_id,
		"name": "Player",  # Could be made dynamic
		"credits": player_info.credits,
		"progression_path": "rogue",  # Could be made dynamic
		"position": {
			"x": current_position.x,
			"y": current_position.y,
			"z": current_position.z
		},
		"upgrades": player_info.upgrades
	}

	# Send to backend
	if api_client.has_method("save_player_data"):
		api_client.save_player_data(player_data)
		last_synced_position = current_position
		_log_message("ZoneMain3D: Player 3D position synced to backend - X:%.1f Y:%.1f Z:%.1f" % [current_position.x, current_position.y, current_position.z])

## Grouped Inventory Display Methods

func _update_grouped_inventory_display(inventory_data: Array) -> void:
	##Update the inventory display grid with grouped quantities by type
	_log_message("ZoneMain3D: Updating grouped inventory display with %d items" % inventory_data.size())

	if not inventory_grid:
		_log_message("ZoneMain3D: Warning - inventory_grid not found!")
		return

	# Clear existing items
	for item in inventory_items:
		if item:
			item.queue_free()
	inventory_items.clear()

	# Group inventory items by type and count quantities
	var grouped_inventory = _group_inventory_by_type(inventory_data)
	_log_message("ZoneMain3D: Grouped %d individual items into %d types" % [inventory_data.size(), grouped_inventory.size()])

	# Add grouped items to display
	for item_type in grouped_inventory:
		var group_data = grouped_inventory[item_type]
		var item_control = _create_grouped_inventory_item_control(item_type, group_data)
		inventory_grid.add_child(item_control)
		inventory_items.append(item_control)
		_log_message("ZoneMain3D: Added %s x%d to inventory display" % [item_type, group_data.quantity])

	# Update tracking variables
	last_inventory_size = inventory_data.size()
	last_inventory_hash = str(inventory_data.hash())

func _group_inventory_by_type(inventory_data: Array) -> Dictionary:
	##Group inventory items by type and calculate totals
	var grouped = {}

	for item_data in inventory_data:
		var item_type = item_data.get("type", "Unknown")
		var item_value = item_data.get("value", 0)

		if not grouped.has(item_type):
			grouped[item_type] = {
				"quantity": 0,
				"total_value": 0,
				"individual_value": item_value
			}

		grouped[item_type].quantity += 1
		grouped[item_type].total_value += item_value

	return grouped

func _create_grouped_inventory_item_control(item_type: String, group_data: Dictionary) -> Control:
	##Create a control for a grouped inventory item with quantity and value display
	var item_panel = Panel.new()
	item_panel.custom_minimum_size = Vector2(120, 80)

	# Use the new generated theme styling with proper margins
	item_panel.theme_type_variation = "InventoryPanel"

	# Use VBoxContainer for clean layout
	var vbox = VBoxContainer.new()
	item_panel.add_child(vbox)
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.add_theme_constant_override("separation", 4)

	# Item type label
	var type_label = Label.new()
	type_label.text = item_type.capitalize().replace("_", " ")
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(type_label)

	# Quantity label (cyan color)
	var quantity_label = Label.new()
	quantity_label.text = "x%d" % group_data.quantity
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_label.add_theme_color_override("font_color", Color.CYAN)
	quantity_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(quantity_label)

	# Total value label (yellow color)
	var total_value_label = Label.new()
	total_value_label.text = "%d credits" % group_data.total_value
	total_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_value_label.add_theme_color_override("font_color", Color.YELLOW)
	total_value_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(total_value_label)

	# Individual value label (gray color)
	var individual_value_label = Label.new()
	individual_value_label.text = "(%d each)" % group_data.individual_value
	individual_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	individual_value_label.add_theme_color_override("font_color", Color.GRAY)
	individual_value_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(individual_value_label)

	return item_panel

func _get_rarity_color(item_type: String) -> Color:
	##Get color based on debris rarity/value
	match item_type:
		"scrap_metal":
			return Color.GRAY  # Common
		"bio_waste":
			return Color.GREEN  # Uncommon
		"broken_satellite":
			return Color.BLUE  # Rare
		"ai_component":
			return Color.PURPLE  # Epic
		"unknown_artifact":
			return Color.GOLD  # Legendary
		_:
			return Color.WHITE  # Default

func _initialize_trading_interface() -> void:
	##Initialize trading interface UI connections and functionality
	_log_message("ZoneMain3D: Initializing enhanced trading interface with selective selling")

	# Initially hide trading interface
	if trading_interface:
		trading_interface.visible = false
		_log_message("ZoneMain3D: Trading interface hidden initially")

	# Create enhanced trading UI structure
	_create_selective_trading_ui()

	# Connect buttons
	if sell_all_button:
		sell_all_button.pressed.connect(_on_sell_all_pressed)
		_log_message("ZoneMain3D: Sell all button connected")

	# Connect close button
	if trading_close_button:
		trading_close_button.pressed.connect(_on_trading_close_pressed)
		_log_message("ZoneMain3D: Trading close button connected")

func _create_selective_trading_ui() -> void:
	##Create the enhanced selective trading UI elements
	_log_message("ZoneMain3D: Creating selective trading UI elements")

	if not trading_content:
		_log_message("ZoneMain3D: ERROR - Trading content container not found!")
		return

	# Create scroll container for debris selection
	debris_selection_container = ScrollContainer.new()
	debris_selection_container.name = "DebrisSelectionContainer"
	debris_selection_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debris_selection_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debris_selection_container.custom_minimum_size = Vector2(0, 200)

	# Create VBox for debris list
	debris_selection_list = VBoxContainer.new()
	debris_selection_list.name = "DebrisSelectionList"
	debris_selection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debris_selection_container.add_child(debris_selection_list)

	# Create selection summary label
	selection_summary_label = Label.new()
	selection_summary_label.name = "SelectionSummary"
	selection_summary_label.text = "No items selected"
	selection_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_summary_label.add_theme_color_override("font_color", Color.CYAN)

	# Create sell selected button
	sell_selected_button = Button.new()
	sell_selected_button.name = "SellSelectedButton"
	sell_selected_button.text = "SELL SELECTED"
	sell_selected_button.pressed.connect(_on_sell_selected_pressed)

	# Rearrange trading content structure
	# Move existing elements to correct positions
	if trading_result:
		trading_content.move_child(trading_result, 0)

	# Add new elements in order
	trading_content.add_child(debris_selection_container)
	trading_content.add_child(selection_summary_label)
	trading_content.add_child(sell_selected_button)

	# Keep sell all button at the end
	if sell_all_button:
		trading_content.move_child(sell_all_button, -1)

	_log_message("ZoneMain3D: Selective trading UI structure created")

## Trading Interface Methods

func open_trading_interface(hub_type: String) -> void:
	##Open the trading interface when player presses F at a trading hub
	_log_message("ZoneMain3D: Opening enhanced trading interface for %s hub" % hub_type)

	if not trading_interface:
		_log_message("ZoneMain3D: ERROR - Trading interface not found!")
		return

	# Clear previous selections
	selected_debris.clear()

	# Show the trading interface
	trading_interface.visible = true

	# Update title
	if trading_title:
		trading_title.text = "TRADING TERMINAL - %s" % hub_type.to_upper()

	# Update basic info
	if trading_result and player_ship:
		var inventory_count = player_ship.current_inventory.size()
		var inventory_value = _calculate_inventory_total_value()
		trading_result.text = "Total Inventory: %d items worth %d credits\nSelect items below to sell individually, or use 'SELL ALL'" % [inventory_count, inventory_value]
		_log_message("ZoneMain3D: Trading interface updated - %d items worth %d credits" % [inventory_count, inventory_value])

	# Populate selective trading UI
	_populate_debris_selection_ui()

	# Update selection summary
	_update_selection_summary()

	_log_message("ZoneMain3D: Enhanced trading interface opened successfully")

func close_trading_interface() -> void:
	##Close the trading interface
	_log_message("ZoneMain3D: Closing trading interface")

	if trading_interface:
		trading_interface.visible = false

	_log_message("ZoneMain3D: Trading interface closed")

func _on_sell_all_pressed() -> void:
	##Handle sell all button press - sell all debris in inventory
	_log_message("ZoneMain3D: Sell all button pressed")

	if not player_ship:
		_log_message("ZoneMain3D: ERROR - Player ship not found!")
		return

	var inventory = player_ship.current_inventory
	if inventory.is_empty():
		_update_trading_result("No debris to sell!", Color.YELLOW)
		_log_message("ZoneMain3D: No debris in inventory to sell")
		return

	# Calculate total value
	var total_value = _calculate_inventory_total_value()
	var item_count = inventory.size()

	_log_message("ZoneMain3D: Selling %d items for %d credits total" % [item_count, total_value])

	# Clear inventory and add credits
	var sold_items = player_ship.clear_inventory()
	player_ship.add_credits(total_value)

	# Update UI immediately
	_update_inventory_displays()
	_update_credits_display()

	# Show success message
	var success_message = "SUCCESS!\nSold %d items for %d credits\nTotal Credits: %d" % [item_count, total_value, player_ship.credits]
	_update_trading_result(success_message, Color.GREEN)

	# Sync with backend API
	_sync_sale_with_backend(sold_items, total_value)

	_log_message("ZoneMain3D: Sale completed - %d items sold for %d credits" % [item_count, total_value])

func _on_trading_close_pressed() -> void:
	##Handle trading close button press
	_log_message("ZoneMain3D: Trading close button pressed")
	close_trading_interface()

func _calculate_inventory_total_value() -> int:
	##Calculate total value of all items in inventory
	if not player_ship:
		return 0

	var total_value = 0
	for item in player_ship.current_inventory:
		total_value += item.get("value", 0)

	return total_value

func _update_trading_result(message: String, color: Color = Color.WHITE) -> void:
	##Update the trading result display
	if trading_result:
		trading_result.text = message
		trading_result.modulate = color
		_log_message("ZoneMain3D: Trading result updated: %s" % message)

func _sync_sale_with_backend(sold_items: Array, total_value: int) -> void:
	##Sync the sale transaction with the backend API
	if not api_client:
		_log_message("ZoneMain3D: Warning - No API client available for backend sync")
		return

	# Create transaction data
	var transaction_data = {
		"player_id": player_ship.player_id,
		"transaction_type": "sell_all",
		"items_sold": sold_items,
		"credits_earned": total_value,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Send to backend if method exists
	if api_client.has_method("record_transaction"):
		api_client.record_transaction(transaction_data)
		_log_message("ZoneMain3D: Transaction synced with backend API")
	elif api_client.has_method("sell_all_inventory"):
		api_client.sell_all_inventory()
		_log_message("ZoneMain3D: Sell all request sent to backend API")
	else:
		_log_message("ZoneMain3D: Warning - Backend API does not support transaction recording")

func _update_inventory_displays() -> void:
	##Update all inventory-related UI displays
	if player_ship and inventory_status:
		var current_size = player_ship.current_inventory.size()
		var max_size = player_ship.inventory_capacity
		inventory_status.text = "%d/%d Items" % [current_size, max_size]

		# Color code based on fullness
		if current_size >= max_size:
			inventory_status.modulate = Color.RED
		elif current_size >= max_size * 0.8:
			inventory_status.modulate = Color.YELLOW
		else:
			inventory_status.modulate = Color.WHITE

		# Update grouped inventory display
		_update_grouped_inventory_display(player_ship.current_inventory)

		_log_message("ZoneMain3D: Inventory displays updated - %d/%d items" % [current_size, max_size])

func _update_credits_display() -> void:
	##Update the credits display
	if player_ship and credits_label:
		credits_label.text = "Credits: %d" % player_ship.credits
		_log_message("ZoneMain3D: Credits display updated - %d credits" % player_ship.credits)

func _on_sell_selected_pressed() -> void:
	##Handle sell selected button press - sell the currently selected items
	_log_message("ZoneMain3D: Sell selected button pressed")

	if not player_ship:
		_log_message("ZoneMain3D: ERROR - Player ship not found!")
		return

	if selected_debris.is_empty():
		_update_trading_result("No items selected to sell!", Color.YELLOW)
		_log_message("ZoneMain3D: No items selected to sell")
		return

	var sold_items = []
	var total_value = 0
	var items_to_remove = []

	# Process each selected debris type
	for debris_type in selected_debris:
		var quantity_to_sell = selected_debris[debris_type]
		if quantity_to_sell <= 0:
			continue

		var items_found = 0

		# Find and mark items for removal
		for i in range(player_ship.current_inventory.size()):
			var item = player_ship.current_inventory[i]
			if item.get("type") == debris_type and items_found < quantity_to_sell:
				sold_items.append(item)
				items_to_remove.append(i)
				total_value += item.get("value", 0)
				items_found += 1

		_log_message("ZoneMain3D: Found %d/%d %s items to sell" % [items_found, quantity_to_sell, debris_type])

	if sold_items.is_empty():
		_update_trading_result("No items found to sell!", Color.YELLOW)
		_log_message("ZoneMain3D: No items found to sell")
		return

	# Remove items from inventory (reverse order to maintain indices)
	items_to_remove.sort()
	items_to_remove.reverse()
	for index in items_to_remove:
		player_ship.current_inventory.remove_at(index)

	# Add credits
	player_ship.add_credits(total_value)

	# Clear selections
	selected_debris.clear()

	# Update UI immediately
	_update_inventory_displays()
	_update_credits_display()

	# Refresh the selection UI with new inventory
	_populate_debris_selection_ui()
	_update_selection_summary()

	# Show success message
	var success_message = "SUCCESS!\nSold %d selected items for %d credits\nTotal Credits: %d" % [sold_items.size(), total_value, player_ship.credits]
	_update_trading_result(success_message, Color.GREEN)

	# Sync with backend API
	_sync_sale_with_backend(sold_items, total_value)

	_log_message("ZoneMain3D: Selective sale completed - %d items sold for %d credits" % [sold_items.size(), total_value])

func _populate_debris_selection_ui() -> void:
	##Populate the debris selection UI with current inventory
	if not debris_selection_list or not player_ship:
		return

	# Clear existing selection items
	for child in debris_selection_list.get_children():
		child.queue_free()

	# Group inventory by type
	var grouped_inventory = _group_inventory_by_type(player_ship.current_inventory)
	_log_message("ZoneMain3D: Populating selection UI with %d debris types" % grouped_inventory.size())

	# Create selection row for each debris type
	for debris_type in grouped_inventory:
		var group_data = grouped_inventory[debris_type]
		var selection_row = _create_debris_selection_row(debris_type, group_data)
		debris_selection_list.add_child(selection_row)

	_log_message("ZoneMain3D: Created %d debris selection rows" % grouped_inventory.size())

func _create_debris_selection_row(debris_type: String, group_data: Dictionary) -> Control:
	##Create a selection row for a specific debris type
	var row_container = HBoxContainer.new()
	row_container.name = "Row_%s" % debris_type
	row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Debris type label
	var type_label = Label.new()
	type_label.text = debris_type.capitalize().replace("_", " ")
	type_label.custom_minimum_size = Vector2(120, 0)
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_container.add_child(type_label)

	# Available quantity label
	var available_label = Label.new()
	available_label.text = "x%d" % group_data.quantity
	available_label.custom_minimum_size = Vector2(40, 0)
	available_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	available_label.add_theme_color_override("font_color", Color.WHITE)
	row_container.add_child(available_label)

	# Quantity selector (SpinBox)
	var quantity_selector = SpinBox.new()
	quantity_selector.name = "QuantitySelector_%s" % debris_type
	quantity_selector.min_value = 0
	quantity_selector.max_value = group_data.quantity
	quantity_selector.step = 1
	quantity_selector.value = 0
	quantity_selector.custom_minimum_size = Vector2(80, 0)
	quantity_selector.value_changed.connect(_on_debris_quantity_changed.bind(debris_type))
	row_container.add_child(quantity_selector)

	# Individual value label
	var individual_value_label = Label.new()
	individual_value_label.text = "%d ea" % group_data.individual_value
	individual_value_label.custom_minimum_size = Vector2(50, 0)
	individual_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	individual_value_label.add_theme_color_override("font_color", Color.GRAY)
	row_container.add_child(individual_value_label)

	# Selected value label (will update based on quantity)
	var selected_value_label = Label.new()
	selected_value_label.name = "SelectedValue_%s" % debris_type
	selected_value_label.text = "0 credits"
	selected_value_label.custom_minimum_size = Vector2(80, 0)
	selected_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_value_label.add_theme_color_override("font_color", Color.YELLOW)
	row_container.add_child(selected_value_label)

	# Max button for quick selection
	var max_button = Button.new()
	max_button.text = "MAX"
	max_button.custom_minimum_size = Vector2(50, 0)
	max_button.pressed.connect(_on_select_max_debris.bind(debris_type, group_data.quantity))
	row_container.add_child(max_button)

	return row_container

func _on_debris_quantity_changed(debris_type: String, new_quantity: float) -> void:
	##Handle debris quantity selection change
	var quantity = int(new_quantity)
	selected_debris[debris_type] = quantity

	_log_message("ZoneMain3D: Selected %d %s for sale" % [quantity, debris_type])

	# Update the selected value display for this debris type
	_update_debris_row_value(debris_type)

	# Update overall selection summary
	_update_selection_summary()

func _on_select_max_debris(debris_type: String, max_quantity: int) -> void:
	##Handle max button press - select all available quantity
	selected_debris[debris_type] = max_quantity

	# Update the quantity selector
	var quantity_selector = debris_selection_list.get_node_or_null("Row_%s/QuantitySelector_%s" % [debris_type, debris_type])
	if quantity_selector:
		quantity_selector.value = max_quantity

	_log_message("ZoneMain3D: Selected maximum %d %s for sale" % [max_quantity, debris_type])

	# Update displays
	_update_debris_row_value(debris_type)
	_update_selection_summary()

func _update_debris_row_value(debris_type: String) -> void:
	##Update the selected value display for a specific debris row
	var selected_quantity = selected_debris.get(debris_type, 0)
	var selected_value_label = debris_selection_list.get_node_or_null("Row_%s/SelectedValue_%s" % [debris_type, debris_type])

	if selected_value_label and player_ship:
		# Calculate value based on selected quantity
		var individual_value = 0
		for item in player_ship.current_inventory:
			if item.get("type") == debris_type:
				individual_value = item.get("value", 0)
				break

		var total_selected_value = selected_quantity * individual_value
		selected_value_label.text = "%d credits" % total_selected_value

		# Color coding
		if selected_quantity > 0:
			selected_value_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			selected_value_label.add_theme_color_override("font_color", Color.GRAY)

func _update_selection_summary() -> void:
	##Update the selection summary display
	if not selection_summary_label:
		return

	var total_selected_items = 0
	var total_selected_value = 0

	# Calculate totals
	for debris_type in selected_debris:
		var quantity = selected_debris[debris_type]
		if quantity > 0:
			total_selected_items += quantity

			# Find individual value
			if player_ship:
				for item in player_ship.current_inventory:
					if item.get("type") == debris_type:
						total_selected_value += quantity * item.get("value", 0)
						break

	# Update summary text
	if total_selected_items > 0:
		selection_summary_label.text = "Selected: %d items worth %d credits" % [total_selected_items, total_selected_value]
		selection_summary_label.add_theme_color_override("font_color", Color.CYAN)

		# Enable sell selected button
		if sell_selected_button:
			sell_selected_button.disabled = false
	else:
		selection_summary_label.text = "No items selected"
		selection_summary_label.add_theme_color_override("font_color", Color.GRAY)

		# Disable sell selected button
		if sell_selected_button:
			sell_selected_button.disabled = true

	_log_message("ZoneMain3D: Selection summary updated - %d items, %d credits" % [total_selected_items, total_selected_value])
