# TradingHub3D.gd
# 3D Trading Hub for Children of the Singularity
# Provides trading functionality with billboard sprite display for 2.5D aesthetic

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

## Hub state
var is_active: bool = true
var current_players: Array[Node3D] = []

func _ready() -> void:
	_log_message("TradingHub3D: Initializing %s" % hub_name)
	_setup_hub()
	_connect_signals()

func _setup_hub() -> void:
	##Set up the trading hub configuration
	_log_message("TradingHub3D: Setting up hub configuration")

	# Configure sprite billboard mode for 2.5D aesthetic
	if hub_sprite_3d:
		hub_sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hub_sprite_3d.pixel_size = 0.02  # Scale for proper size in 3D
		_log_message("TradingHub3D: Sprite3D configured with billboard mode")

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
