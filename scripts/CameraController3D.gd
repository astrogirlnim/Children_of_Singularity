# CameraController3D.gd
# Mario Kart 8 style follow camera for Children of the Singularity
# Handles perspective camera positioned behind ship with smooth following and zoom

extends Node3D

## Camera configuration for Mario Kart 8 style
@export var camera_distance: float = 10.0        # Distance behind ship (Mario Kart 8 style)
@export var camera_height: float = 1.5           # Height above ship (lower for ground-level Mario Kart 8 feel)
@export var camera_fov: float = 65.0             # Field of view (degrees) - console racing standard
@export var follow_speed: float = 5.0            # Camera follow responsiveness
@export var rotation_follow_speed: float = 3.0   # Rotation following speed
@export var enable_smoothing: bool = true

## Zoom settings (now distance-based for perspective)
@export var zoom_min_distance: float = 6.0       # Closest zoom (Mario Kart 8 style)
@export var zoom_max_distance: float = 15.0      # Furthest zoom (Mario Kart 8 style)
@export var zoom_speed: float = 2.0              # Zoom speed multiplier

## Camera tilt settings
@export var enable_camera_tilt: bool = false     # Banking on turns
@export var tilt_amount: float = 10.0            # Max tilt angle (degrees)
@export var tilt_speed: float = 3.0              # Tilt response speed

## Camera shake settings
@export var shake_fade_speed: float = 5.0

@onready var camera: Camera3D = $Camera3D

var target: Node3D = null
var current_distance: float = 15.0               # Current zoom distance
var target_distance: float = 15.0               # Target zoom distance
var shake_strength: float = 0.0
var shake_timer: float = 0.0

# Ship tracking state
var ship_forward_direction: Vector3 = Vector3.FORWARD
var ship_velocity: Vector3 = Vector3.ZERO
var current_tilt: float = 0.0

func _ready() -> void:
	setup_mario_kart_camera()
	_log_message("CameraController3D: Mario Kart 8 style camera controller initialized")

func setup_mario_kart_camera() -> void:
	"""Configure the 3D camera for Mario Kart 8 style perspective"""
	_log_message("CameraController3D: Setting up Mario Kart 8 style perspective camera")

	# Create Camera3D if it doesn't exist
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)

	# Configure PERSPECTIVE projection (key change from orthogonal)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = camera_fov
	camera.near = 0.5   # Close enough for detailed view
	camera.far = 200.0  # Far enough for zone boundaries

	# Initialize distance-based zoom
	current_distance = camera_distance
	target_distance = camera_distance

	_log_message("CameraController3D: Perspective camera configured - FOV: %.1f, Distance: %.1f" % [camera.fov, current_distance])

func set_target(new_target: Node3D) -> void:
	"""Set the target ship for the camera to follow"""
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
	"""Update camera position and effects (Mario Kart 8 style)"""
	if target:
		_update_ship_tracking_data(delta)
		_update_mario_kart_camera_position(delta)

	_update_distance_zoom(delta)
	_update_camera_tilt(delta)
	_update_camera_shake(delta)

func _update_ship_tracking_data(delta: float) -> void:
	"""Update ship movement data for camera following"""
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
	"""Update camera position behind ship Mario Kart 8 style"""
	if not target:
		return

	# Calculate desired position behind ship
	var behind_offset = ship_forward_direction * current_distance
	var height_offset = Vector3.UP * camera_height
	var desired_position = target.global_position - behind_offset + height_offset

	# Smooth camera movement
	if enable_smoothing:
		global_position = global_position.lerp(desired_position, follow_speed * delta)
	else:
		global_position = desired_position

	# Make camera look upward like Mario Kart 8 - low angle looking ahead with ship in lower third
	var look_ahead_distance = 30.0  # Look ahead toward horizon
	var ship_forward = -target.transform.basis.z  # Ship's forward direction
	var look_target = target.global_position + ship_forward * look_ahead_distance + Vector3.UP * (camera_height + 25.0)  # Look even more upward to position ship in lower third
	look_at(look_target, Vector3.UP)

func _update_distance_zoom(delta: float) -> void:
	"""Update distance-based zoom system"""
	if abs(current_distance - target_distance) > 0.01:
		current_distance = lerp(current_distance, target_distance, 5.0 * delta)
		_log_message("CameraController3D: Zoom distance updated to %.1f" % current_distance)

func _update_camera_tilt(delta: float) -> void:
	"""Update camera tilt based on ship movement (if enabled)"""
	if not enable_camera_tilt:
		# Reset tilt if disabled
		if abs(current_tilt) > 0.01:
			current_tilt = lerp(current_tilt, 0.0, tilt_speed * delta)
			camera.rotation_degrees.z = current_tilt
		return

	# Calculate desired tilt based on ship's Y velocity
	var desired_tilt = 0.0
	if ship_velocity.length() > 0.1:
		# Tilt based on Y movement (upward movement = positive tilt)
		desired_tilt = ship_velocity.y * tilt_amount
		desired_tilt = clamp(desired_tilt, -tilt_amount, tilt_amount)

	# Smooth tilt transition
	current_tilt = lerp(current_tilt, desired_tilt, tilt_speed * delta)
	camera.rotation_degrees.z = current_tilt

func _update_camera_shake(delta: float) -> void:
	"""Update camera shake effect"""
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

func _handle_zoom_input(delta: float) -> void:
	"""Handle zoom input controls (distance-based)"""
	var zoom_input = 0.0

	if Input.is_action_pressed("zoom_in"):
		zoom_input = -1.0
	elif Input.is_action_pressed("zoom_out"):
		zoom_input = 1.0

	if zoom_input != 0.0:
		set_zoom_distance(target_distance + zoom_input * zoom_speed)

func set_zoom_distance(new_distance: float) -> void:
	"""Set camera zoom distance (replaces orthogonal size)"""
	target_distance = clamp(new_distance, zoom_min_distance, zoom_max_distance)
	_log_message("CameraController3D: Target zoom distance set to %.1f" % target_distance)

func zoom_in() -> void:
	"""Zoom camera in (decrease distance)"""
	set_zoom_distance(target_distance - zoom_speed)

func zoom_out() -> void:
	"""Zoom camera out (increase distance)"""
	set_zoom_distance(target_distance + zoom_speed)

func set_camera_fov(new_fov: float) -> void:
	"""Set camera field of view"""
	camera_fov = clamp(new_fov, 45.0, 120.0)
	if camera:
		camera.fov = camera_fov
		_log_message("CameraController3D: FOV set to %.1f degrees" % camera_fov)

func enable_tilt(enabled: bool) -> void:
	"""Enable or disable camera tilt on turns"""
	enable_camera_tilt = enabled
	_log_message("CameraController3D: Camera tilt %s" % ("enabled" if enabled else "disabled"))

func shake(intensity: float, duration: float) -> void:
	"""Apply camera shake effect"""
	shake_strength = intensity
	shake_timer = 0.0
	_log_message("CameraController3D: Camera shake applied - Intensity: %.2f, Duration: %.2f" % [intensity, duration])

	# Optional: Auto-fade the shake over duration
	if duration > 0:
		shake_fade_speed = intensity / duration

func set_follow_speeds(position_speed: float, rotation_speed: float) -> void:
	"""Set camera follow speeds"""
	follow_speed = position_speed
	rotation_follow_speed = rotation_speed
	_log_message("CameraController3D: Follow speeds set - Position: %.1f, Rotation: %.1f" % [follow_speed, rotation_follow_speed])

func reset_camera() -> void:
	"""Reset camera to default Mario Kart 8 settings"""
	target_distance = camera_distance
	current_distance = camera_distance
	current_tilt = 0.0
	shake_strength = 0.0
	set_camera_fov(80.0)
	_log_message("CameraController3D: Camera reset to Mario Kart 8 defaults")

func _on_target_position_changed(new_position: Vector3) -> void:
	"""Handle target position change signal"""
	# This is called when the target emits position_changed signal
	# We don't need to do anything here as _physics_process handles following
	pass

func get_camera_info() -> Dictionary:
	"""Get current camera information"""
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
		"tilt_enabled": enable_camera_tilt,
		"current_tilt": current_tilt,
		"ship_forward_direction": ship_forward_direction
	}

func _log_message(message: String) -> void:
	"""Log a message with timestamp"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)

# Input actions for zoom (mouse wheel)
func _input(event: InputEvent) -> void:
	"""Handle additional input events"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			match mouse_event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					zoom_in()
				MOUSE_BUTTON_WHEEL_DOWN:
					zoom_out()

	# Handle keyboard zoom input
	_handle_zoom_input(get_process_delta_time())
