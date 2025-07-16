# DebrisObject.gd
# Network-synchronized debris object for Children of the Singularity
# Provides methods for network synchronization and identification

extends RigidBody2D

func get_debris_id() -> String:
	##Get the unique debris ID for network synchronization
	return get_meta("debris_id", "unknown")

func get_debris_type() -> String:
	##Get the debris type
	return get_meta("debris_type", "unknown")

func get_debris_value() -> int:
	##Get the debris value
	return get_meta("debris_value", 0)

func get_debris_data() -> Dictionary:
	##Get complete debris data for network sync
	return {
		"id": get_debris_id(),
		"type": get_debris_type(),
		"value": get_debris_value(),
		"position": global_position,
		"rotation": rotation,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity
	}

func apply_network_state(state_data: Dictionary) -> void:
	##Apply network state to debris object
	if "position" in state_data:
		global_position = state_data.position
	if "rotation" in state_data:
		rotation = state_data.rotation
	if "linear_velocity" in state_data:
		linear_velocity = state_data.linear_velocity
	if "angular_velocity" in state_data:
		angular_velocity = state_data.angular_velocity

func _ready() -> void:
	##Initialize debris object
	# Add any initialization logic here
	pass
