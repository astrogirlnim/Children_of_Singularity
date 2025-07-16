# ZoneBoundaryManager3D.gd
# Zone boundary manager for Children of the Singularity 3D
# Creates invisible collision walls around the play area and warns players when approaching boundaries

class_name ZoneBoundaryManager3D
extends Node3D

## Signal emitted when player approaches boundary
signal boundary_warning(distance: float, direction: String)

## Signal emitted when player hits boundary
signal boundary_collision(position: Vector3, boundary_type: String)

## Signal emitted when player returns to safe zone
signal boundary_safe()

## Export properties for configuration
@export var zone_bounds: Vector3 = Vector3(400, 50, 400)  # Zone dimensions (X, Y, Z)
@export var wall_height: float = 30.0  # Height of boundary walls
@export var wall_thickness: float = 5.0  # Thickness of boundary walls
@export var warning_distance: float = 40.0  # Distance from boundary to trigger warning
@export var enable_warnings: bool = true
@export var enable_visual_indicators: bool = false  # For debugging, show boundary walls

## Node references
var boundary_container: Node3D
var player_ship: CharacterBody3D

## Boundary walls (StaticBody3D nodes)
var north_wall: StaticBody3D
var south_wall: StaticBody3D
var east_wall: StaticBody3D
var west_wall: StaticBody3D
var top_wall: StaticBody3D
var bottom_wall: StaticBody3D

## Warning state
var is_near_boundary: bool = false
var current_warning_distance: float = 0.0
var current_boundary_direction: String = ""
var warning_cooldown: float = 0.0
var warning_interval: float = 2.0  # Seconds between warning messages

func _ready() -> void:
	_log_message("ZoneBoundaryManager3D: Initializing 3D zone boundary system")
	_setup_boundary_container()
	_create_boundary_walls()
	_log_message("ZoneBoundaryManager3D: Zone boundary system initialized - Zone size: %s" % zone_bounds)

func _process(delta: float) -> void:
	if player_ship and enable_warnings:
		warning_cooldown -= delta
		_check_boundary_proximity()

func _setup_boundary_container() -> void:
	"""Set up container for boundary walls"""
	boundary_container = Node3D.new()
	boundary_container.name = "BoundaryWalls"
	add_child(boundary_container)
	_log_message("ZoneBoundaryManager3D: Boundary container created")

func _create_boundary_walls() -> void:
	"""Create invisible collision walls around the zone boundaries"""
	_log_message("ZoneBoundaryManager3D: Creating boundary collision walls")

	# Calculate wall positions based on zone bounds
	var half_x = zone_bounds.x / 2.0
	var half_y = zone_bounds.y / 2.0
	var half_z = zone_bounds.z / 2.0

	# Create North wall (positive Z)
	north_wall = _create_boundary_wall(
		"NorthWall",
		Vector3(0, half_y / 2, half_z + wall_thickness / 2),
		Vector3(zone_bounds.x + wall_thickness * 2, wall_height, wall_thickness)
	)

	# Create South wall (negative Z)
	south_wall = _create_boundary_wall(
		"SouthWall",
		Vector3(0, half_y / 2, -half_z - wall_thickness / 2),
		Vector3(zone_bounds.x + wall_thickness * 2, wall_height, wall_thickness)
	)

	# Create East wall (positive X)
	east_wall = _create_boundary_wall(
		"EastWall",
		Vector3(half_x + wall_thickness / 2, half_y / 2, 0),
		Vector3(wall_thickness, wall_height, zone_bounds.z)
	)

	# Create West wall (negative X)
	west_wall = _create_boundary_wall(
		"WestWall",
		Vector3(-half_x - wall_thickness / 2, half_y / 2, 0),
		Vector3(wall_thickness, wall_height, zone_bounds.z)
	)

	# Create Top wall (positive Y)
	top_wall = _create_boundary_wall(
		"TopWall",
		Vector3(0, zone_bounds.y + wall_thickness / 2, 0),
		Vector3(zone_bounds.x + wall_thickness * 2, wall_thickness, zone_bounds.z + wall_thickness * 2)
	)

	# Create Bottom wall (negative Y) - floor boundary
	bottom_wall = _create_boundary_wall(
		"BottomWall",
		Vector3(0, -wall_thickness / 2, 0),
		Vector3(zone_bounds.x + wall_thickness * 2, wall_thickness, zone_bounds.z + wall_thickness * 2)
	)

	_log_message("ZoneBoundaryManager3D: Created 6 boundary walls (N/S/E/W/Top/Bottom)")

func _create_boundary_wall(wall_name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	"""Create a single boundary wall with collision"""
	var wall = StaticBody3D.new()
	wall.name = wall_name
	wall.position = position

	# Set collision layer for boundaries (layer 5)
	wall.collision_layer = 16  # Layer 5 (2^4 = 16)
	wall.collision_mask = 1   # Collide with player (layer 1)

	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	wall.add_child(collision_shape)

	# Add visual indicator if enabled (for debugging)
	if enable_visual_indicators:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "VisualIndicator"
		var box_mesh = BoxMesh.new()
		box_mesh.size = size
		mesh_instance.mesh = box_mesh

		# Create semi-transparent red material
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.0, 0.0, 0.3)  # Semi-transparent red
		material.flags_transparent = true
		material.no_depth_test = true
		mesh_instance.material_override = material
		wall.add_child(mesh_instance)

	# Add to boundary container
	boundary_container.add_child(wall)

	_log_message("ZoneBoundaryManager3D: Created %s wall at %s with size %s" % [wall_name, position, size])
	return wall

func _check_boundary_proximity() -> void:
	"""Check if player is approaching any boundary and emit warnings"""
	if not player_ship:
		return

	var player_pos = player_ship.global_position
	var closest_boundary_distance = INF
	var boundary_direction = ""

	# Check distance to each boundary
	var distances = {
		"north": (zone_bounds.z / 2.0) - player_pos.z,      # Distance to north boundary
		"south": player_pos.z - (-zone_bounds.z / 2.0),     # Distance to south boundary
		"east": (zone_bounds.x / 2.0) - player_pos.x,       # Distance to east boundary
		"west": player_pos.x - (-zone_bounds.x / 2.0),      # Distance to west boundary
		"top": (zone_bounds.y) - player_pos.y,              # Distance to top boundary
		"bottom": player_pos.y - 0                          # Distance to bottom boundary
	}

	# Find closest boundary
	for direction in distances:
		var distance = distances[direction]
		if distance < closest_boundary_distance:
			closest_boundary_distance = distance
			boundary_direction = direction

	# Check if warning should be triggered
	if closest_boundary_distance <= warning_distance:
		if not is_near_boundary or boundary_direction != current_boundary_direction:
			is_near_boundary = true
			current_boundary_direction = boundary_direction
			current_warning_distance = closest_boundary_distance

			if warning_cooldown <= 0.0:
				boundary_warning.emit(closest_boundary_distance, boundary_direction)
				warning_cooldown = warning_interval
				_log_message("ZoneBoundaryManager3D: Boundary warning - %.1f units from %s boundary" % [closest_boundary_distance, boundary_direction])
	else:
		if is_near_boundary:
			is_near_boundary = false
			current_boundary_direction = ""
			boundary_safe.emit()
			_log_message("ZoneBoundaryManager3D: Player returned to safe zone")

## Public API Methods

func set_player_reference(player: CharacterBody3D) -> void:
	"""Set reference to player ship for boundary checking"""
	player_ship = player
	_log_message("ZoneBoundaryManager3D: Player reference set to: %s" % (player.name if player else "none"))

func set_zone_bounds(new_bounds: Vector3) -> void:
	"""Update zone bounds and recreate boundary walls"""
	zone_bounds = new_bounds
	_log_message("ZoneBoundaryManager3D: Zone bounds updated to: %s" % zone_bounds)

	# Remove existing walls
	if boundary_container:
		for child in boundary_container.get_children():
			child.queue_free()

	# Recreate walls with new bounds
	call_deferred("_create_boundary_walls")

func enable_boundary_warnings(enabled: bool) -> void:
	"""Enable or disable boundary warnings"""
	enable_warnings = enabled
	_log_message("ZoneBoundaryManager3D: Boundary warnings %s" % ("enabled" if enabled else "disabled"))

func enable_visual_boundaries(enabled: bool) -> void:
	"""Enable or disable visual boundary indicators (for debugging)"""
	enable_visual_indicators = enabled
	_log_message("ZoneBoundaryManager3D: Visual boundaries %s" % ("enabled" if enabled else "disabled"))

	# Update existing walls
	if boundary_container:
		for wall in boundary_container.get_children():
			var visual_indicator = wall.get_node_or_null("VisualIndicator")
			if visual_indicator:
				visual_indicator.visible = enabled

func get_boundary_info() -> Dictionary:
	"""Get information about current boundary state"""
	return {
		"zone_bounds": zone_bounds,
		"warning_distance": warning_distance,
		"is_near_boundary": is_near_boundary,
		"current_boundary_direction": current_boundary_direction,
		"current_warning_distance": current_warning_distance,
		"warnings_enabled": enable_warnings
	}

func get_distance_to_nearest_boundary(position: Vector3) -> float:
	"""Get distance from a position to the nearest boundary"""
	var distances = [
		(zone_bounds.z / 2.0) - position.z,      # North
		position.z - (-zone_bounds.z / 2.0),     # South
		(zone_bounds.x / 2.0) - position.x,      # East
		position.x - (-zone_bounds.x / 2.0),     # West
		(zone_bounds.y) - position.y,            # Top
		position.y - 0                           # Bottom
	]

	return distances.min()

func is_position_in_bounds(position: Vector3) -> bool:
	"""Check if a position is within zone boundaries"""
	return (
		position.x >= -zone_bounds.x / 2.0 and position.x <= zone_bounds.x / 2.0 and
		position.y >= 0 and position.y <= zone_bounds.y and
		position.z >= -zone_bounds.z / 2.0 and position.z <= zone_bounds.z / 2.0
	)

func clamp_position_to_bounds(position: Vector3) -> Vector3:
	"""Clamp a position to stay within zone boundaries"""
	return Vector3(
		clamp(position.x, -zone_bounds.x / 2.0, zone_bounds.x / 2.0),
		clamp(position.y, 0, zone_bounds.y),
		clamp(position.z, -zone_bounds.z / 2.0, zone_bounds.z / 2.0)
	)

## Signal handlers

func _on_boundary_collision(body: Node3D) -> void:
	"""Handle collision with boundary wall"""
	if body == player_ship:
		boundary_collision.emit(body.global_position, "boundary_wall")
		_log_message("ZoneBoundaryManager3D: Player collided with boundary wall at %s" % body.global_position)

func _log_message(message: String) -> void:
	"""Log message with timestamp"""
	var timestamp = Time.get_datetime_string_from_system()
	print("[%s] %s" % [timestamp, message])
