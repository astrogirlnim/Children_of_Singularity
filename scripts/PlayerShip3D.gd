# PlayerShip3D.gd
# 3D version of the player ship controller for Children of the Singularity
# Handles player movement, debris collection, and basic interactions in 3D space

class_name PlayerShip3D
extends CharacterBody3D

## Movement constants
const SPEED = 10.0
const ACCELERATION = 40.0
const FRICTION = 20.0
const JUMP_VELOCITY = 8.0  # For floating/hovering mechanics

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

## Node references
@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var collection_area: Area3D = $CollectionArea
@onready var collection_collision: CollisionShape3D = $CollectionArea/CollectionCollision
@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_collision: CollisionShape3D = $InteractionArea/InteractionCollision

## Sprite resources for directional movement
var sprite_normal: Texture2D = preload("res://assets/sprites/ships/ship_right_vibrant.png")
var sprite_left: Texture2D = preload("res://assets/sprites/ships/ship_sprite_left_updated.png")

## Movement state
var input_vector: Vector2 = Vector2.ZERO
var movement_velocity: Vector3 = Vector3.ZERO

## Player state (same as 2D version)
var player_id: String = "player_001"
var current_inventory: Array[Dictionary] = []
var inventory_capacity: int = 10
var credits: int = 0
var upgrades: Dictionary = {}

## Interaction state
var can_collect: bool = true
var collection_range: float = 80.0
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
var max_speed: float = 300.0

func _ready() -> void:
	_log_message("PlayerShip3D: Initializing 3D player ship")
	_setup_3d_components()
	_setup_collision_detection()
	_setup_collection_area()
	_setup_interaction_area()
	_initialize_player_state()
	_log_message("PlayerShip3D: 3D player ship ready for gameplay")

func _setup_3d_components() -> void:
	"""Set up 3D-specific components"""
	_log_message("PlayerShip3D: Setting up 3D components")

	# Configure sprite to always face camera (billboard mode)
	if sprite_3d:
		sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

		# Note: Ship sprite texture is loaded from the scene file (player_ship.png)
		# No need to create programmatic texture - using imported sprite instead
		_log_message("PlayerShip3D: 3D sprite texture created with billboard mode")

	# Configure floor settings (important for 3D physics)
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(45)
	floor_block_on_wall = false

func _setup_collision_detection() -> void:
	"""Set up collision detection for the 3D player ship"""
	_log_message("PlayerShip3D: Setting up 3D collision detection")

	if collision_shape:
		# Create collision shape wider than sprite (critical for 3D)
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(4.0, 2.0, 4.0)  # Wide on X and Z, thin on Y
		collision_shape.shape = box_shape
		_log_message("PlayerShip3D: Created wide collision box (4x2x4)")

func _setup_collection_area() -> void:
	"""Set up 3D collection area for debris detection"""
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

func _setup_interaction_area() -> void:
	"""Set up 3D interaction area for NPC detection"""
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
	"""Initialize player state and inventory"""
	_log_message("PlayerShip3D: Initializing 3D player state")
	current_inventory.clear()
	upgrades = {
		"speed_boost": 0,
		"inventory_expansion": 0,
		"collection_efficiency": 0,
		"zone_access": 1
	}
	_log_message("PlayerShip3D: 3D player state initialized - Credits: %d, Capacity: %d/%d" % [credits, current_inventory.size(), inventory_capacity])

func _physics_process(delta: float) -> void:
	"""Handle 3D physics processing"""
	_handle_input()
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
	"""Handle input for 3D movement"""
	input_vector = Vector2.ZERO
	var is_moving_left = false

	# Get input from all movement actions
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
		is_moving_left = true
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1  # This will map to Z in 3D
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1  # This will map to Z in 3D

	# Update sprite based on movement direction
	_update_sprite_direction(is_moving_left)

	# Normalize diagonal movement
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	# Optional: Handle jump/float for Y-axis movement
	if Input.is_action_just_pressed("collect") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _apply_3d_movement(delta: float) -> void:
	"""Apply 3D movement on X-Z plane"""
	# Calculate desired velocity on X-Z plane (Y input maps to Z axis)
	var desired_velocity = Vector3(
		input_vector.x * SPEED,
		0,  # Y will be handled by gravity
		input_vector.y * SPEED  # Y input maps to Z axis movement
	)

	# Apply acceleration or friction
	if input_vector.length() > 0:
		movement_velocity = movement_velocity.move_toward(
			desired_velocity,
			ACCELERATION * delta
		)
	else:
		movement_velocity = movement_velocity.move_toward(
			Vector3.ZERO,
			FRICTION * delta
		)

	# Apply to character velocity (preserve Y for gravity)
	velocity.x = movement_velocity.x
	velocity.z = movement_velocity.z

func _apply_gravity(delta: float) -> void:
	"""Apply gravity for floating/jumping mechanics"""
	if not is_on_floor():
		velocity.y += gravity * delta

func _handle_interactions() -> void:
	"""Handle interaction inputs (collection, NPC interaction, etc.)"""
	if Input.is_action_just_pressed("collect"):
		_attempt_collection()

	if Input.is_action_just_pressed("interact"):
		_attempt_interaction()

func _attempt_collection() -> void:
	"""Attempt to collect nearby debris in 3D"""
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
	"""Find the closest debris object in 3D range"""
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
	"""Collect a specific debris object in 3D"""
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
	"""Handle debris entering collection range in 3D"""
	var debris_3d = body as DebrisObject3D
	if debris_3d:
		nearby_debris.append(body)
		_log_message("PlayerShip3D: Debris entered 3D collection range - %s" % debris_3d.get_debris_type())

func _on_collection_area_body_exited(body: Node3D) -> void:
	"""Handle debris exiting collection range in 3D"""
	if body in nearby_debris:
		nearby_debris.erase(body)
		var debris_3d = body as DebrisObject3D
		if debris_3d:
			_log_message("PlayerShip3D: Debris exited 3D collection range - %s" % debris_3d.get_debris_type())

func _on_interaction_area_body_entered(body: Node3D) -> void:
	"""Handle NPC entering interaction range in 3D"""
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
	"""Handle NPC exiting interaction range in 3D"""
	if body in nearby_npcs:
		nearby_npcs.erase(body)
		if current_npc_hub == body:
			current_npc_hub = null
			can_interact = false
			_log_message("PlayerShip3D: Exited NPC hub in 3D")
			npc_hub_exited.emit()
			interaction_unavailable.emit()

func _attempt_interaction() -> void:
	"""Attempt to interact with nearby NPCs or objects in 3D"""
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
	"""Log a message with timestamp"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)

# Player state management methods (same API as 2D version)
func get_player_info() -> Dictionary:
	"""Get current player state information"""
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
	"""Add credits to the player"""
	credits += amount
	_log_message("PlayerShip3D: Added %d credits - Total: %d" % [amount, credits])

func spend_credits(amount: int) -> bool:
	"""Remove credits from the player"""
	if credits >= amount:
		credits -= amount
		_log_message("PlayerShip3D: Spent %d credits - Remaining: %d" % [amount, credits])
		return true
	else:
		_log_message("PlayerShip3D: Insufficient credits - Need: %d, Have: %d" % [amount, credits])
		return false

func clear_inventory() -> Array[Dictionary]:
	"""Clear inventory (used when selling to NPCs)"""
	var sold_items = current_inventory.duplicate()
	current_inventory.clear()
	_log_message("PlayerShip3D: Inventory cleared - Sold %d items" % sold_items.size())
	return sold_items

func get_inventory_value() -> int:
	"""Calculate total value of all items in inventory"""
	var total_value = 0
	for item in current_inventory:
		total_value += item.value
	return total_value

func apply_upgrade(upgrade_type: String, level: int) -> void:
	"""Apply upgrade to player ship"""
	if upgrade_type in upgrades:
		upgrades[upgrade_type] = level
		_apply_upgrade_effects(upgrade_type, level)
		_log_message("PlayerShip3D: Applied upgrade %s level %d" % [upgrade_type, level])

func _apply_upgrade_effects(upgrade_type: String, level: int) -> void:
	"""Apply the effects of an upgrade"""
	match upgrade_type:
		"speed_boost":
			speed = 200.0 + (level * 50.0)
		"inventory_expansion":
			inventory_capacity = 10 + (level * 5)
		"collection_efficiency":
			collection_range = 80.0 + (level * 20.0)
			collection_cooldown = max(0.1, 0.5 - (level * 0.05))
			# Update collection area size
			if collection_collision and collection_collision.shape:
				collection_collision.shape.radius = collection_range
		"zone_access":
			# This will be handled by the zone system
			pass

	_log_message("PlayerShip3D: Upgrade effects applied - Speed: %.1f, Capacity: %d, Collection Range: %.1f" % [speed, inventory_capacity, collection_range])

# Upgrade support methods for UpgradeSystem
func set_speed(new_speed: float) -> void:
	"""Set the player ship speed"""
	speed = new_speed
	_log_message("PlayerShip3D: Speed set to %.1f" % speed)

func set_inventory_capacity(new_capacity: int) -> void:
	"""Set the inventory capacity"""
	inventory_capacity = new_capacity
	_log_message("PlayerShip3D: Inventory capacity set to %d" % inventory_capacity)

func set_collection_range(new_range: float) -> void:
	"""Set the collection range"""
	collection_range = new_range
	# Update collection area size
	if collection_collision and collection_collision.shape:
		collection_collision.shape.radius = collection_range
	_log_message("PlayerShip3D: Collection range set to %.1f" % collection_range)

func set_zone_access(access_level: int) -> void:
	"""Set the zone access level"""
	upgrades["zone_access"] = access_level
	_log_message("PlayerShip3D: Zone access level set to %d" % access_level)

func enable_debris_scanner(enabled: bool) -> void:
	"""Enable or disable debris scanner"""
	# TODO: Implement debris scanner visual effects
	_log_message("PlayerShip3D: Debris scanner %s" % ("enabled" if enabled else "disabled"))

func enable_cargo_magnet(enabled: bool) -> void:
	"""Enable or disable cargo magnet"""
	# TODO: Implement cargo magnet auto-collection
	_log_message("PlayerShip3D: Cargo magnet %s" % ("enabled" if enabled else "disabled"))

# Utility methods
func get_debris_in_range() -> Array[RigidBody3D]:
	"""Get all debris currently in collection range"""
	return nearby_debris.duplicate()

func get_closest_debris() -> RigidBody3D:
	"""Get the closest debris object in range"""
	return _find_closest_debris()

func get_nearby_npcs() -> Array[Node3D]:
	"""Get all NPCs currently in interaction range"""
	return nearby_npcs.duplicate()

func can_interact_with_npcs() -> bool:
	"""Check if player can interact with any nearby NPCs"""
	return can_interact and current_npc_hub != null

func teleport_to(new_position: Vector3) -> void:
	"""Teleport player to a specific 3D position"""
	global_position = new_position
	_log_message("PlayerShip3D: Teleported to %s" % new_position)
	position_changed.emit(global_position)

func _update_sprite_direction(is_moving_left: bool) -> void:
	"""Update sprite texture based on movement direction"""
	if not sprite_3d:
		return

	if is_moving_left:
		if sprite_3d.texture != sprite_left:
			sprite_3d.texture = sprite_left
			_log_message("PlayerShip3D: Switched to left-facing sprite")
	else:
		if sprite_3d.texture != sprite_normal:
			sprite_3d.texture = sprite_normal
			_log_message("PlayerShip3D: Switched to normal sprite")
