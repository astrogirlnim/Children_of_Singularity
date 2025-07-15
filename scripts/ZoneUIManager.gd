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
@export var trading_result: Label
@export var trading_close_button: Button

# UI state
var inventory_items: Array[Control] = []
var last_inventory_size: int = 0
var last_inventory_hash: String = ""
var trading_open: bool = false
var current_hub_type: String = ""
var game_logs: Array[String] = []

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
	"""Setup signal connections for UI elements"""
	if sell_all_button:
		sell_all_button.pressed.connect(_on_sell_all_pressed)

	if trading_close_button:
		trading_close_button.pressed.connect(_on_trading_close_pressed)

	print("ZoneUIManager: UI connections established")

func _initialize_ui_components() -> void:
	"""Initialize UI components with default values"""
	if trading_interface:
		trading_interface.visible = false

	if ai_message_overlay:
		ai_message_overlay.visible = false

	if upgrade_status_panel:
		upgrade_status_panel.visible = true

	print("ZoneUIManager: UI components initialized")

func _update_ui_elements() -> void:
	"""Update all UI elements - called by external systems"""
	# This method is called by ZoneMain to update UI
	pass

func _update_log_display() -> void:
	"""Update the log display with recent messages"""
	if not log_label:
		return

	var display_text = ""
	var recent_logs = game_logs.slice(max(0, game_logs.size() - 5), game_logs.size())

	for log in recent_logs:
		display_text += log + "\n"

	log_label.text = display_text.strip_edges()

## Public API Methods

func update_credits_display(credits: int) -> void:
	"""Update the credits display"""
	if credits_label:
		credits_label.text = "Credits: %d" % credits

func update_inventory_status(current_size: int, max_size: int) -> void:
	"""Update inventory status display"""
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
	"""Update debris count display"""
	if debris_count_label:
		debris_count_label.text = "Nearby Debris: %d" % count

func update_collection_range(range_value: float, upgrade_bonus: int = 0) -> void:
	"""Update collection range display"""
	if collection_range_label:
		var range_text = "Collection Range: %.0f" % range_value
		if upgrade_bonus > 0:
			range_text += " (+%d)" % upgrade_bonus
		collection_range_label.text = range_text

func update_inventory_display(inventory_data: Array) -> void:
	"""Update the inventory display grid"""
	if not inventory_grid:
		return

	# Clear existing items
	for item in inventory_items:
		if item:
			item.queue_free()
	inventory_items.clear()

	# Add new items
	for item_data in inventory_data:
		var item_control = _create_inventory_item_control(item_data)
		inventory_grid.add_child(item_control)
		inventory_items.append(item_control)

	# Update tracking variables
	last_inventory_size = inventory_data.size()
	last_inventory_hash = str(inventory_data.hash())

func _create_inventory_item_control(item_data: Dictionary) -> Control:
	"""Create a control for an inventory item"""
	var item_panel = Panel.new()
	item_panel.custom_minimum_size = Vector2(80, 80)

	var item_label = Label.new()
	item_label.text = item_data.get("type", "Unknown")
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.position = Vector2(10, 10)

	var value_label = Label.new()
	value_label.text = str(item_data.get("value", 0))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.position = Vector2(10, 50)
	value_label.modulate = Color.YELLOW

	item_panel.add_child(item_label)
	item_panel.add_child(value_label)

	return item_panel

func update_upgrade_status_display(upgrades: Dictionary, upgrade_system: Node = null) -> void:
	"""Update the upgrade status display"""
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
	"""Update the debug display"""
	if not debug_label:
		return

	var debug_text = ""
	for key in debug_info:
		debug_text += "%s: %s\n" % [key, debug_info[key]]

	debug_label.text = debug_text.strip_edges()

func show_trading_interface(hub_type: String) -> void:
	"""Show the trading interface"""
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
	"""Hide the trading interface"""
	if trading_interface:
		trading_interface.visible = false

	trading_open = false
	current_hub_type = ""
	trading_interface_closed.emit()
	print("ZoneUIManager: Trading interface closed")

func display_trading_result(result_text: String) -> void:
	"""Display trading result message"""
	if trading_result:
		trading_result.text = result_text
		trading_result.modulate = Color.GREEN

func show_ai_message(message: String, duration: float = 3.0) -> void:
	"""Show AI message overlay"""
	if not ai_message_overlay or not ai_message_label:
		return

	ai_message_label.text = message
	ai_message_overlay.visible = true

	# Auto-hide after duration
	get_tree().create_timer(duration).timeout.connect(_hide_ai_message)
	print("ZoneUIManager: AI message displayed: %s" % message)

func _hide_ai_message() -> void:
	"""Hide AI message overlay"""
	if ai_message_overlay:
		ai_message_overlay.visible = false

func log_message(message: String) -> void:
	"""Add a message to the game log"""
	game_logs.append(message)

	# Keep only last 50 messages
	if game_logs.size() > 50:
		game_logs = game_logs.slice(game_logs.size() - 50, game_logs.size())

	print("ZoneUIManager: Log message added: %s" % message)

func get_trading_status() -> Dictionary:
	"""Get current trading interface status"""
	return {
		"open": trading_open,
		"hub_type": current_hub_type
	}

## Signal handlers

func _on_sell_all_pressed() -> void:
	"""Handle sell all button press"""
	sell_all_requested.emit()
	print("ZoneUIManager: Sell all requested")

func _on_trading_close_pressed() -> void:
	"""Handle trading close button press"""
	hide_trading_interface()

## UI optimization methods

func needs_inventory_update(current_inventory: Array) -> bool:
	"""Check if inventory display needs updating"""
	var current_size = current_inventory.size()
	var current_hash = str(current_inventory.hash())

	return current_size != last_inventory_size or current_hash != last_inventory_hash

func force_ui_update() -> void:
	"""Force immediate UI update"""
	ui_update_timer = ui_update_interval
	_update_ui_elements()
