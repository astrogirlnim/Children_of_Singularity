# ZoneUIManager.gd
# UI manager for Children of the Singularity
# Handles all UI-related functionality including HUD, inventory, trading interface

class_name ZoneUIManager
extends Node

## Signal emitted when trading interface is opened
signal trading_interface_opened(hub_type: String)

## Signal emitted when trading interface is closed
signal trading_interface_closed()

## Signal emitted when sell all button is pressed
signal sell_all_requested()

## Signal emitted when AI message overlay should be shown
signal ai_message_display_requested(message: String)

# UI Component references
@export var hud: Control
@export var debug_label: Label
@export var log_label: Label
@export var inventory_panel: Panel
@export var inventory_grid: GridContainer
@export var inventory_status: Label
@export var credits_label: Label
@export var debris_count_label: Label
@export var collection_range_label: Label
@export var ai_message_overlay: Panel
@export var ai_message_label: Label
@export var upgrade_status_panel: Panel
@export var upgrade_status_text: Label
@export var trading_interface: Panel
@export var trading_title: Label
@export var sell_all_button: Button
@export var dump_inventory_button: Button
@export var clear_upgrades_button: Button
@export var trading_result: Label
@export var trading_close_button: Button

# Upgrade interface UI elements (Phase 3B addition)
@export var trading_tabs: TabContainer
@export var upgrade_content: VBoxContainer
@export var upgrade_catalog: ScrollContainer
@export var upgrade_grid: GridContainer
@export var upgrade_details: Panel
@export var upgrade_details_label: Label
@export var purchase_button: Button
@export var purchase_result: Label

# Player-to-Player Trading Marketplace UI elements
@export var marketplace_tab: Control
@export var marketplace_listings: ScrollContainer
@export var marketplace_listings_grid: GridContainer
@export var marketplace_status_label: Label
@export var marketplace_refresh_button: Button
@export var sell_item_button: Button
@export var sell_item_dialog: AcceptDialog
@export var sell_item_dropdown: OptionButton
@export var sell_quantity_spinbox: SpinBox
@export var sell_price_spinbox: SpinBox
@export var confirm_purchase_dialog: AcceptDialog
@export var confirm_upgrade_name: Label
@export var confirm_upgrade_info: Label
@export var confirm_cost_label: Label
@export var confirm_button: Button
@export var cancel_button: Button

# UI state
var inventory_items: Array[Control] = []
var last_inventory_size: int = 0
var last_inventory_hash: String = ""
var trading_open: bool = false
var current_hub_type: String = ""
var game_logs: Array[String] = []

# Upgrade system UI state (Phase 3B addition)
var current_selected_upgrade: String = ""
var current_upgrade_cost: int = 0
var upgrade_buttons: Dictionary = {}  # Store upgrade button references
var player_ship: Node = null  # Reference to player ship
var upgrade_system: Node = null  # Reference to upgrade system
var api_client: Node = null  # Reference to API client

# Update timers
var ui_update_timer: float = 0.0
var ui_update_interval: float = 0.5
var log_display_timer: float = 0.0
var log_display_duration: float = 5.0

func _ready() -> void:
	print("ZoneUIManager: Initializing UI manager")
	_setup_ui_connections()
	_initialize_ui_components()

func _process(delta: float) -> void:
	ui_update_timer += delta
	log_display_timer += delta

	if ui_update_timer >= ui_update_interval:
		ui_update_timer = 0.0
		_update_ui_elements()

	if log_display_timer >= log_display_duration:
		log_display_timer = 0.0
		_update_log_display()

func _setup_ui_connections() -> void:
	##Setup signal connections for UI elements
	if sell_all_button:
		sell_all_button.pressed.connect(_on_sell_all_pressed)

	if dump_inventory_button:
		dump_inventory_button.pressed.connect(_on_dump_inventory_pressed)

	if clear_upgrades_button:
		clear_upgrades_button.pressed.connect(_on_clear_upgrades_pressed)

	if trading_close_button:
		trading_close_button.pressed.connect(_on_trading_close_pressed)

	# Connect upgrade interface buttons (Phase 3B addition)
	if purchase_button:
		purchase_button.pressed.connect(_on_purchase_button_pressed)

	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_purchase_pressed)

	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_purchase_pressed)

	# Connect marketplace UI buttons
	if marketplace_refresh_button:
		marketplace_refresh_button.pressed.connect(refresh_marketplace_listings)

	if sell_item_button:
		sell_item_button.pressed.connect(show_sell_item_dialog)

	# Connect TradingMarketplace signals
	if TradingMarketplace:
		TradingMarketplace.listings_received.connect(_on_marketplace_listings_received)
		TradingMarketplace.item_purchased.connect(_on_item_purchased)
		TradingMarketplace.listing_posted.connect(_on_listing_posted)
		TradingMarketplace.api_error.connect(_show_marketplace_error)

	print("ZoneUIManager: UI connections established")

func _initialize_ui_components() -> void:
	##Initialize UI components with default values
	if trading_interface:
		trading_interface.visible = false

	if ai_message_overlay:
		ai_message_overlay.visible = false

	if upgrade_status_panel:
		upgrade_status_panel.visible = true

	# Initialize upgrade interface (Phase 3B addition)
	if purchase_button:
		purchase_button.disabled = true

	if confirm_purchase_dialog:
		confirm_purchase_dialog.visible = false

	print("ZoneUIManager: UI components initialized")

func _update_ui_elements() -> void:
	##Update all UI elements - called by external systems
	# This method is called by ZoneMain to update UI
	pass

func _update_log_display() -> void:
	##Update the log display with recent messages
	if not log_label:
		return

	var display_text = ""
	var recent_logs = game_logs.slice(max(0, game_logs.size() - 5), game_logs.size())

	for log in recent_logs:
		display_text += log + "\n"

	log_label.text = display_text.strip_edges()

## Public API Methods

func update_credits_display(credits: int) -> void:
	##Update the credits display
	if credits_label:
		credits_label.text = "Credits: %d" % credits

func update_inventory_status(current_size: int, max_size: int) -> void:
	##Update inventory status display
	if inventory_status:
		inventory_status.text = "%d/%d Items" % [current_size, max_size]

		# Color code based on fullness
		if current_size >= max_size:
			inventory_status.modulate = Color.RED
		elif current_size >= max_size * 0.8:
			inventory_status.modulate = Color.YELLOW
		else:
			inventory_status.modulate = Color.WHITE

func update_debris_count(count: int) -> void:
	##Update debris count display
	if debris_count_label:
		debris_count_label.text = "Nearby Debris: %d" % count

func update_collection_range(range_value: float, upgrade_bonus: int = 0) -> void:
	##Update collection range display
	if collection_range_label:
		var range_text = "Collection Range: %.0f" % range_value
		if upgrade_bonus > 0:
			range_text += " (+%d)" % upgrade_bonus
		collection_range_label.text = range_text

func update_inventory_display(inventory_data: Array) -> void:
	##Update the inventory display grid with grouped quantities by type
	if not inventory_grid:
		return

	# Clear existing items
	for item in inventory_items:
		if item:
			item.queue_free()
	inventory_items.clear()

	# Group inventory items by type and count quantities
	var grouped_inventory = _group_inventory_by_type(inventory_data)

	# Add grouped items to display
	for item_type in grouped_inventory:
		var group_data = grouped_inventory[item_type]
		var item_control = _create_grouped_inventory_item_control(item_type, group_data)
		inventory_grid.add_child(item_control)
		inventory_items.append(item_control)

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
	##Create a control for a grouped inventory item showing quantity
	var item_panel = Panel.new()
	item_panel.custom_minimum_size = Vector2(120, 90)

	# The new StyleBoxFlat theme handles all styling and margins automatically
	# No need for manual styling - just use theme type
	item_panel.theme_type_variation = "InventoryPanel"

	# Use VBoxContainer for clean layout - theme margins will handle spacing
	var vbox = VBoxContainer.new()
	item_panel.add_child(vbox)
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.add_theme_constant_override("separation", 4)  # Space between text elements

	# Item type name (formatted nicely)
	var item_label = Label.new()
	item_label.text = _format_item_name(item_type)
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(item_label)

	# Quantity display
	var quantity_label = Label.new()
	quantity_label.text = "x%d" % group_data.quantity
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_label.add_theme_color_override("font_color", Color.CYAN)
	quantity_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(quantity_label)

	# Total value display
	var value_label = Label.new()
	value_label.text = "%d credits" % group_data.total_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color.YELLOW)
	value_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(value_label)

	# Individual value (smaller text)
	var unit_value_label = Label.new()
	unit_value_label.text = "(%d each)" % group_data.individual_value
	unit_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unit_value_label.add_theme_color_override("font_color", Color.GRAY)
	unit_value_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(unit_value_label)

	return item_panel

func _format_item_name(item_type: String) -> String:
	##Format item name for display (replace underscores with spaces and capitalize)
	return item_type.replace("_", " ").capitalize()

func _get_rarity_color(item_type: String) -> Color:
	##Get color based on item rarity
	match item_type:
		"scrap_metal", "bio_waste":
			return Color.GRAY  # Common
		"broken_satellite", "energy_cell":
			return Color.GREEN  # Uncommon
		"ai_component", "nano_material":
			return Color.BLUE  # Rare
		"quantum_core":
			return Color.PURPLE  # Epic
		"unknown_artifact":
			return Color.GOLD  # Legendary
		_:
			return Color.WHITE  # Default

func update_upgrade_status_display(upgrades: Dictionary, upgrade_system: Node = null) -> void:
	##Update the upgrade status display
	if not upgrade_status_text:
		return

	var status_text = ""
	var upgrade_count = 0

	if upgrades.size() > 0:
		for upgrade_type in upgrades:
			var level = upgrades[upgrade_type]
			if level > 0:
				var upgrade_info = {}
				if upgrade_system and upgrade_system.has_method("get_upgrade_info"):
					upgrade_info = upgrade_system.get_upgrade_info(upgrade_type)

				var upgrade_name = upgrade_info.get("name", upgrade_type)
				status_text += "%s: L%d\n" % [upgrade_name, level]
				upgrade_count += 1

	if upgrade_count == 0:
		upgrade_status_text.text = "No upgrades purchased"
		upgrade_status_text.modulate = Color.GRAY
	else:
		upgrade_status_text.text = status_text
		upgrade_status_text.modulate = Color.WHITE

func update_debug_display(debug_info: Dictionary) -> void:
	##Update the debug display
	if not debug_label:
		return

	var debug_text = ""
	for key in debug_info:
		debug_text += "%s: %s\n" % [key, debug_info[key]]

	debug_label.text = debug_text.strip_edges()

func show_trading_interface(hub_type: String) -> void:
	##Show the trading interface
	if not trading_interface:
		return

	current_hub_type = hub_type
	trading_open = true
	trading_interface.visible = true

	if trading_title:
		trading_title.text = "Trading - %s" % hub_type

	if trading_result:
		trading_result.text = ""

	trading_interface_opened.emit(hub_type)
	print("ZoneUIManager: Trading interface opened for %s" % hub_type)

func hide_trading_interface() -> void:
	##Hide the trading interface
	if trading_interface:
		trading_interface.visible = false

	trading_open = false
	current_hub_type = ""
	trading_interface_closed.emit()
	print("ZoneUIManager: Trading interface closed")

func display_trading_result(result_text: String) -> void:
	##Display trading result message
	if trading_result:
		trading_result.text = result_text
		trading_result.modulate = Color.GREEN

func show_ai_message(message: String, duration: float = 3.0) -> void:
	##Show AI message overlay
	if not ai_message_overlay or not ai_message_label:
		return

	ai_message_label.text = message
	ai_message_overlay.visible = true

	# Auto-hide after duration
	get_tree().create_timer(duration).timeout.connect(_hide_ai_message)
	print("ZoneUIManager: AI message displayed: %s" % message)

func _hide_ai_message() -> void:
	##Hide AI message overlay
	if ai_message_overlay:
		ai_message_overlay.visible = false

func log_message(message: String) -> void:
	##Add a message to the game log
	game_logs.append(message)

	# Keep only last 50 messages
	if game_logs.size() > 50:
		game_logs = game_logs.slice(game_logs.size() - 50, game_logs.size())

	print("ZoneUIManager: Log message added: %s" % message)

func get_trading_status() -> Dictionary:
	##Get current trading interface status
	return {
		"open": trading_open,
		"hub_type": current_hub_type
	}

## Signal handlers

func _on_sell_all_pressed() -> void:
	##Handle sell all button press
	sell_all_requested.emit()
	print("ZoneUIManager: Sell all requested")

func _on_dump_inventory_pressed() -> void:
	##Handle dump inventory button press - clear all inventory without selling
	print("ZoneUIManager: Dump inventory button pressed")

	if not player_ship:
		print("ZoneUIManager: ERROR - Player ship not found!")
		return

	var inventory = player_ship.current_inventory
	if inventory.is_empty():
		_update_trading_result("No inventory to dump!", Color.YELLOW)
		print("ZoneUIManager: No inventory to dump")
		return

	# Show confirmation dialog
	var confirmation_text = "Are you sure you want to DUMP ALL inventory?\n\nThis will permanently delete all %d items.\nYou will NOT receive any credits!\n\nThis action cannot be undone." % inventory.size()

	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Confirm Dump Inventory"
	dialog.dialog_text = confirmation_text
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN

	# Add to scene temporarily
	get_tree().current_scene.add_child(dialog)

	# Connect signals
	dialog.confirmed.connect(_on_dump_inventory_confirmed.bind(dialog))
	dialog.canceled.connect(_on_dump_inventory_canceled.bind(dialog))

	# Show dialog
	dialog.popup_centered(Vector2i(500, 300))
	print("ZoneUIManager: Dump inventory confirmation dialog shown")

func _on_dump_inventory_confirmed(dialog: ConfirmationDialog) -> void:
	##Handle confirmed dump inventory action
	print("ZoneUIManager: Dump inventory confirmed by user")

	if not player_ship:
		print("ZoneUIManager: ERROR - Player ship not found!")
		dialog.queue_free()
		return

	var inventory = player_ship.current_inventory
	var item_count = inventory.size()

	# Clear inventory locally (no credits gained)
	var dumped_items = player_ship.clear_inventory()

	# Clear inventory on backend
	if api_client and api_client.has_method("clear_inventory"):
		api_client.clear_inventory()
		print("ZoneUIManager: Inventory cleared on backend")

	# Update UI immediately
	_update_trading_result("DUMPED %d items - No credits gained" % item_count, Color.RED)
	update_inventory_display(player_ship.current_inventory)

	# CRITICAL FIX: Refresh any trading interface elements if they exist
	if has_method("_populate_debris_selection_ui"):
		call("_populate_debris_selection_ui")
	if has_method("_update_selection_summary"):
		call("_update_selection_summary")

	print("ZoneUIManager: Dumped %d items, no credits gained, UI refreshed" % item_count)

	# Clean up dialog
	dialog.queue_free()

func _on_dump_inventory_canceled(dialog: ConfirmationDialog) -> void:
	##Handle canceled dump inventory action
	print("ZoneUIManager: Dump inventory canceled by user")
	dialog.queue_free()

func _on_clear_upgrades_pressed() -> void:
	##Handle clear upgrades button press - reset all upgrades to defaults
	print("ZoneUIManager: Clear upgrades button pressed")

	if not player_ship:
		print("ZoneUIManager: ERROR - Player ship not found!")
		return

	# Show confirmation dialog
	var confirmation_text = "Are you sure you want to CLEAR ALL upgrades?\n\nThis will reset all upgrades to default levels:\n• Speed Boost: Level 0\n• Inventory Expansion: Level 0\n• Collection Efficiency: Level 0\n• Zone Access: Level 1 (minimum)\n• Debris Scanner: Level 0\n• Cargo Magnet: Level 0\n\nYou will NOT receive any credit refunds!\nThis action cannot be undone."

	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Confirm Clear All Upgrades"
	dialog.dialog_text = confirmation_text
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN

	# Add to scene temporarily
	get_tree().current_scene.add_child(dialog)

	# Connect signals
	dialog.confirmed.connect(_on_clear_upgrades_confirmed.bind(dialog))
	dialog.canceled.connect(_on_clear_upgrades_canceled.bind(dialog))

	# Show dialog
	dialog.popup_centered(Vector2i(600, 400))
	print("ZoneUIManager: Clear upgrades confirmation dialog shown")

func _on_clear_upgrades_confirmed(dialog: ConfirmationDialog) -> void:
	##Handle confirmed clear upgrades action
	print("ZoneUIManager: Clear upgrades confirmed by user")

	if not player_ship:
		print("ZoneUIManager: ERROR - Player ship not found!")
		dialog.queue_free()
		return

	# Clear upgrades on backend first
	if api_client and api_client.has_method("clear_upgrades"):
		api_client.clear_upgrades()
		print("ZoneUIManager: Upgrades clear request sent to backend")
	else:
		print("ZoneUIManager: ERROR - API client does not support clear_upgrades")

	# Clean up dialog
	dialog.queue_free()

func _on_clear_upgrades_canceled(dialog: ConfirmationDialog) -> void:
	##Handle canceled clear upgrades action
	print("ZoneUIManager: Clear upgrades canceled by user")
	dialog.queue_free()

func handle_upgrades_cleared(cleared_data: Dictionary) -> void:
	##Handle upgrades cleared response from API (called by ZoneMain)
	print("ZoneUIManager: Upgrades cleared successfully - %s" % cleared_data)

	if not player_ship:
		print("ZoneUIManager: ERROR - Player ship not found!")
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
	update_upgrade_status_display(player_ship.upgrades, upgrade_system)

	# CRITICAL FIX: Refresh trading interface elements if they exist (inventory capacity may have changed)
	if has_method("_populate_debris_selection_ui"):
		call("_populate_debris_selection_ui")
	if has_method("_update_selection_summary"):
		call("_update_selection_summary")

	var total_cleared = cleared_data.get("total_cleared", 0)
	print("ZoneUIManager: All upgrades reset to defaults - %d upgrades cleared, UI refreshed" % total_cleared)

func _update_trading_result(message: String, color: Color) -> void:
	##Update trading result display with message and color
	if trading_result:
		trading_result.text = message
		trading_result.modulate = color
		print("ZoneUIManager: Trading result updated: %s" % message)

func _on_trading_close_pressed() -> void:
	##Handle trading close button press
	hide_trading_interface()

# PLAYER-TO-PLAYER TRADING MARKETPLACE FUNCTIONALITY

func show_marketplace() -> void:
	##Show the trading marketplace tab and load listings
	print("[ZoneUIManager] Opening trading marketplace")

	if marketplace_tab:
		trading_tabs.current_tab = trading_tabs.get_tab_idx_from_control(marketplace_tab)

	refresh_marketplace_listings()

func refresh_marketplace_listings() -> void:
	##Refresh marketplace listings from API
	print("[ZoneUIManager] Refreshing marketplace listings")

	if marketplace_status_label:
		marketplace_status_label.text = "Loading listings..."

	# Clear existing listings UI
	_clear_marketplace_listings_ui()

	# Request listings from TradingMarketplace singleton
	if TradingMarketplace:
		TradingMarketplace.get_listings()

func _clear_marketplace_listings_ui() -> void:
	##Clear all listing UI elements
	if not marketplace_listings_grid:
		return

	for child in marketplace_listings_grid.get_children():
		child.queue_free()

func _on_marketplace_listings_received(listings: Array[Dictionary]) -> void:
	##Handle marketplace listings received from API
	print("[ZoneUIManager] Received %d marketplace listings" % listings.size())

	if marketplace_status_label:
		marketplace_status_label.text = "Found %d listings" % listings.size()

	_clear_marketplace_listings_ui()

	if listings.is_empty():
		_add_no_listings_message()
		return

	# Create UI elements for each listing
	for listing in listings:
		_create_listing_ui_element(listing)

func _add_no_listings_message() -> void:
	##Add a message when no listings are available
	if not marketplace_listings_grid:
		return

	var no_listings_label = Label.new()
	no_listings_label.text = "No items for sale. Be the first to post something!"
	no_listings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_listings_label.add_theme_color_override("font_color", Color.YELLOW)
	marketplace_listings_grid.add_child(no_listings_label)

func _create_listing_ui_element(listing: Dictionary) -> void:
	##Create a UI element for a single marketplace listing
	if not marketplace_listings_grid:
		return

	var listing_container = VBoxContainer.new()
	listing_container.add_theme_constant_override("separation", 5)

	# Listing info
	var info_label = Label.new()
	var item_name = listing.get("item_name", "Unknown")
	var quantity = listing.get("quantity", 0)
	var price_per_unit = listing.get("price_per_unit", 0)
	var total_price = listing.get("total_price", 0)
	var seller_name = listing.get("seller_name", "Unknown")

	info_label.text = "%s x%d\n%d credits each (%d total)\nSeller: %s" % [item_name, quantity, price_per_unit, total_price, seller_name]
	info_label.add_theme_color_override("font_color", Color.WHITE)
	listing_container.add_child(info_label)

	# Purchase button
	var purchase_button = Button.new()
	purchase_button.text = "Buy for %d credits" % total_price

	# Check if player can afford it
	var can_afford = TradingMarketplace.can_afford_listing(listing) if TradingMarketplace else false
	var is_own_listing = listing.get("seller_id", "") == LocalPlayerData.get_player_id() if LocalPlayerData else false

	if is_own_listing:
		purchase_button.text = "Your Listing"
		purchase_button.disabled = true
		purchase_button.add_theme_color_override("font_color", Color.GRAY)
	elif not can_afford:
		purchase_button.disabled = true
		purchase_button.add_theme_color_override("font_color", Color.RED)
	else:
		purchase_button.add_theme_color_override("font_color", Color.GREEN)

	# Connect purchase button
	if not is_own_listing and can_afford:
		purchase_button.pressed.connect(_on_purchase_listing_pressed.bind(listing))

	listing_container.add_child(purchase_button)

	# Add separator
	var separator = HSeparator.new()
	listing_container.add_child(separator)

	marketplace_listings_grid.add_child(listing_container)

func _on_purchase_listing_pressed(listing: Dictionary) -> void:
	##Handle purchase button press for a listing
	var listing_id = listing.get("listing_id", "")
	var seller_id = listing.get("seller_id", "")
	var item_name = listing.get("item_name", "")
	var quantity = listing.get("quantity", 0)
	var total_price = listing.get("total_price", 0)

	print("[ZoneUIManager] Purchasing listing: %s x%d for %d credits" % [item_name, quantity, total_price])

	if marketplace_status_label:
		marketplace_status_label.text = "Processing purchase..."

	# Make purchase request through TradingMarketplace
	if TradingMarketplace:
		TradingMarketplace.purchase_item(listing_id, seller_id, item_name, quantity, total_price)

func show_sell_item_dialog() -> void:
	##Show dialog to sell an item
	print("[ZoneUIManager] Opening sell item dialog")

	if not sell_item_dialog:
		return

	# Populate dropdown with player's inventory
	_populate_sell_item_dropdown()

	# Reset form
	if sell_quantity_spinbox:
		sell_quantity_spinbox.value = 1
	if sell_price_spinbox:
		sell_price_spinbox.value = 10

	sell_item_dialog.popup_centered()

func _populate_sell_item_dropdown() -> void:
	##Populate the sell item dropdown with player's inventory
	if not sell_item_dropdown or not LocalPlayerData:
		return

	sell_item_dropdown.clear()

	var inventory = LocalPlayerData.get_inventory()
	var item_counts = {}

	# Count quantities of each item type
	for item in inventory:
		var item_type = item.get("type", "")
		if item_type != "":
			item_counts[item_type] = item_counts.get(item_type, 0) + item.get("quantity", 0)

	# Add to dropdown
	for item_type in item_counts:
		var count = item_counts[item_type]
		sell_item_dropdown.add_item("%s (%d available)" % [item_type, count])
		sell_item_dropdown.set_item_metadata(sell_item_dropdown.get_item_count() - 1, {"type": item_type, "available": count})

func _on_sell_item_confirmed() -> void:
	##Handle sell item dialog confirmation
	if not sell_item_dropdown or not sell_quantity_spinbox or not sell_price_spinbox:
		return

	var selected_idx = sell_item_dropdown.selected
	if selected_idx < 0:
		print("[ZoneUIManager] No item selected for selling")
		return

	var item_data = sell_item_dropdown.get_item_metadata(selected_idx)
	var item_type = item_data.get("type", "")
	var available_quantity = item_data.get("available", 0)
	var quantity_to_sell = int(sell_quantity_spinbox.value)
	var price_per_unit = int(sell_price_spinbox.value)

	print("[ZoneUIManager] Selling %d %s for %d credits each" % [quantity_to_sell, item_type, price_per_unit])

	# Validate quantity
	if quantity_to_sell > available_quantity:
		_show_marketplace_error("Cannot sell %d %s, only have %d" % [quantity_to_sell, item_type, available_quantity])
		return

	if quantity_to_sell <= 0:
		_show_marketplace_error("Quantity must be greater than 0")
		return

	if price_per_unit <= 0:
		_show_marketplace_error("Price must be greater than 0")
		return

	# Post listing through TradingMarketplace
	if TradingMarketplace:
		TradingMarketplace.post_listing(item_type, quantity_to_sell, price_per_unit, "")

	sell_item_dialog.hide()

func _show_marketplace_error(message: String) -> void:
	##Show marketplace error message
	print("[ZoneUIManager] Marketplace error: %s" % message)
	if marketplace_status_label:
		marketplace_status_label.text = "Error: %s" % message
		marketplace_status_label.add_theme_color_override("font_color", Color.RED)

func _on_marketplace_success(message: String) -> void:
	##Show marketplace success message
	print("[ZoneUIManager] Marketplace success: %s" % message)
	if marketplace_status_label:
		marketplace_status_label.text = message
		marketplace_status_label.add_theme_color_override("font_color", Color.GREEN)

	# Refresh listings after successful action
	refresh_marketplace_listings()

func _on_item_purchased(success: bool, item_name: String) -> void:
	##Handle item purchase completion
	if success:
		_on_marketplace_success("Successfully purchased %s!" % item_name)
	else:
		_show_marketplace_error("Failed to purchase %s" % item_name)

func _on_listing_posted(success: bool, listing_id: String) -> void:
	##Handle listing post completion
	if success:
		_on_marketplace_success("Item listed successfully!")
	else:
		_show_marketplace_error("Failed to list item")

## UI optimization methods

func needs_inventory_update(current_inventory: Array) -> bool:
	##Check if inventory display needs updating
	var current_size = current_inventory.size()
	var current_hash = str(current_inventory.hash())

	return current_size != last_inventory_size or current_hash != last_inventory_hash

func force_ui_update() -> void:
	##Force immediate UI update
	ui_update_timer = ui_update_interval
	_update_ui_elements()

## Upgrade Catalog Methods (Phase 3B implementation)

func set_system_references(player: Node, upgrade_sys: Node, api: Node) -> void:
	##Set references to game systems needed for upgrade functionality
	player_ship = player
	upgrade_system = upgrade_sys
	api_client = api
	print("ZoneUIManager: System references set for upgrade functionality")

func _populate_upgrade_catalog() -> void:
	##Populate the upgrade catalog with available upgrades (Phase 3B requirement)
	if not upgrade_grid or not upgrade_system or not player_ship:
		print("ZoneUIManager: ERROR - Missing components for upgrade catalog")
		return

	# Clear existing upgrade buttons
	for child in upgrade_grid.get_children():
		child.queue_free()
	upgrade_buttons.clear()

	print("ZoneUIManager: Populating upgrade catalog")

	# Get all upgrade definitions from UpgradeSystem
	var upgrade_definitions = upgrade_system.upgrade_definitions
	var player_credits = player_ship.credits

	for upgrade_type in upgrade_definitions:
		var upgrade_data = upgrade_definitions[upgrade_type]
		var current_level = player_ship.upgrades.get(upgrade_type, 0)
		var max_level = upgrade_data.max_level
		var cost = upgrade_system.calculate_upgrade_cost(upgrade_type, current_level)
		var can_afford = player_credits >= cost

		print("ZoneUIManager: Creating upgrade button - %s: Level %d/%d, Cost %d, Credits %d, Affordable: %s" %
			[upgrade_type, current_level, max_level, cost, player_credits, can_afford])

		# Create upgrade button for this type
		var upgrade_button = _create_upgrade_button(upgrade_type, upgrade_data, current_level, max_level, player_credits)
		upgrade_grid.add_child(upgrade_button)
		upgrade_buttons[upgrade_type] = upgrade_button

	print("ZoneUIManager: Created %d upgrade buttons" % upgrade_buttons.size())

func _create_upgrade_button(upgrade_type: String, upgrade_data: Dictionary, current_level: int, max_level: int, player_credits: int) -> Control:
	##Create a button for a specific upgrade (Phase 3B requirement)
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
	##Handle upgrade selection (Phase 3B requirement)
	print("ZoneUIManager: Upgrade selected: %s (level %d, cost %d)" % [upgrade_type, current_level, cost])

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

func refresh_upgrade_catalog() -> void:
	##Refresh upgrade catalog with current player data (Phase 3B requirement for real-time updates)
	if trading_interface and trading_interface.visible:
		var current_credits = player_ship.credits if player_ship else 0
		print("ZoneUIManager: Refreshing upgrade catalog - Trading interface visible, Player credits: %d" % current_credits)
		_populate_upgrade_catalog()
		print("ZoneUIManager: Upgrade catalog refreshed due to data change")
	else:
		var interface_status = "not visible" if trading_interface else "not found"
		print("ZoneUIManager: Skipping upgrade catalog refresh - Trading interface %s" % interface_status)

## Upgrade Purchase Handlers (Phase 3B implementation)

func _on_purchase_button_pressed() -> void:
	##Handle purchase button press - show confirmation dialog
	if current_selected_upgrade.is_empty():
		print("ZoneUIManager: No upgrade selected for purchase")
		return

	print("ZoneUIManager: Purchase button pressed for %s" % current_selected_upgrade)

	# Get upgrade data
	var upgrade_data = upgrade_system.upgrade_definitions.get(current_selected_upgrade, {})
	if upgrade_data.is_empty():
		print("ZoneUIManager: ERROR - Invalid upgrade data for %s" % current_selected_upgrade)
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
	print("ZoneUIManager: Purchase confirmed by user")

	# Perform the purchase using the shared method
	_perform_upgrade_purchase()

	# Close confirmation dialog
	if confirm_purchase_dialog:
		confirm_purchase_dialog.hide()

func _on_cancel_purchase_pressed() -> void:
	##Handle cancelled purchase
	print("ZoneUIManager: Purchase cancelled")

	# Close confirmation dialog
	if confirm_purchase_dialog:
		confirm_purchase_dialog.hide()

func handle_upgrade_purchased(result: Dictionary) -> void:
	##Handle successful upgrade purchase from API
	print("ZoneUIManager: Upgrade purchase successful: %s" % result)

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

		print("ZoneUIManager: Applied %s level %d effects to player, credits now: %d" % [upgrade_type, new_level, remaining_credits])

	# Update UI immediately
	update_credits_display(remaining_credits)
	_populate_upgrade_catalog()  # Refresh catalog with new levels
	_update_purchase_result("SUCCESS!\nPurchased %s level %d for %d credits" % [upgrade_type, new_level, cost], Color.GREEN)

	# Update the upgrade status panel to show purchased upgrades
	update_upgrade_status_display(player_ship.upgrades, upgrade_system)

	# Clear selection to reset interface
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
	print("ZoneUIManager: Forcing UI refresh after successful upgrade purchase")

func handle_upgrade_purchase_failed(reason: String, upgrade_type: String) -> void:
	##Handle failed upgrade purchase from API
	print("ZoneUIManager: Upgrade purchase failed: %s - %s" % [upgrade_type, reason])

	# Update UI with error
	_update_purchase_result("PURCHASE FAILED\n%s\nReason: %s" % [upgrade_type, reason], Color.RED)

func _update_purchase_result(message: String, color: Color = Color.WHITE) -> void:
	##Update the purchase result display
	if purchase_result:
		purchase_result.text = message
		purchase_result.modulate = color
		print("ZoneUIManager: Purchase result updated: %s" % message)

## Phase 4A: Purchase Processing Integration for ZoneMain.gd (2D version)

func _on_upgrade_purchase_requested(upgrade_type: String) -> void:
	##Handle upgrade purchase request (Phase 4A requirement)
	##Direct entry point for purchasing upgrades with full validation
	print("ZoneUIManager: Upgrade purchase requested for type: %s" % upgrade_type)

	if not upgrade_system or not player_ship:
		print("ZoneUIManager: ERROR - Missing upgrade system or player ship for purchase")
		return

	# Get upgrade data and validate
	var upgrade_definitions = upgrade_system.upgrade_definitions
	var upgrade_data = upgrade_definitions.get(upgrade_type, {})

	if upgrade_data.is_empty():
		print("ZoneUIManager: ERROR - Invalid upgrade type: %s" % upgrade_type)
		return

	# Get current state
	var current_level = player_ship.upgrades.get(upgrade_type, 0)
	var max_level = upgrade_data.max_level
	var player_credits = player_ship.credits
	var cost = upgrade_system.calculate_upgrade_cost(upgrade_type, current_level)

	# Client-side validation
	if current_level >= max_level:
		print("ZoneUIManager: Purchase failed - %s already at max level (%d)" % [upgrade_type, max_level])
		_update_purchase_result("PURCHASE FAILED\n%s is already at maximum level" % upgrade_data.name, Color.RED)
		return

	if player_credits < cost:
		print("ZoneUIManager: Purchase failed - Insufficient credits (need %d, have %d)" % [cost, player_credits])
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
		print("ZoneUIManager: Showing purchase confirmation for %s (cost: %d)" % [upgrade_type, cost])
	else:
		# If no confirmation dialog, proceed directly (for automated/programmatic purchases)
		print("ZoneUIManager: No confirmation dialog - proceeding with direct purchase")
		_perform_upgrade_purchase()

func _perform_upgrade_purchase() -> void:
	##Perform the actual upgrade purchase (extracted for reuse)
	if current_selected_upgrade.is_empty():
		print("ZoneUIManager: ERROR - No upgrade selected for purchase")
		return

	print("ZoneUIManager: Performing upgrade purchase: %s for %d credits" % [current_selected_upgrade, current_upgrade_cost])

	# Call APIClient to purchase upgrade (Phase 2A integration)
	if api_client and api_client.has_method("purchase_upgrade"):
		api_client.purchase_upgrade(current_selected_upgrade, current_upgrade_cost, player_ship.player_id)
		print("ZoneUIManager: Purchase request sent to API")
	else:
		print("ZoneUIManager: ERROR - API client does not support upgrade purchases")
		_update_purchase_result("PURCHASE FAILED\nAPI client error", Color.RED)
