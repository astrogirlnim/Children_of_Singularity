extends Node

# Default configuration values (used if config file doesn't exist)
var default_config = {
	"api_base_url": "https://your-api-gateway-id.execute-api.your-region.amazonaws.com/prod",
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

	if FileAccess.file_exists(config_file_path):
		var file = FileAccess.open(config_file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_text)

			if parse_result == OK:
				config = json.data
				print("[TradingConfig] Configuration loaded from file")
				_merge_default_values()  # Ensure new fields are added
			else:
				print("[TradingConfig] Failed to parse config file, using defaults")
				config = default_config.duplicate()
				save_config()
		else:
			print("[TradingConfig] Failed to open config file, using defaults")
			config = default_config.duplicate()
			save_config()
	else:
		print("[TradingConfig] Config file not found, creating default configuration")
		config = default_config.duplicate()
		save_config()

	_validate_config()

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
