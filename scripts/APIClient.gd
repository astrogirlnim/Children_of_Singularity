# APIClient.gd
# Local-only API client for Children of the Singularity
# Provides unified interface for local data operations via LocalPlayerData.gd
# AWS Trading functionality handled separately by TradingMarketplace.gd

class_name APIClient
extends HTTPRequest

## Signal emitted when player data is loaded
signal player_data_loaded(player_data: Dictionary)

## Signal emitted when inventory is updated
signal inventory_updated(inventory_data: Array)

## Signal emitted when credits are updated
signal credits_updated(credits: int)

## Signal emitted when API request fails
signal api_error(error_message: String)

## Signal emitted when upgrade purchase is successful
signal upgrade_purchased(result: Dictionary)

## Signal emitted when upgrade purchase fails
signal upgrade_purchase_failed(reason: String, upgrade_type: String)

## Signal emitted when upgrades are cleared
signal upgrades_cleared(cleared_data: Dictionary)

# Local-only mode configuration
var use_local_storage: bool = true  # Always true - no backend
var local_player_data: LocalPlayerData

func _ready() -> void:
	_log_message("APIClient: === INITIALIZING LOCAL-ONLY CLIENT ===")
	_log_message("APIClient: Initializing local-only APIClient")

	# Initialize reference to LocalPlayerData autoload singleton
	local_player_data = LocalPlayerData
	_log_message("APIClient: LocalPlayerData reference obtained - is_initialized: %s" % local_player_data.is_initialized)

	# Wait for LocalPlayerData to be fully loaded before proceeding
	if not local_player_data.is_initialized:
		_log_message("APIClient: LocalPlayerData not ready, waiting for player_data_loaded signal...")
		await local_player_data.player_data_loaded
		_log_message("APIClient: LocalPlayerData ready signal received, proceeding with initialization")
	else:
		_log_message("APIClient: LocalPlayerData already initialized, proceeding immediately")

	_log_message("APIClient: === LOCAL-ONLY CLIENT READY ===")
	_log_message("APIClient: Local-only client ready for all data operations")

## Check if APIClient is using local storage mode (always true)
func is_using_local_storage() -> bool:
	"""Return true if APIClient is operating in local storage mode (always true)"""
	return true

## Load player data (local-only)
func load_player_data(target_player_id: String = "") -> void:
	_log_message("APIClient: === LOADING PLAYER DATA FROM LOCAL STORAGE ===")
	_log_message("APIClient: Loading player data from local storage")

	# Ensure LocalPlayerData is fully initialized
	if not local_player_data.is_initialized:
		_log_message("APIClient: LocalPlayerData not ready, waiting...")
		await local_player_data.player_data_loaded
		_log_message("APIClient: LocalPlayerData is now ready")

	# Use LocalPlayerData singleton
	var player_data = {
		"id": target_player_id if target_player_id else local_player_data.get_player_id(),
		"name": local_player_data.get_player_name(),
		"credits": local_player_data.get_credits(),
		"upgrades": local_player_data.player_upgrades,
		"progression": local_player_data.player_data.get("progression", {}),
		"position": local_player_data.player_data.get("position", {"x": 0, "y": 0, "z": 0})
	}

	_log_message("APIClient: Loaded local player data - Credits: %d, Upgrades: %s" % [player_data["credits"], player_data["upgrades"]])

	# Emit signal with local data
	player_data_loaded.emit(player_data)
	_log_message("APIClient: === PLAYER DATA LOADED AND EMITTED ===")

## Save player data (local-only)
func save_player_data(player_data: Dictionary) -> void:
	_log_message("APIClient: Saving player data to local storage")

	# Update LocalPlayerData with provided data
	if player_data.has("credits"):
		local_player_data.set_credits(player_data["credits"])

	if player_data.has("name"):
		local_player_data.set_player_name(player_data["name"])

	if player_data.has("upgrades"):
		local_player_data.player_upgrades = player_data["upgrades"]
		local_player_data.save_upgrades()

	if player_data.has("progression"):
		local_player_data.player_data["progression"] = player_data["progression"]
		local_player_data.save_player_data()

	_log_message("APIClient: Player data saved to local storage")

## Load inventory (local-only)
func load_inventory(target_player_id: String = "") -> void:
	_log_message("APIClient: === LOADING INVENTORY FROM LOCAL STORAGE ===")
	_log_message("APIClient: Loading inventory from local storage")

	# Ensure LocalPlayerData is fully initialized
	if not local_player_data.is_initialized:
		_log_message("APIClient: LocalPlayerData not ready for inventory, waiting...")
		await local_player_data.player_data_loaded

	# Get inventory from LocalPlayerData
	var inventory_data = local_player_data.player_inventory

	_log_message("APIClient: Loaded local inventory - %d items" % inventory_data.size())

	# Emit signal with inventory data
	inventory_updated.emit(inventory_data)
	_log_message("APIClient: === INVENTORY LOADED AND EMITTED ===")

## Add inventory item (local-only)
func add_inventory_item(item_data: Dictionary) -> void:
	_log_message("APIClient: Adding item to local inventory: %s" % item_data)

	# Add item to LocalPlayerData inventory
	local_player_data.player_inventory.append(item_data)
	local_player_data.save_inventory()

	# Emit inventory updated signal
	inventory_updated.emit(local_player_data.player_inventory)

## Clear inventory (local-only)
func clear_inventory() -> void:
	_log_message("APIClient: Clearing local inventory")

	local_player_data.player_inventory.clear()
	local_player_data.save_inventory()

	# Emit signal
	inventory_updated.emit([])

## Clear upgrades (local-only)
func clear_upgrades() -> void:
	_log_message("APIClient: Clearing local upgrades")

	local_player_data.player_upgrades.clear()
	local_player_data.save_upgrades()

	# Emit signal
	upgrades_cleared.emit({"success": true})

## Update credits (local-only)
func update_credits(credit_change: int) -> void:
	_log_message("APIClient: Updating credits locally by %d" % credit_change)

	local_player_data.add_credits(credit_change)
	var new_credits = local_player_data.get_credits()

	_log_message("APIClient: Credits updated to %d" % new_credits)

## Health check (always succeeds for local-only)
func check_backend_health() -> void:
	_log_message("APIClient: Local storage health check - always healthy")
	# Local storage is always "healthy"

## Local upgrade purchase
func purchase_upgrade(upgrade_type: String, expected_cost: int, target_player_id: String = "") -> void:
	_log_message("APIClient: Processing local upgrade purchase - Type: %s, Cost: %d" % [upgrade_type, expected_cost])

	# Check if player has enough credits
	var current_credits = local_player_data.get_credits()
	if current_credits < expected_cost:
		_log_message("APIClient: Insufficient credits for upgrade - Have: %d, Need: %d" % [current_credits, expected_cost])
		var error_message = "Insufficient credits. Need: %d, Have: %d" % [expected_cost, current_credits]
		upgrade_purchase_failed.emit(error_message, upgrade_type)
		return

	# Deduct credits
	local_player_data.add_credits(-expected_cost)

	# Apply upgrade
	var current_level = local_player_data.player_upgrades.get(upgrade_type, 0)
	var new_level = current_level + 1
	local_player_data.player_upgrades[upgrade_type] = new_level
	local_player_data.save_upgrades()

	var new_credits = local_player_data.get_credits()
	_log_message("APIClient: Local upgrade successful - Type: %s, Level: %d, Credits remaining: %d" % [upgrade_type, new_level, new_credits])

	# Emit success signal
	var result = {
		"upgrade_type": upgrade_type,
		"new_level": new_level,
		"cost": expected_cost,
		"remaining_credits": new_credits,
		"success": true
	}

	upgrade_purchased.emit(result)

## Sell all inventory items (local-only)
func sell_all_inventory() -> void:
	_log_message("APIClient: Selling all inventory locally")

	# Calculate total value
	var total_value = 0
	var items_sold = 0
	for item in local_player_data.player_inventory:
		if item.has("value") and item.has("quantity"):
			total_value += item["value"] * item["quantity"]
			items_sold += item["quantity"]
		elif item.has("value"):
			total_value += item["value"]
			items_sold += 1

	# Clear inventory and add credits
	local_player_data.clear_inventory()
	local_player_data.add_credits(total_value)

	_log_message("APIClient: Sold %d items for %d credits locally" % [items_sold, total_value])

	# Emit signals for UI updates
	inventory_updated.emit([])  # Empty inventory
	credits_updated.emit(local_player_data.get_credits())

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
