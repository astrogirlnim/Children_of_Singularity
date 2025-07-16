# SpaceStationModule3D.gd
# Base class for 3D space station modules in Children of the Singularity
# Handles different module types (habitat, industrial, docking, etc.) with visual variety
# Now uses 2D sprite billboards for consistent visual style

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

## Node references (will be created dynamically if they don't exist)
var sprite_3d: Sprite3D
var collision_shape: CollisionShape3D
var interaction_area: Area3D
var interaction_collision: CollisionShape3D

## Module configuration data
var module_data: Dictionary = {}
var module_id: String = ""
var is_active: bool = true

## Space station animation textures - preloaded for fast switching (like PlayerShip3D)
var station_animation_textures: Array[Texture2D] = []
var current_frame: int = 1  # Start at frame 1
var animation_timer: Timer
var animation_speed: float = 0.1  # Time in seconds between frames (10 FPS for smooth rotation)
var total_frames: int = 70  # Frames 1-70 (station_frame_001.png to station_frame_070.png)

## Animation state management (continuous spinning)
var is_spinning: bool = true
var spin_direction: int = 1  # 1 for forward, -1 for reverse

func _ready() -> void:
	_log_message("SpaceStationModule3D: Initializing module type %s with spinning animation" % ModuleType.keys()[module_type])
	_generate_module_id()
	_setup_collision_layers()
	_load_station_animation_textures()  # Load all animation frames first
	_setup_sprite_billboard()
	_setup_collision_shape()
	_setup_interaction_area()
	_configure_module_appearance()
	_setup_rotation_animation()
	_setup_module_data()
	_log_message("SpaceStationModule3D: Module %s ready with spinning animation - ID: %s" % [ModuleType.keys()[module_type], module_id])

func _exit_tree() -> void:
	"""Clean up animation resources when node is freed"""
	if animation_timer and animation_timer.is_valid():
		animation_timer.queue_free()
	_log_message("SpaceStationModule3D: Animation resources cleaned up")

func _generate_module_id() -> void:
	"""Generate unique module ID"""
	module_id = "module_%s_%d" % [ModuleType.keys()[module_type].to_lower(), Time.get_unix_time_from_system()]

func _setup_collision_layers() -> void:
	"""Set up collision layers for station modules"""
	# Layer 8 for NPC/station interactions (compatible with existing player interaction system)
	collision_layer = 8
	collision_mask = 1  # Can collide with player layer

func _load_station_animation_textures() -> void:
	"""Load all station animation frame textures into memory for fast switching"""
	_log_message("SpaceStationModule3D: Loading station animation textures...")

	# Resize array to hold all frames (1-70)
	station_animation_textures.resize(total_frames + 1)

	# Load frames from 1 to 70
	var loaded_count = 0
	for i in range(1, total_frames + 1):
		var texture_path = "res://assets/sprites/space_station/animation_frames/station_frame_%03d.png" % i
		var texture = load(texture_path) as Texture2D
		if texture:
			station_animation_textures[i] = texture
			loaded_count += 1
		else:
			_log_message("SpaceStationModule3D: Failed to load texture: %s" % texture_path)

	_log_message("SpaceStationModule3D: Loaded %d/%d station animation textures" % [loaded_count, total_frames])

func _set_station_frame(frame_number: int) -> void:
	"""Set the station sprite to a specific frame"""
	if frame_number < 1 or frame_number > total_frames:
		_log_message("SpaceStationModule3D: Invalid frame number: %d" % frame_number)
		return

	if sprite_3d and station_animation_textures.size() > frame_number and station_animation_textures[frame_number]:
		sprite_3d.texture = station_animation_textures[frame_number]
		current_frame = frame_number
	else:
		_log_message("SpaceStationModule3D: Could not set frame %d" % frame_number)

func _on_animation_timer_timeout() -> void:
	"""Handle animation timer timeout - advance to next frame"""
	if not is_spinning:
		return

	# Advance to next frame with looping
	current_frame += spin_direction
	if current_frame > total_frames:
		current_frame = 1  # Loop back to start
	elif current_frame < 1:
		current_frame = total_frames  # Loop back to end

	# Update the sprite to the new frame
	_set_station_frame(current_frame)

func _setup_sprite_billboard() -> void:
	"""Set up the 3D sprite billboard for the spinning space station"""
	_log_message("SpaceStationModule3D: Setting up sprite billboard with animation support")

	# Remove any existing mesh instance
	var existing_mesh = get_node_or_null("MeshInstance3D")
	if existing_mesh:
		existing_mesh.queue_free()
		_log_message("SpaceStationModule3D: Removed existing MeshInstance3D")

	# Create or get Sprite3D node
	sprite_3d = get_node_or_null("Sprite3D")
	if not sprite_3d:
		sprite_3d = Sprite3D.new()
		sprite_3d.name = "Sprite3D"
		add_child(sprite_3d)
		_log_message("SpaceStationModule3D: Created new Sprite3D node")

	# Configure sprite for billboard mode (same as player and debris)
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite_3d.pixel_size = 0.03  # 5-6x larger than player ship (0.0055) for realistic space station scale

	# Set initial frame if textures are loaded
	if station_animation_textures.size() > current_frame and station_animation_textures[current_frame]:
		sprite_3d.texture = station_animation_textures[current_frame]
		_log_message("SpaceStationModule3D: Set initial frame %d" % current_frame)
	else:
		_log_message("SpaceStationModule3D: Textures not yet loaded, will set frame later")

	_log_message("SpaceStationModule3D: Sprite billboard configured for animation")

func _setup_collision_shape() -> void:
	"""Set up collision shape for the station module"""
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)

	# Create a reasonable collision box for the station (scaled up to match larger sprite)
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(20, 15, 20) * module_scale  # Larger collision to match 5-6x sprite scale
	collision_shape.shape = box_shape

	_log_message("SpaceStationModule3D: Collision shape configured - Size: %s" % box_shape.size)

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

	# Connect signals (check if not already connected)
	if not interaction_area.body_entered.is_connected(_on_interaction_area_entered):
		interaction_area.body_entered.connect(_on_interaction_area_entered)
	if not interaction_area.body_exited.is_connected(_on_interaction_area_exited):
		interaction_area.body_exited.connect(_on_interaction_area_exited)

	_log_message("SpaceStationModule3D: Interaction area configured with radius %.1f" % interaction_radius)

func _configure_module_appearance() -> void:
	"""Configure the visual appearance based on module type using sprite tinting"""
	_log_message("SpaceStationModule3D: Configuring module appearance for type %s" % ModuleType.keys()[module_type])

	if not sprite_3d:
		_log_message("SpaceStationModule3D: ERROR - No sprite_3d found for appearance configuration!")
		return

	# Configure scaling and color tinting based on module type
	var sprite_scale = Vector3.ONE
	var sprite_color = Color.WHITE
	var collision_size = Vector3(20, 15, 20)  # Default size (scaled up for larger station)

	match module_type:
		ModuleType.HABITAT:
			sprite_scale = Vector3(1.0, 1.0, 1.0) * module_scale
			sprite_color = Color(0.7, 1.0, 0.7, 1.0)  # Soft green tint
			collision_size = Vector3(20, 15, 20) * module_scale
			hub_type = "general"
			_log_message("SpaceStationModule3D: Applied HABITAT appearance - Green tint")

		ModuleType.INDUSTRIAL:
			sprite_scale = Vector3(1.2, 1.0, 1.0) * module_scale
			sprite_color = Color(1.0, 0.8, 0.6, 1.0)  # Industrial orange tint
			collision_size = Vector3(25, 15, 20) * module_scale
			hub_type = "industrial"
			_log_message("SpaceStationModule3D: Applied INDUSTRIAL appearance - Orange tint")

		ModuleType.DOCKING:
			sprite_scale = Vector3(1.3, 0.8, 1.0) * module_scale
			sprite_color = Color(1.0, 1.0, 0.6, 1.0)  # Docking yellow tint
			collision_size = Vector3(30, 12, 20) * module_scale
			hub_type = "docking"
			_log_message("SpaceStationModule3D: Applied DOCKING appearance - Yellow tint")

		ModuleType.TRADING:
			sprite_scale = Vector3(1.1, 1.1, 1.1) * module_scale
			sprite_color = Color.WHITE  # No tint - original sprite colors
			collision_size = Vector3(22, 17, 22) * module_scale
			hub_type = "trading"
			_log_message("SpaceStationModule3D: Applied TRADING appearance - No tint")

		ModuleType.COMMAND:
			sprite_scale = Vector3(1.2, 1.3, 1.2) * module_scale
			sprite_color = Color(0.6, 0.8, 1.0, 1.0)  # Command blue tint
			collision_size = Vector3(25, 20, 25) * module_scale
			hub_type = "command"
			_log_message("SpaceStationModule3D: Applied COMMAND appearance - Blue tint")

		ModuleType.POWER:
			sprite_scale = Vector3(0.8, 1.5, 0.8) * module_scale
			sprite_color = Color(1.0, 0.6, 0.6, 1.0)  # Power red tint
			collision_size = Vector3(15, 22, 15) * module_scale
			hub_type = "power"
			_log_message("SpaceStationModule3D: Applied POWER appearance - Red tint")

		ModuleType.STORAGE:
			sprite_scale = Vector3(1.4, 1.0, 1.6) * module_scale
			sprite_color = Color(0.8, 0.8, 0.8, 1.0)  # Storage gray tint
			collision_size = Vector3(28, 15, 32) * module_scale
			hub_type = "storage"
			_log_message("SpaceStationModule3D: Applied STORAGE appearance - Gray tint")

		ModuleType.RESEARCH:
			sprite_scale = Vector3(1.0, 1.0, 1.4) * module_scale
			sprite_color = Color(0.8, 0.6, 1.0, 1.0)  # Research purple tint
			collision_size = Vector3(20, 15, 28) * module_scale
			hub_type = "research"
			_log_message("SpaceStationModule3D: Applied RESEARCH appearance - Purple tint")

	# Apply scale and color to the sprite
	sprite_3d.scale = sprite_scale
	sprite_3d.modulate = sprite_color

	# Update collision shape to match module type
	if collision_shape and collision_shape.shape is BoxShape3D:
		(collision_shape.shape as BoxShape3D).size = collision_size
		_log_message("SpaceStationModule3D: Updated collision size to %s" % collision_size)

	_log_message("SpaceStationModule3D: Configured %s module with scale %s and color %s" % [ModuleType.keys()[module_type], sprite_scale, sprite_color])

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
		# Reduced logging to prevent spam
		module_entered.emit(hub_type, self)

func _on_interaction_area_exited(body: Node3D) -> void:
	"""Handle player exiting module interaction area"""
	if body.has_method("collect_debris"):  # Check if it's the player
		# Reduced logging to prevent spam
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

func get_sprite_3d() -> Sprite3D:
	"""Get the Sprite3D node for external access"""
	return sprite_3d

func set_sprite_color(color: Color) -> void:
	"""Set the sprite color/tint"""
	if sprite_3d:
		sprite_3d.modulate = color
		_log_message("SpaceStationModule3D: Sprite color set to %s" % color)

func set_sprite_scale(scale: Vector3) -> void:
	"""Set the sprite scale"""
	if sprite_3d:
		sprite_3d.scale = scale
		_log_message("SpaceStationModule3D: Sprite scale set to %s" % scale)

func _setup_rotation_animation() -> void:
	"""Set up the continuous rotation animation timer"""
	_log_message("SpaceStationModule3D: Setting up continuous spinning animation")

	# Create animation timer
	animation_timer = Timer.new()
	animation_timer.name = "AnimationTimer"
	animation_timer.wait_time = animation_speed
	animation_timer.autostart = true
	animation_timer.timeout.connect(_on_animation_timer_timeout)
	add_child(animation_timer)

	# Start with a random frame for visual variety between stations
	current_frame = randi() % total_frames + 1

	# Set initial frame if textures are loaded
	if station_animation_textures.size() > current_frame and station_animation_textures[current_frame]:
		_set_station_frame(current_frame)

	_log_message("SpaceStationModule3D: Continuous spinning animation active - Frame rate: %.1f FPS, Starting frame: %d" % [1.0/animation_speed, current_frame])

func set_animation_speed(speed: float) -> void:
	"""Set the rotation animation speed (time between frames)"""
	animation_speed = speed
	if animation_timer:
		animation_timer.wait_time = animation_speed
		_log_message("SpaceStationModule3D: Animation speed updated to %.2f seconds per frame (%.1f FPS)" % [animation_speed, 1.0/animation_speed])

func pause_spinning() -> void:
	"""Pause the spinning animation"""
	is_spinning = false
	if animation_timer:
		animation_timer.paused = true
		_log_message("SpaceStationModule3D: Spinning animation paused")

func resume_spinning() -> void:
	"""Resume the spinning animation"""
	is_spinning = true
	if animation_timer:
		animation_timer.paused = false
		_log_message("SpaceStationModule3D: Spinning animation resumed")

func reverse_spin_direction() -> void:
	"""Reverse the spinning direction"""
	spin_direction *= -1
	_log_message("SpaceStationModule3D: Spin direction reversed - now spinning %s" % ("forward" if spin_direction > 0 else "backward"))

func _rotate_sprite() -> void:
	"""Legacy function kept for compatibility - now handled by animation timer"""
	_log_message("SpaceStationModule3D: Legacy _rotate_sprite called - using new animation system instead")
	return

	# Original rotation code (disabled)
	# if not sprite_3d or station_sprite_textures.size() <= 1:
	# 	return
	#
	# # Move to next sprite in sequence
	# current_sprite_index = (current_sprite_index + 1) % station_sprite_textures.size()
	#
	# # Update the sprite texture
	# sprite_3d.texture = station_sprite_textures[current_sprite_index]
	#
	# # Log rotation for debugging (reduced frequency to avoid spam)
	# if current_sprite_index == 0:  # Only log when completing a full cycle
	# 	_log_message("SpaceStationModule3D: Completed rotation cycle - Now showing sprite v%d" % (current_sprite_index + 1))

func _log_message(message: String) -> void:
	"""Log a message with timestamp"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
