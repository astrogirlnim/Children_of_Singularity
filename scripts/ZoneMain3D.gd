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
@onready var screen_space_border: Control = $UILayer/ScreenSpaceBorder
@onready var debug_label: Label = $UILayer/HUD/DebugLabel
@onready var log_label: Label = $UILayer/HUD/LogLabel
@onready var inventory_status: Label = $UILayer/HUD/InventoryPanel/InventoryStatus
@onready var inventory_grid: GridContainer = $UILayer/HUD/InventoryPanel/InventoryGrid
@onready var credits_label: Label = $UILayer/HUD/StatsPanel/CreditsLabel
@onready var debris_count_label: Label = $UILayer/HUD/StatsPanel/DebrisCountLabel
@onready var upgrade_status_text: Label = $UILayer/HUD/UpgradeStatusPanel/UpgradeStatusText
@onready var api_client: Node = $APIClient
@onready var upgrade_system: Node = $UpgradeSystem
@onready var ai_communicator: Node = $AICommunicator
@onready var network_manager: Node = $NetworkManager

# Trading interface UI elements
@onready var trading_interface: Panel = $UILayer/HUD/TradingInterface
@onready var trading_title: Label = $UILayer/HUD/TradingInterface/TradingTitle
@onready var trading_tabs: TabContainer = $UILayer/HUD/TradingInterface/TradingTabs
@onready var trading_content: VBoxContainer = $UILayer/HUD/TradingInterface/TradingTabs/SELL/TradingContent
@onready var trading_result: Label = $UILayer/HUD/TradingInterface/TradingTabs/SELL/TradingContent/TradingResult
@onready var sell_all_button: Button = $UILayer/HUD/TradingInterface/TradingTabs/SELL/TradingContent/SellAllButton
@onready var dump_inventory_button: Button = $UILayer/HUD/TradingInterface/TradingTabs/SELL/TradingContent/DumpInventoryButton
@onready var clear_upgrades_button: Button = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/ClearUpgradesContainer/ClearUpgradesButton
@onready var trading_close_button: Button = $UILayer/HUD/TradingInterface/TradingCloseButton

# Upgrade interface UI elements
@onready var upgrade_content: VBoxContainer = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent
@onready var upgrade_catalog: ScrollContainer = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeCatalog
@onready var upgrade_grid: GridContainer = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeCatalog/CenterContainer/UpgradeGrid
@onready var upgrade_details: Panel = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeDetails
@onready var upgrade_details_label: Label = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeDetails/UpgradeDetailsLabel
@onready var purchase_button: Button = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/PurchaseControls/PurchaseButton
@onready var purchase_result: Label = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/PurchaseResult

# Confirmation dialog elements
@onready var confirm_purchase_dialog: AcceptDialog = $UILayer/HUD/ConfirmPurchaseDialog
@onready var confirm_upgrade_name: Label = $UILayer/HUD/ConfirmPurchaseDialog/ConfirmDialogContent/UpgradeNameLabel
@onready var confirm_upgrade_info: Label = $UILayer/HUD/ConfirmPurchaseDialog/ConfirmDialogContent/UpgradeInfoLabel
@onready var confirm_cost_label: Label = $UILayer/HUD/ConfirmPurchaseDialog/ConfirmDialogContent/CostLabel
@onready var confirm_button: Button = $UILayer/HUD/ConfirmPurchaseDialog/ConfirmDialogContent/ConfirmButtons/ConfirmButton
@onready var cancel_button: Button = $UILayer/HUD/ConfirmPurchaseDialog/ConfirmDialogContent/ConfirmButtons/CancelButton

# Selective trading UI elements (will be created dynamically)
var debris_selection_container: ScrollContainer
var debris_selection_list: VBoxContainer
var selection_summary_label: Label
var sell_selected_button: Button
var selected_debris: Dictionary = {}  # Store selected quantities per debris type

# Upgrade system UI state
var current_selected_upgrade: String = ""
var current_upgrade_cost: int = 0
var upgrade_buttons: Dictionary = {}  # Store upgrade button references

# Loading screen management for lobby transitions
var loading_screen_scene: PackedScene
var loading_screen_instance: LoadingScreen
var is_transitioning_to_lobby: bool = false

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
	print("ZoneMain3D._ready() CALLED - Scene is initializing!")
	print("ZoneMain3D: Current scene tree node count: ", get_tree().get_node_count())
	print("ZoneMain3D: Starting initialization...")

	_log_message("ZoneMain3D: Initializing 3D zone controller")
	_initialize_3d_zone()
	_update_debug_display()

	# Preload loading screen for lobby transitions
	_preload_loading_screen_for_lobby()

	_log_message("ZoneMain3D: 3D Zone ready for gameplay")
	zone_ready.emit()

	print("ZoneMain3D._ready() COMPLETED - Scene fully initialized!")

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

		# Connect upgrade effect signals for immediate UI updates
		if player_ship.has_signal("inventory_expanded"):
			player_ship.inventory_expanded.connect(_on_inventory_expanded)

		_log_message("ZoneMain3D: Player ship signals connected")

	# Connect API client signals
	if api_client:
		if api_client.has_signal("upgrade_purchased"):
			api_client.upgrade_purchased.connect(_on_upgrade_purchased)
		if api_client.has_signal("upgrade_purchase_failed"):
			api_client.upgrade_purchase_failed.connect(_on_upgrade_purchase_failed)
		if api_client.has_signal("credits_updated"):
			api_client.credits_updated.connect(_on_credits_updated)
		if api_client.has_signal("upgrades_cleared"):
			api_client.upgrades_cleared.connect(_on_upgrades_cleared)
		# NEW: Connect data loading signals for backend persistence
		if api_client.has_signal("player_data_loaded"):
			api_client.player_data_loaded.connect(_on_player_data_loaded)
		if api_client.has_signal("inventory_updated"):
			api_client.inventory_updated.connect(_on_inventory_loaded)
		_log_message("ZoneMain3D: API client signals connected")

	# Connect upgrade system signals for immediate effect feedback
	if upgrade_system:
		if upgrade_system.has_signal("upgrade_effects_applied"):
			upgrade_system.upgrade_effects_applied.connect(_on_upgrade_effects_applied)
		_log_message("ZoneMain3D: Upgrade system signals connected")

	# Initialize trading interface UI connections
	_initialize_trading_interface()

	# FIXED: Only load from backend if we're not in local mode and local data isn't already loaded
	if api_client and player_ship:
		_load_player_data_smartly()

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

		# Clean up stuck loading screens with F12 key
		elif event.keycode == KEY_F12:
			_cleanup_stuck_loading_screens()
			_log_message("ZoneMain3D: Manually cleaned up stuck loading screens (F12)")

func _cleanup_stuck_loading_screens() -> void:
	##Remove any stuck LoadingScreen instances from the scene tree
	_log_message("ZoneMain3D: Searching for stuck loading screens...")

	# Manually search and remove any LoadingScreen nodes
	var tree = get_tree()
	if tree and tree.current_scene:
		var all_nodes = tree.current_scene.find_children("*", "LoadingScreen", true, false)
		for node in all_nodes:
			if node and is_instance_valid(node):
				_log_message("ZoneMain3D: Removing stuck LoadingScreen node: %s" % node.name)
				node.queue_free()

		# Also check for any Control nodes that might be loading screens
		var control_nodes = tree.current_scene.find_children("*", "Control", true, false)
		for node in control_nodes:
			if node and is_instance_valid(node) and node.name.to_lower().contains("loading"):
				_log_message("ZoneMain3D: Removing potential stuck loading node: %s" % node.name)
				node.queue_free()

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
	_log_message("ZoneMain3D: Player entered space station module - %s - opening trading interface" % module_type)
	open_trading_interface(module_type)

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
	_log_message("ZoneMain3D: Player entered trading hub: %s - opening trading interface" % hub_type)

	# Play trading hub approach sound effect
	# if AudioManager:
	#	AudioManager.play_sfx("approach_station")
	#	_log_message("ZoneMain3D: Played trading hub approach sound effect")

	# Open the trading interface (redirects to 2D lobby)
	open_trading_interface(hub_type)

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

func _on_boundary_collision(collision_pos: Vector3, boundary_type: String) -> void:
	##Handle boundary collision when player hits zone wall
	_log_message("ZoneMain3D: BOUNDARY COLLISION - Player hit %s at position %s" % [boundary_type, collision_pos])

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

func is_position_in_bounds(check_pos: Vector3) -> bool:
	##Check if a position is within zone boundaries
	if zone_boundary_manager:
		return zone_boundary_manager.is_position_in_bounds(check_pos)
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

	if dump_inventory_button:
		dump_inventory_button.pressed.connect(_on_dump_inventory_pressed)
		_log_message("ZoneMain3D: Dump inventory button connected")

	if clear_upgrades_button:
		clear_upgrades_button.pressed.connect(_on_clear_upgrades_pressed)
		_log_message("ZoneMain3D: Clear upgrades button connected")

	# Connect close button
	if trading_close_button:
		trading_close_button.pressed.connect(_on_trading_close_pressed)
		_log_message("ZoneMain3D: Trading close button connected")

	# Initialize upgrade interface
	_initialize_upgrade_interface()

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
	##Redirect to 2D lobby instead of opening trading interface overlay
	_log_message("ZoneMain3D: Player pressed F at %s hub - redirecting to 2D lobby" % hub_type)

	# CRITICAL FIX: Sync complete player ship state to LocalPlayerData before scene transition
	if LocalPlayerData and player_ship:
		_log_message("ZoneMain3D: === SYNCING COMPLETE PLAYER STATE TO LOCAL DATA ===")

		# Sync current inventory from player ship - FIXED: Convert structure properly
		_log_message("ZoneMain3D: Syncing inventory - %d items from PlayerShip3D" % player_ship.current_inventory.size())

		# Clear existing inventory and re-add items with proper structure
		LocalPlayerData.player_inventory.clear()
		for item in player_ship.current_inventory:
			# Convert 3D inventory structure to LocalPlayerData structure
			var converted_item = {
				"type": item.get("type", "unknown"),
				"item_id": item.get("id", ""),  # Convert "id" → "item_id"
				"quantity": 1,  # 3D items are individual, so quantity is always 1
				"value": item.get("value", 0),
				"acquired_at": Time.get_datetime_string_from_system()
			}
			LocalPlayerData.player_inventory.append(converted_item)

		LocalPlayerData.save_inventory()
		_log_message("ZoneMain3D: Inventory converted and synced to LocalPlayerData - %d items" % LocalPlayerData.player_inventory.size())

		# Sync current credits from player ship
		_log_message("ZoneMain3D: Syncing credits - %d from PlayerShip3D" % player_ship.credits)
		LocalPlayerData.set_credits(player_ship.credits)
		_log_message("ZoneMain3D: Credits synced to LocalPlayerData - %d" % LocalPlayerData.get_credits())

		# Sync current upgrades from player ship
		_log_message("ZoneMain3D: Syncing upgrades - %s from PlayerShip3D" % player_ship.upgrades)
		LocalPlayerData.player_upgrades = player_ship.upgrades.duplicate()
		LocalPlayerData.save_upgrades()
		_log_message("ZoneMain3D: Upgrades synced to LocalPlayerData - %s" % LocalPlayerData.player_upgrades)

		# Save all player data
		LocalPlayerData.save_player_data()
		_log_message("ZoneMain3D: === PLAYER STATE SYNC COMPLETE ===")

	elif not LocalPlayerData:
		_log_message("ZoneMain3D: ERROR - LocalPlayerData not available for sync!")
	elif not player_ship:
		_log_message("ZoneMain3D: ERROR - PlayerShip3D not available for sync!")

	# Store hub type for lobby context (optional)
	if LocalPlayerData:
		LocalPlayerData.set_setting("last_interacted_hub_type", hub_type)
		_log_message("ZoneMain3D: Stored hub type for lobby context: %s" % hub_type)

	# Show loading screen and transition to 2D lobby scene
	_show_loading_screen_for_lobby_entry()

func close_trading_interface() -> void:
	##Close the trading interface
	_log_message("ZoneMain3D: Closing trading interface")

	if trading_interface:
		trading_interface.visible = false

	# Unlock player ship movement when trading interface is closed
	if player_ship and player_ship.has_method("unlock_movement"):
		player_ship.unlock_movement()
		_log_message("ZoneMain3D: Player ship movement unlocked")

	_log_message("ZoneMain3D: Trading interface closed")

func _preload_loading_screen_for_lobby() -> void:
	##Preload the loading screen for smooth lobby entry transitions
	_log_message("ZoneMain3D: Preloading loading screen for lobby entry")
	loading_screen_scene = preload("res://scenes/ui/LoadingScreen.tscn")
	if loading_screen_scene:
		_log_message("ZoneMain3D: ✅ Loading screen preloaded successfully")
	else:
		_log_message("ZoneMain3D: ⚠️ Failed to preload loading screen")

func _show_loading_screen_for_lobby_entry() -> void:
	##Show loading screen and transition to 2D lobby
	if is_transitioning_to_lobby:
		_log_message("ZoneMain3D: Already transitioning to lobby, ignoring additional request")
		return

	_log_message("ZoneMain3D: Starting transition to 2D lobby with loading screen")
	is_transitioning_to_lobby = true

	# Hide 3D HUD immediately to prevent overlay with loading screen
	_hide_3d_ui_for_loading()

	# Create loading screen instance if not already created
	if not loading_screen_scene:
		loading_screen_scene = preload("res://scenes/ui/LoadingScreen.tscn")

	if loading_screen_scene:
		loading_screen_instance = loading_screen_scene.instantiate() as LoadingScreen
		if loading_screen_instance:
			_log_message("ZoneMain3D: ✅ Loading screen instantiated successfully")

			# Add loading screen to scene tree (above everything else)
			get_tree().root.add_child(loading_screen_instance)

			# Set lobby scene as target and start loading process
			loading_screen_instance.set_target_scene("res://scenes/zones/LobbyZone2D.tscn")
			loading_screen_instance.start_loading()

			_log_message("ZoneMain3D: Loading screen started - transitioning to lobby")
		else:
			_log_message("ZoneMain3D: ERROR - Failed to instantiate loading screen, falling back to direct scene change")
			_fallback_to_direct_lobby_change()
	else:
		_log_message("ZoneMain3D: ERROR - Loading screen scene not available, falling back to direct scene change")
		_fallback_to_direct_lobby_change()

func _hide_3d_ui_for_loading() -> void:
	##Hide all 3D UI elements immediately when loading screen appears
	_log_message("ZoneMain3D: Hiding UI elements for loading screen transition")

	# Hide main HUD that would overlay with loading screen
	if hud:
		hud.visible = false
		_log_message("ZoneMain3D: ✅ HUD hidden for loading screen")

	# Hide screen space border that would overlay with loading screen
	if screen_space_border:
		screen_space_border.visible = false
		_log_message("ZoneMain3D: ✅ Screen space border hidden for loading screen")

	# Hide trading interface if it was open (though it shouldn't be at this point)
	if trading_interface and trading_interface.visible:
		trading_interface.visible = false
		_log_message("ZoneMain3D: ✅ Trading interface hidden for loading screen")

func _fallback_to_direct_lobby_change() -> void:
	##Fallback to direct scene change if loading screen fails
	_log_message("ZoneMain3D: Using fallback direct scene change method")
	get_tree().change_scene_to_file("res://scenes/zones/LobbyZone2D.tscn")

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

	# Clear selections since inventory is now empty
	selected_debris.clear()

	# Update UI immediately
	_update_inventory_displays()
	_update_credits_display()

	# Refresh the trading interface to show updated inventory
	_populate_debris_selection_ui()
	_update_selection_summary()

	# CRITICAL FIX: Refresh upgrade catalog after credit update (Phase 3B real-time update)
	if trading_interface and trading_interface.visible:
		_populate_upgrade_catalog()
		_log_message("ZoneMain3D: Upgrade catalog refreshed after selling items")

	# Show success message
	var success_message = "SUCCESS!\nSold %d items for %d credits\nTotal Credits: %d" % [item_count, total_value, player_ship.credits]
	_update_trading_result(success_message, Color.GREEN)

	# Sync with backend API
	_sync_sale_with_backend(sold_items, total_value)

	_log_message("ZoneMain3D: Sale completed - %d items sold for %d credits" % [item_count, total_value])

func _on_dump_inventory_pressed() -> void:
	##Handle dump inventory button press - clear all inventory without selling
	_log_message("ZoneMain3D: Dump inventory button pressed")

	if not player_ship:
		_log_message("ZoneMain3D: ERROR - Player ship not found!")
		return

	var inventory = player_ship.current_inventory
	if inventory.is_empty():
		_update_trading_result("No inventory to dump!", Color.YELLOW)
		_log_message("ZoneMain3D: No inventory to dump")
		return

	# Show confirmation dialog
	var confirmation_text = "Are you sure you want to DUMP ALL inventory?\n\nThis will permanently delete all %d items.\nYou will NOT receive any credits!\n\nThis action cannot be undone." % inventory.size()

	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Confirm Dump Inventory"
	dialog.dialog_text = confirmation_text
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS

	# Add to scene temporarily
	add_child(dialog)

	# Connect signals
	dialog.confirmed.connect(_on_dump_inventory_confirmed.bind(dialog))
	dialog.canceled.connect(_on_dump_inventory_canceled.bind(dialog))

	# Show dialog
	dialog.popup_centered(Vector2i(500, 300))
	_log_message("ZoneMain3D: Dump inventory confirmation dialog shown")

func _on_dump_inventory_confirmed(dialog: ConfirmationDialog) -> void:
	##Handle confirmed dump inventory action
	_log_message("ZoneMain3D: Dump inventory confirmed by user")

	if not player_ship:
		_log_message("ZoneMain3D: ERROR - Player ship not found!")
		dialog.queue_free()
		return

	var inventory = player_ship.current_inventory
	var item_count = inventory.size()

	# Clear inventory locally (no credits gained)
	var _dumped_items = player_ship.clear_inventory()

	# Clear inventory on backend
	if api_client and api_client.has_method("clear_inventory"):
		api_client.clear_inventory()
		_log_message("ZoneMain3D: Inventory cleared on backend")

	# Clear selections
	selected_debris.clear()

	# Update UI immediately
	_update_trading_result("DUMPED %d items - No credits gained" % item_count, Color.RED)
	_update_grouped_inventory_display(player_ship.current_inventory)
	_update_inventory_displays()

	# CRITICAL FIX: Refresh the trading interface to show updated inventory
	_populate_debris_selection_ui()
	_update_selection_summary()

	_log_message("ZoneMain3D: Dumped %d items, no credits gained, trading interface refreshed" % item_count)

	# Clean up dialog
	dialog.queue_free()

func _on_dump_inventory_canceled(dialog: ConfirmationDialog) -> void:
	##Handle canceled dump inventory action
	_log_message("ZoneMain3D: Dump inventory canceled by user")
	dialog.queue_free()

func _on_clear_upgrades_pressed() -> void:
	##Handle clear upgrades button press - reset all upgrades to defaults
	_log_message("ZoneMain3D: Clear upgrades button pressed")

	if not player_ship:
		_log_message("ZoneMain3D: ERROR - Player ship not found!")
		return

	# Show confirmation dialog
	var confirmation_text = "Are you sure you want to CLEAR ALL upgrades?\n\nThis will reset all upgrades to default levels:\n• Speed Boost: Level 0\n• Inventory Expansion: Level 0\n• Collection Efficiency: Level 0\n• Zone Access: Level 1 (minimum)\n• Debris Scanner: Level 0\n• Cargo Magnet: Level 0\n\nYou will NOT receive any credit refunds!\nThis action cannot be undone."

	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Confirm Clear All Upgrades"
	dialog.dialog_text = confirmation_text
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS

	# Add to scene temporarily
	add_child(dialog)

	# Connect signals
	dialog.confirmed.connect(_on_clear_upgrades_confirmed.bind(dialog))
	dialog.canceled.connect(_on_clear_upgrades_canceled.bind(dialog))

	# Show dialog
	dialog.popup_centered(Vector2i(600, 400))
	_log_message("ZoneMain3D: Clear upgrades confirmation dialog shown")

func _on_clear_upgrades_confirmed(dialog: ConfirmationDialog) -> void:
	##Handle confirmed clear upgrades action
	_log_message("ZoneMain3D: Clear upgrades confirmed by user")

	if not player_ship:
		_log_message("ZoneMain3D: ERROR - Player ship not found!")
		dialog.queue_free()
		return

	# Clear upgrades on backend first
	if api_client and api_client.has_method("clear_upgrades"):
		api_client.clear_upgrades()
		_log_message("ZoneMain3D: Upgrades clear request sent to backend")
	else:
		_log_message("ZoneMain3D: ERROR - API client does not support clear_upgrades")

	# Clean up dialog
	dialog.queue_free()

func _on_clear_upgrades_canceled(dialog: ConfirmationDialog) -> void:
	##Handle canceled clear upgrades action
	_log_message("ZoneMain3D: Clear upgrades canceled by user")
	dialog.queue_free()

func _on_upgrades_cleared(cleared_data: Dictionary) -> void:
	##Handle upgrades cleared response from API
	_log_message("ZoneMain3D: Upgrades cleared successfully - %s" % cleared_data)

	if not player_ship:
		_log_message("ZoneMain3D: ERROR - Player ship not found!")
		return

	# Reset player ship upgrades to defaults locally
	player_ship.upgrades = {
		"speed_boost": 0,
		"inventory_expansion": 0,
		"collection_efficiency": 0,
		"cargo_magnet": 0
	}

	# Apply default upgrade effects
	for upgrade_type in player_ship.upgrades:
		var level = player_ship.upgrades[upgrade_type]
		player_ship._apply_upgrade_effects(upgrade_type, level)

	# Update UI immediately
	_update_purchase_result("ALL UPGRADES CLEARED", Color.RED)
	_populate_upgrade_catalog()  # Refresh catalog to show Level 0
	_update_upgrade_status_display()
	_update_inventory_displays()  # Inventory capacity may have changed

	# CRITICAL FIX: Also refresh trading interface if open (inventory capacity may have changed)
	if trading_interface and trading_interface.visible:
		_populate_debris_selection_ui()
		_update_selection_summary()

	var total_cleared = cleared_data.get("total_cleared", 0)
	_log_message("ZoneMain3D: All upgrades reset to defaults - %d upgrades cleared, trading interface refreshed" % total_cleared)

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

func _sync_sale_with_backend(_sold_items: Array, total_value: int) -> void:
	##Sync the sale transaction with the backend API
	if not api_client:
		_log_message("ZoneMain3D: Warning - No API client available for backend sync")
		return

	# Sync credits to backend using the existing update_credits method
	if api_client.has_method("update_credits"):
		api_client.update_credits(total_value)  # Add the credits earned from sale
		_log_message("ZoneMain3D: Credits synced with backend API - Added %d credits" % total_value)
	else:
		_log_message("ZoneMain3D: Warning - Backend API does not support credit updates")

	# CRITICAL FIX: Clear sold items from backend inventory
	if api_client.has_method("clear_inventory"):
		api_client.clear_inventory()
		_log_message("ZoneMain3D: FIXED - Cleared backend inventory to remove sold items")
	else:
		_log_message("ZoneMain3D: Warning - Backend API does not support inventory clearing")

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

func _update_upgrade_status_display() -> void:
	##Update the upgrade status display in the UpgradeStatusPanel
	if not upgrade_status_text or not player_ship or not upgrade_system:
		return

	var status_text = ""
	var upgrade_count = 0

	if player_ship.upgrades.size() > 0:
		for upgrade_type in player_ship.upgrades:
			var level = player_ship.upgrades[upgrade_type]
			if level > 0:
				var upgrade_info = upgrade_system.get_upgrade_info(upgrade_type)
				var upgrade_name = upgrade_info.get("name", upgrade_type)
				status_text += "%s: L%d\n" % [upgrade_name, level]
				upgrade_count += 1

	if upgrade_count == 0:
		upgrade_status_text.text = "No upgrades purchased"
		upgrade_status_text.modulate = Color.GRAY
	else:
		upgrade_status_text.text = status_text
		upgrade_status_text.modulate = Color.WHITE

	_log_message("ZoneMain3D: Upgrade status display updated - %d upgrades shown" % upgrade_count)

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

	# CRITICAL FIX: Refresh upgrade catalog after credit update (Phase 3B real-time update)
	if trading_interface and trading_interface.visible:
		_populate_upgrade_catalog()
		_log_message("ZoneMain3D: Upgrade catalog refreshed after selling selected items")

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

## Upgrade Interface Methods

func _initialize_upgrade_interface() -> void:
	##Initialize upgrade interface UI connections and functionality
	_log_message("ZoneMain3D: Initializing upgrade interface")

	# Connect confirmation dialog buttons
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_purchase_pressed)
		_log_message("ZoneMain3D: Confirm purchase button connected")

	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_purchase_pressed)
		_log_message("ZoneMain3D: Cancel purchase button connected")

	# Connect main purchase button
	if purchase_button:
		purchase_button.pressed.connect(_on_purchase_button_pressed)
		_log_message("ZoneMain3D: Main purchase button connected")

	# Initially disable purchase button
	if purchase_button:
		purchase_button.disabled = true

	_log_message("ZoneMain3D: Upgrade interface initialized")

func _populate_upgrade_catalog() -> void:
	##Populate the upgrade catalog with available upgrades
	if not upgrade_grid or not upgrade_system or not player_ship:
		_log_message("ZoneMain3D: ERROR - Missing components for upgrade catalog")
		return

	# Clear existing upgrade buttons
	for child in upgrade_grid.get_children():
		child.queue_free()
	upgrade_buttons.clear()

	_log_message("ZoneMain3D: Populating upgrade catalog")

	# Get all upgrade definitions from UpgradeSystem
	var upgrade_definitions = upgrade_system.upgrade_definitions
	var player_credits = player_ship.credits

	for upgrade_type in upgrade_definitions:
		var upgrade_data = upgrade_definitions[upgrade_type]
		var current_level = player_ship.upgrades.get(upgrade_type, 0)
		var max_level = upgrade_data.max_level

		# Create upgrade button for this type
		var upgrade_button = _create_upgrade_button(upgrade_type, upgrade_data, current_level, max_level, player_credits)
		upgrade_grid.add_child(upgrade_button)
		upgrade_buttons[upgrade_type] = upgrade_button

	_log_message("ZoneMain3D: Created %d upgrade buttons" % upgrade_buttons.size())

func _create_upgrade_button(upgrade_type: String, upgrade_data: Dictionary, current_level: int, max_level: int, player_credits: int) -> Control:
	##Create a button for a specific upgrade
	var upgrade_container = VBoxContainer.new()
	upgrade_container.name = "Upgrade_%s" % upgrade_type

	# Main upgrade button
	var button = Button.new()
	button.custom_minimum_size = Vector2(0, 80)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Calculate cost and availability
	var cost = upgrade_system.calculate_upgrade_cost(upgrade_type, current_level)
	var can_afford = player_credits >= cost
	var is_maxed = current_level >= max_level

	# Set button text and styling
	var button_text = ""
	var button_color = Color.WHITE

	if is_maxed:
		button_text = "%s\nLevel %d/%d - MAXED OUT\nEffect: %s" % [
			upgrade_data.name,
			current_level,
			max_level,
			upgrade_data.description
		]
		button_color = Color.GOLD
		button.disabled = true
	else:
		button_text = "%s\nLevel %d/%d - Cost: %d credits\nEffect: %s" % [
			upgrade_data.name,
			current_level,
			max_level,
			cost,
			upgrade_data.description
		]
		if can_afford:
			button_color = Color.GREEN
			button.disabled = false
		else:
			button_color = Color.RED
			button.disabled = false  # Allow selection to show details

	button.text = button_text
	button.modulate = button_color

	# Connect button press to selection handler
	button.pressed.connect(_on_upgrade_selected.bind(upgrade_type, upgrade_data, current_level, cost, can_afford, is_maxed))

	upgrade_container.add_child(button)

	# Add separator
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 5)
	upgrade_container.add_child(separator)

	return upgrade_container

func _on_upgrade_selected(upgrade_type: String, upgrade_data: Dictionary, current_level: int, cost: int, can_afford: bool, is_maxed: bool) -> void:
	##Handle upgrade selection
	_log_message("ZoneMain3D: Upgrade selected: %s (level %d, cost %d)" % [upgrade_type, current_level, cost])

	current_selected_upgrade = upgrade_type
	current_upgrade_cost = cost

	# Update upgrade details panel
	if upgrade_details_label:
		var details_text = ""
		if is_maxed:
			details_text = "UPGRADE MAXED OUT\n\n%s\nCurrent Level: %d/%d\n\nThis upgrade has reached its maximum level." % [
				upgrade_data.description,
				current_level,
				upgrade_data.max_level
			]
		else:
			var next_level = current_level + 1
			var effect_per_level = upgrade_data.effect_per_level
			details_text = "%s\n\nCurrent Level: %d/%d\nNext Level: %d\nCost: %d credits\nEffect per level: %s\nCategory: %s" % [
				upgrade_data.description,
				current_level,
				upgrade_data.max_level,
				next_level,
				cost,
				str(effect_per_level),
				upgrade_data.category
			]

		upgrade_details_label.text = details_text

	# Update purchase button
	if purchase_button:
		if is_maxed:
			purchase_button.text = "UPGRADE MAXED OUT"
			purchase_button.disabled = true
		elif can_afford:
			purchase_button.text = "PURCHASE UPGRADE (%d credits)" % cost
			purchase_button.disabled = false
		else:
			purchase_button.text = "INSUFFICIENT CREDITS (%d credits)" % cost
			purchase_button.disabled = true

	# Clear any previous purchase result
	if purchase_result:
		purchase_result.text = ""

func _on_purchase_button_pressed() -> void:
	##Handle purchase button press - show confirmation dialog
	if current_selected_upgrade.is_empty():
		_log_message("ZoneMain3D: No upgrade selected for purchase")
		return

	_log_message("ZoneMain3D: Purchase button pressed for %s" % current_selected_upgrade)

	# Get upgrade data
	var upgrade_data = upgrade_system.upgrade_definitions.get(current_selected_upgrade, {})
	if upgrade_data.is_empty():
		_log_message("ZoneMain3D: ERROR - Invalid upgrade data for %s" % current_selected_upgrade)
		return

	# Update confirmation dialog
	if confirm_upgrade_name:
		confirm_upgrade_name.text = upgrade_data.name

	if confirm_upgrade_info:
		confirm_upgrade_info.text = upgrade_data.description

	if confirm_cost_label:
		confirm_cost_label.text = "Cost: %d credits" % current_upgrade_cost

	# Show confirmation dialog
	if confirm_purchase_dialog:
		confirm_purchase_dialog.popup_centered()

func _on_confirm_purchase_pressed() -> void:
	##Handle confirmed purchase
	_log_message("ZoneMain3D: Purchase confirmed by user")

	# Perform the purchase using the shared method
	_perform_upgrade_purchase()

	# Close confirmation dialog
	if confirm_purchase_dialog:
		confirm_purchase_dialog.hide()

func _on_cancel_purchase_pressed() -> void:
	##Handle cancelled purchase
	_log_message("ZoneMain3D: Purchase cancelled")

	# Close confirmation dialog
	if confirm_purchase_dialog:
		confirm_purchase_dialog.hide()

func _on_upgrade_purchased(result: Dictionary) -> void:
	##Handle successful upgrade purchase from API
	_log_message("ZoneMain3D: Upgrade purchase successful: %s" % result)

	var upgrade_type = result.get("upgrade_type", "")
	var new_level = result.get("new_level", 0)
	var cost = result.get("cost", 0)
	var remaining_credits = result.get("remaining_credits", 0)

	# Update player data
	if player_ship:
		player_ship.upgrades[upgrade_type] = new_level
		player_ship.credits = remaining_credits  # Use remaining credits from API response

		# Apply upgrade effects immediately
		if upgrade_system:
			upgrade_system.apply_upgrade_effects(upgrade_type, new_level, player_ship)

		_log_message("ZoneMain3D: Applied %s level %d effects to player, credits now: %d" % [upgrade_type, new_level, remaining_credits])

	# Update UI immediately
	_update_credits_display()
	_populate_upgrade_catalog()  # Refresh catalog with new levels
	_update_purchase_result("SUCCESS!\nPurchased %s level %d for %d credits" % [upgrade_type, new_level, cost], Color.GREEN)

	# Update the upgrade status panel to show purchased upgrades
	_update_upgrade_status_display()

	# Clear selection to reset the interface
	current_selected_upgrade = ""
	current_upgrade_cost = 0

	# Clear upgrade details panel to show updated state
	if upgrade_details_label:
		upgrade_details_label.text = "Select an upgrade above to see details"

	# Reset purchase button
	if purchase_button:
		purchase_button.text = "PURCHASE UPGRADE"
		purchase_button.disabled = true

	# Force UI refresh to ensure immediate update
	_log_message("ZoneMain3D: Forcing UI refresh after successful upgrade purchase")

func _on_upgrade_purchase_failed(reason: String, upgrade_type: String) -> void:
	##Handle failed upgrade purchase from API
	_log_message("ZoneMain3D: Upgrade purchase failed: %s - %s" % [upgrade_type, reason])

	# Update UI with error
	_update_purchase_result("PURCHASE FAILED\n%s\nReason: %s" % [upgrade_type, reason], Color.RED)

func _update_purchase_result(message: String, color: Color = Color.WHITE) -> void:
	##Update the purchase result display
	if purchase_result:
		purchase_result.text = message
		purchase_result.modulate = color
		_log_message("ZoneMain3D: Purchase result updated: %s" % message)

func _on_credits_updated(credits: int) -> void:
	##Handle credits update from API client
	_log_message("ZoneMain3D: Credits updated from API: %d" % credits)
	if player_ship:
		player_ship.credits = credits
	_update_credits_display()

	# Real-time upgrade catalog refresh when credits change (Phase 3B requirement)
	if trading_interface and trading_interface.visible:
		_populate_upgrade_catalog()
		_log_message("ZoneMain3D: Upgrade catalog refreshed due to credits change")

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
	quantity_selector.allow_greater = false  # Prevent values above max
	quantity_selector.allow_lesser = false   # Prevent values below min

	# Connect multiple signals with debugging
	quantity_selector.value_changed.connect(_on_debris_quantity_changed.bind(debris_type))
	quantity_selector.get_line_edit().text_submitted.connect(_on_debris_quantity_text_submitted.bind(debris_type))
	quantity_selector.get_line_edit().text_changed.connect(_on_debris_quantity_text_changed.bind(debris_type))
	_log_message("ZoneMain3D: DEBUG - Connected SpinBox signals for %s (min: %d, max: %d)" % [debris_type, quantity_selector.min_value, quantity_selector.max_value])

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

func _on_debris_quantity_changed(new_quantity: float, debris_type: String) -> void:
	##Handle debris quantity selection change
	var quantity = int(new_quantity)

	# Add extensive debugging
	_log_message("ZoneMain3D: DEBUG - _on_debris_quantity_changed called - Type: %s, New Quantity: %f, Int Quantity: %d" % [debris_type, new_quantity, quantity])

	# Store or remove from selected_debris based on quantity
	if quantity > 0:
		selected_debris[debris_type] = quantity
		_log_message("ZoneMain3D: Selected %d %s for sale" % [quantity, debris_type])
	else:
		# Remove from dictionary if quantity is 0 to keep it clean
		if debris_type in selected_debris:
			selected_debris.erase(debris_type)
		_log_message("ZoneMain3D: Deselected %s (quantity 0)" % debris_type)

	# Debug the selected_debris dictionary state
	_log_message("ZoneMain3D: DEBUG - selected_debris dictionary: %s" % selected_debris)

	# Update the selected value display for this debris type
	_update_debris_row_value(debris_type)

	# Update overall selection summary (this will enable/disable sell selected button)
	_update_selection_summary()

func _on_debris_quantity_text_submitted(text: String, debris_type: String) -> void:
	##Handle when user types a number and presses Enter in the SpinBox
	_log_message("ZoneMain3D: DEBUG - Text submitted for %s: '%s'" % [debris_type, text])
	var quantity = int(text)
	_on_debris_quantity_changed(quantity, debris_type)

func _on_debris_quantity_text_changed(text: String, debris_type: String) -> void:
	##Handle when user types in the SpinBox (every character change)
	_log_message("ZoneMain3D: DEBUG - Text changed for %s: '%s'" % [debris_type, text])
	# Only process if the text is a valid number
	if text.is_valid_int():
		var quantity = int(text)
		_on_debris_quantity_changed(quantity, debris_type)

func _on_select_max_debris(debris_type: String, max_quantity: int) -> void:
	##Handle max button press - select all available quantity
	selected_debris[debris_type] = max_quantity

	# Update the quantity selector to reflect the MAX selection
	var quantity_selector = debris_selection_list.get_node_or_null("Row_%s/QuantitySelector_%s" % [debris_type, debris_type])
	if quantity_selector:
		quantity_selector.value = max_quantity

	_log_message("ZoneMain3D: Selected maximum %d %s for sale" % [max_quantity, debris_type])

	# Update displays
	_update_debris_row_value(debris_type)
	_update_selection_summary()

func _get_debris_value(debris_type: String) -> int:
	##Get the individual value for a specific debris type from player inventory
	if not player_ship:
		return 0

	for item in player_ship.current_inventory:
		if item.get("type") == debris_type:
			return item.get("value", 0)

	# If not found in current inventory, use default values
	match debris_type:
		"scrap_metal":
			return 5
		"bio_waste":
			return 8
		"ai_component":
			return 500
		"broken_satellite":
			return 25
		"unknown_artifact":
			return 100
		_:
			return 1  # Default value

func _update_debris_row_value(debris_type: String) -> void:
	##Update the selected value display for a specific debris type
	var selected_quantity = selected_debris.get(debris_type, 0)
	_log_message("ZoneMain3D: DEBUG - _update_debris_row_value - Type: %s, Selected Quantity: %d" % [debris_type, selected_quantity])

	# Safety check: make sure debris_selection_list exists and hasn't been cleared
	if not debris_selection_list or not debris_selection_list.get_child_count() > 0:
		_log_message("ZoneMain3D: DEBUG - Debris selection list not available, skipping value update")
		return

	# Find the selected value label
	var selected_value_label = debris_selection_list.get_node_or_null("Row_%s/SelectedValue_%s" % [debris_type, debris_type])
	if not selected_value_label:
		_log_message("ZoneMain3D: DEBUG - Could not find selected value label for %s (UI may have been refreshed)" % debris_type)
		return

	_log_message("ZoneMain3D: DEBUG - Found selected value label for %s" % debris_type)

	# Get the individual value for this debris type
	var individual_value = _get_debris_value(debris_type)
	_log_message("ZoneMain3D: DEBUG - Found individual value for %s: %d" % [debris_type, individual_value])

	# Calculate and display total value for selected quantity
	var total_value = selected_quantity * individual_value
	_log_message("ZoneMain3D: DEBUG - Calculated total value: %d x %d = %d" % [selected_quantity, individual_value, total_value])

	selected_value_label.text = "%d credits" % total_value
	_log_message("ZoneMain3D: DEBUG - Updated label text to: %s" % selected_value_label.text)

func _update_selection_summary() -> void:
	##Update the selection summary display and button states
	if not selection_summary_label:
		return

	var total_selected_items = 0
	var total_selected_value = 0

	# Calculate totals (only count items with quantity > 0)
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

	# Update summary text and button state
	if total_selected_items > 0:
		selection_summary_label.text = "Selected: %d items worth %d credits" % [total_selected_items, total_selected_value]
		selection_summary_label.add_theme_color_override("font_color", Color.CYAN)

		# Enable sell selected button
		if sell_selected_button:
			sell_selected_button.disabled = false
			_log_message("ZoneMain3D: Sell Selected button ENABLED - %d items selected" % total_selected_items)
	else:
		selection_summary_label.text = "No items selected"
		selection_summary_label.add_theme_color_override("font_color", Color.GRAY)

		# Disable sell selected button
		if sell_selected_button:
			sell_selected_button.disabled = true
			_log_message("ZoneMain3D: Sell Selected button DISABLED - no items selected")

	_log_message("ZoneMain3D: Selection summary updated - %d items, %d credits, button enabled: %s" %
		[total_selected_items, total_selected_value, not sell_selected_button.disabled if sell_selected_button else false])

## Phase 4A: Purchase Processing Integration

func _on_upgrade_purchase_requested(upgrade_type: String) -> void:
	##Handle upgrade purchase request (Phase 4A requirement)
	##Direct entry point for purchasing upgrades with full validation
	_log_message("ZoneMain3D: Upgrade purchase requested for type: %s" % upgrade_type)

	if not upgrade_system or not player_ship:
		_log_message("ZoneMain3D: ERROR - Missing upgrade system or player ship for purchase")
		return

	# Get upgrade data and validate
	var upgrade_definitions = upgrade_system.upgrade_definitions
	var upgrade_data = upgrade_definitions.get(upgrade_type, {})

	if upgrade_data.is_empty():
		_log_message("ZoneMain3D: ERROR - Invalid upgrade type: %s" % upgrade_type)
		return

	# Get current state
	var current_level = player_ship.upgrades.get(upgrade_type, 0)
	var max_level = upgrade_data.max_level
	var player_credits = player_ship.credits
	var cost = upgrade_system.calculate_upgrade_cost(upgrade_type, current_level)

	# Client-side validation
	if current_level >= max_level:
		_log_message("ZoneMain3D: Purchase failed - %s already at max level (%d)" % [upgrade_type, max_level])
		_update_purchase_result("PURCHASE FAILED\n%s is already at maximum level" % upgrade_data.name, Color.RED)
		return

	if player_credits < cost:
		_log_message("ZoneMain3D: Purchase failed - Insufficient credits (need %d, have %d)" % [cost, player_credits])
		_update_purchase_result("PURCHASE FAILED\nInsufficient credits for %s\nNeed: %d, Have: %d" % [upgrade_data.name, cost, player_credits], Color.RED)
		return

	# Set current selection for confirmation dialog
	current_selected_upgrade = upgrade_type
	current_upgrade_cost = cost

	# Show confirmation dialog with upgrade details
	if confirm_upgrade_name:
		confirm_upgrade_name.text = upgrade_data.name

	if confirm_upgrade_info:
		var next_level = current_level + 1
		confirm_upgrade_info.text = "%s\nUpgrade from Level %d to Level %d\nEffect: %s" % [
			upgrade_data.description,
			current_level,
			next_level,
			upgrade_data.description
		]

	if confirm_cost_label:
		confirm_cost_label.text = "Cost: %d credits" % cost

	# Show confirmation dialog
	if confirm_purchase_dialog:
		confirm_purchase_dialog.popup_centered()
		_log_message("ZoneMain3D: Showing purchase confirmation for %s (cost: %d)" % [upgrade_type, cost])
	else:
		# If no confirmation dialog, proceed directly (for automated/programmatic purchases)
		_log_message("ZoneMain3D: No confirmation dialog - proceeding with direct purchase")
		_perform_upgrade_purchase()

func _perform_upgrade_purchase() -> void:
	##Perform the actual upgrade purchase (extracted for reuse)
	if current_selected_upgrade.is_empty():
		_log_message("ZoneMain3D: ERROR - No upgrade selected for purchase")
		return

	_log_message("ZoneMain3D: Performing upgrade purchase: %s for %d credits" % [current_selected_upgrade, current_upgrade_cost])

	# Call APIClient to purchase upgrade (Phase 2A integration)
	if api_client and api_client.has_method("purchase_upgrade"):
		api_client.purchase_upgrade(current_selected_upgrade, current_upgrade_cost, player_ship.player_id)
		_log_message("ZoneMain3D: Purchase request sent to API")
	else:
		_log_message("ZoneMain3D: ERROR - API client does not support upgrade purchases")
		_update_purchase_result("PURCHASE FAILED\nAPI client error", Color.RED)

func _on_inventory_expanded(old_capacity: int, new_capacity: int) -> void:
	##Handle inventory capacity expansion - update UI immediately
	_log_message("ZoneMain3D: Inventory expanded from %d to %d - updating UI" % [old_capacity, new_capacity])

	# Update inventory status display immediately
	if inventory_status and player_ship:
		var current_size = player_ship.current_inventory.size()
		inventory_status.text = "%d/%d Items" % [current_size, new_capacity]

		# Update color coding based on new capacity
		if current_size >= new_capacity:
			inventory_status.modulate = Color.RED
		elif current_size >= new_capacity * 0.8:
			inventory_status.modulate = Color.YELLOW
		else:
			inventory_status.modulate = Color.GREEN  # Green when expansion gives more room

	# Update upgrade status display to reflect new inventory level
	_update_upgrade_status_display()

	# Show visual feedback message
	_update_purchase_result("INVENTORY EXPANDED!\nCapacity increased to %d items" % new_capacity, Color.GREEN)

func _on_upgrade_effects_applied(upgrade_type: String, level: int) -> void:
	##Handle when upgrade effects are applied - update relevant UI panels
	_log_message("ZoneMain3D: Upgrade effects applied: %s level %d - updating UI" % [upgrade_type, level])

	# Update different UI elements based on upgrade type
	match upgrade_type:
		"speed_boost":
			# Show speed boost feedback
			if player_ship:
				var new_speed = player_ship.speed
				if level > 0:
					_update_purchase_result("SPEED BOOST ACTIVE!\nNew speed: %.0f" % new_speed, Color.CYAN)
				else:
					_update_purchase_result("SPEED BOOST DEACTIVATED\nSpeed reset to: %.0f" % new_speed, Color.GRAY)

		"inventory_expansion":
			# Inventory expansion is handled by _on_inventory_expanded signal
			pass

		"collection_efficiency":
			# Update collection range display
			if player_ship:
				var new_range = player_ship.collection_range
				if level > 0:
					_update_purchase_result("COLLECTION ENHANCED!\nNew range: %.1f units" % new_range, Color.BLUE)
				else:
					_update_purchase_result("COLLECTION EFFICIENCY RESET\nRange reset to: %.1f units" % new_range, Color.GRAY)

		"cargo_magnet":
			if level > 0:
				_update_purchase_result("CARGO MAGNET ACTIVE!\nLevel %d auto-collection enabled" % level, Color.ORANGE)
			else:
				_update_purchase_result("CARGO MAGNET DEACTIVATED", Color.GRAY)

	# Always update the upgrade status display
	_update_upgrade_status_display()

	# Update any relevant stats displays
	if player_ship:
		_update_credits_display()  # Credits might have changed
		_update_inventory_displays()  # Inventory status might need updating

func _load_complete_player_data_from_backend() -> void:
	##Load complete player data from backend (Phase 2.1 implementation)
	_log_message("ZoneMain3D: Loading player data from backend...")

	# Set loading flag to prevent default initialization
	if player_ship:
		player_ship.is_loading_from_backend = true
		_log_message("ZoneMain3D: Set loading flag on player ship")

	# Load all player data
	if api_client and api_client.has_method("load_player_data"):
		api_client.load_player_data(player_ship.player_id)
		_log_message("ZoneMain3D: Requested player data from backend")

	# Load inventory data
	if api_client and api_client.has_method("load_inventory"):
		api_client.load_inventory(player_ship.player_id)
		_log_message("ZoneMain3D: Requested inventory data from backend")

func _on_player_data_loaded(data: Dictionary) -> void:
	##Handle player data loaded from backend (Phase 2.2 implementation)
	_log_message("ZoneMain3D: Applying loaded player data: %s" % data)

	if player_ship and data.has("credits"):
		player_ship.credits = data.credits
		_log_message("ZoneMain3D: Restored credits: %d" % data.credits)

	if player_ship and data.has("upgrades"):
		# Apply each upgrade and its effects
		for upgrade_type in data.upgrades:
			var level = data.upgrades[upgrade_type]
			player_ship.upgrades[upgrade_type] = level

			# CRITICAL: Reapply upgrade effects
			if level > 0:
				player_ship._apply_upgrade_effects(upgrade_type, level)
				_log_message("ZoneMain3D: Restored %s upgrade level %d with effects" % [upgrade_type, level])

	# Update UI immediately
	_update_credits_display()
	_populate_upgrade_catalog()  # Refresh to show loaded upgrades

	# Clear loading flag
	if player_ship:
		player_ship.is_loading_from_backend = false
		_log_message("ZoneMain3D: Cleared loading flag - data loading complete")

func _on_inventory_loaded(inventory_data: Array) -> void:
	##Handle inventory data loaded from backend (Phase 2.3 implementation)
	_log_message("ZoneMain3D: Applying loaded inventory: %d items" % inventory_data.size())

	if player_ship:
		player_ship.current_inventory.clear()

		# Convert backend format to game format
		var converted_inventory = []
		for backend_item in inventory_data:
			# Convert backend format to game format
			var game_item = {
				"type": backend_item.get("item_type", "unknown"),        # item_type → type
				"value": backend_item.get("value", 0),                   # value → value
				"id": backend_item.get("item_id", "unknown"),            # item_id → id
				"timestamp": backend_item.get("timestamp", 0)            # timestamp → timestamp
			}
			converted_inventory.append(game_item)

		player_ship.current_inventory = converted_inventory
		_log_message("ZoneMain3D: Converted %d backend items to game format" % converted_inventory.size())
		_log_message("ZoneMain3D: Restored inventory: %d/%d items" % [player_ship.current_inventory.size(), player_ship.inventory_capacity])

		# Update UI immediately
		_update_grouped_inventory_display(player_ship.current_inventory)

func _load_player_data_smartly() -> void:
	##Smart player data loading - checks local mode and existing data before backend loading
	_log_message("ZoneMain3D: Smart loading - checking data source priority...")

	# Check if LocalPlayerData has already loaded valid data
	var local_player_data = LocalPlayerData
	if local_player_data and local_player_data.is_initialized:
		var credits = local_player_data.get_credits()
		var upgrades = local_player_data.get_all_upgrades()
		var has_valid_local_data = (
			credits > 0 or
			upgrades.values().any(func(level): return level > 0) or
			local_player_data.get_inventory().size() > 0
		)

		if has_valid_local_data:
			_log_message("ZoneMain3D: FOUND VALID LOCAL DATA - Skipping backend loading to preserve local progress")
			_log_message("ZoneMain3D: Local data summary - Credits: %d, Upgrades: %s" % [credits, upgrades])
			# CRITICAL FIX: Update UI to show the loaded local data
			_refresh_ui_with_loaded_data()
			return

	# Check if APIClient is already in local storage mode
	if api_client and api_client.has_method("is_using_local_storage"):
		if api_client.is_using_local_storage():
			_log_message("ZoneMain3D: APIClient in local storage mode - Skipping backend loading")
			# Also refresh UI in this case since data should already be loaded
			_refresh_ui_with_loaded_data()
			return

	# SAFETY CHECK: If PlayerShip3D already has local data loaded, don't override it
	if player_ship and (player_ship.credits > 0 or player_ship.upgrades.values().any(func(level): return level > 0)):
		_log_message("ZoneMain3D: PlayerShip3D already has valid data loaded - Skipping backend loading")
		_log_message("ZoneMain3D: PlayerShip3D data - Credits: %d, Upgrades: %s" % [player_ship.credits, player_ship.upgrades])
		# CRITICAL FIX: Update UI to show the loaded PlayerShip3D data
		_refresh_ui_with_loaded_data()
		return

	# Only proceed with backend loading if no valid local data exists and backend is available
	_log_message("ZoneMain3D: No local data found - Attempting backend loading (will fail safely in local mode)")
	_load_complete_player_data_from_backend()

func _refresh_ui_with_loaded_data() -> void:
	##Refresh all UI displays with currently loaded player data
	_log_message("ZoneMain3D: Refreshing UI with loaded player data...")

	if player_ship:
		_log_message("ZoneMain3D: PlayerShip3D current state - Credits: %d, Upgrades: %s" % [player_ship.credits, player_ship.upgrades])

		# Update credits display
		_update_credits_display()

		# Update upgrade status display
		_update_upgrade_status_display()

		# Update inventory displays
		_update_inventory_displays()

		_log_message("ZoneMain3D: UI refresh complete - Credits: %d, Upgrades shown: %d" % [player_ship.credits, player_ship.upgrades.values().count(func(level): return level > 0)])
	else:
		_log_message("ZoneMain3D: WARNING - PlayerShip3D not available for UI refresh")
