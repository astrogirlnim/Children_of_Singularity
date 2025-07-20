# marketplace_aws_integration.gd
# Helper script for integrating Godot marketplace with AWS backend
# This script provides utilities for setting up and testing AWS API integration

extends Node

## Test AWS API connection and setup
static func test_aws_connection(api_url: String) -> Dictionary:
	print("[AWS Integration] Testing connection to: %s" % api_url)

	var http_request = HTTPRequest.new()
	var result = {"success": false, "message": "", "response_code": 0}

	# Simple health check - try to get listings
	var headers = ["Content-Type: application/json"]
	var error = http_request.request(api_url + "/listings", headers, HTTPClient.METHOD_GET)

	if error != OK:
		result.message = "Failed to send request: " + str(error)
		return result

	# Note: This is a basic test - for full testing you'd need to await the response
	result.success = true
	result.message = "Request sent successfully"
	return result

## Generate trading config file content for AWS
static func generate_aws_config(api_gateway_url: String) -> String:
	var config = {
		"_note": "AWS Trading API Configuration",
		"_last_updated": Time.get_datetime_string_from_system(),
		"api_base_url": api_gateway_url,
		"listings_endpoint": "/listings",
		"timeout_seconds": 30,
		"enable_debug_logs": true,
		"aws_integration": {
			"enabled": true,
			"region": _extract_region_from_url(api_gateway_url),
			"deployment_stage": _extract_stage_from_url(api_gateway_url)
		}
	}

	return JSON.stringify(config, "\t")

## Extract AWS region from API Gateway URL
static func _extract_region_from_url(url: String) -> String:
	var regex = RegEx.new()
	regex.compile(r"execute-api\.([^.]+)\.amazonaws\.com")
	var result = regex.search(url)
	return result.get_string(1) if result else "unknown"

## Extract deployment stage from API Gateway URL
static func _extract_stage_from_url(url: String) -> String:
	var parts = url.split("/")
	return parts[-1] if parts.size() > 0 else "prod"

## Validate API Gateway URL format
static func validate_aws_api_url(url: String) -> Dictionary:
	var result = {"valid": false, "message": ""}

	if url.is_empty():
		result.message = "URL cannot be empty"
		return result

	if not url.begins_with("https://"):
		result.message = "URL must start with https://"
		return result

	if not url.contains("execute-api") or not url.contains("amazonaws.com"):
		result.message = "URL must be a valid AWS API Gateway URL"
		return result

	if url.contains("your-api-gateway-id") or url.contains("your-region"):
		result.message = "URL contains template placeholders - replace with actual values"
		return result

	result.valid = true
	result.message = "URL format is valid"
	return result

## Create configuration file in Godot user directory
static func create_trading_config_file(api_gateway_url: String) -> bool:
	var validation = validate_aws_api_url(api_gateway_url)
	if not validation.valid:
		print("[AWS Integration] Invalid URL: %s" % validation.message)
		return false

	var config_content = generate_aws_config(api_gateway_url)
	var config_path = "user://trading_config.json"

	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if not file:
		print("[AWS Integration] ERROR: Could not create config file at %s" % config_path)
		return false

	file.store_string(config_content)
	file.close()

	print("[AWS Integration] ✅ Created trading config at: %s" % config_path)
	print("[AWS Integration] Config content: %s" % config_content)
	return true

## Get the Godot user directory path for manual file creation
static func get_user_directory_path() -> String:
	# This varies by platform
	match OS.get_name():
		"Windows":
			return OS.get_environment("APPDATA") + "/Godot/app_userdata/Children of the Singularity/"
		"macOS":
			return OS.get_environment("HOME") + "/Library/Application Support/Godot/app_userdata/Children of the Singularity/"
		"Linux":
			return OS.get_environment("HOME") + "/.local/share/godot/app_userdata/Children of the Singularity/"
		_:
			return "unknown"

## Print integration instructions
static func print_integration_instructions():
	print("=== AWS MARKETPLACE INTEGRATION INSTRUCTIONS ===")
	print("")
	print("1. Get your AWS API Gateway URL from your deployment")
	print("   Format: https://YOUR-API-ID.execute-api.YOUR-REGION.amazonaws.com/prod")
	print("")
	print("2. Create trading config using one of these methods:")
	print("   Method A - In Game:")
	print("     marketplace_aws_integration.create_trading_config_file(\"YOUR-API-URL\")")
	print("")
	print("   Method B - Manual:")
	print("     Create file at: user://trading_config.json")
	print("     Platform paths:")
	print("     - Windows: %s" % get_user_directory_path())
	print("     - macOS: %s" % get_user_directory_path())
	print("     - Linux: %s" % get_user_directory_path())
	print("")
	print("3. Restart the game - marketplace will automatically use AWS API")
	print("")
	print("4. Test by opening Trading Terminal > MARKETPLACE > REFRESH LISTINGS")
	print("")
	print("=== END INSTRUCTIONS ===")
