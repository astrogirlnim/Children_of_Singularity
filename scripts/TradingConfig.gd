extends Node

# TradingConfig autoload singleton for Children of the Singularity
# Default configuration (should be overridden by local config file)
var config = {
	"api_base_url": "https://your-api-gateway-id.execute-api.your-region.amazonaws.com/prod",
	"listings_endpoint": "/listings",
	"timeout_seconds": 30,
	"enable_debug_logs": true
}

var config_file_path = "user://trading_config.json"

func _ready():
	print("[TradingConfig] Loading trading marketplace configuration")
	load_config()

func load_config():
	"""Load configuration with environment variable precedence (like LobbyController)"""
	print("[TradingConfig] Loading trading API configuration with environment precedence")

	# Step 1: Try environment variables first (production)
	_load_from_environment_variables()

	# Step 2: Try .env files (development)
	if config.api_base_url.contains("your-api-gateway-id"):
		_load_from_env_files()

	# Step 3: Try JSON config files (legacy fallback)
	if config.api_base_url.contains("your-api-gateway-id"):
		_load_from_json_config()

	# Step 4: Use infrastructure_setup.env if available
	if config.api_base_url.contains("your-api-gateway-id"):
		_load_from_infrastructure_file()

	print("[TradingConfig] Final API configuration:")
	print("[TradingConfig]   API Base URL: %s" % config.api_base_url)
	print("[TradingConfig]   Listings Endpoint: %s" % config.listings_endpoint)

func _load_from_environment_variables() -> void:
	"""Load configuration from OS environment variables (production)"""
	print("[TradingConfig] Checking OS environment variables...")

	var env_api_url = OS.get_environment("TRADING_API_URL")
	if not env_api_url.is_empty():
		config.api_base_url = env_api_url
		print("[TradingConfig] ✅ Found TRADING_API_URL in environment: %s" % env_api_url)

	var env_timeout = OS.get_environment("TRADING_TIMEOUT")
	if not env_timeout.is_empty():
		config.timeout_seconds = int(env_timeout)

	var env_debug = OS.get_environment("TRADING_DEBUG_LOGS")
	if not env_debug.is_empty():
		config.enable_debug_logs = env_debug.to_lower() in ["true", "1", "yes"]

func _load_from_env_files() -> void:
	"""Load configuration from .env files (development)"""
	print("[TradingConfig] Checking for .env files...")

	var env_paths = [
		"res://infrastructure_setup.env",  # Project infrastructure config
		"res://lobby.env",                 # Lobby config file
		"user://trading.env",              # User-specific trading config
		"res://.env"                       # Project root .env
	]

	for env_path in env_paths:
		if FileAccess.file_exists(env_path):
			print("[TradingConfig] Found .env file at: %s" % env_path)
			if _parse_env_file(env_path):
				print("[TradingConfig] ✅ Successfully loaded configuration from .env file")
				return

	print("[TradingConfig] No valid .env file found")

func _parse_env_file(env_path: String) -> bool:
	"""Parse environment file for trading configuration"""
	var file = FileAccess.open(env_path, FileAccess.READ)
	if not file:
		return false

	while not file.eof_reached():
		var line = file.get_line().strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		# Parse KEY=VALUE format
		if "=" in line:
			var parts = line.split("=", false, 1)
			if parts.size() == 2:
				var key = parts[0].strip_edges()
				var value = parts[1].strip_edges()

				# Remove quotes if present
				if (value.begins_with('"') and value.ends_with('"')) or (value.begins_with("'") and value.ends_with("'")):
					value = value.substr(1, value.length() - 2)

				# Map environment variables to configuration
				match key:
					"API_GATEWAY_ENDPOINT", "TRADING_API_URL":
						config.api_base_url = value
						print("[TradingConfig] Found trading API URL in .env: %s" % value)
					"TRADING_TIMEOUT":
						config.timeout_seconds = int(value)
					"TRADING_DEBUG_LOGS":
						config.enable_debug_logs = value.to_lower() in ["true", "1", "yes"]

	file.close()
	return not config.api_base_url.contains("your-api-gateway-id")

func _load_from_json_config() -> void:
	"""Load configuration from JSON files (legacy fallback)"""
	print("[TradingConfig] Checking JSON configuration files...")

	if FileAccess.file_exists(config_file_path):
		var file = FileAccess.open(config_file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_text)
			if parse_result == OK:
				var loaded_config = json.data
				for key in loaded_config:
					config[key] = loaded_config[key]
				print("[TradingConfig] ✅ Loaded configuration from JSON: %s" % config_file_path)

func _load_from_infrastructure_file() -> void:
	"""Load from infrastructure_setup.env as last resort"""
	print("[TradingConfig] Checking infrastructure_setup.env...")

	var infra_path = "res://infrastructure_setup.env"
	if FileAccess.file_exists(infra_path):
		_parse_env_file(infra_path)

func create_default_config_file():
	"""Create a default configuration file for the user to modify"""

	var default_config = {
		"_note": "Edit this file to configure your trading marketplace API endpoint",
		"_instructions": "Copy values from infrastructure_setup.env after AWS deployment",
		"api_base_url": "https://your-api-gateway-id.execute-api.your-region.amazonaws.com/prod",
		"listings_endpoint": "/listings",
		"timeout_seconds": 30,
		"enable_debug_logs": true
	}

	var file = FileAccess.open(config_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(default_config, "\t"))
		file.close()
		print("[TradingConfig] Created default config file at %s" % config_file_path)

func get_api_base_url() -> String:
	return config.get("api_base_url", "")

func get_listings_endpoint() -> String:
	return config.get("listings_endpoint", "/listings")

func get_timeout_seconds() -> int:
	return config.get("timeout_seconds", 30)

func is_debug_enabled() -> bool:
	return config.get("enable_debug_logs", true)

func get_full_listings_url() -> String:
	return get_api_base_url() + get_listings_endpoint()
