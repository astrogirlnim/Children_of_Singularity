# ZoneMain.gd
# Main zone controller for Children of the Singularity
# Manages the primary gameplay zone where players explore and collect debris

class_name ZoneMain
extends Node2D

## Signal emitted when zone is fully loaded and ready for gameplay
signal zone_ready()

## Signal emitted when debris is collected
signal debris_collected(debris_type: String, value: int)

## Signal emitted when player enters NPC hub area
signal npc_hub_entered()

@onready var camera_2d: Camera2D = $Camera2D
@onready var player_ship: CharacterBody2D = $PlayerShip
@onready var debris_container: Node2D = $DebrisContainer
@onready var hud: Control = $UILayer/HUD
@onready var debug_label: Label = $UILayer/HUD/DebugLabel
@onready var log_label: Label = $UILayer/HUD/LogLabel

var zone_name: String = "Zone Alpha"
var zone_id: String = "zone_alpha_01"
var max_debris_count: int = 50
var current_debris_count: int = 0
var zone_bounds: Rect2 = Rect2(-1000, -1000, 2000, 2000)
var game_logs: Array[String] = []

func _ready() -> void:
	_log_message("ZoneMain: Initializing zone controller")
	_initialize_zone()
	_spawn_initial_debris()
	_update_debug_display()
	
	# Connect player signals
	if player_ship:
		player_ship.debris_collected.connect(_on_debris_collected)
		player_ship.position_changed.connect(_on_player_position_changed)
	
	_log_message("ZoneMain: Zone ready for gameplay")
	zone_ready.emit()

func _initialize_zone() -> void:
	"""Initialize the zone with basic settings and validate components"""
	_log_message("ZoneMain: Setting up zone bounds and camera")
	
	# Set camera limits based on zone bounds
	if camera_2d:
		camera_2d.limit_left = int(zone_bounds.position.x)
		camera_2d.limit_top = int(zone_bounds.position.y)
		camera_2d.limit_right = int(zone_bounds.end.x)
		camera_2d.limit_bottom = int(zone_bounds.end.y)
	
	# Initialize HUD
	if debug_label:
		debug_label.text = "Children of the Singularity - %s [DEBUG]" % zone_name
	
	_log_message("ZoneMain: Zone initialization complete")

func _spawn_initial_debris() -> void:
	"""Spawn initial debris objects in the zone"""
	_log_message("ZoneMain: Spawning initial debris (placeholder)")
	
	# TODO: Implement actual debris spawning system
	# For now, just log that we would spawn debris
	for i in range(10):
		var debris_pos = Vector2(
			randf_range(zone_bounds.position.x, zone_bounds.end.x),
			randf_range(zone_bounds.position.y, zone_bounds.end.y)
		)
		_log_message("ZoneMain: Would spawn debris at %s" % debris_pos)
	
	current_debris_count = 10
	_log_message("ZoneMain: Initial debris spawn complete (%d objects)" % current_debris_count)

func _on_debris_collected(debris_type: String, value: int) -> void:
	"""Handle debris collection events from player"""
	_log_message("ZoneMain: Debris collected - Type: %s, Value: %d" % [debris_type, value])
	current_debris_count -= 1
	debris_collected.emit(debris_type, value)
	_update_debug_display()

func _on_player_position_changed(new_position: Vector2) -> void:
	"""Handle player position updates for camera tracking"""
	if camera_2d:
		camera_2d.global_position = new_position

func _update_debug_display() -> void:
	"""Update the debug information display"""
	if debug_label:
		debug_label.text = "Children of the Singularity - %s [DEBUG] | Debris: %d/%d" % [zone_name, current_debris_count, max_debris_count]

func _log_message(message: String) -> void:
	"""Add a message to the game log and display it"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	
	print(formatted_message)
	game_logs.append(formatted_message)
	
	# Keep only last 10 log entries for display
	if game_logs.size() > 10:
		game_logs.pop_front()
	
	# Update log display
	if log_label:
		log_label.text = "Console Log:\n" + "\n".join(game_logs)

## Get the current zone information
func get_zone_info() -> Dictionary:
	return {
		"zone_name": zone_name,
		"zone_id": zone_id,
		"bounds": zone_bounds,
		"debris_count": current_debris_count,
		"max_debris": max_debris_count
	}

## Manually spawn debris at a specific position
func spawn_debris_at(position: Vector2, debris_type: String = "generic") -> void:
	_log_message("ZoneMain: Spawning %s debris at %s" % [debris_type, position])
	# TODO: Implement actual debris spawning
	current_debris_count += 1
	_update_debug_display()

## Clear all debris from the zone
func clear_all_debris() -> void:
	_log_message("ZoneMain: Clearing all debris from zone")
	# TODO: Implement actual debris clearing
	current_debris_count = 0
	_update_debug_display()

## Reset the zone to its initial state
func reset_zone() -> void:
	_log_message("ZoneMain: Resetting zone to initial state")
	clear_all_debris()
	_spawn_initial_debris()
	zone_ready.emit() 