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

## Walking animation system (similar to ship animation)
var walking_animation_textures: Dictionary = {}  # Organized by direction
var animation_timer: Timer
var current_frame: int = 0
var current_animation_state: String = "idle"  # idle, walking_left, walking_right, walking_up, walking_down
var animation_speed: float = 0.1  # Time between frames (10 FPS)
var is_walking: bool = false

## Animation frame ranges
const WALK_LEFT_START: int = 16
const WALK_LEFT_END: int = 23
const WALK_UP_START: int = 42
const WALK_UP_END: int = 45
const WALK_DOWN_START: int = 74
const WALK_DOWN_END: int = 80

## Idle/default sprite
var default_sprite: Texture2D

func _ready() -> void:
	print("[LobbyPlayer2D] Initializing 2D lobby player with walking animation")
	_load_walking_animation_textures()  # Load all walking frames first
	_setup_player_sprite()
	_setup_collision()
	_setup_interaction_area()
	_setup_walking_animation_system()
	_connect_signals()

	# Store initial position
	last_position = global_position
	print("[LobbyPlayer2D] Player initialized at position: %s" % global_position)

func _exit_tree() -> void:
	##Clean up animation resources when node is freed
	if animation_timer and is_instance_valid(animation_timer):
		animation_timer.queue_free()
	print("[LobbyPlayer2D] Walking animation resources cleaned up")

func _physics_process(delta: float) -> void:
	if movement_enabled:
		_handle_input()
		_apply_movement(delta)
		_check_position_change()
		_update_walking_animation()

func _load_walking_animation_textures() -> void:
	##Load all walking animation frame textures organized by direction
	print("[LobbyPlayer2D] Loading walking animation textures...")

	# Initialize texture arrays for each direction
	walking_animation_textures = {
		"walking_left": [],
		"walking_right": [],  # Will be flipped versions of left
		"walking_up": [],
		"walking_down": []
	}

	var loaded_count = 0
	var total_expected = 0

	# Load walking left frames (16-23)
	for i in range(WALK_LEFT_START, WALK_LEFT_END + 1):
		var texture_path = "res://assets/sprites/player/walking_animation/walking_guy_frame_%03d.png" % i
		var texture = load(texture_path) as Texture2D
		if texture:
			# Original frames face right, so use them for walking_right
			walking_animation_textures["walking_right"].append(texture)
			# Create flipped version for walking left
			var flipped_texture = _create_flipped_texture(texture)
			walking_animation_textures["walking_left"].append(flipped_texture)
			loaded_count += 2
		else:
			print("[LobbyPlayer2D] Failed to load texture: %s" % texture_path)
		total_expected += 2

	# Load walking up frames (42-45)
	for i in range(WALK_UP_START, WALK_UP_END + 1):
		var texture_path = "res://assets/sprites/player/walking_animation/walking_guy_frame_%03d.png" % i
		var texture = load(texture_path) as Texture2D
		if texture:
			walking_animation_textures["walking_up"].append(texture)
			loaded_count += 1
		else:
			print("[LobbyPlayer2D] Failed to load texture: %s" % texture_path)
		total_expected += 1

	# Load walking down frames (74-80)
	for i in range(WALK_DOWN_START, WALK_DOWN_END + 1):
		var texture_path = "res://assets/sprites/player/walking_animation/walking_guy_frame_%03d.png" % i
		var texture = load(texture_path) as Texture2D
		if texture:
			walking_animation_textures["walking_down"].append(texture)
			loaded_count += 1
		else:
			print("[LobbyPlayer2D] Failed to load texture: %s" % texture_path)
		total_expected += 1

	print("[LobbyPlayer2D] Loaded %d/%d walking animation textures" % [loaded_count, total_expected])
	print("[LobbyPlayer2D] Left: %d, Right: %d, Up: %d, Down: %d frames" % [
		walking_animation_textures["walking_left"].size(),
		walking_animation_textures["walking_right"].size(),
		walking_animation_textures["walking_up"].size(),
		walking_animation_textures["walking_down"].size()
	])

func _create_flipped_texture(original: Texture2D) -> ImageTexture:
	##Create a horizontally flipped version of a texture
	var image = original.get_image()
	image.flip_x()
	var flipped_texture = ImageTexture.new()
	flipped_texture.set_image(image)
	return flipped_texture

func _setup_walking_animation_system() -> void:
	##Set up the walking animation timer system
	print("[LobbyPlayer2D] Setting up walking animation system")

	# Create animation timer
	animation_timer = Timer.new()
	animation_timer.name = "WalkingAnimationTimer"
	animation_timer.wait_time = animation_speed
	animation_timer.timeout.connect(_on_walking_animation_timeout)
	add_child(animation_timer)

	# Don't autostart - only animate when walking
	animation_timer.autostart = false

	print("[LobbyPlayer2D] Walking animation system ready - Frame rate: %.1f FPS" % [1.0/animation_speed])

func _on_walking_animation_timeout() -> void:
	##Handle walking animation timer timeout - advance to next frame
	if not is_walking or current_animation_state == "idle":
		return

	# Get current animation frame array
	var current_frames = walking_animation_textures.get(current_animation_state, [])
	if current_frames.size() == 0:
		return

	# Advance to next frame with looping
	current_frame += 1
	if current_frame >= current_frames.size():
		current_frame = 0  # Loop back to start

	# Update the sprite texture
	if player_sprite and current_frame < current_frames.size():
		player_sprite.texture = current_frames[current_frame]

func _setup_player_sprite() -> void:
	##Setup the player sprite with walking_guy_frame_080.png as idle
	print("[LobbyPlayer2D] Setting up player sprite")

	if player_sprite:
		# Load the walking guy frame 080 as the idle/default sprite
		default_sprite = preload("res://assets/sprites/player/walking_animation/walking_guy_frame_080.png")
		player_sprite.texture = default_sprite

		# Make the sprite larger for better visibility
		player_sprite.scale = Vector2(0.3, 0.3)  # Increase from 0.1 to 0.3 for 3x larger
		sprite_scale = player_sprite.scale

		print("[LobbyPlayer2D] Player sprite loaded with walking frame 080 as idle and larger scale: %s" % sprite_scale)

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
		is_walking = true
	else:
		# Apply friction when no input
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		is_walking = false

	# Move the player
	move_and_slide()

func _update_facing_direction() -> void:
	##Update the facing direction based on movement (no longer flips sprite - animation handles direction)
	if input_vector.length() > 0:
		facing_direction = input_vector

func _update_walking_animation() -> void:
	##Update walking animation state based on movement direction
	if not is_walking or input_vector.length() == 0:
		# Stop walking animation and return to idle
		_set_animation_state("idle")
		return

	# Determine animation based on dominant movement direction
	var abs_x = abs(input_vector.x)
	var abs_y = abs(input_vector.y)

	var new_animation_state = "idle"

	# Prioritize horizontal movement for left/right animation
	if abs_x > abs_y:
		if input_vector.x > 0:
			new_animation_state = "walking_right"
		else:
			new_animation_state = "walking_left"
	else:
		# Vertical movement
		if input_vector.y < 0:
			new_animation_state = "walking_up"
		else:
			new_animation_state = "walking_down"

	_set_animation_state(new_animation_state)

func _set_animation_state(new_state: String) -> void:
	##Set the current animation state and handle transitions
	if current_animation_state == new_state:
		return  # No change needed

	var previous_state = current_animation_state
	current_animation_state = new_state

	print("[LobbyPlayer2D] Animation state change: %s -> %s" % [previous_state, new_state])

	if new_state == "idle":
		# Stop animation and return to default sprite
		if animation_timer:
			animation_timer.stop()
		if player_sprite and default_sprite:
			player_sprite.texture = default_sprite
		current_frame = 0
	else:
		# Start/continue walking animation
		current_frame = 0  # Reset to first frame of new animation
		if animation_timer:
			if not animation_timer.is_stopped():
				animation_timer.stop()
			animation_timer.start()

		# Set initial frame immediately
		_update_current_frame()

func _update_current_frame() -> void:
	##Update the sprite to show the current frame of the current animation
	if current_animation_state == "idle":
		return

	var current_frames = walking_animation_textures.get(current_animation_state, [])
	if current_frames.size() == 0:
		print("[LobbyPlayer2D] No frames for animation state: %s" % current_animation_state)
		return

	if player_sprite and current_frame < current_frames.size():
		player_sprite.texture = current_frames[current_frame]

## Animation Control Methods

func set_animation_speed(speed: float) -> void:
	##Set the walking animation speed (time between frames)
	animation_speed = speed
	if animation_timer:
		animation_timer.wait_time = animation_speed
		print("[LobbyPlayer2D] Animation speed updated to %.2f seconds per frame (%.1f FPS)" % [animation_speed, 1.0/animation_speed])

func pause_walking_animation() -> void:
	##Pause the walking animation
	if animation_timer:
		animation_timer.paused = true
		print("[LobbyPlayer2D] Walking animation paused")

func resume_walking_animation() -> void:
	##Resume the walking animation
	if animation_timer:
		animation_timer.paused = false
		print("[LobbyPlayer2D] Walking animation resumed")

func _check_position_change() -> void:
	##Check if position changed significantly and emit signal + send to WebSocket
	var current_position = global_position
	var distance_moved = last_position.distance_to(current_position)

	# Only emit if moved more than a threshold (reduce network spam)
	if distance_moved > 5.0:
		position_changed.emit(current_position)
		last_position = current_position

		# Also send directly to LobbyController for WebSocket transmission
		_broadcast_position_to_websocket(current_position)

func _broadcast_position_to_websocket(position: Vector2) -> void:
	##Send position update directly to LobbyController for WebSocket broadcasting
	if LobbyController and LobbyController.is_lobby_connected():
		LobbyController.send_position_update(position)

## Movement Control Methods

func set_movement_enabled(enabled: bool) -> void:
	##Enable or disable player movement
	movement_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		_set_animation_state("idle")  # Stop walking animation when movement disabled
	print("[LobbyPlayer2D] Movement enabled: %s" % enabled)

func teleport_to_position(new_position: Vector2) -> void:
	##Teleport player to a specific position
	global_position = new_position
	last_position = new_position
	velocity = Vector2.ZERO
	_set_animation_state("idle")  # Reset animation state when teleporting
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
