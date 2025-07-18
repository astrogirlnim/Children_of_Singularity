# LocalDatabase.gd
# SQLite wrapper for local player data storage in Children of the Singularity
# Handles all personal player data locally - NO backend sync for personal data

class_name LocalDatabase
extends RefCounted

## Signal emitted when data is saved successfully
signal data_saved(key: String)

## Signal emitted when data fails to save
signal save_failed(key: String, error: String)

## Signal emitted when database is ready
signal database_ready()

# Database connection
var db: SQLiteDatabase

# Database file path
var db_path: String = "user://save_data.db"

# Cache for frequently accessed data
var data_cache: Dictionary = {}

# Initialize flag
var is_initialized: bool = false

func _init() -> void:
	_log_message("LocalDatabase: Initializing SQLite database")
	initialize_database()

func initialize_database() -> void:
	##Initialize SQLite database and create tables
	_log_message("LocalDatabase: Opening database at %s" % db_path)

	# Create SQLite database instance
	db = SQLiteDatabase.new()

	if not db.open(db_path):
		_log_message("LocalDatabase: ERROR - Failed to open database at %s" % db_path)
		return

	_log_message("LocalDatabase: Database opened successfully")

	# Create tables if they don't exist
	_create_tables()

	# Load initial cache
	_load_cache()

	is_initialized = true
	database_ready.emit()
	_log_message("LocalDatabase: Database initialization complete")

func _create_tables() -> void:
	##Create all necessary tables for local storage
	_log_message("LocalDatabase: Creating tables")

	# Main player data table (key-value storage)
	var player_data_sql = """
		CREATE TABLE IF NOT EXISTS player_data (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP
		)
	"""

	# Local inventory table
	var inventory_sql = """
		CREATE TABLE IF NOT EXISTS local_inventory (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			item_type TEXT NOT NULL,
			item_id TEXT,
			quantity INTEGER NOT NULL DEFAULT 1,
			value INTEGER NOT NULL DEFAULT 0,
			acquired_at TEXT DEFAULT CURRENT_TIMESTAMP
		)
	"""

	# Local upgrades table
	var upgrades_sql = """
		CREATE TABLE IF NOT EXISTS local_upgrades (
			upgrade_type TEXT PRIMARY KEY,
			level INTEGER NOT NULL DEFAULT 0,
			purchased_at TEXT DEFAULT CURRENT_TIMESTAMP
		)
	"""

	# Settings table
	var settings_sql = """
		CREATE TABLE IF NOT EXISTS local_settings (
			setting_name TEXT PRIMARY KEY,
			setting_value TEXT NOT NULL,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP
		)
	"""

	# Execute table creation
	if not db.query(player_data_sql):
		_log_message("LocalDatabase: ERROR - Failed to create player_data table")
		return

	if not db.query(inventory_sql):
		_log_message("LocalDatabase: ERROR - Failed to create local_inventory table")
		return

	if not db.query(upgrades_sql):
		_log_message("LocalDatabase: ERROR - Failed to create local_upgrades table")
		return

	if not db.query(settings_sql):
		_log_message("LocalDatabase: ERROR - Failed to create local_settings table")
		return

	_log_message("LocalDatabase: All tables created successfully")

	# Initialize default data if this is first run
	_initialize_default_data()

func _initialize_default_data() -> void:
	##Initialize default player data on first run
	_log_message("LocalDatabase: Checking for default data initialization")

	# Check if this is first run
	var first_run_check = get_data("first_run_complete")
	if first_run_check != null:
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
	##Load frequently accessed data into cache
	_log_message("LocalDatabase: Loading data cache")

	var query = "SELECT key, value FROM player_data"
	var result = db.query_with_bindings(query, [])

	if result:
		for row in result:
			data_cache[row.key] = row.value
		_log_message("LocalDatabase: Loaded %d items into cache" % data_cache.size())
	else:
		_log_message("LocalDatabase: No cached data to load")

## Core data operations

func save_data(key: String, value: String) -> bool:
	##Save key-value data to database
	if not is_initialized:
		_log_message("LocalDatabase: ERROR - Database not initialized")
		save_failed.emit(key, "Database not initialized")
		return false

	var query = """
		INSERT OR REPLACE INTO player_data (key, value, updated_at)
		VALUES (?, ?, datetime('now'))
	"""

	var success = db.query_with_bindings(query, [key, value])

	if success:
		data_cache[key] = value
		data_saved.emit(key)
		_log_message("LocalDatabase: Saved data - %s" % key)
		return true
	else:
		save_failed.emit(key, "Database query failed")
		_log_message("LocalDatabase: ERROR - Failed to save %s" % key)
		return false

func get_data(key: String) -> String:
	##Get data by key, return null if not found
	if not is_initialized:
		_log_message("LocalDatabase: ERROR - Database not initialized")
		return ""

	# Check cache first
	if key in data_cache:
		return data_cache[key]

	# Query database
	var query = "SELECT value FROM player_data WHERE key = ?"
	var result = db.query_with_bindings(query, [key])

	if result and result.size() > 0:
		var value = result[0].value
		data_cache[key] = value
		return value

	return ""

func delete_data(key: String) -> bool:
	##Delete data by key
	if not is_initialized:
		return false

	var query = "DELETE FROM player_data WHERE key = ?"
	var success = db.query_with_bindings(query, [key])

	if success:
		data_cache.erase(key)
		_log_message("LocalDatabase: Deleted data - %s" % key)
		return true

	return false

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
	##Add item to local inventory
	if not is_initialized:
		return false

	var query = """
		INSERT INTO local_inventory (item_type, item_id, quantity, value, acquired_at)
		VALUES (?, ?, ?, ?, datetime('now'))
	"""

	var success = db.query_with_bindings(query, [item_type, item_id, quantity, value])

	if success:
		_log_message("LocalDatabase: Added inventory item - %s (qty: %d, value: %d)" % [item_type, quantity, value])
		return true

	return false

func get_inventory() -> Array[Dictionary]:
	##Get all inventory items
	if not is_initialized:
		return []

	var query = """
		SELECT id, item_type, item_id, quantity, value, acquired_at
		FROM local_inventory
		ORDER BY acquired_at DESC
	"""

	var result = db.query_with_bindings(query, [])
	var inventory: Array[Dictionary] = []

	if result:
		for row in result:
			inventory.append({
				"id": row.id,
				"type": row.item_type,
				"item_id": row.item_id,
				"quantity": row.quantity,
				"value": row.value,
				"acquired_at": row.acquired_at
			})

	return inventory

func clear_inventory() -> Array[Dictionary]:
	##Clear all inventory items and return what was cleared
	if not is_initialized:
		return []

	# Get current inventory before clearing
	var current_inventory = get_inventory()

	# Clear the inventory
	var query = "DELETE FROM local_inventory"
	var success = db.query(query)

	if success:
		_log_message("LocalDatabase: Cleared %d inventory items" % current_inventory.size())
		return current_inventory

	return []

func get_inventory_value() -> int:
	##Calculate total value of all inventory items
	var inventory = get_inventory()
	var total_value = 0

	for item in inventory:
		total_value += item.value * item.quantity

	return total_value

## Upgrade operations

func set_upgrade_level(upgrade_type: String, level: int) -> bool:
	##Set upgrade level
	if not is_initialized:
		return false

	var query = """
		INSERT OR REPLACE INTO local_upgrades (upgrade_type, level, purchased_at)
		VALUES (?, ?, datetime('now'))
	"""

	var success = db.query_with_bindings(query, [upgrade_type, level])

	if success:
		_log_message("LocalDatabase: Set upgrade %s to level %d" % [upgrade_type, level])
		return true

	return false

func get_upgrade_level(upgrade_type: String) -> int:
	##Get upgrade level
	if not is_initialized:
		return 0

	var query = "SELECT level FROM local_upgrades WHERE upgrade_type = ?"
	var result = db.query_with_bindings(query, [upgrade_type])

	if result and result.size() > 0:
		return result[0].level

	return 0

func get_all_upgrades() -> Dictionary:
	##Get all upgrade levels as dictionary
	if not is_initialized:
		return {}

	var query = "SELECT upgrade_type, level FROM local_upgrades"
	var result = db.query_with_bindings(query, [])
	var upgrades = {}

	if result:
		for row in result:
			upgrades[row.upgrade_type] = row.level

	return upgrades

## Settings operations

func save_setting(setting_name: String, setting_value: String) -> bool:
	##Save a game setting
	if not is_initialized:
		return false

	var query = """
		INSERT OR REPLACE INTO local_settings (setting_name, setting_value, updated_at)
		VALUES (?, ?, datetime('now'))
	"""

	var success = db.query_with_bindings(query, [setting_name, setting_value])

	if success:
		_log_message("LocalDatabase: Saved setting %s = %s" % [setting_name, setting_value])
		return true

	return false

func get_setting(setting_name: String, default_value: String = "") -> String:
	##Get a game setting
	if not is_initialized:
		return default_value

	var query = "SELECT setting_value FROM local_settings WHERE setting_name = ?"
	var result = db.query_with_bindings(query, [setting_name])

	if result and result.size() > 0:
		return result[0].setting_value

	return default_value

## Utility methods

func get_database_info() -> Dictionary:
	##Get database statistics and info
	return {
		"database_path": db_path,
		"is_initialized": is_initialized,
		"cache_size": data_cache.size(),
		"credits": get_credits(),
		"inventory_items": get_inventory().size(),
		"inventory_value": get_inventory_value(),
		"upgrades": get_all_upgrades()
	}

func export_save_data() -> Dictionary:
	##Export all save data for backup/transfer
	return {
		"player_data": data_cache.duplicate(),
		"inventory": get_inventory(),
		"upgrades": get_all_upgrades(),
		"export_timestamp": Time.get_datetime_string_from_system()
	}

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
