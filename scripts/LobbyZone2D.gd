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

# MARKETPLACE Tab UI references - Phase 1.1 Implementation
@onready var marketplace_tab: Control = $UILayer/HUD/TradingInterface/TradingTabs/MARKETPLACE
@onready var marketplace_content: VBoxContainer = $UILayer/HUD/TradingInterface/TradingTabs/MARKETPLACE/MarketplaceContent
@onready var marketplace_status_label: Label = $UILayer/HUD/TradingInterface/TradingTabs/MARKETPLACE/MarketplaceContent/MarketplaceStatus
@onready var marketplace_listings_scroll: ScrollContainer = $UILayer/HUD/TradingInterface/TradingTabs/MARKETPLACE/MarketplaceContent/MarketplaceListings
@onready var marketplace_listings_container: GridContainer = $UILayer/HUD/TradingInterface/TradingTabs/MARKETPLACE/MarketplaceContent/MarketplaceListings/MarketplaceGrid
@onready var marketplace_controls: HBoxContainer = $UILayer/HUD/TradingInterface/TradingTabs/MARKETPLACE/MarketplaceContent/MarketplaceControls
@onready var marketplace_refresh_button: Button = $UILayer/HUD/TradingInterface/TradingTabs/MARKETPLACE/MarketplaceContent/MarketplaceControls/RefreshButton
@onready var post_item_button: Button = $UILayer/HUD/TradingInterface/TradingTabs/MARKETPLACE/MarketplaceContent/MarketplaceControls/SellItemButton

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

# Marketplace state variables - Phase 1.1 Implementation
var marketplace_listings: Array[Dictionary] = []  # Store current marketplace listings
var marketplace_loading: bool = false
var marketplace_last_refresh: float = 0.0
var marketplace_refresh_cooldown: float = 2.0  # Minimum seconds between refreshes

# Phase 1.4: Item posting dialog variables
var posting_dialog: AcceptDialog
var posting_item_dropdown: OptionButton
var posting_quantity_spinbox: SpinBox
var posting_price_spinbox: SpinBox
var posting_confirm_button: Button
var posting_total_label: Label
var posting_validation_label: Label
var posting_dialog_initialized: bool = false

# Phase 1.5: Purchase confirmation dialog variables
var purchase_dialog: AcceptDialog
var purchase_item_label: Label
var purchase_seller_label: Label
var purchase_price_label: Label
var purchase_confirm_button: Button
var purchase_current_listing: Dictionary = {}
var purchase_dialog_initialized: bool = false

# Listing removal dialog variables
var removal_dialog: AcceptDialog
var removal_item_label: Label
var removal_price_label: Label
var removal_confirm_button: Button
var removal_current_listing: Dictionary = {}
var removal_dialog_initialized: bool = false

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

# WebSocket and multiplayer state
var websocket_connected: bool = false
var connection_status: String = "disconnected"
var remote_players: Dictionary = {}  # player_id -> RemoteLobbyPlayer2D instance
var remote_player_scene: PackedScene

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
	_setup_player_position_broadcasting()
	_load_and_display_player_data()

	print("[LobbyZone2D] Exit boundaries ready for signal detection")
	print("[LobbyZone2D] Trading computer interaction ready")

	# Setup WebSocket connection and multiplayer
	_setup_websocket_connection()
	_load_remote_player_scene()

	# Mark lobby as ready
	lobby_loaded = true
	lobby_ready.emit()
	print("[LobbyZone2D] Lobby initialization complete with dynamic scaling and WebSocket ready")

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

	# Check marketplace UI references - Phase 1.1
	if not marketplace_tab: missing_nodes.append("marketplace_tab")
	if not marketplace_content: missing_nodes.append("marketplace_content")
	if not marketplace_status_label: missing_nodes.append("marketplace_status_label")
	if not marketplace_listings_scroll: missing_nodes.append("marketplace_listings_scroll")
	if not marketplace_listings_container: missing_nodes.append("marketplace_listings_container")
	if not marketplace_controls: missing_nodes.append("marketplace_controls")
	if not marketplace_refresh_button: missing_nodes.append("marketplace_refresh_button")
	if not post_item_button: missing_nodes.append("post_item_button")

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

	# MARKETPLACE Tab button connections - Phase 1.1 Implementation
	if marketplace_refresh_button:
		if not marketplace_refresh_button.pressed.is_connected(_on_marketplace_refresh_pressed):
			marketplace_refresh_button.pressed.connect(_on_marketplace_refresh_pressed)
			print("[LobbyZone2D] Connected marketplace_refresh_button")

	if post_item_button:
		if not post_item_button.pressed.is_connected(_on_post_item_pressed):
			post_item_button.pressed.connect(_on_post_item_pressed)
			print("[LobbyZone2D] Connected post_item_button")

	# CRITICAL FIX: Connect TradingMarketplace signals during initialization
	if TradingMarketplace:
		# Connect marketplace signals if not already connected
		if not TradingMarketplace.listings_received.is_connected(_on_marketplace_listings_received):
			TradingMarketplace.listings_received.connect(_on_marketplace_listings_received)
			print("[LobbyZone2D] Connected TradingMarketplace listings_received signal")

		if not TradingMarketplace.listing_posted.is_connected(_on_item_posting_result):
			TradingMarketplace.listing_posted.connect(_on_item_posting_result)
			print("[LobbyZone2D] Connected TradingMarketplace listing_posted signal")

		if not TradingMarketplace.listing_removed.is_connected(_on_listing_removal_result):
			TradingMarketplace.listing_removed.connect(_on_listing_removal_result)
			print("[LobbyZone2D] Connected TradingMarketplace listing_removed signal")

		if not TradingMarketplace.item_purchased.is_connected(_on_item_purchase_result):
			TradingMarketplace.item_purchased.connect(_on_item_purchase_result)
			print("[LobbyZone2D] Connected TradingMarketplace item_purchased signal")

		if not TradingMarketplace.api_error.is_connected(_on_marketplace_api_error):
			TradingMarketplace.api_error.connect(_on_marketplace_api_error)
			print("[LobbyZone2D] Connected TradingMarketplace api_error signal")

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

	# Clear existing upgrade buttons - FIXED: Immediately remove from scene tree
	for child in upgrade_grid.get_children():
		upgrade_grid.remove_child(child)
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

		# Phase 1.1: Initialize marketplace when trading interface opens
		_initialize_marketplace_interface()

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

	# Disconnect from WebSocket before leaving
	_disconnect_from_lobby()

	# Store lobby state if needed
	if LocalPlayerData:
		LocalPlayerData.save_player_data()

	# Change scene back to 3D zone
	get_tree().change_scene_to_file("res://scenes/zones/ZoneMain3D.tscn")

## MARKETPLACE BUTTON HANDLERS - Phase 1.1 Implementation

func _on_marketplace_refresh_pressed() -> void:
	##Handle marketplace refresh button press
	print("[LobbyZone2D] Marketplace refresh button pressed")

	# Rate limiting - prevent spam refreshes
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = current_time.hour * 3600 + current_time.minute * 60 + current_time.second

	if current_timestamp - marketplace_last_refresh < marketplace_refresh_cooldown:
		var remaining = marketplace_refresh_cooldown - (current_timestamp - marketplace_last_refresh)
		_update_marketplace_status("Please wait %.1f seconds before refreshing again" % remaining, Color.YELLOW)
		return

	marketplace_last_refresh = current_timestamp
	_refresh_marketplace_listings()

func _on_post_item_pressed() -> void:
	##Handle post item button press
	print("[LobbyZone2D] Post item button pressed")

	if not LocalPlayerData or not LocalPlayerData.is_initialized:
		_update_marketplace_status("Player data not available!", Color.RED)
		return

	var inventory = LocalPlayerData.get_inventory()
	if inventory.is_empty():
		_update_marketplace_status("No items in inventory to sell!\n\nCollect debris in the 3D world first.", Color.YELLOW)
		return

	# Phase 1.4: Show item posting dialog
	_show_item_posting_dialog()

func _show_item_posting_dialog() -> void:
	##Show the item posting dialog for Phase 1.4
	print("[LobbyZone2D] Opening item posting dialog")

	# Initialize dialog if not done yet
	if not posting_dialog_initialized:
		_initialize_posting_dialog()

	# INVENTORY VALIDATION ENHANCEMENT: Refresh listings cache for accurate validation
	if TradingMarketplace:
		print("[LobbyZone2D] Refreshing marketplace cache before posting dialog")
		TradingMarketplace.refresh_listings_for_validation()
		# Wait a brief moment for cache refresh, then populate
		await get_tree().create_timer(0.5).timeout

	# Populate with current inventory
	_populate_posting_dialog()

	# Show the dialog
	if posting_dialog:
		posting_dialog.popup_centered()

func _initialize_posting_dialog() -> void:
	##Initialize the item posting dialog UI (Phase 1.4)
	print("[LobbyZone2D] Initializing item posting dialog")

	# Create main dialog
	posting_dialog = AcceptDialog.new()
	posting_dialog.title = "Post Item for Sale"
	posting_dialog.size = Vector2(450, 350)
	posting_dialog.unresizable = false

	# Main container
	var dialog_vbox = VBoxContainer.new()
	dialog_vbox.add_theme_constant_override("separation", 15)
	posting_dialog.add_child(dialog_vbox)

	# Title label
	var title_label = Label.new()
	title_label.text = "Select an item to post for sale:"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.CYAN)
	dialog_vbox.add_child(title_label)

	# Item selection
	var item_container = HBoxContainer.new()
	var item_label = Label.new()
	item_label.text = "Item:"
	item_label.custom_minimum_size = Vector2(80, 0)
	posting_item_dropdown = OptionButton.new()
	posting_item_dropdown.custom_minimum_size = Vector2(250, 30)
	posting_item_dropdown.item_selected.connect(_on_posting_item_selected)
	item_container.add_child(item_label)
	item_container.add_child(posting_item_dropdown)
	dialog_vbox.add_child(item_container)

	# Quantity selection
	var quantity_container = HBoxContainer.new()
	var quantity_label = Label.new()
	quantity_label.text = "Quantity:"
	quantity_label.custom_minimum_size = Vector2(80, 0)
	posting_quantity_spinbox = SpinBox.new()
	posting_quantity_spinbox.min_value = 1
	posting_quantity_spinbox.max_value = 999
	posting_quantity_spinbox.value = 1
	posting_quantity_spinbox.custom_minimum_size = Vector2(100, 30)
	posting_quantity_spinbox.value_changed.connect(_on_posting_quantity_changed)
	quantity_container.add_child(quantity_label)
	quantity_container.add_child(posting_quantity_spinbox)
	dialog_vbox.add_child(quantity_container)

	# Price per unit selection
	var price_container = HBoxContainer.new()
	var price_label = Label.new()
	price_label.text = "Price Each:"
	price_label.custom_minimum_size = Vector2(80, 0)
	posting_price_spinbox = SpinBox.new()
	posting_price_spinbox.min_value = 1
	posting_price_spinbox.max_value = 10000
	posting_price_spinbox.value = 100
	posting_price_spinbox.custom_minimum_size = Vector2(100, 30)
	posting_price_spinbox.value_changed.connect(_on_posting_price_changed)
	var credits_suffix = Label.new()
	credits_suffix.text = " credits"
	price_container.add_child(price_label)
	price_container.add_child(posting_price_spinbox)
	price_container.add_child(credits_suffix)
	dialog_vbox.add_child(price_container)

	# Total price display
	posting_total_label = Label.new()
	posting_total_label.text = "Total: 100 credits"
	posting_total_label.add_theme_color_override("font_color", Color.YELLOW)
	posting_total_label.add_theme_font_size_override("font_size", 14)
	posting_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_vbox.add_child(posting_total_label)

	# Validation message area
	posting_validation_label = Label.new()
	posting_validation_label.text = ""
	posting_validation_label.add_theme_color_override("font_color", Color.RED)
	posting_validation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	posting_validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	posting_validation_label.custom_minimum_size = Vector2(0, 40)
	dialog_vbox.add_child(posting_validation_label)

	# Buttons
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(100, 35)
	cancel_button.pressed.connect(_on_posting_cancel_pressed)
	posting_confirm_button = Button.new()
	posting_confirm_button.text = "Post for Sale"
	posting_confirm_button.custom_minimum_size = Vector2(120, 35)
	posting_confirm_button.pressed.connect(_on_posting_confirm_pressed)
	button_container.add_child(cancel_button)
	button_container.add_child(posting_confirm_button)
	dialog_vbox.add_child(button_container)

	# Add to scene
	ui_layer.add_child(posting_dialog)
	posting_dialog_initialized = true

	print("[LobbyZone2D] Item posting dialog initialized")

func _populate_posting_dialog() -> void:
	##Populate the posting dialog with sellable inventory items
	print("[LobbyZone2D] Populating posting dialog with inventory")

	if not posting_item_dropdown or not LocalPlayerData:
		return

	posting_item_dropdown.clear()

	# Get inventory and group by item type
	var inventory = LocalPlayerData.get_inventory()
	var item_counts = {}

	for item in inventory:
		var item_type = item.get("type", "")
		if item_type != "":
			item_counts[item_type] = item_counts.get(item_type, 0) + item.get("quantity", 0)

	# Check which items can be sold (using enhanced TradingMarketplace validation)
	var sellable_items = []
	for item_type in item_counts:
		var inventory_quantity = item_counts[item_type]
		if TradingMarketplace and TradingMarketplace.can_sell_item(item_type, item_type, 1):
			var display_name = _format_item_name(item_type)

			# INVENTORY VALIDATION ENHANCEMENT: Show available quantity accounting for already-listed items
			var validation_result = TradingMarketplace.can_sell_item_enhanced(item_type, 1)
			var available_to_list = validation_result.get("available_to_list", inventory_quantity)
			var listed_quantity = TradingMarketplace.get_player_listed_quantity(item_type)

			# Enhanced display with listing information
			var display_text = "%s (%d in inventory, %d listed, %d available)" % [display_name, inventory_quantity, listed_quantity, available_to_list]
			posting_item_dropdown.add_item(display_text)
			posting_item_dropdown.set_item_metadata(posting_item_dropdown.get_item_count() - 1, {
				"type": item_type,
				"available": available_to_list,  # Use available_to_list instead of raw inventory
				"inventory_total": inventory_quantity,
				"already_listed": listed_quantity,
				"base_value": _get_actual_item_value_for_dialog(inventory, item_type)
			})
			sellable_items.append(item_type)

			print("[LobbyZone2D] ENHANCED VALIDATION - %s: %d inventory, %d listed, %d available to list" % [item_type, inventory_quantity, listed_quantity, available_to_list])

	if sellable_items.is_empty():
		posting_item_dropdown.add_item("No sellable items (need 100+ credit value items)")
		posting_item_dropdown.disabled = true
		posting_confirm_button.disabled = true
		posting_validation_label.text = "Collect high-value debris in the 3D world first!"
	else:
		posting_item_dropdown.disabled = false
		posting_confirm_button.disabled = false
		posting_validation_label.text = ""
		# Select first item and update price suggestions
		if posting_item_dropdown.get_item_count() > 0:
			posting_item_dropdown.selected = 0
			_on_posting_item_selected(0)

func _on_posting_item_selected(index: int) -> void:
	##Handle item selection in posting dialog
	if not posting_item_dropdown or index < 0 or index >= posting_item_dropdown.get_item_count():
		return

	var item_data = posting_item_dropdown.get_item_metadata(index)
	if not item_data:
		return

	var available_quantity = item_data.get("available", 1)
	var base_value = item_data.get("base_value", 100)

	# Update quantity limits
	posting_quantity_spinbox.max_value = available_quantity
	posting_quantity_spinbox.value = min(posting_quantity_spinbox.value, available_quantity)

	# Suggest a reasonable price (base value + 25%)
	var suggested_price = int(base_value * 1.25)
	posting_price_spinbox.value = suggested_price

	_update_posting_dialog_validation()

func _on_posting_quantity_changed(value: float) -> void:
	##Handle quantity change in posting dialog
	_update_posting_dialog_validation()

func _on_posting_price_changed(value: float) -> void:
	##Handle price change in posting dialog
	_update_posting_dialog_validation()

func _update_posting_dialog_validation() -> void:
	##Update validation and total price in posting dialog
	if not posting_item_dropdown or not posting_quantity_spinbox or not posting_price_spinbox:
		return

	var selected_index = posting_item_dropdown.selected
	if selected_index < 0:
		return

	var item_data = posting_item_dropdown.get_item_metadata(selected_index)
	if not item_data:
		return

	var item_type = item_data.get("type", "")
	var available_quantity = item_data.get("available", 1)
	var base_value = item_data.get("base_value", 100)
	var quantity = int(posting_quantity_spinbox.value)
	var price_each = int(posting_price_spinbox.value)
	var total_price = quantity * price_each

	# Update total label
	posting_total_label.text = "Total: %d credits (%d × %d)" % [total_price, quantity, price_each]

	# Validate price range using actual item value (same as backend)
	var min_price = max(1, base_value * 0.5)
	var max_price = base_value * 3.0
	var validation_message = ""

	if quantity > available_quantity:
		validation_message = "Quantity exceeds available items!"
		posting_confirm_button.disabled = true
	elif price_each < min_price:
		validation_message = "Price too low! Minimum: %d credits" % min_price
		posting_confirm_button.disabled = true
	elif price_each > max_price:
		validation_message = "Price too high! Maximum: %d credits" % max_price
		posting_confirm_button.disabled = true
	else:
		validation_message = "Ready to post!"
		posting_validation_label.add_theme_color_override("font_color", Color.GREEN)
		posting_confirm_button.disabled = false

	posting_validation_label.text = validation_message

func _on_posting_confirm_pressed() -> void:
	##Handle confirm button in posting dialog
	print("[LobbyZone2D] Confirming item posting")

	var selected_index = posting_item_dropdown.selected
	if selected_index < 0:
		return

	var item_data = posting_item_dropdown.get_item_metadata(selected_index)
	var item_type = item_data.get("type", "")
	var item_name = _format_item_name(item_type)
	var quantity = int(posting_quantity_spinbox.value)
	var price_each = int(posting_price_spinbox.value)

	print("[LobbyZone2D] Posting %d %s for %d credits each" % [quantity, item_name, price_each])

	# CRITICAL FIX: Remove conditional signal connections - they're now connected during initialization
	if TradingMarketplace:
		# FIXED: Pass the original item_type (key) for inventory validation, not the formatted name
		TradingMarketplace.post_item_for_sale(item_type, item_type, quantity, price_each)
	else:
		print("[LobbyZone2D] ERROR: TradingMarketplace not available")
		_update_marketplace_status("Trading system not available", Color.RED)
		return

	# Close dialog
	posting_dialog.hide()

	# Show posting status
	_update_marketplace_status("Posting item for sale...", Color.WHITE)

func _on_posting_cancel_pressed() -> void:
	##Handle cancel button in posting dialog
	print("[LobbyZone2D] Cancelling item posting")
	posting_dialog.hide()

func _on_item_posting_result(success: bool, listing_id: String) -> void:
	##Handle result of item posting
	print("[LobbyZone2D] Item posting result - Success: %s, ID: %s" % [success, listing_id])

	if success:
		_update_marketplace_status("Item posted successfully! ID: %s" % listing_id, Color.GREEN)
		# Refresh marketplace to show new listing
		_refresh_marketplace_listings()
	else:
		_update_marketplace_status("Failed to post item. Please try again.", Color.RED)

func _get_actual_item_value_for_dialog(inventory: Array[Dictionary], item_type: String) -> int:
	##Get actual value for item type from inventory (no hardcoded values)
	# Find the first item of this type in inventory and return its actual value
	for item in inventory:
		if item.get("type", "") == item_type:
			return item.get("value", 0)

	# Fallback to default values only if item not found in inventory
	var default_values = {
		"scrap_metal": 10,
		"broken_satellite": 150,
		"ai_component": 150,
		"unknown_artifact": 500,
		"quantum_core": 1000
	}
	return default_values.get(item_type, 50)

func _refresh_marketplace_listings() -> void:
	##Refresh marketplace listings from the API
	print("[LobbyZone2D] Refreshing marketplace listings...")

	if marketplace_loading:
		print("[LobbyZone2D] Marketplace refresh already in progress")
		return

	marketplace_loading = true
	_update_marketplace_status("Loading marketplace listings...", Color.WHITE)

	# Get listings from TradingMarketplace API
	if TradingMarketplace:
		# CRITICAL FIX: Remove conditional signal connections - they're now connected during initialization
		# Signals are already connected, just call the API method
		TradingMarketplace.get_marketplace_listings()
	else:
		print("[LobbyZone2D] ERROR: TradingMarketplace not available")
		marketplace_loading = false
		_update_marketplace_status("Marketplace system not available", Color.RED)

func _on_marketplace_listings_received(listings: Array[Dictionary]) -> void:
	##Handle marketplace listings received from API
	print("[LobbyZone2D] Received %d marketplace listings" % listings.size())

	marketplace_loading = false
	marketplace_listings = listings
	_populate_marketplace_listings()

func _on_marketplace_api_error(error_message: String) -> void:
	##Handle marketplace API error
	print("[LobbyZone2D] Marketplace API error: %s" % error_message)

	marketplace_loading = false

	# Check if this is a connection error (API unavailable) vs API error
	if error_message.find("code 0") != -1 or error_message.find("Failed to send") != -1:
		# Check if we have a configured AWS endpoint (real API)
		var api_url = TradingConfig.get_api_base_url()
		if api_url.contains("your-api-gateway-id") or api_url.contains("your-region"):
			# Default/template URL - show mock data for development
			print("[LobbyZone2D] Using mock data (API template URL not configured)")
			_show_mock_marketplace_data()
		else:
			# Real AWS URL configured but not responding - show connection error
			_update_marketplace_status("Cannot connect to trading API\nCheck your internet connection", Color.RED)
	else:
		_update_marketplace_status("Error loading marketplace: %s" % error_message, Color.RED)

func _populate_marketplace_listings() -> void:
	##Populate the marketplace UI with current listings
	print("[LobbyZone2D] Populating marketplace with %d listings" % marketplace_listings.size())

	if not marketplace_listings_container:
		print("[LobbyZone2D] ERROR: Marketplace listings container not found")
		return

	# Clear existing listings
	for child in marketplace_listings_container.get_children():
		child.queue_free()

	if marketplace_listings.is_empty():
		_update_marketplace_status("No items for sale in the marketplace", Color.GRAY)
		_add_no_listings_message()
		return

	# Create centering structure like the upgrades panel
	var center_container = CenterContainer.new()
	center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var listings_grid = GridContainer.new()
	listings_grid.columns = 1
	listings_grid.add_theme_constant_override("v_separation", 10)

	center_container.add_child(listings_grid)
	marketplace_listings_container.add_child(center_container)

	print("[LobbyZone2D] Created centered structure for marketplace listings")

	# Add each listing to the centered grid
	for listing in marketplace_listings:
		_create_marketplace_listing_item_for_grid(listing, listings_grid)

	_update_marketplace_status("Marketplace loaded - %d items available" % marketplace_listings.size(), Color.GREEN)

func _create_marketplace_listing_item(listing: Dictionary) -> void:
	##Create a UI item for a marketplace listing
	var listing_container = PanelContainer.new()
	listing_container.custom_minimum_size = Vector2(400, 120)
	listing_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Add a subtle background panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style_box.border_color = Color(0.2, 0.4, 0.6, 0.6)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	listing_container.add_theme_stylebox_override("panel", style_box)

	# Main content container
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)
	listing_container.add_child(content_vbox)

	# Item name and quantity
	var item_label = Label.new()
	var item_name = listing.get("item_name", "Unknown Item")
	var quantity = listing.get("quantity", 1)
	var display_name = _format_item_name(item_name)
	item_label.text = "[%s] x%d" % [display_name, quantity]
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_color_override("font_color", Color.CYAN)
	item_label.add_theme_font_size_override("font_size", 16)
	content_vbox.add_child(item_label)

	# Seller info
	var seller_label = Label.new()
	var seller_name = listing.get("seller_name", "Unknown")
	seller_label.text = "Seller: %s" % seller_name
	seller_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seller_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	seller_label.add_theme_font_size_override("font_size", 12)
	content_vbox.add_child(seller_label)

	# Price info - FIXED: Use asking_price and calculate total properly
	var price_label = Label.new()
	var asking_price = listing.get("asking_price", 0)
	var total_price = asking_price * quantity

	if quantity > 1:
		price_label.text = "Price: %d credits each\nTotal: %d credits" % [asking_price, total_price]
	else:
		price_label.text = "Price: %d credits" % total_price

	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color.YELLOW)
	price_label.add_theme_font_size_override("font_size", 14)
	content_vbox.add_child(price_label)

	# Buy button (Phase 1.5: Now enabled with purchase confirmation)
	var buy_button = Button.new()
	buy_button.text = "BUY NOW"
	buy_button.custom_minimum_size = Vector2(120, 30)

	# Phase 1.5: Enable buy button and connect to purchase handler
	var can_purchase = _validate_listing_purchase(listing)
	buy_button.disabled = not can_purchase.success

	if can_purchase.success:
		buy_button.pressed.connect(_on_buy_button_pressed.bind(listing))
		buy_button.add_theme_color_override("font_color", Color.GREEN)
	else:
		buy_button.tooltip_text = can_purchase.error_message
		buy_button.add_theme_color_override("font_color", Color.GRAY)

	# Style the button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.3, 0.8) if can_purchase.success else Color(0.15, 0.15, 0.2, 0.6)
	button_style.border_color = Color(0.3, 0.3, 0.4) if can_purchase.success else Color(0.2, 0.2, 0.3)
	button_style.border_width_left = 1
	button_style.border_width_right = 1
	button_style.border_width_top = 1
	button_style.border_width_bottom = 1
	buy_button.add_theme_stylebox_override("normal", button_style)

	content_vbox.add_child(buy_button)

	# Create a container for this listing with separator
	var listing_wrapper = VBoxContainer.new()
	listing_wrapper.add_child(listing_container)

	# Add separator like the upgrades panel
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 5)
	listing_wrapper.add_child(separator)

	marketplace_listings_container.add_child(listing_wrapper)

func _create_marketplace_listing_item_for_grid(listing: Dictionary, target_grid: GridContainer) -> void:
	##Create a UI item for a marketplace listing and add it to the specified grid
	var listing_container = PanelContainer.new()
	listing_container.custom_minimum_size = Vector2(400, 120)
	listing_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Add a subtle background panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style_box.border_color = Color(0.2, 0.4, 0.6, 0.6)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	listing_container.add_theme_stylebox_override("panel", style_box)

	# Main content container
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)
	listing_container.add_child(content_vbox)

	# Item name and quantity
	var item_label = Label.new()
	var item_name = listing.get("item_name", "Unknown Item")
	var quantity = listing.get("quantity", 1)
	var display_name = _format_item_name(item_name)
	item_label.text = "[%s] x%d" % [display_name, quantity]
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_color_override("font_color", Color.CYAN)
	item_label.add_theme_font_size_override("font_size", 16)
	content_vbox.add_child(item_label)

	# Seller info
	var seller_label = Label.new()
	var seller_name = listing.get("seller_name", "Unknown")
	seller_label.text = "Seller: %s" % seller_name
	seller_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seller_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	seller_label.add_theme_font_size_override("font_size", 12)
	content_vbox.add_child(seller_label)

	# Price info - FIXED: Use asking_price and calculate total properly
	var price_label = Label.new()
	var asking_price = listing.get("asking_price", 0)
	var total_price = asking_price * quantity

	if quantity > 1:
		price_label.text = "Price: %d credits each\nTotal: %d credits" % [asking_price, total_price]
	else:
		price_label.text = "Price: %d credits" % total_price

	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color.YELLOW)
	price_label.add_theme_font_size_override("font_size", 14)
	content_vbox.add_child(price_label)

	# Action button - either BUY or REMOVE depending on ownership
	var action_button = Button.new()
	action_button.custom_minimum_size = Vector2(120, 30)

	# Check if this is the player's own listing
	var seller_id = listing.get("seller_id", "")
	var player_id = LocalPlayerData.get_player_id() if LocalPlayerData else ""
	var is_own_listing = (seller_id == player_id)

	if is_own_listing:
		# Show REMOVE LISTING button for own listings
		action_button.text = "REMOVE LISTING"
		action_button.pressed.connect(_on_remove_button_pressed.bind(listing))
		action_button.add_theme_color_override("font_color", Color.ORANGE)
		action_button.tooltip_text = "Remove your listing from marketplace"

		# Style for remove button
		var remove_style = StyleBoxFlat.new()
		remove_style.bg_color = Color(0.3, 0.2, 0.1, 0.8)
		remove_style.border_color = Color(0.4, 0.3, 0.2)
		remove_style.border_width_left = 1
		remove_style.border_width_right = 1
		remove_style.border_width_top = 1
		remove_style.border_width_bottom = 1
		action_button.add_theme_stylebox_override("normal", remove_style)
	else:
		# Show BUY button for other players' listings (Phase 1.5: Now enabled with purchase confirmation)
		action_button.text = "BUY NOW"

		# Phase 1.5: Enable buy button and connect to purchase handler
		var can_purchase = _validate_listing_purchase(listing)
		action_button.disabled = not can_purchase.success

		if can_purchase.success:
			action_button.pressed.connect(_on_buy_button_pressed.bind(listing))
			action_button.add_theme_color_override("font_color", Color.GREEN)
		else:
			action_button.tooltip_text = can_purchase.error_message
			action_button.add_theme_color_override("font_color", Color.GRAY)

		# Style for buy button
		var buy_style = StyleBoxFlat.new()
		buy_style.bg_color = Color(0.2, 0.2, 0.3, 0.8) if can_purchase.success else Color(0.15, 0.15, 0.2, 0.6)
		buy_style.border_color = Color(0.3, 0.3, 0.4) if can_purchase.success else Color(0.2, 0.2, 0.3)
		buy_style.border_width_left = 1
		buy_style.border_width_right = 1
		buy_style.border_width_top = 1
		buy_style.border_width_bottom = 1
		action_button.add_theme_stylebox_override("normal", buy_style)

	content_vbox.add_child(action_button)

	# Create a container for this listing with separator (like upgrades panel)
	var listing_wrapper = VBoxContainer.new()
	listing_wrapper.add_child(listing_container)

	# Add separator like the upgrades panel
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 5)
	listing_wrapper.add_child(separator)

	target_grid.add_child(listing_wrapper)

func _update_marketplace_status(message: String, color: Color) -> void:
	##Update marketplace status display
	if marketplace_status_label:
		marketplace_status_label.text = message
		marketplace_status_label.modulate = color
		print("[LobbyZone2D] Marketplace status: %s" % message)

func _initialize_marketplace_interface() -> void:
	##Initialize marketplace interface when trading interface opens
	print("[LobbyZone2D] Initializing marketplace interface")

	# Set initial marketplace status
	_update_marketplace_status("Marketplace ready - Click REFRESH to load listings", Color.WHITE)

	# Clear any existing listings
	if marketplace_listings_container:
		for child in marketplace_listings_container.get_children():
			child.queue_free()

	# Reset marketplace state
	marketplace_listings.clear()
	marketplace_loading = false

	print("[LobbyZone2D] Marketplace interface initialized")

func _show_mock_marketplace_data() -> void:
	##Show mock marketplace data for development/testing when API is unavailable
	print("[LobbyZone2D] Mock data disabled - showing empty marketplace")

	# Clear mock marketplace listings (no test data)
	marketplace_listings = []

	# Populate the UI with empty data (will show "no listings" message)
	_populate_marketplace_listings()

	# Update status to indicate API is unavailable but no mock data
	_update_marketplace_status("Marketplace unavailable - API not configured", Color.ORANGE)

func _add_no_listings_message() -> void:
	##Add a message when no listings are available
	if not marketplace_listings_container:
		return

	# Create the same centering structure as regular listings
	var center_container = CenterContainer.new()
	center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var message_grid = GridContainer.new()
	message_grid.columns = 1

	var message_wrapper = VBoxContainer.new()
	message_wrapper.custom_minimum_size = Vector2(400, 200)
	message_wrapper.add_theme_constant_override("separation", 10)

	# Main message
	var no_listings_label = Label.new()
	no_listings_label.text = "No items for sale in the marketplace"
	no_listings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_listings_label.add_theme_color_override("font_color", Color.YELLOW)
	no_listings_label.add_theme_font_size_override("font_size", 18)
	message_wrapper.add_child(no_listings_label)

	# Helpful tip
	var tip_label = Label.new()
	tip_label.text = "Be the first to post something for sale!\nCollect valuable debris in the 3D world and return here to trade."
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	tip_label.add_theme_font_size_override("font_size", 14)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_wrapper.add_child(tip_label)

	message_grid.add_child(message_wrapper)
	center_container.add_child(message_grid)
	marketplace_listings_container.add_child(center_container)

func _format_item_name(item_name: String) -> String:
	##Format item names for better display in marketplace
	var name_map = {
		"ai_component": "AI Component",
		"unknown_artifact": "Unknown Artifact",
		"broken_satellite": "Broken Satellite",
		"quantum_core": "Quantum Core",
		"scrap_metal": "Scrap Metal"
	}

	return name_map.get(item_name, item_name.capitalize().replace("_", " "))

## WebSocket and Multiplayer Methods

func _setup_websocket_connection() -> void:
	"""Setup WebSocket connection and signal handlers"""
	print("[LobbyZone2D] Setting up WebSocket connection")

	if not LobbyController:
		print("[LobbyZone2D] ERROR: LobbyController not available!")
		return

	# Connect to LobbyController signals
	if not LobbyController.connected_to_lobby.is_connected(_on_websocket_connected):
		LobbyController.connected_to_lobby.connect(_on_websocket_connected)

	if not LobbyController.disconnected_from_lobby.is_connected(_on_websocket_disconnected):
		LobbyController.disconnected_from_lobby.connect(_on_websocket_disconnected)

	if not LobbyController.connection_failed.is_connected(_on_websocket_connection_failed):
		LobbyController.connection_failed.connect(_on_websocket_connection_failed)

	if not LobbyController.remote_player_joined.is_connected(_on_remote_player_joined):
		LobbyController.remote_player_joined.connect(_on_remote_player_joined)

	if not LobbyController.remote_player_left.is_connected(_on_remote_player_left):
		LobbyController.remote_player_left.connect(_on_remote_player_left)

	if not LobbyController.remote_player_position_updated.is_connected(_on_remote_player_position_updated):
		LobbyController.remote_player_position_updated.connect(_on_remote_player_position_updated)

	if not LobbyController.lobby_state_received.is_connected(_on_lobby_state_received):
		LobbyController.lobby_state_received.connect(_on_lobby_state_received)

	if not LobbyController.connection_status_changed.is_connected(_on_connection_status_changed):
		LobbyController.connection_status_changed.connect(_on_connection_status_changed)

	print("[LobbyZone2D] WebSocket signal handlers connected")

	# Start connection to lobby
	_connect_to_lobby()

func _load_remote_player_scene() -> void:
	"""Load the remote player scene for spawning"""
	# Since RemoteLobbyPlayer2D is just a script, we'll create the scene structure programmatically
	print("[LobbyZone2D] Remote player scene will be created programmatically")

func _connect_to_lobby() -> void:
	"""Connect to the lobby WebSocket"""
	print("[LobbyZone2D] Connecting to lobby WebSocket...")

	if LobbyController:
		LobbyController.connect_to_lobby()
		_update_connection_status_display("connecting")
	else:
		print("[LobbyZone2D] ERROR: LobbyController not available for connection")

func _disconnect_from_lobby() -> void:
	"""Disconnect from the lobby WebSocket"""
	print("[LobbyZone2D] Disconnecting from lobby WebSocket...")

	if LobbyController and LobbyController.is_lobby_connected():
		LobbyController.disconnect_from_lobby()

	# Clean up remote players
	_cleanup_remote_players()

func _cleanup_remote_players() -> void:
	"""Remove all remote players from the lobby"""
	print("[LobbyZone2D] Cleaning up %d remote players" % remote_players.size())

	for player_id in remote_players.keys():
		var remote_player = remote_players[player_id]
		if is_instance_valid(remote_player):
			remote_player.queue_free()

	remote_players.clear()

## WebSocket Signal Handlers

func _on_websocket_connected() -> void:
	"""Handle successful WebSocket connection"""
	print("[LobbyZone2D] ✅ Connected to lobby WebSocket")
	websocket_connected = true
	_update_connection_status_display("connected")

	# Update lobby status
	if lobby_status:
		lobby_status.text = "Connected to Lobby - %d players online" % LobbyController.get_lobby_player_count()

func _on_websocket_disconnected() -> void:
	"""Handle WebSocket disconnection"""
	print("[LobbyZone2D] ❌ Disconnected from lobby WebSocket")
	websocket_connected = false
	_update_connection_status_display("disconnected")

	# Clean up remote players
	_cleanup_remote_players()

	# Update lobby status
	if lobby_status:
		lobby_status.text = "Offline Mode - Single Player"

func _on_websocket_connection_failed(reason: String) -> void:
	"""Handle WebSocket connection failure"""
	print("[LobbyZone2D] ❌ Connection failed: %s" % reason)
	websocket_connected = false
	_update_connection_status_display("failed")

	# Update lobby status
	if lobby_status:
		lobby_status.text = "Connection Failed - Offline Mode"

func _on_remote_player_joined(player_data: Dictionary) -> void:
	"""Handle remote player joining the lobby"""
	var player_id = player_data.get("id", "")
	print("[LobbyZone2D] 🎉 Remote player joined signal received: %s" % player_id)
	print("[LobbyZone2D] 🎉 Player data: %s" % player_data)

	if player_id.is_empty() or player_id in remote_players:
		print("[LobbyZone2D] ⚠️ Ignoring player join - empty ID or already exists")
		return

	# Create remote player instance
	print("[LobbyZone2D] 🔧 Creating remote player instance...")
	_spawn_remote_player(player_data)

	# Update player count display
	_update_player_count_display()

func _on_remote_player_left(player_id: String) -> void:
	"""Handle remote player leaving the lobby"""
	print("[LobbyZone2D] Remote player left: %s" % player_id)

	if player_id in remote_players:
		var remote_player = remote_players[player_id]
		if is_instance_valid(remote_player):
			remote_player.remove_remote_player()  # This will trigger fade out and removal
		remote_players.erase(player_id)

	# Update player count display
	_update_player_count_display()

func _on_remote_player_position_updated(player_id: String, position: Vector2) -> void:
	"""Handle remote player position update"""
	if player_id in remote_players:
		var remote_player = remote_players[player_id]
		if is_instance_valid(remote_player):
			remote_player.update_remote_position(position)

func _on_lobby_state_received(lobby_players: Array) -> void:
	"""Handle initial lobby state with existing players"""
	print("[LobbyZone2D] Received lobby state with %d existing players" % lobby_players.size())

	# Spawn existing players
	for player_data in lobby_players:
		var player_id = player_data.get("id", "")
		if not player_id.is_empty() and player_id not in remote_players:
			_spawn_remote_player(player_data)

	# Update displays
	_update_player_count_display()

func _on_connection_status_changed(status: String) -> void:
	"""Handle connection status changes"""
	connection_status = status
	print("[LobbyZone2D] Connection status changed: %s" % status)
	_update_connection_status_display(status)

## Remote Player Management

func _spawn_remote_player(player_data: Dictionary) -> void:
	"""Spawn a new remote player in the lobby"""
	var player_id = player_data.get("id", "")

	if player_id.is_empty():
		print("[LobbyZone2D] ERROR: Cannot spawn remote player without ID")
		return

	print("[LobbyZone2D] 🏗️ Spawning remote player: %s" % player_id)
	print("[LobbyZone2D] 🏗️ Player data: %s" % player_data)

	# Create RemoteLobbyPlayer2D instance
	var remote_player = CharacterBody2D.new()
	remote_player.name = "RemotePlayer_%s" % player_id
	print("[LobbyZone2D] ✅ Created CharacterBody2D node: %s" % remote_player.name)

	# Add the RemoteLobbyPlayer2D script
	var remote_script = preload("res://scripts/RemoteLobbyPlayer2D.gd")
	remote_player.set_script(remote_script)
	print("[LobbyZone2D] ✅ Attached RemoteLobbyPlayer2D script")

	# Add to scene
	add_child(remote_player)
	print("[LobbyZone2D] ✅ Added remote player to scene")

	# Initialize the remote player
	print("[LobbyZone2D] 🔧 Initializing remote player...")
	remote_player.initialize_remote_player(player_data)
	print("[LobbyZone2D] ✅ Remote player initialized")

	# Connect removal signal
	remote_player.remote_player_removed.connect(_on_remote_player_removed)
	print("[LobbyZone2D] ✅ Connected removal signal")

	# Store reference
	remote_players[player_id] = remote_player

	print("[LobbyZone2D] 🎊 Remote player %s spawned successfully at position (%.1f, %.1f)" % [
		player_id, player_data.get("x", 0), player_data.get("y", 0)
	])

func _on_remote_player_removed(player_id: String) -> void:
	"""Handle remote player removal from scene"""
	print("[LobbyZone2D] Remote player removed from scene: %s" % player_id)

	if player_id in remote_players:
		remote_players.erase(player_id)

	_update_player_count_display()

## UI Updates for Multiplayer

func _update_connection_status_display(status: String) -> void:
	"""Update connection status display in UI"""
	var status_text = ""
	var color = Color.WHITE

	match status:
		"connecting":
			status_text = "Connecting to lobby..."
			color = Color.YELLOW
		"connected":
			status_text = "Connected to lobby"
			color = Color.GREEN
		"disconnected":
			status_text = "Offline mode"
			color = Color.GRAY
		"failed":
			status_text = "Connection failed"
			color = Color.RED

	# Update lobby status label color
	if lobby_status:
		lobby_status.modulate = color

func _update_player_count_display() -> void:
	"""Update the player count display"""
	var player_count = remote_players.size() + 1  # +1 for local player

	if lobby_status and websocket_connected:
		lobby_status.text = "Trading Lobby - %d players online" % player_count
	elif lobby_status:
		lobby_status.text = "Trading Lobby - Offline Mode"

## Player Position Broadcasting

func _setup_player_position_broadcasting() -> void:
	"""Setup position broadcasting from local player"""
	if lobby_player and lobby_player.has_signal("position_changed"):
		if not lobby_player.position_changed.is_connected(_on_local_player_position_changed):
			lobby_player.position_changed.connect(_on_local_player_position_changed)
			print("[LobbyZone2D] Connected to local player position updates")

func _on_local_player_position_changed(new_position: Vector2) -> void:
	"""Handle local player position change for broadcasting"""
	if websocket_connected and LobbyController:
		LobbyController.send_position_update(new_position)



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

	# Clear existing inventory display - FIXED: Immediately remove from scene tree
	for item in inventory_items:
		if item and is_instance_valid(item):
			if item.get_parent():
				item.get_parent().remove_child(item)
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

	# Clear existing selection items - FIXED: Immediately remove from scene tree
	for child in debris_selection_list.get_children():
		debris_selection_list.remove_child(child)
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

## PHASE 1.5: PURCHASE CONFIRMATION SYSTEM

func _validate_listing_purchase(listing: Dictionary) -> Dictionary:
	##Validate if player can purchase a marketplace listing
	var result = {"success": false, "error_message": ""}

	if not LocalPlayerData or not LocalPlayerData.is_initialized:
		result.error_message = "Player data not available"
		return result

	# Use TradingMarketplace validation
	if TradingMarketplace:
		return TradingMarketplace.validate_marketplace_purchase(listing)
	else:
		result.error_message = "Trading system not available"
		return result

func _on_buy_button_pressed(listing: Dictionary) -> void:
	##Handle buy button press for marketplace listing
	print("[LobbyZone2D] Buy button pressed for listing: %s" % listing.get("listing_id", "unknown"))

	# Store current listing for purchase dialog
	purchase_current_listing = listing

	# Initialize purchase dialog if needed
	if not purchase_dialog_initialized:
		_initialize_purchase_dialog()

	# Populate purchase dialog with listing details
	_populate_purchase_dialog(listing)

	# Show purchase confirmation dialog
	if purchase_dialog:
		purchase_dialog.popup_centered()

func _initialize_purchase_dialog() -> void:
	##Initialize the purchase confirmation dialog UI (Phase 1.5)
	print("[LobbyZone2D] Initializing purchase confirmation dialog")

	# Create main dialog
	purchase_dialog = AcceptDialog.new()
	purchase_dialog.title = "Confirm Purchase"
	purchase_dialog.size = Vector2(400, 280)
	purchase_dialog.unresizable = false

	# Main container
	var dialog_vbox = VBoxContainer.new()
	dialog_vbox.add_theme_constant_override("separation", 15)
	purchase_dialog.add_child(dialog_vbox)

	# Title label
	var title_label = Label.new()
	title_label.text = "Purchase Item from Marketplace:"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.CYAN)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_vbox.add_child(title_label)

	# Item details
	purchase_item_label = Label.new()
	purchase_item_label.text = "Item: [Unknown Item] x1"
	purchase_item_label.add_theme_font_size_override("font_size", 14)
	purchase_item_label.add_theme_color_override("font_color", Color.WHITE)
	purchase_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_vbox.add_child(purchase_item_label)

	# Seller details
	purchase_seller_label = Label.new()
	purchase_seller_label.text = "Seller: Unknown"
	purchase_seller_label.add_theme_font_size_override("font_size", 12)
	purchase_seller_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	purchase_seller_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_vbox.add_child(purchase_seller_label)

	# Price details
	purchase_price_label = Label.new()
	purchase_price_label.text = "Total Cost: 0 credits"
	purchase_price_label.add_theme_font_size_override("font_size", 16)
	purchase_price_label.add_theme_color_override("font_color", Color.YELLOW)
	purchase_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_vbox.add_child(purchase_price_label)

	# Current credits display
	var credits_info = Label.new()
	credits_info.text = "Your Credits: %d" % (LocalPlayerData.get_credits() if LocalPlayerData else 0)
	credits_info.add_theme_font_size_override("font_size", 12)
	credits_info.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	credits_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_vbox.add_child(credits_info)

	# Warning message
	var warning_label = Label.new()
	warning_label.text = "This will remove credits from your account\nand add the item to your inventory."
	warning_label.add_theme_font_size_override("font_size", 10)
	warning_label.add_theme_color_override("font_color", Color.ORANGE)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_vbox.add_child(warning_label)

	# Buttons
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(100, 35)
	cancel_button.pressed.connect(_on_purchase_cancel_pressed)
	purchase_confirm_button = Button.new()
	purchase_confirm_button.text = "Confirm Purchase"
	purchase_confirm_button.custom_minimum_size = Vector2(140, 35)
	purchase_confirm_button.pressed.connect(_on_purchase_confirm_pressed)
	purchase_confirm_button.add_theme_color_override("font_color", Color.GREEN)
	button_container.add_child(cancel_button)
	button_container.add_child(purchase_confirm_button)
	dialog_vbox.add_child(button_container)

	# Add to scene
	ui_layer.add_child(purchase_dialog)
	purchase_dialog_initialized = true

	print("[LobbyZone2D] Purchase confirmation dialog initialized")

func _populate_purchase_dialog(listing: Dictionary) -> void:
	##Populate the purchase dialog with listing details
	print("[LobbyZone2D] Populating purchase dialog with listing details")

	if not purchase_item_label or not purchase_seller_label or not purchase_price_label:
		return

	# Extract listing details
	var item_name = listing.get("item_name", "Unknown Item")
	var quantity = listing.get("quantity", 1)
	var asking_price = listing.get("asking_price", 0)
	var total_price = asking_price * quantity
	var seller_name = listing.get("seller_name", "Unknown Seller")

	# Format item name for display
	var display_name = _format_item_name(item_name)

	# Update dialog content
	if quantity > 1:
		purchase_item_label.text = "Item: [%s] x%d" % [display_name, quantity]
	else:
		purchase_item_label.text = "Item: [%s]" % display_name

	purchase_seller_label.text = "Seller: %s" % seller_name

	if quantity > 1:
		purchase_price_label.text = "Total Cost: %d credits (%d each)" % [total_price, asking_price]
	else:
		purchase_price_label.text = "Total Cost: %d credits" % total_price

	# Update current credits display
	var credits_info = purchase_dialog.get_child(0).get_child(5) as Label  # Get the credits info label
	if credits_info and LocalPlayerData:
		credits_info.text = "Your Credits: %d" % LocalPlayerData.get_credits()

func _on_purchase_confirm_pressed() -> void:
	##Handle purchase confirmation
	print("[LobbyZone2D] Confirming marketplace purchase")

	if purchase_current_listing.is_empty():
		print("[LobbyZone2D] ERROR: No current listing for purchase")
		return

	var listing_id = purchase_current_listing.get("listing_id", "")
	var seller_id = purchase_current_listing.get("seller_id", "")

	print("[LobbyZone2D] Purchasing listing ID: %s from seller: %s" % [listing_id, seller_id])

	# CRITICAL FIX: Remove conditional signal connections - they're now connected during initialization
	if TradingMarketplace:
		# Make the purchase - signals are already connected
		TradingMarketplace.purchase_marketplace_item(listing_id, seller_id)
	else:
		print("[LobbyZone2D] ERROR: TradingMarketplace not available")
		_update_marketplace_status("Trading system not available", Color.RED)
		return

	# Close dialog
	purchase_dialog.hide()

	# Show purchasing status
	_update_marketplace_status("Processing purchase...", Color.WHITE)

func _on_purchase_cancel_pressed() -> void:
	##Handle purchase cancellation
	print("[LobbyZone2D] Cancelling marketplace purchase")
	purchase_dialog.hide()

func _on_item_purchase_result(success: bool, item_name: String) -> void:
	##Handle result of item purchase
	print("[LobbyZone2D] Item purchase result - Success: %s, Item: %s" % [success, item_name])

	if success:
		var display_name = _format_item_name(item_name)
		_update_marketplace_status("Purchase successful! %s added to inventory." % display_name, Color.GREEN)
		# Refresh marketplace to remove purchased item
		_refresh_marketplace_listings()
		# Update UI to show new inventory/credits
		_update_lobby_ui_with_player_data()
	else:
		_update_marketplace_status("Purchase failed. Please try again.", Color.RED)

## LISTING REMOVAL SYSTEM

func _on_remove_button_pressed(listing: Dictionary) -> void:
	##Handle remove button press for player's own listing
	print("[LobbyZone2D] Remove button pressed for listing: %s" % listing.get("listing_id", "unknown"))

	# Store current listing for removal dialog
	removal_current_listing = listing

	# Initialize removal dialog if needed
	if not removal_dialog_initialized:
		_initialize_removal_dialog()

	# Populate removal dialog with listing details
	_populate_removal_dialog(listing)

	# Show removal confirmation dialog
	if removal_dialog:
		removal_dialog.popup_centered()

func _initialize_removal_dialog() -> void:
	##Initialize the listing removal confirmation dialog
	print("[LobbyZone2D] Initializing removal confirmation dialog")

	# Create dialog
	removal_dialog = AcceptDialog.new()
	removal_dialog.title = "Remove Listing"
	removal_dialog.size = Vector2(400, 300)
	removal_dialog.add_theme_color_override("title_color", Color.ORANGE)

	# Create content container
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 15)

	# Warning message
	var warning_label = Label.new()
	warning_label.text = "Are you sure you want to remove this listing?"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_color_override("font_color", Color.YELLOW)
	warning_label.add_theme_font_size_override("font_size", 14)
	content_vbox.add_child(warning_label)

	# Item details
	removal_item_label = Label.new()
	removal_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	removal_item_label.add_theme_color_override("font_color", Color.CYAN)
	removal_item_label.add_theme_font_size_override("font_size", 16)
	content_vbox.add_child(removal_item_label)

	removal_price_label = Label.new()
	removal_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	removal_price_label.add_theme_color_override("font_color", Color.YELLOW)
	removal_price_label.add_theme_font_size_override("font_size", 14)
	content_vbox.add_child(removal_price_label)

	# Info message
	var info_label = Label.new()
	info_label.text = "The item will be returned to your inventory."
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	info_label.add_theme_font_size_override("font_size", 12)
	content_vbox.add_child(info_label)

	# Button container
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 20)

	# Confirm button
	removal_confirm_button = Button.new()
	removal_confirm_button.text = "REMOVE LISTING"
	removal_confirm_button.custom_minimum_size = Vector2(140, 40)
	removal_confirm_button.pressed.connect(_on_removal_confirm_pressed)
	removal_confirm_button.add_theme_color_override("font_color", Color.ORANGE)
	button_hbox.add_child(removal_confirm_button)

	# Cancel button
	var removal_cancel_button = Button.new()
	removal_cancel_button.text = "CANCEL"
	removal_cancel_button.custom_minimum_size = Vector2(100, 40)
	removal_cancel_button.pressed.connect(_on_removal_cancel_pressed)
	removal_cancel_button.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	button_hbox.add_child(removal_cancel_button)

	content_vbox.add_child(button_hbox)

	# Add content to dialog
	removal_dialog.add_child(content_vbox)

	# Add dialog to scene
	add_child(removal_dialog)

	removal_dialog_initialized = true
	print("[LobbyZone2D] Removal dialog initialized")

func _populate_removal_dialog(listing: Dictionary) -> void:
	##Populate removal dialog with listing details
	var item_name = listing.get("item_name", "Unknown Item")
	var quantity = listing.get("quantity", 1)
	var asking_price = listing.get("asking_price", 0)
	var total_price = asking_price * quantity

	removal_item_label.text = "%s x%d" % [item_name, quantity]

	if quantity > 1:
		removal_price_label.text = "Listed at: %d credits each (%d total)" % [asking_price, total_price]
	else:
		removal_price_label.text = "Listed at: %d credits" % asking_price

func _on_removal_confirm_pressed() -> void:
	##Handle removal confirmation
	print("[LobbyZone2D] Confirming marketplace listing removal")

	if removal_current_listing.is_empty():
		print("[LobbyZone2D] ERROR: No current listing for removal")
		return

	var listing_id = removal_current_listing.get("listing_id", "")

	print("[LobbyZone2D] Removing listing ID: %s" % listing_id)

	# CRITICAL FIX: Remove conditional signal connections - they're now connected during initialization
	if TradingMarketplace:
		# Remove the listing - signals are already connected
		TradingMarketplace.remove_listing(listing_id)
	else:
		print("[LobbyZone2D] ERROR: TradingMarketplace not available")
		_update_marketplace_status("Trading system not available", Color.RED)
		return

	# Close dialog
	removal_dialog.hide()

	# Show removal status
	_update_marketplace_status("Removing listing...", Color.WHITE)

func _on_removal_cancel_pressed() -> void:
	##Handle removal cancellation
	print("[LobbyZone2D] Cancelling marketplace listing removal")
	removal_dialog.hide()

func _on_listing_removal_result(success: bool, listing_id: String) -> void:
	##Handle result of listing removal
	print("[LobbyZone2D] Listing removal result - Success: %s, ID: %s" % [success, listing_id])

	if success:
		_update_marketplace_status("Listing removed successfully! Item returned to inventory.", Color.GREEN)
		# Refresh marketplace to remove the listing from display
		_refresh_marketplace_listings()
		# Update UI to show updated inventory
		_update_lobby_ui_with_player_data()
	else:
		_update_marketplace_status("Failed to remove listing. Please try again.", Color.RED)
