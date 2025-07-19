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

# Trading Interface UI references - CRITICAL MISSING CONNECTIONS
@onready var trading_title: Label = $UILayer/HUD/TradingInterface/TradingTitle
@onready var trading_tabs: TabContainer = $UILayer/HUD/TradingInterface/TradingTabs
@onready var trading_close_button: Button = $UILayer/HUD/TradingInterface/TradingCloseButton

# SELL Tab UI references
@onready var sell_tab: Control = $UILayer/HUD/TradingInterface/TradingTabs/SELL
@onready var trading_content: VBoxContainer = $UILayer/HUD/TradingInterface/TradingTabs/SELL/TradingContent
@onready var trading_result: Label = $UILayer/HUD/TradingInterface/TradingTabs/SELL/TradingContent/TradingResult
@onready var sell_all_button: Button = $UILayer/HUD/TradingInterface/TradingTabs/SELL/TradingContent/SellAllButton
@onready var dump_inventory_button: Button = $UILayer/HUD/TradingInterface/TradingTabs/SELL/TradingContent/DumpInventoryButton

# BUY Tab UI references - CRITICAL MISSING CONNECTIONS
@onready var buy_tab: Control = $UILayer/HUD/TradingInterface/TradingTabs/BUY
@onready var upgrade_content: VBoxContainer = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent
@onready var upgrade_catalog: ScrollContainer = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeCatalog
@onready var upgrade_grid: GridContainer = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeCatalog/CenterContainer/UpgradeGrid
@onready var upgrade_details: Panel = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeDetails
@onready var upgrade_details_label: Label = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeDetails/UpgradeDetailsLabel
@onready var purchase_controls: HBoxContainer = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/PurchaseControls
@onready var purchase_button: Button = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/PurchaseControls/PurchaseButton
@onready var purchase_result: Label = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/PurchaseResult
@onready var clear_upgrades_container: HBoxContainer = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/ClearUpgradesContainer
@onready var clear_upgrades_button: Button = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/ClearUpgradesContainer/ClearUpgradesButton

# MARKETPLACE Tab UI references (future feature)
@onready var marketplace_tab: Control = $UILayer/HUD/TradingInterface/TradingTabs/MARKETPLACE

# System references - will be set from LocalPlayerData
var inventory_manager: Node
var upgrade_system: Node
var api_client: Node
var network_manager: Node

# Trading interface state - CRITICAL MISSING VARIABLES
var current_selected_upgrade: String = ""
var current_upgrade_cost: int = 0
var upgrade_buttons: Dictionary = {}  # Store upgrade button references
var trading_interface_open: bool = false

# Selective trading UI elements (will be created dynamically)
var debris_selection_container: ScrollContainer
var debris_selection_list: VBoxContainer
var selection_summary_label: Label
var sell_selected_button: Button
var selected_debris: Dictionary = {}  # Store selected quantities per debris type

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
	print("[LobbyZone2D] Setting up trading interface with full button connections")

	if trading_interface:
		# Hide initially - positioning is handled by scene anchors
		trading_interface.visible = false
		print("[LobbyZone2D] Trading interface configured with scene-defined anchoring")

	# CRITICAL FIX: Connect all trading interface buttons
	_connect_trading_interface_buttons()

	# Initialize upgrade interface components
	_initialize_upgrade_interface()

	# Create enhanced selective trading UI structure
	_create_selective_trading_ui()

	print("[LobbyZone2D] Trading interface setup complete with all button connections")

func _connect_trading_interface_buttons() -> void:
	##Connect all trading interface button signals - CRITICAL MISSING FUNCTIONALITY
	print("[LobbyZone2D] Connecting trading interface buttons")

	# SELL Tab button connections
	if sell_all_button:
		if not sell_all_button.pressed.is_connected(_on_sell_all_pressed):
			sell_all_button.pressed.connect(_on_sell_all_pressed)
			print("[LobbyZone2D] Connected sell_all_button")

	if dump_inventory_button:
		if not dump_inventory_button.pressed.is_connected(_on_dump_inventory_pressed):
			dump_inventory_button.pressed.connect(_on_dump_inventory_pressed)
			print("[LobbyZone2D] Connected dump_inventory_button")

	# BUY Tab button connections
	if purchase_button:
		if not purchase_button.pressed.is_connected(_on_purchase_button_pressed):
			purchase_button.pressed.connect(_on_purchase_button_pressed)
			print("[LobbyZone2D] Connected purchase_button")

	if clear_upgrades_button:
		if not clear_upgrades_button.pressed.is_connected(_on_clear_upgrades_pressed):
			clear_upgrades_button.pressed.connect(_on_clear_upgrades_pressed)
			print("[LobbyZone2D] Connected clear_upgrades_button")

	# Trading interface control buttons
	if trading_close_button:
		if not trading_close_button.pressed.is_connected(_on_trading_close_pressed):
			trading_close_button.pressed.connect(_on_trading_close_pressed)
			print("[LobbyZone2D] Connected trading_close_button")

	print("[LobbyZone2D] All trading interface buttons connected successfully")

func _initialize_upgrade_interface() -> void:
	##Initialize upgrade interface components - CRITICAL MISSING FUNCTIONALITY
	print("[LobbyZone2D] Initializing upgrade interface")

	# Clear current selection
	current_selected_upgrade = ""
	current_upgrade_cost = 0
	upgrade_buttons.clear()

	# Initially disable purchase button
	if purchase_button:
		purchase_button.disabled = true
		purchase_button.text = "PURCHASE UPGRADE"

	# Set default upgrade details text
	if upgrade_details_label:
		upgrade_details_label.text = "Select an upgrade above to see details"

	# Clear purchase result
	if purchase_result:
		purchase_result.text = ""

	print("[LobbyZone2D] Upgrade interface initialized")

func _create_selective_trading_ui() -> void:
	##Create the enhanced selective trading UI elements
	print("[LobbyZone2D] Creating selective trading UI elements")

	if not trading_content:
		print("[LobbyZone2D] ERROR - Trading content container not found!")
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

	print("[LobbyZone2D] Selective trading UI structure created")

## TRADING INTERFACE BUTTON HANDLERS - CRITICAL MISSING FUNCTIONALITY

func _on_sell_all_pressed() -> void:
	##Handle sell all button press - CRITICAL FIXED IMPLEMENTATION
	print("[LobbyZone2D] === SELL ALL BUTTON PRESSED ===")

	# CRITICAL FIX: Comprehensive validation and debugging
	if not LocalPlayerData:
		print("[LobbyZone2D] CRITICAL ERROR - LocalPlayerData not available!")
		_update_trading_result("System Error: Player data not available!", Color.RED)
		return

	if not LocalPlayerData.is_initialized:
		print("[LobbyZone2D] CRITICAL ERROR - LocalPlayerData not initialized!")
		_update_trading_result("System Error: Player data not ready!", Color.RED)
		return

	# Get inventory with detailed logging
	var inventory = LocalPlayerData.get_inventory()
	print("[LobbyZone2D] Retrieved inventory from LocalPlayerData:")
	print("[LobbyZone2D] - Inventory size: %d" % inventory.size())
	if inventory.size() > 0:
		print("[LobbyZone2D] - Sample items: %s" % inventory.slice(0, min(3, inventory.size())))

	# Check if inventory is empty with detailed feedback
	if inventory.is_empty():
		print("[LobbyZone2D] No debris in inventory to sell")
		_update_trading_result("No debris to sell!\n\nTip: Collect debris in the 3D world first,\nthen return to this lobby to sell items.", Color.YELLOW)
		return

	# Calculate total value with item-by-item logging
	var total_value = 0
	var item_count = inventory.size()
	var item_breakdown = {}

	for item in inventory:
		var item_type = item.get("type", "unknown")
		var item_value = item.get("value", 0)
		total_value += item_value

		if not item_breakdown.has(item_type):
			item_breakdown[item_type] = {"count": 0, "value": 0}
		item_breakdown[item_type].count += 1
		item_breakdown[item_type].value += item_value

	print("[LobbyZone2D] Sale breakdown:")
	for item_type in item_breakdown:
		var data = item_breakdown[item_type]
		print("[LobbyZone2D] - %s: %d items, %d credits" % [item_type, data.count, data.value])
	print("[LobbyZone2D] Total: %d items for %d credits" % [item_count, total_value])

	# Process the sale
	print("[LobbyZone2D] Processing sale transaction...")
	LocalPlayerData.clear_inventory()
	LocalPlayerData.add_credits(total_value)
	print("[LobbyZone2D] Sale completed - inventory cleared, credits added")

	# Update UI immediately with forced refresh
	_update_lobby_ui_with_player_data()

	# CRITICAL FIX: Force inventory display refresh immediately
	var current_inventory = LocalPlayerData.get_inventory()
	var current_capacity = _get_inventory_capacity_from_upgrades(LocalPlayerData.get_all_upgrades())
	_update_inventory_display(current_inventory, current_capacity)
	last_inventory_size = current_inventory.size()  # Update tracking variable

	# CRITICAL FIX: Refresh the selective trading UI after selling all items
	_populate_debris_selection_ui()
	_update_selection_summary()

	# Populate upgrade catalog after credit update (so player can see what they can now afford)
	if trading_interface.visible:
		_populate_upgrade_catalog()
		print("[LobbyZone2D] Upgrade catalog refreshed after sale")

	# Show detailed success message
	var success_message = "SALE SUCCESSFUL!\n\nSold: %d items\nEarned: %d credits\nTotal Credits: %d\n\nYou can now purchase upgrades!" % [item_count, total_value, LocalPlayerData.get_credits()]
	_update_trading_result(success_message, Color.GREEN)

	print("[LobbyZone2D] === SALE COMPLETED SUCCESSFULLY ===")
	print("[LobbyZone2D] Final state - Credits: %d, Inventory: %d items" % [LocalPlayerData.get_credits(), LocalPlayerData.get_inventory().size()])

func _on_dump_inventory_pressed() -> void:
	##Handle dump inventory button press (clear without selling)
	print("[LobbyZone2D] Dump inventory button pressed")

	if not LocalPlayerData or not LocalPlayerData.is_initialized:
		_update_trading_result("Player data not available!", Color.RED)
		return

	var inventory = LocalPlayerData.get_inventory()
	if inventory.is_empty():
		_update_trading_result("No inventory to dump!", Color.YELLOW)
		return

	var item_count = inventory.size()

	# Clear inventory without adding credits
	LocalPlayerData.clear_inventory()

	# Update UI immediately with forced refresh
	_update_lobby_ui_with_player_data()

	# CRITICAL FIX: Force inventory display refresh immediately
	var current_inventory = LocalPlayerData.get_inventory()
	var current_capacity = _get_inventory_capacity_from_upgrades(LocalPlayerData.get_all_upgrades())
	_update_inventory_display(current_inventory, current_capacity)
	last_inventory_size = current_inventory.size()  # Update tracking variable

	# CRITICAL FIX: Refresh the selective trading UI after dumping all items
	_populate_debris_selection_ui()
	_update_selection_summary()

	# Show warning message
	var warning_message = "WARNING!\nDumped %d items without selling\nNo credits gained!" % item_count
	_update_trading_result(warning_message, Color.ORANGE)

	print("[LobbyZone2D] Dumped %d items without selling" % item_count)

func _on_purchase_button_pressed() -> void:
	##Handle purchase button press - CRITICAL MISSING IMPLEMENTATION
	if current_selected_upgrade.is_empty():
		print("[LobbyZone2D] No upgrade selected for purchase")
		return

	print("[LobbyZone2D] Purchase button pressed for %s" % current_selected_upgrade)

	# Attempt to purchase the upgrade
	_purchase_upgrade(current_selected_upgrade)

func _on_trading_close_pressed() -> void:
	##Handle trading close button press
	print("[LobbyZone2D] Trading close button pressed")
	close_trading_interface()

func _update_trading_result(message: String, color: Color) -> void:
	##Update trading result display with message and color
	if trading_result:
		trading_result.text = message
		trading_result.modulate = color
		print("[LobbyZone2D] Trading result updated: %s" % message)

func _on_clear_upgrades_pressed() -> void:
	##Handle clear upgrades button press - reset all upgrades to defaults
	print("[LobbyZone2D] Clear upgrades button pressed")

	if not LocalPlayerData or not LocalPlayerData.is_initialized:
		print("[LobbyZone2D] ERROR - LocalPlayerData not available!")
		return

	# Show confirmation dialog
	var confirmation_text = "Are you sure you want to CLEAR ALL upgrades?\n\nThis will reset all upgrades to default levels:\n• Speed Boost: Level 0\n• Inventory Expansion: Level 0\n• Collection Efficiency: Level 0\n• Zone Access: Level 1 (minimum)\n• Debris Scanner: Level 0\n• Cargo Magnet: Level 0\n\nYou will NOT receive any credit refunds!\nThis action cannot be undone."

	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Confirm Clear All Upgrades"
	dialog.dialog_text = confirmation_text
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN

	# Add to scene temporarily
	add_child(dialog)

	# Connect signals
	dialog.confirmed.connect(_on_clear_upgrades_confirmed.bind(dialog))
	dialog.canceled.connect(_on_clear_upgrades_canceled.bind(dialog))

	# Show dialog
	dialog.popup_centered(Vector2i(600, 400))
	print("[LobbyZone2D] Clear upgrades confirmation dialog shown")

func _on_clear_upgrades_confirmed(dialog: ConfirmationDialog) -> void:
	##Handle confirmed clear upgrades action
	print("[LobbyZone2D] Clear upgrades confirmed by user")

	if not LocalPlayerData or not LocalPlayerData.is_initialized:
		print("[LobbyZone2D] ERROR - LocalPlayerData not available!")
		dialog.queue_free()
		return

	# Reset all upgrades to default values in LocalPlayerData
	LocalPlayerData.player_upgrades = {
		"speed_boost": 0,
		"inventory_expansion": 0,
		"collection_efficiency": 0,
		"zone_access": 1,  # Minimum level 1
		"debris_scanner": 0,
		"cargo_magnet": 0
	}

	# Save the cleared upgrades
	LocalPlayerData.save_upgrades()

	# Reset current selected upgrade
	current_selected_upgrade = ""
	current_upgrade_cost = 0

	# Update UI immediately
	_update_purchase_result("ALL UPGRADES CLEARED", Color.RED)
	_populate_upgrade_catalog()  # Refresh catalog to show Level 0
	_update_lobby_ui_with_player_data()  # Update all UI elements

	print("[LobbyZone2D] All upgrades reset to defaults - UI refreshed")

	# Clean up dialog
	dialog.queue_free()

func _on_clear_upgrades_canceled(dialog: ConfirmationDialog) -> void:
	##Handle canceled clear upgrades action
	print("[LobbyZone2D] Clear upgrades canceled by user")
	dialog.queue_free()

## UPGRADE CATALOG AND PURCHASE FUNCTIONALITY - CRITICAL MISSING IMPLEMENTATION

func _populate_upgrade_catalog() -> void:
	##Populate the upgrade catalog with available upgrades - CRITICAL FIXED FUNCTIONALITY
	print("[LobbyZone2D] === POPULATING UPGRADE CATALOG ===")

	# CRITICAL FIX: Comprehensive validation before proceeding
	if not upgrade_grid:
		print("[LobbyZone2D] CRITICAL ERROR - upgrade_grid not found!")
		return

	if not LocalPlayerData:
		print("[LobbyZone2D] CRITICAL ERROR - LocalPlayerData not available!")
		return

	if not LocalPlayerData.is_initialized:
		print("[LobbyZone2D] CRITICAL ERROR - LocalPlayerData not initialized!")
		return

	# Clear existing upgrade buttons
	for child in upgrade_grid.get_children():
		child.queue_free()
	upgrade_buttons.clear()
	print("[LobbyZone2D] Cleared existing upgrade buttons")

	# CRITICAL FIX: Ensure upgrade_system is available (should be created by _setup_system_references)
	if not upgrade_system:
		print("[LobbyZone2D] upgrade_system missing - calling _setup_system_references()")
		_setup_system_references()

	if not upgrade_system:
		print("[LobbyZone2D] CRITICAL ERROR - Could not create upgrade_system!")
		return

	# Get current player data with detailed logging
	var player_credits = LocalPlayerData.get_credits()
	var player_upgrades = LocalPlayerData.get_all_upgrades()

	print("[LobbyZone2D] Player data loaded:")
	print("[LobbyZone2D] - Credits: %d" % player_credits)
	print("[LobbyZone2D] - Upgrades: %s" % player_upgrades)

	# Get upgrade definitions from system
	var upgrade_definitions = upgrade_system.upgrade_definitions
	if not upgrade_definitions or upgrade_definitions.is_empty():
		print("[LobbyZone2D] WARNING - UpgradeSystem has no upgrade definitions, using fallback")
		upgrade_definitions = _get_basic_upgrade_definitions()

	print("[LobbyZone2D] Creating upgrade buttons for %d upgrade types: %s" % [upgrade_definitions.size(), upgrade_definitions.keys()])

	# Create upgrade buttons for each type
	var buttons_created = 0
	for upgrade_type in upgrade_definitions:
		var upgrade_data = upgrade_definitions[upgrade_type]
		var current_level = player_upgrades.get(upgrade_type, 0)
		var max_level = upgrade_data.get("max_level", 5)
		var cost = _calculate_upgrade_cost(upgrade_type, current_level)

		print("[LobbyZone2D] Creating button for %s - Level %d/%d, Cost: %d" % [upgrade_type, current_level, max_level, cost])

		# Create upgrade button for this type
		var upgrade_button = _create_upgrade_button(upgrade_type, upgrade_data, current_level, max_level, player_credits)
		if upgrade_button:
			upgrade_grid.add_child(upgrade_button)
			upgrade_buttons[upgrade_type] = upgrade_button
			buttons_created += 1
			print("[LobbyZone2D] Successfully created button for %s" % upgrade_type)
		else:
			print("[LobbyZone2D] ERROR - Failed to create button for %s" % upgrade_type)

	print("[LobbyZone2D] === UPGRADE CATALOG POPULATED - %d buttons created ===" % buttons_created)

func _create_upgrade_button(upgrade_type: String, upgrade_data: Dictionary, current_level: int, max_level: int, player_credits: int) -> Button:
	##Create an upgrade button with appropriate styling and functionality
	var upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton_" + upgrade_type

	# Calculate upgrade cost
	var cost = _calculate_upgrade_cost(upgrade_type, current_level)
	var can_afford = player_credits >= cost
	var is_maxed = current_level >= max_level

	# Set button text and styling
	var upgrade_name = upgrade_data.get("name", upgrade_type.capitalize().replace("_", " "))
	var button_text = ""

	if is_maxed:
		button_text = "%s - MAXED (Level %d)" % [upgrade_name, current_level]
		upgrade_button.disabled = true
		upgrade_button.modulate = Color.GRAY
	else:
		var next_level = current_level + 1
		button_text = "%s - Level %d → %d (%d credits)" % [upgrade_name, current_level, next_level, cost]
		upgrade_button.disabled = not can_afford

		if can_afford:
			upgrade_button.modulate = Color.WHITE
		else:
			upgrade_button.modulate = Color.DARK_GRAY

	upgrade_button.text = button_text
	upgrade_button.custom_minimum_size = Vector2(300, 50)

	# Connect button press signal
	upgrade_button.pressed.connect(_on_upgrade_selected.bind(upgrade_type, upgrade_data, current_level, cost, can_afford, is_maxed))

	return upgrade_button

func _calculate_upgrade_cost(upgrade_type: String, current_level: int) -> int:
	##Calculate the cost for the next level of an upgrade
	if upgrade_system and upgrade_system.has_method("calculate_upgrade_cost"):
		return upgrade_system.calculate_upgrade_cost(upgrade_type, current_level)

	# Fallback cost calculation if upgrade system not available
	var base_costs = {
		"speed_boost": 50,
		"inventory_expansion": 75,
		"collection_efficiency": 100,
		"cargo_magnet": 150
	}

	var base_cost = base_costs.get(upgrade_type, 100)
	return base_cost + (current_level * base_cost)

func _on_upgrade_selected(upgrade_type: String, upgrade_data: Dictionary, current_level: int, cost: int, can_afford: bool, is_maxed: bool) -> void:
	##Handle upgrade selection - CRITICAL MISSING FUNCTIONALITY
	print("[LobbyZone2D] Upgrade selected: %s (level %d, cost %d)" % [upgrade_type, current_level, cost])

	current_selected_upgrade = upgrade_type
	current_upgrade_cost = cost

	# Update upgrade details panel
	if upgrade_details_label:
		var details_text = ""
		if is_maxed:
			details_text = "UPGRADE MAXED OUT\n\n%s\nCurrent Level: %d/%d\n\nThis upgrade has reached its maximum level." % [
				upgrade_data.get("description", "No description available"),
				current_level,
				upgrade_data.get("max_level", 5)
			]
		else:
			var next_level = current_level + 1
			var effect_per_level = upgrade_data.get("effect_per_level", "Unknown effect")
			details_text = "%s\n\nCurrent Level: %d/%d\nNext Level: %d\nCost: %d credits\nEffect per level: %s\nCategory: %s" % [
				upgrade_data.get("description", "No description available"),
				current_level,
				upgrade_data.get("max_level", 5),
				next_level,
				cost,
				str(effect_per_level),
				upgrade_data.get("category", "Unknown")
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

func _purchase_upgrade(upgrade_type: String) -> void:
	##Purchase the selected upgrade - CRITICAL MISSING FUNCTIONALITY
	print("[LobbyZone2D] Attempting to purchase upgrade: %s" % upgrade_type)

	if not LocalPlayerData or not LocalPlayerData.is_initialized:
		_update_purchase_result("Player data not available!", Color.RED)
		return

	# Get current state
	var player_credits = LocalPlayerData.get_credits()
	var current_upgrades = LocalPlayerData.get_all_upgrades()
	var current_level = current_upgrades.get(upgrade_type, 0)
	var cost = _calculate_upgrade_cost(upgrade_type, current_level)

	# Validate purchase
	if player_credits < cost:
		_update_purchase_result("INSUFFICIENT CREDITS\nNeed: %d, Have: %d" % [cost, player_credits], Color.RED)
		print("[LobbyZone2D] Purchase failed - insufficient credits")
		return

	# Get upgrade definitions for max level check
	var upgrade_definitions = upgrade_system.upgrade_definitions if upgrade_system else _get_basic_upgrade_definitions()
	var upgrade_data = upgrade_definitions.get(upgrade_type, {})
	var max_level = upgrade_data.get("max_level", 5)

	if current_level >= max_level:
		_update_purchase_result("UPGRADE ALREADY AT MAX LEVEL", Color.RED)
		print("[LobbyZone2D] Purchase failed - already at max level")
		return

	# CRITICAL FIX: Use APIClient for server-backed purchases when available
	if api_client and api_client.has_method("purchase_upgrade"):
		print("[LobbyZone2D] Using APIClient for server-backed upgrade purchase")
		_update_purchase_result("Processing purchase...", Color.YELLOW)

		# Use APIClient for purchase (will trigger signals for success/failure)
		api_client.purchase_upgrade(upgrade_type, cost, LocalPlayerData.get_player_id())

		# The purchase result will be handled by signal handlers
		return

	# Fallback to local-only purchase if APIClient not available
	print("[LobbyZone2D] Using local-only upgrade purchase")
	_process_local_upgrade_purchase(upgrade_type, cost, current_level, upgrade_data)

func _process_local_upgrade_purchase(upgrade_type: String, cost: int, current_level: int, upgrade_data: Dictionary) -> void:
	##Process upgrade purchase locally when APIClient is not available
	# Deduct credits and apply upgrade locally
	LocalPlayerData.add_credits(-cost)
	var new_level = current_level + 1
	LocalPlayerData.set_upgrade_level(upgrade_type, new_level)

	print("[LobbyZone2D] Local purchase successful - %s level %d for %d credits" % [upgrade_type, new_level, cost])

	# Apply upgrade effects if upgrade system is available
	if upgrade_system and upgrade_system.has_method("apply_upgrade_effects"):
		upgrade_system.apply_upgrade_effects(upgrade_type, new_level, null)  # No player ship in lobby
		print("[LobbyZone2D] Applied upgrade effects for %s level %d" % [upgrade_type, new_level])

	# Update UI immediately
	_update_lobby_ui_with_player_data()
	_populate_upgrade_catalog()  # Refresh catalog with new levels

	# Show success message
	var upgrade_name = upgrade_data.get("name", upgrade_type.capitalize().replace("_", " "))
	var success_message = "SUCCESS!\nPurchased %s level %d\nCost: %d credits\nRemaining: %d credits" % [upgrade_name, new_level, cost, LocalPlayerData.get_credits()]
	_update_purchase_result(success_message, Color.GREEN)

	# Clear selection to reset the interface
	current_selected_upgrade = ""
	current_upgrade_cost = 0

	# Reset upgrade details panel
	if upgrade_details_label:
		upgrade_details_label.text = "Select an upgrade above to see details"

	# Reset purchase button
	if purchase_button:
		purchase_button.text = "PURCHASE UPGRADE"
		purchase_button.disabled = true

func _update_purchase_result(message: String, color: Color) -> void:
	##Update the purchase result display
	if purchase_result:
		purchase_result.text = message
		purchase_result.modulate = color
		print("[LobbyZone2D] Purchase result updated: %s" % message)

func _get_basic_upgrade_definitions() -> Dictionary:
	##Get basic upgrade definitions if UpgradeSystem is not available
	return {
		"speed_boost": {
			"name": "Speed Boost",
			"description": "Increases movement speed",
			"max_level": 5,
			"effect_per_level": "+20 speed",
			"category": "Movement"
		},
		"inventory_expansion": {
			"name": "Inventory Expansion",
			"description": "Increases inventory capacity",
			"max_level": 5,
			"effect_per_level": "+5 slots",
			"category": "Storage"
		},
		"collection_efficiency": {
			"name": "Collection Efficiency",
			"description": "Improves debris collection range and speed",
			"max_level": 5,
			"effect_per_level": "+2 range",
			"category": "Collection"
		},
		"cargo_magnet": {
			"name": "Cargo Magnet",
			"description": "Automatically collects nearby debris",
			"max_level": 3,
			"effect_per_level": "+5 range",
			"category": "Automation"
		}
	}

func _create_basic_upgrade_definitions() -> void:
	##Create a basic upgrade system if one doesn't exist
	print("[LobbyZone2D] Creating basic upgrade definitions for lobby")
	# This is handled by _get_basic_upgrade_definitions() method

func _setup_system_references() -> void:
	##Setup references to game systems from singletons/autoloads
	print("[LobbyZone2D] === SETTING UP SYSTEM REFERENCES ===")

	# CRITICAL FIX: Create UpgradeSystem instance if singleton not available
	if not upgrade_system:
		upgrade_system = get_node_or_null("/root/UpgradeSystem")
		if upgrade_system:
			print("[LobbyZone2D] Connected to UpgradeSystem singleton")
		else:
			print("[LobbyZone2D] UpgradeSystem singleton not found - creating local instance")
			# Create local UpgradeSystem instance for lobby
			var upgrade_script = preload("res://scripts/UpgradeSystem.gd")
			upgrade_system = upgrade_script.new()
			upgrade_system.name = "LobbyUpgradeSystem"
			add_child(upgrade_system)
			print("[LobbyZone2D] Created local UpgradeSystem instance")
	else:
		print("[LobbyZone2D] UpgradeSystem already available")

	# Setup APIClient reference for upgrade purchases
	if not api_client:
		api_client = get_node_or_null("/root/APIClient")
		if api_client:
			print("[LobbyZone2D] Connected to APIClient singleton")
		else:
			print("[LobbyZone2D] WARNING - APIClient not found, using local-only mode")

	# Setup InventoryManager reference (optional)
	if not inventory_manager:
		inventory_manager = get_node_or_null("/root/InventoryManager")
		if inventory_manager:
			print("[LobbyZone2D] Connected to InventoryManager")
		else:
			print("[LobbyZone2D] InventoryManager not found - using LocalPlayerData directly")

	# Setup NetworkManager reference (optional)
	if not network_manager:
		network_manager = get_node_or_null("/root/NetworkManager")
		if network_manager:
			print("[LobbyZone2D] Connected to NetworkManager")
		else:
			print("[LobbyZone2D] NetworkManager not found - local mode only")

	# CRITICAL: Verify LocalPlayerData is available and ready
	if LocalPlayerData:
		if LocalPlayerData.is_initialized:
			print("[LobbyZone2D] LocalPlayerData verified and initialized")
			print("[LobbyZone2D] - Credits: %d" % LocalPlayerData.get_credits())
			print("[LobbyZone2D] - Inventory items: %d" % LocalPlayerData.get_inventory().size())
			print("[LobbyZone2D] - Upgrades: %s" % LocalPlayerData.get_all_upgrades())
		else:
			print("[LobbyZone2D] WARNING - LocalPlayerData exists but not initialized")
	else:
		print("[LobbyZone2D] CRITICAL ERROR - LocalPlayerData not available!")

	# Verify critical systems for trading functionality
	var systems_ready = {
		"LocalPlayerData": LocalPlayerData != null and LocalPlayerData.is_initialized,
		"UpgradeSystem": upgrade_system != null,
		"APIClient": api_client != null
	}

	print("[LobbyZone2D] System status: %s" % systems_ready)
	print("[LobbyZone2D] === SYSTEM REFERENCES SETUP COMPLETE ===")

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

	print("[LobbyZone2D] Interacting with trading computer - opening trading interface")

	# Show the trading interface
	if trading_interface:
		trading_interface.visible = true
		trading_interface_open = true

		# CRITICAL FIX: Populate upgrade catalog when interface opens
		_populate_upgrade_catalog()

		# CRITICAL FIX: Populate selective debris selection UI when interface opens
		_populate_debris_selection_ui()

		# Set trading interface title
		if trading_title:
			trading_title.text = "TRADING TERMINAL - LOBBY"

		# Clear any previous results
		if trading_result:
			trading_result.text = "Select specific quantities of debris to sell, or use 'Sell All' to convert everything into credits."

		if purchase_result:
			purchase_result.text = ""

		# Pause player movement while trading
		if lobby_player and lobby_player.has_method("set_movement_enabled"):
			lobby_player.set_movement_enabled(false)

		print("[LobbyZone2D] Trading interface opened with upgrade catalog populated")

	trading_computer_accessed.emit()

func close_trading_interface() -> void:
	##Close the trading interface and resume player movement
	print("[LobbyZone2D] Closing trading interface")

	if trading_interface:
		trading_interface.visible = false
		trading_interface_open = false

	# Clear trading interface state
	current_selected_upgrade = ""
	current_upgrade_cost = 0

	# Resume player movement
	if lobby_player and lobby_player.has_method("set_movement_enabled"):
		lobby_player.set_movement_enabled(true)

	print("[LobbyZone2D] Trading interface closed and player movement resumed")

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

	# CRITICAL FIX: Connect to APIClient signals for upgrade purchases
	if api_client:
		if api_client.has_signal("upgrade_purchased") and not api_client.upgrade_purchased.is_connected(_on_upgrade_purchase_success):
			api_client.upgrade_purchased.connect(_on_upgrade_purchase_success)
			print("[LobbyZone2D] Connected to APIClient upgrade_purchased signal")

		if api_client.has_signal("upgrade_purchase_failed") and not api_client.upgrade_purchase_failed.is_connected(_on_upgrade_purchase_failed):
			api_client.upgrade_purchase_failed.connect(_on_upgrade_purchase_failed)
			print("[LobbyZone2D] Connected to APIClient upgrade_purchase_failed signal")

		if api_client.has_signal("credits_updated") and not api_client.credits_updated.is_connected(_on_credits_updated):
			api_client.credits_updated.connect(_on_credits_updated)
			print("[LobbyZone2D] Connected to APIClient credits_updated signal")

	# Connect to UpgradeSystem signals for upgrade effects
	if upgrade_system:
		if upgrade_system.has_signal("upgrade_effects_applied") and not upgrade_system.upgrade_effects_applied.is_connected(_on_upgrade_effects_applied):
			upgrade_system.upgrade_effects_applied.connect(_on_upgrade_effects_applied)
			print("[LobbyZone2D] Connected to UpgradeSystem upgrade_effects_applied signal")

func _load_and_display_player_data() -> void:
	##Load current player data and update all UI displays
	print("[LobbyZone2D] === LOADING AND DISPLAYING PLAYER DATA ===")

	if not LocalPlayerData:
		print("[LobbyZone2D] CRITICAL ERROR - LocalPlayerData not available!")
		return

	if not LocalPlayerData.is_initialized:
		print("[LobbyZone2D] WARNING - LocalPlayerData not ready, skipping initial display")
		return

	# CRITICAL FIX: Display comprehensive data status for debugging
	var player_credits = LocalPlayerData.get_credits()
	var player_inventory = LocalPlayerData.get_inventory()
	var player_upgrades = LocalPlayerData.get_all_upgrades()

	print("[LobbyZone2D] Player data status:")
	print("[LobbyZone2D] - Credits: %d" % player_credits)
	print("[LobbyZone2D] - Inventory items: %d" % player_inventory.size())
	print("[LobbyZone2D] - Upgrades: %s" % player_upgrades)

	if player_inventory.size() > 0:
		print("[LobbyZone2D] - Sample inventory items: %s" % player_inventory.slice(0, min(3, player_inventory.size())))

	# Check if this looks like freshly synced data from 3D scene
	if player_inventory.size() > 0 or player_credits > 100 or player_upgrades.values().any(func(level): return level > 0):
		print("[LobbyZone2D] ✅ Data appears to be synced from 3D scene successfully!")
	else:
		print("[LobbyZone2D] ⚠️  Data appears to be default values - may need to collect items in 3D first")

	# Force UI update with current data
	_update_lobby_ui_with_player_data()
	print("[LobbyZone2D] === PLAYER DATA LOADING COMPLETE ===")

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

## SIGNAL HANDLERS FOR UPGRADE SYSTEM AND API CLIENT - CRITICAL MISSING FUNCTIONALITY

func _on_upgrade_purchase_success(result: Dictionary) -> void:
	##Handle successful upgrade purchase from API
	print("[LobbyZone2D] Upgrade purchase successful: %s" % result)

	var upgrade_type = result.get("upgrade_type", "")
	var new_level = result.get("new_level", 0)
	var cost = result.get("cost", 0)
	var remaining_credits = result.get("remaining_credits", 0)

	# Update LocalPlayerData with the purchase result
	if LocalPlayerData:
		LocalPlayerData.set_credits(remaining_credits)
		LocalPlayerData.set_upgrade_level(upgrade_type, new_level)
		print("[LobbyZone2D] Updated LocalPlayerData with purchase - %s level %d, credits: %d" % [upgrade_type, new_level, remaining_credits])

	# Apply upgrade effects if upgrade system is available
	if upgrade_system and upgrade_system.has_method("apply_upgrade_effects"):
		upgrade_system.apply_upgrade_effects(upgrade_type, new_level, null)  # No player ship in lobby
		print("[LobbyZone2D] Applied upgrade effects for %s level %d" % [upgrade_type, new_level])

	# Update UI immediately
	_update_lobby_ui_with_player_data()
	_populate_upgrade_catalog()  # Refresh catalog with new levels

	# Show success message
	var upgrade_name = upgrade_type.capitalize().replace("_", " ")
	var success_message = "SUCCESS!\nPurchased %s level %d\nCost: %d credits\nRemaining: %d credits" % [upgrade_name, new_level, cost, remaining_credits]
	_update_purchase_result(success_message, Color.GREEN)

	# Clear selection
	current_selected_upgrade = ""
	current_upgrade_cost = 0

func _on_upgrade_purchase_failed(reason: String, upgrade_type: String) -> void:
	##Handle failed upgrade purchase from API
	print("[LobbyZone2D] Upgrade purchase failed: %s - %s" % [upgrade_type, reason])

	# Show error message
	_update_purchase_result("PURCHASE FAILED\n%s\nReason: %s" % [upgrade_type, reason], Color.RED)

func _on_credits_updated(new_credits: int) -> void:
	##Handle credits update from API
	print("[LobbyZone2D] Credits updated via API: %d" % new_credits)

	# Update LocalPlayerData
	if LocalPlayerData:
		LocalPlayerData.set_credits(new_credits)

	# Update UI
	_update_lobby_ui_with_player_data()

	# Refresh upgrade catalog to show affordability changes
	if trading_interface_open:
		_populate_upgrade_catalog()

func _on_upgrade_effects_applied(effects: Dictionary) -> void:
	##Handle upgrade effects being applied
	print("[LobbyZone2D] Upgrade effects applied: %s" % effects)

	# Update UI to reflect any changes (like inventory capacity)
	_update_lobby_ui_with_player_data()

func _on_player_data_updated(data_type: String) -> void:
	##Handle player data update signals from LocalPlayerData
	print("[LobbyZone2D] Player data updated: %s" % data_type)

	# Force UI update when data changes
	_update_lobby_ui_with_player_data()

	# If trading interface is open and credits/upgrades changed, refresh catalog
	if trading_interface_open and (data_type == "credits" or data_type == "upgrades"):
		_populate_upgrade_catalog()

## Selective Trading Methods - Ported from 3D Implementation

func _populate_debris_selection_ui() -> void:
	##Populate the debris selection UI with current inventory
	if not debris_selection_list or not LocalPlayerData:
		return

	# Clear existing selection items
	for child in debris_selection_list.get_children():
		child.queue_free()

	# Group inventory by type
	var inventory = LocalPlayerData.get_inventory()
	var grouped_inventory = _group_inventory_by_type(inventory)
	print("[LobbyZone2D] Populating selection UI with %d debris types" % grouped_inventory.size())

	# Create selection row for each debris type
	for debris_type in grouped_inventory:
		var group_data = grouped_inventory[debris_type]
		var selection_row = _create_debris_selection_row(debris_type, group_data)
		debris_selection_list.add_child(selection_row)

	print("[LobbyZone2D] Created %d debris selection rows" % grouped_inventory.size())

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
	print("[LobbyZone2D] DEBUG - Connected SpinBox signals for %s (min: %d, max: %d)" % [debris_type, quantity_selector.min_value, quantity_selector.max_value])

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
	print("[LobbyZone2D] DEBUG - _on_debris_quantity_changed called - Type: %s, New Quantity: %f, Int Quantity: %d" % [debris_type, new_quantity, quantity])

	# Store or remove from selected_debris based on quantity
	if quantity > 0:
		selected_debris[debris_type] = quantity
		print("[LobbyZone2D] Selected %d %s for sale" % [quantity, debris_type])
	else:
		# Remove from dictionary if quantity is 0 to keep it clean
		if debris_type in selected_debris:
			selected_debris.erase(debris_type)
		print("[LobbyZone2D] Deselected %s (quantity 0)" % debris_type)

	# Debug the selected_debris dictionary state
	print("[LobbyZone2D] DEBUG - selected_debris dictionary: %s" % selected_debris)

	# Update the selected value display for this debris type
	_update_debris_row_value(debris_type)

	# Update overall selection summary (this will enable/disable sell selected button)
	_update_selection_summary()

func _on_debris_quantity_text_submitted(text: String, debris_type: String) -> void:
	##Handle when user types a number and presses Enter in the SpinBox
	print("[LobbyZone2D] DEBUG - Text submitted for %s: '%s'" % [debris_type, text])
	var quantity = int(text)
	_on_debris_quantity_changed(quantity, debris_type)

func _on_debris_quantity_text_changed(text: String, debris_type: String) -> void:
	##Handle when user types in the SpinBox (every character change)
	print("[LobbyZone2D] DEBUG - Text changed for %s: '%s'" % [debris_type, text])
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

	print("[LobbyZone2D] Selected maximum %d %s for sale" % [max_quantity, debris_type])

	# Update displays
	_update_debris_row_value(debris_type)
	_update_selection_summary()

func _get_debris_value(debris_type: String) -> int:
	##Get the individual value for a specific debris type from LocalPlayerData inventory
	if not LocalPlayerData:
		return 0

	var inventory = LocalPlayerData.get_inventory()
	for item in inventory:
		if item.get("type") == debris_type:
			return item.get("value", 0)

	# If not found in current inventory, use default values
	match debris_type:
		"scrap_metal":
			return 5
		"bio_waste":
			return 25
		"ai_component":
			return 500
		"broken_satellite":
			return 150
		"unknown_artifact":
			return 1000
		_:
			return 1  # Default value

func _update_debris_row_value(debris_type: String) -> void:
	##Update the selected value display for a specific debris type
	var selected_quantity = selected_debris.get(debris_type, 0)
	print("[LobbyZone2D] DEBUG - _update_debris_row_value - Type: %s, Selected Quantity: %d" % [debris_type, selected_quantity])

	# Safety check: make sure debris_selection_list exists and hasn't been cleared
	if not debris_selection_list or not debris_selection_list.get_child_count() > 0:
		print("[LobbyZone2D] DEBUG - Debris selection list not available, skipping value update")
		return

	# Find the selected value label
	var selected_value_label = debris_selection_list.get_node_or_null("Row_%s/SelectedValue_%s" % [debris_type, debris_type])
	if not selected_value_label:
		print("[LobbyZone2D] DEBUG - Could not find selected value label for %s (UI may have been refreshed)" % debris_type)
		return

	print("[LobbyZone2D] DEBUG - Found selected value label for %s" % debris_type)

	# Get the individual value for this debris type
	var individual_value = _get_debris_value(debris_type)
	print("[LobbyZone2D] DEBUG - Found individual value for %s: %d" % [debris_type, individual_value])

	# Calculate and display total value for selected quantity
	var total_value = selected_quantity * individual_value
	print("[LobbyZone2D] DEBUG - Calculated total value: %d x %d = %d" % [selected_quantity, individual_value, total_value])

	selected_value_label.text = "%d credits" % total_value
	print("[LobbyZone2D] DEBUG - Updated label text to: %s" % selected_value_label.text)

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

			# Find individual value from LocalPlayerData inventory
			if LocalPlayerData:
				var inventory = LocalPlayerData.get_inventory()
				for item in inventory:
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
			print("[LobbyZone2D] Sell Selected button ENABLED - %d items selected" % total_selected_items)
	else:
		selection_summary_label.text = "No items selected"
		selection_summary_label.add_theme_color_override("font_color", Color.GRAY)

		# Disable sell selected button
		if sell_selected_button:
			sell_selected_button.disabled = true
			print("[LobbyZone2D] Sell Selected button DISABLED - no items selected")

	print("[LobbyZone2D] Selection summary updated - %d items, %d credits, button enabled: %s" %
		[total_selected_items, total_selected_value, not sell_selected_button.disabled if sell_selected_button else false])

func _on_sell_selected_pressed() -> void:
	##Handle sell selected button press - sell the currently selected items
	print("[LobbyZone2D] Sell selected button pressed")

	if not LocalPlayerData:
		print("[LobbyZone2D] ERROR - LocalPlayerData not found!")
		_update_trading_result("System Error: Player data not available!", Color.RED)
		return

	if selected_debris.is_empty():
		_update_trading_result("No items selected to sell!", Color.YELLOW)
		print("[LobbyZone2D] No items selected to sell")
		return

	var inventory = LocalPlayerData.get_inventory()
	var sold_items = []
	var total_value = 0
	var items_to_remove_ids = []

	# Process each selected debris type
	for debris_type in selected_debris:
		var quantity_to_sell = selected_debris[debris_type]
		if quantity_to_sell <= 0:
			continue

		var items_found = 0

		# Find and collect item IDs for removal
		for item in inventory:
			if item.get("type") == debris_type and items_found < quantity_to_sell:
				sold_items.append(item)
				items_to_remove_ids.append(item.get("item_id", ""))
				total_value += item.get("value", 0)
				items_found += 1

		print("[LobbyZone2D] Found %d/%d %s items to sell" % [items_found, quantity_to_sell, debris_type])

	if sold_items.is_empty():
		_update_trading_result("No items found to sell!", Color.YELLOW)
		print("[LobbyZone2D] No items found to sell")
		return

	# Remove items from inventory using LocalPlayerData API
	for item_id in items_to_remove_ids:
		if item_id != "":
			LocalPlayerData.remove_inventory_item(item_id)
			print("[LobbyZone2D] Removed item with ID: %s" % item_id)

	# Add credits
	LocalPlayerData.add_credits(total_value)

	# Clear selections
	selected_debris.clear()

	# Update UI immediately with forced refresh
	_update_lobby_ui_with_player_data()

	# CRITICAL FIX: Force inventory display refresh immediately
	var current_inventory = LocalPlayerData.get_inventory()
	var current_capacity = _get_inventory_capacity_from_upgrades(LocalPlayerData.get_all_upgrades())
	_update_inventory_display(current_inventory, current_capacity)
	last_inventory_size = current_inventory.size()  # Update tracking variable

	# Refresh the selection UI with new inventory
	_populate_debris_selection_ui()
	_update_selection_summary()

	# CRITICAL FIX: Refresh upgrade catalog after credit update
	if trading_interface and trading_interface.visible:
		_populate_upgrade_catalog()
		print("[LobbyZone2D] Upgrade catalog refreshed after selling selected items")

	# Show success message
	var success_message = "SUCCESS!\nSold %d selected items for %d credits\nTotal Credits: %d" % [sold_items.size(), total_value, LocalPlayerData.get_credits()]
	_update_trading_result(success_message, Color.GREEN)

	print("[LobbyZone2D] Selective sale completed - %d items sold for %d credits" % [sold_items.size(), total_value])
