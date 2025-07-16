# BackgroundManager3D.gd
# Main background system controller for Children of the Singularity 2.5D conversion
# Manages layered background elements with parallax scrolling and depth perception

class_name BackgroundManager3D
extends Node3D

## Signal emitted when background system is fully initialized
signal background_ready()

## Signal emitted when layer visibility changes for performance
signal layer_visibility_changed(layer_name: String, visible: bool)

## Export properties for configuration
@export var parallax_strength: float = 0.1
@export var enable_parallax: bool = true
@export var enable_performance_culling: bool = true
@export var max_background_distance: float = 500.0
@export var layer_fade_distance: float = 400.0

## Node references
@export var camera_reference: Camera3D
var layer_container: Node3D
var particle_container: Node3D
var object_container: Node3D

## Background layer management
var background_layers: Array[Dictionary] = []
var active_layers: Array[BackgroundLayer3D] = []
var last_camera_position: Vector3 = Vector3.ZERO
var performance_timer: float = 0.0
var performance_check_interval: float = 1.0

## Layer configuration with actual asset paths
var layer_configurations: Array[Dictionary] = [
	{
		"name": "space_nebula_far",
		"type": "plane",
		"depth": -250.0,
		"parallax": Vector2(0.02, 0.02),
		"texture_path": "res://assets/backgrounds/layers/space_nebula_far.png",
		"scale": Vector3(100, 1, 100),
		"alpha": 0.2,
		"tint": Color(0.7, 0.8, 1.0, 1.0),
		"priority": 1
	},
	{
		"name": "space_stars_distant",
		"type": "plane",
		"depth": -200.0,
		"parallax": Vector2(0.03, 0.03),
		"texture_path": "res://assets/backgrounds/layers/space_stars_distant.png",
		"scale": Vector3(80, 1, 80),
		"alpha": 0.4,
		"tint": Color(0.9, 0.9, 1.0, 1.0),
		"priority": 2
	},
	{
		"name": "distant_structures",
		"type": "objects",
		"depth": -150.0,
		"parallax": Vector2(0.05, 0.05),
		"objects": [
			"res://assets/backgrounds/objects/space_structures_distant.png",
			"res://assets/backgrounds/objects/orbital_platforms_far.png"
		],
		"count": 8,
		"scale_range": Vector2(15, 30),
		"priority": 3
	},
	{
		"name": "asteroid_field_background",
		"type": "objects",
		"depth": -120.0,
		"parallax": Vector2(0.07, 0.07),
		"objects": ["res://assets/backgrounds/objects/asteroid_field_background.png"],
		"count": 12,
		"scale_range": Vector2(8, 20),
		"priority": 4
	},
	{
		"name": "debris_clouds",
		"type": "plane",
		"depth": -80.0,
		"parallax": Vector2(0.12, 0.12),
		"texture_path": "res://assets/backgrounds/layers/debris_clouds.png",
		"scale": Vector3(60, 1, 60),
		"alpha": 0.3,
		"tint": Color(0.8, 0.9, 0.9, 1.0),
		"priority": 5
	},
	{
		"name": "space_mist_near",
		"type": "plane",
		"depth": -50.0,
		"parallax": Vector2(0.15, 0.15),
		"texture_path": "res://assets/backgrounds/layers/space_mist_near.png",
		"scale": Vector3(40, 1, 40),
		"alpha": 0.2,
		"tint": Color(0.9, 0.9, 1.0, 1.0),
		"priority": 6
	},
	{
		"name": "energy_fields",
		"type": "plane",
		"depth": -30.0,
		"parallax": Vector2(0.2, 0.2),
		"texture_path": "res://assets/backgrounds/layers/energy_fields.png",
		"scale": Vector3(30, 1, 30),
		"alpha": 0.15,
		"tint": Color(0.6, 1.0, 0.8, 1.0),
		"priority": 7
	},
	{
		"name": "star_field_particles",
		"type": "particles",
		"depth": -180.0,
		"parallax": Vector2(0.025, 0.025),
		"particle_texture": "res://assets/particles/textures/star_particle.png",
		"count": 300,
		"area": Vector3(600, 100, 600),
		"priority": 8
	},
	{
		"name": "dust_particles",
		"type": "particles",
		"depth": -60.0,
		"parallax": Vector2(0.1, 0.1),
		"particle_texture": "res://assets/particles/textures/dust_particle.png",
		"count": 150,
		"area": Vector3(200, 50, 200),
		"priority": 9
	}
]

func _ready() -> void:
	_log_message("BackgroundManager3D: Initializing layered background system")
	_setup_containers()
	_initialize_layers()
	_setup_particle_systems()
	_log_message("BackgroundManager3D: Background system ready with %d layers" % active_layers.size())
	background_ready.emit()

func _setup_containers() -> void:
	"""Set up container nodes for organizing background elements"""
	_log_message("BackgroundManager3D: Setting up background containers")

	# Create main containers
	layer_container = Node3D.new()
	layer_container.name = "BackgroundLayers"
	add_child(layer_container)

	particle_container = Node3D.new()
	particle_container.name = "BackgroundParticles"
	add_child(particle_container)

	object_container = Node3D.new()
	object_container.name = "BackgroundObjects"
	add_child(object_container)

func _initialize_layers() -> void:
	"""Initialize all background layers in order of priority"""
	_log_message("BackgroundManager3D: Initializing background layers")

	# Sort layer configurations by priority
	layer_configurations.sort_custom(_compare_layer_priority)

	for config in layer_configurations:
		_create_layer_from_config(config)

	_log_message("BackgroundManager3D: Created %d background layers" % active_layers.size())

func _compare_layer_priority(a: Dictionary, b: Dictionary) -> bool:
	"""Sort layers by priority (lower number = further back)"""
	return a.get("priority", 999) < b.get("priority", 999)

func _create_layer_from_config(config: Dictionary) -> void:
	"""Create a background layer from configuration dictionary"""
	var layer_name = config.get("name", "unnamed_layer")
	var layer_type = config.get("type", "plane")

	_log_message("BackgroundManager3D: Creating layer '%s' of type '%s'" % [layer_name, layer_type])

	match layer_type:
		"plane":
			_create_background_plane(config)
		"objects":
			_create_background_objects(config)
		"particles":
			_create_particle_layer(config)
		_:
			push_error("BackgroundManager3D: Unknown layer type: %s" % layer_type)

func _create_background_plane(config: Dictionary) -> BackgroundLayer3D:
	"""Create a textured plane background layer"""
	var layer = BackgroundLayer3D.new()
	layer.name = config.get("name", "BackgroundPlane")
	layer.layer_depth = config.get("depth", -100.0)
	layer.parallax_factor = config.get("parallax", Vector2(0.1, 0.1))

	# Create mesh instance for the plane
	var mesh_instance = MeshInstance3D.new()
	var quad_mesh = QuadMesh.new()
	var scale_vec = config.get("scale", Vector3(50, 1, 50))
	quad_mesh.size = Vector2(scale_vec.x, scale_vec.z)
	mesh_instance.mesh = quad_mesh

	# Create and configure material
	var material = StandardMaterial3D.new()
	var texture_path = config.get("texture_path", "")

	if texture_path != "" and ResourceLoader.exists(texture_path):
		material.albedo_texture = load(texture_path)
		_log_message("BackgroundManager3D: Loaded texture for layer '%s'" % layer.name)
	else:
		material.albedo_color = Color(0.2, 0.2, 0.3, 1.0)
		_log_message("BackgroundManager3D: Using fallback color for layer '%s'" % layer.name)

	# Configure material properties
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = config.get("alpha", 1.0)

	# Apply tint color
	var tint = config.get("tint", Color.WHITE)
	material.albedo_color = material.albedo_color * tint

	mesh_instance.material_override = material
	layer.add_child(mesh_instance)

	# Position the layer
	layer.position = Vector3(0, 0, layer.layer_depth)
	layer_container.add_child(layer)
	active_layers.append(layer)

	_log_message("BackgroundManager3D: Created background plane '%s' at depth %.1f" % [layer.name, layer.layer_depth])
	return layer

func _create_background_objects(config: Dictionary) -> void:
	"""Create procedural background objects"""
	var layer_name = config.get("name", "BackgroundObjects")
	var object_textures = config.get("objects", [])
	var object_count = config.get("count", 5)
	var scale_range = config.get("scale_range", Vector2(5, 15))
	var depth = config.get("depth", -100.0)
	var parallax_factor = config.get("parallax", Vector2(0.1, 0.1))

	_log_message("BackgroundManager3D: Creating %d background objects for layer '%s'" % [object_count, layer_name])

	# Create container for this object layer
	var object_layer = BackgroundLayer3D.new()
	object_layer.name = layer_name
	object_layer.layer_depth = depth
	object_layer.parallax_factor = parallax_factor
	object_layer.position = Vector3(0, 0, depth)

	for i in range(object_count):
		var obj = _create_single_background_object(object_textures, scale_range, depth)
		if obj:
			object_layer.add_child(obj)

	object_container.add_child(object_layer)
	active_layers.append(object_layer)

	_log_message("BackgroundManager3D: Created background object layer '%s' with %d objects" % [layer_name, object_count])

func _create_single_background_object(textures: Array, scale_range: Vector2, depth: float) -> MeshInstance3D:
	"""Create a single background object"""
	var obj = MeshInstance3D.new()

	# Create simple geometry (box or sphere)
	var mesh_type = randi() % 2
	if mesh_type == 0:
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(1, 1, 1)
		obj.mesh = box_mesh
	else:
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.5
		sphere_mesh.rings = 8
		sphere_mesh.radial_segments = 8
		obj.mesh = sphere_mesh

	# Create material
	var material = StandardMaterial3D.new()

	# Try to use texture from the array
	if textures.size() > 0:
		var texture_path = textures.pick_random()
		if ResourceLoader.exists(texture_path):
			material.albedo_texture = load(texture_path)
		else:
			# Fallback color based on depth
			var color_intensity = 1.0 - (abs(depth) / 300.0)
			material.albedo_color = Color(color_intensity * 0.4, color_intensity * 0.5, color_intensity * 0.6, 0.8)
	else:
		# Default distant object color
		material.albedo_color = Color(0.3, 0.3, 0.4, 0.6)

	# Configure material for distance
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.2
	material.emission_energy = 0.3
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	obj.material_override = material

	# Random positioning within reasonable bounds
	obj.position = Vector3(
		randf_range(-200, 200),
		randf_range(-30, 30),
		randf_range(-10, 10)  # Slight Z variation for interest
	)

	# Random scale within range
	var scale_factor = randf_range(scale_range.x, scale_range.y)
	obj.scale = Vector3.ONE * scale_factor

	# Optional slow rotation (simplified - objects will rotate via _process)
	if randf() > 0.5:
		# Store rotation speed as metadata for later processing
		obj.set_meta("rotation_speed", randf_range(0.5, 2.0))
		obj.set_meta("should_rotate", true)

	return obj

func _process_background_rotations(delta: float) -> void:
	"""Process slow rotation for background objects"""
	for layer in active_layers:
		if layer and is_instance_valid(layer):
			for child in layer.get_children():
				if child is MeshInstance3D and child.has_meta("should_rotate"):
					var rotation_speed = child.get_meta("rotation_speed", 1.0)
					child.rotation_degrees.y += rotation_speed * delta * 10.0

func _create_particle_layer(config: Dictionary) -> void:
	"""Create a particle system background layer"""
	var layer_name = config.get("name", "ParticleLayer")
	var particle_count = config.get("count", 100)
	var area = config.get("area", Vector3(200, 50, 200))
	var depth = config.get("depth", -100.0)
	var parallax_factor = config.get("parallax", Vector2(0.1, 0.1))
	var texture_path = config.get("particle_texture", "")

	_log_message("BackgroundManager3D: Creating particle layer '%s' with %d particles" % [layer_name, particle_count])

	# Create particle layer container
	var particle_layer = BackgroundLayer3D.new()
	particle_layer.name = layer_name
	particle_layer.layer_depth = depth
	particle_layer.parallax_factor = parallax_factor
	particle_layer.position = Vector3(0, 0, depth)

	# Create GPU particle system
	var particles = GPUParticles3D.new()
	particles.name = "ParticleSystem"
	particles.emitting = true
	particles.amount = particle_count
	particles.lifetime = 100.0  # Long-lived particles
	particles.local_coords = true

	# Create particle material
	var process_material = ParticleProcessMaterial.new()
	process_material.direction = Vector3(0, 0, 0)
	process_material.initial_velocity_min = 0.0
	process_material.initial_velocity_max = 0.1
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.5
	process_material.scale_max = 2.0

	# Set emission shape
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = area * 0.5

	particles.process_material = process_material

	# Create particle mesh with texture
	var particle_mesh = QuadMesh.new()
	particle_mesh.size = Vector2(1, 1)
	particles.draw_pass_1 = particle_mesh

	# Create particle material
	var particle_material = StandardMaterial3D.new()
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_material.no_depth_test = true

	if texture_path != "" and ResourceLoader.exists(texture_path):
		particle_material.albedo_texture = load(texture_path)
		_log_message("BackgroundManager3D: Loaded particle texture for '%s'" % layer_name)
	else:
		particle_material.albedo_color = Color(1.0, 1.0, 1.0, 0.3)
		_log_message("BackgroundManager3D: Using fallback color for particle layer '%s'" % layer_name)

	particles.material_override = particle_material
	particle_layer.add_child(particles)

	particle_container.add_child(particle_layer)
	active_layers.append(particle_layer)

	_log_message("BackgroundManager3D: Created particle layer '%s' at depth %.1f" % [layer_name, depth])

func _setup_particle_systems() -> void:
	"""Additional particle system setup if needed"""
	_log_message("BackgroundManager3D: Particle systems setup complete")

func set_camera_reference(camera: Camera3D) -> void:
	"""Set the camera reference for parallax calculations"""
	camera_reference = camera
	if camera_reference:
		last_camera_position = camera_reference.global_position
		_log_message("BackgroundManager3D: Camera reference set for parallax tracking")

func _process(delta: float) -> void:
	"""Update parallax scrolling and performance monitoring"""
	if enable_parallax and camera_reference:
		_update_parallax_scrolling()

	if enable_performance_culling:
		performance_timer += delta
		if performance_timer >= performance_check_interval:
			performance_timer = 0.0
			_update_layer_visibility()

	# Process background object rotations
	_process_background_rotations(delta)

func _update_parallax_scrolling() -> void:
	"""Update parallax scrolling for all layers"""
	if not camera_reference:
		return

	var camera_movement = camera_reference.global_position - last_camera_position

	# Only update if camera moved significantly
	if camera_movement.length() > 0.1:
		for layer in active_layers:
			if layer and is_instance_valid(layer):
				var parallax_offset = Vector3(
					camera_movement.x * layer.parallax_factor.x * parallax_strength,
					0,  # Don't parallax on Y axis
					camera_movement.z * layer.parallax_factor.y * parallax_strength
				)
				layer.position += parallax_offset

		last_camera_position = camera_reference.global_position

func _update_layer_visibility() -> void:
	"""Update layer visibility based on distance for performance"""
	if not camera_reference:
		return

	var camera_pos = camera_reference.global_position

	for layer in active_layers:
		if layer and is_instance_valid(layer):
			var distance = camera_pos.distance_to(layer.global_position)
			var should_be_visible = distance <= max_background_distance

			if layer.visible != should_be_visible:
				layer.visible = should_be_visible
				layer_visibility_changed.emit(layer.name, should_be_visible)

func get_layer_count() -> int:
	"""Get the number of active background layers"""
	return active_layers.size()

func set_parallax_strength(strength: float) -> void:
	"""Set the overall parallax strength"""
	parallax_strength = clamp(strength, 0.0, 1.0)
	_log_message("BackgroundManager3D: Parallax strength set to %.2f" % parallax_strength)

func _log_message(message: String) -> void:
	"""Log debug messages"""
	print("[%s] %s" % [Time.get_datetime_string_from_system(), message])
