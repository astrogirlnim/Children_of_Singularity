# InventoryManager.gd
# Manages player inventory sync with server for Children of the Singularity
# Handles inventory operations, validation, and persistence

class_name InventoryManager
extends Node

## Signal emitted when inventory is updated
signal inventory_updated(inventory_data: Array[Dictionary])

## Signal emitted when inventory is full
signal inventory_full()

## Signal emitted when item is added to inventory
signal item_added(item_type: String, quantity: int)

## Signal emitted when item is removed from inventory
signal item_removed(item_type: String, quantity: int)

## Signal emitted when inventory changes (for compatibility)
signal inventory_changed(inventory_data: Dictionary)

var player_inventory: Array[Dictionary] = []
var inventory_items: Dictionary = {}  # Stack-based inventory for item types
var inventory_capacity: int = 10
var max_inventory_size: int = 25  # Maximum individual items allowed
var max_stack_size: int = 99

func _ready() -> void:
	_log_message("InventoryManager: Initializing inventory system")
	_initialize_inventory()
	_log_message("InventoryManager: Inventory system ready")

func _initialize_inventory() -> void:
	##Initialize the inventory system
	_log_message("InventoryManager: Setting up inventory structure")
	player_inventory.clear()
	inventory_items.clear()
	_log_message("InventoryManager: Inventory initialized with capacity: %d" % inventory_capacity)

## Gets the total count of individual items across all stacks
func get_total_item_count() -> int:
	##Calculate total individual items in inventory
	var total_count = 0
	for item_type in inventory_items:
		total_count += inventory_items[item_type]
	return total_count

## Adds item to inventory.
# @param item_id: String - ID of the item.
# @param quantity: int - Quantity to add.
func add_item(item_type: String, amount: int = 1) -> bool:
	##Add items to inventory with proper item management
	_log_message("InventoryManager: Adding %d %s to inventory" % [amount, item_type])

	# Implement actual item addition logic
	if not _is_valid_item_type(item_type):
		_log_message("InventoryManager: ERROR - Invalid item type: %s" % item_type)
		return false

	if get_total_item_count() + amount > max_inventory_size:
		_log_message("InventoryManager: ERROR - Inventory full, cannot add %d %s" % [amount, item_type])
		return false

	# Add item to inventory
	if inventory_items.has(item_type):
		inventory_items[item_type] += amount
	else:
		inventory_items[item_type] = amount

	_log_message("InventoryManager: Successfully added %d %s. Total %s: %d" % [amount, item_type, item_type, inventory_items[item_type]])

	# Update inventory display
	_update_inventory_display()

	# Emit inventory changed signal
	inventory_changed.emit(inventory_items)

	return true

## Removes item from inventory.
# @param item_id: String - ID of the item to remove.
# @param quantity: int - Quantity to remove.
func remove_item(item_type: String, amount: int = 1) -> bool:
	##Remove items from inventory with validation
	_log_message("InventoryManager: Attempting to remove %d %s from inventory" % [amount, item_type])

	# Implement actual item removal logic
	if not inventory_items.has(item_type):
		_log_message("InventoryManager: ERROR - Item type %s not found in inventory" % item_type)
		return false

	if inventory_items[item_type] < amount:
		_log_message("InventoryManager: ERROR - Insufficient %s. Have: %d, Need: %d" % [item_type, inventory_items[item_type], amount])
		return false

	# Remove item from inventory
	inventory_items[item_type] -= amount

	# Remove entry if count reaches zero
	if inventory_items[item_type] <= 0:
		inventory_items.erase(item_type)
		_log_message("InventoryManager: Removed all %s from inventory" % item_type)
	else:
		_log_message("InventoryManager: Removed %d %s. Remaining: %d" % [amount, item_type, inventory_items[item_type]])

	# Update inventory display
	_update_inventory_display()

	# Emit inventory changed signal
	inventory_changed.emit(inventory_items)

	return true

## Gets the current inventory data.
func get_inventory() -> Array[Dictionary]:
	##Get the current inventory contents
	_log_message("InventoryManager: Retrieving inventory - %d items" % player_inventory.size())
	return player_inventory.duplicate()

## Clears all items from inventory.
func clear_inventory() -> Array[Dictionary]:
	##Clear all items from inventory (used when selling)
	_log_message("InventoryManager: Clearing inventory - %d items removed" % player_inventory.size())
	var cleared_items = player_inventory.duplicate()
	player_inventory.clear()
	inventory_updated.emit(player_inventory)
	return cleared_items

## Calculates the total value of all items in inventory.
func get_total_value() -> int:
	##Calculate the total value of all items in inventory
	var total_value = 0
	for item in player_inventory:
		total_value += item.get("value", 0)
	_log_message("InventoryManager: Total inventory value: %d" % total_value)
	return total_value

## Checks if inventory has space for more items.
func has_space() -> bool:
	##Check if inventory has space for more items
	return player_inventory.size() < inventory_capacity

## Gets the number of free slots in inventory.
func get_free_slots() -> int:
	##Get the number of free inventory slots
	return inventory_capacity - player_inventory.size()

## Sets the inventory capacity.
func set_capacity(new_capacity: int) -> void:
	##Set the inventory capacity
	_log_message("InventoryManager: Setting inventory capacity to %d" % new_capacity)
	inventory_capacity = new_capacity
	inventory_updated.emit(player_inventory)

func _is_valid_item_type(item_type: String) -> bool:
	##Check if item type is valid
	var valid_types = [
		"scrap_metal",
		"bio_waste",
		"broken_satellite",
		"ai_component",
		"unknown_artifact",
		"energy_cell",
		"quantum_core",
		"nano_material"
	]

	return item_type in valid_types

func get_item_type_info(item_type: String) -> Dictionary:
	##Get comprehensive information about an item type
	# Implement proper item type lookup
	var item_info = {
		"name": item_type.replace("_", " ").capitalize(),
		"category": "unknown",
		"rarity": "common",
		"base_value": 1,
		"description": "No description available"
	}

	match item_type:
		"scrap_metal":
			item_info.category = "materials"
			item_info.rarity = "common"
			item_info.base_value = 5
			item_info.description = "Common metallic debris from destroyed spacecraft"

		"bio_waste":
			item_info.category = "organics"
			item_info.rarity = "common"
			item_info.base_value = 25
			item_info.description = "Biological waste materials with potential research value"

		"broken_satellite":
			item_info.category = "technology"
			item_info.rarity = "uncommon"
			item_info.base_value = 150
			item_info.description = "Damaged satellite containing salvageable components"

		"ai_component":
			item_info.category = "technology"
			item_info.rarity = "rare"
			item_info.base_value = 500
			item_info.description = "Advanced AI processing units with high market value"

		"unknown_artifact":
			item_info.category = "artifacts"
			item_info.rarity = "legendary"
			item_info.base_value = 1000
			item_info.description = "Mysterious artifact of unknown origin"

		"energy_cell":
			item_info.category = "power"
			item_info.rarity = "uncommon"
			item_info.base_value = 75
			item_info.description = "High-capacity energy storage device"

		"quantum_core":
			item_info.category = "technology"
			item_info.rarity = "epic"
			item_info.base_value = 2500
			item_info.description = "Quantum processing core with reality-bending properties"

		"nano_material":
			item_info.category = "materials"
			item_info.rarity = "rare"
			item_info.base_value = 800
			item_info.description = "Self-assembling nanomaterial with multiple applications"

	return item_info

func get_item_value(item_type: String, amount: int = 1) -> int:
	##Calculate the total value of items with market factors
	# Implement proper item value calculation
	var item_info = get_item_type_info(item_type)
	var base_value = item_info.base_value

	# Apply rarity multiplier
	var rarity_multiplier = 1.0
	match item_info.rarity:
		"common":
			rarity_multiplier = 1.0
		"uncommon":
			rarity_multiplier = 1.2
		"rare":
			rarity_multiplier = 1.5
		"epic":
			rarity_multiplier = 2.0
		"legendary":
			rarity_multiplier = 3.0

	# Apply market fluctuation (±10% random variation)
	var market_factor = randf_range(0.9, 1.1)

	# Apply bulk discount for large quantities (5% discount per 10 items)
	var bulk_factor = 1.0
	if amount >= 10:
		bulk_factor = 1.0 - (min(amount / 10, 5) * 0.05)  # Max 25% bulk discount

	var final_value = int(base_value * rarity_multiplier * market_factor * bulk_factor * amount)

	_log_message("InventoryManager: Calculated value for %d %s: %d credits (base: %d, rarity: %.1fx, market: %.2fx, bulk: %.2fx)" %
		[amount, item_type, final_value, base_value, rarity_multiplier, market_factor, bulk_factor])

	return final_value

func _update_inventory_display() -> void:
	##Update the inventory UI display
	_log_message("InventoryManager: Updating inventory display")

	# Calculate total value
	var total_value = 0
	for item_type in inventory_items:
		total_value += get_item_value(item_type, inventory_items[item_type])

	_log_message("InventoryManager: Current inventory - Items: %d/%d, Total Value: %d credits" %
		[get_total_item_count(), max_inventory_size, total_value])

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
