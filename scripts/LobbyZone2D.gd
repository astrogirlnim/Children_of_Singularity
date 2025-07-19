# LobbyZone2D.gd
# 2D Retro Trading Lobby for Children of the Singularity
# Handles 2D pixel art lobby where players can see each other and trade

class_name LobbyZone2D
extends Node2D

## Signal emitted when lobby is fully loaded and ready
signal lobby_ready()

## Signal emitted when player interacts with trading computer
signal trading_computer_accessed()

## Signal emitted when player wants to exit lobby
signal lobby_exit_requested()

# Core lobby references
@onready var background: Sprite2D = $Background
@onready var lobby_player: CharacterBody2D = $LobbyPlayer2D
@onready var trading_computer: Area2D = $TradingComputer
@onready var computer_sprite: Sprite2D = $TradingComputer/ComputerSprite2D
@onready var exit_boundaries: Node2D = $ExitBoundaries

# UI Layer references
@onready var ui_layer: CanvasLayer = $UILayer
@onready var hud: Control = $UILayer/HUD
@onready var lobby_status: Label = $UILayer/HUD/LobbyStatus
@onready var interaction_prompt: Label = $UILayer/HUD/InteractionPrompt
@onready var trading_interface: Panel = $UILayer/HUD/TradingInterface

# System references - will be set from LocalPlayerData
var inventory_manager: Node
var upgrade_system: Node
var api_client: Node
var network_manager: Node

# Lobby state
var player_can_interact: bool = false
var computer_in_range: bool = false
var lobby_loaded: bool = false

# Screen dimensions for boundary checking
var screen_size: Vector2
var lobby_bounds: Rect2

# Debug and logging
var lobby_logs: Array[String] = []

func _ready() -> void:
	print("[LobbyZone2D] Initializing 2D trading lobby")
	_setup_lobby_environment()
	_setup_ui_elements()
	_setup_trading_interface()
	_setup_system_references()
	_setup_boundaries()

	# Mark lobby as ready
	lobby_loaded = true
	lobby_ready.emit()
	print("[LobbyZone2D] Lobby initialization complete")

func _process(_delta: float) -> void:
	# Handle input for interaction and exit
	if Input.is_action_just_pressed("interact") and computer_in_range:
		_interact_with_computer()

	# Check for exit boundaries
	_check_exit_boundaries()

func _setup_lobby_environment() -> void:
	##Setup the 2D lobby visual environment
	print("[LobbyZone2D] Setting up lobby environment")

	# Get screen size for proper scaling
	screen_size = get_viewport().get_visible_rect().size
	print("[LobbyZone2D] Screen size: %s" % screen_size)

	# Setup background to fit screen size
	if background:
		# Load the horizontal trading hub background
		var background_texture = preload("res://assets/trading_hub_pixel_horizontal.png")
		background.texture = background_texture

		# Scale background to fit screen while maintaining aspect ratio
		if background_texture:
			var texture_size = background_texture.get_size()
			var scale_factor = max(screen_size.x / texture_size.x, screen_size.y / texture_size.y)
			background.scale = Vector2(scale_factor, scale_factor)
			background.position = screen_size / 2
			print("[LobbyZone2D] Background scaled to: %s at position: %s" % [background.scale, background.position])

	# Setup trading computer sprite
	if computer_sprite:
		var computer_texture = preload("res://assets/computer_trading_hub_sprite.png")
		computer_sprite.texture = computer_texture

		# Position computer in a good spot (adjust as needed)
		trading_computer.position = Vector2(screen_size.x * 0.7, screen_size.y * 0.5)
		print("[LobbyZone2D] Trading computer positioned at: %s" % trading_computer.position)

func _setup_ui_elements() -> void:
	##Setup lobby-specific UI elements
	print("[LobbyZone2D] Setting up UI elements")

	if lobby_status:
		lobby_status.text = "Welcome to the Trading Lobby"
		lobby_status.position = Vector2(20, 20)

	if interaction_prompt:
		interaction_prompt.text = ""
		interaction_prompt.position = Vector2(screen_size.x / 2, screen_size.y - 100)
		interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		interaction_prompt.visible = false

func _setup_trading_interface() -> void:
	##Setup the trading interface that was moved from 3D overlay
	print("[LobbyZone2D] Setting up trading interface")

	if trading_interface:
		# Hide initially
		trading_interface.visible = false

		# Position in center of screen
		trading_interface.position = Vector2(screen_size.x * 0.2, screen_size.y * 0.1)
		trading_interface.size = Vector2(screen_size.x * 0.6, screen_size.y * 0.8)

		print("[LobbyZone2D] Trading interface configured - position: %s, size: %s" % [trading_interface.position, trading_interface.size])

func _setup_system_references() -> void:
	##Setup references to game systems from singletons/autoloads
	print("[LobbyZone2D] Setting up system references")

	# Get references from LocalPlayerData singleton
	if LocalPlayerData:
		inventory_manager = LocalPlayerData.inventory_manager
		print("[LobbyZone2D] Connected to InventoryManager")

	# Get UpgradeSystem reference
	upgrade_system = get_node_or_null("/root/UpgradeSystem")
	if upgrade_system:
		print("[LobbyZone2D] Connected to UpgradeSystem")

	# Get APIClient reference
	api_client = get_node_or_null("/root/APIClient")
	if api_client:
		print("[LobbyZone2D] Connected to APIClient")

	# Get NetworkManager reference
	network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager:
		print("[LobbyZone2D] Connected to NetworkManager")

func _setup_boundaries() -> void:
	##Setup exit boundaries for the lobby
	print("[LobbyZone2D] Setting up lobby boundaries")

	# Define lobby bounds based on screen size with some padding
	var padding = 50
	lobby_bounds = Rect2(-padding, -padding, screen_size.x + padding * 2, screen_size.y + padding * 2)
	print("[LobbyZone2D] Lobby bounds set to: %s" % lobby_bounds)

func _check_exit_boundaries() -> void:
	##Check if player has moved outside lobby boundaries
	if not lobby_player:
		return

	var player_pos = lobby_player.global_position

	# Check if player is outside lobby bounds
	if not lobby_bounds.has_point(player_pos):
		print("[LobbyZone2D] Player attempting to exit lobby at position: %s" % player_pos)
		_prompt_lobby_exit()

func _prompt_lobby_exit() -> void:
	##Prompt player if they want to exit the lobby
	print("[LobbyZone2D] Prompting lobby exit")

	# Simple confirmation approach - could be enhanced with a dialog later
	lobby_exit_requested.emit()

	# Return to 3D world immediately for now
	# TODO: Add confirmation dialog asking "Exit lobby? (Y/N)"
	return_to_3d_world()

func _interact_with_computer() -> void:
	##Handle interaction with the trading computer
	if not computer_in_range:
		return

	print("[LobbyZone2D] Player interacting with trading computer")

	# Show the trading interface
	if trading_interface:
		trading_interface.visible = true
		print("[LobbyZone2D] Trading interface opened")

		# Pause player movement while trading
		if lobby_player and lobby_player.has_method("set_movement_enabled"):
			lobby_player.set_movement_enabled(false)

	trading_computer_accessed.emit()

func close_trading_interface() -> void:
	##Close the trading interface and resume player movement
	print("[LobbyZone2D] Closing trading interface")

	if trading_interface:
		trading_interface.visible = false

	# Resume player movement
	if lobby_player and lobby_player.has_method("set_movement_enabled"):
		lobby_player.set_movement_enabled(true)

func _on_trading_computer_area_entered(_body: Node2D) -> void:
	##Handle player entering trading computer interaction area
	computer_in_range = true
	player_can_interact = true

	if interaction_prompt:
		interaction_prompt.text = "Press F to access Trading Terminal"
		interaction_prompt.visible = true

	print("[LobbyZone2D] Player can now interact with trading computer")

func _on_trading_computer_area_exited(_body: Node2D) -> void:
	##Handle player exiting trading computer interaction area
	computer_in_range = false
	player_can_interact = false

	if interaction_prompt:
		interaction_prompt.visible = false

	print("[LobbyZone2D] Player no longer in range of trading computer")

func return_to_3d_world() -> void:
	##Return player to the 3D world
	print("[LobbyZone2D] Returning to 3D world")

	# Store lobby state if needed
	if LocalPlayerData:
		LocalPlayerData.save_player_data()

	# Change scene back to 3D zone
	get_tree().change_scene_to_file("res://scenes/zones/ZoneMain3D.tscn")

func log_message(message: String) -> void:
	##Add a message to the lobby log
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] [LOBBY] %s" % [timestamp, message]
	lobby_logs.append(formatted_message)
	print(formatted_message)

	# Keep only last 100 messages
	if lobby_logs.size() > 100:
		lobby_logs = lobby_logs.slice(lobby_logs.size() - 100, lobby_logs.size())

## Properties

func get_lobby_status() -> Dictionary:
	##Get current lobby status
	return {
		"loaded": lobby_loaded,
		"player_position": lobby_player.global_position if lobby_player else Vector2.ZERO,
		"computer_in_range": computer_in_range,
		"trading_interface_open": trading_interface.visible if trading_interface else false
	}
