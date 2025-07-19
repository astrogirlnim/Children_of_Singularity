# LocalDatabase.gd
# JSON-based local player data storage for Children of the Singularity
# Handles all personal player data locally - NO backend sync for personal data
# Alternative to LocalPlayerData.gd using simplified key-value storage

class_name LocalDatabase
extends RefCounted

## Signal emitted when data is saved successfully
signal data_saved(key: String)

## Signal emitted when data fails to save
signal save_failed(key: String, error: String)

## Signal emitted when database is ready
signal database_ready()

# JSON file paths for different data types
var db_path: String = "user://local_database.json"
var inventory_path: String = "user://local_inventory.json"
var upgrades_path: String = "user://local_upgrades.json"
var settings_path: String = "user://local_settings.json"

# In-memory data storage
var data_cache: Dictionary = {}
var inventory_data: Array[Dictionary] = []
var upgrades_data: Dictionary = {}
var settings_data: Dictionary = {}

# Initialize flag
var is_initialized: bool = false

func _init() -> void:
	_log_message("LocalDatabase: Initializing JSON-based database")
	initialize_database()

func initialize_database() -> void:
	##Initialize JSON-based database and load data
	_log_message("LocalDatabase: Setting up JSON file storage at %s" % db_path)

	# Load all data files
	_load_all_data()

	# Create default data if this is first run
	_initialize_default_data()

	is_initialized = true
	database_ready.emit()
	_log_message("LocalDatabase: Database initialization complete")

func _load_all_data() -> void:
	##Load all JSON data files
	_log_message("LocalDatabase: Loading all data files")

	# Load main data cache
	_load_cache()

	# Load inventory data
	_load_inventory_data()

	# Load upgrades data
	_load_upgrades_data()

	# Load settings data
	_load_settings_data()

func _initialize_default_data() -> void:
	##Initialize default player data on first run for JSON storage
	_log_message("LocalDatabase: Checking for default data initialization")

	# Check if this is first run
	var first_run_check = get_data("first_run_complete")
	if first_run_check != "":
		_log_message("LocalDatabase: Database already initialized, skipping defaults")
		return

	_log_message("LocalDatabase: First run detected, initializing default data")

	# Default player data
	save_data("credits", "100")
	save_data("player_name", "Space Salvager")
	save_data("zone_progress", '{"max_zone": 1, "unlocked_areas": ["zone_alpha_01"]}')
	save_data("gameplay_stats", '{"debris_collected": 0, "trades_completed": 0, "zones_explored": 1}')
	save_data("first_run_complete", "true")

	# Default upgrades (all at level 0)
	set_upgrade_level("speed_boost", 0)
	set_upgrade_level("inventory_expansion", 0)
	set_upgrade_level("collection_efficiency", 0)
	set_upgrade_level("cargo_magnet", 0)

	# Default settings
	save_setting("master_volume", "1.0")
	save_setting("sfx_volume", "1.0")
	save_setting("music_volume", "0.8")
	save_setting("graphics_quality", "high")

	_log_message("LocalDatabase: Default data initialization complete")

func _load_cache() -> void:
	##Load main data cache from JSON file
	if FileAccess.file_exists(db_path):
		var file = FileAccess.open(db_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_text)
			if parse_result == OK:
				data_cache = json.data
				_log_message("LocalDatabase: Loaded %d items into cache" % data_cache.size())
			else:
				_log_message("LocalDatabase: Error parsing main data file: %s" % json.get_error_message())
	else:
		_log_message("LocalDatabase: No cached data file found, starting fresh")

func _load_inventory_data() -> void:
	##Load inventory data from JSON file
	if FileAccess.file_exists(inventory_path):
		var file = FileAccess.open(inventory_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_text)
			if parse_result == OK:
				inventory_data = json.data
				_log_message("LocalDatabase: Loaded %d inventory items" % inventory_data.size())

func _load_upgrades_data() -> void:
	##Load upgrades data from JSON file
	if FileAccess.file_exists(upgrades_path):
		var file = FileAccess.open(upgrades_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_text)
			if parse_result == OK:
				upgrades_data = json.data
				_log_message("LocalDatabase: Loaded upgrades data")

func _load_settings_data() -> void:
	##Load settings data from JSON file
	if FileAccess.file_exists(settings_path):
		var file = FileAccess.open(settings_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_text)
			if parse_result == OK:
				settings_data = json.data
				_log_message("LocalDatabase: Loaded settings data")

## Core data operations

func save_data(key: String, value: String) -> bool:
	##Save key-value data to JSON file
	if not is_initialized:
		_log_message("LocalDatabase: ERROR - Database not initialized")
		save_failed.emit(key, "Database not initialized")
		return false

	# Update cache
	data_cache[key] = value

	# Save to JSON file
	var file = FileAccess.open(db_path, FileAccess.WRITE)
	if not file:
		save_failed.emit(key, "Could not open file for writing")
		_log_message("LocalDatabase: ERROR - Could not open file for writing")
		return false

	var json_string = JSON.stringify(data_cache, "\t")
	file.store_string(json_string)
	file.close()

	data_saved.emit(key)
	_log_message("LocalDatabase: Saved data - %s" % key)
	return true

func get_data(key: String) -> String:
	##Get data by key, return empty string if not found
	if not is_initialized:
		_log_message("LocalDatabase: ERROR - Database not initialized")
		return ""

	# Return from cache
	return data_cache.get(key, "")

func delete_data(key: String) -> bool:
	##Delete data by key
	if not is_initialized:
		return false

	# Remove from cache
	data_cache.erase(key)

	# Save updated cache to file
	var file = FileAccess.open(db_path, FileAccess.WRITE)
	if not file:
		_log_message("LocalDatabase: ERROR - Could not open file for writing")
		return false

	var json_string = JSON.stringify(data_cache, "\t")
	file.store_string(json_string)
	file.close()

	_log_message("LocalDatabase: Deleted data - %s" % key)
	return true

## Player-specific data operations

func get_credits() -> int:
	##Get player credits
	var credits_str = get_data("credits")
	return int(credits_str) if credits_str != "" else 0

func set_credits(amount: int) -> bool:
	##Set player credits
	_log_message("LocalDatabase: Setting credits to %d" % amount)
	return save_data("credits", str(amount))

func add_credits(amount: int) -> bool:
	##Add credits to player total
	var current = get_credits()
	var new_total = current + amount
	_log_message("LocalDatabase: Adding %d credits (%d -> %d)" % [amount, current, new_total])
	return set_credits(new_total)

func spend_credits(amount: int) -> bool:
	##Spend credits if player has enough
	var current = get_credits()
	if current >= amount:
		var new_total = current - amount
		_log_message("LocalDatabase: Spending %d credits (%d -> %d)" % [amount, current, new_total])
		return set_credits(new_total)
	else:
		_log_message("LocalDatabase: Insufficient credits - Need: %d, Have: %d" % [amount, current])
		return false

## Inventory operations

func add_inventory_item(item_type: String, item_id: String = "", quantity: int = 1, value: int = 0) -> bool:
	##Add item to local inventory JSON file
	if not is_initialized:
		return false

	var new_item = {
		"id": len(inventory_data) + 1,
		"type": item_type,
		"item_id": item_id,
		"quantity": quantity,
		"value": value,
		"acquired_at": Time.get_datetime_string_from_system()
	}

	inventory_data.append(new_item)

	# Save to file
	var file = FileAccess.open(inventory_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(inventory_data, "\t")
		file.store_string(json_string)
		file.close()
		_log_message("LocalDatabase: Added inventory item - %s (qty: %d, value: %d)" % [item_type, quantity, value])
		return true

	return false

func get_inventory() -> Array[Dictionary]:
	##Get all inventory items from memory
	if not is_initialized:
		return []

	return inventory_data.duplicate()

func clear_inventory() -> Array[Dictionary]:
	##Clear all inventory items and return what was cleared
	if not is_initialized:
		return []

	# Get current inventory before clearing
	var current_inventory = inventory_data.duplicate()

	# Clear the inventory
	inventory_data.clear()

	# Save empty inventory to file
	var file = FileAccess.open(inventory_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(inventory_data, "\t")
		file.store_string(json_string)
		file.close()
		_log_message("LocalDatabase: Cleared %d inventory items" % current_inventory.size())

	return current_inventory

func get_inventory_value() -> int:
	##Calculate total value of all inventory items
	var inventory = get_inventory()
	var total_value = 0

	for item in inventory:
		total_value += item.value * item.quantity

	return total_value

## Upgrade operations

func set_upgrade_level(upgrade_type: String, level: int) -> bool:
	##Set upgrade level in JSON file
	if not is_initialized:
		return false

	upgrades_data[upgrade_type] = level

	# Save to file
	var file = FileAccess.open(upgrades_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(upgrades_data, "\t")
		file.store_string(json_string)
		file.close()
		_log_message("LocalDatabase: Set upgrade %s to level %d" % [upgrade_type, level])
		return true

	return false

func get_upgrade_level(upgrade_type: String) -> int:
	##Get upgrade level from memory
	if not is_initialized:
		return 0

	return upgrades_data.get(upgrade_type, 0)

func get_all_upgrades() -> Dictionary:
	##Get all upgrade levels as dictionary
	if not is_initialized:
		return {}

	return upgrades_data.duplicate()

## Settings operations

func save_setting(setting_name: String, setting_value: String) -> bool:
	##Save a game setting to JSON file
	if not is_initialized:
		return false

	settings_data[setting_name] = setting_value

	# Save to file
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(settings_data, "\t")
		file.store_string(json_string)
		file.close()
		_log_message("LocalDatabase: Saved setting %s = %s" % [setting_name, setting_value])
		return true

	return false

func get_setting(setting_name: String, default_value: String = "") -> String:
	##Get a game setting from memory
	if not is_initialized:
		return default_value

	return settings_data.get(setting_name, default_value)

## Utility methods

func get_database_info() -> Dictionary:
	##Get database statistics and info
	return {
		"database_path": db_path,
		"is_initialized": is_initialized,
		"cache_size": data_cache.size(),
		"credits": get_credits(),
		"inventory_items": inventory_data.size(),
		"inventory_value": get_inventory_value(),
		"upgrades": get_all_upgrades()
	}

func export_save_data() -> Dictionary:
	##Export all save data for backup/transfer
	return {
		"player_data": data_cache.duplicate(),
		"inventory": inventory_data.duplicate(),
		"upgrades": upgrades_data.duplicate(),
		"settings": settings_data.duplicate(),
		"export_timestamp": Time.get_datetime_string_from_system()
	}

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
