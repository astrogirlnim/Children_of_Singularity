extends Node

# Default configuration values (fallback only - production values injected at build time)
var default_config = {
	"api_base_url": "",  # Injected at build time from trading.env
	"listings_endpoint": "/listings",
	"timeout_seconds": 30,
	"enable_debug_logs": true,
	# PHASE 1.1: Timeout configuration
	"request_timeout": 15.0,  # 15-second timeout for HTTP requests
	"max_retry_attempts": 3,  # Maximum retry attempts for failed requests
	"retry_delay": 2.0,  # Seconds to wait between retries
	"connection_timeout": 10.0  # Connection timeout
}

# Current configuration
var config: Dictionary = {}
var config_file_path: String = "user://trading_config.json"

func _ready():
	print("[TradingConfig] Initializing trading configuration")
	load_config()

## Load configuration from file or create default
func load_config() -> void:
	print("[TradingConfig] Loading configuration from %s" % config_file_path)

	# Start with default configuration (includes build-time injected values)
	config = default_config.duplicate()

	# Step 1: Try to load from .env file first (like LobbyController does)
	var env_loaded = _load_from_env_file()

	# Step 2: Load JSON config for user preferences, but protect critical settings
	if not env_loaded and FileAccess.file_exists(config_file_path):
		var file = FileAccess.open(config_file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_text)

			if parse_result == OK:
				var json_config = json.data
				# Merge user config, but protect critical production settings
				for key in json_config:
					# Never let user config override empty/critical production values
					if key == "api_base_url":
						# Only use user config if both default and user config are non-empty
						if json_config[key] != "" and config[key] != "":
							config[key] = json_config[key]
						elif config[key] != "":
							# Keep injected production value, ignore empty user config
							print("[TradingConfig] Protecting production API endpoint from empty user config")
						else:
							# Both empty, use user config (development scenario)
							config[key] = json_config[key]
					else:
						# Non-critical settings can be overridden by user config
						config[key] = json_config[key]
				print("[TradingConfig] Configuration loaded from JSON file (with production protection)")
				_merge_default_values()  # Ensure new fields are added
			else:
				print("[TradingConfig] Failed to parse config file, using defaults")
				if config.is_empty():
					config = default_config.duplicate()
				save_config()
		else:
			print("[TradingConfig] Failed to open config file, using defaults")
			if config.is_empty():
				config = default_config.duplicate()
			save_config()
	else:
		print("[TradingConfig] No JSON config file found")
		if config.is_empty():
			print("[TradingConfig] No configuration loaded, creating default configuration")
			config = default_config.duplicate()
			save_config()

	# Always validate and fill in missing defaults
	_validate_config()
	_merge_default_values()

## Load configuration from .env file (matches LobbyController approach)
func _load_from_env_file() -> bool:
	print("[TradingConfig] Checking for .env configuration...")

	# Try different .env file locations (same as LobbyController)
	var env_paths = [
		"user://trading.env",  # User-specific trading config
		"user://.env",       # User-specific general config
		"res://trading.env",  # Project root trading.env
		"res://infrastructure_setup.env",  # Project infrastructure config
		"res://.env"         # Project root .env
	]

	for env_path in env_paths:
		if FileAccess.file_exists(env_path):
			print("[TradingConfig] Found .env file at: %s" % env_path)
			if _parse_env_file(env_path):
				print("[TradingConfig] ✅ Successfully loaded configuration from .env file")
				return true
			else:
				print("[TradingConfig] ⚠️ Failed to parse .env file, trying next location")

	print("[TradingConfig] No valid .env file found")
	return false

## Parse environment file and extract trading configuration
func _parse_env_file(env_path: String) -> bool:
	var file = FileAccess.open(env_path, FileAccess.READ)
	if not file:
		return false

	config = {}  # Start with empty config to be filled from .env
	var found_api_url = false

	var line_number = 0
	while not file.eof_reached():
		line_number += 1
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

				# Map environment variables to trading configuration
				match key:
					"API_GATEWAY_ENDPOINT":
						config["api_base_url"] = value
						found_api_url = true
						print("[TradingConfig] Found API_GATEWAY_ENDPOINT in .env: %s" % value)
					"TRADING_TIMEOUT":
						config["request_timeout"] = float(value)
					"TRADING_DEBUG":
						config["enable_debug_logs"] = value.to_lower() in ["true", "1", "yes"]
					"TRADING_MAX_RETRIES":
						config["max_retry_attempts"] = int(value)

	file.close()

	# Fill in any missing values with defaults
	for key in default_config:
		if not config.has(key):
			config[key] = default_config[key]

	return found_api_url  # Return true if we found at least the API URL

## Merge new default values into existing config (for updates)
func _merge_default_values() -> void:
	var config_updated = false

	for key in default_config:
		if not config.has(key):
			config[key] = default_config[key]
			config_updated = true
			print("[TradingConfig] Added missing config key: %s = %s" % [key, default_config[key]])

	if config_updated:
		save_config()
		print("[TradingConfig] Configuration updated with new defaults")

## Validate configuration values
func _validate_config() -> void:
	# Validate timeout values
	if config.get("request_timeout", 0) <= 0:
		config["request_timeout"] = default_config["request_timeout"]
		print("[TradingConfig] Fixed invalid request_timeout")

	if config.get("connection_timeout", 0) <= 0:
		config["connection_timeout"] = default_config["connection_timeout"]
		print("[TradingConfig] Fixed invalid connection_timeout")

	if config.get("max_retry_attempts", 0) < 0:
		config["max_retry_attempts"] = default_config["max_retry_attempts"]
		print("[TradingConfig] Fixed invalid max_retry_attempts")

	if config.get("retry_delay", 0) < 0:
		config["retry_delay"] = default_config["retry_delay"]
		print("[TradingConfig] Fixed invalid retry_delay")

## Save configuration to file
func save_config() -> void:
	var file = FileAccess.open(config_file_path, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(config, "\t")
		file.store_string(json_text)
		file.close()
		print("[TradingConfig] Configuration saved to %s" % config_file_path)
	else:
		print("[TradingConfig] ERROR: Failed to save configuration file")

## Get API base URL
func get_api_base_url() -> String:
	return config.get("api_base_url", default_config["api_base_url"])

## Get listings endpoint
func get_listings_endpoint() -> String:
	return config.get("listings_endpoint", default_config["listings_endpoint"])

## Get full listings URL (base + endpoint)
func get_full_listings_url() -> String:
	return get_api_base_url() + get_listings_endpoint()

## Get timeout in seconds for HTTP requests
func get_timeout_seconds() -> int:
	return config.get("timeout_seconds", default_config["timeout_seconds"])

## Check if debug logs are enabled
func is_debug_enabled() -> bool:
	return config.get("enable_debug_logs", default_config["enable_debug_logs"])

# PHASE 1.1: Timeout configuration getters
## Get request timeout for HTTP operations
func get_request_timeout() -> float:
	return config.get("request_timeout", default_config["request_timeout"])

## Get maximum retry attempts
func get_max_retry_attempts() -> int:
	return config.get("max_retry_attempts", default_config["max_retry_attempts"])

## Get retry delay in seconds
func get_retry_delay() -> float:
	return config.get("retry_delay", default_config["retry_delay"])

## Get connection timeout
func get_connection_timeout() -> float:
	return config.get("connection_timeout", default_config["connection_timeout"])

## Update timeout configuration
func update_timeout_config(request_timeout: float, max_retries: int = -1, retry_delay: float = -1) -> void:
	config["request_timeout"] = request_timeout

	if max_retries >= 0:
		config["max_retry_attempts"] = max_retries

	if retry_delay >= 0:
		config["retry_delay"] = retry_delay

	save_config()
	print("[TradingConfig] Timeout configuration updated")

## Get configuration summary for debugging
func get_config_summary() -> Dictionary:
	return {
		"api_base_url": get_api_base_url(),
		"listings_endpoint": get_listings_endpoint(),
		"request_timeout": get_request_timeout(),
		"max_retry_attempts": get_max_retry_attempts(),
		"retry_delay": get_retry_delay(),
		"connection_timeout": get_connection_timeout(),
		"debug_enabled": is_debug_enabled()
	}
