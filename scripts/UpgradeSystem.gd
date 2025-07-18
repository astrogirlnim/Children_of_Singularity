# UpgradeSystem.gd
# Upgrade system manager for Children of the Singularity
# Handles upgrade definitions, purchasing, and effect application

class_name UpgradeSystem
extends Node

## Signal emitted when an upgrade is purchased
signal upgrade_purchased(upgrade_type: String, new_level: int, cost: int)

## Signal emitted when upgrade purchase fails
signal upgrade_purchase_failed(upgrade_type: String, reason: String)

## Signal emitted when upgrade effects are applied
signal upgrade_effects_applied(upgrade_type: String, level: int)

# Upgrade definitions
var upgrade_definitions: Dictionary = {
	"speed_boost": {
		"name": "Speed Boost",
		"description": "Increases ship movement speed",
		"max_level": 5,
		"base_cost": 100,
		"cost_multiplier": 1.5,
		"effect_per_level": 20.0,  # FIXED: Reduced from 50.0 to 20.0 for balanced progression
		"category": "movement"
	},
	"inventory_expansion": {
		"name": "Inventory Expansion",
		"description": "Increases inventory capacity",
		"max_level": 10,
		"base_cost": 200,
		"cost_multiplier": 1.3,
		"effect_per_level": 5,
		"category": "inventory"
	},
	"collection_efficiency": {
		"name": "Collection Efficiency",
		"description": "Increases collection range and speed",
		"max_level": 5,
		"base_cost": 150,
		"cost_multiplier": 1.4,
		"effect_per_level": 20.0,
		"category": "collection"
	},
	"zone_access": {
		"name": "Zone Access",
		"description": "Unlocks access to deeper zones",
		"max_level": 5,
		"base_cost": 500,
		"cost_multiplier": 2.0,
		"effect_per_level": 1,
		"category": "access"
	},
	"debris_scanner": {
		"name": "Debris Scanner",
		"description": "Highlights valuable debris on the map",
		"max_level": 3,
		"base_cost": 300,
		"cost_multiplier": 1.6,
		"effect_per_level": 1,
		"category": "utility"
	},
	"cargo_magnet": {
		"name": "Cargo Magnet",
		"description": "Automatically attracts nearby debris",
		"max_level": 3,
		"base_cost": 400,
		"cost_multiplier": 1.7,
		"effect_per_level": 1,
		"category": "collection"
	}
}

func _ready() -> void:
	_log_message("UpgradeSystem: Initializing upgrade system")
	_log_message("UpgradeSystem: Loaded %d upgrade types" % upgrade_definitions.size())

## Get upgrade information
func get_upgrade_info(upgrade_type: String) -> Dictionary:
	##Get complete information about an upgrade
	if upgrade_type in upgrade_definitions:
		return upgrade_definitions[upgrade_type].duplicate()
	else:
		_log_message("UpgradeSystem: Unknown upgrade type: %s" % upgrade_type)
		return {}

## Calculate upgrade cost
func calculate_upgrade_cost(upgrade_type: String, current_level: int) -> int:
	##Calculate the cost to upgrade to the next level
	if upgrade_type not in upgrade_definitions:
		return -1

	var upgrade_data = upgrade_definitions[upgrade_type]
	var base_cost = upgrade_data.base_cost
	var cost_multiplier = upgrade_data.cost_multiplier

	# Cost increases exponentially with level
	var cost = int(base_cost * pow(cost_multiplier, current_level))
	return cost

## Check if upgrade is available
func can_upgrade(upgrade_type: String, current_level: int, available_credits: int) -> Dictionary:
	##Check if an upgrade can be purchased
	var result = {
		"can_upgrade": false,
		"reason": "",
		"cost": 0
	}

	if upgrade_type not in upgrade_definitions:
		result.reason = "Unknown upgrade type"
		return result

	var upgrade_data = upgrade_definitions[upgrade_type]
	var max_level = upgrade_data.max_level

	if current_level >= max_level:
		result.reason = "Maximum level reached"
		return result

	var cost = calculate_upgrade_cost(upgrade_type, current_level)
	result.cost = cost

	if available_credits < cost:
		result.reason = "Insufficient credits"
		return result

	result.can_upgrade = true
	return result

## Purchase upgrade
func purchase_upgrade(upgrade_type: String, current_level: int, available_credits: int) -> Dictionary:
	##Attempt to purchase an upgrade
	_log_message("UpgradeSystem: Attempting to purchase %s upgrade (current level: %d)" % [upgrade_type, current_level])

	var upgrade_check = can_upgrade(upgrade_type, current_level, available_credits)

	if not upgrade_check.can_upgrade:
		_log_message("UpgradeSystem: Purchase failed - %s" % upgrade_check.reason)
		upgrade_purchase_failed.emit(upgrade_type, upgrade_check.reason)
		return {"success": false, "reason": upgrade_check.reason, "cost": upgrade_check.cost}

	var new_level = current_level + 1
	var cost = upgrade_check.cost

	_log_message("UpgradeSystem: Purchase successful - %s level %d for %d credits" % [upgrade_type, new_level, cost])
	upgrade_purchased.emit(upgrade_type, new_level, cost)

	return {
		"success": true,
		"new_level": new_level,
		"cost": cost,
		"upgrade_type": upgrade_type
	}

## Apply upgrade effects
func apply_upgrade_effects(upgrade_type: String, level: int, target_node: Node) -> void:
	##Apply upgrade effects to a target node (usually PlayerShip)
	if upgrade_type not in upgrade_definitions:
		_log_message("UpgradeSystem: Cannot apply unknown upgrade: %s" % upgrade_type)
		return

	var upgrade_data = upgrade_definitions[upgrade_type]
	var effect_per_level = upgrade_data.effect_per_level

	_log_message("UpgradeSystem: Applying %s level %d effects" % [upgrade_type, level])

	match upgrade_type:
		"speed_boost":
			if target_node.has_method("set_speed"):
				# FIXED: Much more reasonable speed progression
				var new_speed = 120.0 + (level * 20.0)  # Base 120, +20 per level (was 200 + 50!)
				target_node.set_speed(new_speed)
			elif target_node.has_property("speed"):
				target_node.speed = 120.0 + (level * 20.0)  # Base 120, +20 per level (was 200 + 50!)

		"inventory_expansion":
			if target_node.has_method("set_inventory_capacity"):
				var new_capacity = 10 + (level * int(effect_per_level))
				target_node.set_inventory_capacity(new_capacity)
			elif target_node.has_property("inventory_capacity"):
				target_node.inventory_capacity = 10 + (level * int(effect_per_level))

		"collection_efficiency":
			if target_node.has_method("set_collection_range"):
				var new_range = 80.0 + (level * effect_per_level)
				target_node.set_collection_range(new_range)
			elif target_node.has_property("collection_range"):
				target_node.collection_range = 80.0 + (level * effect_per_level)

		"zone_access":
			if target_node.has_method("set_zone_access"):
				target_node.set_zone_access(level)
			elif target_node.has_property("zone_access_level"):
				target_node.zone_access_level = level

		"debris_scanner":
			if target_node.has_method("enable_debris_scanner"):
				target_node.enable_debris_scanner(level > 0)

		"cargo_magnet":
			if target_node.has_method("enable_cargo_magnet"):
				target_node.enable_cargo_magnet(level > 0)

	upgrade_effects_applied.emit(upgrade_type, level)

## Get all available upgrades
func get_all_upgrades() -> Dictionary:
	##Get all upgrade definitions
	return upgrade_definitions.duplicate()

## Get upgrades by category
func get_upgrades_by_category(category: String) -> Array[String]:
	##Get all upgrades in a specific category
	var upgrades = []
	for upgrade_type in upgrade_definitions:
		if upgrade_definitions[upgrade_type].category == category:
			upgrades.append(upgrade_type)
	return upgrades

## Get upgrade categories
func get_upgrade_categories() -> Array[String]:
	##Get all unique upgrade categories
	var categories = []
	for upgrade_type in upgrade_definitions:
		var category = upgrade_definitions[upgrade_type].category
		if category not in categories:
			categories.append(category)
	return categories

## Get upgrade progress summary
func get_upgrade_summary(current_upgrades: Dictionary) -> Dictionary:
	##Get a summary of current upgrade progress
	var summary = {
		"total_upgrades": upgrade_definitions.size(),
		"purchased_upgrades": 0,
		"max_level_upgrades": 0,
		"total_levels": 0,
		"categories": {}
	}

	for upgrade_type in upgrade_definitions:
		var current_level = current_upgrades.get(upgrade_type, 0)
		var max_level = upgrade_definitions[upgrade_type].max_level
		var category = upgrade_definitions[upgrade_type].category

		if current_level > 0:
			summary.purchased_upgrades += 1
			summary.total_levels += current_level

		if current_level >= max_level:
			summary.max_level_upgrades += 1

		if category not in summary.categories:
			summary.categories[category] = {
				"total": 0,
				"purchased": 0,
				"max_level": 0
			}

		summary.categories[category].total += 1
		if current_level > 0:
			summary.categories[category].purchased += 1
		if current_level >= max_level:
			summary.categories[category].max_level += 1

	return summary

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
