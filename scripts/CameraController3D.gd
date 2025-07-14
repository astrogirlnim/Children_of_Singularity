# CameraController3D.gd
# Smooth follow camera for 2.5D perspective in Children of the Singularity
# Handles camera movement, zoom, and effects for 3D gameplay

extends Node3D

## Camera configuration
@export var follow_speed: float = 5.0
@export var camera_distance: float = 25.0
@export var camera_height: float = 25.0
@export var look_angle: float = -45.0  # Degrees
@export var enable_smoothing: bool = true

## Zoom settings
@export var default_zoom: float = 80.0
@export var min_zoom: float = 20.0
@export var max_zoom: float = 120.0
@export var zoom_speed: float = 5.0

## Camera shake settings
@export var shake_fade_speed: float = 5.0

@onready var camera: Camera3D = $Camera3D

var target: Node3D = null
var camera_offset: Vector3
var current_zoom: float = 80.0
var shake_strength: float = 0.0
var shake_timer: float = 0.0

func _ready() -> void:
	setup_camera()
	calculate_offset()
	_log_message("CameraController3D: 3D camera controller initialized")

func setup_camera() -> void:
	"""Configure the 3D camera for 2.5D gameplay"""
	_log_message("CameraController3D: Setting up 3D camera")

	# Create Camera3D if it doesn't exist
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)

	# Configure orthogonal projection (no perspective distortion)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = default_zoom
	camera.near = 0.1
	camera.far = 200.0

	# Set initial rotation for 2.5D view
	camera.rotation_degrees.x = look_angle

	current_zoom = default_zoom
	_log_message("CameraController3D: Camera configured with orthogonal projection, size: %.1f" % current_zoom)

func calculate_offset() -> void:
	"""Calculate camera offset based on angle and distance"""
	var angle_rad = deg_to_rad(look_angle)
	camera_offset = Vector3(
		0,
		camera_height,
		camera_distance
	)
	_log_message("CameraController3D: Camera offset calculated - %s" % camera_offset)

func set_target(new_target: Node3D) -> void:
	"""Set the target node for the camera to follow"""
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
	"""Update camera position and effects"""
	if target:
		_update_camera_position(delta)

	_update_camera_shake(delta)
	_handle_zoom_input(delta)

func _update_camera_position(delta: float) -> void:
	"""Update camera position to follow target"""
	if not target:
		return

	var desired_position = target.global_position + camera_offset

	if enable_smoothing:
		global_position = global_position.lerp(
			desired_position,
			follow_speed * delta
		)
	else:
		global_position = desired_position

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
	"""Handle zoom input controls - disabled for now"""
	# TODO: Add zoom_in and zoom_out actions to input map
	# For now, zoom will be controlled via mouse wheel and API calls
	pass

func set_zoom(new_zoom: float) -> void:
	"""Set camera zoom level"""
	current_zoom = clamp(new_zoom, min_zoom, max_zoom)
	if camera:
		camera.size = current_zoom
		_log_message("CameraController3D: Zoom set to %.1f" % current_zoom)

func shake(intensity: float, duration: float) -> void:
	"""Apply camera shake effect"""
	shake_strength = intensity
	shake_timer = 0.0
	_log_message("CameraController3D: Camera shake applied - Intensity: %.2f, Duration: %.2f" % [intensity, duration])

	# Optional: Auto-fade the shake over duration
	if duration > 0:
		shake_fade_speed = intensity / duration

func set_follow_speed(new_speed: float) -> void:
	"""Set camera follow speed"""
	follow_speed = new_speed
	_log_message("CameraController3D: Follow speed set to %.1f" % follow_speed)

func set_camera_angle(new_angle: float) -> void:
	"""Set camera look angle"""
	look_angle = new_angle
	if camera:
		camera.rotation_degrees.x = look_angle
		calculate_offset()  # Recalculate offset with new angle
		_log_message("CameraController3D: Camera angle set to %.1f degrees" % look_angle)

func reset_camera() -> void:
	"""Reset camera to default settings"""
	set_zoom(default_zoom)
	set_camera_angle(-45.0)
	shake_strength = 0.0
	_log_message("CameraController3D: Camera reset to defaults")

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
		"zoom": current_zoom,
		"angle": look_angle,
		"follow_speed": follow_speed,
		"shake_strength": shake_strength,
		"smoothing_enabled": enable_smoothing
	}

func _log_message(message: String) -> void:
	"""Log a message with timestamp"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)

# Input actions for zoom (these should be defined in Input Map)
func _input(event: InputEvent) -> void:
	"""Handle additional input events"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			match mouse_event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					set_zoom(current_zoom - 5.0)
				MOUSE_BUTTON_WHEEL_DOWN:
					set_zoom(current_zoom + 5.0)
