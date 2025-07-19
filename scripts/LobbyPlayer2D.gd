# LobbyPlayer2D.gd
# 2D Player Controller for Trading Lobby
# Handles player movement and sprite rendering in the 2D lobby environment

class_name LobbyPlayer2D
extends CharacterBody2D

## Signal emitted when player position changes (for WebSocket sync)
signal position_changed(new_position: Vector2)

## Signal emitted when player enters/exits interaction areas
signal interaction_area_entered(area_type: String)
signal interaction_area_exited(area_type: String)

# Player sprite and visual components
@onready var player_sprite: Sprite2D = $PlayerSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea2D

# Movement properties
@export var move_speed: float = 200.0
@export var acceleration: float = 800.0
@export var friction: float = 800.0

# Input and movement state
var movement_enabled: bool = true
var input_vector: Vector2 = Vector2.ZERO
var last_position: Vector2 = Vector2.ZERO

# Interaction state
var can_interact: bool = false
var nearby_interaction_objects: Array[Node] = []

# Animation and visual state
var facing_direction: Vector2 = Vector2.DOWN
var sprite_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	print("[LobbyPlayer2D] Initializing 2D lobby player")
	_setup_player_sprite()
	_setup_collision()
	_setup_interaction_area()
	_connect_signals()

	# Store initial position
	last_position = global_position
	print("[LobbyPlayer2D] Player initialized at position: %s" % global_position)

func _physics_process(delta: float) -> void:
	if movement_enabled:
		_handle_input()
		_apply_movement(delta)
		_check_position_change()

func _setup_player_sprite() -> void:
	##Setup the player sprite with schlorp_guy_sprite.png
	print("[LobbyPlayer2D] Setting up player sprite")

	if player_sprite:
		# Load the schlorp guy sprite
		var sprite_texture = preload("res://assets/schlorp_guy_sprite.png")
		player_sprite.texture = sprite_texture

		# Use editor-set scale instead of programmatic scaling
		sprite_scale = player_sprite.scale  # Get the scale from editor

		print("[LobbyPlayer2D] Player sprite loaded with editor scale: %s" % sprite_scale)

func _setup_collision() -> void:
	##Setup collision shape for the player
	print("[LobbyPlayer2D] Setting up collision shape")

	if collision_shape:
		# Create a rectangular collision shape
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(32, 48)  # Adjust based on sprite size
		collision_shape.shape = rect_shape
		print("[LobbyPlayer2D] Collision shape created: %s" % rect_shape.size)

func _setup_interaction_area() -> void:
	##Setup interaction area for detecting nearby objects
	print("[LobbyPlayer2D] Setting up interaction area")

	if interaction_area:
		# Create collision shape for interaction area
		var interaction_shape = CircleShape2D.new()
		interaction_shape.radius = 64.0  # Interaction range

		var interaction_collision = CollisionShape2D.new()
		interaction_collision.shape = interaction_shape
		interaction_area.add_child(interaction_collision)

		print("[LobbyPlayer2D] Interaction area created with radius: %s" % interaction_shape.radius)

func _connect_signals() -> void:
	##Connect interaction area signals
	if interaction_area:
		interaction_area.area_entered.connect(_on_interaction_area_entered)
		interaction_area.area_exited.connect(_on_interaction_area_exited)
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
		print("[LobbyPlayer2D] Interaction signals connected")

func _handle_input() -> void:
	##Handle WASD input for movement
	input_vector = Vector2.ZERO

	# Get input from WASD keys
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1

	# Normalize diagonal movement
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		_update_facing_direction()

func _apply_movement(delta: float) -> void:
	##Apply movement physics to the player
	if input_vector.length() > 0:
		# Apply acceleration toward input direction
		velocity = velocity.move_toward(input_vector * move_speed, acceleration * delta)
	else:
		# Apply friction when no input
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	# Move the player
	move_and_slide()

func _update_facing_direction() -> void:
	##Update the facing direction and sprite flip based on movement
	if input_vector.length() > 0:
		facing_direction = input_vector

		# Flip sprite based on horizontal movement
		if player_sprite:
			if input_vector.x > 0:
				player_sprite.flip_h = false  # Facing right
			elif input_vector.x < 0:
				player_sprite.flip_h = true   # Facing left

func _check_position_change() -> void:
	##Check if position changed significantly and emit signal
	var current_position = global_position
	var distance_moved = last_position.distance_to(current_position)

	# Only emit if moved more than a threshold (reduce network spam)
	if distance_moved > 5.0:
		position_changed.emit(current_position)
		last_position = current_position

## Movement Control Methods

func set_movement_enabled(enabled: bool) -> void:
	##Enable or disable player movement
	movement_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
	print("[LobbyPlayer2D] Movement enabled: %s" % enabled)

func teleport_to_position(new_position: Vector2) -> void:
	##Teleport player to a specific position
	global_position = new_position
	last_position = new_position
	velocity = Vector2.ZERO
	print("[LobbyPlayer2D] Teleported to position: %s" % new_position)

func get_current_position() -> Vector2:
	##Get the current player position
	return global_position

## Interaction Handling

func _on_interaction_area_entered(area: Area2D) -> void:
	##Handle entering an interaction area
	print("[LobbyPlayer2D] Entered interaction area: %s" % area.name)

	nearby_interaction_objects.append(area)
	can_interact = true

	# Determine area type
	var area_type = "unknown"
	if "computer" in area.name.to_lower() or "trading" in area.name.to_lower():
		area_type = "trading_computer"

	interaction_area_entered.emit(area_type)

func _on_interaction_area_exited(area: Area2D) -> void:
	##Handle exiting an interaction area
	print("[LobbyPlayer2D] Exited interaction area: %s" % area.name)

	if area in nearby_interaction_objects:
		nearby_interaction_objects.erase(area)

	can_interact = nearby_interaction_objects.size() > 0

	# Determine area type
	var area_type = "unknown"
	if "computer" in area.name.to_lower() or "trading" in area.name.to_lower():
		area_type = "trading_computer"

	interaction_area_exited.emit(area_type)

func _on_interaction_body_entered(body: Node2D) -> void:
	##Handle entering a body interaction area
	print("[LobbyPlayer2D] Entered interaction body: %s" % body.name)
	# Handle body interactions if needed

func _on_interaction_body_exited(body: Node2D) -> void:
	##Handle exiting a body interaction area
	print("[LobbyPlayer2D] Exited interaction body: %s" % body.name)
	# Handle body interactions if needed

## Networking and Synchronization

func get_network_data() -> Dictionary:
	##Get player data for network synchronization
	return {
		"position": global_position,
		"facing_direction": facing_direction,
		"is_moving": velocity.length() > 10.0
	}

func apply_network_data(data: Dictionary) -> void:
	##Apply network data from remote players
	if data.has("position"):
		global_position = data.position

	if data.has("facing_direction"):
		facing_direction = data.facing_direction
		_update_sprite_from_direction()

func _update_sprite_from_direction() -> void:
	##Update sprite based on facing direction
	if player_sprite and facing_direction.length() > 0:
		if facing_direction.x > 0:
			player_sprite.flip_h = false
		elif facing_direction.x < 0:
			player_sprite.flip_h = true

## Debug and Utility

func log_message(message: String) -> void:
	##Log a message with player context
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] [LobbyPlayer2D] %s" % [timestamp, message]
	print(formatted_message)

func get_player_status() -> Dictionary:
	##Get current player status for debugging
	return {
		"position": global_position,
		"velocity": velocity,
		"movement_enabled": movement_enabled,
		"can_interact": can_interact,
		"facing_direction": facing_direction,
		"nearby_objects": nearby_interaction_objects.size()
	}
