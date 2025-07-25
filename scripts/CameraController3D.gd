# CameraController3D.gd
# Mario Kart 8 style follow camera for Children of the Singularity
# Features:
# - Perspective camera positioned behind ship with smooth following and zoom
# - Mario Kart 8 style camera banking (tilts when turning for G-force effect)
# - Ultra-low ground perspective with upward tilt for racing feel

extends Node3D

## Camera configuration for Mario Kart 8 style (close-up racing camera)
@export var camera_distance: float = 12.0        # Much closer for Mario Kart 8 intimacy
@export var camera_height: float = 3.0           # Lower height for dramatic ground-level perspective
@export var camera_fov: float = 85.0             # Wider FOV for more dramatic perspective (Mario Kart 8 style)
@export var follow_speed: float = 8.0            # Faster follow for responsive feel
@export var rotation_follow_speed: float = 4.0   # Faster rotation following
@export var enable_smoothing: bool = true

## Camera angle settings for Mario Kart 8 bottom-third positioning
@export var camera_pitch_angle: float = 8.0      # Slight upward tilt toward horizon (degrees)
@export var look_ahead_distance: float = 25.0    # How far ahead to look for horizon view

## Zoom settings (now distance-based for perspective)
@export var zoom_min_distance: float = 8.0       # Closest zoom (closer than before)
@export var zoom_max_distance: float = 16.0      # Furthest zoom (still closer than before)
@export var zoom_speed: float = 2.0              # Zoom speed multiplier

## Camera banking settings (Mario Kart 8 style)
@export var enable_camera_banking: bool = true   # Banking on turns like Mario Kart 8!
@export var banking_amount: float = 15.0         # Reduced for smoother effect (was 20.0)
@export var banking_speed: float = 3.0           # Slower for smoother transitions (was 6.0)

## Camera shake settings
@export var shake_fade_speed: float = 5.0

## Mouse rotation settings
@export_group("Mouse Rotation")
@export var enable_mouse_rotation: bool = true
@export var mouse_sensitivity: float = 0.002
@export var invert_mouse_y: bool = false
@export var invert_mouse_x: bool = false
@export var rotation_smoothing: float = 8.0

## Rotation limits
@export_group("Rotation Limits")
@export var max_pitch_up: float = -0.1    # Slight upward limit
@export var max_pitch_down: float = -1.4   # ~80 degrees down
@export var max_yaw_speed: float = 2.0     # Max rotation speed

@onready var camera: Camera3D = $Camera3D
@onready var inner_gimbal: Node3D = null  # Will be created dynamically

# Internal state variables
var target: CharacterBody3D
var ship_velocity: Vector3 = Vector3.ZERO
var ship_forward_direction: Vector3 = Vector3.FORWARD
var current_distance: float = 12.0
var target_distance: float = 12.0
var current_tilt: float = 0.0
var current_banking: float = 0.0  # Smoothed banking value for gradual transitions

# Mouse rotation state
var target_yaw: float = 0.0
var target_pitch: float = 0.0
var current_yaw: float = 0.0
var current_pitch: float = 0.0
var is_mouse_rotating: bool = false

# Camera shake state
var shake_strength: float = 0.0
var shake_timer: float = 0.0

# Debug logging control (reduced frequency to prevent spam)
var debug_log_timer: float = 0.0
var debug_log_interval: float = 5.0  # Log every 5 seconds instead of every frame

func _ready() -> void:
	setup_mario_kart_camera()
	_log_message("CameraController3D: Mario Kart 8 style camera controller initialized")

func setup_mario_kart_camera() -> void:
	##Configure the 3D camera for Mario Kart 8 style perspective with mouse rotation gimbal
	_log_message("CameraController3D: Setting up Mario Kart 8 style camera with mouse rotation gimbal")

	# Create inner gimbal for pitch control (X-axis rotation)
	if not inner_gimbal:
		inner_gimbal = Node3D.new()
		inner_gimbal.name = "InnerGimbal"
		add_child(inner_gimbal)
		_log_message("CameraController3D: Created inner gimbal for pitch control")

	# Create Camera3D if it doesn't exist and move it to inner gimbal
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		inner_gimbal.add_child(camera)
	elif camera.get_parent() != inner_gimbal:
		# Move existing camera to inner gimbal
		var old_parent = camera.get_parent()
		if old_parent:
			old_parent.remove_child(camera)
		inner_gimbal.add_child(camera)

	# FORCE PERSPECTIVE projection (override scene file)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = camera_fov
	camera.near = 0.5   # Increased from 0.3 for better depth precision
	camera.far = 2200.0  # Increased to provide proper buffer beyond skybox radius (1500.0)

	# Clear any manual transform from scene file - let script control everything
	camera.transform = Transform3D.IDENTITY

	# EXPLICITLY reset any rotation to prevent tilting
	camera.rotation = Vector3.ZERO
	camera.rotation_degrees = Vector3.ZERO

	# Reset current tilt state
	current_tilt = 0.0

	# Initialize distance-based zoom
	current_distance = camera_distance
	target_distance = camera_distance

	_log_message("CameraController3D: PERSPECTIVE camera configured - FOV: %.1f, Distance: %.1f, Height: %.1f" % [camera.fov, current_distance, camera_height])
	_log_message("CameraController3D: Camera rotation reset to prevent tilting issues")

func set_target(new_target: Node3D) -> void:
	##Set the target ship for the camera to follow
	target = new_target
	if target:
		_log_message("CameraController3D: Target set to %s" % target.name)
		# Connect to target's position_changed signal if available
		if target.has_signal("position_changed"):
			if not target.position_changed.is_connected(_on_target_position_changed):
				target.position_changed.connect(_on_target_position_changed)
	else:
		_log_message("CameraController3D: Target cleared")

func _physics_process(delta: float) -> void:
	##Update camera position and effects (Mario Kart 8 style with mouse rotation)
	# Update debug timer
	debug_log_timer += delta

	if target:
		_update_ship_tracking_data(delta)
		_update_mario_kart_camera_position(delta)

	# Mario Kart mode: No mouse rotation, camera follows ship naturally
	# _update_mouse_rotation(delta)  # Disabled for Mario Kart steering
	_update_distance_zoom(delta)
	_update_camera_tilt(delta)
	_update_camera_shake(delta)

func _update_ship_tracking_data(delta: float) -> void:
	##Update ship movement data for camera following
	if not target:
		return

	# Get ship's forward direction (assuming ship faces its movement direction)
	# For now, we'll use the ship's transform.basis.z as forward direction
	var new_forward = -target.transform.basis.z.normalized()

	# Smooth the direction change to avoid jitter
	ship_forward_direction = ship_forward_direction.lerp(new_forward, rotation_follow_speed * delta)

	# Track velocity for tilt effects (if enabled)
	var previous_position = global_position
	ship_velocity = (target.global_position - previous_position) / delta if delta > 0 else Vector3.ZERO

func _update_mario_kart_camera_position(delta: float) -> void:
	##Update camera position behind ship Mario Kart 8 style
	if not target:
		return

	# Calculate desired position behind ship with Mario Kart 8 close positioning
	var behind_offset = ship_forward_direction * current_distance
	var height_offset = Vector3.UP * camera_height
	var desired_position = target.global_position - behind_offset + height_offset

	# Smooth camera movement with faster response
	if enable_smoothing:
		global_position = global_position.lerp(desired_position, follow_speed * delta)
	else:
		global_position = desired_position

	# MARIO KART 8 CRITICAL FIX: Look ahead with slight upward angle for bottom-third ship positioning
	# This creates the classic low-chase camera that puts the ship in the bottom third
	var look_target = target.global_position + ship_forward_direction * look_ahead_distance

	# RAISE the look target slightly above ship level for bottom-third positioning
	# This subtle height difference creates the Mario Kart 8 perspective
	look_target.y = target.global_position.y + (camera_height * 0.5)  # Look slightly upward

	# DEBUG: Reduce logging frequency - only log periodically instead of every frame
	var should_log = debug_log_timer >= debug_log_interval
	if should_log:
		debug_log_timer = 0.0  # Reset timer
		_log_message("CameraController3D: Camera at %.1f,%.1f,%.1f looking at %.1f,%.1f,%.1f" %
			[global_position.x, global_position.y, global_position.z,
			 look_target.x, look_target.y, look_target.z])

	# Apply Mario Kart 8 style camera banking when turning (more aggressive)
	var banking_roll = 0.0
	if enable_camera_banking:  # Fixed: use the export variable instead of hardcoded false
		# Get the ship's steering input for Mario Kart style banking
		var ship_body = target as CharacterBody3D
		if ship_body and ship_body.has_method("get_current_steering_input"):
			# Use actual steering input for banking (Mario Kart style)
			var steering_input = ship_body.get_current_steering_input()
			banking_roll = steering_input * banking_amount
			# Only log banking when timer allows and values are significant
			if should_log and abs(steering_input) > 0.1:
				_log_message("CameraController3D: Mario Kart banking - Steering: %.2f, Banking: %.2f" % [steering_input, banking_roll])
		else:
			# Improved: smooth banking calculation with gradual detection
			var horizontal_velocity = Vector3(ship_velocity.x, 0, ship_velocity.z)
			var speed = horizontal_velocity.length()
			if speed > 0.5:  # Lower threshold for smoother activation
				var velocity_direction = horizontal_velocity.normalized()
				var forward_direction = Vector3(ship_forward_direction.x, 0, ship_forward_direction.z).normalized()
				var cross_product = forward_direction.cross(velocity_direction)

				# Smooth banking calculation - no sudden threshold
				var sideways_component = cross_product.y
				# Remove threshold - allow smooth gradual banking
				var speed_factor = clamp(speed / 8.0, 0.0, 1.0)  # Gradual speed scaling
				banking_roll = sideways_component * banking_amount * speed_factor

		banking_roll = clamp(banking_roll, -banking_amount, banking_amount)

	# Smooth banking transition - add interpolation for current banking
	current_banking = lerp(current_banking, banking_roll, banking_speed * delta)

	# Look at target with proper banking support using smoothed banking
	var up_vector = Vector3.UP
	if abs(current_banking) > 0.01:  # Only apply if there's meaningful banking
		# Rotate the up vector to create banking effect
		up_vector = up_vector.rotated(ship_forward_direction.normalized(), deg_to_rad(current_banking))

	# Debug ship forward direction (reduced frequency)
	if should_log:
		_log_message("CameraController3D: Ship forward direction: %.2f,%.2f,%.2f" %
			[ship_forward_direction.x, ship_forward_direction.y, ship_forward_direction.z])

	look_at(look_target, up_vector)

func _update_mouse_rotation(delta: float) -> void:
	##Update mouse-controlled camera rotation with smooth interpolation
	if not enable_mouse_rotation:
		return

	# Smooth interpolation towards target rotations
	current_yaw = lerp_angle(current_yaw, target_yaw, rotation_smoothing * delta)
	current_pitch = lerp_angle(current_pitch, target_pitch, rotation_smoothing * delta)

	# Apply rotations to gimbal system
	# Outer gimbal (this node) controls yaw (Y-axis rotation)
	rotation.y = current_yaw

	# Inner gimbal controls pitch (X-axis rotation) with limits
	if inner_gimbal:
		inner_gimbal.rotation.x = clamp(current_pitch, max_pitch_down, max_pitch_up)

	# Mario Kart style: Ship controls its own rotation, camera follows
	# No longer control ship rotation from camera

func _update_distance_zoom(delta: float) -> void:
	##Update distance-based zoom system
	if abs(current_distance - target_distance) > 0.01:
		current_distance = lerp(current_distance, target_distance, 5.0 * delta)

func _update_camera_tilt(delta: float) -> void:
	##Update camera tilt based on ship movement (re-enabled)
	if not enable_camera_banking:
		# Reset tilt if disabled
		if abs(current_tilt) > 0.01:
			current_tilt = lerp(current_tilt, 0.0, banking_speed * delta)
			camera.rotation_degrees.z = current_tilt
		return

	# DISABLED: Y-velocity based tilt was causing unwanted rotation during forward movement
	# Calculate desired tilt based on ship's Y velocity
	var desired_tilt = 0.0
	# Removed Y-velocity tilt to prevent unwanted rotation when moving straight
	# Only apply tilt if there's actual turning motion (handled by banking system above)

	# Apply smooth tilt transition
	current_tilt = lerp(current_tilt, desired_tilt, banking_speed * delta)

	# Apply tilt to camera
	if camera:
		camera.rotation_degrees.z = current_tilt

func _update_camera_shake(delta: float) -> void:
	##Update camera shake effect
	if shake_strength > 0:
		shake_timer += delta
		var shake_offset = Vector3(
			sin(shake_timer * 20.0) * shake_strength,
			cos(shake_timer * 15.0) * shake_strength * 0.5,
			0
		)
		camera.position = shake_offset

		# Fade out shake
		shake_strength = max(0, shake_strength - shake_fade_speed * delta)
	else:
		camera.position = Vector3.ZERO

func _handle_zoom_input(_delta: float) -> void:
	##Handle zoom input controls (distance-based)
	var zoom_input = 0.0

	if Input.is_action_pressed("zoom_in"):
		zoom_input = -1.0
	elif Input.is_action_pressed("zoom_out"):
		zoom_input = 1.0

	if zoom_input != 0.0:
		set_zoom_distance(target_distance + zoom_input * zoom_speed)

func set_zoom_distance(new_distance: float) -> void:
	##Set camera zoom distance (replaces orthogonal size)
	target_distance = clamp(new_distance, zoom_min_distance, zoom_max_distance)
	_log_message("CameraController3D: Target zoom distance set to %.1f" % target_distance)

func zoom_in() -> void:
	##Zoom camera in (decrease distance)
	set_zoom_distance(target_distance - zoom_speed)

func zoom_out() -> void:
	##Zoom camera out (increase distance)
	set_zoom_distance(target_distance + zoom_speed)

func set_camera_fov(new_fov: float) -> void:
	##Set camera field of view
	camera_fov = clamp(new_fov, 45.0, 120.0)
	if camera:
		camera.fov = camera_fov
		_log_message("CameraController3D: FOV set to %.1f degrees" % camera_fov)

func enable_banking(enabled: bool) -> void:
	##Enable or disable camera banking on turns (Mario Kart 8 style)
	enable_camera_banking = enabled
	_log_message("CameraController3D: Camera banking %s" % ("enabled" if enabled else "disabled"))

func shake(intensity: float, duration: float) -> void:
	##Apply camera shake effect
	shake_strength = intensity
	shake_timer = 0.0
	_log_message("CameraController3D: Camera shake applied - Intensity: %.2f, Duration: %.2f" % [intensity, duration])

	# Optional: Auto-fade the shake over duration
	if duration > 0:
		shake_fade_speed = intensity / duration

func set_follow_speeds(position_speed: float, rotation_speed: float) -> void:
	##Set camera follow speeds
	follow_speed = position_speed
	rotation_follow_speed = rotation_speed
	_log_message("CameraController3D: Follow speeds set - Position: %.1f, Rotation: %.1f" % [follow_speed, rotation_follow_speed])

func reset_camera() -> void:
	##Reset camera to default Mario Kart 8 settings
	target_distance = camera_distance
	current_distance = camera_distance
	current_tilt = 0.0
	shake_strength = 0.0
	set_camera_fov(85.0)  # Mario Kart 8 optimal FOV
	_log_message("CameraController3D: Camera reset to Mario Kart 8 defaults")

func _on_target_position_changed(_new_position: Vector3) -> void:
	##Handle target position change signal
	# This is called when the target emits position_changed signal
	# We don't need to do anything here as _physics_process handles following
	pass

func get_camera_info() -> Dictionary:
	##Get current camera information
	return {
		"target": target.name if target else "none",
		"position": global_position,
		"distance": current_distance,
		"target_distance": target_distance,
		"fov": camera_fov,
		"follow_speed": follow_speed,
		"rotation_follow_speed": rotation_follow_speed,
		"shake_strength": shake_strength,
		"smoothing_enabled": enable_smoothing,
		"banking_enabled": enable_camera_banking,
		"current_tilt": current_tilt,
		"ship_forward_direction": ship_forward_direction
	}

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)

# Input actions for zoom and mouse rotation
func _input(event: InputEvent) -> void:
	##Handle Mario Kart camera input (zoom only, no rotation)
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			match mouse_event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					zoom_in()
					_log_message("CameraController3D: Mario Kart zoom in")
				MOUSE_BUTTON_WHEEL_DOWN:
					zoom_out()
					_log_message("CameraController3D: Mario Kart zoom out")
				# Removed mouse rotation - Mario Kart uses steering keys only

	# Handle keyboard zoom input
	_handle_zoom_input(get_process_delta_time())
