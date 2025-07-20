#!/bin/bash

# Children of the Singularity - Local-Only Development Startup Script
# This script starts the game in local-only mode (pure offline functionality)
# Game uses LocalPlayerData.gd for all data operations

set -e  # Exit on any error

echo "🚀 Starting Children of the Singularity - Local-Only Mode"
echo "========================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to verify process is running
verify_process() {
    local pid=$1
    local name=$2
    if ps -p $pid > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $name is running (PID: $pid)${NC}"
        return 0
    else
        echo -e "${RED}❌ $name failed to start or crashed${NC}"
        return 1
    fi
}

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Shutting down development environment...${NC}"

    # Kill Godot process
    if [[ -n $GODOT_PID ]]; then
        echo -e "${YELLOW}Stopping Godot game (PID: $GODOT_PID)...${NC}"
        kill $GODOT_PID 2>/dev/null || true
        # Wait for graceful shutdown
        sleep 2
        # Force kill if still running
        if ps -p $GODOT_PID > /dev/null 2>&1; then
            kill -9 $GODOT_PID 2>/dev/null || true
        fi
    fi

    echo -e "${GREEN}Development environment stopped.${NC}"
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

echo -e "${PURPLE}🎯 LOCAL-ONLY MODE${NC}"
echo -e "${BLUE}Pure offline functionality with complete data persistence:${NC}"
echo -e "  • No backend dependencies"
echo -e "  • All data stored locally in user:// directory"
echo -e "  • APIClient.gd operates in local-only mode"
echo -e "  • AWS Trading Marketplace still available via TradingMarketplace.gd"
echo ""

echo -e "${BLUE}Step 1: Checking Godot installation...${NC}"

# Check if Godot is available
if ! command -v godot &> /dev/null; then
    echo -e "${RED}❌ Godot not found in PATH${NC}"
    echo -e "${YELLOW}Please install Godot 4.4+ or add it to your PATH${NC}"
    echo -e "${YELLOW}On macOS: brew install godot${NC}"
    echo -e "${YELLOW}On Linux: Download from https://godotengine.org${NC}"
    exit 1
fi

# Get Godot version
GODOT_VERSION=$(godot --version 2>/dev/null || echo "unknown")
echo -e "${GREEN}✅ Godot found: $GODOT_VERSION${NC}"

echo -e "${BLUE}Step 2: Verifying project structure...${NC}"

# Check if we're in the right directory
if [ ! -f "project.godot" ]; then
    echo -e "${RED}❌ project.godot not found${NC}"
    echo -e "${YELLOW}Please run this script from the Children of the Singularity project root${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Project structure verified${NC}"

echo -e "${BLUE}Step 3: Setting up development environment...${NC}"

# Check if environment files exist, if not, set them up
if [[ ! -f "trading.env" || ! -f "lobby.env" ]]; then
    echo -e "${YELLOW}Environment files missing. Setting up development configuration...${NC}"

    if [[ -f "setup_dev_env.sh" ]]; then
        ./setup_dev_env.sh
    else
        echo -e "${YELLOW}⚠️  setup_dev_env.sh not found. Creating basic environment files...${NC}"

        # Create basic trading.env if missing
        if [[ ! -f "trading.env" && -f "trading.env.template" ]]; then
            cp trading.env.template trading.env
            echo -e "${GREEN}✅ Created trading.env from template${NC}"
        fi

        # Create basic lobby.env if missing
        if [[ ! -f "lobby.env" && -f "lobby.env.template" ]]; then
            cp lobby.env.template lobby.env
            echo -e "${GREEN}✅ Created lobby.env from template${NC}"
        fi
    fi
else
    echo -e "${GREEN}✅ Environment files found${NC}"
fi

# Validate environment configuration
echo -e "${BLUE}Validating environment configuration...${NC}"

# Check trading configuration
if [[ -f "trading.env" ]]; then
    API_ENDPOINT=$(grep "^API_GATEWAY_ENDPOINT=" trading.env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    if [[ "$API_ENDPOINT" == *"YOUR_API_ID"* ]]; then
        echo -e "${YELLOW}⚠️  trading.env contains template values - marketplace may not work${NC}"
        echo -e "${YELLOW}   Edit trading.env to fix marketplace 'Refresh Listings' button${NC}"
    else
        echo -e "${GREEN}✅ Trading API configured: $API_ENDPOINT${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  trading.env not found - marketplace will use fallback configuration${NC}"
fi

# Check lobby configuration
if [[ -f "lobby.env" ]]; then
    WEBSOCKET_URL=$(grep "^WEBSOCKET_URL=" lobby.env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    if [[ "$WEBSOCKET_URL" == *"YOUR_API_ID"* ]]; then
        echo -e "${YELLOW}⚠️  lobby.env contains template values - multiplayer lobby may not work${NC}"
        echo -e "${YELLOW}   Edit lobby.env to fix multiplayer lobby connection${NC}"
    else
        echo -e "${GREEN}✅ Lobby WebSocket configured: $WEBSOCKET_URL${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  lobby.env not found - lobby will use fallback configuration${NC}"
fi

echo -e "${BLUE}Step 4: Checking local data directory...${NC}"

# Create user data directory structure for testing (optional)
USER_DATA_DIR="$HOME/.local/share/godot/app_userdata/Children of the Singularity"
if [[ "$OSTYPE" == "darwin"* ]]; then
    USER_DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/Children of the Singularity"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    USER_DATA_DIR="$APPDATA/Godot/app_userdata/Children of the Singularity"
fi

echo -e "${YELLOW}Local data will be stored in:${NC}"
echo -e "  $USER_DATA_DIR"

if [ -d "$USER_DATA_DIR" ]; then
    echo -e "${GREEN}✅ User data directory exists${NC}"

    # Show existing save files if any
    if ls "$USER_DATA_DIR"/*.json &> /dev/null; then
        echo -e "${BLUE}📄 Existing save files:${NC}"
        ls -la "$USER_DATA_DIR"/*.json 2>/dev/null | while read -r line; do
            echo -e "    $line"
        done
    else
        echo -e "${YELLOW}📄 No existing save files (will be created on first run)${NC}"
    fi
else
    echo -e "${YELLOW}📁 User data directory will be created on first run${NC}"
fi

echo ""
echo -e "${BLUE}Step 5: Starting Godot game in local-only mode...${NC}"

# Start Godot game
echo -e "${YELLOW}Launching Godot game...${NC}"
godot --run-project . &
GODOT_PID=$!

# Wait a moment for Godot to start
sleep 3

# Verify Godot process is still running
if ! verify_process $GODOT_PID "Godot Game"; then
    echo -e "${RED}❌ Godot failed to start properly${NC}"

    # Check for common issues
    echo -e "${YELLOW}Common troubleshooting steps:${NC}"
    echo -e "  1. Check if Godot version is 4.4+"
    echo -e "  2. Verify no script errors in the Godot editor"
    echo -e "  3. Try running: godot --editor . (to open in editor first)"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Local-Only development environment fully operational!${NC}"
echo ""
echo -e "${PURPLE}🎮 GAME INFORMATION:${NC}"
echo -e "  🎯 Mode: ${GREEN}Local-Only (Pure Offline)${NC}"
echo -e "  🎮 Game: ${GREEN}Running (PID: $GODOT_PID)${NC}"
echo -e "  💾 Data: ${GREEN}Local JSON files only${NC}"
echo -e "  🌐 Network: ${GREEN}No backend required${NC}"
echo -e "  🔄 Trading: ${GREEN}AWS Marketplace available${NC}"
echo ""
echo -e "${BLUE}🔍 WHAT'S HAPPENING:${NC}"
echo -e "  • APIClient.gd operates in pure local-only mode"
echo -e "  • All player data managed by LocalPlayerData.gd"
echo -e "  • Complete offline functionality with data persistence"
echo -e "  • AWS Trading Marketplace available via TradingMarketplace.gd"
echo -e "  • Environment files (trading.env, lobby.env) configure external services"
echo ""
echo -e "${BLUE}💾 LOCAL DATA FILES:${NC}"
echo -e "  📄 player_save.json       - Credits, progress, player ID"
echo -e "  📄 player_inventory.json  - Items and quantities"
echo -e "  📄 player_upgrades.json   - Upgrade levels"
echo -e "  📄 player_settings.json   - Game preferences"
echo ""
echo -e "${YELLOW}💡 DEVELOPMENT TIPS:${NC}"
echo -e "  • This matches exactly what release users experience"
echo -e "  • Test all offline functionality, data persistence, upgrades"
echo -e "  • Data persists between sessions in user:// directory"
echo -e "  • Inventory clearing and upgrade resetting fully supported"
echo -e "  • Marketplace 'Refresh Listings' button requires proper trading.env setup"
echo -e "  • Multiplayer lobby requires proper lobby.env setup"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the game${NC}"

# Monitor process and wait
while true; do
    # Check if Godot is still running
    if ! ps -p $GODOT_PID > /dev/null 2>&1; then
        echo -e "${YELLOW}Godot process ended. Development session complete.${NC}"
        break
    fi

    sleep 5
done

echo ""
echo -e "${GREEN}🎉 Local-only development session completed successfully!${NC}"
echo -e "${BLUE}Your save data has been preserved in: $USER_DATA_DIR${NC}"
