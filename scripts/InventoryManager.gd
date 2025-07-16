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

var player_inventory: Array[Dictionary] = []
var inventory_capacity: int = 10
var max_stack_size: int = 99

func _ready() -> void:
	_log_message("InventoryManager: Initializing inventory system")
	_initialize_inventory()
	_log_message("InventoryManager: Inventory system ready")

func _initialize_inventory() -> void:
	##Initialize the inventory system
	_log_message("InventoryManager: Setting up inventory structure")
	player_inventory.clear()
	_log_message("InventoryManager: Inventory initialized with capacity: %d" % inventory_capacity)

## Adds item to inventory.
# @param item_id: String - ID of the item.
# @param quantity: int - Quantity to add.
func add_item(item_id: String, quantity: int) -> bool:
	##Add an item to the inventory
	_log_message("InventoryManager: Adding item %s (quantity: %d)" % [item_id, quantity])

	# Check if inventory has space
	if player_inventory.size() >= inventory_capacity:
		_log_message("InventoryManager: Inventory full - cannot add item")
		inventory_full.emit()
		return false

	# TODO: Implement actual item addition logic
	var new_item = {
		"item_id": item_id,
		"item_type": _get_item_type(item_id),
		"quantity": quantity,
		"value": _calculate_item_value(item_id, quantity),
		"timestamp": Time.get_unix_time_from_system()
	}

	player_inventory.append(new_item)
	_log_message("InventoryManager: Item added successfully - Total items: %d" % player_inventory.size())

	item_added.emit(new_item.item_type, quantity)
	inventory_updated.emit(player_inventory)
	return true

## Removes item from inventory.
# @param item_id: String - ID of the item to remove.
# @param quantity: int - Quantity to remove.
func remove_item(item_id: String, quantity: int) -> bool:
	##Remove an item from the inventory
	_log_message("InventoryManager: Removing item %s (quantity: %d)" % [item_id, quantity])

	# TODO: Implement actual item removal logic
	for i in range(player_inventory.size()):
		if player_inventory[i].item_id == item_id:
			var item = player_inventory[i]
			if item.quantity >= quantity:
				item.quantity -= quantity
				if item.quantity <= 0:
					player_inventory.remove_at(i)
				_log_message("InventoryManager: Item removed successfully")
				item_removed.emit(item.item_type, quantity)
				inventory_updated.emit(player_inventory)
				return true
			else:
				_log_message("InventoryManager: Insufficient quantity to remove")
				return false

	_log_message("InventoryManager: Item not found in inventory")
	return false

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

func _get_item_type(item_id: String) -> String:
	##Get the type of an item based on its ID
	# TODO: Implement proper item type lookup
	if item_id.begins_with("scrap"):
		return "scrap_metal"
	elif item_id.begins_with("satellite"):
		return "broken_satellite"
	elif item_id.begins_with("bio"):
		return "bio_waste"
	elif item_id.begins_with("ai"):
		return "ai_component"
	else:
		return "generic"

func _calculate_item_value(item_id: String, quantity: int) -> int:
	##Calculate the value of an item
	# TODO: Implement proper item value calculation
	var base_value = 10
	var item_type = _get_item_type(item_id)

	match item_type:
		"scrap_metal":
			base_value = 5
		"broken_satellite":
			base_value = 150
		"bio_waste":
			base_value = 25
		"ai_component":
			base_value = 500
		_:
			base_value = 10

	return base_value * quantity

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
