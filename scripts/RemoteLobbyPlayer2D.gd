# RemoteLobbyPlayer2D.gd
# Remote Player Representation for 2D Trading Lobby
# Handles visual representation and smooth interpolation of other players

class_name RemoteLobbyPlayer2D
extends CharacterBody2D

## Signal emitted when remote player is removed from scene
signal remote_player_removed(player_id: String)

# Remote player data
var player_id: String = ""
var last_server_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var interpolation_speed: float = 15.0
var position_threshold: float = 2.0  # Minimum movement to trigger interpolation

# Visual components (created programmatically, not @onready)
var player_sprite: Sprite2D
var player_label: Label
var connection_indicator: ColorRect

# Animation and visual state
var facing_direction: Vector2 = Vector2.DOWN
var is_moving: bool = false
var sprite_scale: Vector2 = Vector2.ONE
var label_offset: Vector2 = Vector2(0, -60)

## Walking animation system (same as LobbyPlayer2D)
var walking_animation_textures: Dictionary = {}  # Organized by direction
var animation_timer: Timer
var current_frame: int = 0
var current_animation_state: String = "idle"  # idle, walking_left, walking_right, walking_up, walking_down
var animation_speed: float = 0.1  # Time between frames (10 FPS)

## Animation frame ranges (same as LobbyPlayer2D)
const WALK_LEFT_START: int = 16
const WALK_LEFT_END: int = 23
const WALK_UP_START: int = 42
const WALK_UP_END: int = 45
const WALK_DOWN_START: int = 74
const WALK_DOWN_END: int = 80

## Idle/default sprite
var default_sprite: Texture2D

# Interpolation state
var smooth_movement: bool = true
var interpolation_enabled: bool = true
var time_since_last_update: float = 0.0
var max_interpolation_time: float = 1.0  # Max time to interpolate old positions

# Visual effects
var fade_in_duration: float = 0.5
var fade_out_duration: float = 0.3
var spawn_scale_effect: bool = true
var alpha_when_spawning: float = 0.0

func _ready() -> void:
	print("[RemoteLobbyPlayer2D] Initializing remote player: %s" % player_id)
	_load_walking_animation_textures()  # Load all walking frames first
	_setup_visual_components()
	_setup_walking_animation_system()
	_setup_interpolation()
	_play_spawn_effect()

func _exit_tree() -> void:
	##Clean up animation resources when node is freed
	if animation_timer and is_instance_valid(animation_timer):
		animation_timer.queue_free()
	print("[RemoteLobbyPlayer2D] Walking animation resources cleaned up for player: %s" % player_id)

func _physics_process(delta: float) -> void:
	if interpolation_enabled and smooth_movement:
		_update_position_interpolation(delta)

	time_since_last_update += delta
	_update_visual_state()
	_update_walking_animation_from_movement()

## Public API Methods

func initialize_remote_player(remote_player_data: Dictionary) -> void:
	"""Initialize the remote player with data from server"""
	player_id = remote_player_data.get("id", "unknown")
	var initial_position = Vector2(
		remote_player_data.get("x", 0.0),
		remote_player_data.get("y", 0.0)
	)

	# Set both current and target positions to avoid interpolation on spawn
	global_position = initial_position
	last_server_position = initial_position
	target_position = initial_position

	# Update visual components
	_update_player_label()
	_setup_visual_components()

	print("[RemoteLobbyPlayer2D] Initialized remote player %s at (%.1f, %.1f)" % [
		player_id, initial_position.x, initial_position.y
	])

func update_remote_position(new_position: Vector2) -> void:
	"""Update remote player position with smooth interpolation"""
	# Check if position changed significantly
	var distance = last_server_position.distance_to(new_position)
	if distance < position_threshold:
		return  # Skip minor movements

	# Update positions for interpolation
	last_server_position = target_position
	target_position = new_position
	time_since_last_update = 0.0

	# Update facing direction
	var movement_vector = new_position - global_position
	if movement_vector.length() > 1.0:
		facing_direction = movement_vector.normalized()
		is_moving = true
		_update_sprite_direction()
	else:
		is_moving = false

	print("[RemoteLobbyPlayer2D] Player %s moving to (%.1f, %.1f), distance: %.1f" % [
		player_id, new_position.x, new_position.y, distance
	])

func set_player_name(name: String) -> void:
	"""Set the display name for this remote player"""
	if player_label:
		player_label.text = name
		print("[RemoteLobbyPlayer2D] Set player name: %s" % name)

func get_player_id() -> String:
	"""Get the player ID"""
	return player_id

func remove_remote_player() -> void:
	"""Remove this remote player with fade out effect"""
	print("[RemoteLobbyPlayer2D] Removing remote player: %s" % player_id)
	_play_despawn_effect()

## Private Methods

func _setup_visual_components() -> void:
	"""Initialize visual components with walking animation support"""
	print("[RemoteLobbyPlayer2D] Setting up visual components for %s" % player_id)

	# Setup sprite with walking animation idle texture
	if not player_sprite:
		player_sprite = Sprite2D.new()
		player_sprite.name = "RemotePlayerSprite2D"
		add_child(player_sprite)

	# Load the walking guy frame 080 as the idle/default sprite
	default_sprite = preload("res://assets/sprites/player/walking_animation/walking_guy_frame_080.png")
	player_sprite.texture = default_sprite

	# Make the sprite larger for better visibility (same as local player)
	player_sprite.scale = Vector2(0.3, 0.3)  # Match local player scale
	sprite_scale = player_sprite.scale
	print("[RemoteLobbyPlayer2D] Remote player sprite setup with walking frame 080 as idle and larger scale: %s" % sprite_scale)

	# Setup player label
	if not player_label:
		player_label = Label.new()
		player_label.name = "PlayerLabel"
		add_child(player_label)

	_update_player_label()

	# Setup connection indicator
	if not connection_indicator:
		connection_indicator = ColorRect.new()
		connection_indicator.name = "ConnectionIndicator"
		connection_indicator.size = Vector2(8, 8)
		connection_indicator.position = Vector2(-4, -70)
		add_child(connection_indicator)

	_update_connection_indicator()

	print("[RemoteLobbyPlayer2D] Visual components setup complete")

func _update_player_label() -> void:
	"""Update the player label display"""
	if player_label:
		# Show shortened player ID (first 8 characters)
		var display_name = player_id
		if display_name.length() > 8:
			display_name = display_name.substr(0, 8) + "..."

		player_label.text = display_name
		player_label.position = label_offset
		player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_label.add_theme_color_override("font_color", Color.CYAN)

		# Add background for better readability
		player_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		player_label.add_theme_constant_override("shadow_offset_x", 1)
		player_label.add_theme_constant_override("shadow_offset_y", 1)

func _update_connection_indicator() -> void:
	"""Update the connection status indicator"""
	if connection_indicator:
		# Green dot for active connection
		connection_indicator.color = Color.GREEN

		# Fade the indicator based on time since last update
		var alpha = 1.0
		if time_since_last_update > max_interpolation_time:
			alpha = max(0.3, 1.0 - (time_since_last_update - max_interpolation_time) * 0.5)

		connection_indicator.modulate.a = alpha

func _setup_interpolation() -> void:
	"""Setup position interpolation settings"""
	# Load interpolation settings from LobbyController config if available
	if LobbyController and LobbyController.lobby_config.has("performance"):
		var perf_config = LobbyController.lobby_config.performance
		smooth_movement = perf_config.get("smooth_movement", true)
		interpolation_enabled = perf_config.get("position_interpolation", true)
		interpolation_speed = perf_config.get("interpolation_speed", 15.0)

	print("[RemoteLobbyPlayer2D] Interpolation enabled: %s, smooth movement: %s" % [
		interpolation_enabled, smooth_movement
	])

func _update_position_interpolation(delta: float) -> void:
	"""Update position with smooth interpolation"""
	if not interpolation_enabled:
		global_position = target_position
		return

	# Skip interpolation if we're already at target
	var distance_to_target = global_position.distance_to(target_position)
	if distance_to_target < 1.0:
		return

	# Use lerp for smooth interpolation
	var interpolation_factor = interpolation_speed * delta

	# Adjust interpolation speed based on distance (faster for larger distances)
	if distance_to_target > 50.0:
		interpolation_factor *= 2.0
	elif distance_to_target > 100.0:
		interpolation_factor *= 3.0

	# Clamp interpolation factor
	interpolation_factor = min(interpolation_factor, 1.0)

	# Apply interpolation
	global_position = global_position.lerp(target_position, interpolation_factor)

func _update_sprite_direction() -> void:
	"""Update sprite facing direction based on movement"""
	if player_sprite and facing_direction.length() > 0:
		# Flip sprite based on horizontal movement
		if facing_direction.x > 0:
			player_sprite.flip_h = false  # Facing right
		elif facing_direction.x < 0:
			player_sprite.flip_h = true   # Facing left

func _update_visual_state() -> void:
	"""Update visual state indicators"""
	_update_connection_indicator()

	# Update sprite alpha based on movement state
	if player_sprite:
		var alpha = 1.0 if is_moving else 0.8
		player_sprite.modulate.a = alpha

func _play_spawn_effect() -> void:
	"""Play spawn animation effect"""
	if not spawn_scale_effect:
		return

	print("[RemoteLobbyPlayer2D] Playing spawn effect for %s" % player_id)

	# Start with small scale and fade in
	scale = Vector2.ZERO
	modulate.a = alpha_when_spawning

	# Animate to full size and opacity
	var tween = create_tween()
	tween.set_parallel(true)

	# Scale animation
	tween.tween_property(self, "scale", Vector2.ONE, fade_in_duration)
	tween.tween_method(_set_scale_with_easing, 0.0, 1.0, fade_in_duration)

	# Fade in animation
	tween.tween_property(self, "modulate:a", 1.0, fade_in_duration)

func _play_despawn_effect() -> void:
	"""Play despawn animation effect"""
	print("[RemoteLobbyPlayer2D] Playing despawn effect for %s" % player_id)

	# Animate scale down and fade out
	var tween = create_tween()
	tween.set_parallel(true)

	# Scale animation
	tween.tween_property(self, "scale", Vector2.ZERO, fade_out_duration)

	# Fade out animation
	tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)

	# Remove from scene when animation completes
	tween.tween_callback(_remove_from_scene).set_delay(fade_out_duration)

func _set_scale_with_easing(value: float) -> void:
	"""Set scale with easing effect for spawn animation"""
	var ease_value = ease_out_bounce(value)
	scale = Vector2(ease_value, ease_value)

func ease_out_bounce(t: float) -> float:
	"""Bounce easing function for spawn effect"""
	if t < 1.0 / 2.75:
		return 7.5625 * t * t
	elif t < 2.0 / 2.75:
		t -= 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	elif t < 2.5 / 2.75:
		t -= 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	else:
		t -= 2.625 / 2.75
		return 7.5625 * t * t + 0.984375

func _remove_from_scene() -> void:
	"""Remove this remote player from the scene"""
	remote_player_removed.emit(player_id)
	queue_free()

## Utility Methods

func get_display_position() -> Vector2:
	"""Get the current display position"""
	return global_position

func get_target_position() -> Vector2:
	"""Get the target position for interpolation"""
	return target_position

func is_interpolating() -> bool:
	"""Check if currently interpolating to a new position"""
	return global_position.distance_to(target_position) > 1.0

func set_interpolation_speed(speed: float) -> void:
	"""Set custom interpolation speed"""
	interpolation_speed = speed

func teleport_to_position(new_position: Vector2) -> void:
	"""Teleport to position without interpolation"""
	global_position = new_position
	target_position = new_position
	last_server_position = new_position
	print("[RemoteLobbyPlayer2D] Teleported %s to (%.1f, %.1f)" % [
		player_id, new_position.x, new_position.y
	])

## Debug Methods

func get_remote_player_info() -> Dictionary:
	"""Get debug information about this remote player"""
	return {
		"player_id": player_id,
		"current_position": global_position,
		"target_position": target_position,
		"last_server_position": last_server_position,
		"is_moving": is_moving,
		"is_interpolating": is_interpolating(),
		"time_since_update": time_since_last_update,
		"facing_direction": facing_direction,
		"interpolation_enabled": interpolation_enabled
	}

func _load_walking_animation_textures() -> void:
	##Load all walking animation frame textures (same as LobbyPlayer2D)
	print("[RemoteLobbyPlayer2D] Loading walking animation textures for remote player...")

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
			print("[RemoteLobbyPlayer2D] Failed to load texture: %s" % texture_path)
		total_expected += 2

	# Load walking up frames (42-45)
	for i in range(WALK_UP_START, WALK_UP_END + 1):
		var texture_path = "res://assets/sprites/player/walking_animation/walking_guy_frame_%03d.png" % i
		var texture = load(texture_path) as Texture2D
		if texture:
			walking_animation_textures["walking_up"].append(texture)
			loaded_count += 1
		else:
			print("[RemoteLobbyPlayer2D] Failed to load texture: %s" % texture_path)
		total_expected += 1

	# Load walking down frames (74-80)
	for i in range(WALK_DOWN_START, WALK_DOWN_END + 1):
		var texture_path = "res://assets/sprites/player/walking_animation/walking_guy_frame_%03d.png" % i
		var texture = load(texture_path) as Texture2D
		if texture:
			walking_animation_textures["walking_down"].append(texture)
			loaded_count += 1
		else:
			print("[RemoteLobbyPlayer2D] Failed to load texture: %s" % texture_path)
		total_expected += 1

	print("[RemoteLobbyPlayer2D] Loaded %d/%d walking animation textures for remote player" % [loaded_count, total_expected])

func _create_flipped_texture(original: Texture2D) -> ImageTexture:
	##Create a horizontally flipped version of a texture
	var image = original.get_image()
	image.flip_x()
	var flipped_texture = ImageTexture.new()
	flipped_texture.set_image(image)
	return flipped_texture

func _setup_walking_animation_system() -> void:
	##Set up the walking animation timer system for remote player
	print("[RemoteLobbyPlayer2D] Setting up walking animation system for remote player")

	# Create animation timer
	animation_timer = Timer.new()
	animation_timer.name = "RemoteWalkingAnimationTimer"
	animation_timer.wait_time = animation_speed
	animation_timer.timeout.connect(_on_walking_animation_timeout)
	add_child(animation_timer)

	# Don't autostart - only animate when walking
	animation_timer.autostart = false

	print("[RemoteLobbyPlayer2D] Walking animation system ready for remote player - Frame rate: %.1f FPS" % [1.0/animation_speed])

func _on_walking_animation_timeout() -> void:
	##Handle walking animation timer timeout - advance to next frame
	if not is_moving or current_animation_state == "idle":
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

func _update_walking_animation_from_movement() -> void:
	##Update walking animation state based on movement (using facing_direction)
	if not is_moving or facing_direction.length() == 0:
		# Stop walking animation and return to idle
		_set_animation_state("idle")
		return

	# Determine animation based on dominant movement direction
	var abs_x = abs(facing_direction.x)
	var abs_y = abs(facing_direction.y)

	var new_animation_state = "idle"

	# Prioritize horizontal movement for left/right animation
	if abs_x > abs_y:
		if facing_direction.x > 0:
			new_animation_state = "walking_right"
		else:
			new_animation_state = "walking_left"
	else:
		# Vertical movement
		if facing_direction.y < 0:
			new_animation_state = "walking_up"
		else:
			new_animation_state = "walking_down"

	_set_animation_state(new_animation_state)

func _set_animation_state(new_state: String) -> void:
	##Set the current animation state and handle transitions for remote player
	if current_animation_state == new_state:
		return  # No change needed

	var previous_state = current_animation_state
	current_animation_state = new_state

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
		return

	if player_sprite and current_frame < current_frames.size():
		player_sprite.texture = current_frames[current_frame]
