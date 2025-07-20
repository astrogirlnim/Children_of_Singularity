extends Node

# AudioManager - Enhanced singleton for background music and sound effects
# Handles looping background music, sound effects, and persistent mute functionality

## Signal emitted when music mute state changes
signal music_mute_changed(is_muted: bool)

## Signal emitted when SFX mute state changes
signal sfx_mute_changed(is_muted: bool)

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

var music_volume: float = 0.8
var sfx_volume: float = 1.0
var music_muted: bool = false
var sfx_muted: bool = false

# Store original volumes for unmuting
var original_music_volume: float = 0.8
var original_sfx_volume: float = 1.0

func _ready() -> void:
	print("AudioManager: Initializing enhanced audio system with mute functionality")

	# Add audio players as children
	add_child(music_player)
	add_child(sfx_player)

	# Set up audio buses
	music_player.bus = "Music"
	sfx_player.bus = "SFX"

	# Configure music player for looping
	music_player.finished.connect(_on_music_finished)

	# Load mute settings from LocalPlayerData
	_load_mute_settings()

	# Set initial volumes (respecting mute state)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)

	# Start background music
	play_background_music()

	print("AudioManager: Enhanced audio system initialized - Music muted: %s, SFX muted: %s" % [music_muted, sfx_muted])

func _load_mute_settings() -> void:
	"""Load mute settings from LocalPlayerData"""
	print("AudioManager: Loading mute settings from LocalPlayerData")

	var local_player_data = get_node_or_null("/root/LocalPlayerData")
	if local_player_data and local_player_data.is_initialized:
		music_muted = local_player_data.get_setting("music_muted", false)
		sfx_muted = local_player_data.get_setting("sfx_muted", false)
		original_music_volume = local_player_data.get_setting("music_volume", 0.8)
		original_sfx_volume = local_player_data.get_setting("sfx_volume", 1.0)

		# Set current volumes to original unless muted
		music_volume = original_music_volume
		sfx_volume = original_sfx_volume

		print("AudioManager: Loaded settings - Music muted: %s, SFX muted: %s" % [music_muted, sfx_muted])
	else:
		print("AudioManager: LocalPlayerData not available, using default mute settings")

func _save_mute_settings() -> void:
	"""Save mute settings to LocalPlayerData"""
	var local_player_data = get_node_or_null("/root/LocalPlayerData")
	if local_player_data and local_player_data.is_initialized:
		local_player_data.set_setting("music_muted", music_muted)
		local_player_data.set_setting("sfx_muted", sfx_muted)
		local_player_data.set_setting("music_volume", original_music_volume)
		local_player_data.set_setting("sfx_volume", original_sfx_volume)
		print("AudioManager: Mute settings saved to LocalPlayerData")

## Music mute functionality

func toggle_music_mute() -> void:
	"""Toggle music mute state"""
	set_music_muted(not music_muted)

func set_music_muted(muted: bool) -> void:
	"""Set music mute state"""
	music_muted = muted

	if music_muted:
		print("AudioManager: Muting music")
		music_player.volume_db = -80.0  # Effectively silent
	else:
		print("AudioManager: Unmuting music")
		music_player.volume_db = linear_to_db(music_volume)

	# Save setting and emit signal
	_save_mute_settings()
	music_mute_changed.emit(music_muted)
	print("AudioManager: Music mute toggled - Now muted: %s" % music_muted)

func is_music_muted() -> bool:
	"""Check if music is currently muted"""
	return music_muted

## SFX mute functionality

func toggle_sfx_mute() -> void:
	"""Toggle SFX mute state"""
	set_sfx_muted(not sfx_muted)

func set_sfx_muted(muted: bool) -> void:
	"""Set SFX mute state"""
	sfx_muted = muted

	if sfx_muted:
		print("AudioManager: Muting SFX")
		sfx_player.volume_db = -80.0  # Effectively silent
	else:
		print("AudioManager: Unmuting SFX")
		sfx_player.volume_db = linear_to_db(sfx_volume)

	# Save setting and emit signal
	_save_mute_settings()
	sfx_mute_changed.emit(sfx_muted)
	print("AudioManager: SFX mute toggled - Now muted: %s" % sfx_muted)

func is_sfx_muted() -> bool:
	"""Check if SFX is currently muted"""
	return sfx_muted

func play_background_music() -> void:
	"""Start playing the background music on loop"""
	print("AudioManager: Loading background music")

	var music_path = "res://assets/audio/music/background_music.ogg"
	if not ResourceLoader.exists(music_path):
		print("AudioManager: ERROR - Background music file not found at: ", music_path)
		return

	var music_stream = load(music_path)
	if music_stream == null:
		print("AudioManager: ERROR - Failed to load background music")
		return

	# Enable seamless looping on the audio stream
	if music_stream is AudioStreamOggVorbis:
		music_stream.loop = true
		print("AudioManager: Enabled seamless looping for OGG audio stream")

	music_player.stream = music_stream
	music_player.play()
	print("AudioManager: Background music started successfully with seamless looping")

func _on_music_finished() -> void:
	"""Restart music when it finishes to create seamless loop"""
	print("AudioManager: Restarting background music loop")
	music_player.play()

func play_sfx(sound_name: String) -> void:
	"""Play a one-shot sound effect"""
	print("AudioManager: Playing sound effect: ", sound_name)

	var sfx_path = "res://assets/audio/sfx/" + sound_name + ".ogg"
	if not ResourceLoader.exists(sfx_path):
		print("AudioManager: WARNING - Sound effect not found: ", sfx_path)
		return

	var sfx_stream = load(sfx_path)
	if sfx_stream == null:
		print("AudioManager: ERROR - Failed to load sound effect: ", sound_name)
		return

	sfx_player.stream = sfx_stream
	sfx_player.play()

func set_music_volume(volume: float) -> void:
	"""Set music volume (0.0 to 1.0) - respects mute state"""
	original_music_volume = clamp(volume, 0.0, 1.0)
	music_volume = original_music_volume

	if not music_muted:
		music_player.volume_db = linear_to_db(music_volume)
		print("AudioManager: Music volume set to: %.2f" % music_volume)
	else:
		print("AudioManager: Music volume updated to %.2f but muted" % music_volume)

func set_sfx_volume(volume: float) -> void:
	"""Set sound effects volume (0.0 to 1.0) - respects mute state"""
	original_sfx_volume = clamp(volume, 0.0, 1.0)
	sfx_volume = original_sfx_volume

	if not sfx_muted:
		sfx_player.volume_db = linear_to_db(sfx_volume)
		print("AudioManager: SFX volume set to: %.2f" % sfx_volume)
	else:
		print("AudioManager: SFX volume updated to %.2f but muted" % sfx_volume)

func stop_music() -> void:
	"""Stop background music"""
	music_player.stop()
	print("AudioManager: Background music stopped")

func pause_music() -> void:
	"""Pause background music"""
	music_player.stream_paused = true
	print("AudioManager: Background music paused")

func resume_music() -> void:
	"""Resume background music"""
	music_player.stream_paused = false
	print("AudioManager: Background music resumed")

func is_music_playing() -> bool:
	"""Check if background music is currently playing"""
	return music_player.playing and not music_player.stream_paused
