# PlayerShip3D.gd
# 3D version of the player ship controller for Children of the Singularity
# Handles player movement, debris collection, and basic interactions in 3D space

class_name PlayerShip3D
extends CharacterBody3D

## Movement constants (legacy - being replaced with Mario Kart physics)
const SPEED = 10.0
const ACCELERATION = 40.0
const FRICTION = 20.0
const JUMP_VELOCITY = 8.0  # For floating/hovering mechanics

## Mario Kart Style Physics Parameters
@export_group("Steering Controls")
@export var max_turn_speed: float = 90.0           # Max degrees/second at low speed
@export var turn_speed_at_max_velocity: float = 45.0  # Degrees/second at max speed
@export var reverse_turn_multiplier: float = 0.7    # Turn speed when reversing
@export var turn_smoothing: float = 8.0             # Rotation interpolation speed

@export_group("Movement Physics")
@export var max_forward_speed: float = 15.0         # Maximum forward velocity
@export var max_reverse_speed: float = 8.0          # Maximum reverse velocity
@export var acceleration_force: float = 20.0        # Forward acceleration rate
@export var brake_force: float = 30.0               # Braking force
@export var friction_force: float = 5.0             # Natural friction when no input
@export var momentum_factor: float = 0.9            # Momentum preservation

## Gravity (adjusted for space floating effect)
var gravity: float = -9.8
var floor_normal: Vector3 = Vector3.UP

## Signals (compatible with 2D version)
signal debris_collected(debris_type: String, value: int)
signal position_changed(new_position: Vector3)
signal interaction_available(interaction_type: String)
signal interaction_unavailable()
signal npc_hub_entered(hub_type: String)
signal npc_hub_exited()
signal inventory_expanded(old_capacity: int, new_capacity: int)

## Node references
@onready var sprite_3d: Sprite3D = $Sprite3D

## Ship animation textures - preloaded for fast switching
var ship_textures: Array[Texture2D] = []
var current_frame: int = 113  # Default straight frame
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var collection_area: Area3D = $CollectionArea
@onready var collection_collision: CollisionShape3D = $CollectionArea/CollectionCollision
@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_collision: CollisionShape3D = $InteractionArea/InteractionCollision

## Animation state management
var current_animation_state: String = "straight"
var is_turning_left: bool = false
var is_turning_right: bool = false
var animation_tween: Tween

## Animation constants
const DEFAULT_FRAME: int = 113
const LEFT_TURN_START: int = 113
const LEFT_TURN_END: int = 98
const RIGHT_TURN_START: int = 113
const RIGHT_TURN_END: int = 127
const ANIMATION_SPEED: float = 12.0  # frames per second
const FRAME_COUNT: int = 127  # Total number of frames (1-127)

## Movement state (legacy - being replaced)
var input_vector: Vector2 = Vector2.ZERO
var movement_velocity: Vector3 = Vector3.ZERO

## Mario Kart Movement State
var steering_input: float = 0.0              # Current steering input (-1 to 1)
var acceleration_input: float = 0.0          # Current acceleration input (-1 to 1)
var current_velocity: float = 0.0            # Forward/backward velocity
var current_direction: Vector3 = Vector3.FORWARD  # Ship's facing direction

## Player state (same as 2D version)
var player_id: String = "550e8400-e29b-41d4-a716-446655440000"
var current_inventory: Array[Dictionary] = []
var inventory_capacity: int = 10
var credits: int = 0
var upgrades: Dictionary = {}

## Data loading state
var is_loading_from_backend: bool = false  # Flag to prevent clearing data during backend loading

## Interaction state
var can_collect: bool = true
var collection_range: float = 3.0  # Touching distance - just overlaps with debris (2.0 radius)
var nearby_debris: Array[RigidBody3D] = []
var collection_cooldown: float = 0.5

## NPC interaction state
var nearby_npcs: Array[Node3D] = []
var current_npc_hub: Node3D = null
var can_interact: bool = false

## Movement properties
var speed: float = 200.0
var acceleration: float = 800.0
var friction: float = 600.0

## Debug logging control (to prevent spam)
var debug_log_timer: float = 0.0
var debug_log_interval: float = 2.0  # Log every 2 seconds instead of every frame
var enable_debug_logs: bool = false  # Disable verbose logs by default
var last_logged_steering: float = 0.0
var last_logged_velocity: float = 0.0
var last_logged_acceleration: float = 0.0

## Scanner and Magnet states
var is_scanner_active: bool = false
var is_magnet_active: bool = false
var magnet_range: float = 15.0

## Ship rotation for mouse control
var target_rotation: float = 0.0
var current_ship_rotation: float = 0.0
var ship_rotation_speed: float = 3.0
var ship_forward_direction: Vector3 = Vector3.FORWARD

## Visual feedback for collection range
var collection_indicator: MeshInstance3D = null
var collection_material: StandardMaterial3D = null
var show_collection_indicator: bool = false  # Set to true to see collection range when near debris

func _ready() -> void:
	_log_message("PlayerShip3D: Initializing 3D player ship")
	_setup_3d_components()
	_setup_collision_detection()
	_setup_collection_area()
	_setup_interaction_area()
	_initialize_player_state()
	_log_message("PlayerShip3D: 3D player ship ready for gameplay")

func _exit_tree() -> void:
	##Clean up animation resources when node is freed
	if animation_tween and animation_tween.is_valid():
		animation_tween.kill()

	_log_message("PlayerShip3D: Animation resources cleaned up")

func _setup_3d_components() -> void:
	##Set up 3D-specific components
	_log_message("PlayerShip3D: Setting up 3D components")

	# Load all ship animation frame textures
	_load_ship_animation_textures()

	# Configure sprite to always face camera (billboard mode)
	if sprite_3d:
		sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

		# Set default frame (113 - straight position)
		_set_ship_frame(DEFAULT_FRAME)

		_log_message("PlayerShip3D: Sprite3D configured with billboard mode and default frame")

	# Animation tween will be created when needed
	animation_tween = null

	# Configure floor settings (important for 3D physics)
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(45)
	floor_block_on_wall = false

func _setup_collision_detection() -> void:
	##Set up collision detection for the 3D player ship
	_log_message("PlayerShip3D: Setting up 3D collision detection")

	# Set collision layers for proper boundary detection
	collision_layer = 1   # Player on layer 1
	collision_mask = 17   # Detect layer 1 (other players/objects) + layer 5 (16) for boundaries
	_log_message("PlayerShip3D: Collision layers configured - Layer: 1, Mask: 17 (includes boundary walls)")

	if collision_shape:
		# Create collision shape wider than sprite (critical for 3D)
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(4.0, 2.0, 4.0)  # Wide on X and Z, thin on Y
		collision_shape.shape = box_shape
		_log_message("PlayerShip3D: Created wide collision box (4x2x4)")

func _setup_collection_area() -> void:
	##Set up 3D collection area for debris detection
	_log_message("PlayerShip3D: Setting up 3D collection area")

	if not collection_area:
		collection_area = Area3D.new()
		collection_area.name = "CollectionArea"
		collection_area.collision_layer = 0  # Don't collide with anything
		collection_area.collision_mask = 4   # Detect debris (layer 4)
		add_child(collection_area)

		# Create collision shape for collection area
		collection_collision = CollisionShape3D.new()
		collection_collision.name = "CollectionCollision"
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = collection_range
		collection_collision.shape = sphere_shape
		collection_area.add_child(collection_collision)
		_log_message("PlayerShip3D: Created 3D collection area with sphere collision")

	# Connect signals
	if collection_area:
		collection_area.body_entered.connect(_on_collection_area_body_entered)
		collection_area.body_exited.connect(_on_collection_area_body_exited)
		_log_message("PlayerShip3D: Collection area signals connected")

	# Create visual collection range indicator
	if show_collection_indicator:
		_create_collection_range_indicator()

func _create_collection_range_indicator() -> void:
	##Create a visual indicator for collection range
	_log_message("PlayerShip3D: Creating collection range indicator")

	# Create the mesh instance for the indicator
	collection_indicator = MeshInstance3D.new()
	collection_indicator.name = "CollectionRangeIndicator"

	# Create a sphere mesh for the range indicator
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = collection_range
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8
	collection_indicator.mesh = sphere_mesh

	# Create a transparent material for the indicator
	collection_material = StandardMaterial3D.new()
	collection_material.albedo_color = Color(0.0, 0.8, 1.0, 0.1)  # Very transparent cyan
	collection_material.flags_transparent = true
	collection_material.flags_unshaded = true
	collection_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	collection_material.no_depth_test = true
	collection_indicator.material_override = collection_material

	# Start invisible - only show when debris is nearby
	collection_indicator.visible = false

	# Add to ship
	add_child(collection_indicator)
	_log_message("PlayerShip3D: Collection range indicator created (invisible by default)")

func _setup_interaction_area() -> void:
	##Set up 3D interaction area for NPC detection
	_log_message("PlayerShip3D: Setting up 3D interaction area")

	if not interaction_area:
		interaction_area = Area3D.new()
		interaction_area.name = "InteractionArea"
		interaction_area.collision_layer = 0  # Don't collide with anything
		interaction_area.collision_mask = 8   # Detect NPCs (layer 8)
		add_child(interaction_area)

		# Create collision shape for interaction area
		interaction_collision = CollisionShape3D.new()
		interaction_collision.name = "InteractionCollision"
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = collection_range
		interaction_collision.shape = sphere_shape
		interaction_area.add_child(interaction_collision)
		_log_message("PlayerShip3D: Created 3D interaction area with sphere collision")

	# Connect signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
		_log_message("PlayerShip3D: Interaction area signals connected")

func _initialize_player_state() -> void:
	##Initialize player state and inventory
	_log_message("PlayerShip3D: Initializing 3D player state")

	# Don't clear data if we're loading from backend
	if not is_loading_from_backend:
		current_inventory.clear()
		credits = 0
		upgrades = {
			"speed_boost": 0,
			"inventory_expansion": 0,
			"collection_efficiency": 0,
			"zone_access": 1
		}
		_log_message("PlayerShip3D: Initialized with default values - Credits: %d, Capacity: %d/%d" % [credits, current_inventory.size(), inventory_capacity])
	else:
		_log_message("PlayerShip3D: Waiting for backend data load - Current credits: %d, inventory: %d items" % [credits, current_inventory.size()])

func _physics_process(delta: float) -> void:
	##Handle 3D physics processing
	debug_log_timer += delta  # Update debug timer

	_handle_input()
	_apply_ship_rotation(delta)
	_apply_3d_movement(delta)
	_apply_gravity(delta)

	# Move and check collisions
	move_and_slide()

	# Reset Y velocity when hitting floor or ceiling (important for 3D)
	if is_on_floor() or is_on_ceiling():
		velocity.y = 0

	# Handle interactions
	_handle_interactions()

	# Update position tracking for camera
	position_changed.emit(global_position)

func _handle_input() -> void:
	##Handle Mario Kart style steering input
	# Only log periodically or when significant changes occur, not every frame
	var should_log_debug = enable_debug_logs and (debug_log_timer >= debug_log_interval or
		abs(steering_input - last_logged_steering) > 0.5)

	# Reset input values
	steering_input = 0.0
	acceleration_input = 0.0

	# Steering input (A/D keys for ship rotation)
	if Input.is_action_pressed("move_right"):
		steering_input += 1.0  # Steer right
	if Input.is_action_pressed("move_left"):
		steering_input -= 1.0  # Steer left

	# Acceleration input (W/S keys for forward/backward movement)
	if Input.is_action_pressed("move_up"):
		acceleration_input += 1.0  # Accelerate forward
	if Input.is_action_pressed("move_down"):
		acceleration_input -= 1.0  # Reverse/brake

	# Log only when values change significantly or at intervals
	if should_log_debug and (steering_input != 0 or acceleration_input != 0):
		_log_message("PlayerShip3D: Input - Steer: %.2f, Accel: %.2f" % [steering_input, acceleration_input])
		last_logged_steering = steering_input
		last_logged_acceleration = acceleration_input

	# Legacy input vector for backward compatibility (will be removed later)
	input_vector = Vector2(steering_input, -acceleration_input)

	# Reset turning states for animation (now based on steering input)
	is_turning_left = steering_input < -0.1
	is_turning_right = steering_input > 0.1

	# Optional: Handle jump/float for Y-axis movement
	if Input.is_action_just_pressed("collect") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_log_message("PlayerShip3D: Jump/float activated")  # Keep this log as it's event-based

func _apply_3d_movement(delta: float) -> void:
	##Apply Mario Kart style forward/backward movement only
	# Only log when debug is enabled and significant changes occur or at intervals
	var should_log_movement = enable_debug_logs and (debug_log_timer >= debug_log_interval or
		abs(current_velocity - last_logged_velocity) > 5.0)

	# Apply acceleration based on input
	_apply_acceleration(delta, acceleration_input)

	# Apply movement only in ship's facing direction (no lateral movement)
	current_direction = -transform.basis.z.normalized()
	var movement_vector = current_direction * current_velocity

	# Apply to character velocity (preserve Y for gravity)
	velocity.x = movement_vector.x
	velocity.z = movement_vector.z

	# Log only when significant changes occur or at intervals
	if should_log_movement and abs(current_velocity) > 0.1:
		_log_message("PlayerShip3D: Movement - Vel: %.1f, Dir: (%.1f,%.1f,%.1f)" %
			[current_velocity, current_direction.x, current_direction.y, current_direction.z])
		last_logged_velocity = current_velocity

func _apply_acceleration(delta: float, accel_input: float) -> void:
	##Apply Mario Kart style acceleration/deceleration
	# Store previous velocity for change detection
	var prev_velocity = current_velocity

	if accel_input > 0:
		# Forward acceleration
		current_velocity = move_toward(current_velocity, max_forward_speed, acceleration_force * delta)
	elif accel_input < 0:
		# Reverse/braking
		if current_velocity > 0:
			# Braking while moving forward
			current_velocity = move_toward(current_velocity, 0, brake_force * delta)
		else:
			# Reverse acceleration
			current_velocity = move_toward(current_velocity, -max_reverse_speed, acceleration_force * delta)
	else:
		# No input - apply friction
		current_velocity = move_toward(current_velocity, 0, friction_force * delta)

	# Only log significant velocity changes when debug is enabled
	if enable_debug_logs and abs(current_velocity - prev_velocity) > 2.0:
		var action = ""
		if accel_input > 0:
			action = "Accelerating"
		elif accel_input < 0:
			action = "Braking" if prev_velocity > 0 else "Reversing"
		else:
			action = "Friction"
		_log_message("PlayerShip3D: %s - Velocity: %.1f" % [action, current_velocity])

func _apply_ship_rotation(delta: float) -> void:
	##Apply Mario Kart style steering rotation
	_apply_steering(delta)

	# Update ship forward direction for movement
	ship_forward_direction = -transform.basis.z.normalized()

func _apply_steering(delta: float) -> void:
	##Apply Mario Kart style steering based on A/D keys
	if abs(steering_input) > 0.1:
		# Calculate turn speed based on current velocity (slower turning at high speed)
		var velocity_factor = clamp(abs(current_velocity) / max_forward_speed, 0.2, 1.0)
		var effective_turn_speed = lerp(max_turn_speed, turn_speed_at_max_velocity, velocity_factor)

		# Handle reverse turning (slower when moving backward)
		if current_velocity < 0:
			effective_turn_speed *= reverse_turn_multiplier

		# Apply steering rotation around Y-axis (yaw)
		# Note: Negative because positive Y rotation in Godot is counterclockwise (left turn)
		var turn_amount = -steering_input * effective_turn_speed * delta
		rotation.y += deg_to_rad(turn_amount)

		# Update ship animation to show turning
		_update_turning_animation(steering_input)

		# Only log steering when debug is enabled and at intervals or significant changes
		if enable_debug_logs and (debug_log_timer >= debug_log_interval or
			abs(steering_input - last_logged_steering) > 0.3):
			_log_message("PlayerShip3D: Steering - Input: %.2f, Turn: %.1f°" % [steering_input, turn_amount])
			last_logged_steering = steering_input
	else:
		# Not turning - reset animation to straight
		_update_turning_animation(0.0)

	# Reset debug timer when it reaches interval
	if debug_log_timer >= debug_log_interval:
		debug_log_timer = 0.0

func _apply_gravity(delta: float) -> void:
	##Apply gravity for floating/jumping mechanics
	if not is_on_floor():
		velocity.y += gravity * delta

func _handle_interactions() -> void:
	##Handle interaction inputs (collection, NPC interaction, etc.)
	if Input.is_action_just_pressed("collect"):
		_attempt_collection()

	if Input.is_action_just_pressed("interact"):
		_attempt_interaction()

func _attempt_collection() -> void:
	##Attempt to collect nearby debris in 3D
	if not can_collect:
		_log_message("PlayerShip3D: Collection on cooldown")
		return

	if current_inventory.size() >= inventory_capacity:
		_log_message("PlayerShip3D: Inventory full! Cannot collect more debris")
		return

	if nearby_debris.is_empty():
		_log_message("PlayerShip3D: No debris in collection range")
		return

	# Find the closest debris
	var closest_debris = _find_closest_debris()
	if closest_debris:
		_collect_debris_object(closest_debris)

func _find_closest_debris() -> RigidBody3D:
	##Find the closest debris object in 3D range
	var closest_debris: RigidBody3D = null
	var closest_distance = INF

	for debris in nearby_debris:
		if is_instance_valid(debris):
			var distance = global_position.distance_to(debris.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_debris = debris

	return closest_debris

func _collect_debris_object(debris_object: RigidBody3D) -> void:
	##Collect a specific debris object in 3D
	if not is_instance_valid(debris_object):
		return

	# Check if it's a 3D debris object
	var debris_3d = debris_object as DebrisObject3D
	if not debris_3d:
		_log_message("PlayerShip3D: Debris object is not a DebrisObject3D")
		return

	# Get debris data from 3D debris object
	var debris_type = debris_3d.get_debris_type()
	var debris_value = debris_3d.get_debris_value()
	var debris_id = debris_3d.get_debris_id()

	# Network-authoritative collection - send to server for validation
	var zone_main = get_parent()
	if zone_main and zone_main.has_method("get_network_manager"):
		var network_manager = zone_main.get_network_manager()
		if network_manager:
			network_manager.collect_debris(debris_id, debris_type)
			_log_message("PlayerShip3D: Sent debris collection request to network - %s (%s)" % [debris_id, debris_type])

	# Create inventory item (local prediction - server will validate)
	var debris_item = {
		"type": debris_type,
		"value": debris_value,
		"id": debris_id,
		"timestamp": Time.get_unix_time_from_system()
	}

	current_inventory.append(debris_item)
	_log_message("PlayerShip3D: Collected %s (Value: %d) - Inventory: %d/%d" % [debris_type, debris_value, current_inventory.size(), inventory_capacity])

	# Remove from nearby debris list
	nearby_debris.erase(debris_object)

	# Emit signal
	debris_collected.emit(debris_type, debris_value)

	# Sync inventory item with backend API
	if zone_main and zone_main.has_method("get_api_client"):
		var api_client = zone_main.get_api_client()
		if api_client and api_client.has_method("add_inventory_item"):
			api_client.add_inventory_item(debris_item)
			_log_message("PlayerShip3D: Synced inventory item with backend API - %s" % debris_type)
	else:
		_log_message("PlayerShip3D: Warning - Backend API sync not available for inventory item")

	# Trigger debris collection through the debris manager
	if zone_main and zone_main.has_method("get_debris_manager"):
		var debris_manager = zone_main.get_debris_manager()
		if debris_manager:
			debris_manager.collect_debris_3d(debris_3d)
			_log_message("PlayerShip3D: Notified debris manager of collection")

	# Brief collection cooldown
	can_collect = false
	await get_tree().create_timer(collection_cooldown).timeout
	can_collect = true

# Signal handlers for 3D areas
func _on_collection_area_body_entered(body: Node3D) -> void:
	##Handle debris entering collection range in 3D
	var debris_3d = body as DebrisObject3D
	if debris_3d:
		nearby_debris.append(body)
		_log_message("PlayerShip3D: Debris entered 3D collection range - %s" % debris_3d.get_debris_type())

		# Show collection range indicator when debris is nearby
		_update_collection_indicator_visibility()

func _on_collection_area_body_exited(body: Node3D) -> void:
	##Handle debris exiting collection range in 3D
	if body in nearby_debris:
		nearby_debris.erase(body)
		var debris_3d = body as DebrisObject3D
		if debris_3d:
			_log_message("PlayerShip3D: Debris exited 3D collection range - %s" % debris_3d.get_debris_type())

		# Update collection range indicator visibility
		_update_collection_indicator_visibility()

func _update_collection_indicator_visibility() -> void:
	##Update visibility of collection range indicator based on nearby debris
	if collection_indicator:
		var should_show = nearby_debris.size() > 0 and show_collection_indicator
		if collection_indicator.visible != should_show:
			collection_indicator.visible = should_show
			if should_show:
				_log_message("PlayerShip3D: Collection range indicator shown (debris nearby)")
			else:
				_log_message("PlayerShip3D: Collection range indicator hidden (no debris nearby)")

		# Update material color based on debris count
		if collection_material and should_show:
			var alpha = min(0.2 + (nearby_debris.size() * 0.05), 0.5)  # More opaque with more debris
			collection_material.albedo_color.a = alpha

func _on_interaction_area_body_entered(body: Node3D) -> void:
	##Handle NPC entering interaction range in 3D
	if body.is_in_group("npc_hub") or body.collision_layer == 8:
		nearby_npcs.append(body)
		current_npc_hub = body
		can_interact = true

		# Determine hub type
		var hub_type = "trading"
		if body.has_method("get_hub_type"):
			hub_type = body.get_hub_type()
		elif body.name.to_lower().contains("upgrade"):
			hub_type = "upgrade"

		_log_message("PlayerShip3D: Entered NPC hub in 3D - %s" % hub_type)
		npc_hub_entered.emit(hub_type)
		interaction_available.emit(hub_type)

func _on_interaction_area_body_exited(body: Node3D) -> void:
	##Handle NPC exiting interaction range in 3D
	if body in nearby_npcs:
		nearby_npcs.erase(body)
		if current_npc_hub == body:
			current_npc_hub = null
			can_interact = false
			_log_message("PlayerShip3D: Exited NPC hub in 3D")
			npc_hub_exited.emit()
			interaction_unavailable.emit()

func _attempt_interaction() -> void:
	##Attempt to interact with nearby NPCs or objects in 3D
	if not can_interact or not current_npc_hub:
		_log_message("PlayerShip3D: No interaction targets available in 3D")
		return

	# Get hub type
	var hub_type = "trading"
	if current_npc_hub.name.to_lower().contains("upgrade"):
		hub_type = "upgrade"

	_log_message("PlayerShip3D: Interacting with %s hub in 3D" % hub_type)

	# Emit signal to open appropriate interface
	var zone_main = get_parent()
	if zone_main and zone_main.has_method("open_trading_interface"):
		zone_main.open_trading_interface(hub_type)

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)

## Mario Kart steering interface methods for camera controller

func get_current_steering_input() -> float:
	##Get current steering input for camera banking (-1 to 1)
	return steering_input

func get_current_velocity() -> float:
	##Get current forward/backward velocity for camera effects
	return current_velocity

# Player state management methods (same API as 2D version)
func get_player_info() -> Dictionary:
	##Get current player state information
	return {
		"player_id": player_id,
		"position": global_position,
		"inventory": current_inventory,
		"inventory_capacity": inventory_capacity,
		"credits": credits,
		"upgrades": upgrades,
		"speed": speed,
		"nearby_debris_count": nearby_debris.size(),
		"nearby_npcs_count": nearby_npcs.size(),
		"can_interact": can_interact,
		"is_3d": true
	}

func add_credits(amount: int) -> void:
	##Add credits to the player
	credits += amount
	_log_message("PlayerShip3D: Added %d credits - Total: %d" % [amount, credits])

func spend_credits(amount: int) -> bool:
	##Remove credits from the player
	if credits >= amount:
		credits -= amount
		_log_message("PlayerShip3D: Spent %d credits - Remaining: %d" % [amount, credits])
		return true
	else:
		_log_message("PlayerShip3D: Insufficient credits - Need: %d, Have: %d" % [amount, credits])
		return false

func clear_inventory() -> Array[Dictionary]:
	##Clear inventory (used when selling to NPCs)
	var sold_items = current_inventory.duplicate()
	current_inventory.clear()
	_log_message("PlayerShip3D: Inventory cleared - Sold %d items" % sold_items.size())
	return sold_items

func get_inventory_value() -> int:
	##Calculate total value of all items in inventory
	var total_value = 0
	for item in current_inventory:
		total_value += item.value
	return total_value

func apply_upgrade(upgrade_type: String, level: int) -> void:
	##Apply upgrade to player ship
	if upgrade_type in upgrades:
		upgrades[upgrade_type] = level
		_apply_upgrade_effects(upgrade_type, level)
		_log_message("PlayerShip3D: Applied upgrade %s level %d" % [upgrade_type, level])

func _apply_upgrade_effects(upgrade_type: String, level: int) -> void:
	##Apply the effects of an upgrade
	match upgrade_type:
		"speed_boost":
			# FIXED: Much more reasonable speed progression
			# Level 0: 120 (comfortable base), Level 5: 220 (+83% vs old +125%)
			speed = 120.0 + (level * 20.0)  # Base 120, +20 per level (was +50!)
			# Update movement parameters for 3D (Mario Kart style)
			max_forward_speed = speed
			max_reverse_speed = speed * 0.6  # Reverse is 60% of forward speed
			# CRITICAL FIX: Update visual feedback when speed changes (including removal at level 0)
			_update_speed_visual_feedback()
			_log_message("PlayerShip3D: Speed boost applied - Speed: %.1f, Max Forward: %.1f, Max Reverse: %.1f" % [speed, max_forward_speed, max_reverse_speed])
		"inventory_expansion":
			set_inventory_capacity(10 + (level * 5))
			_log_message("PlayerShip3D: Inventory expansion applied - Capacity: %d" % inventory_capacity)
		"collection_efficiency":
			collection_range = 3.0 + (level * 2.0)  # Base 3.0, small upgrades to maintain close collection
			collection_cooldown = max(0.1, 0.5 - (level * 0.05))
			# Update collection area size
			if collection_collision and collection_collision.shape:
				collection_collision.shape.radius = collection_range
			# Update visual indicator size
			if collection_indicator and collection_indicator.mesh:
				collection_indicator.mesh.radius = collection_range
				_log_message("PlayerShip3D: Updated collection range indicator to %.1f units" % collection_range)
			_log_message("PlayerShip3D: Collection efficiency applied - Range: %.1f, Cooldown: %.2fs" % [collection_range, collection_cooldown])
		"zone_access":
			# Set zone access level for future zone system integration
			upgrades["zone_access"] = level
			_log_message("PlayerShip3D: Zone access applied - Level: %d" % level)
		"debris_scanner":
			if level > 0:
				enable_debris_scanner(level)
			else:
				disable_debris_scanner()
			_log_message("PlayerShip3D: Debris scanner applied - Level: %d, Active: %s" % [level, level > 0])
		"cargo_magnet":
			if level > 0:
				enable_cargo_magnet(level)
			else:
				disable_cargo_magnet()
			_log_message("PlayerShip3D: Cargo magnet applied - Level: %d, Active: %s" % [level, level > 0])

	_log_message("PlayerShip3D: Upgrade effects applied - Speed: %.1f, Capacity: %d, Collection Range: %.1f" % [speed, inventory_capacity, collection_range])

# Upgrade support methods for UpgradeSystem
func set_speed(new_speed: float) -> void:
	##Set the player ship speed
	speed = new_speed
	max_forward_speed = new_speed
	max_reverse_speed = new_speed * 0.6

	# Add visual feedback for speed changes
	_update_speed_visual_feedback()

	_log_message("PlayerShip3D: Speed set to %.1f" % speed)

func _update_speed_visual_feedback() -> void:
	##Update visual feedback based on current speed upgrades
	var speed_level = int((speed - 120.0) / 20.0)  # FIXED: Calculate upgrade level with new values (was 200.0/50.0)

	if speed_level > 0:
		_create_speed_boost_effects(speed_level)
	else:
		_remove_speed_boost_effects()

func _create_speed_boost_effects(level: int) -> void:
	##Create visual effects for speed boost upgrades
	_log_message("PlayerShip3D: Creating speed boost visual effects at level %d" % level)

	# Remove existing speed effects
	_remove_speed_boost_effects()

	# Create thrust particle effects
	_create_thrust_particles(level)

	# Create speed indicator
	_create_speed_indicator(level)

	# Add ship trail effect
	_create_ship_trail(level)

func _remove_speed_boost_effects() -> void:
	##Remove all speed boost visual effects
	var thrust_particles = get_node_or_null("ThrustParticles")
	if thrust_particles:
		thrust_particles.queue_free()

	var speed_indicator = get_node_or_null("SpeedIndicator")
	if speed_indicator:
		speed_indicator.queue_free()

	var ship_trail = get_node_or_null("ShipTrail")
	if ship_trail:
		ship_trail.queue_free()

func _create_thrust_particles(level: int) -> void:
	##Create particle effects for ship thrust based on speed level
	var particles = GPUParticles3D.new()
	particles.name = "ThrustParticles"
	particles.emitting = true

	# Create particle material
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 1)  # Thrust backwards
	material.initial_velocity_min = 5.0 + (level * 3.0)
	material.initial_velocity_max = 10.0 + (level * 5.0)
	material.gravity = Vector3.ZERO
	material.scale_min = 0.1
	material.scale_max = 0.3 + (level * 0.1)

	# Color variation based on speed level
	var base_color = Color(0.2, 0.5, 1.0, 0.8)  # Blue thrust
	var boost_color = Color(1.0, 0.3, 0.0, 0.9)  # Orange/red for higher speeds
	var blend_factor = min(level / 5.0, 1.0)
	material.color = base_color.lerp(boost_color, blend_factor)

	material.emission = 50 + (level * 20)  # More particles at higher levels
	particles.process_material = material
	particles.lifetime = 1.0

	# Position behind the ship
	particles.position = Vector3(0, 0, 2)
	add_child(particles)

	_log_message("PlayerShip3D: Thrust particles created for speed level %d" % level)

func _create_speed_indicator(level: int) -> void:
	##Create visual speed indicator around the ship
	var indicator = MeshInstance3D.new()
	indicator.name = "SpeedIndicator"

	# Create ring mesh for speed indicator
	var torus_mesh = TorusMesh.new()
	torus_mesh.inner_radius = 2.5
	torus_mesh.outer_radius = 3.0
	indicator.mesh = torus_mesh

	# Create glowing material
	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.emission_enabled = true

	# Color intensity based on speed level
	var intensity = 0.3 + (level * 0.2)
	var speed_color = Color(0.0, 1.0, 0.5, intensity)  # Green speed indicator
	material.emission = speed_color
	material.albedo_color = Color(0.0, 0.8, 0.4, 0.1)

	indicator.material_override = material
	add_child(indicator)

	# Animate the speed indicator
	var tween = create_tween()
	tween.set_loops()
	var rotation_speed = 1.0 + (level * 0.5)  # Faster rotation for higher speeds
	tween.tween_property(indicator, "rotation_degrees:y", 360.0, 2.0 / rotation_speed)

	_log_message("PlayerShip3D: Speed indicator created for level %d" % level)

func _create_ship_trail(level: int) -> void:
	##Create trailing effect behind the ship when moving fast
	var trail = MeshInstance3D.new()
	trail.name = "ShipTrail"

	# Create trail mesh using a stretched box
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.2, 4.0 + (level * 1.0))  # Longer trail at higher speeds
	trail.mesh = box_mesh

	# Create trail material
	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.emission_enabled = true
	material.emission = Color(0.3, 0.7, 1.0) * (0.3 + level * 0.1)
	material.albedo_color = Color(0.2, 0.5, 0.8, 0.2 + level * 0.05)

	trail.material_override = material
	trail.position = Vector3(0, 0, 3)  # Position behind ship
	add_child(trail)

	# Only show trail when moving
	trail.visible = false

	_log_message("PlayerShip3D: Ship trail created for level %d" % level)

func set_inventory_capacity(new_capacity: int) -> void:
	##Set the inventory capacity
	var old_capacity = inventory_capacity
	inventory_capacity = new_capacity

	# Add visual feedback for inventory expansion
	if new_capacity > old_capacity:
		_show_inventory_expansion_effects(old_capacity, new_capacity)

	_log_message("PlayerShip3D: Inventory capacity set to %d" % inventory_capacity)

func _show_inventory_expansion_effects(old_capacity: int, new_capacity: int) -> void:
	##Show visual effects when inventory capacity increases
	_log_message("PlayerShip3D: Showing inventory expansion effects from %d to %d" % [old_capacity, new_capacity])

	# Create expansion visual effect
	_create_inventory_expansion_visual(new_capacity)

	# Emit signal for UI updates
	inventory_expanded.emit(old_capacity, new_capacity)

	# Create capacity indicator
	_update_inventory_capacity_indicator(new_capacity)

func _create_inventory_expansion_visual(capacity: int) -> void:
	##Create visual effect for inventory expansion
	var expansion_effect = MeshInstance3D.new()
	expansion_effect.name = "InventoryExpansionEffect"

	# Create expanding sphere mesh
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 2.0
	sphere_mesh.height = 4.0
	expansion_effect.mesh = sphere_mesh

	# Create expansion material
	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.emission_enabled = true
	material.emission = Color(0.8, 0.4, 1.0)  # Purple expansion effect
	material.albedo_color = Color(0.6, 0.3, 0.8, 0.3)
	expansion_effect.material_override = material

	add_child(expansion_effect)

	# Animate expansion effect
	var tween = create_tween()
	tween.parallel().tween_property(expansion_effect, "scale", Vector3(3.0, 3.0, 3.0), 1.5)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 1.5)
	tween.tween_callback(expansion_effect.queue_free)

	_log_message("PlayerShip3D: Inventory expansion visual effect created")

func _update_inventory_capacity_indicator(capacity: int) -> void:
	##Update or create inventory capacity indicator
	# Remove existing indicator
	var existing_indicator = get_node_or_null("InventoryIndicator")
	if existing_indicator:
		existing_indicator.queue_free()

	# Create new capacity indicator
	var indicator = Node3D.new()
	indicator.name = "InventoryIndicator"

	# Create capacity level visualization (stacked boxes)
	var capacity_level = int((capacity - 10) / 5)  # Calculate upgrade level
	for level in range(capacity_level + 1):
		var box = MeshInstance3D.new()
		box.name = "CapacityBox%d" % level

		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(0.5, 0.3, 0.5)
		box.mesh = box_mesh

		# Create capacity material
		var material = StandardMaterial3D.new()
		material.emission_enabled = true
		var intensity = 0.3 + (level * 0.1)
		material.emission = Color(0.3, 0.8, 0.3, intensity)  # Green capacity indicator
		material.albedo_color = Color(0.2, 0.6, 0.2, 0.7)
		box.material_override = material

		# Stack boxes vertically
		box.position = Vector3(3, -1 + (level * 0.4), 0)
		indicator.add_child(box)

	add_child(indicator)
	_log_message("PlayerShip3D: Inventory capacity indicator updated for capacity %d" % capacity)

func set_collection_range(new_range: float) -> void:
	##Set the collection range
	var old_range = collection_range
	collection_range = new_range

	# Update collection area size
	if collection_collision and collection_collision.shape:
		collection_collision.shape.radius = collection_range

	# Add visual feedback for collection efficiency improvements
	if new_range > old_range:
		_show_collection_efficiency_effects(old_range, new_range)

	# Update collection range indicator
	_update_collection_range_indicator()

	_log_message("PlayerShip3D: Collection range set to %.1f" % collection_range)

func _show_collection_efficiency_effects(old_range: float, new_range: float) -> void:
	##Show visual effects when collection efficiency increases
	_log_message("PlayerShip3D: Showing collection efficiency effects from %.1f to %.1f" % [old_range, new_range])

	# Create efficiency boost visual effect
	_create_collection_efficiency_visual()

	# Create collection pulse effect
	_create_collection_pulse_effect()

func _create_collection_efficiency_visual() -> void:
	##Create visual effect for collection efficiency upgrade
	var efficiency_effect = MeshInstance3D.new()
	efficiency_effect.name = "CollectionEfficiencyEffect"

	# Create expanding torus mesh for efficiency visualization
	var torus_mesh = TorusMesh.new()
	torus_mesh.inner_radius = collection_range * 0.8
	torus_mesh.outer_radius = collection_range
	efficiency_effect.mesh = torus_mesh

	# Create efficiency material
	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.emission_enabled = true
	material.emission = Color(0.2, 0.8, 1.0)  # Cyan collection efficiency effect
	material.albedo_color = Color(0.1, 0.6, 0.8, 0.4)
	efficiency_effect.material_override = material

	add_child(efficiency_effect)

	# Animate efficiency effect
	var tween = create_tween()
	tween.parallel().tween_property(efficiency_effect, "scale", Vector3(1.5, 1.5, 1.5), 2.0)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 2.0)
	tween.tween_callback(efficiency_effect.queue_free)

	_log_message("PlayerShip3D: Collection efficiency visual effect created")

func _create_collection_pulse_effect() -> void:
	##Create pulsing effect showing collection range
	var pulse_effect = MeshInstance3D.new()
	pulse_effect.name = "CollectionPulseEffect"

	# Create sphere mesh for pulse
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = collection_range
	sphere_mesh.height = collection_range * 2
	pulse_effect.mesh = sphere_mesh

	# Create pulse material
	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.emission_enabled = true
	material.emission = Color(0.0, 1.0, 0.5, 0.3)  # Green pulse effect
	material.albedo_color = Color(0.0, 0.8, 0.4, 0.1)
	pulse_effect.material_override = material

	add_child(pulse_effect)

	# Animate pulse effect (3 pulses)
	var tween = create_tween()
	for i in range(3):
		tween.parallel().tween_property(pulse_effect, "scale", Vector3(1.3, 1.3, 1.3), 0.5)
		tween.parallel().tween_property(pulse_effect, "scale", Vector3(0.7, 0.7, 0.7), 0.5)

	tween.tween_callback(pulse_effect.queue_free)

	_log_message("PlayerShip3D: Collection pulse effect created")

func _update_collection_range_indicator() -> void:
	##Update the collection range indicator based on current range
	if not collection_indicator:
		return

	# Update indicator size to match current collection range
	if collection_indicator.mesh:
		collection_indicator.mesh.radius = collection_range
		_log_message("PlayerShip3D: Updated collection range indicator to %.1f units" % collection_range)

	# Update indicator visibility and intensity based on nearby debris
	_update_collection_indicator_visibility()

	# Update material intensity based on collection efficiency level
	var efficiency_level = int((collection_range - 3.0) / 2.0)  # Calculate efficiency level
	if collection_material and efficiency_level > 0:
		var base_intensity = 0.15
		var level_bonus = efficiency_level * 0.05
		collection_material.albedo_color.a = base_intensity + level_bonus
		collection_material.emission_energy = 0.5 + (efficiency_level * 0.2)
		_log_message("PlayerShip3D: Collection indicator intensity updated for level %d" % efficiency_level)

func set_zone_access(access_level: int) -> void:
	##Set the zone access level
	upgrades["zone_access"] = access_level
	_log_message("PlayerShip3D: Zone access level set to %d" % access_level)

func enable_debris_scanner(level: int = 1) -> void:
	##Enable debris scanner with visual effects (level-based activation)
	is_scanner_active = true
	_log_message("PlayerShip3D: Debris scanner activated at level %d" % level)

	# Remove existing scanner effect if it exists
	var existing_scanner = get_node_or_null("ScannerEffect")
	if existing_scanner:
		existing_scanner.queue_free()

	# Implement debris scanner visual effects
	_create_scanner_visual_effects(level)

	# Start scanning for debris periodically (or update existing timer)
	var scanner_timers = get_tree().get_nodes_in_group("scanner_timer")
	if scanner_timers.is_empty():
		var scanner_timer = Timer.new()
		scanner_timer.name = "ScannerTimer"
		scanner_timer.wait_time = max(0.5, 2.0 - (level * 0.3))  # Faster scanning at higher levels
		scanner_timer.timeout.connect(_perform_debris_scan)
		scanner_timer.add_to_group("scanner_timer")
		add_child(scanner_timer)
		scanner_timer.start()
		_log_message("PlayerShip3D: Scanner timer created with %.1fs interval" % scanner_timer.wait_time)
	else:
		# Update existing timer for improved frequency
		var scanner_timer = scanner_timers[0] as Timer
		scanner_timer.wait_time = max(0.5, 2.0 - (level * 0.3))
		_log_message("PlayerShip3D: Scanner timer updated to %.1fs interval" % scanner_timer.wait_time)

func disable_debris_scanner() -> void:
	##Disable debris scanner and remove visual effects
	is_scanner_active = false
	_log_message("PlayerShip3D: Debris scanner deactivated")

	# Remove scanner visual effects
	var scanner_effect = get_node_or_null("ScannerEffect")
	if scanner_effect:
		scanner_effect.queue_free()

	# Remove scanner timer
	var scanner_timers = get_tree().get_nodes_in_group("scanner_timer")
	for timer in scanner_timers:
		timer.queue_free()

func _create_scanner_visual_effects(level: int = 1) -> void:
	##Create visual effects for debris scanner (level-based intensity)
	_log_message("PlayerShip3D: Creating scanner visual effects at level %d" % level)

	# Create scanner pulse effect
	var scanner_effect = MeshInstance3D.new()
	scanner_effect.name = "ScannerEffect"
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 15.0 + (level * 10.0)  # Larger range at higher levels
	sphere_mesh.height = sphere_mesh.radius * 2.0
	scanner_effect.mesh = sphere_mesh

	# Create scanner material with transparency and animation
	var scanner_material = StandardMaterial3D.new()
	var intensity = 0.1 + (level * 0.05)  # Brighter at higher levels
	scanner_material.albedo_color = Color(0.0, 1.0, 1.0, intensity)  # Cyan with level-based transparency
	scanner_material.flags_transparent = true
	scanner_material.grow = true
	scanner_material.emission_enabled = true
	scanner_material.emission = Color(0.0, 0.6 + (level * 0.1), 0.6 + (level * 0.1))  # Brighter emission at higher levels
	scanner_effect.material_override = scanner_material

	add_child(scanner_effect)

	# Animate scanner pulse (faster at higher levels)
	var pulse_duration = max(0.5, 1.2 - (level * 0.2))
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(scanner_effect, "scale", Vector3(1.3, 1.3, 1.3), pulse_duration)
	tween.tween_property(scanner_effect, "scale", Vector3(0.7, 0.7, 0.7), pulse_duration)

func enable_cargo_magnet(level: int = 1) -> void:
	##Enable cargo magnet for auto-collection (level-based effectiveness)
	is_magnet_active = true
	magnet_range = 10.0 + (level * 5.0)  # Increased range based on level
	_log_message("PlayerShip3D: Cargo magnet activated at level %d with range %.1f" % [level, magnet_range])

	# Remove existing magnet timer if it exists
	var magnet_timers = get_tree().get_nodes_in_group("magnet_timer")
	for timer in magnet_timers:
		timer.queue_free()

	# Implement cargo magnet auto-collection
	_start_magnet_auto_collection(level)

	# Create visual effect for magnet
	_create_magnet_visual_effects(level)

func disable_cargo_magnet() -> void:
	##Disable cargo magnet and remove visual effects
	is_magnet_active = false
	magnet_range = 0.0
	_log_message("PlayerShip3D: Cargo magnet deactivated")

	# Remove magnet visual effects
	var magnet_effect = get_node_or_null("MagnetEffect")
	if magnet_effect:
		magnet_effect.queue_free()

	# Remove magnet timer
	var magnet_timers = get_tree().get_nodes_in_group("magnet_timer")
	for timer in magnet_timers:
		timer.queue_free()

func _create_magnet_visual_effects(level: int = 1) -> void:
	##Create visual effects for cargo magnet
	_log_message("PlayerShip3D: Creating magnet visual effects at level %d" % level)

	# Remove existing magnet effect if it exists
	var existing_magnet = get_node_or_null("MagnetEffect")
	if existing_magnet:
		existing_magnet.queue_free()

	# Create magnet field visualization
	var magnet_effect = MeshInstance3D.new()
	magnet_effect.name = "MagnetEffect"
	var torus_mesh = TorusMesh.new()
	torus_mesh.inner_radius = magnet_range * 0.8
	torus_mesh.outer_radius = magnet_range
	magnet_effect.mesh = torus_mesh

	# Create magnet material
	var magnet_material = StandardMaterial3D.new()
	var intensity = 0.1 + (level * 0.03)
	magnet_material.albedo_color = Color(1.0, 0.5, 0.0, intensity)  # Orange magnetic field
	magnet_material.flags_transparent = true
	magnet_material.emission_enabled = true
	magnet_material.emission = Color(1.0, 0.3, 0.0)
	magnet_effect.material_override = magnet_material

	add_child(magnet_effect)

	# Animate magnet field rotation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(magnet_effect, "rotation_degrees:y", 360.0, 3.0)

func _start_magnet_auto_collection(level: int = 1) -> void:
	##Start automatic debris collection when magnet is active (level-based frequency)
	var collection_frequency = max(0.2, 0.5 - (level * 0.1))  # Faster collection at higher levels

	var magnet_timer = Timer.new()
	magnet_timer.name = "MagnetTimer"
	magnet_timer.wait_time = collection_frequency
	magnet_timer.timeout.connect(_auto_collect_debris)
	magnet_timer.add_to_group("magnet_timer")
	add_child(magnet_timer)
	magnet_timer.start()

	_log_message("PlayerShip3D: Magnet auto-collection started with %.2fs frequency" % collection_frequency)

func _perform_debris_scan() -> void:
	##Perform debris scan and highlight detected objects
	if not is_scanner_active:
		return

	_log_message("PlayerShip3D: Performing debris scan")

	# Get all debris objects in scanner range
	var debris_in_range = []
	for body in collection_area.get_overlapping_bodies():
		if body.is_in_group("debris_3d"):
			debris_in_range.append(body)

	# Highlight detected debris
	for debris in debris_in_range:
		_highlight_debris_object(debris)

func _highlight_debris_object(debris: Node3D) -> void:
	##Add visual highlight to detected debris
	if not debris or not debris.has_method("get_sprite_3d"):
		return

	var sprite = debris.get_sprite_3d()
	if sprite:
		# Add temporary highlight effect
		var original_modulate = sprite.modulate
		sprite.modulate = Color(1.5, 1.5, 1.0, 1.0)  # Bright yellow highlight

		# Remove highlight after 2 seconds
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", original_modulate, 2.0)

func _auto_collect_debris() -> void:
	##Automatically collect debris within magnet range
	if not is_magnet_active:
		return

	var debris_collected = 0
	var max_per_cycle = 2 + (int(magnet_range / 15.0))  # More collection at higher levels
	for body in collection_area.get_overlapping_bodies():
		if body.is_in_group("debris_3d") and debris_collected < max_per_cycle:
			var distance = global_position.distance_to(body.global_position)
			if distance <= magnet_range:
				_collect_debris_object(body)
				debris_collected += 1

	if debris_collected > 0:
		_log_message("PlayerShip3D: Magnet auto-collected %d debris objects" % debris_collected)

# Utility methods
func get_debris_in_range() -> Array[RigidBody3D]:
	##Get all debris currently in collection range
	return nearby_debris.duplicate()

func get_closest_debris() -> RigidBody3D:
	##Get the closest debris object in range
	return _find_closest_debris()

func get_nearby_npcs() -> Array[Node3D]:
	##Get all NPCs currently in interaction range
	return nearby_npcs.duplicate()

func can_interact_with_npcs() -> bool:
	##Check if player can interact with any nearby NPCs
	return can_interact and current_npc_hub != null

func teleport_to(new_position: Vector3) -> void:
	##Teleport player to a specific 3D position
	global_position = new_position
	_log_message("PlayerShip3D: Teleported to %s" % new_position)
	position_changed.emit(global_position)

func _load_ship_animation_textures() -> void:
	##Load all ship animation frame textures into memory for fast switching
	_log_message("PlayerShip3D: Loading ship animation textures...")

	# Resize array to hold all frames (1-127, but we use 0-based indexing)
	ship_textures.resize(FRAME_COUNT + 1)

	# Load frames from 98 to 127 (the range we actually use)
	for i in range(98, FRAME_COUNT + 1):
		var texture_path = "res://assets/sprites/ships/animation_frames/ship_turn_frame_%03d.png" % i
		var texture = load(texture_path) as Texture2D
		if texture:
			ship_textures[i] = texture
		else:
			_log_message("PlayerShip3D: Failed to load texture: %s" % texture_path)

	_log_message("PlayerShip3D: Loaded ship animation textures (frames 98-127)")

func _set_ship_frame(frame_number: int) -> void:
	##Set the ship sprite to a specific frame
	if frame_number < 98 or frame_number > FRAME_COUNT:
		_log_message("PlayerShip3D: Invalid frame number: %d" % frame_number)
		return

	if sprite_3d and ship_textures.size() > frame_number and ship_textures[frame_number]:
		sprite_3d.texture = ship_textures[frame_number]
		current_frame = frame_number
	else:
		_log_message("PlayerShip3D: Could not set frame %d" % frame_number)

func _update_turning_animation(steer_input: float) -> void:
	##Update ship turning animation based on steering input (Mario Kart style)
	var target_frame = DEFAULT_FRAME  # Frame 113 (straight)

	if abs(steer_input) > 0.1:
		if steer_input < 0:
			# Turning left - blend based on steering intensity
			var blend_factor = clamp(abs(steer_input), 0.0, 1.0)
			target_frame = int(lerp(DEFAULT_FRAME, LEFT_TURN_END, blend_factor))
			_log_message("PlayerShip3D: Left turn animation - Steer: %.2f, Frame: %d" % [steer_input, target_frame])
		else:
			# Turning right - blend based on steering intensity
			var blend_factor = clamp(abs(steer_input), 0.0, 1.0)
			target_frame = int(lerp(DEFAULT_FRAME, RIGHT_TURN_END, blend_factor))
			_log_message("PlayerShip3D: Right turn animation - Steer: %.2f, Frame: %d" % [steer_input, target_frame])
	else:
		target_frame = DEFAULT_FRAME  # Frame 113 (straight)

	# Smoothly animate to target frame if different from current
	if target_frame != current_frame:
		_animate_to_frame(target_frame)

func _update_ship_visual_rotation() -> void:
	##Update ship visual rotation to match actual rotation (Mario Kart style)
	# Convert rotation to frame index (0-126 range)
	var normalized_rotation = fmod(rotation.y + PI, 2 * PI) / (2 * PI)  # 0-1
	var target_frame = int(normalized_rotation * (FRAME_COUNT - 1)) + 1  # 1-127

	# Clamp to valid range
	target_frame = clamp(target_frame, 1, FRAME_COUNT)

	# Update sprite frame if different
	if target_frame != current_frame:
		_set_ship_frame(target_frame)
		_log_message("PlayerShip3D: Visual rotation update - Rotation: %.2f degrees, Frame: %d" % [rad_to_deg(rotation.y), target_frame])

func _animate_to_frame(target_frame: int) -> void:
	##Smoothly animate from current frame to target frame
	if animation_tween and animation_tween.is_valid():
		animation_tween.kill()

	animation_tween = create_tween()
	animation_tween.set_ease(Tween.EASE_OUT)
	animation_tween.set_trans(Tween.TRANS_CUBIC)

	var frame_difference = abs(target_frame - current_frame)
	var animation_duration = frame_difference / ANIMATION_SPEED

	# Animate through the frames
	animation_tween.tween_method(_set_ship_frame_interpolated, current_frame, target_frame, animation_duration)

func _set_ship_frame_interpolated(frame: float) -> void:
	##Set ship frame with interpolation support for smooth animation
	var rounded_frame = int(round(frame))
	_set_ship_frame(rounded_frame)
