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
	"""Load configuration from local file, falling back to defaults"""

	# Try to load from local config file
	if FileAccess.file_exists(config_file_path):
		var file = FileAccess.open(config_file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_text)
			if parse_result == OK:
				var loaded_config = json.data
				# Merge loaded config with defaults
				for key in loaded_config:
					config[key] = loaded_config[key]
				print("[TradingConfig] Loaded configuration from %s" % config_file_path)
			else:
				print("[TradingConfig] Error parsing config file: %s" % json.get_error_message())
	else:
		print("[TradingConfig] No config file found, using defaults")
		print("[TradingConfig] Create %s to override default settings" % config_file_path)
		create_default_config_file()

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
