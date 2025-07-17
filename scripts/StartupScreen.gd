# StartupScreen.gd
# Startup screen for Children of the Singularity
# Displays animated intro video loop until player presses any key

class_name StartupScreen
extends Control

## Signal emitted when startup screen should transition to main game
signal startup_complete()

## Export properties for configuration
@export var startup_gif_path: String = "res://assets/ui/startup_screen/startup_screen.gif"
@export var fade_duration: float = 1.0
@export var auto_start_after: float = 0.0  # 0 = disabled, >0 = auto-start after seconds
@export var show_press_key_delay: float = 2.0  # Delay before showing "Press any key"

## Node references
@onready var background: ColorRect = $Background
@onready var video_container: CenterContainer = $VideoContainer
@onready var video_display: TextureRect = $VideoContainer/VideoDisplay
@onready var press_key_label: Label = $PressAnyKeyLabel
@onready var fade_overlay: ColorRect = $FadeOverlay

## Animation and state management (following project patterns)
var startup_animation_textures: Array[Texture2D] = []
var current_frame: int = 1  # Start at frame 1
var animation_timer: Timer
var animation_speed: float = 1.0 / 12.0  # 12 FPS = 1/12 seconds per frame
var total_frames: int = 60  # We extracted 60 frames
var is_animating: bool = true

## State management
var is_transitioning: bool = false
var startup_timer: float = 0.0
var press_key_timer: float = 0.0
var key_prompt_visible: bool = false

func _ready() -> void:
	print("StartupScreen: Initializing startup screen")
	_setup_startup_screen()
	_load_startup_animation()
	_start_animation_loop()

func _exit_tree() -> void:
	##Clean up animation resources when node is freed (following project patterns)
	if animation_timer and is_instance_valid(animation_timer):
		animation_timer.queue_free()
	print("StartupScreen: Animation resources cleaned up")

func _process(delta: float) -> void:
	# Handle auto-start timer
	if auto_start_after > 0.0:
		startup_timer += delta
		if startup_timer >= auto_start_after and not is_transitioning:
			_start_transition()
			return

	# Handle press key label visibility
	if not key_prompt_visible:
		press_key_timer += delta
		if press_key_timer >= show_press_key_delay:
			_show_press_key_label()

func _input(event: InputEvent) -> void:
	# Detect any key press, mouse click, or gamepad input
	if is_transitioning:
		return

	var should_transition = false

	if event is InputEventKey and event.pressed:
		should_transition = true
		print("StartupScreen: Key pressed - %s" % event.as_text())
	elif event is InputEventMouseButton and event.pressed:
		should_transition = true
		print("StartupScreen: Mouse clicked")
	elif event is InputEventJoypadButton and event.pressed:
		should_transition = true
		print("StartupScreen: Gamepad button pressed")

	if should_transition:
		_start_transition()

func _setup_startup_screen() -> void:
	##Initialize startup screen components
	print("StartupScreen: Setting up startup screen components")

	# Hide press key label initially
	if press_key_label:
		press_key_label.visible = false
		press_key_label.modulate = Color.TRANSPARENT

	# Set up fade overlay for transitions
	if fade_overlay:
		fade_overlay.color = Color.BLACK
		fade_overlay.modulate = Color.TRANSPARENT

	# Set background to space theme
	if background:
		background.color = Color(0.05, 0.05, 0.1, 1.0)  # Dark space blue

	print("StartupScreen: Startup screen components configured")

func _load_startup_animation() -> void:
	##Load all startup animation frame textures into memory for fast switching (following project patterns)
	print("StartupScreen: Loading startup animation textures...")

	# Resize array to hold all frames (1-60)
	startup_animation_textures.resize(total_frames + 1)

	# Load frames from 1 to 60 (following project naming pattern)
	var loaded_count = 0
	for i in range(1, total_frames + 1):
		var texture_path = "res://assets/ui/startup_screen/frames/frame_%03d.png" % i
		var texture = load(texture_path) as Texture2D
		if texture:
			startup_animation_textures[i] = texture
			loaded_count += 1
		else:
			print("StartupScreen: Failed to load texture: %s" % texture_path)

	if loaded_count > 0:
		print("StartupScreen: Loaded %d/%d startup animation textures" % [loaded_count, total_frames])

		# Set initial frame
		_set_startup_frame(current_frame)

		# Scale to fit screen while maintaining aspect ratio
		video_display.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		video_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# Setup timer-based animation system
		_setup_animation_timer()
	else:
		print("StartupScreen: ERROR - Could not load any animation frames")
		# Fallback: show a simple static image or color
		_setup_fallback_display()

func _setup_fallback_display() -> void:
	##Setup fallback display if GIF loading fails
	print("StartupScreen: Setting up fallback display")

	# Create a simple animated background as fallback
	background.color = Color(0.1, 0.05, 0.2, 1.0)  # Purple space theme

	# Add a simple text display
	var fallback_label = Label.new()
	fallback_label.text = "CHILDREN OF THE SINGULARITY"
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.add_theme_font_size_override("font_size", 48)

	video_container.add_child(fallback_label)

	# Create a simple pulsing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(fallback_label, "modulate", Color.WHITE * 0.7, 1.0)
	tween.tween_property(fallback_label, "modulate", Color.WHITE * 1.0, 1.0)

func _start_animation_loop() -> void:
	##Start the animation loop
	print("StartupScreen: Starting animation loop")

	# Animation is now handled by the timer system
	if animation_timer:
		animation_timer.start()
		print("StartupScreen: Timer-based animation started")

	# Create a subtle background animation regardless
	_animate_background()

func _set_startup_frame(frame_number: int) -> void:
	##Set the startup screen to display a specific frame (following project patterns)
	if frame_number < 1 or frame_number > total_frames:
		print("StartupScreen: Invalid frame number: %d" % frame_number)
		return

	if video_display and startup_animation_textures.size() > frame_number and startup_animation_textures[frame_number]:
		video_display.texture = startup_animation_textures[frame_number]
		current_frame = frame_number
	else:
		print("StartupScreen: Could not set frame %d" % frame_number)

func _setup_animation_timer() -> void:
	##Set up the timer-based animation system (following project patterns)
	print("StartupScreen: Setting up timer-based animation")

	# Create animation timer
	animation_timer = Timer.new()
	animation_timer.name = "AnimationTimer"
	animation_timer.wait_time = animation_speed
	animation_timer.autostart = true
	animation_timer.timeout.connect(_on_animation_timer_timeout)
	add_child(animation_timer)

	print("StartupScreen: Timer-based animation active - Frame rate: %.1f FPS" % (1.0/animation_speed))

func _on_animation_timer_timeout() -> void:
	##Handle animation timer timeout - advance to next frame (following project patterns)
	if not is_animating or is_transitioning:
		return

	# Advance to next frame with looping
	current_frame += 1
	if current_frame > total_frames:
		current_frame = 1  # Loop back to start

	# Update the display to the new frame
	_set_startup_frame(current_frame)

func _animate_background() -> void:
	##Create subtle background animations
	var tween = create_tween()
	tween.set_loops()
	tween.set_parallel(true)

	# Subtle color pulsing
	tween.tween_property(background, "color", Color(0.05, 0.05, 0.15, 1.0), 3.0)
	tween.tween_property(background, "color", Color(0.05, 0.05, 0.1, 1.0), 3.0)

func _show_press_key_label() -> void:
	##Show the "Press any key" label with fade-in animation
	if not press_key_label or key_prompt_visible:
		return

	print("StartupScreen: Showing 'Press any key' label")
	key_prompt_visible = true
	press_key_label.visible = true

	# Fade in the label
	var tween = create_tween()
	tween.tween_property(press_key_label, "modulate", Color.WHITE, 0.5)

	# Add subtle pulsing animation
	tween.tween_callback(_animate_press_key_label)

func _animate_press_key_label() -> void:
	##Animate the press key label with subtle pulsing
	if not press_key_label or not key_prompt_visible:
		return

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(press_key_label, "modulate", Color.WHITE * 0.8, 1.0)
	tween.tween_property(press_key_label, "modulate", Color.WHITE * 1.0, 1.0)

func _start_transition() -> void:
	##Start transition to main game
	if is_transitioning:
		return

	print("StartupScreen: Starting transition to main game")
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

	# Fade out press key label
	if key_prompt_visible and press_key_label:
		tween.tween_property(press_key_label, "modulate", Color.TRANSPARENT, fade_duration * 0.5)

	# Complete transition when fade is done
	tween.tween_callback(_complete_transition).set_delay(fade_duration)

func _complete_transition() -> void:
	##Complete the transition to main game
	print("StartupScreen: Transition complete, loading main game")

	# Emit signal to notify of completion
	startup_complete.emit()

	# Change to main game scene
	_load_main_game()

func _load_main_game() -> void:
	##Load the main game scene
	print("StartupScreen: Loading main game scene")

	# Load the main game scene (ZoneMain3D based on project.godot)
	var main_scene_path = "res://scenes/zones/ZoneMain3D.tscn"

	# Use deferred call to avoid issues during transition
	call_deferred("_change_scene", main_scene_path)

func _change_scene(scene_path: String) -> void:
	##Change to the specified scene
	get_tree().change_scene_to_file(scene_path)

## Public API methods

func set_auto_start_timer(seconds: float) -> void:
	##Set auto-start timer for automatic transition
	auto_start_after = seconds
	print("StartupScreen: Auto-start timer set to %s seconds" % seconds)

func force_transition() -> void:
	##Force immediate transition (for testing or special cases)
	print("StartupScreen: Forcing immediate transition")
	_start_transition()

func get_transition_status() -> Dictionary:
	##Get current transition status
	return {
		"is_transitioning": is_transitioning,
		"startup_timer": startup_timer,
		"key_prompt_visible": key_prompt_visible,
		"auto_start_after": auto_start_after
	}
