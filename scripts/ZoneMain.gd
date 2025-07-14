# ZoneMain.gd
# Main zone controller for Children of the Singularity
# Manages the primary gameplay zone where players explore and collect debris

class_name ZoneMain
extends Node2D

## Signal emitted when zone is fully loaded and ready for gameplay
signal zone_ready()

## Signal emitted when debris is collected
signal debris_collected(debris_type: String, value: int)

## Signal emitted when player enters NPC hub area
signal npc_hub_entered()

@onready var camera_2d: Camera2D = $Camera2D
@onready var player_ship: CharacterBody2D = $PlayerShip
@onready var debris_container: Node2D = $DebrisContainer
@onready var hud: Control = $UILayer/HUD
@onready var debug_label: Label = $UILayer/HUD/DebugLabel
@onready var log_label: Label = $UILayer/HUD/LogLabel

# UI Components
@onready var inventory_panel: Panel = $UILayer/HUD/InventoryPanel
@onready var inventory_grid: GridContainer = $UILayer/HUD/InventoryPanel/InventoryGrid
@onready var inventory_status: Label = $UILayer/HUD/InventoryPanel/InventoryStatus
@onready var credits_label: Label = $UILayer/HUD/StatsPanel/CreditsLabel
@onready var debris_count_label: Label = $UILayer/HUD/StatsPanel/DebrisCountLabel
@onready var collection_range_label: Label = $UILayer/HUD/StatsPanel/CollectionRangeLabel
@onready var ai_message_overlay: Panel = $UILayer/HUD/AIMessageOverlay
@onready var ai_message_label: Label = $UILayer/HUD/AIMessageOverlay/AIMessageLabel

var zone_name: String = "Zone Alpha"
var zone_id: String = "zone_alpha_01"
var max_debris_count: int = 50
var current_debris_count: int = 0
var zone_bounds: Rect2 = Rect2(-1000, -1000, 2000, 2000)
var game_logs: Array[String] = []

# Debris spawning properties
var debris_types: Array[Dictionary] = [
	{"type": "scrap_metal", "value": 5, "spawn_weight": 40, "color": Color.GRAY},
	{"type": "broken_satellite", "value": 150, "spawn_weight": 10, "color": Color.SILVER},
	{"type": "bio_waste", "value": 25, "spawn_weight": 25, "color": Color.GREEN},
	{"type": "ai_component", "value": 500, "spawn_weight": 5, "color": Color.CYAN},
	{"type": "unknown_artifact", "value": 1000, "spawn_weight": 1, "color": Color.PURPLE}
]

# UI Management
var inventory_items: Array[Control] = []
var ui_update_timer: float = 0.0
var ui_update_interval: float = 0.1

func _ready() -> void:
	_log_message("ZoneMain: Initializing zone controller")
	_initialize_zone()
	_spawn_initial_debris()
	_setup_ui_connections()
	_update_debug_display()

	# Connect player signals
	if player_ship:
		player_ship.debris_collected.connect(_on_debris_collected)
		player_ship.position_changed.connect(_on_player_position_changed)

	_log_message("ZoneMain: Zone ready for gameplay")
	zone_ready.emit()

func _process(delta: float) -> void:
	"""Update UI periodically"""
	ui_update_timer += delta
	if ui_update_timer >= ui_update_interval:
		_update_ui()
		ui_update_timer = 0.0

func _initialize_zone() -> void:
	"""Initialize the zone with basic settings and validate components"""
	_log_message("ZoneMain: Setting up zone bounds and camera")

	# Set camera limits based on zone bounds
	if camera_2d:
		camera_2d.limit_left = int(zone_bounds.position.x)
		camera_2d.limit_top = int(zone_bounds.position.y)
		camera_2d.limit_right = int(zone_bounds.end.x)
		camera_2d.limit_bottom = int(zone_bounds.end.y)

	# Initialize HUD
	if debug_label:
		debug_label.text = "Children of the Singularity - %s [DEBUG]" % zone_name

	_log_message("ZoneMain: Zone initialization complete")

func _setup_ui_connections() -> void:
	"""Set up UI connections and initial state"""
	_log_message("ZoneMain: Setting up UI connections")

	# Clear any existing inventory items
	_clear_inventory_display()

	# Initialize UI state
	_update_ui()

	_log_message("ZoneMain: UI connections established")

func _update_ui() -> void:
	"""Update all UI elements with current game state"""
	if not player_ship:
		return

	var player_info = player_ship.get_player_info()

	# Update inventory display
	_update_inventory_display(player_info.inventory)

	# Update stats
	if credits_label:
		credits_label.text = "Credits: %d" % player_info.credits

	if debris_count_label:
		debris_count_label.text = "Nearby Debris: %d" % player_info.nearby_debris_count

	if collection_range_label:
		collection_range_label.text = "Collection Range: %.0f" % player_ship.collection_range

	# Update inventory status
	if inventory_status:
		inventory_status.text = "%d/%d Items" % [player_info.inventory.size(), player_info.inventory_capacity]

func _update_inventory_display(inventory: Array[Dictionary]) -> void:
	"""Update the inventory grid display"""
	if not inventory_grid:
		return

	# Clear existing items
	_clear_inventory_display()

	# Add current inventory items
	for item in inventory:
		_add_inventory_item_to_display(item)

func _clear_inventory_display() -> void:
	"""Clear all items from the inventory display"""
	if not inventory_grid:
		return

	for child in inventory_grid.get_children():
		child.queue_free()

	inventory_items.clear()

func _add_inventory_item_to_display(item: Dictionary) -> void:
	"""Add an item to the inventory display"""
	if not inventory_grid:
		return

	# Create item container
	var item_container = Panel.new()
	item_container.custom_minimum_size = Vector2(80, 80)

	# Get item color based on type
	var item_color = _get_item_color(item.type)
	item_container.color = item_color

	# Create item label
	var item_label = Label.new()
	item_label.text = "%s\nVal: %d" % [_get_item_display_name(item.type), item.value]
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_label.anchor_right = 1.0
	item_label.anchor_bottom = 1.0

	item_container.add_child(item_label)
	inventory_grid.add_child(item_container)
	inventory_items.append(item_container)

func _get_item_color(item_type: String) -> Color:
	"""Get the display color for an item type"""
	for debris_type in debris_types:
		if debris_type.type == item_type:
			return debris_type.color
	return Color.WHITE

func _get_item_display_name(item_type: String) -> String:
	"""Get a friendly display name for an item type"""
	match item_type:
		"scrap_metal":
			return "Scrap\nMetal"
		"broken_satellite":
			return "Broken\nSatellite"
		"bio_waste":
			return "Bio\nWaste"
		"ai_component":
			return "AI\nComponent"
		"unknown_artifact":
			return "Unknown\nArtifact"
		_:
			return "Unknown\nItem"

func _spawn_initial_debris() -> void:
	"""Spawn initial debris objects in the zone"""
	_log_message("ZoneMain: Spawning initial debris objects")

	# Clear existing debris
	for child in debris_container.get_children():
		child.queue_free()

	current_debris_count = 0

	# Spawn debris objects
	for i in range(max_debris_count):
		_spawn_debris_object()

	_log_message("ZoneMain: Initial debris spawn complete (%d objects)" % current_debris_count)

func _spawn_debris_object() -> void:
	"""Spawn a single debris object"""
	if current_debris_count >= max_debris_count:
		return

	# Choose debris type based on spawn weights
	var debris_type_data = _get_weighted_debris_type()

	# Create debris object
	var debris_object = _create_debris_object(debris_type_data)

	# Set random position within zone bounds
	var spawn_position = Vector2(
		randf_range(zone_bounds.position.x + 100, zone_bounds.end.x - 100),
		randf_range(zone_bounds.position.y + 100, zone_bounds.end.y - 100)
	)

	debris_object.global_position = spawn_position
	debris_container.add_child(debris_object)

	current_debris_count += 1

	_log_message("ZoneMain: Spawned %s debris at %s" % [debris_type_data.type, spawn_position])

func _get_weighted_debris_type() -> Dictionary:
	"""Get a random debris type based on spawn weights"""
	var total_weight = 0
	for debris_type in debris_types:
		total_weight += debris_type.spawn_weight

	var random_value = randf() * total_weight
	var current_weight = 0

	for debris_type in debris_types:
		current_weight += debris_type.spawn_weight
		if random_value <= current_weight:
			return debris_type

	# Fallback to first type
	return debris_types[0]

func _create_debris_object(debris_type_data: Dictionary) -> RigidBody2D:
	"""Create a debris object with collision and visual components"""
	var debris_object = RigidBody2D.new()
	debris_object.name = "Debris_%s_%d" % [debris_type_data.type, current_debris_count]
	debris_object.collision_layer = 4  # debris layer
	debris_object.collision_mask = 1   # can collide with player
	debris_object.gravity_scale = 0    # no gravity in space
	debris_object.linear_damp = 0.5    # slight damping for realistic movement
	debris_object.angular_damp = 0.3

	# Create visual representation
	var sprite = Sprite2D.new()
	sprite.name = "DebrisSprite"

	# Create a simple colored rectangle texture
	var texture = ImageTexture.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(debris_type_data.color)
	texture.set_image(image)
	sprite.texture = texture

	debris_object.add_child(sprite)

	# Create collision shape
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "DebrisCollision"
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(30, 30)
	collision_shape.shape = rect_shape
	debris_object.add_child(collision_shape)

	# Add metadata to the debris object
	debris_object.set_meta("debris_type", debris_type_data.type)
	debris_object.set_meta("debris_value", debris_type_data.value)
	debris_object.set_meta("debris_id", "debris_%s_%d" % [debris_type_data.type, current_debris_count])

	# Add slight random rotation and velocity
	debris_object.rotation = randf() * TAU
	debris_object.linear_velocity = Vector2(
		randf_range(-20, 20),
		randf_range(-20, 20)
	)
	debris_object.angular_velocity = randf_range(-0.5, 0.5)

	return debris_object

func _on_debris_collected(debris_type: String, value: int) -> void:
	"""Handle debris collection events from player"""
	_log_message("ZoneMain: Debris collected - Type: %s, Value: %d" % [debris_type, value])
	current_debris_count -= 1
	debris_collected.emit(debris_type, value)
	_update_debug_display()

	# Spawn a new debris object to maintain count
	if current_debris_count < max_debris_count:
		get_tree().create_timer(randf_range(5.0, 15.0)).timeout.connect(_spawn_debris_object)

func _on_player_position_changed(new_position: Vector2) -> void:
	"""Handle player position updates for camera tracking"""
	if camera_2d:
		camera_2d.global_position = new_position

func _update_debug_display() -> void:
	"""Update the debug information display"""
	if debug_label:
		debug_label.text = "Children of the Singularity - %s [DEBUG] | Debris: %d/%d" % [zone_name, current_debris_count, max_debris_count]

func _log_message(message: String) -> void:
	"""Add a message to the game log and display it"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]

	print(formatted_message)
	game_logs.append(formatted_message)

	# Keep only last 10 log entries for display
	if game_logs.size() > 10:
		game_logs.pop_front()

	# Update log display
	if log_label:
		log_label.text = "Console Log:\n" + "\n".join(game_logs)

## Display AI message to player
func show_ai_message(message: String, duration: float = 3.0) -> void:
	"""Display an AI message to the player"""
	if ai_message_overlay and ai_message_label:
		ai_message_label.text = message
		ai_message_overlay.visible = true

		# Hide after duration
		get_tree().create_timer(duration).timeout.connect(func(): ai_message_overlay.visible = false)

		_log_message("ZoneMain: AI message displayed: %s" % message)

## Get debris object by ID
func get_debris_by_id(debris_id: String) -> RigidBody2D:
	"""Get a specific debris object by its ID"""
	for child in debris_container.get_children():
		if child.has_meta("debris_id") and child.get_meta("debris_id") == debris_id:
			return child
	return null

## Remove debris object (called when collected)
func remove_debris(debris_object: RigidBody2D) -> void:
	"""Remove a debris object from the zone"""
	if debris_object and is_instance_valid(debris_object):
		var debris_type = debris_object.get_meta("debris_type", "unknown")
		var debris_value = debris_object.get_meta("debris_value", 0)

		_log_message("ZoneMain: Removing debris - Type: %s, Value: %d" % [debris_type, debris_value])

		# Create collection effect
		_create_collection_effect(debris_object.global_position)

		# Remove the debris object
		debris_object.queue_free()
		current_debris_count -= 1
		_update_debug_display()

func _create_collection_effect(position: Vector2) -> void:
	"""Create a visual effect when debris is collected"""
	var effect = Node2D.new()
	effect.name = "CollectionEffect"
	effect.global_position = position

	# Create expanding circle effect
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.spread = 45.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.color = Color.WHITE

	effect.add_child(particles)
	add_child(effect)

	# Remove effect after animation completes
	get_tree().create_timer(1.0).timeout.connect(func(): effect.queue_free())

## Get the current zone information
func get_zone_info() -> Dictionary:
	return {
		"zone_name": zone_name,
		"zone_id": zone_id,
		"bounds": zone_bounds,
		"debris_count": current_debris_count,
		"max_debris": max_debris_count
	}

## Manually spawn debris at a specific position
func spawn_debris_at(position: Vector2, debris_type: String = "scrap_metal") -> void:
	"""Spawn debris at a specific position"""
	_log_message("ZoneMain: Spawning %s debris at %s" % [debris_type, position])

	# Find debris type data
	var debris_type_data = null
	for dtype in debris_types:
		if dtype.type == debris_type:
			debris_type_data = dtype
			break

	if not debris_type_data:
		debris_type_data = debris_types[0]  # Default to first type

	# Create debris object
	var debris_object = _create_debris_object(debris_type_data)
	debris_object.global_position = position
	debris_container.add_child(debris_object)

	current_debris_count += 1
	_update_debug_display()

## Clear all debris from the zone
func clear_all_debris() -> void:
	"""Clear all debris from the zone"""
	_log_message("ZoneMain: Clearing all debris from zone")

	for child in debris_container.get_children():
		child.queue_free()

	current_debris_count = 0
	_update_debug_display()

## Reset the zone to its initial state
func reset_zone() -> void:
	"""Reset the zone to its initial state"""
	_log_message("ZoneMain: Resetting zone to initial state")
	clear_all_debris()
	_spawn_initial_debris()
	zone_ready.emit()
