# SkyboxLayer.gd
# Individual skybox layer that creates an inside-out sphere with texture mapping
# Part of the skybox-based background revamp for Children of the Singularity

class_name SkyboxLayer
extends MeshInstance3D

## Layer configuration properties
@export var layer_radius: float = 100.0
@export var rotation_speed: float = 1.0  # Degrees per second
@export var layer_alpha: float = 1.0
@export var texture_path: String = ""
@export var layer_tint: Color = Color.WHITE
@export var uv_scale: float = 8.0  # Configurable UV tiling scale
@export var use_random_tint: bool = false  # Enable random color variations
@export var tint_hue_range: float = 30.0  # Hue variation range in degrees (0-360)
@export var tint_saturation: float = 0.2  # Color saturation strength

## Internal references
var sphere_mesh: SphereMesh
var material: StandardMaterial3D
var initial_rotation: Vector3 = Vector3.ZERO

## Debug flag
var debug_logging: bool = true

func _ready() -> void:
	if debug_logging:
		print("[SkyboxLayer] Initializing skybox layer with radius: %.1f" % layer_radius)

	_create_inside_out_sphere()
	_setup_material()
	_load_texture()

	if debug_logging:
		print("[SkyboxLayer] Sphere generated and configured")

func _process(delta: float) -> void:
	# Rotate the layer based on rotation_speed
	if rotation_speed != 0.0:
		rotation_degrees.y += rotation_speed * delta

func _create_inside_out_sphere() -> SphereMesh:
	## Create a SphereMesh with flipped normals for inside-out rendering
	sphere_mesh = SphereMesh.new()

	# Configure sphere geometry
	sphere_mesh.radius = layer_radius
	sphere_mesh.height = layer_radius * 2.0
	sphere_mesh.radial_segments = 64  # Higher resolution for large skybox spheres
	sphere_mesh.rings = 32  # More rings for better tiling and detail

	# Flip normals by setting flip_faces to true
	sphere_mesh.flip_faces = true

	# Assign the mesh to this MeshInstance3D
	mesh = sphere_mesh

	if debug_logging:
		print("[SkyboxLayer] Created inside-out sphere mesh with %d radial segments, radius: %.1f" % [sphere_mesh.radial_segments, layer_radius])

	return sphere_mesh

func _setup_material() -> void:
	## Set up the material for the skybox layer
	material = StandardMaterial3D.new()

	# Configure material for skybox rendering
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Don't cull faces since we're inside
	material.flags_unshaded = true  # No lighting calculations needed
	material.flags_do_not_receive_shadows = true
	material.flags_disable_ambient_light = true

	# Critical: Configure for skybox rendering (render behind everything else)
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED  # Don't write to depth buffer
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED

	# Configure transparency for PNG alpha channel support
	material.flags_transparent = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX

	# Critical: Set render priority to ensure skybox renders before game objects
	# Note: In Godot 4.4, render priority is handled differently for transparent materials

	# Ensure proper render order for layered skyboxes
	material.vertex_color_use_as_albedo = false
	material.vertex_color_is_srgb = false

	# Apply color tinting (with optional random variations)
	var final_tint = layer_tint
	if use_random_tint:
		final_tint = _generate_random_tint()

	# Use alpha for the albedo color but keep material opaque
	material.albedo_color = Color(final_tint.r, final_tint.g, final_tint.b, layer_alpha)

	# Apply material to mesh
	set_surface_override_material(0, material)

	if debug_logging:
		print("[SkyboxLayer] Material configured with alpha: %.2f, tint: %s" % [layer_alpha, layer_tint])

func _load_texture() -> void:
	## Load and apply texture from texture_path
	if texture_path.is_empty():
		if debug_logging:
			print("[SkyboxLayer] No texture path specified, using solid color")
		return

	# Try to load the texture
	var texture = load(texture_path) as Texture2D
	if texture:
		material.albedo_texture = texture

		# Configure UV scaling for texture tiling
		# Use the configurable uv_scale property for precise control
		material.uv1_scale = Vector3(uv_scale, uv_scale, 1.0)
		material.uv1_offset = Vector3.ZERO

		if debug_logging:
			print("[SkyboxLayer] Loaded texture: %s with UV scale: %.2f" % [texture_path, uv_scale])
	else:
		push_warning("[SkyboxLayer] Failed to load texture: %s" % texture_path)
		if debug_logging:
			print("[SkyboxLayer] Using fallback solid color for missing texture")

## Public configuration methods

func set_layer_radius(new_radius: float) -> void:
	## Update the sphere radius
	layer_radius = new_radius
	if sphere_mesh:
		sphere_mesh.radius = new_radius
		sphere_mesh.height = new_radius * 2.0
		if debug_logging:
			print("[SkyboxLayer] Updated radius to: %.1f" % new_radius)

func set_rotation_speed(new_speed: float) -> void:
	## Update the rotation speed in degrees per second
	rotation_speed = new_speed
	if debug_logging:
		print("[SkyboxLayer] Updated rotation speed to: %.2f deg/s" % new_speed)

func set_layer_alpha(new_alpha: float) -> void:
	## Update the layer transparency
	layer_alpha = clamp(new_alpha, 0.0, 1.0)
	if material:
		material.albedo_color.a = layer_alpha
		if layer_alpha < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if debug_logging:
			print("[SkyboxLayer] Updated alpha to: %.2f" % layer_alpha)

func set_layer_tint(new_tint: Color) -> void:
	## Update the layer color tint
	layer_tint = new_tint
	if material:
		material.albedo_color = new_tint
		material.albedo_color.a = layer_alpha  # Preserve alpha
		if debug_logging:
			print("[SkyboxLayer] Updated tint to: %s" % new_tint)

func set_texture(new_texture_path: String) -> void:
	## Update the texture for this layer
	texture_path = new_texture_path
	_load_texture()

func pause_rotation() -> void:
	## Pause the layer rotation
	rotation_speed = 0.0
	if debug_logging:
		print("[SkyboxLayer] Rotation paused")

func resume_rotation(speed: float) -> void:
	## Resume rotation at specified speed
	rotation_speed = speed
	if debug_logging:
		print("[SkyboxLayer] Rotation resumed at %.2f deg/s" % speed)

## Debug and utility methods

func get_layer_info() -> Dictionary:
	## Get layer configuration info for debugging
	return {
		"radius": layer_radius,
		"rotation_speed": rotation_speed,
		"alpha": layer_alpha,
		"tint": layer_tint,
		"texture_path": texture_path,
		"position": global_position,
		"rotation": rotation_degrees
	}

func enable_debug_logging(enabled: bool) -> void:
	## Enable or disable debug logging for this layer
	debug_logging = enabled

func _generate_random_tint() -> Color:
	## Generate a random color tint based on hue range and saturation settings
	# Start with the base tint
	var base_hue = layer_tint.h
	var base_sat = layer_tint.s
	var base_val = layer_tint.v

	# Generate random hue variation within specified range
	var hue_variation = (randf() - 0.5) * 2.0 * (tint_hue_range / 360.0)
	var new_hue = fmod(base_hue + hue_variation, 1.0)
	if new_hue < 0.0:
		new_hue += 1.0

	# Apply saturation boost for more vivid colors
	var new_saturation = clamp(base_sat + tint_saturation, 0.0, 1.0)

	# Create the final tinted color
	var random_tint = Color.from_hsv(new_hue, new_saturation, base_val)

	if debug_logging:
		print("[SkyboxLayer] Generated random tint - Hue: %.2f, Sat: %.2f, Val: %.2f" % [new_hue, new_saturation, base_val])

	return random_tint
