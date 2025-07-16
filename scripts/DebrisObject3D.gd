# DebrisObject3D.gd
# 3D debris object with physics, floating animation, and collection mechanics
# Converts the 2D debris system to work in 3D space for Children of the Singularity

class_name DebrisObject3D
extends RigidBody3D

## Debris properties
@export var debris_type: String = "scrap_metal"
@export var value: int = 10
@export var debris_id: String = ""

## Animation properties
@export var float_speed: float = 0.5
@export var rotation_speed: float = 20.0
@export var float_amplitude: float = 0.5

## Physics properties
@export var linear_damping: float = 0.5
@export var angular_damping: float = 0.5

## Node references
@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var collection_area: Area3D = $CollectionArea

## Animation state
var initial_position: Vector3
var float_offset: float = 0.0
var is_collected: bool = false

## Texture storage for early assignment
var pending_texture: Texture2D = null
var pending_debris_type: String = ""

## Signal for collection
signal collected(debris_object: DebrisObject3D)

func _ready() -> void:
	_log_message("DebrisObject3D: Initializing 3D debris object")
	_setup_debris_id()
	_setup_3d_physics()
	_setup_3d_sprite()
	_setup_collection_area()
	_setup_initial_animation()
	_log_message("DebrisObject3D: 3D debris object ready - Type: %s, Value: %d" % [debris_type, value])

func _setup_debris_id() -> void:
	##Generate unique debris ID if not set
	if debris_id.is_empty():
		debris_id = "debris_3d_%d_%s" % [Time.get_ticks_msec(), debris_type]

func _setup_3d_physics() -> void:
	##Configure 3D physics properties
	_log_message("DebrisObject3D: Setting up 3D physics")

	# Configure physics for space environment
	gravity_scale = 0.0  # No gravity in space
	linear_damp = linear_damping
	angular_damp = 0.1  # Reduce angular damping for more visible rotation

	# Set collision layers (debris on layer 4)
	collision_layer = 4
	collision_mask = 1  # Collide with player (layer 1)

	# Store initial position for floating animation
	initial_position = position

func _setup_3d_sprite() -> void:
	##Configure 3D sprite properties
	_log_message("DebrisObject3D: Setting up 3D sprite with billboard configuration")

	if not sprite_3d:
		sprite_3d = Sprite3D.new()
		add_child(sprite_3d)
		_log_message("DebrisObject3D: Created new Sprite3D node")

	# Configure sprite properties
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite_3d.pixel_size = 0.0055  # Same size as player ship for visual consistency
	sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Ensure visibility and disable any automatic culling
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite_3d.visibility_range_end = 0.0  # Disable distance-based visibility culling
	sprite_3d.visibility_range_begin = 0.0

	_log_message("DebrisObject3D: Sprite3D configured - pixel_size: %.10f, billboard: %d, filter: %d" % [sprite_3d.pixel_size, sprite_3d.billboard, sprite_3d.texture_filter])

	# Apply pending texture if available
	if pending_texture and pending_debris_type:
		sprite_3d.texture = pending_texture
		var world_size = pending_texture.get_size() * sprite_3d.pixel_size

		# Check if texture is too large and auto-adjust pixel_size for performance
		if pending_texture.get_size().x > 128 or pending_texture.get_size().y > 128:
			# Calculate and apply optimal pixel_size for reasonable world size (target ~3 units)
			var original_pixel_size = sprite_3d.pixel_size
			var suggested_pixel_size = 3.0 / max(pending_texture.get_size().x, pending_texture.get_size().y)
			sprite_3d.pixel_size = suggested_pixel_size
			_log_message("DebrisObject3D: Auto-adjusted pixel_size from %.10f to %.10f for texture size %s" % [original_pixel_size, suggested_pixel_size, pending_texture.get_size()])

		_log_message("DebrisObject3D: Applied pending texture for debris type: %s (size: %s, world size: %s)" % [pending_debris_type, pending_texture.get_size(), world_size])
		pending_texture = null
		pending_debris_type = ""

func _setup_collection_area() -> void:
	##Set up collection area for player interaction
	_log_message("DebrisObject3D: Setting up collection area")

	if collection_area:
		# Configure collection area
		collection_area.collision_layer = 0  # Don't collide with anything
		collection_area.collision_mask = 1   # Detect player (layer 1)

		# Connect signals for collection detection
		collection_area.body_entered.connect(_on_collection_area_entered)
		collection_area.body_exited.connect(_on_collection_area_exited)

		# Set up collision shape for collection area
		var collection_collision = collection_area.get_child(0) as CollisionShape3D
		if collection_collision:
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = 2.0  # Small collection radius
			collection_collision.shape = sphere_shape

func _setup_initial_animation() -> void:
	##Set up initial animation state
	_log_message("DebrisObject3D: Setting up initial animation")

	# Random initial spin for variety - make it more visible
	angular_velocity = Vector3(
		randf_range(-2, 2),
		randf_range(-2, 2),
		randf_range(-2, 2)
	) * rotation_speed * 0.1  # Scale down for smooth rotation

	# Random float offset for variation
	float_offset = randf() * TAU

func _physics_process(delta: float) -> void:
	##Handle physics and animation updates
	if is_collected or not is_inside_tree():
		return

	_update_floating_animation(delta)
	_update_rotation_animation(delta)

func _update_floating_animation(delta: float) -> void:
	##Update gentle floating motion
	if not is_inside_tree() or is_collected:
		return

	float_offset += delta * float_speed
	var float_y = sin(float_offset) * float_amplitude

	# Apply floating motion as force to maintain physics
	var target_pos = initial_position + Vector3(0, float_y, 0)
	var force_direction = (target_pos - position).normalized()

	# Apply gentle force for floating effect
	if force_direction.length() > 0:
		apply_central_force(force_direction * 2.0)

func _update_rotation_animation(_delta: float) -> void:
	##Update rotation animation
	if not is_inside_tree() or is_collected:
		return

	# Maintain continuous rotation despite physics damping
	# Apply rotational velocity to keep debris spinning
	var rotation_force = Vector3(
		sin(Time.get_unix_time_from_system() * 0.7) * rotation_speed,
		cos(Time.get_unix_time_from_system() * 0.5) * rotation_speed,
		sin(Time.get_unix_time_from_system() * 0.3) * rotation_speed
	) * 0.1

	# Apply the rotation force to maintain spin
	apply_torque(rotation_force)

func _on_collection_area_entered(body: Node3D) -> void:
	##Handle player entering collection area
	# Only log once when player enters, avoid spam
	if body.has_method("collect_debris") and not is_collected:
		_log_message("DebrisObject3D: Player entered collection area")
		# Player will handle collection through their collection area

func _on_collection_area_exited(body: Node3D) -> void:
	##Handle player exiting collection area
	# Only log for actual player, avoid spam
	if body.has_method("collect_debris"):
		_log_message("DebrisObject3D: Player exited collection area")

func collect() -> void:
	##Handle debris collection
	if is_collected:
		return

	_log_message("DebrisObject3D: Debris collected - Type: %s, Value: %d" % [debris_type, value])
	is_collected = true

	# Emit collection signal
	collected.emit(self)

	# Remove from scene
	queue_free()

## Public API methods

func get_debris_id() -> String:
	##Get unique debris ID for network synchronization
	return debris_id

func get_debris_type() -> String:
	##Get debris type
	return debris_type

func get_debris_value() -> int:
	##Get debris value
	return value

func get_debris_data() -> Dictionary:
	##Get complete debris data for network sync
	# Check if the node is still in the scene tree before accessing transform data
	if not is_inside_tree():
		_log_message("DebrisObject3D: Warning - get_debris_data() called on node not in scene tree")
		return {
			"id": debris_id,
			"type": debris_type,
			"value": value,
			"position": Vector3.ZERO,
			"rotation": Vector3.ZERO,
			"linear_velocity": Vector3.ZERO,
			"angular_velocity": Vector3.ZERO
		}

	return {
		"id": debris_id,
		"type": debris_type,
		"value": value,
		"position": global_position,
		"rotation": rotation,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity
	}

func apply_network_state(state_data: Dictionary) -> void:
	##Apply network state to debris object
	# Check if the node is still in the scene tree before applying state
	if not is_inside_tree():
		_log_message("DebrisObject3D: Warning - apply_network_state() called on node not in scene tree")
		return

	if is_collected:
		_log_message("DebrisObject3D: Warning - apply_network_state() called on already collected debris")
		return

	_log_message("DebrisObject3D: Applying network state")

	if "position" in state_data:
		global_position = state_data.position
		initial_position = global_position
	if "rotation" in state_data:
		rotation = state_data.rotation
	if "linear_velocity" in state_data:
		linear_velocity = state_data.linear_velocity
	if "angular_velocity" in state_data:
		angular_velocity = state_data.angular_velocity

func set_debris_data(type: String, val: int, color: Color) -> void:
	##Set debris data and visual properties
	_log_message("DebrisObject3D: Setting debris data - Type: %s, Value: %d" % [type, val])

	debris_type = type
	value = val

	# Apply color to sprite
	if sprite_3d:
		sprite_3d.modulate = color

	# Set metadata for compatibility
	set_meta("debris_type", type)
	set_meta("debris_value", val)
	set_meta("debris_id", debris_id)

func set_debris_texture(texture: Texture2D, texture_debris_type: String) -> void:
	_log_message("DebrisObject3D: Setting texture for debris type: %s (valid: %s)" % [texture_debris_type, texture != null])
	if texture:
		# Log texture details only in debug mode
		_log_message("DebrisObject3D: Texture loaded - size: %s, class: %s" % [texture.get_size(), texture.get_class()])

	if sprite_3d:
		sprite_3d.texture = texture
		# Log actual rendered size
		var actual_size = texture.get_size() * sprite_3d.pixel_size
		_log_message("DebrisObject3D: Texture applied immediately - world size: %s" % actual_size)

		pending_texture = null
		pending_debris_type = ""
	else:
		pending_texture = texture
		pending_debris_type = texture_debris_type
		_log_message("DebrisObject3D: Texture stored as pending for debris type: %s (size: %s)" % [texture_debris_type, texture.get_size()])

func _log_message(message: String) -> void:
	##Log message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	print("[%s] %s" % [timestamp, message])
