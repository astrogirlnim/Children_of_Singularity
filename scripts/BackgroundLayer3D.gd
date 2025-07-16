# BackgroundLayer3D.gd
# Individual background layer component for Children of the Singularity 2.5D conversion
# Handles parallax properties and layer-specific behaviors

class_name BackgroundLayer3D
extends Node3D

## Signal emitted when layer is moved by parallax
signal layer_moved(new_position: Vector3)

## Signal emitted when layer visibility changes
signal layer_visibility_changed(visible: bool)

## Export properties for configuration
@export var layer_depth: float = -100.0
@export var parallax_factor: Vector2 = Vector2(0.1, 0.1)
@export var scroll_speed: Vector2 = Vector2.ZERO
@export var enable_auto_scroll: bool = false
@export var layer_alpha: float = 1.0

## Layer properties
var layer_name: String = ""
var layer_type: String = "plane"  # plane, objects, particles
var is_initialized: bool = false
var original_position: Vector3 = Vector3.ZERO

## Auto-scroll state
var scroll_time: float = 0.0

func _ready() -> void:
	_log_message("BackgroundLayer3D: Initializing layer '%s'" % name)
	original_position = position
	layer_name = name
	is_initialized = true
	_log_message("BackgroundLayer3D: Layer '%s' ready at depth %.1f" % [layer_name, layer_depth])

func _process(delta: float) -> void:
	"""Handle auto-scrolling if enabled"""
	if enable_auto_scroll and scroll_speed.length() > 0:
		scroll_time += delta
		_apply_auto_scroll(delta)

func _apply_auto_scroll(delta: float) -> void:
	"""Apply automatic scrolling movement"""
	var scroll_offset = Vector3(
		scroll_speed.x * delta,
		0,
		scroll_speed.y * delta
	)

	position += scroll_offset
	layer_moved.emit(position)

func set_layer_depth(depth: float) -> void:
	"""Set the layer depth and update position"""
	layer_depth = depth
	position.z = layer_depth
	_log_message("BackgroundLayer3D: Layer '%s' depth set to %.1f" % [layer_name, layer_depth])

func set_parallax_factor(factor: Vector2) -> void:
	"""Set the parallax factor for this layer"""
	parallax_factor = factor
	_log_message("BackgroundLayer3D: Layer '%s' parallax factor set to %s" % [layer_name, parallax_factor])

func set_auto_scroll(speed: Vector2) -> void:
	"""Enable auto-scrolling with specified speed"""
	scroll_speed = speed
	enable_auto_scroll = speed.length() > 0
	_log_message("BackgroundLayer3D: Layer '%s' auto-scroll set to %s" % [layer_name, scroll_speed])

func set_layer_alpha(alpha: float) -> void:
	"""Set the alpha transparency for all materials in this layer"""
	layer_alpha = clamp(alpha, 0.0, 1.0)
	_apply_alpha_to_children()
	_log_message("BackgroundLayer3D: Layer '%s' alpha set to %.2f" % [layer_name, layer_alpha])

func _apply_alpha_to_children() -> void:
	"""Apply alpha setting to all child nodes with materials"""
	_recursive_apply_alpha(self)

func _recursive_apply_alpha(node: Node) -> void:
	"""Recursively apply alpha to all materials in the node tree"""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		if mesh_instance.material_override:
			var material = mesh_instance.material_override
			if material is StandardMaterial3D:
				var std_material = material as StandardMaterial3D
				std_material.albedo_color.a = layer_alpha
	elif node is GPUParticles3D:
		var particles = node as GPUParticles3D
		if particles.material_override:
			var material = particles.material_override
			if material is StandardMaterial3D:
				var std_material = material as StandardMaterial3D
				std_material.albedo_color.a = layer_alpha

	# Recurse through children
	for child in node.get_children():
		_recursive_apply_alpha(child)

func reset_to_original_position() -> void:
	"""Reset layer to its original position"""
	position = original_position
	_log_message("BackgroundLayer3D: Layer '%s' reset to original position" % layer_name)

func move_by_parallax(camera_movement: Vector3, parallax_strength: float) -> void:
	"""Move layer based on camera movement and parallax settings"""
	var parallax_offset = Vector3(
		camera_movement.x * parallax_factor.x * parallax_strength,
		0,  # Don't parallax on Y axis for 2.5D consistency
		camera_movement.z * parallax_factor.y * parallax_strength
	)

	position += parallax_offset
	layer_moved.emit(position)

func set_visibility(visible: bool) -> void:
	"""Set layer visibility and emit signal"""
	if self.visible != visible:
		self.visible = visible
		layer_visibility_changed.emit(visible)
		_log_message("BackgroundLayer3D: Layer '%s' visibility set to %s" % [layer_name, visible])

func get_layer_info() -> Dictionary:
	"""Get comprehensive layer information"""
	return {
		"name": layer_name,
		"type": layer_type,
		"depth": layer_depth,
		"parallax_factor": parallax_factor,
		"position": position,
		"visible": visible,
		"alpha": layer_alpha,
		"auto_scroll_enabled": enable_auto_scroll,
		"scroll_speed": scroll_speed,
		"child_count": get_child_count()
	}

func _log_message(message: String) -> void:
	"""Log debug messages"""
	print("[%s] %s" % [Time.get_datetime_string_from_system(), message])
