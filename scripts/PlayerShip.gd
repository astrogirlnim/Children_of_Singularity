# PlayerShip.gd
# Player ship controller for Children of the Singularity
# Handles player movement, debris collection, and basic interactions

class_name PlayerShip
extends CharacterBody2D

## Signal emitted when debris is collected
signal debris_collected(debris_type: String, value: int)

## Signal emitted when player position changes (for camera tracking)
signal position_changed(new_position: Vector2)

## Signal emitted when player enters interaction range
signal interaction_available(interaction_type: String)

## Signal emitted when player exits interaction range
signal interaction_unavailable()

## Signal emitted when player enters NPC hub area
signal npc_hub_entered(hub_type: String)

## Signal emitted when player exits NPC hub area
signal npc_hub_exited()

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var collection_area: Area2D = $CollectionArea
@onready var collection_collision: CollisionShape2D = $CollectionArea/CollectionCollision
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_collision: CollisionShape2D = $InteractionArea/InteractionCollision

## Sprite resources for directional movement
var sprite_left: Texture2D = preload("res://assets/sprites/ships/ship_sprite_left_updated.png")
var sprite_normal: Texture2D = preload("res://assets/sprites/ships/ship_right_vibrant.png")

# Movement properties
var speed: float = 200.0
var acceleration: float = 800.0
var friction: float = 600.0
var max_speed: float = 300.0

# Player state
var player_id: String = "550e8400-e29b-41d4-a716-446655440000"
var current_inventory: Array[Dictionary] = []
var inventory_capacity: int = 10
var credits: int = 0
var upgrades: Dictionary = {}

# Interaction state
var can_collect: bool = true
var collection_range: float = 80.0
var nearby_debris: Array[RigidBody2D] = []
var collection_cooldown: float = 0.5

# NPC interaction state
var nearby_npcs: Array[Node2D] = []
var current_npc_hub: Node2D = null
var can_interact: bool = false

## Scanner and Magnet states
var is_scanner_active: bool = false
var is_magnet_active: bool = false
var magnet_range: float = 15.0

func _ready() -> void:
	_log_message("PlayerShip: Initializing player ship")
	_setup_player_visuals()
	_setup_collision()
	_setup_collection_area()
	_setup_interaction_area()
	_initialize_player_state()
	_log_message("PlayerShip: Player ship ready for gameplay")

func _setup_player_visuals() -> void:
	##Set up visual appearance for the player ship
	_log_message("PlayerShip: Setting up player ship visuals")

	# Use preloaded sprite texture instead of programmatic generation
	if sprite_2d and sprite_normal:
		sprite_2d.texture = sprite_normal
		_log_message("PlayerShip: Right-facing vibrant ship sprite loaded")

func _setup_collision() -> void:
	##Set up collision detection for the player ship
	_log_message("PlayerShip: Setting up collision detection")

	# Create a basic collision shape if one doesn't exist
	if collision_shape_2d and not collision_shape_2d.shape:
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(32, 32)
		collision_shape_2d.shape = rect_shape
		_log_message("PlayerShip: Created default collision shape")

func _setup_collection_area() -> void:
	##Set up collection area for debris detection
	_log_message("PlayerShip: Setting up collection area")

	# Create collection area if it doesn't exist
	if not collection_area:
		collection_area = Area2D.new()
		collection_area.name = "CollectionArea"
		collection_area.collision_layer = 0  # Don't collide with anything
		collection_area.collision_mask = 4   # Detect debris (layer 4)
		add_child(collection_area)

		# Create collision shape for collection area
		collection_collision = CollisionShape2D.new()
		collection_collision.name = "CollectionCollision"
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = collection_range
		collection_collision.shape = circle_shape
		collection_area.add_child(collection_collision)

		_log_message("PlayerShip: Created collection area")

	# Connect signals
	if collection_area:
		collection_area.body_entered.connect(_on_collection_area_body_entered)
		collection_area.body_exited.connect(_on_collection_area_body_exited)
		_log_message("PlayerShip: Collection area signals connected")

func _setup_interaction_area() -> void:
	##Set up interaction area for NPC detection
	_log_message("PlayerShip: Setting up interaction area")

	# Create interaction area if it doesn't exist
	if not interaction_area:
		interaction_area = Area2D.new()
		interaction_area.name = "InteractionArea"
		interaction_area.collision_layer = 0  # Don't collide with anything
		interaction_area.collision_mask = 8   # Detect NPCs (layer 8)
		add_child(interaction_area)

		# Create collision shape for interaction area
		interaction_collision = CollisionShape2D.new()
		interaction_collision.name = "InteractionCollision"
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = collection_range
		interaction_collision.shape = circle_shape
		interaction_area.add_child(interaction_collision)

		_log_message("PlayerShip: Created interaction area")

	# Connect signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
		_log_message("PlayerShip: Interaction area signals connected")

func _initialize_player_state() -> void:
	##Initialize player state and inventory
	_log_message("PlayerShip: Initializing player state")
	current_inventory.clear()
	upgrades = {
		"speed_boost": 0,
		"inventory_expansion": 0,
		"collection_efficiency": 0,
		"zone_access": 1
	}
	_log_message("PlayerShip: Player state initialized - Credits: %d, Capacity: %d/%d" % [credits, current_inventory.size(), inventory_capacity])

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_interactions()
	_update_position_tracking()

func _handle_movement(delta: float) -> void:
	##Handle player movement input and physics
	var input_vector = Vector2.ZERO
	var is_moving_left = false

	# Get input from all movement actions
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
		is_moving_left = true
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1

	# Update sprite based on movement direction
	_update_sprite_direction(is_moving_left)

	# Normalize diagonal movement
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	# Apply movement
	move_and_slide()

func _handle_interactions() -> void:
	##Handle interaction inputs (collection, NPC interaction, etc.)
	if Input.is_action_just_pressed("collect"):
		_attempt_collection()

	if Input.is_action_just_pressed("interact"):
		_attempt_interaction()

func _update_position_tracking() -> void:
	##Update position tracking for camera and other systems
	position_changed.emit(global_position)

func _attempt_collection() -> void:
	##Attempt to collect nearby debris
	if not can_collect:
		_log_message("PlayerShip: Collection on cooldown")
		return

	if current_inventory.size() >= inventory_capacity:
		_log_message("PlayerShip: Inventory full! Cannot collect more debris")
		return

	if nearby_debris.is_empty():
		_log_message("PlayerShip: No debris in collection range")
		return

	# Find the closest debris
	var closest_debris = _find_closest_debris()
	if closest_debris:
		_collect_debris_object(closest_debris)

func _find_closest_debris() -> RigidBody2D:
	##Find the closest debris object in range
	var closest_debris: RigidBody2D = null
	var closest_distance = INF

	for debris in nearby_debris:
		if is_instance_valid(debris):
			var distance = global_position.distance_to(debris.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_debris = debris

	return closest_debris

func _collect_debris_object(debris_object: RigidBody2D) -> void:
	##Collect a specific debris object
	if not is_instance_valid(debris_object):
		return

	# Get debris data from metadata
	var debris_type = debris_object.get_meta("debris_type", "unknown")
	var debris_value = debris_object.get_meta("debris_value", 0)
	var debris_id = debris_object.get_meta("debris_id", "unknown")

	# Network-authoritative collection - send to server for validation
	var zone_main = get_parent()
	if zone_main and zone_main.has_method("get_network_manager"):
		var network_manager = zone_main.get_network_manager()
		if network_manager:
			network_manager.collect_debris(debris_id, debris_type)
			_log_message("PlayerShip: Sent debris collection request to network - %s (%s)" % [debris_id, debris_type])

	# Create inventory item (local prediction - server will validate)
	var debris_item = {
		"type": debris_type,
		"value": debris_value,
		"id": debris_id,
		"timestamp": Time.get_unix_time_from_system()
	}

	current_inventory.append(debris_item)
	_log_message("PlayerShip: Collected %s (Value: %d) - Inventory: %d/%d" % [debris_type, debris_value, current_inventory.size(), inventory_capacity])

	# Remove from nearby debris list
	nearby_debris.erase(debris_object)

	# Emit signal
	debris_collected.emit(debris_type, debris_value)

	# Remove the debris object from the zone
	if zone_main and zone_main.has_method("remove_debris"):
		zone_main.remove_debris(debris_object)

	# Brief collection cooldown
	can_collect = false
	await get_tree().create_timer(collection_cooldown).timeout
	can_collect = true

func _on_collection_area_body_entered(body: Node2D) -> void:
	##Handle debris entering collection range
	if body.is_in_group("debris") or body.has_meta("debris_type"):
		nearby_debris.append(body)
		_log_message("PlayerShip: Debris entered collection range - %s" % body.get_meta("debris_type", "unknown"))

func _on_collection_area_body_exited(body: Node2D) -> void:
	##Handle debris exiting collection range
	if body in nearby_debris:
		nearby_debris.erase(body)
		_log_message("PlayerShip: Debris exited collection range - %s" % body.get_meta("debris_type", "unknown"))

func _on_interaction_area_body_entered(body: Node2D) -> void:
	##Handle NPC entering interaction range
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

		_log_message("PlayerShip: Entered NPC hub - %s" % hub_type)
		npc_hub_entered.emit(hub_type)
		interaction_available.emit(hub_type)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	##Handle NPC exiting interaction range
	if body in nearby_npcs:
		nearby_npcs.erase(body)
		if current_npc_hub == body:
			current_npc_hub = null
			can_interact = false
			_log_message("PlayerShip: Exited NPC hub")
			npc_hub_exited.emit()
			interaction_unavailable.emit()

func _attempt_interaction() -> void:
	##Attempt to interact with nearby NPCs or objects
	if not can_interact or not current_npc_hub:
		_log_message("PlayerShip: No interaction targets available")
		return

	# Get hub type
	var hub_type = "trading"
	if current_npc_hub.name.to_lower().contains("upgrade"):
		hub_type = "upgrade"

	_log_message("PlayerShip: Interacting with %s hub" % hub_type)

	# Emit signal to open appropriate interface
	var zone_main = get_parent()
	if zone_main and zone_main.has_method("open_trading_interface"):
		zone_main.open_trading_interface(hub_type)

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)

## Get current player state information
func get_player_info() -> Dictionary:
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
		"can_interact": can_interact
	}

## Add credits to the player
func add_credits(amount: int) -> void:
	credits += amount
	_log_message("PlayerShip: Added %d credits - Total: %d" % [amount, credits])

## Remove credits from the player
func spend_credits(amount: int) -> bool:
	if credits >= amount:
		credits -= amount
		_log_message("PlayerShip: Spent %d credits - Remaining: %d" % [amount, credits])
		return true
	else:
		_log_message("PlayerShip: Insufficient credits - Need: %d, Have: %d" % [amount, credits])
		return false

## Clear inventory (used when selling to NPCs)
func clear_inventory() -> Array[Dictionary]:
	var sold_items = current_inventory.duplicate()
	current_inventory.clear()
	_log_message("PlayerShip: Inventory cleared - Sold %d items" % sold_items.size())
	return sold_items

## Get total value of current inventory
func get_inventory_value() -> int:
	##Calculate total value of all items in inventory
	var total_value = 0
	for item in current_inventory:
		total_value += item.value
	return total_value

## Apply upgrade to player ship
func apply_upgrade(upgrade_type: String, level: int) -> void:
	if upgrade_type in upgrades:
		upgrades[upgrade_type] = level
		_apply_upgrade_effects(upgrade_type, level)
		_log_message("PlayerShip: Applied upgrade %s level %d" % [upgrade_type, level])

func _apply_upgrade_effects(upgrade_type: String, level: int) -> void:
	##Apply the effects of an upgrade
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
		"debris_scanner":
			if level > 0:
				enable_debris_scanner()
				_log_message("PlayerShip: Debris scanner upgrade applied - Level %d" % level)
			else:
				is_scanner_active = false
				_log_message("PlayerShip: Debris scanner deactivated")
		"cargo_magnet":
			if level > 0:
				enable_cargo_magnet()
				_log_message("PlayerShip: Cargo magnet upgrade applied - Level %d" % level)
			else:
				is_magnet_active = false
				magnet_range = 0.0
				_log_message("PlayerShip: Cargo magnet deactivated")

	_log_message("PlayerShip: Upgrade effects applied - Speed: %.1f, Capacity: %d, Collection Range: %.1f, Scanner: %s, Magnet: %s" % [speed, inventory_capacity, collection_range, str(is_scanner_active), str(is_magnet_active)])

## Upgrade support methods for UpgradeSystem
func set_speed(new_speed: float) -> void:
	##Set the player ship speed
	speed = new_speed
	_log_message("PlayerShip: Speed set to %.1f" % speed)

func set_inventory_capacity(new_capacity: int) -> void:
	##Set the inventory capacity
	inventory_capacity = new_capacity
	_log_message("PlayerShip: Inventory capacity set to %d" % inventory_capacity)

func set_collection_range(new_range: float) -> void:
	##Set the collection range
	collection_range = new_range
	# Update collection area size
	if collection_collision and collection_collision.shape:
		collection_collision.shape.radius = collection_range
	_log_message("PlayerShip: Collection range set to %.1f" % collection_range)

func set_zone_access(access_level: int) -> void:
	##Set the zone access level
	upgrades["zone_access"] = access_level
	_log_message("PlayerShip: Zone access level set to %d" % access_level)

func enable_debris_scanner() -> void:
	##Enable debris scanner with visual effects
	is_scanner_active = true
	_log_message("PlayerShip: Debris scanner activated")

	# Implement debris scanner visual effects for 2D
	_create_scanner_visual_effects_2d()

	# Start scanning for debris periodically
	if not get_tree().get_nodes_in_group("scanner_timer_2d"):
		var scanner_timer = Timer.new()
		scanner_timer.name = "ScannerTimer2D"
		scanner_timer.wait_time = 2.0  # Scan every 2 seconds
		scanner_timer.timeout.connect(_perform_debris_scan_2d)
		scanner_timer.add_to_group("scanner_timer_2d")
		add_child(scanner_timer)
		scanner_timer.start()

func _create_scanner_visual_effects_2d() -> void:
	##Create 2D visual effects for debris scanner
	_log_message("PlayerShip: Creating 2D scanner visual effects")

	# Create scanner pulse effect using Node2D and Polygon2D
	var scanner_effect = Node2D.new()
	scanner_effect.name = "ScannerEffect2D"

	var circle_polygon = Polygon2D.new()
	circle_polygon.name = "ScannerCircle"

	# Create circle points for scanner range
	var circle_points = PackedVector2Array()
	var radius = 25.0  # Scanner range in 2D
	for i in range(32):  # 32 points for smooth circle
		var angle = (i / 32.0) * 2 * PI
		circle_points.append(Vector2(cos(angle) * radius, sin(angle) * radius))

	circle_polygon.polygon = circle_points
	circle_polygon.color = Color(0.0, 1.0, 1.0, 0.2)  # Cyan with transparency

	scanner_effect.add_child(circle_polygon)
	add_child(scanner_effect)

	# Animate scanner pulse
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(scanner_effect, "scale", Vector2(1.2, 1.2), 1.0)
	tween.tween_property(scanner_effect, "scale", Vector2(0.8, 0.8), 1.0)

func _perform_debris_scan_2d() -> void:
	##Perform 2D debris scan and highlight detected objects
	if not is_scanner_active:
		return

	_log_message("PlayerShip: Performing 2D debris scan")

	# Get all debris objects in scanner range
	var debris_in_range = []
	for body in collection_area.get_overlapping_bodies():
		if body.is_in_group("debris"):
			debris_in_range.append(body)

	# Highlight detected debris
	for debris in debris_in_range:
		_highlight_debris_object_2d(debris)

func _highlight_debris_object_2d(debris: Node2D) -> void:
	##Add visual highlight to detected debris in 2D
	if not debris or not debris.has_method("get_sprite"):
		return

	var sprite = debris.get_sprite()
	if sprite:
		# Add temporary highlight effect
		var original_modulate = sprite.modulate
		sprite.modulate = Color(1.5, 1.5, 1.0, 1.0)  # Bright yellow highlight

		# Remove highlight after 2 seconds
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", original_modulate, 2.0)

func enable_cargo_magnet() -> void:
	##Enable cargo magnet for auto-collection
	is_magnet_active = true
	magnet_range = 15.0  # Increased collection range
	_log_message("PlayerShip: Cargo magnet activated with range %.1f" % magnet_range)

	# Implement cargo magnet auto-collection for 2D
	_start_magnet_auto_collection_2d()

func _start_magnet_auto_collection_2d() -> void:
	##Start automatic debris collection when magnet is active in 2D
	if not get_tree().get_nodes_in_group("magnet_timer_2d"):
		var magnet_timer = Timer.new()
		magnet_timer.name = "MagnetTimer2D"
		magnet_timer.wait_time = 0.5  # Check for auto-collection every 0.5 seconds
		magnet_timer.timeout.connect(_auto_collect_debris_2d)
		magnet_timer.add_to_group("magnet_timer_2d")
		add_child(magnet_timer)
		magnet_timer.start()

func _auto_collect_debris_2d() -> void:
	##Automatically collect debris within magnet range in 2D
	if not is_magnet_active:
		return

	var debris_collected = 0
	for body in collection_area.get_overlapping_bodies():
		if body.is_in_group("debris") and debris_collected < 3:  # Limit to 3 per cycle
			var distance = global_position.distance_to(body.global_position)
			if distance <= magnet_range:
				_collect_debris_object(body)
				debris_collected += 1

	if debris_collected > 0:
		_log_message("PlayerShip: Magnet auto-collected %d debris objects" % debris_collected)

## Get debris in collection range
func get_debris_in_range() -> Array[RigidBody2D]:
	##Get all debris currently in collection range
	return nearby_debris.duplicate()

## Get the closest debris object
func get_closest_debris() -> RigidBody2D:
	##Get the closest debris object in range
	return _find_closest_debris()

## Get nearby NPCs
func get_nearby_npcs() -> Array[Node2D]:
	##Get all NPCs currently in interaction range
	return nearby_npcs.duplicate()

## Check if player can interact with NPCs
func can_interact_with_npcs() -> bool:
	##Check if player can interact with any nearby NPCs
	return can_interact and current_npc_hub != null

## Teleport player to a specific position
func teleport_to(new_position: Vector2) -> void:
	global_position = new_position
	_log_message("PlayerShip: Teleported to %s" % new_position)
	position_changed.emit(global_position)

func _update_sprite_direction(is_moving_left: bool) -> void:
	##Update sprite texture based on movement direction
	if not sprite_2d:
		return

	if is_moving_left:
		if sprite_2d.texture != sprite_left:
			sprite_2d.texture = sprite_left
			_log_message("PlayerShip: Switched to left-facing sprite")
	else:
		if sprite_2d.texture != sprite_normal:
			sprite_2d.texture = sprite_normal
			_log_message("PlayerShip: Switched to normal sprite")
