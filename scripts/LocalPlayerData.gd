# LocalPlayerData.gd
# JSON-based local player data manager for Children of the Singularity
# Handles all personal player data locally using Godot's built-in file system
# NO backend sync for personal data - only trading goes to AWS RDS

class_name LocalPlayerData
extends RefCounted

## Signal emitted when data is saved
signal data_saved(data_type: String)

## Signal emitted when data fails to save
signal save_failed(data_type: String, error: String)

## Signal emitted when player data is loaded
signal player_data_loaded()

# File paths for different data types
var save_file_path: String = "user://player_save.json"
var settings_file_path: String = "user://player_settings.json"
var inventory_file_path: String = "user://player_inventory.json"
var upgrades_file_path: String = "user://player_upgrades.json"

# In-memory data storage
var player_data: Dictionary = {}
var player_settings: Dictionary = {}
var player_inventory: Array[Dictionary] = []
var player_upgrades: Dictionary = {}

# Initialization flag
var is_initialized: bool = false

func _init() -> void:
	_log_message("LocalPlayerData: Initializing local storage system")
	load_all_data()

func load_all_data() -> void:
	##Load all player data from local files
	_log_message("LocalPlayerData: Loading all player data from local files")

	# Load main player data
	load_player_data()

	# Load settings
	load_settings()

	# Load inventory
	load_inventory()

	# Load upgrades
	load_upgrades()

	# Initialize defaults if this is first run
	if not player_data.has("first_run_complete"):
		_initialize_defaults()

	is_initialized = true
	player_data_loaded.emit()
	_log_message("LocalPlayerData: All data loaded successfully")

func _initialize_defaults() -> void:
	##Initialize default player data on first run
	_log_message("LocalPlayerData: First run detected, initializing defaults")

	# Default player data
	player_data = {
		"credits": 100,
		"player_name": "Space Salvager",
		"player_id": _generate_player_id(),
		"zone_progress": {
			"max_zone": 1,
			"unlocked_areas": ["zone_alpha_01"],
			"current_zone": "zone_alpha_01"
		},
		"gameplay_stats": {
			"debris_collected": 0,
			"trades_completed": 0,
			"zones_explored": 1,
			"total_credits_earned": 100,
			"total_items_sold": 0
		},
		"first_run_complete": true,
		"last_played": Time.get_datetime_string_from_system()
	}

	# Default settings
	player_settings = {
		"master_volume": 1.0,
		"sfx_volume": 1.0,
		"music_volume": 0.8,
		"graphics_quality": "high",
		"fullscreen": false,
		"vsync": true,
		"auto_save": true
	}

	# Default upgrades (all at level 0)
	player_upgrades = {
		"speed_boost": 0,
		"inventory_expansion": 0,
		"collection_efficiency": 0,
		"cargo_magnet": 0
	}

	# Empty inventory
	player_inventory = []

	# Save all defaults
	save_all_data()

	_log_message("LocalPlayerData: Default data initialization complete")

func _generate_player_id() -> String:
	##Generate a unique player ID for trading
	var time_stamp = Time.get_ticks_msec()
	var random_component = randi() % 10000
	return "player_%d_%d" % [time_stamp, random_component]

## Main data file operations

func load_player_data() -> bool:
	##Load main player data from JSON file
	var file = FileAccess.open(save_file_path, FileAccess.READ)
	if not file:
		_log_message("LocalPlayerData: No save file found, will create new one")
		player_data = {}
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		_log_message("LocalPlayerData: ERROR - Failed to parse save file JSON")
		player_data = {}
		return false

	player_data = json.data
	_log_message("LocalPlayerData: Player data loaded - Credits: %d" % get_credits())
	return true

func save_player_data() -> bool:
	##Save main player data to JSON file
	player_data["last_played"] = Time.get_datetime_string_from_system()

	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if not file:
		_log_message("LocalPlayerData: ERROR - Could not open save file for writing")
		save_failed.emit("player_data", "Could not open file")
		return false

	var json_string = JSON.stringify(player_data, "\t")
	file.store_string(json_string)
	file.close()

	data_saved.emit("player_data")
	_log_message("LocalPlayerData: Player data saved")
	return true

## Settings operations

func load_settings() -> bool:
	##Load player settings from JSON file
	var file = FileAccess.open(settings_file_path, FileAccess.READ)
	if not file:
		_log_message("LocalPlayerData: No settings file found, using defaults")
		player_settings = {}
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		_log_message("LocalPlayerData: ERROR - Failed to parse settings JSON")
		player_settings = {}
		return false

	player_settings = json.data
	_log_message("LocalPlayerData: Settings loaded")
	return true

func save_settings() -> bool:
	##Save player settings to JSON file
	var file = FileAccess.open(settings_file_path, FileAccess.WRITE)
	if not file:
		_log_message("LocalPlayerData: ERROR - Could not open settings file for writing")
		save_failed.emit("settings", "Could not open file")
		return false

	var json_string = JSON.stringify(player_settings, "\t")
	file.store_string(json_string)
	file.close()

	data_saved.emit("settings")
	_log_message("LocalPlayerData: Settings saved")
	return true

## Inventory operations

func load_inventory() -> bool:
	##Load player inventory from JSON file
	var file = FileAccess.open(inventory_file_path, FileAccess.READ)
	if not file:
		_log_message("LocalPlayerData: No inventory file found, starting with empty inventory")
		player_inventory = []
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		_log_message("LocalPlayerData: ERROR - Failed to parse inventory JSON")
		player_inventory = []
		return false

	player_inventory = json.data
	_log_message("LocalPlayerData: Inventory loaded - %d items" % player_inventory.size())
	return true

func save_inventory() -> bool:
	##Save player inventory to JSON file
	var file = FileAccess.open(inventory_file_path, FileAccess.WRITE)
	if not file:
		_log_message("LocalPlayerData: ERROR - Could not open inventory file for writing")
		save_failed.emit("inventory", "Could not open file")
		return false

	var json_string = JSON.stringify(player_inventory, "\t")
	file.store_string(json_string)
	file.close()

	data_saved.emit("inventory")
	_log_message("LocalPlayerData: Inventory saved - %d items" % player_inventory.size())
	return true

## Upgrades operations

func load_upgrades() -> bool:
	##Load player upgrades from JSON file
	var file = FileAccess.open(upgrades_file_path, FileAccess.READ)
	if not file:
		_log_message("LocalPlayerData: No upgrades file found, using defaults")
		player_upgrades = {}
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		_log_message("LocalPlayerData: ERROR - Failed to parse upgrades JSON")
		player_upgrades = {}
		return false

	player_upgrades = json.data
	_log_message("LocalPlayerData: Upgrades loaded")
	return true

func save_upgrades() -> bool:
	##Save player upgrades to JSON file
	var file = FileAccess.open(upgrades_file_path, FileAccess.WRITE)
	if not file:
		_log_message("LocalPlayerData: ERROR - Could not open upgrades file for writing")
		save_failed.emit("upgrades", "Could not open file")
		return false

	var json_string = JSON.stringify(player_upgrades, "\t")
	file.store_string(json_string)
	file.close()

	data_saved.emit("upgrades")
	_log_message("LocalPlayerData: Upgrades saved")
	return true

## Convenience methods to save all data

func save_all_data() -> bool:
	##Save all player data to files
	var success = true
	success = save_player_data() and success
	success = save_settings() and success
	success = save_inventory() and success
	success = save_upgrades() and success

	if success:
		_log_message("LocalPlayerData: All data saved successfully")
	else:
		_log_message("LocalPlayerData: Some data failed to save")

	return success

## Credits management

func get_credits() -> int:
	##Get player credits
	return player_data.get("credits", 0)

func set_credits(amount: int) -> bool:
	##Set player credits
	player_data["credits"] = amount
	_log_message("LocalPlayerData: Credits set to %d" % amount)
	return save_player_data()

func add_credits(amount: int) -> bool:
	##Add credits to player total
	var current = get_credits()
	var new_total = current + amount
	player_data["credits"] = new_total

	# Update stats
	var stats = player_data.get("gameplay_stats", {})
	stats["total_credits_earned"] = stats.get("total_credits_earned", 0) + amount
	player_data["gameplay_stats"] = stats

	_log_message("LocalPlayerData: Added %d credits (%d -> %d)" % [amount, current, new_total])
	return save_player_data()

func spend_credits(amount: int) -> bool:
	##Spend credits if player has enough
	var current = get_credits()
	if current >= amount:
		var new_total = current - amount
		player_data["credits"] = new_total
		_log_message("LocalPlayerData: Spent %d credits (%d -> %d)" % [amount, current, new_total])
		return save_player_data()
	else:
		_log_message("LocalPlayerData: Insufficient credits - Need: %d, Have: %d" % [amount, current])
		return false

## Inventory management

func get_inventory() -> Array[Dictionary]:
	##Get current inventory
	return player_inventory.duplicate()

func add_inventory_item(item_type: String, item_id: String = "", quantity: int = 1, value: int = 0) -> bool:
	##Add item to inventory
	var new_item = {
		"type": item_type,
		"item_id": item_id if item_id != "" else _generate_item_id(),
		"quantity": quantity,
		"value": value,
		"acquired_at": Time.get_datetime_string_from_system()
	}

	player_inventory.append(new_item)

	# Update stats
	var stats = player_data.get("gameplay_stats", {})
	stats["debris_collected"] = stats.get("debris_collected", 0) + quantity
	player_data["gameplay_stats"] = stats
	save_player_data()

	_log_message("LocalPlayerData: Added inventory item - %s (qty: %d, value: %d)" % [item_type, quantity, value])
	return save_inventory()

func remove_inventory_item(item_id: String) -> bool:
	##Remove specific item from inventory
	for i in range(player_inventory.size()):
		if player_inventory[i].get("item_id") == item_id:
			player_inventory.remove_at(i)
			_log_message("LocalPlayerData: Removed inventory item - %s" % item_id)
			return save_inventory()

	_log_message("LocalPlayerData: Item not found for removal - %s" % item_id)
	return false

func clear_inventory() -> Array[Dictionary]:
	##Clear all inventory and return what was cleared
	var cleared_items = player_inventory.duplicate()
	player_inventory.clear()

	# Update stats
	var stats = player_data.get("gameplay_stats", {})
	stats["total_items_sold"] = stats.get("total_items_sold", 0) + cleared_items.size()
	player_data["gameplay_stats"] = stats
	save_player_data()

	save_inventory()
	_log_message("LocalPlayerData: Cleared %d inventory items" % cleared_items.size())
	return cleared_items

func get_inventory_value() -> int:
	##Calculate total value of all inventory items
	var total_value = 0
	for item in player_inventory:
		total_value += item.get("value", 0) * item.get("quantity", 1)
	return total_value

func _generate_item_id() -> String:
	##Generate a unique item ID
	var time_stamp = Time.get_ticks_msec()
	var random_component = randi() % 1000
	return "item_%d_%d" % [time_stamp, random_component]

## Upgrade management

func get_upgrade_level(upgrade_type: String) -> int:
	##Get upgrade level
	return player_upgrades.get(upgrade_type, 0)

func set_upgrade_level(upgrade_type: String, level: int) -> bool:
	##Set upgrade level
	player_upgrades[upgrade_type] = level
	_log_message("LocalPlayerData: Set upgrade %s to level %d" % [upgrade_type, level])
	return save_upgrades()

func get_all_upgrades() -> Dictionary:
	##Get all upgrade levels
	return player_upgrades.duplicate()

## Settings management

func get_setting(setting_name: String, default_value: Variant = null) -> Variant:
	##Get a setting value
	return player_settings.get(setting_name, default_value)

func set_setting(setting_name: String, value: Variant) -> bool:
	##Set a setting value
	player_settings[setting_name] = value
	_log_message("LocalPlayerData: Set setting %s = %s" % [setting_name, str(value)])
	return save_settings()

## Player info management

func get_player_name() -> String:
	##Get player name
	return player_data.get("player_name", "Space Salvager")

func set_player_name(name: String) -> bool:
	##Set player name
	player_data["player_name"] = name
	_log_message("LocalPlayerData: Player name set to %s" % name)
	return save_player_data()

func get_player_id() -> String:
	##Get unique player ID for trading
	return player_data.get("player_id", "")

func get_zone_progress() -> Dictionary:
	##Get zone progression data
	return player_data.get("zone_progress", {})

func update_zone_progress(zone_data: Dictionary) -> bool:
	##Update zone progression
	player_data["zone_progress"] = zone_data
	return save_player_data()

func get_gameplay_stats() -> Dictionary:
	##Get gameplay statistics
	return player_data.get("gameplay_stats", {})

## Utility methods

func get_all_data_info() -> Dictionary:
	##Get comprehensive info about all stored data
	return {
		"player_id": get_player_id(),
		"player_name": get_player_name(),
		"credits": get_credits(),
		"inventory_items": player_inventory.size(),
		"inventory_value": get_inventory_value(),
		"upgrades": player_upgrades,
		"zone_progress": get_zone_progress(),
		"gameplay_stats": get_gameplay_stats(),
		"last_played": player_data.get("last_played", "Never"),
		"is_initialized": is_initialized
	}

func export_all_data() -> Dictionary:
	##Export all data for backup/transfer
	return {
		"player_data": player_data.duplicate(),
		"player_settings": player_settings.duplicate(),
		"player_inventory": player_inventory.duplicate(),
		"player_upgrades": player_upgrades.duplicate(),
		"export_timestamp": Time.get_datetime_string_from_system(),
		"game_version": "1.0.0"
	}

func import_all_data(imported_data: Dictionary) -> bool:
	##Import data from backup/transfer
	if not imported_data.has("player_data"):
		_log_message("LocalPlayerData: ERROR - Invalid import data")
		return false

	player_data = imported_data.get("player_data", {})
	player_settings = imported_data.get("player_settings", {})
	player_inventory = imported_data.get("player_inventory", [])
	player_upgrades = imported_data.get("player_upgrades", {})

	save_all_data()
	_log_message("LocalPlayerData: Data imported successfully")
	return true

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
