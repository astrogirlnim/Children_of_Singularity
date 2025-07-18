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

## Signal emitted when inventory capacity is expanded
signal inventory_expanded(old_capacity: int, new_capacity: int)

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
			max_speed = speed * 1.5  # Allow burst speed above base speed
			# CRITICAL FIX: Update visual feedback when speed changes (including removal at level 0)
			_update_speed_visual_feedback()
			_log_message("PlayerShip: Speed boost applied - Speed: %.1f, Max Speed: %.1f" % [speed, max_speed])
		"inventory_expansion":
			var old_capacity = inventory_capacity
			inventory_capacity = 10 + (level * 5)
			_log_message("PlayerShip: Inventory expansion applied - Old Capacity: %d, New Capacity: %d" % [old_capacity, inventory_capacity])
			inventory_expanded.emit(old_capacity, inventory_capacity)
		"collection_efficiency":
			collection_range = 80.0 + (level * 20.0)
			collection_cooldown = max(0.1, 0.5 - (level * 0.05))
			# Update collection area size
			if collection_collision and collection_collision.shape:
				collection_collision.shape.radius = collection_range
			_log_message("PlayerShip: Collection efficiency applied - Range: %.1f, Cooldown: %.2fs" % [collection_range, collection_cooldown])
		"zone_access":
			# Set zone access level for future zone system integration
			upgrades["zone_access"] = level
			_log_message("PlayerShip: Zone access applied - Level: %d" % level)
		"debris_scanner":
			if level > 0:
				enable_debris_scanner(level)
			else:
				disable_debris_scanner()
			_log_message("PlayerShip: Debris scanner applied - Level: %d, Active: %s" % [level, level > 0])
		"cargo_magnet":
			if level > 0:
				enable_cargo_magnet(level)
			else:
				disable_cargo_magnet()
			_log_message("PlayerShip: Cargo magnet applied - Level: %d, Active: %s" % [level, level > 0])

	_log_message("PlayerShip: Upgrade effects applied - Speed: %.1f, Capacity: %d, Collection Range: %.1f" % [speed, inventory_capacity, collection_range])

## Upgrade support methods for UpgradeSystem
func set_speed(new_speed: float) -> void:
	##Set the player ship speed
	speed = new_speed
	max_speed = new_speed * 1.5  # Allow burst speed above base speed

	# Add visual feedback for speed changes
	_update_speed_visual_feedback()

	_log_message("PlayerShip: Speed set to %.1f" % speed)

func _update_speed_visual_feedback() -> void:
	##Update visual feedback based on current speed upgrades for 2D
	var speed_level = int((speed - 200.0) / 50.0)  # Calculate upgrade level based on speed

	if speed_level > 0:
		_create_speed_boost_effects_2d(speed_level)
	else:
		_remove_speed_boost_effects_2d()

func _create_speed_boost_effects_2d(level: int) -> void:
	##Create 2D visual effects for speed boost upgrades
	_log_message("PlayerShip: Creating 2D speed boost visual effects at level %d" % level)

	# Remove existing speed effects
	_remove_speed_boost_effects_2d()

	# Create thrust particle effects for 2D
	_create_thrust_particles_2d(level)

	# Create speed indicator for 2D
	_create_speed_indicator_2d(level)

	# Add ship trail effect for 2D
	_create_ship_trail_2d(level)

func _remove_speed_boost_effects_2d() -> void:
	##Remove all 2D speed boost visual effects
	var thrust_particles = get_node_or_null("ThrustParticles2D")
	if thrust_particles:
		thrust_particles.queue_free()

	var speed_indicator = get_node_or_null("SpeedIndicator2D")
	if speed_indicator:
		speed_indicator.queue_free()

	var ship_trail = get_node_or_null("ShipTrail2D")
	if ship_trail:
		ship_trail.queue_free()

func _create_thrust_particles_2d(level: int) -> void:
	##Create 2D particle effects for ship thrust based on speed level
	var particles = GPUParticles2D.new()
	particles.name = "ThrustParticles2D"
	particles.emitting = true

	# Create particle material for 2D
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)  # Thrust backwards in 2D
	material.initial_velocity_min = 20.0 + (level * 15.0)
	material.initial_velocity_max = 40.0 + (level * 25.0)
	material.gravity = Vector3.ZERO
	material.scale_min = 0.3
	material.scale_max = 0.8 + (level * 0.2)

	# Color variation based on speed level
	var base_color = Color(0.2, 0.5, 1.0, 0.8)  # Blue thrust
	var boost_color = Color(1.0, 0.3, 0.0, 0.9)  # Orange/red for higher speeds
	var blend_factor = min(level / 5.0, 1.0)
	material.color = base_color.lerp(boost_color, blend_factor)

	material.emission = 30 + (level * 15)  # More particles at higher levels
	particles.process_material = material
	particles.lifetime = 1.2

	# Position behind the ship in 2D
	particles.position = Vector2(0, 25)
	add_child(particles)

	_log_message("PlayerShip: 2D thrust particles created for speed level %d" % level)

func _create_speed_indicator_2d(level: int) -> void:
	##Create 2D visual speed indicator around the ship
	var indicator = Node2D.new()
	indicator.name = "SpeedIndicator2D"

	# Create multiple ring polygons for layered effect
	for ring in range(2):
		var ring_polygon = Polygon2D.new()
		ring_polygon.name = "SpeedRing%d" % ring

		var ring_points = PackedVector2Array()
		var radius = 25.0 + (ring * 8.0) + (level * 5.0)
		for i in range(16):  # 16 points for speed ring
			var angle = (i / 16.0) * 2 * PI
			ring_points.append(Vector2(cos(angle) * radius, sin(angle) * radius))

		ring_polygon.polygon = ring_points

		# Color intensity based on speed level and ring
		var intensity = (0.2 + (level * 0.1)) * (1.0 - ring * 0.4)
		var speed_color = Color(0.0, 1.0, 0.5, intensity)  # Green speed indicator
		ring_polygon.color = speed_color

		indicator.add_child(ring_polygon)

	add_child(indicator)

	# Animate the speed indicator
	var tween = create_tween()
	tween.set_loops()
	var rotation_speed = 1.0 + (level * 0.5)  # Faster rotation for higher speeds
	tween.tween_property(indicator, "rotation", 2 * PI, 3.0 / rotation_speed)

	_log_message("PlayerShip: 2D speed indicator created for level %d" % level)

func _create_ship_trail_2d(level: int) -> void:
	##Create 2D trailing effect behind the ship when moving fast
	var trail = Node2D.new()
	trail.name = "ShipTrail2D"

	# Create trail using line2D for smooth trail effect
	var trail_line = Line2D.new()
	trail_line.name = "TrailLine"

	# Configure trail appearance
	trail_line.width = 3.0 + (level * 1.5)
	trail_line.default_color = Color(0.3, 0.7, 1.0, 0.6 + level * 0.1)
	trail_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH

	# Add gradient for fading effect
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.3, 0.7, 1.0, 0.8 + level * 0.1))
	gradient.add_point(1.0, Color(0.1, 0.3, 0.5, 0.0))

	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	trail_line.texture = gradient_texture

	trail.add_child(trail_line)
	add_child(trail)

	# Start with empty trail
	trail_line.clear_points()
	trail.visible = false

	_log_message("PlayerShip: 2D ship trail created for level %d" % level)

func set_inventory_capacity(new_capacity: int) -> void:
	##Set the inventory capacity
	var old_capacity = inventory_capacity
	inventory_capacity = new_capacity

	# Add visual feedback for inventory expansion
	if new_capacity > old_capacity:
		_show_inventory_expansion_effects_2d(old_capacity, new_capacity)

	_log_message("PlayerShip: Inventory capacity set to %d" % inventory_capacity)

func _show_inventory_expansion_effects_2d(old_capacity: int, new_capacity: int) -> void:
	##Show 2D visual effects when inventory capacity increases
	_log_message("PlayerShip: Showing 2D inventory expansion effects from %d to %d" % [old_capacity, new_capacity])

	# Create expansion visual effect
	_create_inventory_expansion_visual_2d(new_capacity)

	# Emit signal for UI updates
	inventory_expanded.emit(old_capacity, new_capacity)

	# Create capacity indicator
	_update_inventory_capacity_indicator_2d(new_capacity)

func _create_inventory_expansion_visual_2d(capacity: int) -> void:
	##Create 2D visual effect for inventory expansion
	var expansion_effect = Node2D.new()
	expansion_effect.name = "InventoryExpansionEffect2D"

	# Create expanding circle effect using Polygon2D
	var expansion_circle = Polygon2D.new()
	expansion_circle.name = "ExpansionCircle"

	# Create circle points for expansion
	var circle_points = PackedVector2Array()
	var radius = 30.0
	for i in range(32):
		var angle = (i / 32.0) * 2 * PI
		circle_points.append(Vector2(cos(angle) * radius, sin(angle) * radius))

	expansion_circle.polygon = circle_points
	expansion_circle.color = Color(0.8, 0.4, 1.0, 0.5)  # Purple expansion effect

	expansion_effect.add_child(expansion_circle)
	add_child(expansion_effect)

	# Animate expansion effect
	var tween = create_tween()
	tween.parallel().tween_property(expansion_effect, "scale", Vector2(4.0, 4.0), 1.5)
	tween.parallel().tween_property(expansion_circle, "color:a", 0.0, 1.5)
	tween.tween_callback(expansion_effect.queue_free)

	_log_message("PlayerShip: 2D inventory expansion visual effect created")

func _update_inventory_capacity_indicator_2d(capacity: int) -> void:
	##Update or create 2D inventory capacity indicator
	# Remove existing indicator
	var existing_indicator = get_node_or_null("InventoryIndicator2D")
	if existing_indicator:
		existing_indicator.queue_free()

	# Create new capacity indicator
	var indicator = Node2D.new()
	indicator.name = "InventoryIndicator2D"

	# Create capacity level visualization (stacked rectangles)
	var capacity_level = int((capacity - 10) / 5)  # Calculate upgrade level
	for level in range(capacity_level + 1):
		var rect = Polygon2D.new()
		rect.name = "CapacityRect%d" % level

		# Create rectangle points
		var rect_size = Vector2(8, 6)
		var rect_points = PackedVector2Array([
			Vector2(-rect_size.x/2, -rect_size.y/2),
			Vector2(rect_size.x/2, -rect_size.y/2),
			Vector2(rect_size.x/2, rect_size.y/2),
			Vector2(-rect_size.x/2, rect_size.y/2)
		])
		rect.polygon = rect_points

		# Color based on level
		var intensity = 0.5 + (level * 0.2)
		rect.color = Color(0.3, 0.8, 0.3, intensity)  # Green capacity indicator

		# Stack rectangles horizontally on the right side of ship
		rect.position = Vector2(25 + (level * 10), 0)
		indicator.add_child(rect)

	add_child(indicator)
	_log_message("PlayerShip: 2D inventory capacity indicator updated for capacity %d" % capacity)

func set_collection_range(new_range: float) -> void:
	##Set the collection range
	var old_range = collection_range
	collection_range = new_range

	# Update collection area size
	if collection_collision and collection_collision.shape:
		collection_collision.shape.radius = collection_range

	# Add visual feedback for collection efficiency improvements
	if new_range > old_range:
		_show_collection_efficiency_effects_2d(old_range, new_range)

	# Update collection range indicator
	_update_collection_range_indicator_2d()

	_log_message("PlayerShip: Collection range set to %.1f" % collection_range)

func _show_collection_efficiency_effects_2d(old_range: float, new_range: float) -> void:
	##Show 2D visual effects when collection efficiency increases
	_log_message("PlayerShip: Showing 2D collection efficiency effects from %.1f to %.1f" % [old_range, new_range])

	# Create efficiency boost visual effect
	_create_collection_efficiency_visual_2d()

	# Create collection pulse effect
	_create_collection_pulse_effect_2d()

func _create_collection_efficiency_visual_2d() -> void:
	##Create 2D visual effect for collection efficiency upgrade
	var efficiency_effect = Node2D.new()
	efficiency_effect.name = "CollectionEfficiencyEffect2D"

	# Create expanding ring effect
	var efficiency_ring = Polygon2D.new()
	efficiency_ring.name = "EfficiencyRing"

	# Create ring points for efficiency visualization
	var ring_points = PackedVector2Array()
	var ring_radius = collection_range * 0.9
	for i in range(32):
		var angle = (i / 32.0) * 2 * PI
		ring_points.append(Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius))

	efficiency_ring.polygon = ring_points
	efficiency_ring.color = Color(0.2, 0.8, 1.0, 0.4)  # Cyan collection efficiency effect

	efficiency_effect.add_child(efficiency_ring)
	add_child(efficiency_effect)

	# Animate efficiency effect
	var tween = create_tween()
	tween.parallel().tween_property(efficiency_effect, "scale", Vector2(1.5, 1.5), 2.0)
	tween.parallel().tween_property(efficiency_ring, "color:a", 0.0, 2.0)
	tween.tween_callback(efficiency_effect.queue_free)

	_log_message("PlayerShip: 2D collection efficiency visual effect created")

func _create_collection_pulse_effect_2d() -> void:
	##Create 2D pulsing effect showing collection range
	var pulse_effect = Node2D.new()
	pulse_effect.name = "CollectionPulseEffect2D"

	# Create circle for pulse
	var pulse_circle = Polygon2D.new()
	pulse_circle.name = "PulseCircle"

	var circle_points = PackedVector2Array()
	for i in range(24):
		var angle = (i / 24.0) * 2 * PI
		circle_points.append(Vector2(cos(angle) * collection_range, sin(angle) * collection_range))

	pulse_circle.polygon = circle_points
	pulse_circle.color = Color(0.0, 1.0, 0.5, 0.3)  # Green pulse effect

	pulse_effect.add_child(pulse_circle)
	add_child(pulse_effect)

	# Animate pulse effect (3 pulses)
	var tween = create_tween()
	for i in range(3):
		tween.parallel().tween_property(pulse_effect, "scale", Vector2(1.3, 1.3), 0.5)
		tween.parallel().tween_property(pulse_effect, "scale", Vector2(0.7, 0.7), 0.5)

	tween.tween_callback(pulse_effect.queue_free)

	_log_message("PlayerShip: 2D collection pulse effect created")

func _update_collection_range_indicator_2d() -> void:
	##Update the 2D collection range indicator based on current range
	# Remove existing collection range indicator
	var existing_range_indicator = get_node_or_null("CollectionRangeIndicator2D")
	if existing_range_indicator:
		existing_range_indicator.queue_free()

	# Create new range indicator
	var range_indicator = Node2D.new()
	range_indicator.name = "CollectionRangeIndicator2D"

	# Create range circle
	var range_circle = Polygon2D.new()
	range_circle.name = "RangeCircle"

	var circle_points = PackedVector2Array()
	for i in range(32):
		var angle = (i / 32.0) * 2 * PI
		circle_points.append(Vector2(cos(angle) * collection_range, sin(angle) * collection_range))

	range_circle.polygon = circle_points

	# Color intensity based on collection efficiency level
	var efficiency_level = int((collection_range - 80.0) / 20.0)  # Calculate efficiency level for 2D
	var base_intensity = 0.1
	var level_bonus = max(0, efficiency_level) * 0.03
	range_circle.color = Color(0.0, 0.8, 0.4, base_intensity + level_bonus)  # Green range indicator

	range_indicator.add_child(range_circle)
	add_child(range_indicator)

	# Only show when there's debris nearby or efficiency is upgraded
	range_indicator.visible = (nearby_debris.size() > 0) or (efficiency_level > 0)

	_log_message("PlayerShip: 2D collection range indicator updated for range %.1f (level %d)" % [collection_range, efficiency_level])

func set_zone_access(access_level: int) -> void:
	##Set the zone access level
	upgrades["zone_access"] = access_level
	_log_message("PlayerShip: Zone access level set to %d" % access_level)

func enable_debris_scanner(level: int = 1) -> void:
	##Enable debris scanner with visual effects (level-based activation for 2D)
	is_scanner_active = true
	_log_message("PlayerShip: Debris scanner activated at level %d" % level)

	# Remove existing scanner effect if it exists
	var existing_scanner = get_node_or_null("ScannerEffect2D")
	if existing_scanner:
		existing_scanner.queue_free()

	# Implement debris scanner visual effects for 2D
	_create_scanner_visual_effects_2d(level)

	# Start scanning for debris periodically (or update existing timer)
	var scanner_timers = get_tree().get_nodes_in_group("scanner_timer_2d")
	if scanner_timers.is_empty():
		var scanner_timer = Timer.new()
		scanner_timer.name = "ScannerTimer2D"
		scanner_timer.wait_time = max(0.5, 2.0 - (level * 0.3))  # Faster scanning at higher levels
		scanner_timer.timeout.connect(_perform_debris_scan_2d)
		scanner_timer.add_to_group("scanner_timer_2d")
		add_child(scanner_timer)
		scanner_timer.start()
		_log_message("PlayerShip: Scanner timer created with %.1fs interval" % scanner_timer.wait_time)
	else:
		# Update existing timer for improved frequency
		var scanner_timer = scanner_timers[0] as Timer
		scanner_timer.wait_time = max(0.5, 2.0 - (level * 0.3))
		_log_message("PlayerShip: Scanner timer updated to %.1fs interval" % scanner_timer.wait_time)

func disable_debris_scanner() -> void:
	##Disable debris scanner and remove visual effects for 2D
	is_scanner_active = false
	_log_message("PlayerShip: Debris scanner deactivated")

	# Remove scanner visual effects
	var scanner_effect = get_node_or_null("ScannerEffect2D")
	if scanner_effect:
		scanner_effect.queue_free()

	# Remove scanner timer
	var scanner_timers = get_tree().get_nodes_in_group("scanner_timer_2d")
	for timer in scanner_timers:
		timer.queue_free()

func _create_scanner_visual_effects_2d(level: int = 1) -> void:
	##Create 2D visual effects for debris scanner (level-based intensity)
	_log_message("PlayerShip: Creating 2D scanner visual effects at level %d" % level)

	# Create scanner pulse effect using Node2D and Polygon2D
	var scanner_effect = Node2D.new()
	scanner_effect.name = "ScannerEffect2D"

	var circle_polygon = Polygon2D.new()
	circle_polygon.name = "ScannerCircle"

	# Create circle points for scanner range (larger at higher levels)
	var circle_points = PackedVector2Array()
	var radius = 20.0 + (level * 15.0)  # Scanner range in 2D scales with level
	for i in range(32):  # 32 points for smooth circle
		var angle = (i / 32.0) * 2 * PI
		circle_points.append(Vector2(cos(angle) * radius, sin(angle) * radius))

	circle_polygon.polygon = circle_points
	var intensity = 0.1 + (level * 0.05)  # Brighter at higher levels
	circle_polygon.color = Color(0.0, 1.0, 1.0, intensity)  # Cyan with level-based transparency

	scanner_effect.add_child(circle_polygon)
	add_child(scanner_effect)

	# Animate scanner pulse (faster at higher levels)
	var pulse_duration = max(0.5, 1.2 - (level * 0.2))
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(scanner_effect, "scale", Vector2(1.3, 1.3), pulse_duration)
	tween.tween_property(scanner_effect, "scale", Vector2(0.7, 0.7), pulse_duration)

func enable_cargo_magnet(level: int = 1) -> void:
	##Enable cargo magnet for auto-collection (level-based effectiveness for 2D)
	is_magnet_active = true
	magnet_range = 10.0 + (level * 8.0)  # Increased range based on level (different scaling for 2D)
	_log_message("PlayerShip: Cargo magnet activated at level %d with range %.1f" % [level, magnet_range])

	# Remove existing magnet timer if it exists
	var magnet_timers = get_tree().get_nodes_in_group("magnet_timer_2d")
	for timer in magnet_timers:
		timer.queue_free()

	# Implement cargo magnet auto-collection for 2D
	_start_magnet_auto_collection_2d(level)

	# Create visual effect for magnet
	_create_magnet_visual_effects_2d(level)

func disable_cargo_magnet() -> void:
	##Disable cargo magnet and remove visual effects for 2D
	is_magnet_active = false
	magnet_range = 0.0
	_log_message("PlayerShip: Cargo magnet deactivated")

	# Remove magnet visual effects
	var magnet_effect = get_node_or_null("MagnetEffect2D")
	if magnet_effect:
		magnet_effect.queue_free()

	# Remove magnet timer
	var magnet_timers = get_tree().get_nodes_in_group("magnet_timer_2d")
	for timer in magnet_timers:
		timer.queue_free()

func _create_magnet_visual_effects_2d(level: int = 1) -> void:
	##Create 2D visual effects for cargo magnet
	_log_message("PlayerShip: Creating 2D magnet visual effects at level %d" % level)

	# Remove existing magnet effect if it exists
	var existing_magnet = get_node_or_null("MagnetEffect2D")
	if existing_magnet:
		existing_magnet.queue_free()

	# Create magnet field visualization using multiple circles
	var magnet_effect = Node2D.new()
	magnet_effect.name = "MagnetEffect2D"

	# Create concentric circles for magnetic field effect
	for ring in range(3):
		var ring_polygon = Polygon2D.new()
		ring_polygon.name = "MagnetRing%d" % ring

		var ring_points = PackedVector2Array()
		var ring_radius = magnet_range * (0.4 + ring * 0.3)
		for i in range(24):  # 24 points for each ring
			var angle = (i / 24.0) * 2 * PI
			ring_points.append(Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius))

		ring_polygon.polygon = ring_points
		var ring_intensity = (0.08 + (level * 0.02)) * (1.0 - ring * 0.3)  # Fade outer rings
		ring_polygon.color = Color(1.0, 0.5, 0.0, ring_intensity)  # Orange magnetic field

		magnet_effect.add_child(ring_polygon)

	add_child(magnet_effect)

	# Animate magnet field rotation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(magnet_effect, "rotation", 2 * PI, 4.0)

func _start_magnet_auto_collection_2d(level: int = 1) -> void:
	##Start automatic debris collection when magnet is active in 2D (level-based frequency)
	var collection_frequency = max(0.2, 0.5 - (level * 0.1))  # Faster collection at higher levels

	var magnet_timer = Timer.new()
	magnet_timer.name = "MagnetTimer2D"
	magnet_timer.wait_time = collection_frequency
	magnet_timer.timeout.connect(_auto_collect_debris_2d)
	magnet_timer.add_to_group("magnet_timer_2d")
	add_child(magnet_timer)
	magnet_timer.start()

	_log_message("PlayerShip: Magnet auto-collection started with %.2fs frequency" % collection_frequency)

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

func _auto_collect_debris_2d() -> void:
	##Automatically collect debris within magnet range in 2D
	if not is_magnet_active:
		return

	var debris_collected = 0
	var max_per_cycle = 2 + (int(magnet_range / 20.0))  # More collection at higher levels (2D scaling)
	for body in collection_area.get_overlapping_bodies():
		if body.is_in_group("debris") and debris_collected < max_per_cycle:
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
