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


class UpgradePurchaseRequest(BaseModel):
    upgrade_type: str
    expected_cost: int


class UpgradePurchaseResponse(BaseModel):
    success: bool
    new_level: int
    cost: int
    remaining_credits: int
    error_message: str = ""


# Upgrade definitions matching the client-side UpgradeSystem.gd
UPGRADE_DEFINITIONS = {
    "speed_boost": {
        "name": "Speed Boost",
        "description": "Increases ship movement speed",
        "max_level": 5,
        "base_cost": 100,
        "cost_multiplier": 1.5,
        "effect_per_level": 50.0,
        "category": "movement",
    },
    "inventory_expansion": {
        "name": "Inventory Expansion",
        "description": "Increases inventory capacity",
        "max_level": 10,
        "base_cost": 200,
        "cost_multiplier": 1.3,
        "effect_per_level": 5,
        "category": "inventory",
    },
    "collection_efficiency": {
        "name": "Collection Efficiency",
        "description": "Increases collection range and speed",
        "max_level": 5,
        "base_cost": 150,
        "cost_multiplier": 1.4,
        "effect_per_level": 20.0,
        "category": "collection",
    },
    "zone_access": {
        "name": "Zone Access",
        "description": "Unlocks access to deeper zones",
        "max_level": 5,
        "base_cost": 500,
        "cost_multiplier": 2.0,
        "effect_per_level": 1,
        "category": "access",
    },
    "debris_scanner": {
        "name": "Debris Scanner",
        "description": "Highlights valuable debris on the map",
        "max_level": 3,
        "base_cost": 300,
        "cost_multiplier": 1.6,
        "effect_per_level": 1,
        "category": "utility",
    },
    "cargo_magnet": {
        "name": "Cargo Magnet",
        "description": "Automatically attracts nearby debris",
        "max_level": 3,
        "base_cost": 400,
        "cost_multiplier": 1.7,
        "effect_per_level": 1,
        "category": "collection",
    },
}


def calculate_upgrade_cost(upgrade_type: str, current_level: int) -> int:
    """Calculate the cost to upgrade to the next level"""
    if upgrade_type not in UPGRADE_DEFINITIONS:
        return -1

    upgrade_data = UPGRADE_DEFINITIONS[upgrade_type]
    base_cost = upgrade_data["base_cost"]
    cost_multiplier = upgrade_data["cost_multiplier"]

    # Cost increases exponentially with level
    cost = int(base_cost * (cost_multiplier**current_level))
    logger.info(
        f"Calculated upgrade cost for {upgrade_type} level {current_level}: {cost}"
    )
    return cost


def validate_upgrade_purchase(
    upgrade_type: str, current_level: int, player_credits: int, expected_cost: int
) -> tuple[bool, str]:
    """Validate if upgrade purchase is possible"""
    logger.info(
        f"Validating upgrade purchase: {upgrade_type}, level {current_level}, "
        f"credits {player_credits}, expected cost {expected_cost}"
    )

    # Check if upgrade type exists
    if upgrade_type not in UPGRADE_DEFINITIONS:
        return False, f"Unknown upgrade type: {upgrade_type}"

    upgrade_data = UPGRADE_DEFINITIONS[upgrade_type]
    max_level = upgrade_data["max_level"]

    # Check if already at max level
    if current_level >= max_level:
        return (
            False,
            f"Upgrade {upgrade_type} is already at maximum level ({max_level})",
        )

    # Calculate actual cost
    actual_cost = calculate_upgrade_cost(upgrade_type, current_level)

    # Validate expected cost matches actual cost (client-side validation)
    if expected_cost != actual_cost:
        logger.warning(
            f"Cost mismatch for {upgrade_type}: expected {expected_cost}, actual {actual_cost}"
        )
        # Still allow purchase but use actual cost

    # Check if player has enough credits
    if player_credits < actual_cost:
        return False, f"Insufficient credits. Need {actual_cost}, have {player_credits}"

    return True, ""


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


@app.post("/api/v1/players/{player_id}/upgrades/purchase")
async def purchase_upgrade(player_id: str, upgrade_data: UpgradePurchaseRequest):
    """Purchase an upgrade for a player"""
    logger.info(
        f"Processing upgrade purchase for player {player_id}: "
        f"{upgrade_data.upgrade_type} (expected cost: {upgrade_data.expected_cost})"
    )

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Begin transaction for atomic upgrade purchase
                cursor.execute("BEGIN")

                try:
                    # Get current player data with row lock to prevent concurrent modifications
                    cursor.execute(
                        """
                        SELECT id, name, credits FROM players
                        WHERE id = %s FOR UPDATE
                        """,
                        (player_id,),
                    )

                    player_row = cursor.fetchone()
                    if not player_row:
                        logger.warning(f"Player not found: {player_id}")
                        raise HTTPException(status_code=404, detail="Player not found")

                    current_credits = player_row["credits"]
                    logger.info(
                        f"Player {player_row['name']} has {current_credits} credits"
                    )

                    # Get current upgrade level
                    cursor.execute(
                        """
                        SELECT level FROM upgrades
                        WHERE player_id = %s AND upgrade_type = %s
                        """,
                        (player_id, upgrade_data.upgrade_type),
                    )

                    upgrade_row = cursor.fetchone()
                    current_level = upgrade_row["level"] if upgrade_row else 0
                    logger.info(
                        f"Current {upgrade_data.upgrade_type} level: {current_level}"
                    )

                    # Validate the purchase
                    is_valid, error_message = validate_upgrade_purchase(
                        upgrade_data.upgrade_type,
                        current_level,
                        current_credits,
                        upgrade_data.expected_cost,
                    )

                    if not is_valid:
                        logger.warning(
                            f"Upgrade purchase validation failed: {error_message}"
                        )
                        cursor.execute("ROLLBACK")
                        return UpgradePurchaseResponse(
                            success=False,
                            new_level=current_level,
                            cost=0,
                            remaining_credits=current_credits,
                            error_message=error_message,
                        )

                    # Calculate actual cost (use actual cost, not expected cost)
                    actual_cost = calculate_upgrade_cost(
                        upgrade_data.upgrade_type, current_level
                    )
                    new_level = current_level + 1
                    new_credits = current_credits - actual_cost

                    logger.info(
                        f"Processing upgrade: cost={actual_cost}, new_level={new_level}, "
                        f"remaining_credits={new_credits}"
                    )

                    # Update player credits
                    cursor.execute(
                        """
                        UPDATE players
                        SET credits = %s, updated_at = CURRENT_TIMESTAMP
                        WHERE id = %s
                        """,
                        (new_credits, player_id),
                    )

                    # Update or insert upgrade level
                    cursor.execute(
                        """
                        INSERT INTO upgrades (player_id, upgrade_type, level)
                        VALUES (%s, %s, %s)
                        ON CONFLICT (player_id, upgrade_type)
                        DO UPDATE SET
                            level = EXCLUDED.level,
                            updated_at = CURRENT_TIMESTAMP
                        """,
                        (player_id, upgrade_data.upgrade_type, new_level),
                    )

                    # Commit transaction
                    cursor.execute("COMMIT")

                    logger.info(
                        f"Upgrade purchased successfully: {upgrade_data.upgrade_type} "
                        f"level {new_level} for {actual_cost} credits"
                    )

                    return UpgradePurchaseResponse(
                        success=True,
                        new_level=new_level,
                        cost=actual_cost,
                        remaining_credits=new_credits,
                        error_message="",
                    )

                except Exception as e:
                    cursor.execute("ROLLBACK")
                    logger.error(f"Transaction error during upgrade purchase: {e}")
                    raise e

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Database error during upgrade purchase: {e}")

        # Fall back to in-memory storage
        if player_id not in players_db:
            raise HTTPException(status_code=404, detail="Player not found")

        player = players_db[player_id]
        current_level = player.upgrades.get(upgrade_data.upgrade_type, 0)

        # Validate the purchase using fallback data
        is_valid, error_message = validate_upgrade_purchase(
            upgrade_data.upgrade_type,
            current_level,
            player.credits,
            upgrade_data.expected_cost,
        )

        if not is_valid:
            return UpgradePurchaseResponse(
                success=False,
                new_level=current_level,
                cost=0,
                remaining_credits=player.credits,
                error_message=error_message,
            )

        # Process purchase in memory
        actual_cost = calculate_upgrade_cost(upgrade_data.upgrade_type, current_level)
        new_level = current_level + 1
        player.credits -= actual_cost
        player.upgrades[upgrade_data.upgrade_type] = new_level

        logger.info(
            f"Upgrade purchased in fallback mode: {upgrade_data.upgrade_type} level {new_level}"
        )

        return UpgradePurchaseResponse(
            success=True,
            new_level=new_level,
            cost=actual_cost,
            remaining_credits=player.credits,
            error_message="",
        )


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
