# app.py
# FastAPI backend application for Children of the Singularity
# Handles REST API endpoints for player persistence, inventory, and progression

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Optional
import logging
import json
from datetime import datetime
import os

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Children of the Singularity API",
    description="REST API for player persistence and game state management",
    version="1.0.0"
)

# Add CORS middleware for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this properly in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models for request/response validation
class PlayerData(BaseModel):
    player_id: str
    name: str
    credits: int
    progression_path: str
    position: Dict[str, float]
    upgrades: Dict[str, int]

class InventoryItem(BaseModel):
    item_id: str
    item_type: str
    quantity: int
    value: int
    timestamp: float

class ZoneData(BaseModel):
    zone_id: str
    player_id: str
    access_level: int
    last_visited: float

# In-memory storage for stub implementation
# TODO: Replace with actual PostgreSQL database
players_db: Dict[str, PlayerData] = {}
inventory_db: Dict[str, List[InventoryItem]] = {}
zones_db: Dict[str, List[ZoneData]] = {}

@app.on_event("startup")
async def startup_event():
    """Initialize the application on startup"""
    logger.info("Children of the Singularity API starting up...")
    
    # TODO: Initialize database connection
    logger.info("Database connection initialized (stub)")
    
    # Create default test data
    _create_test_data()
    
    logger.info("API server ready for requests")

def _create_test_data():
    """Create some test data for development"""
    logger.info("Creating test data...")
    
    # Create a test player
    test_player = PlayerData(
        player_id="player_001",
        name="Test Salvager",
        credits=100,
        progression_path="rogue",
        position={"x": 0.0, "y": 0.0},
        upgrades={"speed_boost": 0, "inventory_expansion": 0, "collection_efficiency": 0, "zone_access": 1}
    )
    
    players_db["player_001"] = test_player
    inventory_db["player_001"] = []
    
    logger.info("Test data created successfully")

@app.get("/")
async def root():
    """Root endpoint for health check"""
    return {
        "message": "Children of the Singularity API",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/v1/players/{player_id}")
async def get_player(player_id: str):
    """Get player data by ID"""
    logger.info(f"Fetching player data for: {player_id}")
    
    if player_id not in players_db:
        logger.warning(f"Player not found: {player_id}")
        raise HTTPException(status_code=404, detail="Player not found")
    
    player_data = players_db[player_id]
    logger.info(f"Retrieved player data: {player_data.name}, Credits: {player_data.credits}")
    
    return player_data

@app.post("/api/v1/players/{player_id}")
async def create_or_update_player(player_id: str, player_data: PlayerData):
    """Create or update player data"""
    logger.info(f"Creating/updating player: {player_id}")
    
    player_data.player_id = player_id  # Ensure ID matches URL
    players_db[player_id] = player_data
    
    # Initialize inventory if it doesn't exist
    if player_id not in inventory_db:
        inventory_db[player_id] = []
    
    logger.info(f"Player {player_id} saved successfully")
    return {"message": "Player saved successfully", "player_id": player_id}

@app.get("/api/v1/players/{player_id}/inventory")
async def get_player_inventory(player_id: str):
    """Get player inventory"""
    logger.info(f"Fetching inventory for player: {player_id}")
    
    if player_id not in players_db:
        logger.warning(f"Player not found: {player_id}")
        raise HTTPException(status_code=404, detail="Player not found")
    
    inventory = inventory_db.get(player_id, [])
    logger.info(f"Retrieved inventory: {len(inventory)} items")
    
    return {
        "player_id": player_id,
        "inventory": inventory,
        "total_items": len(inventory)
    }

@app.post("/api/v1/players/{player_id}/inventory")
async def add_inventory_item(player_id: str, item: InventoryItem):
    """Add item to player inventory"""
    logger.info(f"Adding item to inventory for player: {player_id}")
    
    if player_id not in players_db:
        logger.warning(f"Player not found: {player_id}")
        raise HTTPException(status_code=404, detail="Player not found")
    
    if player_id not in inventory_db:
        inventory_db[player_id] = []
    
    inventory_db[player_id].append(item)
    logger.info(f"Added {item.item_type} (quantity: {item.quantity}) to {player_id}'s inventory")
    
    return {"message": "Item added to inventory", "item": item}

@app.delete("/api/v1/players/{player_id}/inventory")
async def clear_player_inventory(player_id: str):
    """Clear player inventory (used when selling items)"""
    logger.info(f"Clearing inventory for player: {player_id}")
    
    if player_id not in players_db:
        logger.warning(f"Player not found: {player_id}")
        raise HTTPException(status_code=404, detail="Player not found")
    
    cleared_items = inventory_db.get(player_id, [])
    inventory_db[player_id] = []
    
    logger.info(f"Cleared {len(cleared_items)} items from {player_id}'s inventory")
    
    return {
        "message": "Inventory cleared",
        "cleared_items": cleared_items,
        "total_cleared": len(cleared_items)
    }

@app.post("/api/v1/players/{player_id}/credits")
async def update_player_credits(player_id: str, credits_change: int):
    """Update player credits (positive to add, negative to subtract)"""
    logger.info(f"Updating credits for player: {player_id}, change: {credits_change}")
    
    if player_id not in players_db:
        logger.warning(f"Player not found: {player_id}")
        raise HTTPException(status_code=404, detail="Player not found")
    
    player = players_db[player_id]
    old_credits = player.credits
    player.credits += credits_change
    
    # Ensure credits don't go below zero
    if player.credits < 0:
        player.credits = 0
    
    logger.info(f"Credits updated: {old_credits} -> {player.credits}")
    
    return {
        "message": "Credits updated",
        "old_credits": old_credits,
        "new_credits": player.credits,
        "change": credits_change
    }

@app.get("/api/v1/players/{player_id}/zones")
async def get_player_zones(player_id: str):
    """Get zones accessible to player"""
    logger.info(f"Fetching zones for player: {player_id}")
    
    if player_id not in players_db:
        logger.warning(f"Player not found: {player_id}")
        raise HTTPException(status_code=404, detail="Player not found")
    
    zones = zones_db.get(player_id, [])
    logger.info(f"Retrieved {len(zones)} zones for player {player_id}")
    
    return {
        "player_id": player_id,
        "zones": zones,
        "total_zones": len(zones)
    }

@app.get("/api/v1/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "players_count": len(players_db),
        "database_status": "connected (stub)"
    }

@app.get("/api/v1/stats")
async def get_stats():
    """Get API statistics"""
    total_inventory_items = sum(len(inventory) for inventory in inventory_db.values())
    total_zones = sum(len(zones) for zones in zones_db.values())
    
    return {
        "total_players": len(players_db),
        "total_inventory_items": total_inventory_items,
        "total_zones": total_zones,
        "timestamp": datetime.now().isoformat()
    }

if __name__ == "__main__":
    import uvicorn
    
    # Create logs directory if it doesn't exist
    os.makedirs("../logs", exist_ok=True)
    
    logger.info("Starting Children of the Singularity API server...")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info",
        access_log=True
    ) 