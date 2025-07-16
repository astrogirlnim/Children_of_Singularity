# SkyboxManager3D.gd
# Main skybox system controller for Children of the Singularity
# Manages multiple concentric rotating skybox layers for enhanced depth perception

class_name SkyboxManager3D
extends Node3D

## Signal emitted when skybox system is ready
signal skybox_ready()

## Export properties for configuration
@export var camera_reference: Camera3D
@export var enable_rotation: bool = true
@export var enable_performance_culling: bool = true
@export var idle_rotation_pause_time: float = 5.0  # Pause rotation after 5s idle

## Node references
var pivot_node: Node3D
var active_layers: Array = []

## Skybox layer configurations (seamless space backgrounds)
var layers_config: Array[Dictionary] = [
	{
		"name": "Shell_0_Stars_Seamless",
		"radius": 1500.0,  # Bright twinkling stars - furthest layer
		"texture_path": "res://assets/backgrounds/seamless/starfield_seamless.png",
		"rotation_speed": 0.3,  # Slow, majestic rotation
		"alpha": 1.0,  # Completely opaque for proper depth ordering
		"uv_scale": 12.0,  # Dense starfield tiling
		"is_overlay_layer": false,  # Base layer - no transparency needed
	}
]

## Idle detection system
var last_camera_position: Vector3 = Vector3.ZERO
var idle_timer: float = 0.0
var rotation_paused: bool = false

## Debug flag
var debug_logging: bool = true

func _ready() -> void:
	if debug_logging:
		print("[SkyboxManager3D] Initializing skybox system with %d layers" % layers_config.size())

	_setup_pivot_node()
	_create_skybox_layers()

	if debug_logging:
		print("[SkyboxManager3D] Skybox system ready with %d active layers" % active_layers.size())

	skybox_ready.emit()

func _process(delta: float) -> void:
	##Handle camera following and idle detection
	_update_pivot_position()
	_handle_idle_detection(delta)

func _setup_pivot_node() -> void:
	##Create and configure the pivot node that follows the camera
	pivot_node = Node3D.new()
	pivot_node.name = "SkyboxPivot"
	add_child(pivot_node)

	if debug_logging:
		print("[SkyboxManager3D] Pivot node created for camera following")

func _update_pivot_position() -> void:
	# Update pivot position to match camera position each frame
	if camera_reference and pivot_node:
		var camera_pos = camera_reference.global_position
		pivot_node.global_position = camera_pos

		# Debug print every 0.5 seconds for verification using more reliable timing
		if debug_logging:
			var current_time = Time.get_time_dict_from_system()
			var time_seconds = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
			if time_seconds % 1 == 0:  # Print every second instead of using fmod with fractional seconds
				if camera_pos != last_camera_position:
					print("[SkyboxManager3D] Pivot following camera at: %s" % camera_pos)

func _create_skybox_layers() -> void:
	# Create all skybox layers based on configuration
	if debug_logging:
		print("[SkyboxManager3D] Creating %d skybox shells" % layers_config.size())

	for i in range(layers_config.size()):
		var config = layers_config[i]
		_create_layer_from_config(config, i)

	if debug_logging:
		print("[SkyboxManager3D] All skybox layers created successfully")

func _create_layer_from_config(config: Dictionary, index: int) -> void:
	# Create a single skybox layer from configuration
	var layer_name = config.get("name", "Shell_%d" % index)

	if debug_logging:
		print("[SkyboxManager3D] Creating skybox layer: %s" % layer_name)

	# Create SkyboxLayer instance by loading the script
	var skybox_layer_script = load("res://scripts/SkyboxLayer.gd")
	var skybox_layer = skybox_layer_script.new()
	skybox_layer.name = layer_name

	# Configure layer properties
	skybox_layer.layer_radius = config.get("radius", 250.0)
	skybox_layer.rotation_speed = config.get("rotation_speed", 1.0)
	skybox_layer.layer_alpha = config.get("alpha", 1.0)
	skybox_layer.texture_path = config.get("texture_path", "")
	skybox_layer.layer_tint = config.get("tint", Color.WHITE)
	skybox_layer.uv_scale = config.get("uv_scale", 8.0)
	skybox_layer.use_random_tint = config.get("use_random_tint", false)
	skybox_layer.tint_hue_range = config.get("tint_hue_range", 30.0)
	skybox_layer.tint_saturation = config.get("tint_saturation", 0.2)
	skybox_layer.is_overlay_layer = config.get("is_overlay_layer", false)

	# Enable debug logging for layers
	skybox_layer.enable_debug_logging(debug_logging)

	# Add to pivot node so it follows camera
	pivot_node.add_child(skybox_layer)
	active_layers.append(skybox_layer)

	if debug_logging:
		print("[SkyboxManager3D] Layer '%s' created with radius %.1f" % [layer_name, skybox_layer.layer_radius])

func _handle_idle_detection(delta: float) -> void:
	# Handle idle detection and rotation pausing
	if not camera_reference or not enable_rotation:
		return

	var current_camera_pos: Vector3 = camera_reference.global_position

	# Check if camera has moved
	if current_camera_pos.distance_to(last_camera_position) > 0.1:
		# Camera moved, reset idle timer
		idle_timer = 0.0
		last_camera_position = current_camera_pos

		# Resume rotation if it was paused
		if rotation_paused:
			_resume_all_rotations()
			rotation_paused = false
			if debug_logging:
				print("[SkyboxManager3D] Camera movement detected, rotation resumed")
	else:
		# Camera is idle, increment timer
		idle_timer += delta

		# Pause rotation if idle for too long
		if idle_timer >= idle_rotation_pause_time and not rotation_paused:
			_pause_all_rotations()
			rotation_paused = true
			if debug_logging:
				print("[SkyboxManager3D] Camera idle for %.1fs, rotation paused" % idle_timer)

func _pause_all_rotations() -> void:
	# Pause rotation for all skybox layers
	for layer in active_layers:
		if layer and layer.has_method("pause_rotation"):
			layer.pause_rotation()

func _resume_all_rotations() -> void:
	# Resume rotation for all skybox layers
	for i in range(active_layers.size()):
		var layer = active_layers[i]
		if layer and layer.has_method("resume_rotation") and i < layers_config.size():
			var original_speed: float = layers_config[i].get("rotation_speed", 1.0)
			layer.resume_rotation(original_speed)

## Public configuration methods

func set_camera_reference(new_camera: Camera3D) -> void:
	# Set the camera reference for position following
	camera_reference = new_camera
	if debug_logging:
		print("[SkyboxManager3D] Camera reference set: %s" % (new_camera.name if new_camera else "null"))

func set_rotation_enabled(enabled: bool) -> void:
	# Enable or disable all layer rotations
	enable_rotation = enabled
	if not enabled:
		_pause_all_rotations()
		rotation_paused = true
	else:
		_resume_all_rotations()
		rotation_paused = false

	if debug_logging:
		print("[SkyboxManager3D] Rotation enabled: %s" % enabled)

func set_global_alpha(alpha: float) -> void:
	# Set alpha for all layers (multiplied with individual layer alphas)
	alpha = clamp(alpha, 0.0, 1.0)
	for i in range(active_layers.size()):
		var layer = active_layers[i]
		if layer and i < layers_config.size():
			var base_alpha: float = layers_config[i].get("alpha", 1.0)
			layer.set_layer_alpha(base_alpha * alpha)

	if debug_logging:
		print("[SkyboxManager3D] Global alpha set to: %.2f" % alpha)

func get_layer_count() -> int:
	# Get the number of active skybox layers
	return active_layers.size()

func get_layer_by_name(layer_name: String):
	# Get a skybox layer by name
	for layer in active_layers:
		if layer and layer.name == layer_name:
			return layer
	return null

## Debug and utility methods

func get_skybox_info() -> Dictionary:
	##Get skybox system configuration info for debugging
	var layer_info = []
	for layer in active_layers:
		if layer:
			layer_info.append(layer.get_layer_info())

	return {
		"layer_count": active_layers.size(),
		"rotation_enabled": enable_rotation,
		"rotation_paused": rotation_paused,
		"idle_timer": idle_timer,
		"camera_position": camera_reference.global_position if camera_reference else Vector3.ZERO,
		"layers": layer_info
	}

func enable_debug_logging(enabled: bool) -> void:
	##Enable or disable debug logging for manager and all layers
	debug_logging = enabled
	for layer in active_layers:
		if layer:
			layer.enable_debug_logging(enabled)

	if debug_logging:
		print("[SkyboxManager3D] Debug logging enabled for manager and all layers")

func toggle_skybox_visibility(skybox_visible: bool = true) -> void:
	## Toggle visibility of all skybox layers (for testing skybox interference)
	if debug_logging:
		print("[SkyboxManager3D] Toggling skybox visibility: ", skybox_visible)

	for layer in active_layers:
		if layer and is_instance_valid(layer):
			layer.visible = skybox_visible

	if debug_logging:
		print("[SkyboxManager3D] Skybox visibility set to: ", skybox_visible)
