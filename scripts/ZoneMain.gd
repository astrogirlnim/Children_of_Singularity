# ZoneMainRefactored.gd
# Main zone coordinator for Children of the Singularity
# Coordinates specialized managers for clean architecture

class_name ZoneMainRefactored
extends Node2D

## Signal emitted when zone is fully loaded and ready for gameplay
signal zone_ready()

## Signal emitted when zone state changes
signal zone_state_changed(state: String)

# Component references
@export var camera_controller: ZoneCameraController
@export var ui_manager: ZoneUIManager
@export var debris_manager: ZoneDebrisManager
@export var ai_handler: ZoneAIHandler

# Core game components
@onready var player_ship: CharacterBody2D = $PlayerShip
@onready var api_client: Node = $APIClient
@onready var upgrade_system: Node = $UpgradeSystem
@onready var network_manager: NetworkManager = $NetworkManager

# Zone configuration
@export var zone_name: String = "Zone Alpha"
@export var zone_id: String = "zone_alpha_01"
@export var zone_bounds: Rect2 = Rect2(-1000, -1000, 2000, 2000)

# Update intervals
@export var ui_update_interval: float = 0.5
@export var network_update_interval: float = 0.1

# Internal state
var ui_update_timer: float = 0.0
var network_update_timer: float = 0.0
var zone_state: String = "initializing"

func _ready() -> void:
	print("ZoneMainRefactored: Initializing zone coordinator")
	_setup_components()
	_connect_signals()
	_initialize_zone()
	_finalize_setup()

func _process(delta: float) -> void:
	ui_update_timer += delta
	network_update_timer += delta

	if ui_update_timer >= ui_update_interval:
		ui_update_timer = 0.0
		_update_ui_systems()

	if network_update_timer >= network_update_interval:
		network_update_timer = 0.0
		_update_network_systems()

func _setup_components() -> void:
	##Setup and configure all zone components
	print("ZoneMainRefactored: Setting up components")

	# Setup camera controller
	if camera_controller:
		camera_controller.camera_2d = $Camera2D
		camera_controller.target_node = player_ship
		camera_controller.bounds = zone_bounds
		print("ZoneMainRefactored: Camera controller configured")

	# Setup UI manager
	if ui_manager:
		ui_manager.hud = $UILayer/HUD
		ui_manager.debug_label = $UILayer/HUD/DebugLabel
		ui_manager.log_label = $UILayer/HUD/LogLabel
		ui_manager.inventory_panel = $UILayer/HUD/InventoryPanel
		ui_manager.inventory_grid = $UILayer/HUD/InventoryPanel/InventoryGrid
		ui_manager.inventory_status = $UILayer/HUD/InventoryPanel/InventoryStatus
		ui_manager.credits_label = $UILayer/HUD/StatsPanel/CreditsLabel
		ui_manager.debris_count_label = $UILayer/HUD/StatsPanel/DebrisCountLabel
		ui_manager.collection_range_label = $UILayer/HUD/StatsPanel/CollectionRangeLabel
		ui_manager.ai_message_overlay = $UILayer/HUD/AIMessageOverlay
		ui_manager.ai_message_label = $UILayer/HUD/AIMessageOverlay/AIMessageLabel
		ui_manager.upgrade_status_panel = $UILayer/HUD/UpgradeStatusPanel
		ui_manager.upgrade_status_text = $UILayer/HUD/UpgradeStatusPanel/UpgradeStatusText
		ui_manager.trading_interface = $UILayer/HUD/TradingInterface
		ui_manager.trading_title = $UILayer/HUD/TradingInterface/TradingTitle
		ui_manager.sell_all_button = $UILayer/HUD/TradingInterface/TradingTabs/SELL/TradingContent/SellAllButton
		ui_manager.dump_inventory_button = $UILayer/HUD/TradingInterface/TradingTabs/SELL/TradingContent/DumpInventoryButton
		ui_manager.clear_upgrades_button = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/ClearUpgradesContainer/ClearUpgradesButton
		ui_manager.trading_result = $UILayer/HUD/TradingInterface/TradingTabs/SELL/TradingContent/TradingResult
		ui_manager.trading_close_button = $UILayer/HUD/TradingInterface/TradingCloseButton

		# Setup upgrade interface UI elements (Phase 3B addition)
		ui_manager.trading_tabs = $UILayer/HUD/TradingInterface/TradingTabs
		ui_manager.upgrade_content = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent
		ui_manager.upgrade_catalog = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeCatalog
		ui_manager.upgrade_grid = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeCatalog/UpgradeGrid
		ui_manager.upgrade_details = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeDetails
		ui_manager.upgrade_details_label = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/UpgradeDetails/UpgradeDetailsLabel
		ui_manager.purchase_button = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/PurchaseControls/PurchaseButton
		ui_manager.purchase_result = $UILayer/HUD/TradingInterface/TradingTabs/BUY/UpgradeContent/PurchaseResult
		ui_manager.confirm_purchase_dialog = $UILayer/HUD/ConfirmPurchaseDialog
		ui_manager.confirm_upgrade_name = $UILayer/HUD/ConfirmPurchaseDialog/ConfirmDialogContent/UpgradeNameLabel
		ui_manager.confirm_upgrade_info = $UILayer/HUD/ConfirmPurchaseDialog/ConfirmDialogContent/UpgradeInfoLabel
		ui_manager.confirm_cost_label = $UILayer/HUD/ConfirmPurchaseDialog/ConfirmDialogContent/CostLabel
		ui_manager.confirm_button = $UILayer/HUD/ConfirmPurchaseDialog/ConfirmDialogContent/ConfirmButtons/ConfirmButton
		ui_manager.cancel_button = $UILayer/HUD/ConfirmPurchaseDialog/ConfirmDialogContent/ConfirmButtons/CancelButton

		# Set system references for upgrade functionality (Phase 3B)
		ui_manager.set_system_references(player_ship, upgrade_system, api_client)

		print("ZoneMainRefactored: UI manager configured with upgrade interface")

	# Setup debris manager
	if debris_manager:
		debris_manager.debris_container = $DebrisContainer
		debris_manager.zone_bounds = zone_bounds
		debris_manager.set_player_reference(player_ship)
		print("ZoneMainRefactored: Debris manager configured")

	# Setup AI handler
	if ai_handler:
		ai_handler.ai_communicator = $AICommunicator
		print("ZoneMainRefactored: AI handler configured")

func _connect_signals() -> void:
	##Connect all component signals
	print("ZoneMainRefactored: Connecting signals")

	# Player ship signals
	if player_ship:
		if player_ship.has_signal("debris_collected"):
			player_ship.debris_collected.connect(_on_debris_collected)
		if player_ship.has_signal("position_changed"):
			player_ship.position_changed.connect(_on_player_position_changed)
		if player_ship.has_signal("npc_hub_entered"):
			player_ship.npc_hub_entered.connect(_on_npc_hub_entered)
		if player_ship.has_signal("npc_hub_exited"):
			player_ship.npc_hub_exited.connect(_on_npc_hub_exited)

		# Connect upgrade effect signals for immediate UI updates
		if player_ship.has_signal("inventory_expanded"):
			player_ship.inventory_expanded.connect(_on_inventory_expanded)
			print("ZoneMain: Connected to inventory_expanded signal")

	# API client signals
	if api_client:
		if api_client.has_signal("player_data_loaded"):
			api_client.player_data_loaded.connect(_on_player_data_loaded)
		if api_client.has_signal("credits_updated"):
			api_client.credits_updated.connect(_on_credits_updated)
		if api_client.has_signal("inventory_updated"):
			api_client.inventory_updated.connect(_on_inventory_updated)
		if api_client.has_signal("api_error"):
			api_client.api_error.connect(_on_api_error)
		# Connect upgrade purchase signals (Phase 3B addition)
		if api_client.has_signal("upgrade_purchased"):
			api_client.upgrade_purchased.connect(_on_upgrade_purchased_api)
		if api_client.has_signal("upgrade_purchase_failed"):
			api_client.upgrade_purchase_failed.connect(_on_upgrade_purchase_failed_api)
		if api_client.has_signal("upgrades_cleared"):
			api_client.upgrades_cleared.connect(_on_upgrades_cleared)

	# Upgrade system signals
	if upgrade_system:
		upgrade_system.upgrade_purchased.connect(_on_upgrade_purchased)
		upgrade_system.upgrade_purchase_failed.connect(_on_upgrade_purchase_failed)
		upgrade_system.upgrade_effects_applied.connect(_on_upgrade_effects_applied)

		# Connect upgrade effect signals for immediate UI feedback
		if upgrade_system.has_signal("upgrade_effects_applied"):
			upgrade_system.upgrade_effects_applied.connect(_on_upgrade_effects_applied_ui_update)
			print("ZoneMain: Connected to upgrade_effects_applied signal")

	# Network manager signals
	if network_manager:
		network_manager.connected_to_server.connect(_on_connected_to_server)
		network_manager.disconnected_from_server.connect(_on_disconnected_from_server)
		network_manager.player_joined.connect(_on_network_player_joined)
		network_manager.player_left.connect(_on_network_player_left)
		network_manager.player_position_updated.connect(_on_network_player_position_updated)
		network_manager.debris_collected_by_player.connect(_on_network_debris_collected)
		network_manager.server_state_updated.connect(_on_network_server_state_updated)

	# Component signals
	if camera_controller:
		camera_controller.zoom_changed.connect(_on_camera_zoom_changed)
		camera_controller.bounds_exceeded.connect(_on_camera_bounds_exceeded)

	if ui_manager:
		ui_manager.trading_interface_opened.connect(_on_trading_interface_opened)
		ui_manager.trading_interface_closed.connect(_on_trading_interface_closed)
		ui_manager.sell_all_requested.connect(_on_sell_all_requested)

	if debris_manager:
		debris_manager.debris_spawned.connect(_on_debris_spawned)
		debris_manager.debris_collected.connect(_on_debris_collected_by_manager)
		debris_manager.debris_count_changed.connect(_on_debris_count_changed)

	if ai_handler:
		ai_handler.ai_message_received.connect(_on_ai_message_received)
		ai_handler.milestone_reached.connect(_on_milestone_reached)
		ai_handler.ai_broadcast_ready.connect(_on_ai_broadcast_ready)

func _initialize_zone() -> void:
	##Initialize the zone environment
	print("ZoneMainRefactored: Initializing zone environment")
	zone_state = "loading"
	zone_state_changed.emit(zone_state)

	# Setup zone background
	_setup_zone_background()

	# Setup NPC hubs
	_setup_npc_hubs()

	# Initialize networking
	_initialize_networking()

	# Check backend health
	if api_client and api_client.has_method("check_health"):
		api_client.check_health()

func _finalize_setup() -> void:
	##Finalize zone setup
	print("ZoneMainRefactored: Finalizing setup")
	zone_state = "ready"
	zone_state_changed.emit(zone_state)
	zone_ready.emit()

	# Log initial state
	_log_message("Zone ready for gameplay")

func _setup_zone_background() -> void:
	##Set up the zone background
	print("ZoneMainRefactored: Setting up zone background")

	# Create space background
	var background = ColorRect.new()
	background.name = "SpaceBackground"
	background.color = Color(0.05, 0.05, 0.15, 1.0)
	background.size = Vector2(4000, 4000)
	background.position = Vector2(-2000, -2000)
	background.z_index = -100

	# Create stars
	var stars_container = Node2D.new()
	stars_container.name = "StarsContainer"
	stars_container.z_index = -90

	for i in range(100):
		var star = ColorRect.new()
		star.size = Vector2(2, 2)
		star.color = Color(1.0, 1.0, 1.0, randf_range(0.3, 1.0))
		star.position = Vector2(randf_range(-2000, 2000), randf_range(-2000, 2000))
		stars_container.add_child(star)

	add_child(background)
	add_child(stars_container)

func _setup_npc_hubs() -> void:
	##Setup NPC trading hubs
	print("ZoneMainRefactored: Setting up NPC hubs")
	# NPC hub setup logic would go here
	# For now, assume hubs are already in the scene

func _initialize_networking() -> void:
	##Initialize networking systems
	if network_manager:
		# Try to start as server first, fall back to client
		print("ZoneMainRefactored: Initializing networking")

func _update_ui_systems() -> void:
	##Update UI systems with current game state
	if not ui_manager or not player_ship:
		return

	# Update UI elements
	ui_manager.update_credits_display(player_ship.credits)
	ui_manager.update_inventory_status(player_ship.current_inventory.size(), player_ship.inventory_capacity)
	ui_manager.update_collection_range(player_ship.collection_range, player_ship.upgrades.get("collection_efficiency", 0) * 10)
	ui_manager.update_upgrade_status_display(player_ship.upgrades, upgrade_system)

	# Update debris count
	if debris_manager:
		ui_manager.update_debris_count(debris_manager.get_debris_count())

	# Update inventory display if needed
	if ui_manager.needs_inventory_update(player_ship.current_inventory):
		ui_manager.update_inventory_display(player_ship.current_inventory)

	# Update debug display
	var debug_info = {
		"Zone": zone_name,
		"State": zone_state,
		"Position": str(player_ship.global_position),
		"Zoom": camera_controller.get_current_zoom() if camera_controller else 1.0
	}
	ui_manager.update_debug_display(debug_info)

func _update_network_systems() -> void:
	##Update network systems
	if network_manager:
		# Network updates would go here
		pass

func _log_message(message: String) -> void:
	##Log a message to the UI system
	if ui_manager:
		ui_manager.log_message(message)
	print("ZoneMainRefactored: %s" % message)

## Signal handlers

func _on_debris_collected(debris_type: String, value: int) -> void:
	##Handle debris collection by player
	_log_message("Collected %s worth %d credits" % [debris_type, value])

	# Immediately update UI when debris is collected (don't wait for timer)
	if ui_manager and player_ship:
		ui_manager.update_inventory_status(player_ship.current_inventory.size(), player_ship.inventory_capacity)
		# Update inventory display if UI manager supports immediate updates
		if ui_manager.has_method("update_inventory_display"):
			ui_manager.update_inventory_display(player_ship.current_inventory)
		_log_message("ZoneMain: UI updated immediately after debris collection")

	# Update AI handler
	if ai_handler:
		ai_handler.on_debris_collected(debris_type, value)

func _on_player_position_changed(position: Vector2) -> void:
	##Handle player position changes
	# Position updates handled by camera controller automatically
	pass

func _on_npc_hub_entered() -> void:
	##Handle entering NPC hub
	if ui_manager:
		ui_manager.show_trading_interface("Trading Hub")
		# Populate upgrade catalog when trading interface opens (Phase 3B requirement)
		if ui_manager.has_method("_populate_upgrade_catalog"):
			ui_manager._populate_upgrade_catalog()

func _on_npc_hub_exited() -> void:
	##Handle exiting NPC hub
	if ui_manager:
		ui_manager.hide_trading_interface()

func _on_upgrade_purchased(upgrade_type: String, cost: int) -> void:
	##Handle upgrade purchase
	_log_message("Purchased upgrade: %s for %d credits" % [upgrade_type, cost])

	# Update AI handler
	if ai_handler:
		ai_handler.on_upgrade_purchased(upgrade_type, cost)

func _on_upgrade_purchase_failed(upgrade_type: String, reason: String) -> void:
	##Handle upgrade purchase failure
	_log_message("Upgrade purchase failed: %s - %s" % [upgrade_type, reason])

func _on_upgrade_effects_applied(effects: Dictionary) -> void:
	##Handle upgrade effects being applied
	_log_message("Upgrade effects applied: %s" % effects)

func _on_inventory_expanded(old_capacity: int, new_capacity: int) -> void:
	##Handle inventory capacity expansion - update UI immediately for 2D
	_log_message("ZoneMain: Inventory expanded from %d to %d - updating UI" % [old_capacity, new_capacity])

	# Update UI manager with new inventory status
	if ui_manager and player_ship:
		var current_size = player_ship.current_inventory.size()
		ui_manager.update_inventory_status(current_size, new_capacity)

		# Update upgrade status display
		ui_manager.update_upgrade_status_display(player_ship.upgrades, upgrade_system)

		# Log the UI update
		_log_message("ZoneMain: UI updated for inventory expansion to %d items" % new_capacity)

func _on_upgrade_effects_applied_ui_update(upgrade_type: String, level: int) -> void:
	##Handle when upgrade effects are applied - update relevant UI panels for 2D
	_log_message("ZoneMain: Upgrade effects applied: %s level %d - updating UI" % [upgrade_type, level])

	# Update UI manager with current player state
	if ui_manager and player_ship:
		# Update credits display
		ui_manager.update_credits_display(player_ship.credits)

		# Update inventory status (capacity might have changed)
		ui_manager.update_inventory_status(player_ship.current_inventory.size(), player_ship.inventory_capacity)

		# Update collection range display (might have changed)
		var upgrade_bonus = player_ship.upgrades.get("collection_efficiency", 0) * 20  # 2D uses different scaling
		ui_manager.update_collection_range(player_ship.collection_range, upgrade_bonus)

		# Update upgrade status display
		ui_manager.update_upgrade_status_display(player_ship.upgrades, upgrade_system)

		# Force inventory display update if needed
		if ui_manager.has_method("update_inventory_display"):
			ui_manager.update_inventory_display(player_ship.current_inventory)

		_log_message("ZoneMain: UI updated for %s upgrade level %d" % [upgrade_type, level])

func _on_sell_all_requested() -> void:
	##Handle sell all request
	if api_client and api_client.has_method("sell_all_inventory"):
		api_client.sell_all_inventory()
		# Note: upgrade catalog refresh will be triggered by credits_updated signal from API
	else:
		# Fallback: if API client not available, handle locally and refresh catalog
		_log_message("API client not available, handling sell all locally")
		if player_ship and player_ship.current_inventory.size() > 0:
			var total_value = 0
			for item in player_ship.current_inventory:
				total_value += item.get("value", 0)
			var sold_items = player_ship.clear_inventory()
			player_ship.add_credits(total_value)

			# Update UI and refresh upgrade catalog
			if ui_manager:
				ui_manager.update_credits_display(player_ship.credits)
				ui_manager.refresh_upgrade_catalog()  # CRITICAL FIX: Manual refresh for local updates
			_log_message("Sold %d items for %d credits locally with catalog refresh" % [sold_items.size(), total_value])

func _on_ai_message_received(message: String, priority: int) -> void:
	##Handle AI message received
	if ui_manager:
		ui_manager.show_ai_message(message, 3.0)

func _on_milestone_reached(milestone_type: String, value: int) -> void:
	##Handle milestone reached
	_log_message("Milestone reached: %s = %d" % [milestone_type, value])

func _on_ai_broadcast_ready(broadcast_data: Dictionary) -> void:
	##Handle AI broadcast ready
	_log_message("AI broadcast ready: %s" % broadcast_data)

func _on_debris_spawned(debris: Node2D) -> void:
	##Handle debris spawned
	# Debris spawning handled by manager
	pass

func _on_debris_collected_by_manager(debris_type: String, value: int) -> void:
	##Handle debris collected by manager
	# Forward to main debris collection handler
	_on_debris_collected(debris_type, value)

func _on_debris_count_changed(count: int) -> void:
	##Handle debris count changes
	# Count updates handled by UI manager
	pass

func _on_camera_zoom_changed(new_zoom: float) -> void:
	##Handle camera zoom changes
	# Camera zoom handled by camera controller
	pass

func _on_camera_bounds_exceeded(position: Vector2) -> void:
	##Handle camera bounds exceeded
	_log_message("Camera bounds exceeded at: %s" % position)

func _on_trading_interface_opened(hub_type: String) -> void:
	##Handle trading interface opened
	_log_message("Trading interface opened: %s" % hub_type)

func _on_trading_interface_closed() -> void:
	##Handle trading interface closed
	_log_message("Trading interface closed")

# API and Network signal handlers (simplified)
func _on_player_data_loaded(data: Dictionary) -> void:
	_log_message("Player data loaded")

func _on_credits_updated(credits: int) -> void:
	_log_message("Credits updated: %d" % credits)
	if player_ship:
		player_ship.credits = credits
	if ui_manager:
		ui_manager.update_credits_display(credits)
		# Real-time upgrade catalog refresh when credits change (Phase 3B requirement)
		ui_manager.refresh_upgrade_catalog()
		_log_message("Credits updated from API with upgrade catalog refresh: %d" % credits)

func _on_inventory_updated(inventory: Array) -> void:
	_log_message("Inventory updated: %d items" % inventory.size())

func _on_api_error(error: String) -> void:
	_log_message("API Error: %s" % error)

func _on_connected_to_server() -> void:
	_log_message("Connected to server")

func _on_disconnected_from_server() -> void:
	_log_message("Disconnected from server")

func _on_network_player_joined(player_id: String) -> void:
	_log_message("Player joined: %s" % player_id)

func _on_network_player_left(player_id: String) -> void:
	_log_message("Player left: %s" % player_id)

func _on_network_player_position_updated(player_id: String, position: Vector2) -> void:
	pass  # Handle network position updates

func _on_network_debris_collected(player_id: String, debris_type: String, value: int) -> void:
	_log_message("Network debris collected by %s: %s worth %d" % [player_id, debris_type, value])

func _on_network_server_state_updated(state: Dictionary) -> void:
	_log_message("Server state updated")

## Upgrade Purchase Signal Handlers (Phase 3B addition)

func _on_upgrade_purchased_api(result: Dictionary) -> void:
	##Handle upgrade purchase success from API client
	_log_message("Upgrade purchased via API: %s" % result)
	if ui_manager:
		ui_manager.handle_upgrade_purchased(result)

func _on_upgrade_purchase_failed_api(reason: String, upgrade_type: String) -> void:
	##Handle upgrade purchase failure from API client
	_log_message("Upgrade purchase failed via API: %s - %s" % [upgrade_type, reason])
	if ui_manager:
		ui_manager.handle_upgrade_purchase_failed(reason, upgrade_type)

func _on_upgrades_cleared(cleared_data: Dictionary) -> void:
	##Handle upgrades cleared from API client
	_log_message("All upgrades cleared via API: %s" % cleared_data)
	if ui_manager:
		ui_manager.handle_upgrades_cleared(cleared_data)

## Public API

func get_zone_state() -> String:
	##Get current zone state
	return zone_state

func get_zone_bounds() -> Rect2:
	##Get zone bounds
	return zone_bounds

func force_ui_update() -> void:
	##Force immediate UI update
	if ui_manager:
		ui_manager.force_ui_update()

func get_game_stats() -> Dictionary:
	##Get current game statistics
	if ai_handler:
		return ai_handler.get_game_stats()
	return {}

func request_ai_analysis() -> void:
	##Request AI analysis
	if ai_handler:
		ai_handler.request_ai_analysis()

func get_debris_stats() -> Dictionary:
	##Get debris statistics
	if debris_manager:
		return debris_manager.get_stats()
	return {}

## Phase 4A: Purchase Processing Integration

func _on_upgrade_purchase_requested(upgrade_type: String) -> void:
	##Handle upgrade purchase request (Phase 4A requirement)
	##Delegates to UIManager for 2D version functionality
	_log_message("ZoneMain: Upgrade purchase requested for type: %s" % upgrade_type)

	if ui_manager and ui_manager.has_method("_on_upgrade_purchase_requested"):
		ui_manager._on_upgrade_purchase_requested(upgrade_type)
	else:
		_log_message("ZoneMain: ERROR - UIManager does not support upgrade purchase requests")

func reset_zone() -> void:
	##Reset zone to initial state
	print("ZoneMainRefactored: Resetting zone")

	if debris_manager:
		debris_manager.clear_all_debris()

	if ai_handler:
		ai_handler.reset_session()

	if camera_controller:
		camera_controller.reset_camera()

	zone_state = "ready"
	zone_state_changed.emit(zone_state)
	_log_message("Zone reset completed")
