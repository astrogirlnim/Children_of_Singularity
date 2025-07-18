# LoadingScreen.gd
# Custom loading screen for Children of the Singularity
# Displays loading_screen.png with progress indication and loading messages

class_name LoadingScreen
extends Control

## Signal emitted when loading is complete
signal loading_complete()

## Signal emitted when loading progress updates
signal loading_progress_updated(progress: float, message: String)

## Node references
@onready var loading_background: TextureRect = $LoadingBackground
@onready var loading_overlay: ColorRect = $LoadingOverlay
@onready var loading_label: Label = $LoadingContent/LoadingLabel
@onready var loading_progress: ProgressBar = $LoadingContent/LoadingProgress
@onready var loading_spinner: Control = $LoadingContent/LoadingSpinner

## Loading management
var loading_items: Array[Dictionary] = []
var current_loading_index: int = 0
var loading_timer: float = 0.0
var message_change_timer: float = 0.0
var spinner_timer: float = 0.0
var active_threaded_loads: Dictionary = {}  # Track which resources are actively loading

## Loading messages for immersive feedback
var loading_messages: Array[String] = [
	"Initializing quantum drive systems...",
	"Calibrating navigation sensors...",
	"Loading stellar cartography data...",
	"Synchronizing debris detection arrays...",
	"Establishing communication links...",
	"Activating life support systems...",
	"Loading ship upgrade configurations...",
	"Preparing for deep space exploration...",
	"Finalizing system initialization..."
]

var current_message_index: int = 0

## Configuration
@export var fade_duration: float = 0.5
@export var message_change_interval: float = 2.0
@export var spinner_speed: float = 2.0
@export var min_loading_time: float = 3.0  # Minimum time to show loading screen

## State tracking
var is_loading: bool = false
var loading_start_time: float = 0.0
var assets_loaded: bool = false

func _ready() -> void:
	print("LoadingScreen: Initializing custom loading screen")
	add_to_group("loading_screens")  # For cleanup purposes
	_setup_loading_screen()
	_setup_loading_items()
	# _start_spinner_animation()  # Disabled for clean loading screen

func _exit_tree() -> void:
	##Clean up when the loading screen is freed
	cleanup_loading()
	print("LoadingScreen: Cleaned up loading system on exit")

func _process(delta: float) -> void:
	##Handle loading screen updates
	if is_loading:
		loading_timer += delta
		# message_change_timer += delta  # Disabled for clean loading screen
		# spinner_timer += delta  # Disabled for clean loading screen

		# Update loading messages - DISABLED for clean loading screen
		# if message_change_timer >= message_change_interval:
		#	message_change_timer = 0.0
		#	_update_loading_message()

		# Update spinner animation - DISABLED for clean loading screen
		# _update_spinner_animation(delta)

		# Process loading queue
		_process_loading_queue(delta)

func _setup_loading_screen() -> void:
	##Initialize loading screen display
	print("LoadingScreen: Setting up loading screen display")

	# Ensure background image fills screen properly
	if loading_background:
		loading_background.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		loading_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		print("LoadingScreen: Background image configured")

	# Hide all progress UI elements for clean loading screen
	if loading_progress:
		loading_progress.visible = false
		print("LoadingScreen: Progress bar hidden")

	if loading_label:
		loading_label.visible = false
		print("LoadingScreen: Loading text hidden")

	if loading_spinner:
		loading_spinner.visible = false
		print("LoadingScreen: Spinner animation hidden")

	print("LoadingScreen: Clean loading screen setup complete (no progress UI)")

func _setup_loading_items() -> void:
	##Define items to load during the loading process
	loading_items = [
		{
			"name": "ZoneMain3D Scene",
			"resource_path": "res://scenes/zones/ZoneMain3D.tscn",
			"load_time": 1.5,
			"weight": 40
		},
		{
			"name": "Player Ship 3D",
			"resource_path": "res://scenes/player/PlayerShip3D.tscn",
			"load_time": 0.5,
			"weight": 15
		},
		{
			"name": "Debris Objects",
			"resource_path": "res://scenes/objects/Debris3D.tscn",
			"load_time": 0.3,
			"weight": 10
		},
		{
			"name": "Trading Hub",
			"resource_path": "res://scenes/objects/TradingHub3D.tscn",
			"load_time": 0.3,
			"weight": 10
		},
		{
			"name": "Space Station Module",
			"resource_path": "res://scenes/objects/SpaceStationModule3D.tscn",
			"load_time": 0.3,
			"weight": 10
		},
		{
			"name": "Background Assets",
			"resource_path": "res://assets/backgrounds/seamless/starfield_seamless.png",
			"load_time": 0.4,
			"weight": 15
		}
	]

	print("LoadingScreen: Configured %d loading items" % loading_items.size())

func start_loading() -> void:
	##Start the loading process
	print("LoadingScreen: Starting loading process")
	is_loading = true
	loading_start_time = Time.get_unix_time_from_system()
	current_loading_index = 0
	current_message_index = 0
	assets_loaded = false

	# Reset loading tracking
	active_threaded_loads.clear()

	# Reset progress
	if loading_progress:
		loading_progress.value = 0

	# Show initial message
	_update_loading_message()

	# Start preloading resources
	_start_resource_preloading()

func _start_resource_preloading() -> void:
	##Start background preloading of game resources
	print("LoadingScreen: Starting resource preloading")

	# Clear previous loading states
	active_threaded_loads.clear()

	# Begin threaded loading of the main scene and critical resources
	for item in loading_items:
		var resource_path = item.get("resource_path", "")
		if resource_path != "" and ResourceLoader.exists(resource_path):
			# Check if already loaded in cache
			if ResourceLoader.has_cached(resource_path):
				print("LoadingScreen: Resource already cached: %s" % resource_path)
				continue

			# Use threaded loading for better performance
			var load_result = ResourceLoader.load_threaded_request(resource_path)
			if load_result == OK:
				active_threaded_loads[resource_path] = true
				print("LoadingScreen: Queued threaded loading for: %s" % resource_path)
			else:
				print("LoadingScreen: Failed to initiate threaded loading for: %s" % resource_path)

func _process_loading_queue(delta: float) -> void:
	##Process the loading queue and update progress
	if current_loading_index >= loading_items.size():
		_check_loading_completion()
		return

	var current_item = loading_items[current_loading_index]
	var resource_path = current_item.get("resource_path", "")
	var load_time = current_item.get("load_time", 1.0)
	var weight = current_item.get("weight", 10)

	# Check if this resource path exists and is actively being loaded
	if ResourceLoader.exists(resource_path) and active_threaded_loads.has(resource_path):
		var status = ResourceLoader.load_threaded_get_status(resource_path)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# Item loaded successfully
			print("LoadingScreen: Loaded: %s" % current_item.get("name", "Unknown"))
			active_threaded_loads.erase(resource_path)  # Remove from active tracking
			current_loading_index += 1
			_update_progress()
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			# Handle loading failure
			print("LoadingScreen: Failed to load: %s" % current_item.get("name", "Unknown"))
			active_threaded_loads.erase(resource_path)  # Remove from active tracking
			current_loading_index += 1
			_update_progress()
		elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			# Resource doesn't exist or is invalid
			print("LoadingScreen: Invalid resource: %s" % current_item.get("name", "Unknown"))
			active_threaded_loads.erase(resource_path)  # Remove from active tracking
			current_loading_index += 1
			_update_progress()
		# If status is THREAD_LOAD_IN_PROGRESS, just wait for next frame
	else:
		# Resource doesn't exist or isn't actively loading, skip it
		print("LoadingScreen: Skipping resource: %s (not found or not loading)" % current_item.get("name", "Unknown"))
		current_loading_index += 1
		_update_progress()

func _update_progress() -> void:
	##Update loading progress bar and messages
	var total_weight = 0
	var completed_weight = 0

	# Calculate total weight of all items
	for item in loading_items:
		total_weight += item.get("weight", 10)

	# Calculate completed weight
	for i in range(min(current_loading_index, loading_items.size())):
		completed_weight += loading_items[i].get("weight", 10)

	# Update progress bar (0-100%) - DISABLED for clean loading screen
	var progress_percent = (float(completed_weight) / float(total_weight)) * 100.0
	# if loading_progress:
	#	loading_progress.value = progress_percent

	# Emit progress signal - DISABLED for clean loading screen
	# var current_message = loading_label.text if loading_label else ""
	# loading_progress_updated.emit(progress_percent, current_message)

	print("LoadingScreen: Progress: %.1f%% (%d/%d items)" % [progress_percent, current_loading_index, loading_items.size()])

func _update_loading_message() -> void:
	##Update the loading message to the next in sequence
	if loading_label and current_message_index < loading_messages.size():
		loading_label.text = loading_messages[current_message_index]
		current_message_index += 1

		# Loop back to start if we reach the end
		if current_message_index >= loading_messages.size():
			current_message_index = 0

		print("LoadingScreen: Updated message: %s" % loading_label.text)

func _start_spinner_animation() -> void:
	##Start the spinner animation for visual loading feedback
	if loading_spinner:
		# Simple rotation animation for the entire spinner
		var spinner_tween = create_tween()
		spinner_tween.set_loops()
		spinner_tween.tween_property(loading_spinner, "rotation", TAU, 2.0)
		print("LoadingScreen: Started simple spinner rotation animation")

func _update_spinner_animation(delta: float) -> void:
	##Update spinner animation - handled by tween now
	pass  # Spinner animation is now handled by the tween in _start_spinner_animation

func _check_loading_completion() -> void:
	##Check if loading is complete and handle transition
	if not assets_loaded and current_loading_index >= loading_items.size():
		# Ensure minimum loading time has passed for user experience
		var current_time = Time.get_unix_time_from_system()
		var elapsed_time = current_time - loading_start_time

		if elapsed_time >= min_loading_time:
			# Final check - make sure no active threaded loads remain
			if active_threaded_loads.size() == 0:
				print("LoadingScreen: All assets loaded, completing loading process")
				assets_loaded = true
				_complete_loading()
			else:
				print("LoadingScreen: Waiting for %d remaining threaded loads to complete" % active_threaded_loads.size())

func _complete_loading() -> void:
	##Complete the loading process and transition to main game
	print("LoadingScreen: Loading complete!")
	is_loading = false

	# Set progress to 100%
	if loading_progress:
		loading_progress.value = 100

	# Update final message
	if loading_label:
		loading_label.text = "Loading complete! Welcome to the singularity..."

	# Show completion message briefly
	print("LoadingScreen: Waiting 1 second before transitioning...")
	await get_tree().create_timer(1.0).timeout

	# Emit signal for any listeners (but don't depend on it)
	print("LoadingScreen: Emitting loading_complete signal...")
	print("LoadingScreen: Signal has %d connections" % loading_complete.get_connections().size())
	loading_complete.emit()

	# Handle scene transition directly (don't wait for signal)
	print("LoadingScreen: ✅ Handling scene transition directly...")
	await _transition_to_main_game()

func _transition_to_main_game() -> void:
	print("LoadingScreen: Starting transition to main game")

	# Critical debug: Validate scene file exists before transition
	var scene_path = "res://scenes/zones/ZoneMain3D.tscn"
	print("LoadingScreen: Validating scene file exists: ", scene_path)

	if not ResourceLoader.exists(scene_path):
		print("LoadingScreen: ❌ CRITICAL ERROR - Scene file does not exist: ", scene_path)
		return

	print("LoadingScreen: ✅ Scene file confirmed to exist")

	# Check if scene is already loaded from preloading
	var preloaded_scene = ResourceLoader.load_threaded_get(scene_path)
	if preloaded_scene:
		print("LoadingScreen: ✅ Using preloaded scene resource")
	else:
		print("LoadingScreen: ⚠️  Scene not preloaded, will load fresh")

	print("LoadingScreen: Attempting scene change to: ", scene_path)
	print("LoadingScreen: 🔄 KEEPING LOADING SCREEN VISIBLE during transition...")

	# Attempt scene transition with error checking (KEEP LOADING SCREEN VISIBLE)
	var error = get_tree().change_scene_to_file(scene_path)

	if error != OK:
		print("LoadingScreen: ❌ CRITICAL ERROR - Scene change failed with error code: ", error)
		print("LoadingScreen: Error codes: OK=0, FAILED=1, ERR_UNAVAILABLE=2, ERR_UNCONFIGURED=3")
		return

		print("LoadingScreen: ✅ Scene change call completed successfully")
	print("LoadingScreen: Waiting for ZoneMain3D zone_ready signal...")

	# Wait a moment for scene to initialize, then connect to its signal
	await get_tree().create_timer(0.1).timeout
	print("LoadingScreen: Post-transition check - Current scene: ", get_tree().current_scene)

	if get_tree().current_scene and get_tree().current_scene.name == "ZoneMain3D":
		print("LoadingScreen: ✅ ZoneMain3D scene active - Connecting to zone_ready signal")

		# Try multiple approaches for instant transition
		var zone_main_3d = get_tree().current_scene as ZoneMain3D
		if zone_main_3d:
			print("LoadingScreen: ✅ ZoneMain3D found - Attempting instant transition")

			# Method 1: Check if zone is already ready (most likely case)
			if zone_main_3d.has_method("_ready") or true:  # Zone is already initialized since _ready ran
				print("LoadingScreen: Zone already ready - INSTANT transition!")
				_on_zone_ready()
				return

			# Method 2: Connect to signal as backup
			if zone_main_3d.has_signal("zone_ready"):
				if not zone_main_3d.zone_ready.is_connected(_on_zone_ready):
					zone_main_3d.zone_ready.connect(_on_zone_ready)
					print("LoadingScreen: ✅ Connected to zone_ready signal as backup")

					# Give signal a moment to fire, then fallback
					await get_tree().create_timer(0.2).timeout
					if self.visible:  # Still visible? Force instant transition
						print("LoadingScreen: Signal backup - forcing instant transition")
						_on_zone_ready()
				else:
					_on_zone_ready()
		else:
			print("LoadingScreen: ⚠️ ZoneMain3D not available, using timer fallback")
			await get_tree().create_timer(0.5).timeout
			_on_zone_ready()
	else:
		print("LoadingScreen: ❌ CRITICAL ERROR - No current scene after transition!")

func _on_zone_ready() -> void:
	##Called when ZoneMain3D emits zone_ready signal - INSTANT transition
	print("LoadingScreen: 🎯 ZoneMain3D is ready! INSTANT transition to gameplay!")

	# INSTANT hide - no fade animation
	print("LoadingScreen: Hiding loading screen instantly")
	self.visible = false
	self.modulate = Color.TRANSPARENT

	print("LoadingScreen: Cleaning up loading system")
	cleanup_loading()

	print("LoadingScreen: ✅ INSTANT transition complete - No overlap!")

func fade_out() -> void:
	##Fade out the loading screen
	print("LoadingScreen: Fading out loading screen")
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, fade_duration)
	await tween.finished

## Public API methods

func get_loading_progress() -> float:
	##Get current loading progress (0-100)
	if loading_progress:
		return loading_progress.value
	return 0.0

func is_loading_active() -> bool:
	##Check if loading is currently active
	return is_loading

func get_current_message() -> String:
	##Get the current loading message
	if loading_label:
		return loading_label.text
	return ""

func cleanup_loading() -> void:
	##Clean up loading resources and state
	print("LoadingScreen: Cleaning up loading system")

	# Cancel any remaining threaded loads
	for resource_path in active_threaded_loads.keys():
		# Note: Godot doesn't have a direct way to cancel threaded loads
		# but we can clear our tracking to avoid further status checks
		print("LoadingScreen: Clearing tracking for: %s" % resource_path)

	active_threaded_loads.clear()
	is_loading = false
	assets_loaded = false

## Static cleanup function to remove stuck LoadingScreen instances
static func remove_all_loading_screens() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		var loading_screens = tree.get_nodes_in_group("loading_screens")
		for screen in loading_screens:
			if screen and is_instance_valid(screen):
				print("LoadingScreen: Removing stuck loading screen instance")
				screen.queue_free()
