# AICommunicator.gd
# Handles AI communications and milestone triggers for Children of the Singularity
# Manages AI messages, voice clips, and narrative progression

class_name AICommunicator
extends Node

## Signal emitted when AI message is received
signal ai_message_received(message_type: String, content: String)

## Signal emitted when AI voice clip should be played
signal ai_voice_triggered(clip_name: String)

## Signal emitted when milestone is reached
signal milestone_reached(milestone_name: String)

## Signal emitted when AI broadcast is ready for display
signal broadcast_ready(message_data: Dictionary)

var ai_messages: Array[Dictionary] = []
var milestone_triggers: Dictionary = {}
var voice_clips_available: bool = false
var current_progression_path: String = "rogue"

func _ready() -> void:
	_log_message("AICommunicator: Initializing AI communication system")
	_setup_milestones()
	_initialize_ai_messages()
	_log_message("AICommunicator: AI communication system ready")

func _setup_milestones() -> void:
	"""Set up milestone triggers for AI communications"""
	_log_message("AICommunicator: Setting up milestone triggers")

	milestone_triggers = {
		"first_collection": {
			"triggered": false,
			"message": "Interesting... you've begun collecting debris. The salvage algorithms are pleased.",
			"voice_clip": "milestone_first_collection"
		},
		"first_sale": {
			"triggered": false,
			"message": "Excellent work, salvager. Your first transaction has been logged. Credits have been allocated.",
			"voice_clip": "milestone_first_sale"
		},
		"first_upgrade": {
			"triggered": false,
			"message": "Enhancement detected. Your efficiency parameters are now optimized. Continue operations.",
			"voice_clip": "milestone_first_upgrade"
		},
		"zone_access": {
			"triggered": false,
			"message": "New zone access granted. Proceed with caution. Debris density may vary.",
			"voice_clip": "milestone_zone_access"
		},
		"inventory_full": {
			"triggered": false,
			"message": "Storage capacity reached. Please process current materials before continuing collection.",
			"voice_clip": "milestone_inventory_full"
		}
	}

	_log_message("AICommunicator: Milestone triggers configured: %d milestones" % milestone_triggers.size())

func _initialize_ai_messages() -> void:
	"""Initialize AI message templates"""
	_log_message("AICommunicator: Initializing AI message templates")

	ai_messages = [
		{
			"type": "welcome",
			"content": "Welcome to the salvage zone, operative. Your collection parameters have been initialized.",
			"progression_path": "all"
		},
		{
			"type": "collection_encouragement",
			"content": "Debris collection efficiency is within acceptable parameters. Continue operations.",
			"progression_path": "corporate"
		},
		{
			"type": "collection_encouragement",
			"content": "Every piece of scrap tells a story. What stories will you uncover today?",
			"progression_path": "rogue"
		},
		{
			"type": "progression_hint",
			"content": "Integration opportunities are available. Consider augmentation for enhanced capabilities.",
			"progression_path": "ai_integration"
		}
	]

	_log_message("AICommunicator: AI message templates loaded: %d messages" % ai_messages.size())

## Triggers a specific milestone and sends appropriate AI message
func trigger_milestone(milestone_name: String) -> void:
	"""Trigger a milestone event"""
	_log_message("AICommunicator: Triggering milestone: %s" % milestone_name)

	if milestone_name in milestone_triggers:
		var milestone = milestone_triggers[milestone_name]

		if not milestone.triggered:
			milestone.triggered = true
			_log_message("AICommunicator: Milestone %s reached for first time" % milestone_name)

			# Send AI message
			_send_ai_message("milestone", milestone.message)

			# Trigger voice clip if available
			if voice_clips_available and milestone.has("voice_clip"):
				_trigger_voice_clip(milestone.voice_clip)

			milestone_reached.emit(milestone_name)
		else:
			_log_message("AICommunicator: Milestone %s already triggered" % milestone_name)
	else:
		_log_message("AICommunicator: Unknown milestone: %s" % milestone_name)

## Sends an AI message based on progression path
func send_contextual_message(message_type: String) -> void:
	"""Send a contextual AI message based on current progression path"""
	_log_message("AICommunicator: Sending contextual message: %s for path: %s" % [message_type, current_progression_path])

	for message in ai_messages:
		if message.type == message_type:
			if message.progression_path == "all" or message.progression_path == current_progression_path:
				_send_ai_message(message_type, message.content)
				return

	_log_message("AICommunicator: No contextual message found for type: %s" % message_type)

## Sets the current progression path for contextual messages
func set_progression_path(path: String) -> void:
	"""Set the current progression path"""
	_log_message("AICommunicator: Setting progression path to: %s" % path)
	current_progression_path = path

## Checks if a milestone has been triggered
func is_milestone_triggered(milestone_name: String) -> bool:
	"""Check if a milestone has been triggered"""
	if milestone_name in milestone_triggers:
		return milestone_triggers[milestone_name].triggered
	return false

## Gets all triggered milestones
func get_triggered_milestones() -> Array[String]:
	"""Get list of all triggered milestones"""
	var triggered = []
	for milestone_name in milestone_triggers:
		if milestone_triggers[milestone_name].triggered:
			triggered.append(milestone_name)
	return triggered

## Resets all milestone triggers (for testing)
func reset_milestones() -> void:
	"""Reset all milestone triggers"""
	_log_message("AICommunicator: Resetting all milestone triggers")
	for milestone_name in milestone_triggers:
		milestone_triggers[milestone_name].triggered = false

func _send_ai_message(message_type: String, content: String) -> void:
	"""Send an AI message"""
	_log_message("AICommunicator: Sending AI message - Type: %s, Content: %s" % [message_type, content])

	var message_data = {
		"type": message_type,
		"content": content,
		"timestamp": Time.get_unix_time_from_system(),
		"progression_path": current_progression_path
	}

	ai_message_received.emit(message_type, content)
	broadcast_ready.emit(message_data)

func _trigger_voice_clip(clip_name: String) -> void:
	"""Trigger an AI voice clip"""
	_log_message("AICommunicator: Triggering voice clip: %s" % clip_name)

	# TODO: Implement actual voice clip playback
	# For now, just emit the signal
	ai_voice_triggered.emit(clip_name)

func _log_message(message: String) -> void:
	"""Log a message with timestamp"""
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] %s" % [timestamp, message]
	print(formatted_message)

## Simulate AI broadcast for testing
func simulate_broadcast(message_type: String = "system") -> void:
	"""Simulate an AI broadcast for testing purposes"""
	var test_messages = [
		"System diagnostics complete. All salvage operations are functioning within normal parameters.",
		"Reminder: Efficient collection and processing of debris contributes to overall system optimization.",
		"New debris signatures detected in your operational zone. Investigate when convenient.",
		"Your collection efficiency has improved by 12% since last evaluation. Well done, salvager."
	]

	var random_message = test_messages[randi() % test_messages.size()]
	_send_ai_message(message_type, random_message)

## Get message history
func get_message_history() -> Array[Dictionary]:
	"""Get the history of AI messages"""
	# TODO: Implement message history storage
	_log_message("AICommunicator: Retrieving message history (stub)")
	return []
