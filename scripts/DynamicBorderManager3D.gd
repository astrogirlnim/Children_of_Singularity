# DynamicBorderManager3D.gd
# Dynamic border manager that positions border elements based on camera viewport edges
# Similar to how tile cards are positioned relative to camera bounds

class_name DynamicBorderManager3D
extends Node3D

## Signal emitted when border is repositioned
signal border_repositioned(viewport_bounds: Rect2)

## Export properties for configuration
@export var camera_reference: Camera3D
@export var border_texture: Texture2D
@export var border_distance_from_camera: float = 50.0  # How far from camera to place border
@export var border_scale: float = 1.0
@export var update_frequency: float = 0.1  # Update every 0.1 seconds for performance
@export var debug_show_viewport_corners: bool = false  # Show corner markers for debugging

## Border elements (Sprite3D nodes at viewport edges)
var border_top: Sprite3D
var border_bottom: Sprite3D
var border_left: Sprite3D
var border_right: Sprite3D

## Corner markers for debugging
var corner_markers: Array[MeshInstance3D] = []

## Internal state
var update_timer: float = 0.0
var last_camera_position: Vector3
var last_camera_rotation: Vector3
var last_camera_fov: float
var viewport_corners_world: Array[Vector3] = []

func _ready() -> void:
	_log_message("DynamicBorderManager3D: Initializing dynamic border system")
	_setup_border_elements()
	_setup_debug_markers()
	_update_border_positions()
	_log_message("DynamicBorderManager3D: Dynamic border system initialized")

func _process(delta: float) -> void:
	update_timer += delta

	if update_timer >= update_frequency:
		update_timer = 0.0
		_check_for_camera_changes()

func _setup_border_elements() -> void:
	##Create border sprite elements
	_log_message("DynamicBorderManager3D: Creating border elements")

	# Create top border
	border_top = _create_border_sprite("BorderTop")
	border_bottom = _create_border_sprite("BorderBottom")
	border_left = _create_border_sprite("BorderLeft")
	border_right = _create_border_sprite("BorderRight")

	_log_message("DynamicBorderManager3D: Created 4 border elements")

func _create_border_sprite(sprite_name: String) -> Sprite3D:
	##Create a single border sprite element
	var sprite = Sprite3D.new()
	sprite.name = sprite_name
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Always face camera like UI elements
	sprite.texture = border_texture
	sprite.pixel_size = 0.01 * border_scale
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Ensure visibility
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.visibility_range_end = 0.0
	sprite.visibility_range_begin = 0.0

	add_child(sprite)
	return sprite

func _setup_debug_markers() -> void:
	##Create debug markers for viewport corners
	if not debug_show_viewport_corners:
		return

	_log_message("DynamicBorderManager3D: Creating debug viewport corner markers")

	for i in range(4):
		var marker = MeshInstance3D.new()
		marker.name = "CornerMarker" + str(i)

		# Create a small sphere mesh for the marker
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.5
		sphere_mesh.height = 1.0
		marker.mesh = sphere_mesh

		# Create bright colored material
		var material = StandardMaterial3D.new()
		material.flags_unshaded = true
		material.albedo_color = Color.RED if i < 2 else Color.BLUE
		marker.material_override = material

		add_child(marker)
		corner_markers.append(marker)

func _check_for_camera_changes() -> void:
	##Check if camera properties have changed and update border if needed
	if not camera_reference:
		return

	var camera_pos = camera_reference.global_position
	var camera_rot = camera_reference.global_rotation
	var camera_fov = camera_reference.fov if camera_reference.projection == Camera3D.PROJECTION_PERSPECTIVE else 0.0

	# Check if significant changes occurred
	if (camera_pos.distance_to(last_camera_position) > 0.5 or
		camera_rot.distance_to(last_camera_rotation) > 0.01 or
		abs(camera_fov - last_camera_fov) > 1.0):

		_update_border_positions()

		# Store current values
		last_camera_position = camera_pos
		last_camera_rotation = camera_rot
		last_camera_fov = camera_fov

func _update_border_positions() -> void:
	##Calculate viewport edges in world space and position border elements
	if not camera_reference:
		return

	_calculate_viewport_corners_world()
	_position_border_elements()
	_update_debug_markers()

	# Emit signal with viewport bounds
	var viewport_bounds = _calculate_viewport_bounds_2d()
	border_repositioned.emit(viewport_bounds)

func _calculate_viewport_corners_world() -> void:
	##Calculate the four corners of the viewport in world space
	viewport_corners_world.clear()

	if not camera_reference:
		return

	# Get viewport size
	var viewport = camera_reference.get_viewport()
	var viewport_size = viewport.get_visible_rect().size

	# Calculate the four corners in NDC space (-1 to 1)
	var ndc_corners = [
		Vector2(-1, -1),  # Bottom-left
		Vector2(1, -1),   # Bottom-right
		Vector2(1, 1),    # Top-right
		Vector2(-1, 1)    # Top-left
	]

	# Convert NDC corners to world space at the border distance
	for ndc_corner in ndc_corners:
		var world_pos = _ndc_to_world_space(ndc_corner, border_distance_from_camera)
		viewport_corners_world.append(world_pos)

func _ndc_to_world_space(ndc_point: Vector2, distance: float) -> Vector3:
	##Convert NDC coordinates to world space at specified distance from camera
	if not camera_reference:
		return Vector3.ZERO

	# Get camera transform
	var camera_transform = camera_reference.global_transform
	var camera_pos = camera_transform.origin
	var camera_forward = -camera_transform.basis.z
	var camera_right = camera_transform.basis.x
	var camera_up = camera_transform.basis.y

	# Calculate the point at the specified distance
	var target_point = camera_pos + camera_forward * distance

	# Calculate viewport dimensions at that distance
	var half_height: float
	var half_width: float

	if camera_reference.projection == Camera3D.PROJECTION_PERSPECTIVE:
		# Perspective projection
		var fov_rad = deg_to_rad(camera_reference.fov)
		half_height = distance * tan(fov_rad * 0.5)
		var aspect_ratio = camera_reference.get_viewport().get_visible_rect().size.aspect()
		half_width = half_height * aspect_ratio
	else:
		# Orthogonal projection
		half_height = camera_reference.size * 0.5
		var aspect_ratio = camera_reference.get_viewport().get_visible_rect().size.aspect()
		half_width = half_height * aspect_ratio

	# Convert NDC to world position
	var world_offset = camera_right * (ndc_point.x * half_width) + camera_up * (ndc_point.y * half_height)
	return target_point + world_offset

func _position_border_elements() -> void:
	##Position border elements at viewport edges
	if viewport_corners_world.size() < 4:
		return

	# Extract corners (bottom-left, bottom-right, top-right, top-left)
	var bottom_left = viewport_corners_world[0]
	var bottom_right = viewport_corners_world[1]
	var top_right = viewport_corners_world[2]
	var top_left = viewport_corners_world[3]

	# Calculate viewport dimensions for scaling
	var viewport_width = bottom_left.distance_to(bottom_right)
	var viewport_height = bottom_left.distance_to(top_left)

	# Position border elements at viewport edges (billboarded, so no rotation needed)
	if border_top:
		border_top.global_position = (top_left + top_right) * 0.5
		border_top.scale = Vector3(viewport_width * 0.1, 0.5, 1)  # Wide and thin for top edge

	if border_bottom:
		border_bottom.global_position = (bottom_left + bottom_right) * 0.5
		border_bottom.scale = Vector3(viewport_width * 0.1, 0.5, 1)  # Wide and thin for bottom edge

	if border_left:
		border_left.global_position = (bottom_left + top_left) * 0.5
		border_left.scale = Vector3(0.5, viewport_height * 0.1, 1)  # Tall and thin for left edge

	if border_right:
		border_right.global_position = (bottom_right + top_right) * 0.5
		border_right.scale = Vector3(0.5, viewport_height * 0.1, 1)  # Tall and thin for right edge

func _update_debug_markers() -> void:
	##Update debug marker positions
	if not debug_show_viewport_corners or corner_markers.size() < 4:
		return

	for i in range(min(4, viewport_corners_world.size())):
		if i < corner_markers.size():
			corner_markers[i].global_position = viewport_corners_world[i]

func _calculate_viewport_bounds_2d() -> Rect2:
	##Calculate 2D viewport bounds for compatibility
	if viewport_corners_world.size() < 4:
		return Rect2()

	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF

	for corner in viewport_corners_world:
		min_x = min(min_x, corner.x)
		max_x = max(max_x, corner.x)
		min_z = min(min_z, corner.z)
		max_z = max(max_z, corner.z)

	return Rect2(min_x, min_z, max_x - min_x, max_z - min_z)

## Public API Methods

func set_camera_reference(camera: Camera3D) -> void:
	##Set the camera reference for viewport calculations
	camera_reference = camera
	_log_message("DynamicBorderManager3D: Camera reference set to: %s" % (camera.name if camera else "none"))
	_update_border_positions()

func set_border_texture(texture: Texture2D) -> void:
	##Set the border texture for all border elements
	border_texture = texture
	if border_top: border_top.texture = texture
	if border_bottom: border_bottom.texture = texture
	if border_left: border_left.texture = texture
	if border_right: border_right.texture = texture
	_log_message("DynamicBorderManager3D: Border texture updated")

func set_border_distance(distance: float) -> void:
	##Set the distance from camera where border appears
	border_distance_from_camera = distance
	_update_border_positions()
	_log_message("DynamicBorderManager3D: Border distance set to %.1f" % distance)

func set_border_scale(scale: float) -> void:
	##Set the scale of border elements
	border_scale = scale
	_setup_border_elements()  # Recreate with new scale
	_log_message("DynamicBorderManager3D: Border scale set to %.2f" % scale)

func enable_debug_markers(enabled: bool) -> void:
	##Enable or disable debug viewport corner markers
	debug_show_viewport_corners = enabled

	# Remove existing markers
	for marker in corner_markers:
		marker.queue_free()
	corner_markers.clear()

	if enabled:
		_setup_debug_markers()
		_update_debug_markers()

	_log_message("DynamicBorderManager3D: Debug markers %s" % ("enabled" if enabled else "disabled"))

func get_viewport_corners_world() -> Array[Vector3]:
	##Get the current viewport corners in world space
	return viewport_corners_world.duplicate()

func get_border_info() -> Dictionary:
	##Get information about current border state
	return {
		"camera_reference": camera_reference.name if camera_reference else "none",
		"border_distance": border_distance_from_camera,
		"border_scale": border_scale,
		"viewport_corners_count": viewport_corners_world.size(),
		"update_frequency": update_frequency,
		"debug_markers_enabled": debug_show_viewport_corners
	}

func _log_message(message: String) -> void:
	##Log message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	print("[%s] %s" % [timestamp, message])
