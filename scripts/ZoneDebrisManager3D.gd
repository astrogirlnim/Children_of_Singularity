# ZoneDebrisManager3D.gd
# 3D debris manager for Children of the Singularity
# Handles debris spawning, collection, types, and lifecycle management in 3D space

class_name ZoneDebrisManager3D
extends Node3D

## Signal emitted when debris is spawned
signal debris_spawned(debris: DebrisObject3D)

## Signal emitted when debris is collected
signal debris_collected(debris_type: String, value: int)

## Signal emitted when debris count changes
signal debris_count_changed(count: int)

## Signal emitted when debris despawns
signal debris_despawned(debris: DebrisObject3D)

## Export properties for configuration
@export var debris_container: Node3D
@export var zone_bounds: Vector3 = Vector3(100, 50, 100)  # 3D bounds (X, Y, Z)
@export var debris_spawn_height_range: Vector2 = Vector2(-5, 5)  # Y-axis range for debris spawning
@export var max_debris_count: int = 50
@export var spawn_interval: float = 2.0
@export var despawn_distance: float = 150.0

## Debris types configuration (same as 2D version)
var debris_types: Array[Dictionary] = [
	{"type": "scrap_metal", "value": 5, "spawn_weight": 40, "color": Color.GRAY, "texture_path": "res://assets/sprites/debris/scrap_metal.png"},
	{"type": "broken_satellite", "value": 150, "spawn_weight": 10, "color": Color.SILVER, "texture_path": "res://assets/sprites/debris/broken_satellite.png"},
	{"type": "bio_waste", "value": 25, "spawn_weight": 25, "color": Color.GREEN, "texture_path": "res://assets/sprites/debris/bio_waste.png"},
	{"type": "ai_component", "value": 500, "spawn_weight": 5, "color": Color.CYAN, "texture_path": "res://assets/sprites/debris/ai_component.png"},
	{"type": "unknown_artifact", "value": 1000, "spawn_weight": 1, "color": Color.PURPLE, "texture_path": "res://assets/sprites/debris/unknown_artifact.png"}
]

## Internal state
var current_debris_count: int = 0
var active_debris: Array[DebrisObject3D] = []
var spawn_timer: float = 0.0
var weighted_spawn_table: Array[String] = []

## Debris texture cache
var debris_textures: Dictionary = {}

## References
var player_ship: CharacterBody3D
var debris_3d_scene: PackedScene

func _ready() -> void:
	_log_message("ZoneDebrisManager3D: Initializing 3D debris manager")
	_load_debris_scene()
	_load_debris_textures()
	_build_weighted_spawn_table()
	_spawn_initial_debris()
	_log_message("ZoneDebrisManager3D: 3D debris manager initialized")

func _load_debris_scene() -> void:
	"""Load the 3D debris scene"""
	debris_3d_scene = preload("res://scenes/objects/Debris3D.tscn")
	if debris_3d_scene:
		_log_message("ZoneDebrisManager3D: Debris3D scene loaded successfully")
	else:
		push_error("ZoneDebrisManager3D: Failed to load Debris3D scene!")

func _load_debris_textures() -> void:
	"""Load debris textures from files or create fallback textures"""
	_log_message("ZoneDebrisManager3D: Loading debris textures")

	for debris_type in debris_types:
		var type_name = debris_type.get("type", "unknown")
		var texture_path = debris_type.get("texture_path", "")
		var fallback_color = debris_type.get("color", Color.WHITE)

		var texture: Texture2D = null

		# Try to load texture from file
		if texture_path != "" and ResourceLoader.exists(texture_path):
			texture = load(texture_path)
			if texture:
				_log_message("ZoneDebrisManager3D: Successfully loaded texture for %s from %s (size: %s)" % [type_name, texture_path, texture.get_size()])
			else:
				_log_message("ZoneDebrisManager3D: Failed to load texture for %s from %s, using fallback" % [type_name, texture_path])
				texture = _create_fallback_texture(fallback_color)
		else:
			# Create fallback colored texture
			texture = _create_fallback_texture(fallback_color)
			_log_message("ZoneDebrisManager3D: Texture file not found for %s at %s, using fallback (color: %s)" % [type_name, texture_path, fallback_color])

		debris_textures[type_name] = texture

	_log_message("ZoneDebrisManager3D: Loaded %d debris textures total" % debris_textures.size())

func _create_fallback_texture(color: Color) -> Texture2D:
	"""Create a fallback colored texture for debris"""
	var texture = ImageTexture.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(color)
	texture.set_image(image)
	return texture

func _process(delta: float) -> void:
	"""Handle debris spawning and cleanup"""
	_update_spawn_timer(delta)
	_cleanup_distant_debris()

func _update_spawn_timer(delta: float) -> void:
	"""Update spawn timer and attempt spawning"""
	spawn_timer += delta

	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_attempt_debris_spawn()

func _build_weighted_spawn_table() -> void:
	"""Build weighted spawn table for debris types"""
	weighted_spawn_table.clear()

	for debris_type in debris_types:
		var type_name = debris_type.get("type", "unknown")
		var weight = debris_type.get("spawn_weight", 1)

		# Add type to table multiple times based on weight
		for i in range(weight):
			weighted_spawn_table.append(type_name)

	_log_message("ZoneDebrisManager3D: Weighted spawn table built with %d entries" % weighted_spawn_table.size())

func _spawn_initial_debris() -> void:
	"""Spawn initial debris to populate the 3D zone"""
	_log_message("ZoneDebrisManager3D: Spawning initial debris in 3D space")

	var initial_count = min(max_debris_count * 0.7, 30)  # Start with 70% of max or 30

	for i in range(initial_count):
		_spawn_debris_at_random_3d_position()

	_log_message("ZoneDebrisManager3D: Spawned %d initial debris in 3D" % initial_count)

func _attempt_debris_spawn() -> void:
	"""Attempt to spawn new debris if under the limit"""
	if current_debris_count >= max_debris_count:
		return

	if not player_ship:
		return

	# Try to spawn debris away from player in 3D space
	var spawn_position = _get_spawn_position_away_from_player_3d()
	if spawn_position != Vector3.ZERO:
		_spawn_debris_at_position_3d(spawn_position)

func _spawn_debris_at_random_3d_position() -> void:
	"""Spawn debris at a random 3D position within zone bounds"""
	var random_pos = Vector3(
		randf_range(-zone_bounds.x / 2, zone_bounds.x / 2),
		randf_range(debris_spawn_height_range.x, debris_spawn_height_range.y),
		randf_range(-zone_bounds.z / 2, zone_bounds.z / 2)
	)

	_spawn_debris_at_position_3d(random_pos)

func _get_spawn_position_away_from_player_3d() -> Vector3:
	"""Get spawn position that's away from the player in 3D space"""
	if not player_ship:
		return Vector3.ZERO

	var player_pos = player_ship.global_position
	var min_distance = 30.0  # Minimum distance from player
	var max_attempts = 10

	for attempt in range(max_attempts):
		var random_pos = Vector3(
			randf_range(-zone_bounds.x / 2, zone_bounds.x / 2),
			randf_range(debris_spawn_height_range.x, debris_spawn_height_range.y),
			randf_range(-zone_bounds.z / 2, zone_bounds.z / 2)
		)

		if player_pos.distance_to(random_pos) >= min_distance:
			return random_pos

	return Vector3.ZERO  # Failed to find suitable position

func _spawn_debris_at_position_3d(position: Vector3) -> void:
	"""Spawn debris at specific 3D position"""
	if not debris_container:
		push_error("ZoneDebrisManager3D: No debris container assigned!")
		return

	if not debris_3d_scene:
		push_error("ZoneDebrisManager3D: No debris scene loaded!")
		return

	var debris_type = _get_random_debris_type()
	var debris_node = _create_debris_node_3d(debris_type, position)

	if debris_node:
		# Add to scene tree first before setting position
		debris_container.add_child(debris_node)

		# Now set position after node is in scene tree
		debris_node.global_position = position
		debris_node.initial_position = position

		active_debris.append(debris_node)
		current_debris_count += 1

		# Connect collection signal
		debris_node.collected.connect(_on_debris_collected_3d)

		debris_spawned.emit(debris_node)
		debris_count_changed.emit(current_debris_count)

		_log_message("ZoneDebrisManager3D: Spawned %s at 3D position %s" % [debris_type.get("type", "unknown"), position])

func _get_random_debris_type() -> Dictionary:
	"""Get random debris type based on weighted probabilities"""
	if weighted_spawn_table.is_empty():
		return debris_types[0]  # Fallback

	var random_type_name = weighted_spawn_table[randi() % weighted_spawn_table.size()]

	for debris_type in debris_types:
		if debris_type.get("type", "") == random_type_name:
			return debris_type

	return debris_types[0]  # Fallback

func _create_debris_node_3d(debris_type: Dictionary, position: Vector3) -> DebrisObject3D:
	"""Create a 3D debris node with proper components"""
	var debris_node = debris_3d_scene.instantiate() as DebrisObject3D
	if not debris_node:
		push_error("ZoneDebrisManager3D: Failed to instantiate debris scene!")
		return null

	# Set node name
	debris_node.name = "Debris3D_%s_%d" % [debris_type.get("type", "unknown"), Time.get_ticks_msec()]

	# Set debris properties
	var type_name = debris_type.get("type", "unknown")
	debris_node.set_debris_data(
		type_name,
		debris_type.get("value", 1),
		debris_type.get("color", Color.WHITE)
	)

	# Set debris texture
	if debris_textures.has(type_name):
		debris_node.set_debris_texture(debris_textures[type_name])
		_log_message("ZoneDebrisManager3D: Assigned texture to debris type: %s" % type_name)
	else:
		_log_message("ZoneDebrisManager3D: No texture available for debris type: %s" % type_name)

	# Add random rotation for variety
	debris_node.rotation_degrees = Vector3(
		randf() * 360,
		randf() * 360,
		randf() * 360
	)

	return debris_node

func _cleanup_distant_debris() -> void:
	"""Remove debris that's too far from player in 3D space"""
	if not player_ship:
		return

	var player_pos = player_ship.global_position
	var debris_to_remove: Array[DebrisObject3D] = []

	for debris in active_debris:
		if not is_instance_valid(debris) or not debris.is_inside_tree():
			debris_to_remove.append(debris)
			continue

		var distance = player_pos.distance_to(debris.global_position)
		if distance > despawn_distance:
			debris_to_remove.append(debris)

	for debris in debris_to_remove:
		_remove_debris_3d(debris)

func _remove_debris_3d(debris: DebrisObject3D) -> void:
	"""Remove a 3D debris node from the game"""
	if debris in active_debris:
		active_debris.erase(debris)
		current_debris_count -= 1

		debris_despawned.emit(debris)
		debris_count_changed.emit(current_debris_count)

		if is_instance_valid(debris):
			debris.queue_free()

		_log_message("ZoneDebrisManager3D: Removed debris, count now: %d" % current_debris_count)

func _on_debris_collected_3d(debris_object: DebrisObject3D) -> void:
	"""Handle debris collection signal from 3D debris"""
	if not debris_object:
		return

	var debris_type = debris_object.get_debris_type()
	var debris_value = debris_object.get_debris_value()

	_log_message("ZoneDebrisManager3D: Debris collected - Type: %s, Value: %d" % [debris_type, debris_value])

	# Remove from active debris list
	if debris_object in active_debris:
		active_debris.erase(debris_object)
		current_debris_count -= 1
		debris_count_changed.emit(current_debris_count)

	# Emit collection signal
	debris_collected.emit(debris_type, debris_value)

## Public API Methods

func set_player_reference(player: CharacterBody3D) -> void:
	"""Set player reference for distance calculations"""
	player_ship = player
	_log_message("ZoneDebrisManager3D: Player reference set to: %s" % (player.name if player else "none"))

func get_debris_count() -> int:
	"""Get current debris count"""
	return current_debris_count

func get_debris_in_3d_range(center: Vector3, radius: float) -> Array[DebrisObject3D]:
	"""Get all debris within range of a 3D position"""
	var debris_in_range: Array[DebrisObject3D] = []

	for debris in active_debris:
		if not is_instance_valid(debris) or not debris.is_inside_tree():
			continue

		if center.distance_to(debris.global_position) <= radius:
			debris_in_range.append(debris)

	return debris_in_range

func collect_debris_3d(debris: DebrisObject3D) -> Dictionary:
	"""Collect a 3D debris item and return its data"""
	if not debris or not debris in active_debris:
		return {}

	var debris_data = debris.get_debris_data()

	# Trigger collection
	debris.collect()

	return debris_data

func force_spawn_debris_3d(debris_type_name: String, position: Vector3) -> DebrisObject3D:
	"""Force spawn specific debris type at 3D position"""
	var debris_type = _get_debris_type_by_name(debris_type_name)
	if debris_type.is_empty():
		push_error("ZoneDebrisManager3D: Unknown debris type: %s" % debris_type_name)
		return null

	var debris_node = _create_debris_node_3d(debris_type, position)
	if debris_node and debris_container:
		# Add to scene tree first before setting position
		debris_container.add_child(debris_node)

		# Now set position after node is in scene tree
		debris_node.global_position = position
		debris_node.initial_position = position

		active_debris.append(debris_node)
		current_debris_count += 1

		# Connect collection signal
		debris_node.collected.connect(_on_debris_collected_3d)

		debris_spawned.emit(debris_node)
		debris_count_changed.emit(current_debris_count)

		_log_message("ZoneDebrisManager3D: Force spawned %s at 3D position %s" % [debris_type_name, position])
		return debris_node

	return null

func _get_debris_type_by_name(type_name: String) -> Dictionary:
	"""Get debris type data by name"""
	for debris_type in debris_types:
		if debris_type.get("type", "") == type_name:
			return debris_type
	return {}

func clear_all_debris() -> void:
	"""Clear all debris from the 3D zone"""
	for debris in active_debris:
		if is_instance_valid(debris):
			debris.queue_free()

	active_debris.clear()
	current_debris_count = 0
	debris_count_changed.emit(current_debris_count)

	_log_message("ZoneDebrisManager3D: All debris cleared from 3D zone")

func set_spawn_settings(new_max_count: int, new_spawn_interval: float) -> void:
	"""Update spawn settings"""
	max_debris_count = new_max_count
	spawn_interval = new_spawn_interval
	_log_message("ZoneDebrisManager3D: Spawn settings updated - max: %d, interval: %.2f" % [max_debris_count, spawn_interval])

func set_zone_bounds_3d(new_bounds: Vector3) -> void:
	"""Set 3D zone bounds for debris spawning"""
	zone_bounds = new_bounds
	_log_message("ZoneDebrisManager3D: Zone bounds updated: %s" % zone_bounds)

func get_debris_stats() -> Dictionary:
	"""Get debris statistics"""
	var stats = {
		"current_count": current_debris_count,
		"max_count": max_debris_count,
		"active_debris": active_debris.size(),
		"spawn_interval": spawn_interval,
		"zone_bounds": zone_bounds
	}

	# Count by type
	var type_counts = {}
	for debris in active_debris:
		if not is_instance_valid(debris):
			continue

		var debris_type = debris.get_debris_type()
		type_counts[debris_type] = type_counts.get(debris_type, 0) + 1

	stats["type_counts"] = type_counts
	return stats

func _log_message(message: String) -> void:
	"""Log message with timestamp"""
	var timestamp = Time.get_datetime_string_from_system()
	print("[%s] %s" % [timestamp, message])
