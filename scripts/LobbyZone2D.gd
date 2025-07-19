# LobbyZone2D.gd
# 2D Retro Trading Lobby for Children of the Singularity
# Handles 2D pixel art lobby where players can see each other and trade

class_name LobbyZone2D
extends Node2D

## Signal emitted when lobby is fully loaded and ready
signal lobby_ready()

## Signal emitted when player interacts with trading computer
signal trading_computer_accessed()

## Signal emitted when player wants to exit lobby
signal lobby_exit_requested()

# Core lobby references
@onready var camera_2d: Camera2D = $Camera2D
@onready var background: Sprite2D = $Background
@onready var lobby_player: CharacterBody2D = $LobbyPlayer2D
@onready var trading_computer: Area2D = $TradingComputer
@onready var computer_sprite: Sprite2D = $TradingComputer/ComputerSprite2D
@onready var exit_boundaries: Area2D = $ExitBoundaries

# UI Layer references
@onready var ui_layer: CanvasLayer = $UILayer
@onready var hud: Control = $UILayer/HUD
@onready var lobby_status: Label = $UILayer/HUD/LobbyStatus
@onready var interaction_prompt: Label = $UILayer/HUD/InteractionPrompt
@onready var trading_interface: Panel = $UILayer/HUD/TradingInterface

# UI Card references - The 4 cards from 3D zone
@onready var inventory_panel: Panel = $UILayer/HUD/InventoryPanel
@onready var inventory_grid: GridContainer = $UILayer/HUD/InventoryPanel/InventoryGrid
@onready var inventory_status: Label = $UILayer/HUD/InventoryPanel/InventoryStatus
@onready var stats_panel: Panel = $UILayer/HUD/StatsPanel
@onready var credits_label: Label = $UILayer/HUD/StatsPanel/CreditsLabel
@onready var debris_count_label: Label = $UILayer/HUD/StatsPanel/DebrisCountLabel
@onready var collection_range_label: Label = $UILayer/HUD/StatsPanel/CollectionRangeLabel
@onready var upgrade_status_panel: Panel = $UILayer/HUD/UpgradeStatusPanel
@onready var upgrade_status_text: Label = $UILayer/HUD/UpgradeStatusPanel/UpgradeStatusText
@onready var controls_panel: Panel = $UILayer/HUD/ControlsPanel

# System references - will be set from LocalPlayerData
var inventory_manager: Node
var upgrade_system: Node
var api_client: Node
var network_manager: Node

# Lobby state
var player_can_interact: bool = false
var computer_in_range: bool = false
var lobby_loaded: bool = false

# Dynamic scaling properties
var original_viewport_size: Vector2 = Vector2(1920, 1080)  # Design resolution
var original_background_size: Vector2
var current_scale_factor: Vector2 = Vector2.ONE  # Now using Vector2 for independent X/Y scaling
var scaling_enabled: bool = true

# Screen dimensions for boundary checking
var screen_size: Vector2
var lobby_bounds: Rect2

# Debug and logging
var lobby_logs: Array[String] = []

# UI state tracking
var last_credits: int = -1
var last_inventory_size: int = -1
var last_inventory_capacity: int = -1
var last_upgrades_hash: String = ""
var inventory_items: Array[Control] = []
var ui_update_timer: float = 0.0

func _ready() -> void:
	print("[LobbyZone2D] Initializing 2D trading lobby with dynamic scaling")

	# Critical safety check - verify essential nodes exist
	if not _verify_essential_nodes():
		print("[LobbyZone2D] CRITICAL ERROR: Essential nodes missing, lobby will not function properly")
		return

	# Store original sizes before any scaling
	_store_original_sizes()

	# Setup viewport resize signal
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Initial setup
	_setup_lobby_environment()
	_setup_ui_elements()
	_setup_trading_interface()
	_setup_system_references()
	_setup_boundaries()

	# Apply initial scaling
	_apply_dynamic_scaling()

	# Setup UI data connections and load current player data
	_setup_ui_data_connections()
	_load_and_display_player_data()

	print("[LobbyZone2D] Exit boundaries ready for signal detection")
	print("[LobbyZone2D] Trading computer interaction ready")

	# Mark lobby as ready
	lobby_loaded = true
	lobby_ready.emit()
	print("[LobbyZone2D] Lobby initialization complete with dynamic scaling")

func _verify_essential_nodes() -> bool:
	##Verify that all essential @onready nodes were resolved correctly
	var missing_nodes: Array[String] = []

	# Check core references
	if not camera_2d: missing_nodes.append("camera_2d")
	if not background: missing_nodes.append("background")
	if not lobby_player: missing_nodes.append("lobby_player")
	if not trading_computer: missing_nodes.append("trading_computer")
	if not ui_layer: missing_nodes.append("ui_layer")
	if not hud: missing_nodes.append("hud")
	if not lobby_status: missing_nodes.append("lobby_status")
	if not interaction_prompt: missing_nodes.append("interaction_prompt")
	if not trading_interface: missing_nodes.append("trading_interface")

	# Check UI card references
	if not inventory_panel: missing_nodes.append("inventory_panel")
	if not stats_panel: missing_nodes.append("stats_panel")
	if not upgrade_status_panel: missing_nodes.append("upgrade_status_panel")
	if not controls_panel: missing_nodes.append("controls_panel")

	if missing_nodes.size() > 0:
		print("[LobbyZone2D] MISSING NODES: ", missing_nodes)
		return false

	print("[LobbyZone2D] All essential nodes verified successfully")
	return true

func _store_original_sizes() -> void:
	"""Store original sizes before any scaling modifications"""
	print("[LobbyZone2D] Storing original sizes for scaling calculations")

	# Store original background texture size if available
	if background and background.texture:
		original_background_size = background.texture.get_size()
		print("[LobbyZone2D] Original background size: %s" % original_background_size)
	else:
		# Fallback size if no texture yet
		original_background_size = Vector2(1000, 400)  # Approximate size of trading_hub_pixel_horizontal.png
		print("[LobbyZone2D] Using fallback background size: %s" % original_background_size)

func _on_viewport_size_changed() -> void:
	"""Handle viewport resize events"""
	print("[LobbyZone2D] Viewport size changed, reapplying scaling")
	_apply_dynamic_scaling()

func _apply_dynamic_scaling() -> void:
	"""Apply dynamic scaling to make the entire scene fill the viewport with aspect ratio stretching"""
	if not scaling_enabled:
		return

	var current_viewport_size = get_viewport().get_visible_rect().size
	print("[LobbyZone2D] Applying dynamic scaling - Current viewport: %s" % current_viewport_size)
	print("[LobbyZone2D] Original viewport design size: %s" % original_viewport_size)

	# Debug: Check what the actual scene content bounds are
	if background and background.texture:
		var bg_size = background.texture.get_size()
		var bg_pos = background.position
		print("[LobbyZone2D] Background texture size: %s, position: %s" % [bg_size, bg_pos])

		# Use the actual background size as our reference instead of arbitrary design resolution
		# Since the background is the main visual element that should fill the screen
		var actual_content_size = bg_size

		# Calculate scale factors to make background fill the entire viewport
		var scale_x = current_viewport_size.x / actual_content_size.x
		var scale_y = current_viewport_size.y / actual_content_size.y

		current_scale_factor = Vector2(scale_x, scale_y)

		print("[LobbyZone2D] Using background-based scaling - X: %.3f, Y: %.3f" % [scale_x, scale_y])

		# Apply scaling to the entire scene
		self.scale = current_scale_factor

		# Position the scene to center the background at viewport center
		# Background is at bg_pos, so we need to account for that
		var scaled_bg_pos = bg_pos * current_scale_factor
		var viewport_center = current_viewport_size * 0.5
		self.position = viewport_center - scaled_bg_pos

		print("[LobbyZone2D] Scene scaled to: %s, positioned at: %s" % [self.scale, self.position])
	else:
		# Fallback to original method if no background
		var scale_x = current_viewport_size.x / original_viewport_size.x
		var scale_y = current_viewport_size.y / original_viewport_size.y
		current_scale_factor = Vector2(scale_x, scale_y)
		self.scale = current_scale_factor
		self.position = Vector2.ZERO
		print("[LobbyZone2D] Using fallback scaling - X: %.3f, Y: %.3f" % [scale_x, scale_y])

	# Update camera to account for scaling
	_update_camera_for_scaling()

	# Update boundaries for new scale
	_update_boundaries_for_scaling()

func _update_camera_for_scaling() -> void:
	"""Update camera settings for the new scaling"""
	if not camera_2d:
		return

	# Don't change camera position - let it scale with the scene
	# The camera maintains its relative position within the scaled scene
	# This way the camera view moves naturally with the scaled content

	# Make sure camera is enabled
	camera_2d.enabled = true

	print("[LobbyZone2D] Camera maintaining relative position in scaled scene: %s" % camera_2d.position)

func _update_boundaries_for_scaling() -> void:
	"""Update exit boundaries for the new scaling"""
	var current_viewport_size = get_viewport().get_visible_rect().size

	# Boundaries should be in local space (before scaling)
	# Use component-wise division since current_scale_factor is now Vector2
	var local_bounds_size = Vector2(
		current_viewport_size.x / current_scale_factor.x,
		current_viewport_size.y / current_scale_factor.y
	)

	# Scale padding based on average scale factor
	var avg_scale = (current_scale_factor.x + current_scale_factor.y) / 2.0
	var padding = 50 / avg_scale

	lobby_bounds = Rect2(-padding, -padding, local_bounds_size.x + padding * 2, local_bounds_size.y + padding * 2)
	print("[LobbyZone2D] Updated lobby bounds for scaling: %s" % lobby_bounds)

# _process method is now implemented in the UI Data Management section below

func toggle_scaling(enabled: bool) -> void:
	"""Toggle dynamic scaling on/off"""
	scaling_enabled = enabled
	print("[LobbyZone2D] Dynamic scaling %s" % ("enabled" if enabled else "disabled"))

	if enabled:
		_apply_dynamic_scaling()
	else:
		# Reset to original scale and position
		self.scale = Vector2.ONE
		self.position = Vector2.ZERO

func get_current_scale_factor() -> Vector2:
	"""Get the current scale factor being applied"""
	return current_scale_factor

func get_average_scale_factor() -> float:
	"""Get the average of X and Y scale factors as a single value"""
	return (current_scale_factor.x + current_scale_factor.y) / 2.0

func _setup_lobby_environment() -> void:
	"""Setup the 2D lobby visual environment"""
	print("[LobbyZone2D] Setting up lobby environment")

	# Get screen size for proper scaling
	screen_size = get_viewport().get_visible_rect().size
	print("[LobbyZone2D] Screen size: %s" % screen_size)

	# Use editor-set player position and scale instead of programmatic positioning
	if lobby_player:
		print("[LobbyZone2D] Using editor-set player position: %s" % lobby_player.global_position)
		if lobby_player.get_node_or_null("PlayerSprite2D"):
			var player_sprite = lobby_player.get_node("PlayerSprite2D")
			print("[LobbyZone2D] Using editor-set player scale: %s" % player_sprite.scale)

	# Setup background - use editor positioning for consistency
	if background:
		# Load the horizontal trading hub background
		var background_texture = preload("res://assets/trading_hub_pixel_horizontal.png")
		background.texture = background_texture

		# Use editor-set background position (no programmatic override)
		# This ensures sprites and camera work with consistent coordinates
		print("[LobbyZone2D] Background using editor position: %s" % background.position)
		print("[LobbyZone2D] Background using editor centering: %s" % background.centered)

	# Setup trading computer sprite
	if computer_sprite:
		var computer_texture = preload("res://assets/computer_trading_hub_sprite.png")
		computer_sprite.texture = computer_texture

		# Use editor-set computer position and scale instead of programmatic positioning
		print("[LobbyZone2D] Using editor-set computer position: %s" % trading_computer.position)
		print("[LobbyZone2D] Using editor-set computer scale: %s" % computer_sprite.scale)

func _setup_ui_elements() -> void:
	##Setup lobby-specific UI elements
	print("[LobbyZone2D] Setting up UI elements")

	if lobby_status:
		lobby_status.text = "Welcome to the Trading Lobby"
		lobby_status.position = Vector2(20, 20)

	if interaction_prompt:
		interaction_prompt.text = ""
		# Position at bottom center of screen
		interaction_prompt.anchors_preset = Control.PRESET_BOTTOM_WIDE
		interaction_prompt.position = Vector2(0, -100)
		interaction_prompt.size = Vector2(screen_size.x, 50)
		interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		interaction_prompt.visible = false
		print("[LobbyZone2D] Interaction prompt positioned at bottom center")

func _setup_trading_interface() -> void:
	##Setup the trading interface that was moved from 3D overlay
	print("[LobbyZone2D] Setting up trading interface")

	if trading_interface:
		# Hide initially - positioning is handled by scene anchors
		trading_interface.visible = false
		print("[LobbyZone2D] Trading interface configured with scene-defined anchoring")

func _setup_system_references() -> void:
	##Setup references to game systems from singletons/autoloads
	print("[LobbyZone2D] Setting up system references")

	# LocalPlayerData is available as a singleton - no need for inventory_manager property
	if LocalPlayerData:
		print("[LobbyZone2D] Connected to LocalPlayerData singleton")

	# Get UpgradeSystem reference
	upgrade_system = get_node_or_null("/root/UpgradeSystem")
	if upgrade_system:
		print("[LobbyZone2D] Connected to UpgradeSystem")

	# Get APIClient reference
	api_client = get_node_or_null("/root/APIClient")
	if api_client:
		print("[LobbyZone2D] Connected to APIClient")

	# Get NetworkManager reference
	network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager:
		print("[LobbyZone2D] Connected to NetworkManager")

func _setup_boundaries() -> void:
	##Setup exit boundaries for the lobby
	print("[LobbyZone2D] Setting up lobby boundaries")

	# Define lobby bounds based on screen size with some padding
	var padding = 50
	lobby_bounds = Rect2(-padding, -padding, screen_size.x + padding * 2, screen_size.y + padding * 2)
	print("[LobbyZone2D] Lobby bounds set to: %s" % lobby_bounds)

func _check_exit_boundaries() -> void:
	##Check if player has moved outside lobby boundaries
	if not lobby_player:
		return

	var player_pos = lobby_player.global_position

	# Check if player is outside lobby bounds
	if not lobby_bounds.has_point(player_pos):
		print("[LobbyZone2D] Player attempting to exit lobby at position: %s" % player_pos)
		_prompt_lobby_exit()

func _prompt_lobby_exit() -> void:
	##Prompt player if they want to exit the lobby
	print("[LobbyZone2D] Prompting lobby exit")

	# Simple confirmation approach - could be enhanced with a dialog later
	lobby_exit_requested.emit()

	# Return to 3D world immediately for now
	# TODO: Add confirmation dialog asking "Exit lobby? (Y/N)"
	return_to_3d_world()

func _interact_with_computer() -> void:
	##Handle interaction with the trading computer
	if not computer_in_range:
		return

	# Show the trading interface
	if trading_interface:
		trading_interface.visible = true

		# Pause player movement while trading
		if lobby_player and lobby_player.has_method("set_movement_enabled"):
			lobby_player.set_movement_enabled(false)

	trading_computer_accessed.emit()

func close_trading_interface() -> void:
	##Close the trading interface and resume player movement
	print("[LobbyZone2D] Closing trading interface")

	if trading_interface:
		trading_interface.visible = false

	# Resume player movement
	if lobby_player and lobby_player.has_method("set_movement_enabled"):
		lobby_player.set_movement_enabled(true)

func _on_trading_computer_area_entered(area: Area2D) -> void:
	##Handle player entering trading computer interaction area
	# The signal comes from player's InteractionArea2D, so 'area' is the area the player entered
	if area == trading_computer:
		computer_in_range = true
		player_can_interact = true

		if interaction_prompt:
			interaction_prompt.text = "Press F to access Trading Terminal"
			interaction_prompt.visible = true

		print("[LobbyZone2D] Player entered trading computer interaction area")

func _on_trading_computer_area_exited(area: Area2D) -> void:
	##Handle player exiting trading computer interaction area
	# The signal comes from player's InteractionArea2D, so 'area' is the area the player exited
	if area == trading_computer:
		computer_in_range = false
		player_can_interact = false

		if interaction_prompt:
			interaction_prompt.visible = false

		print("[LobbyZone2D] Player exited trading computer interaction area")

func return_to_3d_world() -> void:
	##Return player to the 3D world
	print("[LobbyZone2D] Returning to 3D world")

	# Store lobby state if needed
	if LocalPlayerData:
		LocalPlayerData.save_player_data()

	# Change scene back to 3D zone
	get_tree().change_scene_to_file("res://scenes/zones/ZoneMain3D.tscn")



func log_message(message: String) -> void:
	##Add a message to the lobby log
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] [LOBBY] %s" % [timestamp, message]
	lobby_logs.append(formatted_message)
	print(formatted_message)

	# Keep only last 100 messages
	if lobby_logs.size() > 100:
		lobby_logs = lobby_logs.slice(lobby_logs.size() - 100, lobby_logs.size())

## Properties

func get_lobby_status() -> Dictionary:
	##Get current lobby status
	return {
		"loaded": lobby_loaded,
		"player_position": lobby_player.global_position if lobby_player else Vector2.ZERO,
		"computer_in_range": computer_in_range,
		"trading_interface_open": trading_interface.visible if trading_interface else false
	}


func _on_exit_boundaries_body_exited(body: Node2D) -> void:
	# Check if the exiting body is our lobby player
	if body == lobby_player:
		print("[LobbyZone2D] Player exited lobby boundaries via Area2D signal")
		_prompt_lobby_exit()

## UI Data Management Methods

func _setup_ui_data_connections() -> void:
	##Setup connections to LocalPlayerData for real-time UI updates
	print("[LobbyZone2D] Setting up UI data connections")

	# Connect to LocalPlayerData signals if available
	if LocalPlayerData:
		if LocalPlayerData.has_signal("data_saved") and not LocalPlayerData.data_saved.is_connected(_on_player_data_updated):
			LocalPlayerData.data_saved.connect(_on_player_data_updated)
			print("[LobbyZone2D] Connected to LocalPlayerData signals")
	else:
		print("[LobbyZone2D] WARNING - LocalPlayerData not available")

func _load_and_display_player_data() -> void:
	##Load current player data and update all UI displays
	print("[LobbyZone2D] Loading and displaying current player data")

	if not LocalPlayerData or not LocalPlayerData.is_initialized:
		print("[LobbyZone2D] LocalPlayerData not ready, skipping initial display")
		return

	# Force UI update with current data
	_update_lobby_ui_with_player_data()

func _process(delta: float) -> void:
	# Handle input for interaction and exit
	if Input.is_action_just_pressed("interact") and computer_in_range:
		_interact_with_computer()

	# Periodically update UI (every 0.5 seconds) using a timer
	ui_update_timer += delta
	if ui_update_timer >= 0.5:
		ui_update_timer = 0.0
		_update_lobby_ui_with_player_data()

func _update_lobby_ui_with_player_data() -> void:
	##Update all UI cards with current player data from LocalPlayerData
	if not LocalPlayerData or not LocalPlayerData.is_initialized:
		return

	# Get current player data
	var current_credits = LocalPlayerData.get_credits()
	var current_inventory = LocalPlayerData.get_inventory()
	var current_upgrades = LocalPlayerData.get_all_upgrades()

	# Update credits if changed
	if current_credits != last_credits:
		_update_credits_display(current_credits)
		last_credits = current_credits

	# Update inventory if changed
	var current_capacity = _get_inventory_capacity_from_upgrades(current_upgrades)
	if current_inventory.size() != last_inventory_size or current_capacity != last_inventory_capacity:
		_update_inventory_display(current_inventory, current_capacity)
		last_inventory_size = current_inventory.size()
		last_inventory_capacity = current_capacity

	# Update upgrades if changed
	var upgrades_hash = str(current_upgrades.hash())
	if upgrades_hash != last_upgrades_hash:
		_update_upgrade_status_display(current_upgrades)
		last_upgrades_hash = upgrades_hash

	# Update stats (debris count and collection range from upgrades)
	_update_stats_display(current_upgrades)

func _update_credits_display(credits: int) -> void:
	##Update the credits display in the StatsPanel
	if credits_label and is_instance_valid(credits_label):
		credits_label.text = "Credits: %d" % credits
		print("[LobbyZone2D] Updated credits display: %d" % credits)
	else:
		print("[LobbyZone2D] WARNING: credits_label not available")

func _update_inventory_display(inventory: Array, capacity: int) -> void:
	##Update the inventory display with grouped items
	if not inventory_grid or not is_instance_valid(inventory_grid) or not inventory_status or not is_instance_valid(inventory_status):
		print("[LobbyZone2D] WARNING: inventory UI elements not available")
		return

	# Update status text
	inventory_status.text = "%d/%d Items" % [inventory.size(), capacity]

	# Color code based on fullness
	if inventory.size() >= capacity:
		inventory_status.modulate = Color.RED
	elif inventory.size() >= capacity * 0.8:
		inventory_status.modulate = Color.YELLOW
	else:
		inventory_status.modulate = Color.WHITE

	# Clear existing inventory display
	for item in inventory_items:
		if item:
			item.queue_free()
	inventory_items.clear()

	# Group inventory by type
	var grouped_inventory = _group_inventory_by_type(inventory)

	# Add grouped items to display
	for item_type in grouped_inventory:
		var group_data = grouped_inventory[item_type]
		var item_control = _create_inventory_item_control(item_type, group_data)
		inventory_grid.add_child(item_control)
		inventory_items.append(item_control)

	print("[LobbyZone2D] Updated inventory display: %d/%d items" % [inventory.size(), capacity])

func _update_upgrade_status_display(upgrades: Dictionary) -> void:
	##Update the upgrade status display
	if not upgrade_status_text:
		return

	var status_text = ""
	var upgrade_count = 0

	for upgrade_type in upgrades:
		var level = upgrades[upgrade_type]
		if level > 0:
			var upgrade_name = upgrade_type.capitalize().replace("_", " ")
			status_text += "%s: L%d\n" % [upgrade_name, level]
			upgrade_count += 1

	if upgrade_count == 0:
		upgrade_status_text.text = "No upgrades purchased"
		upgrade_status_text.modulate = Color.GRAY
	else:
		upgrade_status_text.text = status_text.strip_edges()
		upgrade_status_text.modulate = Color.WHITE

	print("[LobbyZone2D] Updated upgrade status: %d upgrades" % upgrade_count)

func _update_stats_display(upgrades: Dictionary) -> void:
	##Update the stats display (debris count and collection range)
	if not debris_count_label or not collection_range_label:
		return

	# For lobby, debris count is always 0 (no debris spawning in lobby)
	debris_count_label.text = "Nearby Debris: 0"

	# Calculate collection range based on upgrades
	var base_range = 80
	var collection_efficiency_level = upgrades.get("collection_efficiency", 0)
	var bonus_range = collection_efficiency_level * 20  # 2D uses different scaling
	var total_range = base_range + bonus_range

	if bonus_range > 0:
		collection_range_label.text = "Collection Range: %d (+%d)" % [total_range, bonus_range]
	else:
		collection_range_label.text = "Collection Range: %d" % total_range

func _group_inventory_by_type(inventory: Array) -> Dictionary:
	##Group inventory items by type and calculate quantities
	var grouped = {}

	for item in inventory:
		var item_type = item.get("type", "Unknown")
		var item_value = item.get("value", 0)

		if not grouped.has(item_type):
			grouped[item_type] = {
				"quantity": 0,
				"total_value": 0,
				"individual_value": item_value
			}

		grouped[item_type].quantity += 1
		grouped[item_type].total_value += item_value

	return grouped

func _create_inventory_item_control(item_type: String, group_data: Dictionary) -> Control:
	##Create a control for displaying a grouped inventory item
	var item_container = VBoxContainer.new()
	item_container.custom_minimum_size = Vector2(60, 60)

	# Item type label
	var type_label = Label.new()
	type_label.text = item_type.capitalize().replace("_", " ")
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	item_container.add_child(type_label)

	# Quantity label
	var quantity_label = Label.new()
	quantity_label.text = "x%d" % group_data.quantity
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_label.add_theme_color_override("font_color", Color.CYAN)
	item_container.add_child(quantity_label)

	# Value label
	var value_label = Label.new()
	value_label.text = "%d credits" % group_data.total_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color.YELLOW)
	item_container.add_child(value_label)

	return item_container

func _get_inventory_capacity_from_upgrades(upgrades: Dictionary) -> int:
	##Calculate inventory capacity based on upgrade levels
	var base_capacity = 10
	var expansion_level = upgrades.get("inventory_expansion", 0)
	var bonus_capacity = expansion_level * 5  # Each level adds 5 slots
	return base_capacity + bonus_capacity

func _on_player_data_updated(data_type: String) -> void:
	##Handle player data update signals from LocalPlayerData
	print("[LobbyZone2D] Player data updated: %s" % data_type)

	# Force UI update when data changes
	_update_lobby_ui_with_player_data()
