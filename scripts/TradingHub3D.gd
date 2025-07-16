# TradingHub3D.gd
# 3D Trading Hub for Children of the Singularity
# Provides trading functionality with billboard sprite display for 2.5D aesthetic
# Now includes 176-frame animation loop for enhanced visual appeal

class_name TradingHub3D
extends StaticBody3D

## Signal emitted when player enters hub interaction area
signal hub_entered(hub_type: String, hub: TradingHub3D)

## Signal emitted when player exits hub interaction area
signal hub_exited(hub_type: String, hub: TradingHub3D)

## Export properties for configuration
@export var hub_type: String = "trading"
@export var hub_name: String = "Trading Hub"
@export var interaction_radius: float = 15.0
@export var can_interact: bool = true

## Node references
@onready var hub_sprite_3d: Sprite3D = $HubSprite3D
@onready var hub_collision: CollisionShape3D = $HubCollision
@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_collision: CollisionShape3D = $InteractionArea/InteractionCollision
@onready var hub_label: Label3D = $HubLabel

## Trading hub animation textures - preloaded for fast switching (like SpaceStationModule3D)
var hub_animation_textures: Array[Texture2D] = []
var current_frame: int = 1  # Start at frame 1
var animation_timer: Timer
var animation_speed: float = 0.05  # Time in seconds between frames (20 FPS for smooth animation)
var total_frames: int = 176  # Frames 1-176 (frame_0001.png to frame_0176.png)

## Animation state management (continuous playing)
var is_animating: bool = true
var animation_direction: int = 1  # 1 for forward, -1 for reverse

## Hub state
var is_active: bool = true
var current_players: Array[Node3D] = []

func _ready() -> void:
	_log_message("TradingHub3D: Initializing %s with 176-frame animation" % hub_name)
	_load_hub_animation_textures()  # Load all animation frames first
	_setup_hub()
	_setup_animation_system()
	_connect_signals()

func _exit_tree() -> void:
	##Clean up animation resources when node is freed
	if animation_timer and animation_timer.is_valid():
		animation_timer.queue_free()
	_log_message("TradingHub3D: Animation resources cleaned up")

func _load_hub_animation_textures() -> void:
	##Load all trading hub animation frame textures into memory for fast switching
	_log_message("TradingHub3D: Loading trading hub animation textures...")

	# Resize array to hold all frames (1-176)
	hub_animation_textures.resize(total_frames + 1)

	# Load frames from 1 to 176
	var loaded_count = 0
	for i in range(1, total_frames + 1):
		var texture_path = "res://assets/sprites/trading_hub/animation_frames/frame_%04d.png" % i
		var texture = load(texture_path) as Texture2D
		if texture:
			hub_animation_textures[i] = texture
			loaded_count += 1
		else:
			_log_message("TradingHub3D: Failed to load texture: %s" % texture_path)

	_log_message("TradingHub3D: Loaded %d/%d trading hub animation textures" % [loaded_count, total_frames])

func _set_hub_frame(frame_number: int) -> void:
	##Set the trading hub sprite to a specific frame
	if frame_number < 1 or frame_number > total_frames:
		_log_message("TradingHub3D: Invalid frame number: %d" % frame_number)
		return

	if hub_sprite_3d and hub_animation_textures.size() > frame_number and hub_animation_textures[frame_number]:
		hub_sprite_3d.texture = hub_animation_textures[frame_number]
		current_frame = frame_number
	else:
		_log_message("TradingHub3D: Could not set frame %d" % frame_number)

func _on_animation_timer_timeout() -> void:
	##Handle animation timer timeout - advance to next frame
	if not is_animating:
		return

	# Advance to next frame with looping
	current_frame += animation_direction
	if current_frame > total_frames:
		current_frame = 1  # Loop back to start
	elif current_frame < 1:
		current_frame = total_frames  # Loop back to end

	# Update the sprite to the new frame
	_set_hub_frame(current_frame)

func _setup_animation_system() -> void:
	##Set up the continuous animation timer
	_log_message("TradingHub3D: Setting up continuous animation system")

	# Create animation timer
	animation_timer = Timer.new()
	animation_timer.name = "AnimationTimer"
	animation_timer.wait_time = animation_speed
	animation_timer.autostart = true
	animation_timer.timeout.connect(_on_animation_timer_timeout)
	add_child(animation_timer)

	# Start with a random frame for visual variety between hubs
	current_frame = randi() % total_frames + 1

	# Set initial frame if textures are loaded
	if hub_animation_textures.size() > current_frame and hub_animation_textures[current_frame]:
		_set_hub_frame(current_frame)

	_log_message("TradingHub3D: Continuous animation active - Frame rate: %.1f FPS, Starting frame: %d" % [1.0/animation_speed, current_frame])

func _setup_hub() -> void:
	##Set up the trading hub configuration
	_log_message("TradingHub3D: Setting up hub configuration")

	# Configure sprite billboard mode for 2.5D aesthetic
	if hub_sprite_3d:
		hub_sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hub_sprite_3d.pixel_size = 0.02  # Scale for proper size in 3D
		hub_sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

		# Ensure visibility and disable any automatic culling
		hub_sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hub_sprite_3d.visibility_range_end = 0.0  # Disable distance-based visibility culling
		hub_sprite_3d.visibility_range_begin = 0.0

		_log_message("TradingHub3D: Sprite3D configured with billboard mode and animation support")

	# Configure label
	if hub_label:
		hub_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hub_label.text = hub_name.to_upper()
		_log_message("TradingHub3D: Label3D configured")

	# Ensure proper collision layer and mask for NPC detection
	collision_layer = 8  # NPC layer
	collision_mask = 1   # Player layer

	# Configure interaction area
	if interaction_area:
		interaction_area.collision_layer = 0  # Don't collide with anything
		interaction_area.collision_mask = 1   # Detect players

	# Update interaction radius
	if interaction_collision and interaction_collision.shape is SphereShape3D:
		(interaction_collision.shape as SphereShape3D).radius = interaction_radius
		_log_message("TradingHub3D: Interaction radius set to %.1f" % interaction_radius)

	# Add to npc_hub group for player detection
	add_to_group("npc_hub")
	_log_message("TradingHub3D: Added to npc_hub group")

## Animation control methods
func set_animation_speed(speed: float) -> void:
	##Set the animation speed (time between frames)
	animation_speed = speed
	if animation_timer:
		animation_timer.wait_time = animation_speed
		_log_message("TradingHub3D: Animation speed updated to %.3f seconds per frame (%.1f FPS)" % [animation_speed, 1.0/animation_speed])

func pause_animation() -> void:
	##Pause the animation
	is_animating = false
	if animation_timer:
		animation_timer.paused = true
		_log_message("TradingHub3D: Animation paused")

func resume_animation() -> void:
	##Resume the animation
	is_animating = true
	if animation_timer:
		animation_timer.paused = false
		_log_message("TradingHub3D: Animation resumed")

func reverse_animation_direction() -> void:
	##Reverse the animation direction
	animation_direction *= -1
	_log_message("TradingHub3D: Animation direction reversed - now playing %s" % ("forward" if animation_direction > 0 else "backward"))

func _connect_signals() -> void:
	##Connect interaction area signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
		_log_message("TradingHub3D: Interaction signals connected")

func _on_interaction_area_body_entered(body: Node3D) -> void:
	##Handle player entering interaction area
	if body.has_method("collect_debris") and can_interact:  # Check if it's the player
		current_players.append(body)
		_log_message("TradingHub3D: Player entered %s hub" % hub_type)
		hub_entered.emit(hub_type, self)

func _on_interaction_area_body_exited(body: Node3D) -> void:
	##Handle player exiting interaction area
	if body in current_players:
		current_players.erase(body)
		_log_message("TradingHub3D: Player exited %s hub" % hub_type)
		hub_exited.emit(hub_type, self)

func get_hub_type() -> String:
	##Get the hub type for compatibility with existing trading system
	return hub_type

func get_hub_name() -> String:
	##Get the hub display name
	return hub_name

func set_hub_active(active: bool) -> void:
	##Set hub active state
	is_active = active
	can_interact = active
	visible = active

	# Update collision based on active state
	if hub_collision:
		hub_collision.disabled = not active

	if interaction_area:
		interaction_area.monitoring = active

	# Pause/resume animation based on active state
	if active:
		resume_animation()
	else:
		pause_animation()

	_log_message("TradingHub3D: Hub %s set to %s" % [hub_name, "active" if active else "inactive"])

func set_hub_type(new_type: String) -> void:
	##Set the hub type and update label
	hub_type = new_type

	# Update display based on type
	if new_type.to_lower().contains("upgrade"):
		hub_name = "Upgrade Station"
		if hub_label:
			hub_label.text = "UPGRADE STATION"
			hub_label.modulate = Color(0.8, 0.6, 1.0, 1.0)  # Purple tint for upgrade
	elif new_type.to_lower().contains("trading"):
		hub_name = "Trading Hub"
		if hub_label:
			hub_label.text = "TRADING HUB"
			hub_label.modulate = Color(0.8, 1.0, 0.6, 1.0)  # Green tint for trading
	else:
		hub_name = "Hub Station"
		if hub_label:
			hub_label.text = "HUB STATION"
			hub_label.modulate = Color(1.0, 1.0, 1.0, 1.0)  # White for generic

	_log_message("TradingHub3D: Hub type set to %s (%s)" % [hub_type, hub_name])

func get_current_players() -> Array[Node3D]:
	##Get list of players currently in interaction range
	return current_players.duplicate()

func has_players() -> bool:
	##Check if any players are currently in interaction range
	return current_players.size() > 0

func _log_message(message: String) -> void:
	##Log a message with timestamp
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)
