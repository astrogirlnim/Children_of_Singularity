# app.py
# FastAPI backend application for Children of the Singularity
# Handles REST API endpoints for player persistence, inventory, and progression

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any
import logging
from datetime import datetime
import os
import psycopg
from psycopg.rows import dict_row
from contextlib import contextmanager

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Children of the Singularity API",
    description="REST API for player persistence and game state management",
    version="1.0.0",
)

# Add CORS middleware for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this properly in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database configuration
DATABASE_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": os.getenv("DB_NAME", "children_of_singularity"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"),
    "port": os.getenv("DB_PORT", "5432"),
}


# Database connection management
@contextmanager
def get_db_connection():
    """Get database connection with proper error handling"""
    conn = None
    try:
        # Construct connection string for psycopg3
        conn_string = (
            f"host={DATABASE_CONFIG['host']} "
            f"dbname={DATABASE_CONFIG['database']} "
            f"user={DATABASE_CONFIG['user']} "
            f"password={DATABASE_CONFIG['password']} "
            f"port={DATABASE_CONFIG['port']}"
        )
        conn = psycopg.connect(conn_string, row_factory=dict_row)
        yield conn
    except psycopg.Error as e:
        logger.error(f"Database connection error: {e}")
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail="Database connection failed")
    finally:
        if conn:
            conn.close()


def initialize_database():
    """Initialize database with schema if it doesn't exist"""
    logger.info("Initializing database...")

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Read and execute schema
                schema_path = "../data/postgres/schema.sql"
                if os.path.exists(schema_path):
                    with open(schema_path, "r") as f:
                        schema_sql = f.read()
                    cursor.execute(schema_sql)
                    conn.commit()
                    logger.info("Database schema initialized successfully")
                else:
                    logger.warning("Schema file not found, creating basic tables")
                    # Create basic tables if schema file doesn't exist
                    cursor.execute(
                        """
                        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
                        CREATE TABLE IF NOT EXISTS players (
                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                            name VARCHAR(255) NOT NULL,
                            credits INTEGER NOT NULL DEFAULT 0,
                            progression_path VARCHAR(50) NOT NULL
                                DEFAULT 'rogue',
                            position_x FLOAT NOT NULL DEFAULT 0.0,
                            position_y FLOAT NOT NULL DEFAULT 0.0,
                            position_z FLOAT NOT NULL DEFAULT 0.0,
                            created_at TIMESTAMP WITH TIME ZONE DEFAULT
                                CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP WITH TIME ZONE DEFAULT
                                CURRENT_TIMESTAMP
                        );
                    """
                    )
                    conn.commit()
                    logger.info("Basic database tables created")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        # Continue without database for development
        logger.info("Continuing with fallback mode...")


# Pydantic models for request/response validation
class PlayerData(BaseModel):
    player_id: str
    name: str
    credits: int
    progression_path: str
    position: Dict[str, float]  # 3D coordinates: x, y, z (z added for 2.5D support)
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


# In-memory storage for fallback when database is unavailable
players_db: Dict[str, PlayerData] = {}
inventory_db: Dict[str, List[dict[str, Any]]] = {}
zones_db: Dict[str, List[dict[str, Any]]] = {}


@app.on_event("startup")
async def startup_event():
    """Initialize the application on startup"""
    logger.info("Children of the Singularity API starting up...")

    # Validate database configuration
    if not DATABASE_CONFIG["password"]:
        logger.error(
            "DB_PASSWORD environment variable not set. "
            "Database connection requires a password."
        )
        logger.error(
            "Please set DB_PASSWORD environment variable for " "secure database access."
        )
        logger.info("Continuing with fallback mode...")
    else:
        logger.info("Database configuration validated")

    # Try to initialize database
    initialize_database()

    # Create default test data
    _create_test_data()

    logger.info("API server ready for requests")


def _create_test_data():
    """Create some test data for development"""
    logger.info("Creating test data...")

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Check if test player exists
                cursor.execute(
                    "SELECT id FROM players WHERE name = %s",
                    ("Test Salvager",),
                )
                if not cursor.fetchone():
                    # Create test player
                    cursor.execute(
                        """
                        INSERT INTO players (name, credits, progression_path,
                                           position_x, position_y, position_z)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        RETURNING id
                    """,
                        ("Test Salvager", 100, "rogue", 0.0, 0.0, 0.0),
                    )

                    player_id = cursor.fetchone()["id"]

                    # Create initial upgrades for test player (skip if exist)
                    cursor.execute(
                        """
                        INSERT INTO upgrades (player_id, upgrade_type, level)
                        VALUES
                        (%s, 'speed_boost', 0),
                        (%s, 'inventory_expansion', 0),
                        (%s, 'collection_efficiency', 0),
                        (%s, 'zone_access', 1)
                        ON CONFLICT (player_id, upgrade_type) DO NOTHING
                    """,
                        (player_id, player_id, player_id, player_id),
                    )

                    conn.commit()
                    logger.info("Test data created in database")
    except Exception as e:
        logger.error(f"Database test data creation failed: {e}")
        # Fall back to in-memory storage
        test_player = PlayerData(
            player_id="player_001",
            name="Test Salvager",
            credits=100,
            progression_path="rogue",
            position={"x": 0.0, "y": 0.0},
            upgrades={
                "speed_boost": 0,
                "inventory_expansion": 0,
                "collection_efficiency": 0,
                "zone_access": 1,
            },
        )
        players_db["player_001"] = test_player
        inventory_db["player_001"] = []
        logger.info("Test data created in memory (fallback)")


@app.get("/")
async def root():
    """Root endpoint for health check"""
    return {
        "message": "Children of the Singularity API",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.now().isoformat(),
    }


@app.get("/api/v1/players/{player_id}")
async def get_player(player_id: str):
    """Get player data by ID"""
    logger.info(f"Fetching player data for: {player_id}")

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Get player data
                cursor.execute(
                    """
                    SELECT id, name, credits, progression_path, position_x,
                           position_y, position_z, created_at, updated_at
                    FROM players WHERE id = %s
                """,
                    (player_id,),
                )

                player_row = cursor.fetchone()
                if not player_row:
                    logger.warning(f"Player not found: {player_id}")
                    raise HTTPException(status_code=404, detail="Player not found")

                # Get player upgrades
                cursor.execute(
                    """
                    SELECT upgrade_type, level FROM upgrades
                    WHERE player_id = %s
                """,
                    (player_id,),
                )

                upgrades = {
                    row["upgrade_type"]: row["level"] for row in cursor.fetchall()
                }

                player_data = {
                    "player_id": str(player_row["id"]),
                    "name": player_row["name"],
                    "credits": player_row["credits"],
                    "progression_path": player_row["progression_path"],
                    "position": {
                        "x": player_row["position_x"],
                        "y": player_row["position_y"],
                        "z": player_row["position_z"],
                    },
                    "upgrades": upgrades,
                }

                logger.info(
                    f"Retrieved player data: {player_data['name']}, "
                    f"Credits: {player_data['credits']}"
                )
                return player_data

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Database error getting player: {e}")
        # Fall back to in-memory storage
        if player_id in players_db:
            return players_db[player_id]
        else:
            raise HTTPException(status_code=404, detail="Player not found")


@app.post("/api/v1/players/{player_id}")
async def create_or_update_player(player_id: str, player_data: PlayerData):
    """Create or update player data"""
    logger.info(f"Creating/updating player: {player_id}")

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Check if player exists
                cursor.execute("SELECT id FROM players WHERE id = %s", (player_id,))
                exists = cursor.fetchone()

                if exists:
                    # Update existing player
                    cursor.execute(
                        """
                        UPDATE players
                        SET name = %s, credits = %s, progression_path = %s,
                            position_x = %s, position_y = %s, position_z = %s,
                            updated_at = CURRENT_TIMESTAMP
                        WHERE id = %s
                    """,
                        (
                            player_data.name,
                            player_data.credits,
                            player_data.progression_path,
                            player_data.position.get("x", 0.0),
                            player_data.position.get("y", 0.0),
                            player_data.position.get("z", 0.0),
                            player_id,
                        ),
                    )
                    logger.info(f"Updated existing player: {player_id}")
                else:
                    # Create new player
                    cursor.execute(
                        """
                        INSERT INTO players (id, name, credits,
                                           progression_path,
                                           position_x, position_y, position_z)
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                        (
                            player_id,
                            player_data.name,
                            player_data.credits,
                            player_data.progression_path,
                            player_data.position.get("x", 0.0),
                            player_data.position.get("y", 0.0),
                            player_data.position.get("z", 0.0),
                        ),
                    )
                    logger.info(f"Created new player: {player_id}")

                # Update upgrades
                for upgrade_type, level in player_data.upgrades.items():
                    cursor.execute(
                        """
                        INSERT INTO upgrades (player_id, upgrade_type, level)
                        VALUES (%s, %s, %s)
                        ON CONFLICT (player_id, upgrade_type)
                        DO UPDATE SET level = EXCLUDED.level,
                                      updated_at = CURRENT_TIMESTAMP
                    """,
                        (player_id, upgrade_type, level),
                    )

                conn.commit()
                logger.info(f"Player {player_id} saved successfully")
                return {
                    "message": "Player saved successfully",
                    "player_id": player_id,
                }

    except Exception as e:
        logger.error(f"Database error saving player: {e}")
        # Fall back to in-memory storage
        player_data.player_id = player_id
        players_db[player_id] = player_data
        if player_id not in inventory_db:
            inventory_db[player_id] = []
        return {
            "message": "Player saved successfully (fallback)",
            "player_id": player_id,
        }


@app.get("/api/v1/players/{player_id}/inventory")
async def get_player_inventory(player_id: str):
    """Get player inventory"""
    logger.info(f"Fetching inventory for player: {player_id}")

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Check if player exists
                cursor.execute("SELECT id FROM players WHERE id = %s", (player_id,))
                if not cursor.fetchone():
                    logger.warning(f"Player not found: {player_id}")
                    raise HTTPException(status_code=404, detail="Player not found")

                # Get inventory items
                cursor.execute(
                    """
                    SELECT item_id, item_type, quantity, value,
                           EXTRACT(EPOCH FROM created_at) as timestamp
                    FROM inventory WHERE player_id = %s
                """,
                    (player_id,),
                )

                inventory = []
                for row in cursor.fetchall():
                    inventory.append(
                        {
                            "item_id": row["item_id"],
                            "item_type": row["item_type"],
                            "quantity": row["quantity"],
                            "value": row["value"],
                            "timestamp": row["timestamp"],
                        }
                    )

                logger.info(f"Retrieved inventory: {len(inventory)} items")
                return {
                    "player_id": player_id,
                    "inventory": inventory,
                    "total_items": len(inventory),
                }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Database error getting inventory: {e}")
        # Fall back to in-memory storage
        if player_id not in players_db:
            raise HTTPException(status_code=404, detail="Player not found")

        inventory = inventory_db.get(player_id, [])
        return {
            "player_id": player_id,
            "inventory": inventory,
            "total_items": len(inventory),
        }


@app.post("/api/v1/players/{player_id}/inventory")
async def add_inventory_item(player_id: str, item: InventoryItem):
    """Add item to player inventory"""
    logger.info(f"Adding item to inventory for player: {player_id}")

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Check if player exists
                cursor.execute("SELECT id FROM players WHERE id = %s", (player_id,))
                if not cursor.fetchone():
                    logger.warning(f"Player not found: {player_id}")
                    raise HTTPException(status_code=404, detail="Player not found")

                # Add item to inventory
                cursor.execute(
                    """
                    INSERT INTO inventory (player_id, item_id, item_type,
                                          quantity, value)
                    VALUES (%s, %s, %s, %s, %s)
                """,
                    (
                        player_id,
                        item.item_id,
                        item.item_type,
                        item.quantity,
                        item.value,
                    ),
                )

                conn.commit()
                logger.info(
                    f"Added {item.item_type} (quantity: {item.quantity}) to "
                    + f"{player_id}'s inventory"
                )
                return {"message": "Item added to inventory", "item": item}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Database error adding inventory item: {e}")
        # Fall back to in-memory storage
        if player_id not in players_db:
            raise HTTPException(status_code=404, detail="Player not found")

        if player_id not in inventory_db:
            inventory_db[player_id] = []

        inventory_db[player_id].append(item.model_dump())
        return {"message": "Item added to inventory (fallback)", "item": item}


@app.delete("/api/v1/players/{player_id}/inventory")
async def clear_player_inventory(player_id: str):
    """Clear player inventory (used when selling items)"""
    logger.info(f"Clearing inventory for player: {player_id}")

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Check if player exists
                cursor.execute("SELECT id FROM players WHERE id = %s", (player_id,))
                if not cursor.fetchone():
                    logger.warning(f"Player not found: {player_id}")
                    raise HTTPException(status_code=404, detail="Player not found")

                # Get items before clearing
                cursor.execute(
                    """
                    SELECT item_id, item_type, quantity, value,
                           EXTRACT(EPOCH FROM created_at) as timestamp
                    FROM inventory WHERE player_id = %s
                """,
                    (player_id,),
                )

                cleared_items = []
                for row in cursor.fetchall():
                    cleared_items.append(
                        {
                            "item_id": row["item_id"],
                            "item_type": row["item_type"],
                            "quantity": row["quantity"],
                            "value": row["value"],
                            "timestamp": row["timestamp"],
                        }
                    )

                # Clear inventory
                cursor.execute(
                    "DELETE FROM inventory WHERE player_id = %s", (player_id,)
                )
                conn.commit()

                logger.info(
                    f"Cleared {len(cleared_items)} items from "
                    f"{player_id}'s inventory"
                )
                return {
                    "message": "Inventory cleared",
                    "cleared_items": cleared_items,
                    "total_cleared": len(cleared_items),
                }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Database error clearing inventory: {e}")
        # Fall back to in-memory storage
        if player_id not in players_db:
            raise HTTPException(status_code=404, detail="Player not found")

        cleared_items = inventory_db.get(player_id, [])
        inventory_db[player_id] = []

        return {
            "message": "Inventory cleared (fallback)",
            "cleared_items": cleared_items,
            "total_cleared": len(cleared_items),
        }


@app.post("/api/v1/players/{player_id}/credits")
async def update_player_credits(player_id: str, credits_change: int):
    """Update player credits (positive to add, negative to subtract)"""
    logger.info(f"Updating credits for player: {player_id}, change: {credits_change}")

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Get current credits
                cursor.execute(
                    "SELECT credits FROM players WHERE id = %s", (player_id,)
                )
                result = cursor.fetchone()
                if not result:
                    logger.warning(f"Player not found: {player_id}")
                    raise HTTPException(status_code=404, detail="Player not found")

                old_credits = result["credits"]
                new_credits = max(
                    0, old_credits + credits_change
                )  # Ensure credits don't go below zero

                # Update credits
                cursor.execute(
                    """
                    UPDATE players SET credits = %s,
                           updated_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                """,
                    (new_credits, player_id),
                )

                conn.commit()
                logger.info(f"Credits updated: {old_credits} -> {new_credits}")

                return {
                    "message": "Credits updated",
                    "old_credits": old_credits,
                    "new_credits": new_credits,
                    "change": credits_change,
                }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Database error updating credits: {e}")
        # Fall back to in-memory storage
        if player_id not in players_db:
            raise HTTPException(status_code=404, detail="Player not found")

        player = players_db[player_id]
        old_credits = player.credits
        player.credits = max(0, old_credits + credits_change)

        return {
            "message": "Credits updated (fallback)",
            "old_credits": old_credits,
            "new_credits": player.credits,
            "change": credits_change,
        }


@app.get("/api/v1/players/{player_id}/zones")
async def get_player_zones(player_id: str):
    """Get zones accessible to player"""
    logger.info(f"Fetching zones for player: {player_id}")

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Check if player exists
                cursor.execute("SELECT id FROM players WHERE id = %s", (player_id,))
                if not cursor.fetchone():
                    logger.warning(f"Player not found: {player_id}")
                    raise HTTPException(status_code=404, detail="Player not found")

                # Get accessible zones
                cursor.execute(
                    """
                    SELECT zone_id, access_level,
                           EXTRACT(EPOCH FROM last_visited) as last_visited
                    FROM zones WHERE player_id = %s
                """,
                    (player_id,),
                )

                zones = []
                for row in cursor.fetchall():
                    zones.append(
                        {
                            "zone_id": row["zone_id"],
                            "player_id": player_id,
                            "access_level": row["access_level"],
                            "last_visited": row["last_visited"],
                        }
                    )

                logger.info(f"Retrieved {len(zones)} zones for player {player_id}")
                return {
                    "player_id": player_id,
                    "zones": zones,
                    "total_zones": len(zones),
                }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Database error getting zones: {e}")
        # Fall back to in-memory storage
        if player_id not in players_db:
            raise HTTPException(status_code=404, detail="Player not found")

        zones = zones_db.get(player_id, [])
        return {
            "player_id": player_id,
            "zones": zones,
            "total_zones": len(zones),
        }


@app.get("/api/v1/health")
async def health_check():
    """Health check endpoint"""
    db_status = "connected"
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        db_status = "disconnected (using fallback)"

    players_count = len(players_db)
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) FROM players")
                players_count = cursor.fetchone()[0]
    except Exception:
        pass

    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "players_count": players_count,
        "database_status": db_status,
    }


@app.get("/api/v1/stats")
async def get_stats():
    """Get API statistics"""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Get player count
                cursor.execute("SELECT COUNT(*) as count FROM players")
                total_players = cursor.fetchone()["count"]

                # Get inventory item count
                cursor.execute("SELECT COUNT(*) as count FROM inventory")
                total_inventory_items = cursor.fetchone()["count"]

                # Get zone count
                cursor.execute("SELECT COUNT(*) as count FROM zones")
                total_zones = cursor.fetchone()["count"]

                return {
                    "total_players": total_players,
                    "total_inventory_items": total_inventory_items,
                    "total_zones": total_zones,
                    "timestamp": datetime.now().isoformat(),
                }

    except Exception as e:
        logger.error(f"Database error getting stats: {e}")
        # Fall back to in-memory storage
        total_inventory_items = sum(
            len(inventory) for inventory in inventory_db.values()
        )
        total_zones = sum(len(zones) for zones in zones_db.values())

        return {
            "total_players": len(players_db),
            "total_inventory_items": total_inventory_items,
            "total_zones": total_zones,
            "timestamp": datetime.now().isoformat(),
        }


if __name__ == "__main__":
    import uvicorn

    # Create logs directory if it doesn't exist
    os.makedirs("../logs", exist_ok=True)

    logger.info("Starting Children of the Singularity API server...")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info", access_log=True)
