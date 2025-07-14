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
@onready var hud: Control = $UILayer/HUD
@onready var debug_label: Label = $UILayer/HUD/DebugLabel
@onready var log_label: Label = $UILayer/HUD/LogLabel
@onready var api_client: APIClient = $APIClient
@onready var upgrade_system: UpgradeSystem = $UpgradeSystem
@onready var ai_communicator: AICommunicator = $AICommunicator

# UI Components
@onready var inventory_panel: Panel = $UILayer/HUD/InventoryPanel
@onready var inventory_grid: GridContainer = $UILayer/HUD/InventoryPanel/InventoryGrid
@onready var inventory_status: Label = $UILayer/HUD/InventoryPanel/InventoryStatus
@onready var credits_label: Label = $UILayer/HUD/StatsPanel/CreditsLabel
@onready var debris_count_label: Label = $UILayer/HUD/StatsPanel/DebrisCountLabel
@onready var collection_range_label: Label = $UILayer/HUD/StatsPanel/CollectionRangeLabel
@onready var ai_message_overlay: Panel = $UILayer/HUD/AIMessageOverlay
@onready var ai_message_label: Label = $UILayer/HUD/AIMessageOverlay/AIMessageLabel

# Trading Interface Components
@onready var trading_interface: Panel = $UILayer/HUD/TradingInterface
@onready var trading_title: Label = $UILayer/HUD/TradingInterface/TradingTitle
@onready var sell_all_button: Button = $UILayer/HUD/TradingInterface/TradingContent/SellAllButton
@onready var trading_result: Label = $UILayer/HUD/TradingInterface/TradingContent/TradingResult
@onready var trading_close_button: Button = $UILayer/HUD/TradingInterface/TradingCloseButton

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
var ui_update_interval: float = 0.1

# Trading system
var current_hub_type: String = ""
var trading_open: bool = false

func _ready() -> void:
	_log_message("ZoneMain: Initializing zone controller")
	_initialize_zone()
	_spawn_initial_debris()
	_setup_ui_connections()
	_setup_npc_hubs()
	_update_debug_display()

	# Connect player signals
	if player_ship:
		player_ship.debris_collected.connect(_on_debris_collected)
		player_ship.position_changed.connect(_on_player_position_changed)
		player_ship.npc_hub_entered.connect(_on_npc_hub_entered)
		player_ship.npc_hub_exited.connect(_on_npc_hub_exited)

	# Connect API client signals
	if api_client:
		api_client.player_data_loaded.connect(_on_player_data_loaded)
		api_client.credits_updated.connect(_on_credits_updated)
		api_client.inventory_updated.connect(_on_inventory_updated)
		api_client.api_error.connect(_on_api_error)

		# Check backend health on startup
		api_client.check_health()

	# Connect upgrade system signals
	if upgrade_system:
		upgrade_system.upgrade_purchased.connect(_on_upgrade_purchased)
		upgrade_system.upgrade_purchase_failed.connect(_on_upgrade_purchase_failed)
		upgrade_system.upgrade_effects_applied.connect(_on_upgrade_effects_applied)

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
		# Create a simple colored rectangle texture
		var texture = ImageTexture.new()
		var image = Image.create(150, 150, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.8, 0.6, 0.2, 1.0))
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
	"""Add an item to the inventory display"""
	if not inventory_grid:
		return

	# Create item container
	var item_container = Panel.new()
	item_container.custom_minimum_size = Vector2(80, 80)

	# Get item color based on type
	var item_color = _get_item_color(item.type)
	item_container.color = item_color

	# Create item label
	var item_label = Label.new()
	item_label.text = "%s\nVal: %d" % [_get_item_display_name(item.type), item.value]
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_label.anchor_right = 1.0
	item_label.anchor_bottom = 1.0

	item_container.add_child(item_label)
	inventory_grid.add_child(item_container)
	inventory_items.append(item_container)

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

	# Create a simple colored rectangle texture
	var texture = ImageTexture.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(debris_type_data.color)
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
	debris_object.set_meta("debris_type", debris_type_data.type)
	debris_object.set_meta("debris_value", debris_type_data.value)
	debris_object.set_meta("debris_id", "debris_%s_%d" % [debris_type_data.type, current_debris_count])

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
	if player_ship and player_ship.current_inventory.size() >= player_ship.inventory_capacity:
		if ai_communicator and not ai_communicator.is_milestone_triggered("inventory_full"):
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

## Display AI message to player
func show_ai_message(message: String, duration: float = 3.0) -> void:
	"""Display an AI message to the player"""
	if ai_message_overlay and ai_message_label:
		ai_message_label.text = message
		ai_message_overlay.visible = true

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

	var credits = player_ship.credits
	var upgrades = player_ship.upgrades

	var interface_text = "UPGRADE STATION\nCredits: %d\n\nAvailable Upgrades:\n" % credits

	# Show available upgrades
	for upgrade_type in upgrade_system.get_all_upgrades():
		var upgrade_info = upgrade_system.get_upgrade_info(upgrade_type)
		var current_level = upgrades.get(upgrade_type, 0)
		var max_level = upgrade_info.max_level
		var cost = upgrade_system.calculate_upgrade_cost(upgrade_type, current_level)

		interface_text += "\n%s (Level %d/%d)" % [upgrade_info.name, current_level, max_level]
		interface_text += "\n%s" % upgrade_info.description

		if current_level >= max_level:
			interface_text += "\n[MAX LEVEL]"
		elif credits >= cost:
			interface_text += "\n[UPGRADE - %d Credits]" % cost
		else:
			interface_text += "\n[INSUFFICIENT CREDITS - %d Required]" % cost

		interface_text += "\n"

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

func _create_upgrade_buttons() -> void:
	"""Create upgrade buttons dynamically"""
	if not trading_interface or not upgrade_system:
		return

	# Remove existing upgrade buttons
	_clear_upgrade_buttons()

	# Create upgrade buttons for each upgrade type
	var button_container = VBoxContainer.new()
	button_container.name = "UpgradeButtons"

	var credits = player_ship.credits if player_ship else 0
	var upgrades = player_ship.upgrades if player_ship else {}

	for upgrade_type in upgrade_system.get_all_upgrades():
		var upgrade_info = upgrade_system.get_upgrade_info(upgrade_type)
		var current_level = upgrades.get(upgrade_type, 0)
		var max_level = upgrade_info.max_level
		var cost = upgrade_system.calculate_upgrade_cost(upgrade_type, current_level)

		var button = Button.new()
		button.name = "Upgrade_%s" % upgrade_type
		button.text = "%s - %d Credits" % [upgrade_info.name, cost]
		button.custom_minimum_size = Vector2(200, 30)

		# Disable button if can't afford or at max level
		if current_level >= max_level:
			button.disabled = true
			button.text = "%s - MAX LEVEL" % upgrade_info.name
		elif credits < cost:
			button.disabled = true

		# Connect button signal
		button.pressed.connect(_on_upgrade_button_pressed.bind(upgrade_type))

		button_container.add_child(button)

	# Add button container to trading interface
	trading_interface.add_child(button_container)

func _clear_upgrade_buttons() -> void:
	"""Clear existing upgrade buttons"""
	var button_container = trading_interface.get_node_or_null("UpgradeButtons")
	if button_container:
		button_container.queue_free()

func _on_upgrade_button_pressed(upgrade_type: String) -> void:
	"""Handle upgrade button press"""
	if not player_ship or not upgrade_system:
		return

	_log_message("ZoneMain: Attempting to purchase upgrade: %s" % upgrade_type)

	var current_level = player_ship.upgrades.get(upgrade_type, 0)
	var available_credits = player_ship.credits

	var result = upgrade_system.purchase_upgrade(upgrade_type, current_level, available_credits)

	if result.success:
		# Update player ship
		player_ship.spend_credits(result.cost)
		player_ship.apply_upgrade(upgrade_type, result.new_level)

		# Show success message
		show_ai_message("Upgrade purchased: %s Level %d" % [upgrade_type, result.new_level], 3.0)

		# Trigger AI milestone for first upgrade
		if ai_communicator and not ai_communicator.is_milestone_triggered("first_upgrade"):
			ai_communicator.trigger_milestone("first_upgrade")

		# Check for zone access milestone
		if upgrade_type == "zone_access" and result.new_level > 1:
			if ai_communicator and not ai_communicator.is_milestone_triggered("zone_access"):
				ai_communicator.trigger_milestone("zone_access")

		# Refresh upgrade interface
		_setup_upgrade_interface()
	else:
		# Show error message
		show_ai_message("Purchase failed: %s" % result.reason, 3.0)

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
