# StartupScreen.gd
# Startup screen for Children of the Singularity
# Displays animated intro loop until player presses any key

class_name StartupScreen
extends Control

## Signal emitted when startup screen should transition to main game
signal startup_complete()

## Export properties for configuration
@export var fade_duration: float = 1.0
@export var show_press_key_delay: float = 3.0  # Show "Press any key" after 3 seconds

## Node references
@onready var background: ColorRect = $Background
@onready var video_display: TextureRect = $VideoDisplay
@onready var press_key_label: Label = $PressAnyKeyLabel
@onready var fade_overlay: ColorRect = $FadeOverlay

## Animation management
var startup_animation_textures: Array[Texture2D] = []
var current_frame: int = 1
var animation_timer: Timer
var animation_speed: float = 1.0 / 15.0  # 15 FPS for smooth animation
var total_frames: int = 60
var is_animating: bool = true

## State management
var is_transitioning: bool = false
var press_key_timer: float = 0.0
var key_prompt_visible: bool = false

## Loading system
var loading_screen_scene: PackedScene
var loading_screen_instance: LoadingScreen

func _ready() -> void:
	print("StartupScreen: Starting animation startup sequence")
	_setup_startup_screen()
	_load_startup_animation()
	_setup_animation_timer()
	_start_animation_loop()
	_preload_loading_screen()

func _exit_tree() -> void:
	# Clean up animation resources when node is freed
	if animation_timer and is_instance_valid(animation_timer):
		animation_timer.queue_free()
	print("StartupScreen: Cleaned up animation resources")

func _process(delta: float) -> void:
	# Handle press key label visibility
	if not key_prompt_visible and not is_transitioning:
		press_key_timer += delta
		if press_key_timer >= show_press_key_delay:
			_show_press_key_label()

func _input(event: InputEvent) -> void:
	# Detect any input to transition to main game
	if is_transitioning:
		return

	var should_transition = false

	if event is InputEventKey and event.pressed:
		should_transition = true
		print("StartupScreen: Key pressed: %s" % event.as_text())
	elif event is InputEventMouseButton and event.pressed:
		should_transition = true
		print("StartupScreen: Mouse clicked")
	elif event is InputEventJoypadButton and event.pressed:
		should_transition = true
		print("StartupScreen: Gamepad button pressed")

	if should_transition:
		_start_transition()

func _setup_startup_screen() -> void:
	# Initialize startup screen components
	print("StartupScreen: Setting up startup screen UI")

	# Hide press key label initially
	if press_key_label:
		press_key_label.visible = false
		press_key_label.modulate = Color.TRANSPARENT

	# Set up fade overlay for smooth transitions
	if fade_overlay:
		fade_overlay.color = Color.BLACK
		fade_overlay.modulate = Color.TRANSPARENT

	# Set background to deep space theme
	if background:
		background.color = Color(0.02, 0.02, 0.05, 1.0)  # Very dark space blue

	# Configure video display for proper frame scaling
	if video_display:
		print("StartupScreen: Configuring VideoDisplay...")
		video_display.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		video_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		video_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

		# Ensure it's visible and properly sized for full viewport
		video_display.visible = true
		video_display.modulate = Color.WHITE

		print("StartupScreen: VideoDisplay configured - visible: %s, size: %s" % [video_display.visible, video_display.size])
	else:
		print("StartupScreen: ERROR - VideoDisplay node not found!")

	print("StartupScreen: UI setup complete")

func _load_startup_animation() -> void:
	# Load all startup animation frame textures into memory
	print("StartupScreen: Loading startup animation frames...")

	# Pre-allocate array for all frames
	startup_animation_textures.resize(total_frames + 1)

	# Load frames 1-60
	var loaded_count = 0
	for i in range(1, total_frames + 1):
		var texture_path = "res://assets/ui/startup_screen/frames/frame_%03d.png" % i
		var texture = load(texture_path) as Texture2D
		if texture:
			startup_animation_textures[i] = texture
			loaded_count += 1
			print("StartupScreen: Loaded frame %d" % i)
		else:
			print("StartupScreen: ERROR - Failed to load frame: %s" % texture_path)

	print("StartupScreen: Animation loading complete - %d/%d frames loaded" % [loaded_count, total_frames])

	if loaded_count > 0:
		# Set initial frame to start display immediately
		_set_startup_frame(1)
		print("StartupScreen: Initial frame set, ready for animation")
	else:
		print("StartupScreen: CRITICAL ERROR - No animation frames loaded, using fallback")
		_setup_fallback_display()

func _setup_fallback_display() -> void:
	# Setup fallback display if frame loading fails
	print("StartupScreen: Setting up fallback display")

	# Create a simple animated background as fallback
	background.color = Color(0.1, 0.05, 0.2, 1.0)  # Purple space theme

	# Add fallback text directly to the main Control node
	var fallback_label = Label.new()
	fallback_label.text = "CHILDREN OF THE SINGULARITY"
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.add_theme_font_size_override("font_size", 48)

	# Set up full viewport anchoring for the fallback label
	fallback_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Add to the main control node instead of video_container
	add_child(fallback_label)

	# Animate the fallback text
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(fallback_label, "modulate", Color.WHITE * 0.7, 1.5)
	tween.tween_property(fallback_label, "modulate", Color.WHITE * 1.0, 1.5)

func _setup_animation_timer() -> void:
	# Set up timer for frame-by-frame animation
	print("StartupScreen: Setting up animation timer (%.1f FPS)" % (1.0/animation_speed))

	animation_timer = Timer.new()
	animation_timer.name = "AnimationTimer"
	animation_timer.wait_time = animation_speed
	animation_timer.autostart = false
	animation_timer.timeout.connect(_on_animation_timer_timeout)
	add_child(animation_timer)

	print("StartupScreen: Animation timer ready")

func _start_animation_loop() -> void:
	# Start the gif-style animation loop
	print("StartupScreen: Starting gif-style animation loop")

	if animation_timer and startup_animation_textures.size() > 0:
		animation_timer.start()
		is_animating = true
		print("StartupScreen: Animation loop started successfully")
	else:
		print("StartupScreen: ERROR - Cannot start animation (timer: %s, frames: %d)" % [animation_timer != null, startup_animation_textures.size()])

func _set_startup_frame(frame_number: int) -> void:
	# Set the display to show a specific frame
	if frame_number < 1 or frame_number > total_frames:
		print("StartupScreen: Invalid frame number: %d" % frame_number)
		return

	if not video_display:
		print("StartupScreen: ERROR - VideoDisplay is null!")
		return

	if startup_animation_textures.size() <= frame_number:
		print("StartupScreen: ERROR - No texture at index %d (array size: %d)" % [frame_number, startup_animation_textures.size()])
		return

	var texture = startup_animation_textures[frame_number]
	if not texture:
		print("StartupScreen: ERROR - Texture at frame %d is null" % frame_number)
		return

	# Apply the texture and verify it worked
	video_display.texture = texture
	current_frame = frame_number

	# Debug: Verify the texture was actually set
	if video_display.texture == texture:
		print("StartupScreen: ✅ Successfully displaying frame %d (texture size: %dx%d)" % [frame_number, texture.get_width(), texture.get_height()])

		# Ensure the video display is visible
		if not video_display.visible:
			video_display.visible = true
			print("StartupScreen: Made VideoDisplay visible")
	else:
		print("StartupScreen: ERROR - Failed to assign texture to VideoDisplay!")

func _on_animation_timer_timeout() -> void:
	# Handle animation timer timeout - advance to next frame
	if not is_animating or is_transitioning:
		return

	# Advance to next frame with looping
	current_frame += 1
	if current_frame > total_frames:
		current_frame = 1  # Loop back to start
		print("StartupScreen: Animation loop completed, restarting")

	# Update the display to the new frame
	_set_startup_frame(current_frame)

func _show_press_key_label() -> void:
	# Show the "Press any key" label with fade-in animation
	if not press_key_label or key_prompt_visible:
		return

	print("StartupScreen: Showing 'Press any key' prompt")
	key_prompt_visible = true
	press_key_label.visible = true

	# Fade in the label
	var tween = create_tween()
	tween.tween_property(press_key_label, "modulate", Color.WHITE, 0.8)

	# Add subtle pulsing animation
	tween.tween_callback(_animate_press_key_label)

func _animate_press_key_label() -> void:
	# Animate the press key label with subtle pulsing
	if not press_key_label or not key_prompt_visible or is_transitioning:
		return

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(press_key_label, "modulate", Color.WHITE * 0.6, 1.2)
	tween.tween_property(press_key_label, "modulate", Color.WHITE * 1.0, 1.2)

func _preload_loading_screen() -> void:
	##Preload the loading screen for instant transition
	print("StartupScreen: Preloading loading screen scene")
	loading_screen_scene = preload("res://scenes/ui/LoadingScreen.tscn")
	if loading_screen_scene:
		print("StartupScreen: Loading screen scene preloaded successfully")
	else:
		print("StartupScreen: ERROR - Failed to preload loading screen scene")

func _start_transition() -> void:
	# Start transition to main game
	if is_transitioning:
		return

	print("StartupScreen: Starting transition to loading screen")
	is_transitioning = true

	# Stop animation during transition
	is_animating = false
	if animation_timer:
		animation_timer.paused = true

	# Fade out everything
	var tween = create_tween()
	tween.set_parallel(true)

	# Fade to black
	tween.tween_property(fade_overlay, "modulate", Color.WHITE, fade_duration)

	# Fade out press key label if visible
	if key_prompt_visible and press_key_label:
		tween.tween_property(press_key_label, "modulate", Color.TRANSPARENT, fade_duration * 0.5)

	# Complete transition when fade is done
	tween.tween_callback(_complete_transition).set_delay(fade_duration)

func _complete_transition() -> void:
	# Complete the transition to loading screen
	print("StartupScreen: Transition complete, switching to loading screen")

	# Emit signal to notify of completion
	startup_complete.emit()

	# Switch to loading screen instead of directly to main game
	_switch_to_loading_screen()

func _switch_to_loading_screen() -> void:
	##Switch to the custom loading screen
	print("StartupScreen: Switching to custom loading screen")

	# Create loading screen instance
	if loading_screen_scene:
		loading_screen_instance = loading_screen_scene.instantiate() as LoadingScreen
		if loading_screen_instance:
			print("StartupScreen: ✅ Loading screen instantiated successfully")

			# Add loading screen to scene tree
			get_tree().root.add_child(loading_screen_instance)

			# Start loading process (LoadingScreen will handle scene transition)
			loading_screen_instance.start_loading()

			# Remove startup screen now that loading screen is active
			queue_free()

			print("StartupScreen: Successfully switched to loading screen")
		else:
			print("StartupScreen: ERROR - Failed to instantiate loading screen, falling back to direct scene change")
			_fallback_to_direct_scene_change()
	else:
		print("StartupScreen: ERROR - Loading screen scene not available, falling back to direct scene change")
		_fallback_to_direct_scene_change()

# Signal handlers removed - LoadingScreen handles scene transition directly

func _fallback_to_direct_scene_change() -> void:
	##Fallback to direct scene change if loading screen fails
	print("StartupScreen: Using fallback direct scene change method")
	_load_main_game()

func _load_main_game() -> void:
	# Load the main game scene
	print("StartupScreen: ✅ Loading main game scene")

	# Load the main 3D game scene
	var main_scene_path = "res://scenes/zones/ZoneMain3D.tscn"
	print("StartupScreen: Target scene path: %s" % main_scene_path)

	# Check if the scene file exists
	if not FileAccess.file_exists(main_scene_path):
		print("StartupScreen: ❌ ERROR: Scene file does not exist: %s" % main_scene_path)
		return

	print("StartupScreen: Scene file exists, proceeding with deferred scene change...")
	# Use deferred call to avoid issues during transition
	call_deferred("_change_scene", main_scene_path)

func _change_scene(scene_path: String) -> void:
	# Change to the specified scene
	print("StartupScreen: ✅ Executing scene change to: %s" % scene_path)
	print("StartupScreen: Current scene: %s" % get_tree().current_scene.scene_file_path)

	var result = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		print("StartupScreen: ❌ ERROR: Failed to change scene. Error code: %d" % result)
	else:
		print("StartupScreen: ✅ Scene change initiated successfully")

## Public API methods for testing and configuration

func force_transition() -> void:
	# Force immediate transition (for testing)
	print("StartupScreen: Forcing immediate transition")
	_start_transition()

func get_animation_status() -> Dictionary:
	# Get current animation status for debugging
	return {
		"is_animating": is_animating,
		"is_transitioning": is_transitioning,
		"current_frame": current_frame,
		"total_frames": total_frames,
		"frames_loaded": startup_animation_textures.size(),
		"key_prompt_visible": key_prompt_visible,
		"timer_active": animation_timer != null and not animation_timer.is_stopped()
	}
