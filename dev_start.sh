#!/bin/bash

# Children of the Singularity - Development Startup Script
# This script starts both the backend API and Godot game for local development

set -e  # Exit on any error

echo "🚀 Starting Children of the Singularity Development Environment"
echo "=============================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to kill process on port
kill_port() {
    local port=$1
    echo -e "${YELLOW}Killing existing process on port $port...${NC}"
    lsof -ti :$port | xargs kill -9 2>/dev/null || true
    sleep 2
}

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Shutting down development environment...${NC}"
    if [[ -n $BACKEND_PID ]]; then
        echo -e "${YELLOW}Stopping backend API (PID: $BACKEND_PID)...${NC}"
        kill $BACKEND_PID 2>/dev/null || true
    fi
    if [[ -n $GODOT_PID ]]; then
        echo -e "${YELLOW}Stopping Godot game (PID: $GODOT_PID)...${NC}"  
        kill $GODOT_PID 2>/dev/null || true
    fi
    echo -e "${GREEN}Development environment stopped.${NC}"
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# Check if backend port is already in use
BACKEND_PORT=8000
if check_port $BACKEND_PORT; then
    echo -e "${YELLOW}Backend port $BACKEND_PORT is already in use.${NC}"
    read -p "Kill existing process and continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kill_port $BACKEND_PORT
    else
        echo -e "${RED}Exiting. Please stop the existing process first.${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}Step 1: Setting up Python virtual environment...${NC}"

# Create venv if it doesn't exist
if [ ! -d "backend/venv" ]; then
    echo -e "${YELLOW}Creating Python virtual environment...${NC}"
    python3 -m venv backend/venv
fi

# Activate venv and install dependencies
echo -e "${YELLOW}Activating virtual environment and checking dependencies...${NC}"
source backend/venv/bin/activate

# Install core dependencies (skip problematic ones for now)
pip install -q fastapi uvicorn pydantic python-multipart python-dotenv httpx 2>/dev/null || {
    echo -e "${RED}Some dependencies failed to install (likely Python 3.13 compatibility)${NC}"
    echo -e "${YELLOW}Continuing with core dependencies...${NC}"
}

echo -e "${BLUE}Step 2: Starting backend API server...${NC}"

# Start backend in background
cd backend
python -m uvicorn app:app --host 0.0.0.0 --port $BACKEND_PORT &
BACKEND_PID=$!
cd ..

# Wait for backend to start
echo -e "${YELLOW}Waiting for backend to start...${NC}"
sleep 3

# Test backend health
if curl -s http://localhost:$BACKEND_PORT/api/v1/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend API started successfully on port $BACKEND_PORT${NC}"
else
    echo -e "${RED}❌ Backend API failed to start${NC}"
    exit 1
fi

echo -e "${BLUE}Step 3: Starting Godot game...${NC}"

# Start Godot game
echo -e "${YELLOW}Launching Godot game...${NC}"
godot --run-project . &
GODOT_PID=$!

echo -e "${GREEN}✅ Development environment fully operational!${NC}"
echo
echo -e "${BLUE}📊 Service Status:${NC}"
echo -e "  🔗 Backend API: ${GREEN}http://localhost:$BACKEND_PORT${NC}"
echo -e "  🎮 Godot Game: ${GREEN}Running (PID: $GODOT_PID)${NC}"
echo -e "  📚 API Docs: ${GREEN}http://localhost:$BACKEND_PORT/docs${NC}"
echo
echo -e "${BLUE}🔧 Useful endpoints:${NC}"
echo -e "  Health: ${YELLOW}curl http://localhost:$BACKEND_PORT/api/v1/health${NC}"
echo -e "  Stats: ${YELLOW}curl http://localhost:$BACKEND_PORT/api/v1/stats${NC}"
echo -e "  Player: ${YELLOW}curl http://localhost:$BACKEND_PORT/api/v1/players/player_001${NC}"
echo
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"

# Wait for processes
wait 