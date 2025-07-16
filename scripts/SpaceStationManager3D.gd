# SpaceStationManager3D.gd
# Manages modular 3D space station construction in Children of the Singularity
# Replaces simple NPC hubs with procedurally generated modular space stations

class_name SpaceStationManager3D
extends Node3D

# Preload the SpaceStationModule3D script to avoid circular dependency issues
const SpaceStationModule3DScript = preload("res://scripts/SpaceStationModule3D.gd")

## Signal emitted when a new station module is created
signal module_created(module: Node3D)

## Signal emitted when player enters any module
signal player_entered_module(module_type: String, module: Node3D)

## Signal emitted when player exits any module
signal player_exited_module(module_type: String, module: Node3D)

## Export properties for configuration
@export var station_container: Node3D
@export var zone_bounds: Vector3 = Vector3(100, 50, 100)
@export var station_count: int = 2  # Reduced from 3 to 2 stations per zone
@export var modules_per_station: int = 3  # Reduced from 5 to 3 modules per station
@export var module_spacing: float = 20.0
@export var station_separation: float = 60.0

# Define module types enum locally to avoid dependency issues
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

## Station layouts and configurations (simplified to 1 module per station)
var station_templates: Array[Dictionary] = [
	{
		"name": "Space Station Alpha",
		"modules": [
			{"type": ModuleType.COMMAND, "position": Vector3(0, 0, 0)}
		]
	},
	{
		"name": "Industrial Outpost",
		"modules": [
			{"type": ModuleType.INDUSTRIAL, "position": Vector3(0, 0, 0)}
		]
	}
]

## Internal state
var active_stations: Array[Dictionary] = []
var all_modules: Array[Node3D] = []
var station_positions: Array[Vector3] = []

func _ready() -> void:
	_log_message("SpaceStationManager3D: Initializing modular space station system")
	_setup_station_container()
	_calculate_station_positions()
	await _generate_space_stations()
	_log_message("SpaceStationManager3D: Generated %d modular space stations with %d total modules" % [active_stations.size(), all_modules.size()])

func _setup_station_container() -> void:
	"""Set up the container for station modules"""
	if not station_container:
		station_container = Node3D.new()
		station_container.name = "SpaceStationsContainer"
		add_child(station_container)
		_log_message("SpaceStationManager3D: Created station container")

func _calculate_station_positions() -> void:
	"""Calculate positions for space stations near player spawn location"""
	_log_message("SpaceStationManager3D: Calculating station positions near player spawn")
	station_positions.clear()

	# Player spawn position is at (0, 2, 0) - place stations nearby
	var player_spawn_position = Vector3(0, 2, 0)
	var station_radius = 20.0  # Increased for larger sprite clearance
	var min_distance_between_stations = 15.0  # Increased spacing between stations

	for i in range(station_count):
		var position: Vector3
		var attempts = 0
		var max_attempts = 20

		# Find a valid position near player spawn that doesn't overlap with other stations
		while attempts < max_attempts:
			# Generate position in a circle around player spawn
			var angle = (PI * 2 * i / station_count) + randf_range(-PI/4, PI/4)  # Spread stations around player
			var distance = randf_range(15.0, station_radius)  # Safer distance from player (15-20 units)

			position = Vector3(
				player_spawn_position.x + cos(angle) * distance,
				player_spawn_position.y + randf_range(-0.5, 0.5),  # Changed from +randf_range(10, 15) to keep stations at ship level (Y=2)
				player_spawn_position.z + sin(angle) * distance
			)

			# Check distance from other stations
			var valid_position = true
			for existing_pos in station_positions:
				if existing_pos.distance_to(position) < min_distance_between_stations:
					valid_position = false
					break

			if valid_position:
				break

			attempts += 1

		station_positions.append(position)
		_log_message("SpaceStationManager3D: Station %d positioned near player spawn at: %s (distance from player: %.1f)" % [i, position, position.distance_to(player_spawn_position)])

func _generate_space_stations() -> void:
	"""Generate all space stations using templates"""
	_log_message("SpaceStationManager3D: Generating space stations")

	for i in range(station_count):
		var station_position = station_positions[i]
		var template = station_templates[i % station_templates.size()]

		var station_data = await _create_space_station(template, station_position, i)
		active_stations.append(station_data)

		_log_message("SpaceStationManager3D: Created station '%s' at %s with %d modules" % [template.name, station_position, template.modules.size()])

func _create_space_station(template: Dictionary, base_position: Vector3, station_id: int) -> Dictionary:
	"""Create a single space station from a template"""
	var station_node = Node3D.new()
	station_node.name = "Station_%d_%s" % [station_id, template.name.replace(" ", "_")]
	station_node.position = base_position
	station_container.add_child(station_node)

	var station_modules: Array[Node3D] = []
	var module_configs = template.get("modules", [])

	for i in range(module_configs.size()):
		var module_config = module_configs[i]
		var module = await _create_station_module(
			module_config.type,
			module_config.position,
			station_node,
			i
		)

		if module:
			station_modules.append(module)
			all_modules.append(module)

			# Connect module signals if they exist
			if module.has_signal("module_entered"):
				module.module_entered.connect(_on_module_entered)
			if module.has_signal("module_exited"):
				module.module_exited.connect(_on_module_exited)

	var station_data = {
		"id": station_id,
		"name": template.name,
		"position": base_position,
		"node": station_node,
		"modules": station_modules,
		"template": template
	}

	return station_data

func _create_station_module(module_type: ModuleType, relative_position: Vector3, parent: Node3D, module_index: int) -> Node3D:
	"""Create a single station module"""
	# Create a StaticBody3D as required by SpaceStationModule3D script
	var module = StaticBody3D.new()
	module.set_script(SpaceStationModule3DScript)
	module.name = "Module_%d_%s" % [module_index, ModuleType.keys()[module_type]]

	# Set module properties using set() to avoid property assignment issues
	module.set("module_type", module_type)
	module.position = relative_position

	# Add some variation to module scale
	var scale_variation = randf_range(0.8, 1.2)
	module.set("module_scale", Vector3(scale_variation, scale_variation, scale_variation))

	parent.add_child(module)

	# Wait for script to fully initialize
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame to ensure full initialization

	# Force script initialization by calling _ready if it hasn't been called
	if module.has_method("_ready"):
		module._ready()

	# Add visual details to make modules more interesting
	if module.has_method("add_module_details"):
		module.add_module_details()

	_log_message("SpaceStationManager3D: Created %s module at %s" % [ModuleType.keys()[module_type], relative_position])

	module_created.emit(module)
	return module

func _on_module_entered(module_type: String, module: Node3D) -> void:
	"""Handle player entering any module"""
	_log_message("SpaceStationManager3D: Player entered %s module" % module_type)
	player_entered_module.emit(module_type, module)

func _on_module_exited(module_type: String, module: Node3D) -> void:
	"""Handle player exiting any module"""
	_log_message("SpaceStationManager3D: Player exited %s module" % module_type)
	player_exited_module.emit(module_type, module)

func get_all_modules() -> Array[Node3D]:
	"""Get all station modules"""
	return all_modules

func get_modules_by_type(module_type: ModuleType) -> Array[Node3D]:
	"""Get all modules of a specific type"""
	var filtered_modules: Array[Node3D] = []

	for module in all_modules:
		if module.has_method("get_module_type") and module.get_module_type() == module_type:
			filtered_modules.append(module)

	return filtered_modules

func get_trading_modules() -> Array[Node3D]:
	"""Get all trading modules for compatibility with existing systems"""
	return get_modules_by_type(ModuleType.TRADING)

func get_station_count() -> int:
	"""Get the number of active stations"""
	return active_stations.size()

func get_module_count() -> int:
	"""Get the total number of modules"""
	return all_modules.size()

func get_station_data() -> Array[Dictionary]:
	"""Get data for all stations"""
	var station_data: Array[Dictionary] = []

	for station in active_stations:
		var modules_data: Array[Dictionary] = []
		for module in station.modules:
			if module.has_method("get_module_data"):
				modules_data.append(module.get_module_data())

		station_data.append({
			"id": station.id,
			"name": station.name,
			"position": station.position,
			"module_count": station.modules.size(),
			"modules": modules_data
		})

	return station_data

func add_connecting_structures() -> void:
	"""Add connecting structures between modules in each station"""
	_log_message("SpaceStationManager3D: Adding connecting structures between modules")

	for station in active_stations:
		_add_station_connections(station)

func _add_station_connections(station: Dictionary) -> void:
	"""Add connecting structures for a single station"""
	var modules = station.get("modules", [])
	var station_node = station.get("node")

	if not station_node or modules.size() < 2:
		return

	var connections_container = Node3D.new()
	connections_container.name = "StationConnections"
	station_node.add_child(connections_container)

	# Connect nearby modules with tubes/corridors
	for i in range(modules.size()):
		for j in range(i + 1, modules.size()):
			var module_a = modules[i]
			var module_b = modules[j]

			var distance = module_a.position.distance_to(module_b.position)

			# Only connect modules that are relatively close
			if distance < 30.0:
				_create_connection_tube(module_a, module_b, connections_container)

func _create_connection_tube(module_a: Node3D, module_b: Node3D, parent: Node3D) -> void:
	"""Create a connecting tube between two modules"""
	var tube = MeshInstance3D.new()
	var cylinder_mesh = CylinderMesh.new()

	# Calculate tube properties
	var distance = module_a.position.distance_to(module_b.position)
	var midpoint = (module_a.position + module_b.position) / 2

	cylinder_mesh.height = distance
	cylinder_mesh.top_radius = 0.8
	cylinder_mesh.bottom_radius = 0.8

	# Create tube material
	var tube_material = StandardMaterial3D.new()
	tube_material.albedo_color = Color(0.6, 0.6, 0.7, 1.0)
	tube_material.metallic = 0.3
	tube_material.roughness = 0.7

	tube.mesh = cylinder_mesh
	tube.material_override = tube_material
	tube.position = midpoint

	# Orient tube to connect the modules
	tube.look_at(module_b.global_position, Vector3.UP)
	tube.rotate_object_local(Vector3.RIGHT, PI/2)

	parent.add_child(tube)

	_log_message("SpaceStationManager3D: Created connection tube between modules (distance: %.1f)" % distance)

func create_custom_station(station_name: String, position: Vector3, module_types: Array) -> Dictionary:
	"""Create a custom station with specified module types"""
	_log_message("SpaceStationManager3D: Creating custom station '%s' at %s" % [station_name, position])

	var custom_template = {
		"name": station_name,
		"modules": []
	}

	# Arrange modules in a grid pattern
	var modules_per_row = ceil(sqrt(module_types.size()))

	for i in range(module_types.size()):
		var row = i / int(modules_per_row)
		var col = i % int(modules_per_row)

		var module_position = Vector3(
			(col - modules_per_row/2) * module_spacing,
			0,
			(row - modules_per_row/2) * module_spacing
		)

		custom_template.modules.append({
			"type": module_types[i],
			"position": module_position
		})

	var station_data = await _create_space_station(custom_template, position, active_stations.size())
	active_stations.append(station_data)

	_log_message("SpaceStationManager3D: Custom station '%s' created with %d modules" % [station_name, module_types.size()])

	return station_data

func remove_simple_npc_hubs() -> void:
	"""Remove the old simple NPC hub boxes"""
	_log_message("SpaceStationManager3D: Removing old simple NPC hub boxes")

	# Find and remove old NPCHub nodes
	var zone_main = get_parent()
	if zone_main and zone_main.has_node("NPCHubContainer"):
		var hub_container = zone_main.get_node("NPCHubContainer")

		# Remove old hubs
		for child in hub_container.get_children():
			if child.name.begins_with("NPCHub"):
				_log_message("SpaceStationManager3D: Removing old hub: %s" % child.name)
				child.queue_free()

func _log_message(message: String) -> void:
	"""Log a message with timestamp"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
