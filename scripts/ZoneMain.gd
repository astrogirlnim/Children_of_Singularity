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
@onready var npc_hub_container: Node2D = $NPCHubContainer

# Camera zoom settings
var default_zoom: float = 1.0
var min_zoom: float = 0.5
var max_zoom: float = 2.0
var zoom_speed: float = 2.0
var current_zoom: float = 1.0
@onready var hud: Control = $UILayer/HUD
@onready var debug_label: Label = $UILayer/HUD/DebugLabel
@onready var log_label: Label = $UILayer/HUD/LogLabel
@onready var api_client: Node = $APIClient
@onready var upgrade_system: Node = $UpgradeSystem
@onready var ai_communicator: AICommunicator = $AICommunicator
@onready var network_manager: NetworkManager = $NetworkManager

# UI Components
@onready var inventory_panel: Panel = $UILayer/HUD/InventoryPanel
@onready var inventory_grid: GridContainer = $UILayer/HUD/InventoryPanel/InventoryGrid
@onready var inventory_status: Label = $UILayer/HUD/InventoryPanel/InventoryStatus
@onready var credits_label: Label = $UILayer/HUD/StatsPanel/CreditsLabel
@onready var debris_count_label: Label = $UILayer/HUD/StatsPanel/DebrisCountLabel
@onready var collection_range_label: Label = $UILayer/HUD/StatsPanel/CollectionRangeLabel
@onready var ai_message_overlay: Panel = $UILayer/HUD/AIMessageOverlay
@onready var ai_message_label: Label = $UILayer/HUD/AIMessageOverlay/AIMessageLabel

# Upgrade Status Components
@onready var upgrade_status_panel: Panel = $UILayer/HUD/UpgradeStatusPanel
@onready var upgrade_status_text: Label = $UILayer/HUD/UpgradeStatusPanel/UpgradeStatusText

# Trading Interface Components
@onready var trading_interface: Panel = $UILayer/HUD/TradingInterface
@onready var trading_title: Label = $UILayer/HUD/TradingInterface/TradingTitle
@onready var sell_all_button: Button = $UILayer/HUD/TradingInterface/TradingContent/SellAllButton
@onready var trading_result: Label = $UILayer/HUD/TradingInterface/TradingContent/TradingResult
@onready var trading_close_button: Button = $UILayer/HUD/TradingInterface/TradingCloseButton

# Network Management
var network_players: Dictionary = {}
var is_multiplayer_server: bool = false
var is_multiplayer_client: bool = false

var zone_name: String = "Zone Alpha"
var zone_id: String = "zone_alpha_01"
var max_debris_count: int = 50
var current_debris_count: int = 0
var zone_bounds: Rect2 = Rect2(-1000, -1000, 2000, 2000)
var game_logs: Array[String] = []

# Debris spawning properties
var debris_types: Array[Dictionary] = [
	{"type": "scrap_metal", "value": 5, "spawn_weight": 40, "color": Color.GRAY},
	{"type": "broken_satellite", "value": 150, "spawn_weight": 10, "color": Color.SILVER},
	{"type": "bio_waste", "value": 25, "spawn_weight": 25, "color": Color.GREEN},
	{"type": "ai_component", "value": 500, "spawn_weight": 5, "color": Color.CYAN},
	{"type": "unknown_artifact", "value": 1000, "spawn_weight": 1, "color": Color.PURPLE}
]

# UI Management
var inventory_items: Array[Control] = []
var ui_update_timer: float = 0.0
var ui_update_interval: float = 0.5
var last_inventory_size: int = 0
var last_inventory_hash: String = ""
var network_update_timer: float = 0.0
var network_update_interval: float = 0.1

# Trading system
var current_hub_type: String = ""
var trading_open: bool = false

func _ready() -> void:
	_log_message("ZoneMain: Initializing zone controller")
	_setup_zone_background()
	_initialize_zone()
	_spawn_initial_debris()
	_setup_ui_connections()
	_setup_npc_hubs()
	_update_debug_display()

	# Initialize camera zoom
	_initialize_camera_zoom()

	# Connect player signals
	if player_ship:
		player_ship.debris_collected.connect(_on_debris_collected)
		player_ship.position_changed.connect(_on_player_position_changed)
		player_ship.npc_hub_entered.connect(_on_npc_hub_entered)
		player_ship.npc_hub_exited.connect(_on_npc_hub_exited)

	# Connect API client signals
	if api_client:
		if api_client.has_signal("player_data_loaded"):
			api_client.player_data_loaded.connect(_on_player_data_loaded)
		if api_client.has_signal("credits_updated"):
			api_client.credits_updated.connect(_on_credits_updated)
		if api_client.has_signal("inventory_updated"):
			api_client.inventory_updated.connect(_on_inventory_updated)
		if api_client.has_signal("api_error"):
			api_client.api_error.connect(_on_api_error)

		# Check backend health on startup
		if api_client.has_method("check_health"):
			api_client.check_health()

	# Connect upgrade system signals
	if upgrade_system:
		upgrade_system.upgrade_purchased.connect(_on_upgrade_purchased)
		upgrade_system.upgrade_purchase_failed.connect(_on_upgrade_purchase_failed)
		upgrade_system.upgrade_effects_applied.connect(_on_upgrade_effects_applied)

	# Connect network manager signals
	if network_manager:
		network_manager.connected_to_server.connect(_on_connected_to_server)
		network_manager.disconnected_from_server.connect(_on_disconnected_from_server)
		network_manager.player_joined.connect(_on_network_player_joined)
		network_manager.player_left.connect(_on_network_player_left)
		network_manager.player_position_updated.connect(_on_network_player_position_updated)
		network_manager.debris_collected_by_player.connect(_on_network_debris_collected)
		network_manager.server_state_updated.connect(_on_network_server_state_updated)

		# Initialize networking (attempt to start as server first)
		_initialize_networking()

	# Connect AI communicator signals
	if ai_communicator:
		ai_communicator.ai_message_received.connect(_on_ai_message_received)
		ai_communicator.milestone_reached.connect(_on_milestone_reached)
		ai_communicator.broadcast_ready.connect(_on_ai_broadcast_ready)

	_log_message("ZoneMain: Zone ready for gameplay")
	zone_ready.emit()

func _process(delta: float) -> void:
	"""Update UI periodically"""
	ui_update_timer += delta
	if ui_update_timer >= ui_update_interval:
		_update_ui()
		ui_update_timer = 0.0

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

func _setup_ui_connections() -> void:
	"""Set up UI connections and initial state"""
	_log_message("ZoneMain: Setting up UI connections")

	# Clear any existing inventory items
	_clear_inventory_display()

	# Initialize UI state
	_update_ui()

	# Connect trading interface signals
	if sell_all_button:
		sell_all_button.pressed.connect(_on_sell_all_pressed)

	if trading_close_button:
		trading_close_button.pressed.connect(_on_trading_close_pressed)

	_log_message("ZoneMain: UI connections established")

func _setup_npc_hubs() -> void:
	"""Set up NPC hub visual components"""
	_log_message("ZoneMain: Setting up NPC hubs")

	# Find all NPC hubs and set up their visual components
	for hub in npc_hub_container.get_children():
		if hub is StaticBody2D:
			_setup_npc_hub_visuals(hub)

	_log_message("ZoneMain: NPC hubs setup complete")

func _setup_npc_hub_visuals(hub: StaticBody2D) -> void:
	"""Set up visual components for an NPC hub"""
	var sprite = hub.get_node("HubSprite")
	if sprite:
		# Create a more sophisticated hub texture
		var texture = ImageTexture.new()
		var image = Image.create(150, 150, false, Image.FORMAT_RGBA8)

		# Create a gradient background
		for x in range(150):
			for y in range(150):
				var distance_from_center = Vector2(x - 75, y - 75).length()
				var normalized_distance = distance_from_center / 75.0
				var color_intensity = 1.0 - (normalized_distance * 0.3)
				var base_color = Color(0.8, 0.6, 0.2, 1.0)
				image.set_pixel(x, y, base_color * color_intensity)

		# Add a border
		for x in range(150):
			for y in range(150):
				if x < 5 or x > 144 or y < 5 or y > 144:
					image.set_pixel(x, y, Color(1.0, 0.8, 0.4, 1.0))

		texture.set_image(image)
		sprite.texture = texture

func _update_ui() -> void:
	"""Update all UI elements with current game state"""
	if not player_ship:
		return

	var player_info = player_ship.get_player_info()

	# Update inventory display
	_update_inventory_display(player_info.inventory)

	# Update stats
	if credits_label:
		credits_label.text = "Credits: %d" % player_info.credits

	if debris_count_label:
		debris_count_label.text = "Nearby Debris: %d" % player_info.nearby_debris_count

	if collection_range_label:
		collection_range_label.text = "Collection Range: %.0f" % player_ship.collection_range

	# Update inventory status
	if inventory_status:
		inventory_status.text = "%d/%d Items" % [player_info.inventory.size(), player_info.inventory_capacity]

func _update_inventory_display(inventory: Array[Dictionary]) -> void:
	"""Update the inventory grid display"""
	if not inventory_grid:
		return

	# Clear existing items
	_clear_inventory_display()

	# Add current inventory items
	for item in inventory:
		_add_inventory_item_to_display(item)

func _clear_inventory_display() -> void:
	"""Clear all items from the inventory display"""
	if not inventory_grid:
		return

	for child in inventory_grid.get_children():
		child.queue_free()

	inventory_items.clear()

func _add_inventory_item_to_display(item: Dictionary) -> void:
	"""Add an item to the inventory display with interactive functionality"""
	if not inventory_grid:
		return

	# Create interactive item button
	var item_button = Button.new()
	item_button.custom_minimum_size = Vector2(80, 80)
	item_button.flat = true

	# Get item color based on type
	var item_color = _get_item_color(item.type)

	# Create custom style for the button
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = item_color
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color.WHITE
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = item_color.lightened(0.2)
	style_hover.border_width_left = 2
	style_hover.border_width_right = 2
	style_hover.border_width_top = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color.YELLOW
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4

	item_button.add_theme_stylebox_override("normal", style_normal)
	item_button.add_theme_stylebox_override("hover", style_hover)
	item_button.add_theme_stylebox_override("pressed", style_hover)

	# Create item label
	item_button.text = "%s\nVal: %d" % [_get_item_display_name(item.type), item.value]
	item_button.alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Store item data in button
	item_button.set_meta("item_data", item)

	# Connect button signals for interactivity
	item_button.pressed.connect(_on_inventory_item_clicked.bind(item))
	item_button.mouse_entered.connect(_on_inventory_item_hovered.bind(item))
	item_button.mouse_exited.connect(_on_inventory_item_unhovered.bind(item))

	inventory_grid.add_child(item_button)
	inventory_items.append(item_button)

func _get_item_color(item_type: String) -> Color:
	"""Get the display color for an item type"""
	for debris_type in debris_types:
		if debris_type.type == item_type:
			return debris_type.color
	return Color.WHITE

func _get_item_display_name(item_type: String) -> String:
	"""Get a friendly display name for an item type"""
	match item_type:
		"scrap_metal":
			return "Scrap\nMetal"
		"broken_satellite":
			return "Broken\nSatellite"
		"bio_waste":
			return "Bio\nWaste"
		"ai_component":
			return "AI\nComponent"
		"unknown_artifact":
			return "Unknown\nArtifact"
		_:
			return "Unknown\nItem"

func _spawn_initial_debris() -> void:
	"""Spawn initial debris objects in the zone"""
	_log_message("ZoneMain: Spawning initial debris objects")

	# Clear existing debris
	for child in debris_container.get_children():
		child.queue_free()

	current_debris_count = 0

	# Spawn debris objects
	for i in range(max_debris_count):
		_spawn_debris_object()

	_log_message("ZoneMain: Initial debris spawn complete (%d objects)" % current_debris_count)

func _spawn_debris_object() -> void:
	"""Spawn a single debris object"""
	if current_debris_count >= max_debris_count:
		return

	# Choose debris type based on spawn weights
	var debris_type_data = _get_weighted_debris_type()

	# Create debris object
	var debris_object = _create_debris_object(debris_type_data)

	# Set random position within zone bounds
	var spawn_position = Vector2(
		randf_range(zone_bounds.position.x + 100, zone_bounds.end.x - 100),
		randf_range(zone_bounds.position.y + 100, zone_bounds.end.y - 100)
	)

	debris_object.global_position = spawn_position
	debris_container.add_child(debris_object)

	current_debris_count += 1

	_log_message("ZoneMain: Spawned %s debris at %s" % [debris_type_data.type, spawn_position])

func _get_weighted_debris_type() -> Dictionary:
	"""Get a random debris type based on spawn weights"""
	var total_weight = 0
	for debris_type in debris_types:
		total_weight += debris_type.spawn_weight

	var random_value = randf() * total_weight
	var current_weight = 0

	for debris_type in debris_types:
		current_weight += debris_type.spawn_weight
		if random_value <= current_weight:
			return debris_type

	# Fallback to first type
	return debris_types[0]

func _create_debris_object(debris_type_data: Dictionary) -> RigidBody2D:
	"""Create a debris object with collision and visual components"""
	var debris_object = RigidBody2D.new()
	debris_object.name = "Debris_%s_%d" % [debris_type_data.type, current_debris_count]
	debris_object.collision_layer = 4  # debris layer
	debris_object.collision_mask = 1   # can collide with player
	debris_object.gravity_scale = 0    # no gravity in space
	debris_object.linear_damp = 0.5    # slight damping for realistic movement
	debris_object.angular_damp = 0.3

	# Create visual representation
	var sprite = Sprite2D.new()
	sprite.name = "DebrisSprite"

	# Create a more sophisticated debris texture
	var size = 32
	var texture = ImageTexture.new()
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)

	# Base color with some variation
	var base_color = debris_type_data.color
	for x in range(size):
		for y in range(size):
			var distance_from_center = Vector2(x - size/2, y - size/2).length()
			if distance_from_center < size/2:
				var color_variation = randf_range(0.8, 1.2)
				var pixel_color = base_color * color_variation
				pixel_color.a = 1.0
				image.set_pixel(x, y, pixel_color)
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)

	# Add some highlights for different debris types
	match debris_type_data.type:
		"broken_satellite":
			# Add some metallic highlights
			for i in range(5):
				var x = randi() % size
				var y = randi() % size
				image.set_pixel(x, y, Color(0.9, 0.9, 0.9, 1.0))
		"ai_component":
			# Add some glowing effects
			for i in range(8):
				var x = randi() % size
				var y = randi() % size
				image.set_pixel(x, y, Color(0.7, 1.0, 1.0, 1.0))
		"unknown_artifact":
			# Add some mysterious sparkles
			for i in range(10):
				var x = randi() % size
				var y = randi() % size
				image.set_pixel(x, y, Color(1.0, 0.8, 1.0, 1.0))

	texture.set_image(image)
	sprite.texture = texture

	debris_object.add_child(sprite)

	# Create collision shape
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "DebrisCollision"
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(30, 30)
	collision_shape.shape = rect_shape
	debris_object.add_child(collision_shape)

	# Add metadata to the debris object
	var debris_id = "debris_%s_%d_%d" % [debris_type_data.type, current_debris_count, Time.get_ticks_msec()]
	debris_object.set_meta("debris_type", debris_type_data.type)
	debris_object.set_meta("debris_value", debris_type_data.value)
	debris_object.set_meta("debris_id", debris_id)

	# Add network sync methods to debris object
	debris_object.set_script(preload("res://scripts/DebrisObject.gd"))

	# Add slight random rotation and velocity
	debris_object.rotation = randf() * TAU
	debris_object.linear_velocity = Vector2(
		randf_range(-20, 20),
		randf_range(-20, 20)
	)
	debris_object.angular_velocity = randf_range(-0.5, 0.5)

	return debris_object

func _on_debris_collected(debris_type: String, value: int) -> void:
	"""Handle debris collection events from player"""
	_log_message("ZoneMain: Debris collected - Type: %s, Value: %d" % [debris_type, value])
	current_debris_count -= 1
	debris_collected.emit(debris_type, value)
	_update_debug_display()

	# Trigger AI milestone for first collection
	if ai_communicator and not ai_communicator.is_milestone_triggered("first_collection"):
		ai_communicator.trigger_milestone("first_collection")

	# Check for inventory full milestone
	if player_ship and ai_communicator:
		if player_ship.current_inventory.size() >= player_ship.inventory_capacity:
			if not ai_communicator.is_milestone_triggered("inventory_full"):
				ai_communicator.trigger_milestone("inventory_full")

	# Sync with backend if available
	if api_client:
		var item_data = {
			"item_id": "debris_%s_%d" % [debris_type, Time.get_unix_time_from_system()],
			"item_type": debris_type,
			"quantity": 1,
			"value": value,
			"timestamp": Time.get_unix_time_from_system()
		}
		api_client.add_inventory_item(item_data)

	# Spawn a new debris object to maintain count
	if current_debris_count < max_debris_count:
		get_tree().create_timer(randf_range(5.0, 15.0)).timeout.connect(_spawn_debris_object)

func _on_player_position_changed(new_position: Vector2) -> void:
	"""Handle player position updates for camera tracking"""
	if camera_2d:
		camera_2d.global_position = new_position

func _on_npc_hub_entered(hub_type: String) -> void:
	"""Handle player entering NPC hub"""
	_log_message("ZoneMain: Player entered %s hub" % hub_type)
	current_hub_type = hub_type
	show_ai_message("Press F to interact with %s" % hub_type.capitalize(), 2.0)

func _on_npc_hub_exited() -> void:
	"""Handle player exiting NPC hub"""
	_log_message("ZoneMain: Player exited NPC hub")
	current_hub_type = ""

func _update_debug_display() -> void:
	"""Update the debug information display"""
	if debug_label:
		var player_count = 1 + network_players.size() if (is_multiplayer_server or is_multiplayer_client) else 1
		debug_label.text = "Children of the Singularity - %s [DEBUG] | Players: %d | Debris: %d/%d" % [
			zone_name,
			player_count,
			current_debris_count,
			max_debris_count
		]

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

## Display AI message to player
func show_ai_message(message: String, duration: float = 3.0) -> void:
	"""Display an AI message to the player with enhanced styling"""
	if ai_message_overlay and ai_message_label:
		ai_message_label.text = message
		ai_message_overlay.visible = true

		# Add visual effects for milestone messages
		if "milestone" in message.to_lower() or "upgrade" in message.to_lower() or "first" in message.to_lower():
			ai_message_overlay.modulate = Color(1.0, 1.0, 0.8, 1.0)  # Slightly yellow tint for important messages
		else:
			ai_message_overlay.modulate = Color.WHITE

		# Hide after duration
		get_tree().create_timer(duration).timeout.connect(func(): ai_message_overlay.visible = false)

		_log_message("ZoneMain: AI message displayed: %s" % message)

## Open trading interface
func open_trading_interface(hub_type: String) -> void:
	"""Open the trading interface for a specific hub type"""
	if not trading_interface:
		_log_message("ZoneMain: Trading interface not available")
		return

	_log_message("ZoneMain: Opening %s interface" % hub_type)

	current_hub_type = hub_type
	trading_open = true

	# Update interface based on hub type
	if trading_title:
		match hub_type:
			"trading":
				trading_title.text = "TRADING TERMINAL"
				_setup_trading_interface()
			"upgrade":
				trading_title.text = "UPGRADE STATION"
				_setup_upgrade_interface()
			_:
				trading_title.text = "INTERACTION TERMINAL"
				_setup_trading_interface()

	# Show the interface
	trading_interface.visible = true

func _setup_trading_interface() -> void:
	"""Set up the trading interface for selling items"""
	if not trading_result or not player_ship:
		return

	var inventory_value = player_ship.get_inventory_value()
	var inventory_count = player_ship.current_inventory.size()

	if inventory_count > 0:
		trading_result.text = "You have %d items worth %d credits total.\nClick 'Sell All' to convert to credits." % [inventory_count, inventory_value]
	else:
		trading_result.text = "Your inventory is empty.\nCollect debris to trade for credits."

	# Show sell all button
	if sell_all_button:
		sell_all_button.visible = true
		sell_all_button.text = "SELL ALL DEBRIS"

func _setup_upgrade_interface() -> void:
	"""Set up the upgrade interface for purchasing upgrades"""
	if not trading_result or not player_ship or not upgrade_system:
		return

	# Clear existing upgrade buttons
	_clear_upgrade_buttons()

	var credits = player_ship.credits
	var upgrades = player_ship.upgrades

	var interface_text = "UPGRADE STATION\nCredits: %d\n\nClick upgrade buttons to purchase:\n" % credits

	# Create upgrade buttons
	_create_upgrade_buttons()

	trading_result.text = interface_text

	# Hide sell all button, show upgrade buttons
	if sell_all_button:
		sell_all_button.visible = false

	# Create upgrade buttons dynamically
	_create_upgrade_buttons()

func _on_sell_all_pressed() -> void:
	"""Handle sell all button press"""
	if not player_ship or not api_client:
		return

	_log_message("ZoneMain: Processing sell all transaction")

	# Calculate total value
	var total_value = player_ship.get_inventory_value()
	var item_count = player_ship.current_inventory.size()

	if item_count == 0:
		trading_result.text = "No items to sell!"
		return

	# Update UI to show processing
	trading_result.text = "Processing transaction..."
	sell_all_button.disabled = true

	# Store transaction data for completion
	var transaction_data = {
		"total_value": total_value,
		"item_count": item_count
	}

	# Send requests to backend
	api_client.clear_inventory()
	api_client.update_credits(total_value)

	# Clear local inventory
	player_ship.clear_inventory()
	player_ship.add_credits(total_value)

	# Update result text
	trading_result.text = "Sold %d items for %d credits!\nTotal credits: %d" % [item_count, total_value, player_ship.credits]

	# Show AI message
	show_ai_message("Transaction completed. %d credits deposited to your account." % total_value, 3.0)

	# Trigger AI milestone for first sale
	if ai_communicator and not ai_communicator.is_milestone_triggered("first_sale"):
		ai_communicator.trigger_milestone("first_sale")

	# Re-enable button
	sell_all_button.disabled = false

	_log_message("ZoneMain: Sold %d items for %d credits" % [item_count, total_value])

func _on_trading_close_pressed() -> void:
	"""Handle trading interface close button press"""
	_log_message("ZoneMain: Closing trading interface")
	trading_interface.visible = false
	trading_open = false
	current_hub_type = ""

## Get debris object by ID
func get_debris_by_id(debris_id: String) -> RigidBody2D:
	"""Get a specific debris object by its ID"""
	for child in debris_container.get_children():
		if child.has_meta("debris_id") and child.get_meta("debris_id") == debris_id:
			return child
	return null

## Remove debris object (called when collected)
func remove_debris(debris_object: RigidBody2D) -> void:
	"""Remove a debris object from the zone"""
	if debris_object and is_instance_valid(debris_object):
		var debris_type = debris_object.get_meta("debris_type", "unknown")
		var debris_value = debris_object.get_meta("debris_value", 0)

		_log_message("ZoneMain: Removing debris - Type: %s, Value: %d" % [debris_type, debris_value])

		# Create collection effect
		_create_collection_effect(debris_object.global_position)

		# Remove the debris object
		debris_object.queue_free()
		current_debris_count -= 1
		_update_debug_display()

func _create_collection_effect(position: Vector2) -> void:
	"""Create a visual effect when debris is collected"""
	var effect = Node2D.new()
	effect.name = "CollectionEffect"
	effect.global_position = position

	# Create expanding circle effect
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.spread = 45.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.color = Color.WHITE

	effect.add_child(particles)
	add_child(effect)

	# Remove effect after animation completes
	get_tree().create_timer(1.0).timeout.connect(func(): effect.queue_free())

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
func spawn_debris_at(position: Vector2, debris_type: String = "scrap_metal") -> void:
	"""Spawn debris at a specific position"""
	_log_message("ZoneMain: Spawning %s debris at %s" % [debris_type, position])

	# Find debris type data
	var debris_type_data = null
	for dtype in debris_types:
		if dtype.type == debris_type:
			debris_type_data = dtype
			break

	if not debris_type_data:
		debris_type_data = debris_types[0]  # Default to first type

	# Create debris object
	var debris_object = _create_debris_object(debris_type_data)
	debris_object.global_position = position
	debris_container.add_child(debris_object)

	current_debris_count += 1
	_update_debug_display()

## Clear all debris from the zone
func clear_all_debris() -> void:
	"""Clear all debris from the zone"""
	_log_message("ZoneMain: Clearing all debris from zone")

	for child in debris_container.get_children():
		child.queue_free()

	current_debris_count = 0
	_update_debug_display()

## Reset the zone to its initial state
func reset_zone() -> void:
	"""Reset the zone to its initial state"""
	_log_message("ZoneMain: Resetting zone to initial state")
	clear_all_debris()
	_spawn_initial_debris()
	zone_ready.emit()

## API Response Handlers
func _on_player_data_loaded(player_data: Dictionary) -> void:
	"""Handle player data loaded from backend"""
	_log_message("ZoneMain: Player data loaded from backend")

	if player_ship:
		# Update player ship with backend data
		if "credits" in player_data:
			player_ship.credits = player_data.credits
		if "upgrades" in player_data:
			player_ship.upgrades = player_data.upgrades
			# Apply upgrade effects
			for upgrade_type in player_data.upgrades:
				player_ship.apply_upgrade(upgrade_type, player_data.upgrades[upgrade_type])

func _on_credits_updated(credits: int) -> void:
	"""Handle credits updated from backend"""
	_log_message("ZoneMain: Credits updated from backend: %d" % credits)

	if player_ship:
		player_ship.credits = credits

func _on_inventory_updated(inventory_data: Array) -> void:
	"""Handle inventory updated from backend"""
	_log_message("ZoneMain: Inventory updated from backend")

	if player_ship:
		# Convert backend inventory format to local format
		var local_inventory = []
		for item in inventory_data:
			local_inventory.append({
				"type": item.get("item_type", "unknown"),
				"value": item.get("value", 0),
				"id": item.get("item_id", "unknown"),
				"timestamp": item.get("timestamp", Time.get_unix_time_from_system())
			})

		player_ship.current_inventory = local_inventory

func _on_api_error(error_message: String) -> void:
	"""Handle API errors"""
	_log_message("ZoneMain: API error: %s" % error_message)

	# Show error message to player
	show_ai_message("Network error: %s" % error_message, 5.0)

	# Re-enable trading button if it was disabled
	if sell_all_button:
		sell_all_button.disabled = false



		# Refresh upgrade interface
		_setup_upgrade_interface()

## Upgrade System Response Handlers
func _on_upgrade_purchased(upgrade_type: String, new_level: int, cost: int) -> void:
	"""Handle upgrade purchase completion"""
	_log_message("ZoneMain: Upgrade purchased - %s Level %d for %d credits" % [upgrade_type, new_level, cost])

func _on_upgrade_purchase_failed(upgrade_type: String, reason: String) -> void:
	"""Handle upgrade purchase failure"""
	_log_message("ZoneMain: Upgrade purchase failed - %s: %s" % [upgrade_type, reason])

func _on_upgrade_effects_applied(upgrade_type: String, level: int) -> void:
	"""Handle upgrade effects being applied"""
	_log_message("ZoneMain: Upgrade effects applied - %s Level %d" % [upgrade_type, level])

## AI Communication Response Handlers
func _on_ai_message_received(message_type: String, content: String) -> void:
	"""Handle AI message received"""
	_log_message("ZoneMain: AI message received - Type: %s, Content: %s" % [message_type, content])

	# Display AI message to player
	show_ai_message(content, 4.0)

func _on_milestone_reached(milestone_name: String) -> void:
	"""Handle milestone reached"""
	_log_message("ZoneMain: Milestone reached - %s" % milestone_name)

	# Add visual or audio feedback for milestone completion
	# TODO: Add special effects for milestone completion

func _on_ai_broadcast_ready(message_data: Dictionary) -> void:
	"""Handle AI broadcast ready"""
	_log_message("ZoneMain: AI broadcast ready - %s" % message_data)

	# Display the broadcast message
	var content = message_data.get("content", "System message")
	show_ai_message(content, 5.0)

func get_network_manager() -> NetworkManager:
	"""Get the network manager instance"""
	return network_manager

## Interactive Inventory Functions
func _on_inventory_item_clicked(item: Dictionary) -> void:
	"""Handle inventory item click"""
	_log_message("ZoneMain: Inventory item clicked - %s (Value: %d)" % [item.type, item.value])

	# Show detailed item information
	_show_item_details(item)

func _on_inventory_item_hovered(item: Dictionary) -> void:
	"""Handle inventory item hover"""
	_log_message("ZoneMain: Inventory item hovered - %s" % item.type)

	# Show tooltip with item details
	_show_item_tooltip(item)

func _on_inventory_item_unhovered(item: Dictionary) -> void:
	"""Handle inventory item unhover"""
	_log_message("ZoneMain: Inventory item unhovered - %s" % item.type)

	# Hide tooltip
	_hide_item_tooltip()

func _show_item_details(item: Dictionary) -> void:
	"""Show detailed item information in AI message overlay"""
	var item_name = _get_item_display_name(item.type)
	var item_description = _get_item_description(item.type)

	var details_text = "ITEM DETAILS\n\n"
	details_text += "Name: %s\n" % item_name
	details_text += "Type: %s\n" % item.type
	details_text += "Value: %d Credits\n" % item.value
	details_text += "Description: %s\n" % item_description

	if "timestamp" in item:
		var collection_time = Time.get_datetime_dict_from_unix_time(item.timestamp)
		details_text += "Collected: %02d:%02d:%02d" % [collection_time.hour, collection_time.minute, collection_time.second]

	show_ai_message(details_text, 5.0)

func _show_item_tooltip(item: Dictionary) -> void:
	"""Show item tooltip"""
	# For now, update the inventory status label as a simple tooltip
	if inventory_status:
		var tooltip_text = "%s - %d Credits\n%s" % [
			_get_item_display_name(item.type),
			item.value,
			_get_item_description(item.type)
		]
		inventory_status.text = tooltip_text

func _hide_item_tooltip() -> void:
	"""Hide item tooltip"""
	if inventory_status and player_ship:
		inventory_status.text = "%d/%d Items" % [player_ship.current_inventory.size(), player_ship.inventory_capacity]

func _get_item_description(item_type: String) -> String:
	"""Get a description for an item type"""
	match item_type:
		"scrap_metal":
			return "Common debris from damaged ships. Basic salvage material."
		"broken_satellite":
			return "Damaged communication equipment. Contains valuable components."
		"bio_waste":
			return "Organic waste materials. Processed for biological components."
		"ai_component":
			return "Advanced AI processing unit. Highly valuable salvage."
		"unknown_artifact":
			return "Mysterious object of unknown origin. Extremely valuable."
		_:
			return "Unknown debris type. Value uncertain."

## Upgrade Interface Functions
var upgrade_buttons: Array[Button] = []

func _create_upgrade_buttons() -> void:
	"""Create interactive upgrade buttons"""
	if not trading_interface or not upgrade_system:
		return

	var trading_content = trading_interface.get_node("TradingContent")
	if not trading_content:
		return

	var credits = player_ship.credits if player_ship else 0
	var upgrades = player_ship.upgrades if player_ship else {}

	# Create upgrade buttons for each upgrade type
	for upgrade_type in upgrade_system.get_all_upgrades():
		var upgrade_info = upgrade_system.get_upgrade_info(upgrade_type)
		var current_level = upgrades.get(upgrade_type, 0)
		var max_level = upgrade_info.max_level
		var cost = upgrade_system.calculate_upgrade_cost(upgrade_type, current_level)

		var button = Button.new()
		button.custom_minimum_size = Vector2(300, 80)
		button.text = _format_upgrade_button_text(upgrade_type, upgrade_info, current_level, max_level, cost)

		# Set button style based on availability
		if current_level >= max_level:
			button.disabled = true
			button.modulate = Color.GRAY
		elif credits < cost:
			button.disabled = true
			button.modulate = Color.RED
		else:
			button.modulate = Color.GREEN

		# Connect button signal
		button.pressed.connect(_on_upgrade_button_pressed.bind(upgrade_type))
		button.mouse_entered.connect(_on_upgrade_button_hovered.bind(upgrade_type))
		button.mouse_exited.connect(_on_upgrade_button_unhovered.bind(upgrade_type))

		trading_content.add_child(button)
		upgrade_buttons.append(button)

func _clear_upgrade_buttons() -> void:
	"""Clear all upgrade buttons"""
	for button in upgrade_buttons:
		if is_instance_valid(button):
			button.queue_free()
	upgrade_buttons.clear()

func _format_upgrade_button_text(upgrade_type: String, upgrade_info: Dictionary, current_level: int, max_level: int, cost: int) -> String:
	"""Format the text for an upgrade button"""
	var text = "%s (Level %d/%d)\n" % [upgrade_info.name, current_level, max_level]
	text += "%s\n" % upgrade_info.description

	if current_level >= max_level:
		text += "[MAX LEVEL]"
	else:
		text += "[UPGRADE - %d Credits]" % cost

	return text

func _on_upgrade_button_pressed(upgrade_type: String) -> void:
	"""Handle upgrade button press"""
	_log_message("ZoneMain: Upgrade button pressed - %s" % upgrade_type)

	if not player_ship or not upgrade_system:
		return

	var credits = player_ship.credits
	var current_level = player_ship.upgrades.get(upgrade_type, 0)
	var cost = upgrade_system.calculate_upgrade_cost(upgrade_type, current_level)

	if credits >= cost:
		# Purchase upgrade
		_purchase_upgrade(upgrade_type)
	else:
		# Show insufficient credits message
		show_ai_message("Insufficient Credits!\nYou need %d credits to purchase this upgrade.\nCurrent credits: %d" % [cost, credits], 3.0)

func _on_upgrade_button_hovered(upgrade_type: String) -> void:
	"""Handle upgrade button hover"""
	if not upgrade_system:
		return

	var upgrade_info = upgrade_system.get_upgrade_info(upgrade_type)
	var current_level = player_ship.upgrades.get(upgrade_type, 0) if player_ship else 0
	var cost = upgrade_system.calculate_upgrade_cost(upgrade_type, current_level)

	var tooltip_text = "UPGRADE DETAILS\n\n"
	tooltip_text += "Name: %s\n" % upgrade_info.name
	tooltip_text += "Current Level: %d/%d\n" % [current_level, upgrade_info.max_level]
	tooltip_text += "Cost: %d Credits\n" % cost
	tooltip_text += "Effect: %s\n" % upgrade_info.description

	# Show detailed effects
	if "effects" in upgrade_info:
		tooltip_text += "\nEffects:\n"
		for effect_name in upgrade_info.effects:
			var effect_value = upgrade_info.effects[effect_name]
			tooltip_text += "• %s: +%s\n" % [effect_name, effect_value]

	show_ai_message(tooltip_text, 4.0)

func _on_upgrade_button_unhovered(upgrade_type: String) -> void:
	"""Handle upgrade button unhover"""
	# Hide tooltip by clearing AI message
	if ai_message_overlay:
		ai_message_overlay.visible = false

func _purchase_upgrade(upgrade_type: String) -> void:
	"""Purchase an upgrade"""
	_log_message("ZoneMain: Attempting to purchase upgrade - %s" % upgrade_type)

	if not player_ship or not upgrade_system:
		return

	var current_level = player_ship.upgrades.get(upgrade_type, 0)
	var cost = upgrade_system.calculate_upgrade_cost(upgrade_type, current_level)

	if player_ship.credits >= cost:
		# Deduct credits
		player_ship.credits -= cost

		# Purchase upgrade through upgrade system
		if upgrade_system.purchase_upgrade(upgrade_type, player_ship):
			_log_message("ZoneMain: Successfully purchased upgrade - %s" % upgrade_type)

			# Trigger AI milestone for first upgrade
			if ai_communicator and not ai_communicator.is_milestone_triggered("first_upgrade"):
				ai_communicator.trigger_milestone("first_upgrade")

			# Update UI
			_refresh_upgrade_interface()
			_update_debug_display()

			# Show success message
			var upgrade_info = upgrade_system.get_upgrade_info(upgrade_type)
			show_ai_message("Upgrade Purchased!\n%s upgraded to level %d\nRemaining credits: %d" % [upgrade_info.name, current_level + 1, player_ship.credits], 3.0)

			# Sync with backend
			if api_client:
				api_client.sync_player_data(player_ship.player_id, player_ship.credits, player_ship.current_inventory)
		else:
			_log_message("ZoneMain: Failed to purchase upgrade - %s" % upgrade_type)
			show_ai_message("Upgrade Failed!\nUnable to process upgrade request.", 3.0)
	else:
		show_ai_message("Insufficient Credits!\nYou need %d credits.\nCurrent credits: %d" % [cost, player_ship.credits], 3.0)

func _refresh_upgrade_interface() -> void:
	"""Refresh the upgrade interface"""
	if current_hub_type == "upgrade":
		_setup_upgrade_interface()

## Network Management Functions
func _initialize_networking() -> void:
	"""Initialize networking system"""
	_log_message("ZoneMain: Initializing networking system")

	# For MVP, try to start as server first
	if network_manager.start_server():
		is_multiplayer_server = true
		_log_message("ZoneMain: Started as multiplayer server")

		# Sync initial zone state
		_sync_zone_state_to_network()
	else:
		_log_message("ZoneMain: Failed to start as server, will connect as client if needed")

func _sync_zone_state_to_network() -> void:
	"""Sync current zone state to network"""
	if not is_multiplayer_server:
		return

	var zone_data = {
		"zone_id": zone_id,
		"zone_name": zone_name,
		"debris_count": current_debris_count,
		"debris": _get_debris_state(),
		"timestamp": Time.get_ticks_msec()
	}

	network_manager.sync_zone_state(zone_data)

func _get_debris_state() -> Dictionary:
	"""Get current debris state for network sync"""
	var debris_state = {}

	for debris in debris_container.get_children():
		if debris.has_method("get_debris_id"):
			var debris_id = debris.get_debris_id()
			debris_state[debris_id] = {
				"type": debris.get_debris_type(),
				"position": debris.global_position,
				"value": debris.get_debris_value()
			}

	return debris_state

func _update_network_player_position() -> void:
	"""Update local player position to network"""
	if not network_manager or not network_manager.is_connected:
		return

	var player_data = {
		"position": player_ship.global_position,
		"inventory": player_ship.current_inventory,
		"credits": player_ship.credits,
		"timestamp": Time.get_ticks_msec()
	}

	network_manager.send_player_update(player_data)

func connect_to_multiplayer_server(server_address: String) -> bool:
	"""Connect to a multiplayer server"""
	_log_message("ZoneMain: Attempting to connect to server at %s" % server_address)

	if network_manager.connect_to_server(server_address):
		is_multiplayer_client = true
		_log_message("ZoneMain: Connection attempt initiated")
		return true
	else:
		_log_message("ZoneMain: Failed to initiate connection")
		return false

## Network Event Handlers
func _on_connected_to_server() -> void:
	"""Handle successful connection to server"""
	_log_message("ZoneMain: Successfully connected to multiplayer server")
	is_multiplayer_client = true

	# Trigger AI milestone for zone access
	if ai_communicator and not ai_communicator.is_milestone_triggered("zone_access"):
		ai_communicator.trigger_milestone("zone_access")

	# Request to join the current zone
	network_manager.request_zone_join(zone_id)

	# Start sending position updates
	_update_network_player_position()

func _on_disconnected_from_server() -> void:
	"""Handle disconnection from server"""
	_log_message("ZoneMain: Disconnected from multiplayer server")
	is_multiplayer_client = false

	# Clean up network players
	_cleanup_network_players()

func _on_network_player_joined(player_id: int, player_data: Dictionary) -> void:
	"""Handle new player joining the network"""
	_log_message("ZoneMain: Network player %d joined" % player_id)

	# Create visual representation for network player
	_create_network_player_visual(player_id, player_data)

	# Update player count in UI
	_update_player_count_display()

func _on_network_player_left(player_id: int) -> void:
	"""Handle player leaving the network"""
	_log_message("ZoneMain: Network player %d left" % player_id)

	# Remove visual representation
	_remove_network_player_visual(player_id)

	# Update player count in UI
	_update_player_count_display()

func _on_network_player_position_updated(player_id: int, position: Vector2) -> void:
	"""Handle network player position update"""
	if player_id in network_players:
		var player_visual = network_players[player_id]
		if player_visual:
			player_visual.global_position = position

func _on_network_debris_collected(player_id: int, debris_id: String, debris_type: String) -> void:
	"""Handle debris collection by network player"""
	_log_message("ZoneMain: Network player %d collected debris %s (%s)" % [player_id, debris_id, debris_type])

	# Remove debris from local zone
	_remove_debris_by_id(debris_id)

	# Update debris count
	current_debris_count = max(0, current_debris_count - 1)
	_update_debug_display()

func _on_network_server_state_updated(state_data: Dictionary) -> void:
	"""Handle server state update"""
	_log_message("ZoneMain: Received server state update")

	# Update local zone state based on server data
	var debris_data = state_data.get("debris", {})
	_sync_debris_from_server(debris_data)

## Network Helper Functions
func _create_network_player_visual(player_id: int, player_data: Dictionary) -> void:
	"""Create visual representation for network player"""
	var player_visual = CharacterBody2D.new()
	player_visual.name = "NetworkPlayer_%d" % player_id

	# Add sprite for network player
	var sprite = Sprite2D.new()
	sprite.modulate = Color.BLUE  # Different color for network players
	player_visual.add_child(sprite)

	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(64, 32)
	collision.shape = shape
	player_visual.add_child(collision)

	# Position the network player
	var position = player_data.get("position", Vector2.ZERO)
	player_visual.global_position = position

	# Add to scene and track
	add_child(player_visual)
	network_players[player_id] = player_visual

	_log_message("ZoneMain: Created visual for network player %d at %s" % [player_id, position])

func _remove_network_player_visual(player_id: int) -> void:
	"""Remove visual representation for network player"""
	if player_id in network_players:
		var player_visual = network_players[player_id]
		if player_visual:
			player_visual.queue_free()
		network_players.erase(player_id)
		_log_message("ZoneMain: Removed visual for network player %d" % player_id)

func _cleanup_network_players() -> void:
	"""Clean up all network player visuals"""
	for player_id in network_players.keys():
		_remove_network_player_visual(player_id)
	network_players.clear()

func _remove_debris_by_id(debris_id: String) -> void:
	"""Remove debris by ID (for network sync)"""
	for debris in debris_container.get_children():
		if debris.has_method("get_debris_id") and debris.get_debris_id() == debris_id:
			debris.queue_free()
			break

func _sync_debris_from_server(debris_data: Dictionary) -> void:
	"""Sync debris state from server"""
	# This is a simplified sync - in a full implementation, you'd want
	# more sophisticated state reconciliation
	_log_message("ZoneMain: Syncing debris state from server - %d items" % debris_data.size())

func _update_player_count_display() -> void:
	"""Update player count display in UI"""
	var total_players = 1 + network_players.size()  # Local player + network players
	debug_label.text = "Children of the Singularity - %s [DEBUG] | Players: %d | Debris: %d/%d" % [
		zone_name,
		total_players,
		current_debris_count,
		max_debris_count
	]

func _physics_process(delta: float) -> void:
	"""Physics process - handle network updates"""
	# Handle zoom input controls
	_handle_zoom_input(delta)

	# Send position updates to network periodically (throttled)
	if is_multiplayer_client or is_multiplayer_server:
		network_update_timer += delta
		if network_update_timer >= network_update_interval:
			network_update_timer = 0.0
			_update_network_player_position()

	# Update UI timer
	ui_update_timer += delta
	if ui_update_timer >= ui_update_interval:
		ui_update_timer = 0.0
		_update_ui_elements()

		# Update network player count display
		if is_multiplayer_server or is_multiplayer_client:
			_update_player_count_display()

func _handle_zoom_input(delta: float) -> void:
	"""Handle zoom input controls"""
	var zoom_input = 0.0

	if Input.is_action_pressed("zoom_in"):
		zoom_input = -1.0
	elif Input.is_action_pressed("zoom_out"):
		zoom_input = 1.0

	if zoom_input != 0.0:
		set_zoom(current_zoom + zoom_input * zoom_speed * delta)
		_log_message("ZoneMain: Camera zoom adjusted to %.2f" % current_zoom)

func set_zoom(new_zoom: float) -> void:
	"""Set the camera zoom level"""
	current_zoom = clamp(new_zoom, min_zoom, max_zoom)

	if camera_2d:
		camera_2d.zoom = Vector2(current_zoom, current_zoom)

func _initialize_camera_zoom() -> void:
	"""Initialize camera zoom settings"""
	current_zoom = default_zoom
	if camera_2d:
		camera_2d.zoom = Vector2(current_zoom, current_zoom)
		_log_message("ZoneMain: Camera zoom initialized to %.2f" % current_zoom)

func _update_ui_elements() -> void:
	"""Update all UI elements with current game state"""
	if not player_ship:
		return

	# Update credits display
	if credits_label:
		credits_label.text = "Credits: %d" % player_ship.credits

	# Update inventory status
	if inventory_status:
		var current_size = player_ship.current_inventory.size()
		var max_size = player_ship.inventory_capacity
		inventory_status.text = "%d/%d Items" % [current_size, max_size]

		# Color code based on fullness
		if current_size >= max_size:
			inventory_status.modulate = Color.RED
		elif current_size >= max_size * 0.8:
			inventory_status.modulate = Color.YELLOW
		else:
			inventory_status.modulate = Color.WHITE

	# Update debris count
	if debris_count_label:
		debris_count_label.text = "Nearby Debris: %d" % current_debris_count

	# Update collection range (with upgrades)
	if collection_range_label:
		var range_text = "Collection Range: %.0f" % player_ship.collection_range
		if player_ship.upgrades.get("collection_efficiency", 0) > 0:
			range_text += " (+%d)" % (player_ship.upgrades.get("collection_efficiency", 0) * 10)
		collection_range_label.text = range_text

	# Update inventory display only if it changed
	var current_inventory_size = player_ship.current_inventory.size()
	var current_inventory_hash = str(player_ship.current_inventory.hash())

	if current_inventory_size != last_inventory_size or current_inventory_hash != last_inventory_hash:
		_update_inventory_display(player_ship.current_inventory)
		last_inventory_size = current_inventory_size
		last_inventory_hash = current_inventory_hash

	# Update upgrade status display
	_update_upgrade_status_display()

	# Update debug display
	_update_debug_display()

func _update_upgrade_status_display() -> void:
	"""Update the upgrade status display"""
	if not upgrade_status_text or not player_ship:
		return

	var status_text = ""
	var upgrade_count = 0

	if player_ship.upgrades.size() > 0:
		for upgrade_type in player_ship.upgrades:
			var level = player_ship.upgrades[upgrade_type]
			if level > 0:
				var upgrade_info = upgrade_system.get_upgrade_info(upgrade_type) if upgrade_system else {}
				var upgrade_name = upgrade_info.get("name", upgrade_type)
				status_text += "%s: L%d\n" % [upgrade_name, level]
				upgrade_count += 1

	if upgrade_count == 0:
		upgrade_status_text.text = "No upgrades purchased"
		upgrade_status_text.modulate = Color.GRAY
	else:
		upgrade_status_text.text = status_text
		upgrade_status_text.modulate = Color.WHITE

func _setup_zone_background() -> void:
	"""Set up the zone background for better visual appeal"""
	_log_message("ZoneMain: Setting up zone background")

	# Create a space-like background
	var background = ColorRect.new()
	background.name = "SpaceBackground"
	background.color = Color(0.05, 0.05, 0.15, 1.0)  # Dark space blue
	background.size = Vector2(4000, 4000)
	background.position = Vector2(-2000, -2000)
	background.z_index = -100

	# Add some stars
	var stars_container = Node2D.new()
	stars_container.name = "StarsContainer"
	stars_container.z_index = -90

	for i in range(100):
		var star = ColorRect.new()
		star.size = Vector2(2, 2)
		star.color = Color(1.0, 1.0, 1.0, randf_range(0.3, 1.0))
		star.position = Vector2(
			randf_range(-2000, 2000),
			randf_range(-2000, 2000)
		)
		stars_container.add_child(star)

	add_child(background)
	add_child(stars_container)

	_log_message("ZoneMain: Zone background setup complete")
