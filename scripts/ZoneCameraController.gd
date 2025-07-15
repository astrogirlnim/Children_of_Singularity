# ZoneCameraController.gd
# Camera controller for Children of the Singularity
# Handles camera zoom, following, and movement functionality

class_name ZoneCameraController
extends Node

## Signal emitted when camera zoom changes
signal zoom_changed(new_zoom: float)

## Signal emitted when camera bounds exceeded
signal bounds_exceeded(position: Vector2)

@export var camera_2d: Camera2D
@export var target_node: Node2D  # Usually the player ship

# Camera zoom settings
@export var default_zoom: float = 1.5
@export var min_zoom: float = 0.8
@export var max_zoom: float = 3.0
@export var zoom_speed: float = 2.0
@export var zoom_smoothing: float = 5.0

# Camera follow settings
@export var follow_speed: float = 5.0
@export var follow_smoothing: bool = true
@export var follow_offset: Vector2 = Vector2.ZERO

# Camera bounds
@export var use_bounds: bool = true
@export var bounds: Rect2 = Rect2(-1000, -1000, 2000, 2000)

# Internal state
var current_zoom: float = 1.5
var target_zoom: float = 1.5
var is_following: bool = true

func _ready() -> void:
	print("ZoneCameraController: Initializing camera controller")
	_initialize_camera()

func _process(delta: float) -> void:
	if not camera_2d:
		return

	_handle_zoom_input(delta)
	_update_zoom(delta)
	_update_camera_position(delta)
	_enforce_bounds()

func _initialize_camera() -> void:
	"""Initialize camera settings"""
	if not camera_2d:
		push_error("ZoneCameraController: Camera2D not assigned!")
		return

	current_zoom = default_zoom
	target_zoom = default_zoom
	camera_2d.zoom = Vector2.ONE * current_zoom

	print("ZoneCameraController: Camera initialized with zoom: %f" % current_zoom)

func _handle_zoom_input(delta: float) -> void:
	"""Handle zoom input from mouse wheel"""
	if Input.is_action_just_pressed("zoom_in"):
		zoom_in()
	elif Input.is_action_just_pressed("zoom_out"):
		zoom_out()

func _update_zoom(delta: float) -> void:
	"""Update camera zoom with smoothing"""
	if abs(current_zoom - target_zoom) > 0.01:
		current_zoom = lerp(current_zoom, target_zoom, zoom_smoothing * delta)
		camera_2d.zoom = Vector2.ONE * current_zoom
		zoom_changed.emit(current_zoom)

func _update_camera_position(delta: float) -> void:
	"""Update camera position to follow target"""
	if not target_node or not is_following:
		return

	var target_position = target_node.global_position + follow_offset

	if follow_smoothing:
		var new_position = camera_2d.global_position.lerp(target_position, follow_speed * delta)
		camera_2d.global_position = new_position
	else:
		camera_2d.global_position = target_position

func _enforce_bounds() -> void:
	"""Ensure camera stays within defined bounds"""
	if not use_bounds or not camera_2d:
		return

	var camera_pos = camera_2d.global_position
	var clamped_pos = Vector2(
		clamp(camera_pos.x, bounds.position.x, bounds.position.x + bounds.size.x),
		clamp(camera_pos.y, bounds.position.y, bounds.position.y + bounds.size.y)
	)

	if camera_pos != clamped_pos:
		camera_2d.global_position = clamped_pos
		bounds_exceeded.emit(camera_pos)

## Public API Methods

func zoom_in() -> void:
	"""Zoom camera in"""
	set_target_zoom(target_zoom + zoom_speed * 0.1)

func zoom_out() -> void:
	"""Zoom camera out"""
	set_target_zoom(target_zoom - zoom_speed * 0.1)

func set_target_zoom(new_zoom: float) -> void:
	"""Set target zoom level with clamping"""
	target_zoom = clamp(new_zoom, min_zoom, max_zoom)
	print("ZoneCameraController: Target zoom set to: %f" % target_zoom)

func set_zoom_instant(new_zoom: float) -> void:
	"""Set zoom instantly without smoothing"""
	target_zoom = clamp(new_zoom, min_zoom, max_zoom)
	current_zoom = target_zoom
	camera_2d.zoom = Vector2.ONE * current_zoom
	zoom_changed.emit(current_zoom)

func set_follow_target(new_target: Node2D) -> void:
	"""Set new target for camera to follow"""
	target_node = new_target
	print("ZoneCameraController: Follow target set to: %s" % (new_target.name if new_target else "none"))

func set_follow_enabled(enabled: bool) -> void:
	"""Enable or disable camera following"""
	is_following = enabled
	print("ZoneCameraController: Camera following %s" % ("enabled" if enabled else "disabled"))

func set_camera_position(position: Vector2) -> void:
	"""Set camera position directly"""
	if camera_2d:
		camera_2d.global_position = position

func get_camera_position() -> Vector2:
	"""Get current camera position"""
	if camera_2d:
		return camera_2d.global_position
	return Vector2.ZERO

func get_current_zoom() -> float:
	"""Get current zoom level"""
	return current_zoom

func set_bounds(new_bounds: Rect2) -> void:
	"""Set camera bounds"""
	bounds = new_bounds
	print("ZoneCameraController: Bounds set to: %s" % bounds)

func reset_camera() -> void:
	"""Reset camera to default settings"""
	set_zoom_instant(default_zoom)
	follow_offset = Vector2.ZERO
	is_following = true
	print("ZoneCameraController: Camera reset to defaults")
