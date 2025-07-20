# Trading Environment Configuration Guide

## 🎯 Overview

The trading marketplace API connection can now be configured dynamically using environment variables instead of hardcoded URLs. This follows [12-factor app principles](https://12factor.net/config) and makes deployment much more flexible.

## 🏆 Configuration Priority (Highest to Lowest)

1. **OS Environment Variables** - `export API_GATEWAY_ENDPOINT=...`
2. **User Environment Files** - `user://trading.env` or `user://.env`
3. **Project Environment Files** - `res://infrastructure_setup.env`
4. **JSON Configuration Files** - `user://trading_config.json`
5. **Hardcoded Defaults** - Fallback values in `TradingConfig.gd`

## 🚀 Quick Setup Options

### Option 1: OS Environment Variables (Recommended for Production)

```bash
# Set environment variables in your shell
export API_GATEWAY_ENDPOINT="https://2clyiu4f8f.execute-api.us-east-2.amazonaws.com/prod"
export TRADING_DEBUG="true"

# Run the game
godot --path . res://scenes/zones/ZoneMain3D.tscn
```

### Option 2: Project Environment File (Recommended for Development)

```bash
# 1. Copy the template file
cp trading.env.template trading.env

# 2. Edit trading.env with your actual values
# Update API_GATEWAY_ENDPOINT=https://YOUR_ACTUAL_API_ID.execute-api.us-east-2.amazonaws.com/prod

# 3. The game will automatically load from trading.env
```

### Option 3: User Environment File (Recommended for User-Specific Config)

Create `user://trading.env` in your Godot user directory:

**macOS**: `~/Library/Application Support/Godot/app_userdata/Children of the Singularity/trading.env`  
**Linux**: `~/.local/share/godot/app_userdata/Children of the Singularity/trading.env`  
**Windows**: `%APPDATA%/Godot/app_userdata/Children of the Singularity/trading.env`

```bash
# Content of user://trading.env
API_GATEWAY_ENDPOINT=https://2clyiu4f8f.execute-api.us-east-2.amazonaws.com/prod
TRADING_DEBUG=true
```

## 📝 Environment Variables Reference

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `API_GATEWAY_ENDPOINT` | **Required** - Trading API Gateway URL | `https://your-api-gateway...` | `https://2clyiu4f8f.execute-api.us-east-2.amazonaws.com/prod` |
| `TRADING_TIMEOUT` | HTTP request timeout in seconds | `15` | `30` |
| `TRADING_DEBUG` | Enable debug logging | `true` | `false` |
| `TRADING_MAX_RETRIES` | Maximum retry attempts for failed requests | `3` | `5` |

## 🛠️ Development Workflows

### Local Development (Mock API Server)

```bash
# Create development environment
cat > trading.env << EOF
API_GATEWAY_ENDPOINT=http://localhost:3000
TRADING_DEBUG=true
TRADING_TIMEOUT=5
EOF

# Start local API server (if you have one)
# Then run the game - it will connect to localhost
```

### Staging Environment

```bash
# Create staging environment
export API_GATEWAY_ENDPOINT="https://staging-api.execute-api.us-east-2.amazonaws.com/prod"
export TRADING_DEBUG="true"
export TRADING_MAX_RETRIES="5"

# Run game with staging config
```

### Production Environment

```bash
# Set production environment variables
export API_GATEWAY_ENDPOINT="https://2clyiu4f8f.execute-api.us-east-2.amazonaws.com/prod"
export TRADING_DEBUG="false"
export TRADING_TIMEOUT="15"

# Run game with production config
```

## 🔧 Integration with Infrastructure Setup

The `infrastructure_setup.env` file is used as a fallback and contains the current deployment values:

```bash
# Check current infrastructure configuration
grep API_GATEWAY_ENDPOINT infrastructure_setup.env
# Output: API_GATEWAY_ENDPOINT=https://2clyiu4f8f.execute-api.us-east-2.amazonaws.com/prod
```

## 🧪 Testing Configuration Loading

Check the console logs when the game starts to see which configuration source was used:

```
[TradingConfig] Loading configuration from user://trading_config.json
[TradingConfig] Checking for .env configuration...
[TradingConfig] Found .env file at: res://trading.env
[TradingConfig] Found API_GATEWAY_ENDPOINT in .env: https://2clyiu4f8f.execute-api.us-east-2.amazonaws.com/prod
[TradingConfig] ✅ Successfully loaded configuration from .env file
```

## 🔍 Troubleshooting

### "Refresh Listings" Button Not Working

1. **Check configuration loading**:
   ```bash
   # Enable debug to see which config source is used
   export TRADING_DEBUG=true
   ```

2. **Verify API Gateway URL format**:
   ```bash
   # Correct format
   API_GATEWAY_ENDPOINT=https://api-id.execute-api.region.amazonaws.com/stage

   # Test with curl
   curl "https://2clyiu4f8f.execute-api.us-east-2.amazonaws.com/prod/listings"
   ```

3. **Check file permissions**:
   ```bash
   # Ensure the .env file is readable
   ls -la trading.env
   ```

### Configuration Not Loading

1. **Check environment variable spelling** - Variables are case-sensitive
2. **Verify file locations** - Use absolute paths for debugging
3. **Check quotes in .env files** - Both single and double quotes are supported
4. **Review console logs** - All configuration attempts are logged

### API Connection Issues

1. **Network connectivity**:
   ```bash
   # Test API connectivity
   curl -v "https://2clyiu4f8f.execute-api.us-east-2.amazonaws.com/prod/listings"
   ```

2. **CORS issues** - API Gateway should have CORS enabled
3. **API Gateway status** - Check AWS console for API Gateway health

## 🎯 Best Practices

1. **Use environment variables for production** - More secure and flexible
2. **Use .env files for development** - Easy to switch between environments  
3. **Never commit .env files** - They're in .gitignore for security
4. **Use the template** - Copy `trading.env.template` as starting point
5. **Test configuration loading** - Check console logs to verify source
6. **Document your setup** - Add comments to your .env files

## 🔐 Security Considerations

- ✅ **Environment files are gitignored** - Won't be committed accidentally
- ✅ **API URLs are not secrets** - They're public endpoints
- ✅ **Configuration hierarchy** - Environment variables override files
- ✅ **Graceful fallbacks** - System works even if config is missing

## 📋 Setup Checklist for New Computers

When setting up the game on a new computer, ensure marketplace functionality works:

- [ ] Copy `trading.env.template` to `trading.env`
- [ ] Update `API_GATEWAY_ENDPOINT` with actual API Gateway URL
- [ ] Verify `trading.env` is not committed to git (in .gitignore)
- [ ] Test "Refresh Listings" button in lobby
- [ ] Check console logs for successful configuration loading
- [ ] Test posting and purchasing items in marketplace

## 🔗 Related Documentation

- [Lobby Environment Configuration](lobby_environment_configuration.md) - Similar pattern for WebSocket lobby
- [AWS Infrastructure Setup](aws_serverless_trading_setup.md) - Backend deployment guide
- [Marketplace System Overview](marketplace_complete_system_overview.md) - Complete trading system documentation
