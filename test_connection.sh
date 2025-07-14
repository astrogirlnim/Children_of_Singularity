#!/bin/bash

# Test script to verify backend API connectivity
echo "🔍 Testing Children of the Singularity API Connection"
echo "====================================================="

BACKEND_URL="http://localhost:8000"

echo "Testing backend API endpoints..."
echo

# Test health endpoint
echo "1. Health Check:"
curl -s "$BACKEND_URL/api/v1/health" | python3 -m json.tool 2>/dev/null || echo "❌ Health check failed"
echo

# Test stats endpoint  
echo "2. Game Stats:"
curl -s "$BACKEND_URL/api/v1/stats" | python3 -m json.tool 2>/dev/null || echo "❌ Stats check failed"
echo

# Test player data
echo "3. Player Data:"
curl -s "$BACKEND_URL/api/v1/players/player_001" | python3 -m json.tool 2>/dev/null || echo "❌ Player data failed"
echo

echo "✅ API connection tests complete!"
echo
echo "🔗 Architecture Overview:"
echo "  Frontend (Godot) ←→ Backend (FastAPI)"
echo "  Game logic ←→ Player data, AI, persistence" 