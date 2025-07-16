# ZoneAIHandler.gd
# AI handler for Children of the Singularity
# Manages AI communication, messages, and milestone tracking

class_name ZoneAIHandler
extends Node

## Signal emitted when AI message is received
signal ai_message_received(message: String, priority: int)

## Signal emitted when milestone is reached
signal milestone_reached(milestone_type: String, value: int)

## Signal emitted when AI broadcast is ready
signal ai_broadcast_ready(broadcast_data: Dictionary)

## Signal emitted when AI analysis is complete
signal ai_analysis_complete(analysis_data: Dictionary)

@export var ai_communicator: AICommunicator
@export var analysis_interval: float = 30.0
@export var milestone_check_interval: float = 10.0

# AI state
var active_messages: Array[Dictionary] = []
var milestone_thresholds: Dictionary = {
	"debris_collected": [10, 25, 50, 100, 250, 500],
	"credits_earned": [100, 500, 1000, 5000, 10000],
	"upgrades_purchased": [1, 3, 5, 10],
	"time_played": [300, 900, 1800, 3600]  # seconds
}
var reached_milestones: Dictionary = {}

# Timers
var analysis_timer: float = 0.0
var milestone_timer: float = 0.0
var start_time: float = 0.0

# Game state tracking
var game_stats: Dictionary = {
	"debris_collected": 0,
	"credits_earned": 0,
	"upgrades_purchased": 0,
	"time_played": 0.0
}

func _ready() -> void:
	print("ZoneAIHandler: Initializing AI handler")
	start_time = Time.get_ticks_msec() / 1000.0
	_setup_ai_connections()
	_initialize_milestones()

func _process(delta: float) -> void:
	analysis_timer += delta
	milestone_timer += delta
	game_stats["time_played"] = (Time.get_ticks_msec() / 1000.0) - start_time

	if analysis_timer >= analysis_interval:
		analysis_timer = 0.0
		_perform_ai_analysis()

	if milestone_timer >= milestone_check_interval:
		milestone_timer = 0.0
		_check_milestones()

func _setup_ai_connections() -> void:
	## Setup connections with AI communicator
	if ai_communicator:
		if ai_communicator.has_signal("ai_message_received"):
			ai_communicator.ai_message_received.connect(_on_ai_message_received)
		if ai_communicator.has_signal("milestone_reached"):
			ai_communicator.milestone_reached.connect(_on_milestone_reached)
		if ai_communicator.has_signal("broadcast_ready"):
			ai_communicator.broadcast_ready.connect(_on_ai_broadcast_ready)

		print("ZoneAIHandler: AI communicator connections established")

func _initialize_milestones() -> void:
	## Initialize milestone tracking
	for milestone_type in milestone_thresholds:
		reached_milestones[milestone_type] = []

	print("ZoneAIHandler: Milestone tracking initialized")

func _perform_ai_analysis() -> void:
	## Perform periodic AI analysis of game state
	var analysis_data = {
		"timestamp": Time.get_ticks_msec(),
		"game_stats": game_stats.duplicate(),
		"active_messages": active_messages.size(),
		"recent_milestones": _get_recent_milestones()
	}

	# Send to AI communicator if available
	if ai_communicator and ai_communicator.has_method("analyze_game_state"):
		ai_communicator.analyze_game_state(analysis_data)

	ai_analysis_complete.emit(analysis_data)
	print("ZoneAIHandler: AI analysis performed")

func _check_milestones() -> void:
	## Check if any milestones have been reached
	for milestone_type in milestone_thresholds:
		var current_value = game_stats.get(milestone_type, 0)
		var thresholds = milestone_thresholds[milestone_type]
		var reached = reached_milestones[milestone_type]

		for threshold in thresholds:
			if current_value >= threshold and not threshold in reached:
				reached_milestones[milestone_type].append(threshold)
				_trigger_milestone(milestone_type, threshold)

func _trigger_milestone(milestone_type: String, value: int) -> void:
	##Trigger milestone achievement
	var milestone_data = {
		"type": milestone_type,
		"value": value,
		"timestamp": Time.get_ticks_msec(),
		"current_stats": game_stats.duplicate()
	}

	milestone_reached.emit(milestone_type, value)

	# Generate AI message for milestone
	var message = _generate_milestone_message(milestone_type, value)
	if message != "":
		_queue_ai_message(message, 2)  # Medium priority

	print("ZoneAIHandler: Milestone reached - %s: %d" % [milestone_type, value])

func _generate_milestone_message(milestone_type: String, value: int) -> String:
	##Generate contextual message for milestone
	match milestone_type:
		"debris_collected":
			match value:
				10: return "Nice work! You're getting the hang of debris collection."
				25: return "You're building up a good collection rate!"
				50: return "Excellent progress! The salvage operation is going well."
				100: return "Outstanding! You're becoming quite efficient at this."
				250: return "Impressive salvage skills! The AI is taking notice."
				500: return "Exceptional work! You're among the top salvage operators."

		"credits_earned":
			match value:
				100: return "Your first hundred credits! A solid foundation."
				500: return "Five hundred credits earned! You're getting profitable."
				1000: return "One thousand credits! You're doing well financially."
				5000: return "Five thousand credits! Quite the entrepreneur."
				10000: return "Ten thousand credits! You're incredibly successful."

		"upgrades_purchased":
			match value:
				1: return "Your first upgrade! Smart investment in your capabilities."
				3: return "Three upgrades! You're building a capable ship."
				5: return "Five upgrades! Your ship is becoming quite advanced."
				10: return "Ten upgrades! You've built an impressive vessel."

		"time_played":
			match value:
				300: return "Five minutes in! You're getting comfortable with the controls."
				900: return "Fifteen minutes of exploration! You're finding your rhythm."
				1800: return "Half an hour of salvage work! You're becoming experienced."
				3600: return "One hour of dedication! You're a committed operator."

	return ""

func _get_recent_milestones() -> Array:
	##Get recently reached milestones
	var recent: Array = []
	var current_time = Time.get_ticks_msec()

	for message in active_messages:
		var age = current_time - message.get("timestamp", 0)
		if age < 60000:  # Last minute
			recent.append(message)

	return recent

## Public API Methods

func update_game_stat(stat_name: String, value: int) -> void:
	##Update a game statistic
	if stat_name in game_stats:
		game_stats[stat_name] = value
		print("ZoneAIHandler: Updated %s to %d" % [stat_name, value])

func increment_game_stat(stat_name: String, amount: int = 1) -> void:
	##Increment a game statistic
	if stat_name in game_stats:
		game_stats[stat_name] += amount
		print("ZoneAIHandler: Incremented %s by %d (now %d)" % [stat_name, amount, game_stats[stat_name]])

func send_ai_message(message: String, priority: int = 1) -> void:
	##Send message to AI system
	_queue_ai_message(message, priority)

func _queue_ai_message(message: String, priority: int) -> void:
	##Queue an AI message for processing
	var message_data = {
		"content": message,
		"priority": priority,
		"timestamp": Time.get_ticks_msec()
	}

	active_messages.append(message_data)

	# Keep only recent messages
	if active_messages.size() > 50:
		active_messages = active_messages.slice(active_messages.size() - 50, active_messages.size())

	ai_message_received.emit(message, priority)
	print("ZoneAIHandler: AI message queued: %s" % message)

func request_ai_analysis() -> void:
	##Request immediate AI analysis
	_perform_ai_analysis()

func get_game_stats() -> Dictionary:
	##Get current game statistics
	return game_stats.duplicate()

func get_milestone_progress() -> Dictionary:
	##Get milestone progress data
	var progress = {}

	for milestone_type in milestone_thresholds:
		var current_value = game_stats.get(milestone_type, 0)
		var thresholds = milestone_thresholds[milestone_type]
		var reached = reached_milestones[milestone_type]

		# Find next milestone
		var next_milestone = -1
		for threshold in thresholds:
			if current_value < threshold:
				next_milestone = threshold
				break

		progress[milestone_type] = {
			"current": current_value,
			"next_milestone": next_milestone,
			"reached_count": reached.size(),
			"total_milestones": thresholds.size()
		}

	return progress

func clear_old_messages() -> void:
	##Clear old AI messages
	var current_time = Time.get_ticks_msec()
	var fresh_messages: Array[Dictionary] = []

	for message in active_messages:
		var age = current_time - message.get("timestamp", 0)
		if age < 300000:  # Keep messages from last 5 minutes
			fresh_messages.append(message)

	active_messages = fresh_messages
	print("ZoneAIHandler: Cleared old messages, %d remaining" % active_messages.size())

func reset_session() -> void:
	##Reset session data
	game_stats = {
		"debris_collected": 0,
		"credits_earned": 0,
		"upgrades_purchased": 0,
		"time_played": 0.0
	}

	reached_milestones.clear()
	_initialize_milestones()

	active_messages.clear()
	start_time = Time.get_ticks_msec() / 1000.0

	print("ZoneAIHandler: Session reset")

## Signal handlers

func _on_ai_message_received(message: String, priority: int) -> void:
	##Handle AI message received from communicator
	ai_message_received.emit(message, priority)
	print("ZoneAIHandler: AI message forwarded: %s" % message)

func _on_milestone_reached(milestone_type: String, value: int) -> void:
	##Handle milestone reached from communicator
	milestone_reached.emit(milestone_type, value)
	print("ZoneAIHandler: Milestone forwarded: %s = %d" % [milestone_type, value])

func _on_ai_broadcast_ready(broadcast_data: Dictionary) -> void:
	##Handle AI broadcast ready from communicator
	ai_broadcast_ready.emit(broadcast_data)
	print("ZoneAIHandler: AI broadcast ready")

## Event handlers for game events

func on_debris_collected(debris_type: String, value: int) -> void:
	##Handle debris collection event
	increment_game_stat("debris_collected")
	increment_game_stat("credits_earned", value)

func on_upgrade_purchased(upgrade_type: String, cost: int) -> void:
	##Handle upgrade purchase event
	increment_game_stat("upgrades_purchased")

func on_player_action(action_type: String, data: Dictionary = {}) -> void:
	##Handle general player action for AI context
	var action_message = "Player performed: %s" % action_type
	if data.size() > 0:
		action_message += " - %s" % data

	_queue_ai_message(action_message, 0)  # Low priority
