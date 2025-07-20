# MuteButtonManager.gd
# Reusable mute button manager for Children of the Singularity
# Handles music mute/unmute functionality across all game scenes

class_name MuteButtonManager
extends Control

## Signal emitted when mute button is clicked
signal mute_button_clicked(is_muted: bool)

# UI references
@onready var mute_button: Button = $MuteButton

# Mute button icons/text
var mute_icon: String = "🔇"    # Muted icon
var unmute_icon: String = "🔊"  # Unmuted icon

# Current mute state
var is_muted: bool = false

func _ready() -> void:
	print("MuteButtonManager: Initializing mute button manager")

	# Create mute button if it doesn't exist
	if not mute_button:
		_create_mute_button()

	# Connect to AudioManager signals
	_connect_audio_manager()

	# Set initial button state
	_update_button_appearance()

	print("MuteButtonManager: Mute button manager initialized")

func _create_mute_button() -> void:
	"""Create the mute button UI element"""
	print("MuteButtonManager: Creating mute button UI element")

	mute_button = Button.new()
	mute_button.name = "MuteButton"
	mute_button.size = Vector2(60, 40)
	mute_button.flat = true

	# Position in top-right corner with some padding
	mute_button.anchors_preset = Control.PRESET_TOP_RIGHT
	mute_button.position = Vector2(-80, 10)  # 20px padding from edges

	# Style the button
	mute_button.add_theme_font_size_override("font_size", 20)

	# Connect button signal
	mute_button.pressed.connect(_on_mute_button_pressed)

	# Add to scene
	add_child(mute_button)

	print("MuteButtonManager: Mute button created and positioned in top-right corner")

func _connect_audio_manager() -> void:
	"""Connect to AudioManager signals for state synchronization"""
	print("MuteButtonManager: Connecting to AudioManager signals")

	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		# Connect to music mute state changes
		if not audio_manager.music_mute_changed.is_connected(_on_music_mute_changed):
			audio_manager.music_mute_changed.connect(_on_music_mute_changed)

		# Get initial mute state
		is_muted = audio_manager.is_music_muted()
		print("MuteButtonManager: Connected to AudioManager - Initial mute state: %s" % is_muted)
	else:
		print("MuteButtonManager: WARNING - AudioManager not found, using default state")

func _on_mute_button_pressed() -> void:
	"""Handle mute button press"""
	print("MuteButtonManager: Mute button pressed - Current state: %s" % is_muted)

	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		# Toggle mute state through AudioManager
		audio_manager.toggle_music_mute()
		print("MuteButtonManager: Toggled music mute through AudioManager")
	else:
		print("MuteButtonManager: ERROR - AudioManager not found")

	# Emit signal for any other components that need to know
	mute_button_clicked.emit(not is_muted)

func _on_music_mute_changed(muted: bool) -> void:
	"""Handle music mute state change from AudioManager"""
	print("MuteButtonManager: Music mute state changed to: %s" % muted)
	is_muted = muted
	_update_button_appearance()

func _update_button_appearance() -> void:
	"""Update button appearance based on mute state"""
	if not mute_button:
		return

	if is_muted:
		mute_button.text = mute_icon
		mute_button.tooltip_text = "Unmute Music"
		mute_button.modulate = Color(1.0, 0.6, 0.6, 1.0)  # Reddish tint when muted
	else:
		mute_button.text = unmute_icon
		mute_button.tooltip_text = "Mute Music"
		mute_button.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal color when unmuted

	print("MuteButtonManager: Button appearance updated - Muted: %s, Icon: %s" % [is_muted, mute_button.text])

## Public methods for external control

func set_mute_state(muted: bool) -> void:
	"""Externally set mute state (will sync with AudioManager)"""
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.set_music_muted(muted)

func get_mute_state() -> bool:
	"""Get current mute state"""
	return is_muted

func hide_button() -> void:
	"""Hide the mute button"""
	if mute_button:
		mute_button.visible = false

func show_button() -> void:
	"""Show the mute button"""
	if mute_button:
		mute_button.visible = true

func set_button_position(pos: Vector2) -> void:
	"""Set custom button position"""
	if mute_button:
		mute_button.position = pos
		print("MuteButtonManager: Button position set to: %s" % pos)
