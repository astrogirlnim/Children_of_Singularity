# SpaceStationModule3D.gd
# Base class for 3D space station modules in Children of the Singularity
# Handles different module types (habitat, industrial, docking, etc.) with visual variety

class_name SpaceStationModule3D
extends StaticBody3D

## Signal emitted when player enters module interaction area
signal module_entered(module_type: String, module: SpaceStationModule3D)

## Signal emitted when player exits module interaction area
signal module_exited(module_type: String, module: SpaceStationModule3D)

## Module types available
enum ModuleType {
	HABITAT,      # Living quarters, crew areas
	INDUSTRIAL,   # Manufacturing, processing
	DOCKING,      # Ship docking and repair
	TRADING,      # Commerce and trading
	COMMAND,      # Control and communications
	POWER,        # Power generation
	STORAGE,      # Cargo and storage
	RESEARCH      # Labs and development
}

## Export properties for configuration
@export var module_type: ModuleType = ModuleType.HABITAT
@export var module_scale: Vector3 = Vector3(1, 1, 1)
@export var can_interact: bool = true
@export var interaction_radius: float = 15.0
@export var hub_type: String = "general"  # For backward compatibility with trading system

## Node references
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_collision: CollisionShape3D = $InteractionArea/CollisionShape3D

## Module configuration data
var module_data: Dictionary = {}
var module_id: String = ""
var is_active: bool = true

func _ready() -> void:
	_log_message("SpaceStationModule3D: Initializing module type %s" % ModuleType.keys()[module_type])
	_generate_module_id()
	_setup_collision_layers()
	_setup_interaction_area()
	_configure_module_appearance()
	_setup_module_data()
	_log_message("SpaceStationModule3D: Module %s ready - ID: %s" % [ModuleType.keys()[module_type], module_id])

func _generate_module_id() -> void:
	"""Generate unique module ID"""
	module_id = "module_%s_%d" % [ModuleType.keys()[module_type].to_lower(), Time.get_unix_time_from_system()]

func _setup_collision_layers() -> void:
	"""Set up collision layers for station modules"""
	# Layer 8 for NPC/station interactions (compatible with existing player interaction system)
	collision_layer = 8
	collision_mask = 1  # Can collide with player layer

func _setup_interaction_area() -> void:
	"""Set up interaction area for player detection"""
	if not interaction_area:
		interaction_area = Area3D.new()
		interaction_area.name = "InteractionArea"
		add_child(interaction_area)

	if not interaction_collision:
		interaction_collision = CollisionShape3D.new()
		interaction_collision.name = "CollisionShape3D"
		interaction_area.add_child(interaction_collision)

	# Create sphere collision for interaction
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = interaction_radius
	interaction_collision.shape = sphere_shape

	# Configure interaction area layers
	interaction_area.collision_layer = 0  # Don't collide with anything
	interaction_area.collision_mask = 1   # Detect player (layer 1)

	# Connect signals
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	interaction_area.body_exited.connect(_on_interaction_area_exited)

	_log_message("SpaceStationModule3D: Interaction area configured with radius %.1f" % interaction_radius)

func _configure_module_appearance() -> void:
	"""Configure the visual appearance based on module type using detailed 3D model"""
	# Load the detailed space station model from Blender
	var station_model_scene = preload("res://assets/models/space_station_module.gltf")
	var station_model = station_model_scene.instantiate()

	# Remove any old mesh instance if it exists
	if mesh_instance:
		mesh_instance.queue_free()

	# Add the detailed 3D model as our mesh instance
	add_child(station_model)
	station_model.name = "DetailedStationModel"

	# Find the mesh instance within the loaded model
	mesh_instance = station_model.get_node("SpaceStationModule") as MeshInstance3D
	if not mesh_instance:
		# Fallback: look for any MeshInstance3D in the loaded model
		for child in station_model.get_children():
			if child is MeshInstance3D:
				mesh_instance = child
				break

	# Set up collision shape if not exists
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)

	# Create material variations based on module type
	var material = StandardMaterial3D.new()
	var model_scale = Vector3.ONE
	var collision_size = Vector3(10, 8, 12)  # Default size for detailed model

	match module_type:
		ModuleType.HABITAT:
			model_scale = Vector3(1.0, 1.0, 1.2) * module_scale
			material.albedo_color = Color(0.7, 0.8, 0.6, 1.0)  # Soft green
			material.emission_enabled = true
			material.emission = Color(0.1, 0.2, 0.1)
			collision_size = Vector3(8, 6, 12) * module_scale
			hub_type = "general"

		ModuleType.INDUSTRIAL:
			model_scale = Vector3(1.2, 1.0, 1.0) * module_scale
			material.albedo_color = Color(0.6, 0.6, 0.7, 1.0)  # Industrial gray
			material.metallic = 0.7
			material.roughness = 0.3
			collision_size = Vector3(12, 8, 10) * module_scale
			hub_type = "industrial"

		ModuleType.DOCKING:
			model_scale = Vector3(1.5, 0.8, 1.0) * module_scale
			material.albedo_color = Color(0.8, 0.7, 0.3, 1.0)  # Docking yellow
			material.emission_enabled = true
			material.emission = Color(0.2, 0.15, 0.05)
			collision_size = Vector3(15, 6, 8) * module_scale
			hub_type = "docking"

		ModuleType.TRADING:
			model_scale = Vector3(1.1, 1.1, 1.1) * module_scale
			material.albedo_color = Color(0.8, 0.6, 0.2, 1.0)  # Trading gold
			material.emission_enabled = true
			material.emission = Color(0.2, 0.1, 0.05)
			material.metallic = 0.3
			collision_size = Vector3(10, 8, 10) * module_scale
			hub_type = "trading"

		ModuleType.COMMAND:
			model_scale = Vector3(1.2, 1.3, 1.2) * module_scale
			material.albedo_color = Color(0.3, 0.5, 0.8, 1.0)  # Command blue
			material.emission_enabled = true
			material.emission = Color(0.05, 0.1, 0.2)
			collision_size = Vector3(12, 10, 12) * module_scale
			hub_type = "command"

		ModuleType.POWER:
			model_scale = Vector3(0.8, 1.5, 0.8) * module_scale
			material.albedo_color = Color(0.9, 0.3, 0.2, 1.0)  # Power red
			material.emission_enabled = true
			material.emission = Color(0.3, 0.1, 0.1)
			collision_size = Vector3(6, 12, 6) * module_scale
			hub_type = "power"

		ModuleType.STORAGE:
			model_scale = Vector3(1.4, 1.0, 1.6) * module_scale
			material.albedo_color = Color(0.5, 0.5, 0.5, 1.0)  # Storage gray
			material.metallic = 0.2
			material.roughness = 0.8
			collision_size = Vector3(14, 8, 16) * module_scale
			hub_type = "storage"

		ModuleType.RESEARCH:
			model_scale = Vector3(1.0, 1.0, 1.4) * module_scale
			material.albedo_color = Color(0.6, 0.3, 0.8, 1.0)  # Research purple
			material.emission_enabled = true
			material.emission = Color(0.15, 0.05, 0.2)
			collision_size = Vector3(10, 8, 14) * module_scale
			hub_type = "research"

	# Apply scale and material to the detailed model
	station_model.scale = model_scale

	# Apply material override to all mesh instances in the model
	if mesh_instance:
		mesh_instance.material_override = material
		_log_message("SpaceStationModule3D: Applied %s material to detailed model" % ModuleType.keys()[module_type])

	# Also apply to any child mesh instances
	for child in station_model.get_children():
		if child is MeshInstance3D:
			child.material_override = material

	# Create matching collision shape for the detailed model
	var box_shape = BoxShape3D.new()
	box_shape.size = collision_size
	collision_shape.shape = box_shape

	_log_message("SpaceStationModule3D: Configured detailed %s module with scale %s and collision size %s" % [ModuleType.keys()[module_type], model_scale, collision_size])

func _setup_module_data() -> void:
	"""Set up module-specific data and functionality"""
	# Get the collision size from our collision shape for consistent sizing data
	var module_size = Vector3.ZERO
	if collision_shape and collision_shape.shape is BoxShape3D:
		module_size = (collision_shape.shape as BoxShape3D).size

	module_data = {
		"type": ModuleType.keys()[module_type],
		"hub_type": hub_type,
		"size": module_size,
		"can_interact": can_interact,
		"interaction_radius": interaction_radius,
		"is_active": is_active,
		"module_id": module_id,
		"position": global_position
	}

func _on_interaction_area_entered(body: Node3D) -> void:
	"""Handle player entering module interaction area"""
	if body.has_method("collect_debris"):  # Check if it's the player
		_log_message("SpaceStationModule3D: Player entered %s module - %s" % [ModuleType.keys()[module_type], module_id])
		module_entered.emit(hub_type, self)

func _on_interaction_area_exited(body: Node3D) -> void:
	"""Handle player exiting module interaction area"""
	if body.has_method("collect_debris"):  # Check if it's the player
		_log_message("SpaceStationModule3D: Player exited %s module - %s" % [ModuleType.keys()[module_type], module_id])
		module_exited.emit(hub_type, self)

func get_hub_type() -> String:
	"""Get the hub type for compatibility with existing trading system"""
	return hub_type

func get_module_type() -> ModuleType:
	"""Get the module type enum"""
	return module_type

func get_module_data() -> Dictionary:
	"""Get complete module data"""
	module_data["position"] = global_position  # Update position
	return module_data

func set_module_active(active: bool) -> void:
	"""Set module active state"""
	is_active = active
	visible = active

	# Update collision based on active state
	if collision_shape:
		collision_shape.disabled = not active

	if interaction_area:
		interaction_area.monitoring = active

	_log_message("SpaceStationModule3D: Module %s set to %s" % [module_id, "active" if active else "inactive"])

func add_module_details() -> void:
	"""Add detailed elements to the module (pipes, antennas, lights)"""
	# Add some visual details for variety
	_add_surface_details()
	_add_connection_points()
	_add_status_lights()

func _add_surface_details() -> void:
	"""Add surface details like panels, pipes, antennas"""
	var details_container = Node3D.new()
	details_container.name = "ModuleDetails"
	add_child(details_container)

	# Add some random surface elements
	for i in range(randi() % 3 + 2):  # 2-4 details per module
		var detail = MeshInstance3D.new()
		var detail_mesh = BoxMesh.new()
		detail_mesh.size = Vector3(
			randf_range(0.5, 2.0),
			randf_range(0.2, 0.8),
			randf_range(0.5, 2.0)
		)
		detail.mesh = detail_mesh

		# Position randomly on module surface
		var module_size = _get_module_size()
		detail.position = Vector3(
			randf_range(-module_size.x/2, module_size.x/2),
			module_size.y/2 + detail_mesh.size.y/2,
			randf_range(-module_size.z/2, module_size.z/2)
		)

		# Create material for detail
		var detail_material = StandardMaterial3D.new()
		detail_material.albedo_color = Color(
			randf_range(0.3, 0.8),
			randf_range(0.3, 0.8),
			randf_range(0.3, 0.8)
		)
		detail.material_override = detail_material

		details_container.add_child(detail)

func _add_connection_points() -> void:
	"""Add connection points for module linking"""
	# Add small cylindrical connection points
	var connections_container = Node3D.new()
	connections_container.name = "ConnectionPoints"
	add_child(connections_container)

	var module_size = _get_module_size()

	# Add 2-4 connection points on sides
	for i in range(randi() % 3 + 2):
		var connection = MeshInstance3D.new()
		var cylinder_mesh = CylinderMesh.new()
		cylinder_mesh.height = 1.0
		cylinder_mesh.top_radius = 0.3
		cylinder_mesh.bottom_radius = 0.3
		connection.mesh = cylinder_mesh

		# Position on module sides
		var side = randi() % 4
		match side:
			0:  # Front
				connection.position = Vector3(0, 0, module_size.z/2 + 0.5)
			1:  # Back
				connection.position = Vector3(0, 0, -module_size.z/2 - 0.5)
			2:  # Right
				connection.position = Vector3(module_size.x/2 + 0.5, 0, 0)
				connection.rotation_degrees = Vector3(0, 0, 90)
			3:  # Left
				connection.position = Vector3(-module_size.x/2 - 0.5, 0, 0)
				connection.rotation_degrees = Vector3(0, 0, 90)

		# Create connection material
		var connection_material = StandardMaterial3D.new()
		connection_material.albedo_color = Color(0.7, 0.7, 0.8)
		connection_material.metallic = 0.8
		connection_material.roughness = 0.2
		connection.material_override = connection_material

		connections_container.add_child(connection)

func _add_status_lights() -> void:
	"""Add status lights to indicate module functionality"""
	var lights_container = Node3D.new()
	lights_container.name = "StatusLights"
	add_child(lights_container)

	var module_size = _get_module_size()

	# Add 1-3 status lights
	for i in range(randi() % 3 + 1):
		var light_node = Node3D.new()
		var light_mesh = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.2
		sphere_mesh.height = 0.4
		light_mesh.mesh = sphere_mesh

		# Position lights on module surface
		light_mesh.position = Vector3(
			randf_range(-module_size.x/2 + 1, module_size.x/2 - 1),
			module_size.y/2 + 0.2,
			randf_range(-module_size.z/2 + 1, module_size.z/2 - 1)
		)

		# Create emissive material for lights
		var light_material = StandardMaterial3D.new()
		var light_color = Color(
			randf_range(0.5, 1.0),
			randf_range(0.5, 1.0),
			randf_range(0.5, 1.0)
		)
		light_material.albedo_color = light_color
		light_material.emission_enabled = true
		light_material.emission = light_color * 0.8
		light_material.emission_energy = 2.0
		light_mesh.material_override = light_material

		light_node.add_child(light_mesh)
		lights_container.add_child(light_node)

func _get_module_size() -> Vector3:
	"""Get the module size from collision shape for consistent sizing"""
	if collision_shape and collision_shape.shape is BoxShape3D:
		return (collision_shape.shape as BoxShape3D).size
	return Vector3(10, 8, 12)  # Default size for detailed station model

func _log_message(message: String) -> void:
	"""Log a message with timestamp"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
