extends Node

# AudioManager - Simple singleton for background music and sound effects
# Handles looping background music and one-shot sound effects

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

var music_volume: float = 0.8
var sfx_volume: float = 1.0

func _ready() -> void:
	print("AudioManager: Initializing audio system")

	# Add audio players as children
	add_child(music_player)
	add_child(sfx_player)

	# Set up audio buses
	music_player.bus = "Music"
	sfx_player.bus = "SFX"

	# Configure music player for looping
	music_player.finished.connect(_on_music_finished)

	# Set initial volumes
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)

	# Start background music
	play_background_music()

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
	"""Set music volume (0.0 to 1.0)"""
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)
	print("AudioManager: Music volume set to: ", music_volume)

func set_sfx_volume(volume: float) -> void:
	"""Set sound effects volume (0.0 to 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)
	sfx_player.volume_db = linear_to_db(sfx_volume)
	print("AudioManager: SFX volume set to: ", sfx_volume)

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
