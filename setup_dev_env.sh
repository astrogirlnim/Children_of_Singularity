#!/bin/bash
# setup_dev_env.sh - Quick development environment setup
# Sets up .env files for development work

echo "🛠️  Children of the Singularity - Development Environment Setup"
echo ""

# Function to setup trading environment
setup_trading_env() {
    if [[ -f "trading.env" ]]; then
        echo "✅ trading.env already exists"
        return
    fi

    if [[ ! -f "trading.env.template" ]]; then
        echo "❌ Error: trading.env.template not found!"
        exit 1
    fi

    echo "📝 Creating trading.env from template..."
    cp trading.env.template trading.env

    # Use infrastructure_setup.env as source for actual API endpoint
    if [[ -f "infrastructure_setup.env" ]]; then
        local api_endpoint=$(grep "^API_GATEWAY_ENDPOINT=" infrastructure_setup.env | cut -d'=' -f2)
        if [[ -n "$api_endpoint" ]]; then
            # Update the template with actual endpoint
            sed -i.bak "s|API_GATEWAY_ENDPOINT=https://YOUR_API_ID.*|API_GATEWAY_ENDPOINT=$api_endpoint|g" trading.env
            rm trading.env.bak
            echo "🔗 Updated with actual API endpoint: $api_endpoint"
        fi
    fi

    echo "✅ trading.env created"
}

# Function to setup lobby environment
setup_lobby_env() {
    if [[ -f "lobby.env" ]]; then
        echo "✅ lobby.env already exists"
        return
    fi

    if [[ ! -f "lobby.env.template" ]]; then
        echo "❌ Error: lobby.env.template not found!"
        exit 1
    fi

    echo "📝 Creating lobby.env from template..."
    cp lobby.env.template lobby.env

    # Use infrastructure_setup.env as source for actual WebSocket URL
    if [[ -f "infrastructure_setup.env" ]]; then
        local websocket_url=$(grep "^WEBSOCKET_URL=" infrastructure_setup.env | cut -d'=' -f2)
        if [[ -n "$websocket_url" ]]; then
            # Update the template with actual WebSocket URL
            sed -i.bak "s|WEBSOCKET_URL=wss://YOUR_API_ID.*|WEBSOCKET_URL=$websocket_url|g" lobby.env
            rm lobby.env.bak
            echo "🔗 Updated with actual WebSocket URL: $websocket_url"
        fi
    fi

    echo "✅ lobby.env created"
}

# Function to validate setup
validate_setup() {
    echo ""
    echo "🔍 Validating development environment..."

    local issues=0

    # Check trading config
    if [[ -f "trading.env" ]]; then
        local api_endpoint=$(grep "^API_GATEWAY_ENDPOINT=" trading.env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        if [[ "$api_endpoint" == *"YOUR_API_ID"* ]]; then
            echo "⚠️  Warning: trading.env still contains template values"
            echo "   Please edit trading.env and update API_GATEWAY_ENDPOINT"
            issues=$((issues + 1))
        else
            echo "✅ Trading API endpoint configured: $api_endpoint"
        fi
    else
        echo "❌ trading.env not found"
        issues=$((issues + 1))
    fi

    # Check lobby config
    if [[ -f "lobby.env" ]]; then
        local websocket_url=$(grep "^WEBSOCKET_URL=" lobby.env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        if [[ "$websocket_url" == *"YOUR_API_ID"* ]]; then
            echo "⚠️  Warning: lobby.env still contains template values"
            echo "   Please edit lobby.env and update WEBSOCKET_URL"
            issues=$((issues + 1))
        else
            echo "✅ Lobby WebSocket URL configured: $websocket_url"
        fi
    else
        echo "❌ lobby.env not found"
        issues=$((issues + 1))
    fi

    echo ""
    if [[ $issues -eq 0 ]]; then
        echo "🎉 Development environment setup complete!"
        echo "🚀 You can now run the game in development mode"
    else
        echo "⚠️  Setup completed with $issues warnings"
        echo "💡 Please review and update the configuration files as needed"
    fi
}

# Main execution
echo "Setting up development environment..."
echo ""

setup_trading_env
setup_lobby_env
validate_setup

echo ""
echo "📋 Next steps:"
echo "1. Review trading.env and lobby.env files"
echo "2. Update any placeholder values if needed"
echo "3. Run the game to test configuration"
echo ""
echo "💡 For production builds, use: BUILD_ENV=production ./build.sh"
