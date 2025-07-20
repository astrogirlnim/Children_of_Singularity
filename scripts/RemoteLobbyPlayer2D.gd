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

# Visual components
@onready var player_sprite: Sprite2D = $RemotePlayerSprite2D
@onready var player_label: Label = $PlayerLabel
@onready var connection_indicator: ColorRect = $ConnectionIndicator

# Animation and visual state
var facing_direction: Vector2 = Vector2.DOWN
var is_moving: bool = false
var sprite_scale: Vector2 = Vector2.ONE
var label_offset: Vector2 = Vector2(0, -60)

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
	_setup_visual_components()
	_setup_interpolation()
	_play_spawn_effect()

func _physics_process(delta: float) -> void:
	if interpolation_enabled and smooth_movement:
		_update_position_interpolation(delta)

	time_since_last_update += delta
	_update_visual_state()

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
	"""Setup visual components for the remote player"""
	print("[RemoteLobbyPlayer2D] Setting up visual components")

	# Setup player sprite
	if not player_sprite:
		player_sprite = Sprite2D.new()
		player_sprite.name = "RemotePlayerSprite2D"
		add_child(player_sprite)

	# Load the same sprite as local player
	var sprite_texture = preload("res://assets/schlorp_guy_sprite.png")
	player_sprite.texture = sprite_texture

	# Scale to match local player (make slightly smaller to distinguish)
	sprite_scale = Vector2(0.08, 0.08)  # Slightly smaller than local player
	player_sprite.scale = sprite_scale

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
