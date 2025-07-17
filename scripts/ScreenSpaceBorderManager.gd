# ScreenSpaceBorderManager.gd
# Screen-space border manager that creates border overlays at viewport edges
# Uses Control nodes for proper screen-space positioning like other UI elements

class_name ScreenSpaceBorderManager
extends Control

## Signal emitted when border is repositioned
signal border_repositioned(viewport_size: Vector2)

## Export properties for configuration
@export var border_texture: Texture2D
@export var border_width: int = 20  # Width of border in pixels
@export var border_opacity: float = 1.0
@export var border_tint: Color = Color.WHITE
@export var update_on_resize: bool = true

## Border element (Single TextureRect for entire border frame)
var border_frame: TextureRect

## Internal state
var last_viewport_size: Vector2

func _ready() -> void:
	_log_message("ScreenSpaceBorderManager: Initializing screen-space border system")

	# Set up this control to fill the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input

	_setup_border_elements()
	_update_border_positions()

	# Connect to viewport resize
	if update_on_resize:
		get_viewport().size_changed.connect(_on_viewport_resized)

	_log_message("ScreenSpaceBorderManager: Screen-space border system initialized")

func _setup_border_elements() -> void:
	##Create border UI element for entire frame
	_log_message("ScreenSpaceBorderManager: Creating border frame element")

	# Create single border frame element
	border_frame = _create_border_element("BorderFrame")

	_log_message("ScreenSpaceBorderManager: Created border frame element")

func _create_border_element(element_name: String) -> TextureRect:
	##Create a single border UI element
	var border_rect = TextureRect.new()
	border_rect.name = element_name
	border_rect.texture = border_texture
	border_rect.modulate = border_tint
	border_rect.modulate.a = border_opacity
	border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	border_rect.stretch_mode = TextureRect.STRETCH_TILE  # Scale texture to fill exact control size
	border_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL  # Force control to expand to fit content
	border_rect.z_index = 1000  # Ensure it's the topmost UI element

	# Initialize with zero size - will be set properly in _update_border_positions
	border_rect.position = Vector2.ZERO
	border_rect.size = Vector2.ZERO

	# CRITICAL: Reset anchors to prevent automatic sizing
	border_rect.anchor_left = 0.0
	border_rect.anchor_top = 0.0
	border_rect.anchor_right = 0.0
	border_rect.anchor_bottom = 0.0

	# Force the control to NOT auto-size based on texture
	border_rect.custom_minimum_size = Vector2.ZERO

	add_child(border_rect)
	return border_rect

func _update_border_positions() -> void:
	##Update border frame for viewport changes and manually scale to exact window dimensions
	var viewport_size = get_viewport().get_visible_rect().size

	if viewport_size == Vector2.ZERO:
		return

	_log_message("ScreenSpaceBorderManager: Updating border frame for viewport size: %s" % viewport_size)

	# Manually calculate and set border dimensions to exactly match game window
	if border_frame and border_texture:
		var texture_size = border_texture.get_size()
		_log_message("ScreenSpaceBorderManager: Border texture original size: %s" % texture_size)
		_log_message("ScreenSpaceBorderManager: Target window size: %s" % viewport_size)

		# Set border frame to exact window dimensions
		border_frame.position = Vector2.ZERO
		border_frame.size = viewport_size

		# Force the TextureRect to respect our manual sizing - use multiple approaches
		border_frame.set_position(Vector2.ZERO)
		border_frame.set_size(viewport_size)
		border_frame.custom_minimum_size = viewport_size  # Force minimum size to viewport

		# Deferred call to ensure size sticks after node is fully initialized
		border_frame.call_deferred("set_size", viewport_size)
		border_frame.call_deferred("set_position", Vector2.ZERO)
		border_frame.call_deferred("set_custom_minimum_size", viewport_size)

		border_frame.queue_redraw()

		# Debug: Check if TextureRect is actually the size we set it to
		var actual_rect = border_frame.get_rect()
		var is_larger_than_viewport = actual_rect.size.x > viewport_size.x or actual_rect.size.y > viewport_size.y
		var extends_beyond = actual_rect.position != Vector2.ZERO or actual_rect.size != viewport_size

		_log_message("ScreenSpaceBorderManager: === BORDER SIZE COMPARISON ===")
		_log_message("ScreenSpaceBorderManager: Viewport size: %s" % viewport_size)
		_log_message("ScreenSpaceBorderManager: TextureRect actual size: %s" % actual_rect.size)
		_log_message("ScreenSpaceBorderManager: TextureRect actual position: %s" % actual_rect.position)
		_log_message("ScreenSpaceBorderManager: Is TextureRect larger than viewport? %s" % is_larger_than_viewport)
		_log_message("ScreenSpaceBorderManager: Does TextureRect extend beyond viewport? %s" % extends_beyond)
		_log_message("ScreenSpaceBorderManager: Border anchors: L:%s T:%s R:%s B:%s" % [border_frame.anchor_left, border_frame.anchor_top, border_frame.anchor_right, border_frame.anchor_bottom])

		# Calculate scale factors for manual scaling information
		var scale_x = viewport_size.x / texture_size.x if texture_size.x > 0 else 1.0
		var scale_y = viewport_size.y / texture_size.y if texture_size.y > 0 else 1.0

		_log_message("ScreenSpaceBorderManager: Texture scaling - X: %.3f, Y: %.3f" % [scale_x, scale_y])

	last_viewport_size = viewport_size
	border_repositioned.emit(viewport_size)

func _on_viewport_resized() -> void:
	##Handle viewport resize events
	_log_message("ScreenSpaceBorderManager: Viewport resized, updating border positions")
	call_deferred("_update_border_positions")  # Defer to next frame to ensure proper size calculation

## Public API Methods

func set_border_texture(texture: Texture2D) -> void:
	##Set the border texture for the border frame
	border_texture = texture
	if border_frame: border_frame.texture = texture
	_log_message("ScreenSpaceBorderManager: Border texture updated")

func set_border_width(width: int) -> void:
	##Set the width of border (kept for compatibility, but not used in full-frame mode)
	border_width = width
	_log_message("ScreenSpaceBorderManager: Border width set to %d pixels (full-frame mode)" % width)

func set_border_opacity(opacity: float) -> void:
	##Set the opacity of border frame
	border_opacity = clamp(opacity, 0.0, 1.0)

	if border_frame: border_frame.modulate.a = border_opacity

	_log_message("ScreenSpaceBorderManager: Border opacity set to %.2f" % border_opacity)

func set_border_tint(tint: Color) -> void:
	##Set the tint color of border frame
	border_tint = tint

	if border_frame:
		border_frame.modulate = tint
		border_frame.modulate.a = border_opacity

	_log_message("ScreenSpaceBorderManager: Border tint set to %s" % tint)

func set_border_visible(visible: bool) -> void:
	##Show or hide border frame
	if border_frame: border_frame.visible = visible

	_log_message("ScreenSpaceBorderManager: Border visibility set to %s" % visible)

func set_individual_border_visible(border_name: String, visible: bool) -> void:
	##Show or hide border frame (individual control not available in full-frame mode)
	_log_message("ScreenSpaceBorderManager: Individual border control not available in full-frame mode")
	set_border_visible(visible)

func set_stretch_mode(stretch_mode: TextureRect.StretchMode) -> void:
	##Set the stretch mode for border scaling
	if border_frame:
		border_frame.stretch_mode = stretch_mode
		var mode_name = _get_stretch_mode_name(stretch_mode)
		_log_message("ScreenSpaceBorderManager: Border stretch mode set to %s" % mode_name)

func _get_stretch_mode_name(stretch_mode: TextureRect.StretchMode) -> String:
	##Get human-readable name for stretch mode
	match stretch_mode:
		TextureRect.STRETCH_TILE:
			return "STRETCH_TILE"
		TextureRect.STRETCH_KEEP:
			return "STRETCH_KEEP"
		TextureRect.STRETCH_KEEP_CENTERED:
			return "STRETCH_KEEP_CENTERED"
		TextureRect.STRETCH_KEEP_ASPECT:
			return "STRETCH_KEEP_ASPECT"
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			return "STRETCH_KEEP_ASPECT_CENTERED"
		TextureRect.STRETCH_KEEP_ASPECT_COVERED:
			return "STRETCH_KEEP_ASPECT_COVERED"
		_:
			return "UNKNOWN"

func get_border_info() -> Dictionary:
	##Get information about current border state
	return {
		"border_width": border_width,
		"border_opacity": border_opacity,
		"border_tint": border_tint,
		"viewport_size": last_viewport_size,
		"update_on_resize": update_on_resize,
		"border_visible": border_frame.visible if border_frame else false
	}

func _log_message(message: String) -> void:
	##Log message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	print("[%s] %s" % [timestamp, message])
