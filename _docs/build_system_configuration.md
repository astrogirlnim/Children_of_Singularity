# Build System Configuration Guide

## 🎯 Overview

The Children of the Singularity uses a sophisticated build-time configuration system that ensures:

1. **Development**: Easy setup with `.env` files for rapid iteration
2. **Production**: Self-contained builds with configuration baked in at build-time
3. **Security**: No secrets committed to source code
4. **Flexibility**: Support for multiple environments (development, staging, production)

## 🏗️ Architecture

### Configuration Flow

```
Development:
  .env files → Game reads at runtime → Easy debugging/testing

Production Build:
  .env files → Build-time injection → Self-contained executable
```

### Key Components

- **`trading.env`** - Trading marketplace API configuration
- **`lobby.env`** - WebSocket lobby configuration  
- **`build_config.sh`** - Build-time configuration injection
- **`setup_dev_env.sh`** - Development environment setup
- **`dev_start.sh`** - Development startup with env validation

## 🚀 Quick Start

### For Developers

```bash
# 1. Set up development environment
./setup_dev_env.sh

# 2. Start development
./dev_start.sh

# 3. Build for production
BUILD_ENV=production ./build.sh
```

### For New Team Members

```bash
# Clone the repository
git clone <repo-url>
cd Children_of_Singularity

# Set up environment automatically
./setup_dev_env.sh

# Start coding!
./dev_start.sh
```

## 📁 File Structure

```
Children_of_Singularity/
├── trading.env.template      # Template for trading API config
├── lobby.env.template        # Template for lobby WebSocket config
├── trading.env              # Actual trading config (gitignored)
├── lobby.env                # Actual lobby config (gitignored)
├── build_config.sh          # Build-time configuration injection
├── setup_dev_env.sh         # Development environment setup
├── dev_start.sh             # Development startup script
└── build.sh                 # Main build script
```

## 🔧 Configuration Files

### trading.env

```bash
# Trading Marketplace Configuration
API_GATEWAY_ENDPOINT=https://your-api.execute-api.region.amazonaws.com/prod
TRADING_TIMEOUT=15
TRADING_DEBUG=true
TRADING_MAX_RETRIES=3
```

### lobby.env

```bash
# Lobby WebSocket Configuration  
WEBSOCKET_URL=wss://your-websocket.execute-api.region.amazonaws.com/prod
LOBBY_CONNECTION_TIMEOUT=10
LOBBY_BROADCAST_INTERVAL=0.2
LOBBY_MAX_RETRIES=3
LOBBY_DEBUG_LOGS=true
```

## 🛠️ Development Workflow

### Initial Setup

```bash
# 1. Copy templates (automated by setup_dev_env.sh)
cp trading.env.template trading.env
cp lobby.env.template lobby.env

# 2. Update with your actual API endpoints
vim trading.env  # Update API_GATEWAY_ENDPOINT
vim lobby.env    # Update WEBSOCKET_URL

# 3. Start development
./dev_start.sh
```

### Daily Development

```bash
# Start development environment
./dev_start.sh

# The script will:
# - Validate environment files exist
# - Check configuration values
# - Start Godot with proper config
# - Show warnings for template values
```

## 🎯 Build Process

### Build Environments

1. **Development** - Uses template values for testing
2. **Staging** - Uses `*.staging.env` files  
3. **Production** - Uses `trading.env` and `lobby.env`

### Build Command

```bash
# Development build
BUILD_ENV=development ./build.sh

# Staging build  
BUILD_ENV=staging ./build.sh

# Production build (default)
BUILD_ENV=production ./build.sh
```

### What Happens During Build

1. **Configuration Injection**
   ```bash
   ./build_config.sh production inject
   ```
   - Reads production `.env` files
   - Injects values into Godot script files
   - Creates configured copies

2. **Godot Build Process**
   - Uses configured scripts with production values
   - Exports self-contained executable

3. **Cleanup**
   ```bash
   ./build_config.sh production restore
   ```
   - Restores original development scripts
   - Removes temporary build files

## 🔍 Configuration Priority

Each system follows this configuration hierarchy:

1. **OS Environment Variables** (highest priority)
2. **User Environment Files** (`user://trading.env`)
3. **Project Environment Files** (`res://trading.env`)
4. **Infrastructure Files** (`infrastructure_setup.env`)
5. **Build-time Injected Values** (production builds)
6. **Hardcoded Fallbacks** (emergency only)

## 🧪 Testing Configuration

### Validate Development Setup

```bash
# Check environment files
./setup_dev_env.sh

# Test configuration loading
./dev_start.sh

# Check marketplace functionality
# - Start game
# - Go to lobby
# - Test "Refresh Listings" button
```

### Test Production Build

```bash
# Build with production config
BUILD_ENV=production ./build.sh

# Test the built executable
./builds/children_of_singularity_*

# Verify marketplace works without .env files
```

## 🐛 Troubleshooting

### "Refresh Listings" Button Not Working

**Symptoms**: Button doesn't respond, no marketplace data

**Solution**:
```bash
# 1. Check if trading.env exists
ls -la trading.env

# 2. Validate configuration
./setup_dev_env.sh

# 3. Check API endpoint
grep API_GATEWAY_ENDPOINT trading.env
```

### Lobby Connection Failed

**Symptoms**: Cannot connect to multiplayer lobby

**Solution**:
```bash
# 1. Check if lobby.env exists  
ls -la lobby.env

# 2. Validate WebSocket URL
grep WEBSOCKET_URL lobby.env

# 3. Test WebSocket connectivity
curl -I https://your-websocket-api.execute-api.region.amazonaws.com/prod
```

### Template Values in Production

**Symptoms**: Production build contains "YOUR_API_ID" placeholders

**Solution**:
```bash
# 1. Ensure environment files have real values
cat trading.env | grep -v "YOUR_API_ID"
cat lobby.env | grep -v "YOUR_API_ID"

# 2. Re-run build configuration
./build_config.sh production inject
```

## 📋 Deployment Checklist

### Pre-Deployment

- [ ] All `.env` files contain production values
- [ ] No template placeholders (`YOUR_API_ID`) remain
- [ ] API endpoints are accessible
- [ ] WebSocket URLs are valid
- [ ] Build configuration injection works
- [ ] Built game runs without `.env` files

### Post-Deployment

- [ ] Marketplace "Refresh Listings" works
- [ ] Multiplayer lobby connects successfully
- [ ] No configuration-related errors in logs
- [ ] Game is fully self-contained

## 🔐 Security Considerations

### Development

- ✅ `.env` files are gitignored
- ✅ Templates provide safe defaults
- ✅ Setup scripts prevent accidental commits

### Production

- ✅ Configuration injected at build time
- ✅ No runtime dependency on external files
- ✅ Self-contained executables
- ✅ Original source code contains no secrets

## 🔗 Related Documentation

- [Trading Environment Configuration](trading_environment_configuration.md)
- [Lobby Environment Configuration](lobby_environment_configuration.md)
- [AWS Infrastructure Setup](aws_serverless_trading_setup.md)
- [Marketplace System Overview](marketplace_complete_system_overview.md)
