#!/bin/bash
# build_config.sh - Build-time configuration injection for Children of the Singularity
# This script prepares configuration for different build environments

set -e

echo "🔧 Build Configuration Setup for Children of the Singularity"

# Determine build environment
BUILD_ENV=${1:-production}
echo "📦 Build Environment: $BUILD_ENV"

# Configuration file paths
TRADING_CONFIG_TEMPLATE="scripts/TradingConfig.gd"
LOBBY_CONFIG_TEMPLATE="scripts/LobbyController.gd"
BUILD_CONFIG_DIR="build_configs"
TRADING_ENV_FILE=""
LOBBY_ENV_FILE=""

# Set environment-specific files
case $BUILD_ENV in
    "development")
        echo "🛠️  Development build - using local configuration"
        TRADING_ENV_FILE="trading.env.template"
        LOBBY_ENV_FILE="lobby.env.template"
        ;;
    "staging")
        echo "🧪 Staging build - using staging configuration"
        TRADING_ENV_FILE="trading.staging.env"
        LOBBY_ENV_FILE="lobby.staging.env"
        ;;
    "production")
        echo "🚀 Production build - using production configuration"
        TRADING_ENV_FILE="trading.env"
        LOBBY_ENV_FILE="lobby.env"
        ;;
    *)
        echo "❌ Unknown build environment: $BUILD_ENV"
        echo "Available: development, staging, production"
        exit 1
        ;;
esac

# Create build configs directory
mkdir -p "$BUILD_CONFIG_DIR"

# Function to extract value from env file
extract_env_value() {
    local env_file=$1
    local key=$2

    if [[ ! -f "$env_file" ]]; then
        echo "⚠️  Warning: Environment file not found: $env_file"
        return 1
    fi

    grep "^$key=" "$env_file" | cut -d'=' -f2 | tr -d '"' | tr -d "'"
}

# Function to inject trading configuration
inject_trading_config() {
    echo "📝 Injecting trading configuration..."

    local api_endpoint=""
    if [[ -f "$TRADING_ENV_FILE" ]]; then
        api_endpoint=$(extract_env_value "$TRADING_ENV_FILE" "API_GATEWAY_ENDPOINT")
    fi

    if [[ -z "$api_endpoint" ]]; then
        echo "❌ Error: API_GATEWAY_ENDPOINT not found in $TRADING_ENV_FILE"
        exit 1
    fi

    echo "🔗 Using API endpoint: $api_endpoint"

    # Create backup of original file
    cp "$TRADING_CONFIG_TEMPLATE" "$TRADING_CONFIG_TEMPLATE.original"

    # Inject production API endpoint directly into source file
    sed -i.bak "s|\"api_base_url\": \"\"|\"api_base_url\": \"$api_endpoint\"|g" "$TRADING_CONFIG_TEMPLATE"

    echo "✅ Trading configuration injected into $TRADING_CONFIG_TEMPLATE"
}

# Function to inject lobby configuration
inject_lobby_config() {
    echo "📝 Injecting lobby configuration..."

    local websocket_url=""
    if [[ -f "$LOBBY_ENV_FILE" ]]; then
        websocket_url=$(extract_env_value "$LOBBY_ENV_FILE" "WEBSOCKET_URL")
    fi

    if [[ -z "$websocket_url" ]]; then
        echo "❌ Error: WEBSOCKET_URL not found in $LOBBY_ENV_FILE"
        exit 1
    fi

    echo "🔗 Using WebSocket URL: $websocket_url"

    # Create backup of original file
    cp "$LOBBY_CONFIG_TEMPLATE" "$LOBBY_CONFIG_TEMPLATE.original"

    # Inject production WebSocket URL directly into source file
    sed -i.bak "s|websocket_url = \"wss://.*\"|websocket_url = \"$websocket_url\"|g" "$LOBBY_CONFIG_TEMPLATE"

    echo "✅ Lobby configuration injected into $LOBBY_CONFIG_TEMPLATE"
}

# Function to backup original files and replace with configured versions
apply_build_config() {
    echo "🔄 Applying build configuration..."

    # Note: inject_trading_config and inject_lobby_config now handle
    # their own backups and in-place modifications

    echo "✅ Build configuration applied"
    echo "📁 Original files backed up with .original extension"
}

# Function to restore original configuration files
restore_config() {
    echo "🔄 Restoring original configuration files..."

    if [[ -f "$TRADING_CONFIG_TEMPLATE.original" ]]; then
        mv "$TRADING_CONFIG_TEMPLATE.original" "$TRADING_CONFIG_TEMPLATE"
        echo "✅ Trading config restored"
    fi

    if [[ -f "$LOBBY_CONFIG_TEMPLATE.original" ]]; then
        mv "$LOBBY_CONFIG_TEMPLATE.original" "$LOBBY_CONFIG_TEMPLATE"
        echo "✅ Lobby config restored"
    fi
}

# Function to validate environment files exist
validate_env_files() {
    echo "🔍 Validating environment files..."

    if [[ "$BUILD_ENV" == "production" ]]; then
        if [[ ! -f "$TRADING_ENV_FILE" ]]; then
            echo "❌ Error: Production trading.env file not found!"
            echo "💡 Please copy trading.env.template to trading.env and configure it"
            exit 1
        fi

        if [[ ! -f "$LOBBY_ENV_FILE" ]]; then
            echo "❌ Error: Production lobby.env file not found!"
            echo "💡 Please copy lobby.env.template to lobby.env and configure it"
            exit 1
        fi
    fi

    echo "✅ Environment files validated"
}

# Main execution
case ${2:-inject} in
    "inject")
        validate_env_files
        inject_trading_config
        inject_lobby_config
        apply_build_config
        echo ""
        echo "🎯 Build configuration complete for $BUILD_ENV environment"
        echo "📦 Ready to build game with injected configuration"
        echo ""
        echo "💡 Run './build_config.sh $BUILD_ENV restore' to restore original files"
        ;;
    "restore")
        restore_config
        echo "🔄 Configuration restored to development state"
        ;;
    *)
        echo "❌ Unknown action: ${2:-inject}"
        echo "Available actions: inject, restore"
        exit 1
        ;;
esac
