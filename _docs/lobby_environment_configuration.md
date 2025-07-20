# Lobby Environment Configuration Guide

## 🎯 Overview

The lobby WebSocket connection can now be configured dynamically using environment variables instead of hardcoded URLs. This follows [12-factor app principles](https://12factor.net/config) and makes deployment much more flexible.

## 🏆 Configuration Priority (Highest to Lowest)

1. **OS Environment Variables** - `export WEBSOCKET_URL=...`
2. **User Environment Files** - `user://lobby.env` or `user://.env`
3. **Project Environment Files** - `res://infrastructure_setup.env`
4. **JSON Configuration Files** - `res://infrastructure/lobby_config.json`
5. **Hardcoded Defaults** - Fallback values in `LobbyController.gd`

## 🚀 Quick Setup Options

### Option 1: OS Environment Variables (Recommended for Production)

```bash
# Set environment variables in your shell
export WEBSOCKET_URL="wss://bktpsfy4rb.execute-api.us-east-2.amazonaws.com/prod"
export LOBBY_DEBUG_LOGS="true"

# Run the game
godot --path . res://scenes/zones/ZoneMain3D.tscn
```

### Option 2: Project Environment File (Recommended for Development)

```bash
# 1. Copy the template file
cp lobby.env.template lobby.env

# 2. Edit lobby.env with your actual values
# Update WEBSOCKET_URL=wss://YOUR_ACTUAL_API_ID.execute-api.us-east-2.amazonaws.com/prod

# 3. The game will automatically load from lobby.env
```

### Option 3: User Environment File (Recommended for User-Specific Config)

Create `user://lobby.env` in your Godot user directory:

**macOS**: `~/Library/Application Support/Godot/app_userdata/Children of the Singularity/lobby.env`  
**Linux**: `~/.local/share/godot/app_userdata/Children of the Singularity/lobby.env`  
**Windows**: `%APPDATA%/Godot/app_userdata/Children of the Singularity/lobby.env`

```bash
# Content of user://lobby.env
WEBSOCKET_URL=wss://bktpsfy4rb.execute-api.us-east-2.amazonaws.com/prod
LOBBY_DEBUG_LOGS=true
```

## 📝 Environment Variables Reference

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `WEBSOCKET_URL` | **Required** - WebSocket API Gateway URL | `wss://bktpsfy4rb...` | `wss://your-api.execute-api.us-east-2.amazonaws.com/prod` |
| `LOBBY_CONNECTION_TIMEOUT` | Connection timeout in seconds | `10` | `15` |
| `LOBBY_BROADCAST_INTERVAL` | Position update interval in seconds | `0.2` | `0.1` |
| `LOBBY_MAX_RETRIES` | Maximum reconnection attempts | `3` | `5` |
| `LOBBY_DEBUG_LOGS` | Enable debug logging | `true` | `false` |

## 🛠️ Development Workflows

### Local Development (Mock WebSocket Server)

```bash
# Create development environment
cat > lobby.env << EOF
WEBSOCKET_URL=ws://localhost:8080
LOBBY_DEBUG_LOGS=true
LOBBY_CONNECTION_TIMEOUT=5
EOF

# Start local WebSocket server (if you have one)
# Then run the game - it will connect to localhost
```

### Staging Environment

```bash
# Create staging environment
export WEBSOCKET_URL="wss://staging-api.execute-api.us-east-2.amazonaws.com/prod"
export LOBBY_DEBUG_LOGS="true"
export LOBBY_MAX_RETRIES="5"

# Run game with staging config
```

### Production Environment

```bash
# Set production environment variables
export WEBSOCKET_URL="wss://bktpsfy4rb.execute-api.us-east-2.amazonaws.com/prod"
export LOBBY_DEBUG_LOGS="false"
export LOBBY_CONNECTION_TIMEOUT="10"

# Run game with production config
```

## 🔧 Integration with Infrastructure Setup

The `infrastructure/lobby-setup.sh` script automatically creates `lobby.env` with the correct values:

```bash
# Run the lobby setup script
./infrastructure/lobby-setup.sh

# This creates lobby.env with your actual AWS values:
# WEBSOCKET_URL=wss://YOUR_ACTUAL_API_ID.execute-api.us-east-2.amazonaws.com/prod
```

## 🧪 Testing Configuration Loading

Check the console logs when the game starts to see which configuration source was used:

```
[LobbyController] Loading lobby configuration with environment precedence
[LobbyController] Checking OS environment variables...
[LobbyController] ✅ Found WEBSOCKET_URL in environment: wss://bktpsfy4rb...
[LobbyController] Environment configuration loaded
[LobbyController] Configuration loaded successfully
[LobbyController] Final configuration:
[LobbyController]   WebSocket URL: wss://bktpsfy4rb.execute-api.us-east-2.amazonaws.com/prod
```

## 🔍 Troubleshooting

### Connection Issues

1. **Check configuration loading order**:
   ```bash
   # Enable debug to see which config source is used
   export LOBBY_DEBUG_LOGS=true
   ```

2. **Verify WebSocket URL format**:
   ```bash
   # Correct format
   WEBSOCKET_URL=wss://api-id.execute-api.region.amazonaws.com/stage

   # Test with wscat
   wscat -c "wss://bktpsfy4rb.execute-api.us-east-2.amazonaws.com/prod"
   ```

3. **Check file permissions**:
   ```bash
   # Ensure the .env file is readable
   ls -la lobby.env
   ```

### Configuration Not Loading

1. **Check environment variable spelling** - Variables are case-sensitive
2. **Verify file locations** - Use absolute paths for debugging
3. **Check quotes in .env files** - Both single and double quotes are supported
4. **Review console logs** - All configuration attempts are logged

## 🎯 Best Practices

1. **Use environment variables for production** - More secure and flexible
2. **Use .env files for development** - Easy to switch between environments  
3. **Never commit .env files** - They're in .gitignore for security
4. **Use the template** - Copy `lobby.env.template` as starting point
5. **Test configuration loading** - Check console logs to verify source
6. **Document your setup** - Add comments to your .env files

## 🔐 Security Considerations

- ✅ **Environment files are gitignored** - Won't be committed accidentally
- ✅ **WebSocket URLs are not secrets** - They're public endpoints
- ✅ **Configuration hierarchy** - Environment variables override files
- ✅ **Graceful fallbacks** - System works even if config is missing

This new configuration system makes the lobby much more flexible for different deployment environments while maintaining backward compatibility with the existing JSON configuration approach.
