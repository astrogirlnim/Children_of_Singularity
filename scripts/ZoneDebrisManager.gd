# ZoneDebrisManager.gd
# Debris manager for Children of the Singularity
# Handles debris spawning, collection, types, and lifecycle management

class_name ZoneDebrisManager
extends Node

## Signal emitted when debris is spawned
signal debris_spawned(debris: Node2D)

## Signal emitted when debris is collected
signal debris_collected(debris_type: String, value: int)

## Signal emitted when debris count changes
signal debris_count_changed(count: int)

## Signal emitted when debris despawns
signal debris_despawned(debris: Node2D)

@export var debris_container: Node2D
@export var zone_bounds: Rect2 = Rect2(-1000, -1000, 2000, 2000)
@export var max_debris_count: int = 50
@export var spawn_interval: float = 2.0
@export var despawn_distance: float = 1500.0

# Debris types configuration
var debris_types: Array[Dictionary] = [
	{"type": "scrap_metal", "value": 5, "spawn_weight": 40, "color": Color.GRAY},
	{"type": "broken_satellite", "value": 150, "spawn_weight": 10, "color": Color.SILVER},
	{"type": "bio_waste", "value": 25, "spawn_weight": 25, "color": Color.GREEN},
	{"type": "ai_component", "value": 500, "spawn_weight": 5, "color": Color.CYAN},
	{"type": "unknown_artifact", "value": 1000, "spawn_weight": 1, "color": Color.PURPLE}
]

# Internal state
var current_debris_count: int = 0
var active_debris: Array[Node2D] = []
var spawn_timer: float = 0.0
var weighted_spawn_table: Array[String] = []

# References
var player_ship: Node2D

func _ready() -> void:
	print("ZoneDebrisManager: Initializing debris manager")
	_build_weighted_spawn_table()
	_spawn_initial_debris()

func _process(delta: float) -> void:
	spawn_timer += delta

	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_attempt_debris_spawn()

	_cleanup_distant_debris()

func _build_weighted_spawn_table() -> void:
	"""Build weighted spawn table for debris types"""
	weighted_spawn_table.clear()

	for debris_type in debris_types:
		var type_name = debris_type.get("type", "unknown")
		var weight = debris_type.get("spawn_weight", 1)

		# Add type to table multiple times based on weight
		for i in range(weight):
			weighted_spawn_table.append(type_name)

	print("ZoneDebrisManager: Weighted spawn table built with %d entries" % weighted_spawn_table.size())

func _spawn_initial_debris() -> void:
	"""Spawn initial debris to populate the zone"""
	print("ZoneDebrisManager: Spawning initial debris")

	var initial_count = min(max_debris_count * 0.7, 30)  # Start with 70% of max or 30, whichever is smaller

	for i in range(initial_count):
		_spawn_debris_at_random_position()

	print("ZoneDebrisManager: Spawned %d initial debris" % initial_count)

func _attempt_debris_spawn() -> void:
	"""Attempt to spawn new debris if under the limit"""
	if current_debris_count >= max_debris_count:
		return

	if not player_ship:
		return

	# Try to spawn debris away from player
	var spawn_position = _get_spawn_position_away_from_player()
	if spawn_position != Vector2.ZERO:
		_spawn_debris_at_position(spawn_position)

func _spawn_debris_at_random_position() -> void:
	"""Spawn debris at a random position within zone bounds"""
	var random_pos = Vector2(
		randf_range(zone_bounds.position.x, zone_bounds.position.x + zone_bounds.size.x),
		randf_range(zone_bounds.position.y, zone_bounds.position.y + zone_bounds.size.y)
	)

	_spawn_debris_at_position(random_pos)

func _get_spawn_position_away_from_player() -> Vector2:
	"""Get spawn position that's away from the player"""
	if not player_ship:
		return Vector2.ZERO

	var player_pos = player_ship.global_position
	var min_distance = 300.0  # Minimum distance from player
	var max_attempts = 10

	for attempt in range(max_attempts):
		var random_pos = Vector2(
			randf_range(zone_bounds.position.x, zone_bounds.position.x + zone_bounds.size.x),
			randf_range(zone_bounds.position.y, zone_bounds.position.y + zone_bounds.size.y)
		)

		if player_pos.distance_to(random_pos) >= min_distance:
			return random_pos

	return Vector2.ZERO  # Failed to find suitable position

func _spawn_debris_at_position(position: Vector2) -> void:
	"""Spawn debris at specific position"""
	if not debris_container:
		push_error("ZoneDebrisManager: No debris container assigned!")
		return

	var debris_type = _get_random_debris_type()
	var debris_node = _create_debris_node(debris_type, position)

	if debris_node:
		debris_container.add_child(debris_node)
		active_debris.append(debris_node)
		current_debris_count += 1

		debris_spawned.emit(debris_node)
		debris_count_changed.emit(current_debris_count)

		print("ZoneDebrisManager: Spawned %s at %s" % [debris_type.get("type", "unknown"), position])

func _get_random_debris_type() -> Dictionary:
	"""Get random debris type based on weighted probabilities"""
	if weighted_spawn_table.is_empty():
		return debris_types[0]  # Fallback

	var random_type_name = weighted_spawn_table[randi() % weighted_spawn_table.size()]

	for debris_type in debris_types:
		if debris_type.get("type", "") == random_type_name:
			return debris_type

	return debris_types[0]  # Fallback

func _create_debris_node(debris_type: Dictionary, position: Vector2) -> Node2D:
	"""Create a debris node with proper components"""
	var debris_node = preload("res://scripts/DebrisObject.gd").new()
	debris_node.position = position
	debris_node.name = "Debris_%s_%d" % [debris_type.get("type", "unknown"), Time.get_ticks_msec()]

	# Set debris properties
	debris_node.debris_type = debris_type.get("type", "unknown")
	debris_node.value = debris_type.get("value", 1)
	debris_node.color = debris_type.get("color", Color.WHITE)

	# Connect collection signal
	if debris_node.has_signal("collected"):
		debris_node.collected.connect(_on_debris_collected)

	return debris_node

func _cleanup_distant_debris() -> void:
	"""Remove debris that's too far from player"""
	if not player_ship:
		return

	var player_pos = player_ship.global_position
	var debris_to_remove: Array[Node2D] = []

	for debris in active_debris:
		if not is_instance_valid(debris):
			debris_to_remove.append(debris)
			continue

		var distance = player_pos.distance_to(debris.global_position)
		if distance > despawn_distance:
			debris_to_remove.append(debris)

	for debris in debris_to_remove:
		_remove_debris(debris)

func _remove_debris(debris: Node2D) -> void:
	"""Remove a debris node from the game"""
	if debris in active_debris:
		active_debris.erase(debris)
		current_debris_count -= 1

		debris_despawned.emit(debris)
		debris_count_changed.emit(current_debris_count)

		if is_instance_valid(debris):
			debris.queue_free()

		print("ZoneDebrisManager: Removed debris, count now: %d" % current_debris_count)

## Public API Methods

func set_player_reference(player: Node2D) -> void:
	"""Set player reference for distance calculations"""
	player_ship = player
	print("ZoneDebrisManager: Player reference set to: %s" % (player.name if player else "none"))

func get_debris_count() -> int:
	"""Get current debris count"""
	return current_debris_count

func get_debris_in_range(center: Vector2, radius: float) -> Array[Node2D]:
	"""Get all debris within range of a position"""
	var debris_in_range: Array[Node2D] = []

	for debris in active_debris:
		if not is_instance_valid(debris):
			continue

		if center.distance_to(debris.global_position) <= radius:
			debris_in_range.append(debris)

	return debris_in_range

func collect_debris(debris: Node2D) -> Dictionary:
	"""Collect a debris item and return its data"""
	if not debris in active_debris:
		return {}

	var debris_data = {
		"type": debris.get("debris_type") if debris.has_method("get") else "unknown",
		"value": debris.get("value") if debris.has_method("get") else 1
	}

	_remove_debris(debris)
	debris_collected.emit(debris_data.get("type", "unknown"), debris_data.get("value", 1))

	return debris_data

func force_spawn_debris(debris_type_name: String, position: Vector2) -> Node2D:
	"""Force spawn specific debris type at position"""
	var debris_type = _get_debris_type_by_name(debris_type_name)
	if debris_type.is_empty():
		push_error("ZoneDebrisManager: Unknown debris type: %s" % debris_type_name)
		return null

	var debris_node = _create_debris_node(debris_type, position)
	if debris_node and debris_container:
		debris_container.add_child(debris_node)
		active_debris.append(debris_node)
		current_debris_count += 1

		debris_spawned.emit(debris_node)
		debris_count_changed.emit(current_debris_count)

		print("ZoneDebrisManager: Force spawned %s at %s" % [debris_type_name, position])
		return debris_node

	return null

func _get_debris_type_by_name(type_name: String) -> Dictionary:
	"""Get debris type data by name"""
	for debris_type in debris_types:
		if debris_type.get("type", "") == type_name:
			return debris_type
	return {}

func clear_all_debris() -> void:
	"""Clear all debris from the zone"""
	for debris in active_debris:
		if is_instance_valid(debris):
			debris.queue_free()

	active_debris.clear()
	current_debris_count = 0
	debris_count_changed.emit(current_debris_count)

	print("ZoneDebrisManager: All debris cleared")

func set_spawn_settings(new_max_count: int, new_spawn_interval: float) -> void:
	"""Update spawn settings"""
	max_debris_count = new_max_count
	spawn_interval = new_spawn_interval
	print("ZoneDebrisManager: Spawn settings updated - max: %d, interval: %.2f" % [max_debris_count, spawn_interval])

func set_zone_bounds(new_bounds: Rect2) -> void:
	"""Set zone bounds for debris spawning"""
	zone_bounds = new_bounds
	print("ZoneDebrisManager: Zone bounds updated: %s" % zone_bounds)

func get_debris_stats() -> Dictionary:
	"""Get debris statistics"""
	var stats = {
		"current_count": current_debris_count,
		"max_count": max_debris_count,
		"active_debris": active_debris.size(),
		"spawn_interval": spawn_interval
	}

	# Count by type
	var type_counts = {}
	for debris in active_debris:
		if not is_instance_valid(debris):
			continue

		var debris_type = debris.get("debris_type") if debris.has_method("get") else "unknown"
		type_counts[debris_type] = type_counts.get(debris_type, 0) + 1

	stats["type_counts"] = type_counts
	return stats

## Signal handlers

func _on_debris_collected(debris_type: String, value: int) -> void:
	"""Handle debris collection signal"""
	debris_collected.emit(debris_type, value)
	print("ZoneDebrisManager: Debris collected - type: %s, value: %d" % [debris_type, value])
