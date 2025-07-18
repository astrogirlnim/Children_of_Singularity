import json
import boto3
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Any

# Initialize S3 client
s3 = boto3.client("s3")

# Configuration - updated with actual bucket name
BUCKET_NAME = "children-of-singularity-releases"
LISTINGS_KEY = "trading/listings.json"
TRADES_KEY = "trading/completed_trades.json"


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for trading API
    Handles: GET /listings, POST /listings, POST /buy/{listing_id}
    """
    try:
        # Extract HTTP method and path
        method = event.get("httpMethod", "")
        path = event.get("path", "")
        path_parameters = event.get("pathParameters") or {}

        print(f"Processing {method} {path}")

        # Route requests
        if method == "GET" and path == "/listings":
            return get_active_listings()
        elif method == "POST" and path == "/listings":
            body = json.loads(event.get("body", "{}"))
            return create_listing(body)
        elif method == "POST" and path.startswith("/buy/"):
            listing_id = path_parameters.get("listing_id")
            body = json.loads(event.get("body", "{}"))
            return buy_listing(listing_id, body)
        elif method == "GET" and path.startswith("/history/"):
            player_id = path_parameters.get("player_id")
            return get_trade_history(player_id)
        else:
            return create_response(404, {"error": "Endpoint not found"})

    except Exception as e:
        print(f"Error: {str(e)}")
        return create_response(500, {"error": "Internal server error"})


def get_active_listings() -> Dict[str, Any]:
    """Get all active trading listings"""
    try:
        listings = load_from_s3(LISTINGS_KEY)

        # Filter for active listings only
        active_listings = [
            listing for listing in listings if listing.get("status") == "active"
        ]

        print(f"Retrieved {len(active_listings)} active listings")
        return create_response(
            200, {"listings": active_listings, "total": len(active_listings)}
        )

    except Exception as e:
        print(f"Error getting listings: {str(e)}")
        return create_response(500, {"error": "Failed to get listings"})


def create_listing(data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new trading listing"""
    try:
        # Validate required fields
        required_fields = [
            "seller_id",
            "seller_name",
            "item_type",
            "item_name",
            "quantity",
            "asking_price",
        ]
        for field in required_fields:
            if field not in data:
                return create_response(
                    400, {"error": f"Missing required field: {field}"}
                )

        # Create new listing
        listing = {
            "listing_id": str(uuid.uuid4()),
            "seller_id": data["seller_id"],
            "seller_name": data["seller_name"],
            "item_type": data["item_type"],
            "item_name": data["item_name"],
            "quantity": int(data["quantity"]),
            "asking_price": int(data["asking_price"]),
            "description": data.get("description", ""),
            "status": "active",
            "created_at": datetime.now(timezone.utc).isoformat(),
            "expires_at": None,  # Could add expiration logic later
        }

        # Load existing listings
        listings = load_from_s3(LISTINGS_KEY)

        # Add new listing
        listings.append(listing)

        # Save back to S3
        save_to_s3(LISTINGS_KEY, listings)

        print(f"Created listing {listing['listing_id']} for {listing['item_name']}")
        return create_response(201, {"success": True, "listing": listing})

    except Exception as e:
        print(f"Error creating listing: {str(e)}")
        return create_response(500, {"error": "Failed to create listing"})


def buy_listing(listing_id: str, buyer_data: Dict[str, Any]) -> Dict[str, Any]:
    """Purchase a trading listing"""
    try:
        if not listing_id:
            return create_response(400, {"error": "Missing listing ID"})

        # Validate buyer data
        if "buyer_id" not in buyer_data or "buyer_name" not in buyer_data:
            return create_response(400, {"error": "Missing buyer_id or buyer_name"})

        # Load current listings
        listings = load_from_s3(LISTINGS_KEY)

        # Find the listing
        listing_index = None
        target_listing = None

        for i, listing in enumerate(listings):
            if listing["listing_id"] == listing_id and listing["status"] == "active":
                listing_index = i
                target_listing = listing
                break

        if not target_listing:
            return create_response(404, {"error": "Listing not found or already sold"})

        # Prevent self-purchase
        if target_listing["seller_id"] == buyer_data["buyer_id"]:
            return create_response(400, {"error": "Cannot buy your own listing"})

        # Mark listing as sold
        listings[listing_index]["status"] = "sold"
        listings[listing_index]["buyer_id"] = buyer_data["buyer_id"]
        listings[listing_index]["buyer_name"] = buyer_data["buyer_name"]
        listings[listing_index]["sold_at"] = datetime.now(timezone.utc).isoformat()

        # Save updated listings
        save_to_s3(LISTINGS_KEY, listings)

        # Create completed trade record
        trade_record = {
            "trade_id": str(uuid.uuid4()),
            "listing_id": listing_id,
            "seller_id": target_listing["seller_id"],
            "seller_name": target_listing["seller_name"],
            "buyer_id": buyer_data["buyer_id"],
            "buyer_name": buyer_data["buyer_name"],
            "item_type": target_listing["item_type"],
            "item_name": target_listing["item_name"],
            "quantity": target_listing["quantity"],
            "final_price": target_listing["asking_price"],
            "completed_at": datetime.now(timezone.utc).isoformat(),
        }

        # Save trade record
        trades = load_from_s3(TRADES_KEY)
        trades.append(trade_record)
        save_to_s3(TRADES_KEY, trades)

        print(
            f"Completed trade {trade_record['trade_id']}: "
            f"{buyer_data['buyer_name']} bought {target_listing['item_name']}"
        )

        return create_response(
            200,
            {
                "success": True,
                "trade": trade_record,
                "item": {
                    "item_type": target_listing["item_type"],
                    "item_name": target_listing["item_name"],
                    "quantity": target_listing["quantity"],
                    "price_paid": target_listing["asking_price"],
                },
            },
        )

    except Exception as e:
        print(f"Error buying listing: {str(e)}")
        return create_response(500, {"error": "Failed to complete purchase"})


def get_trade_history(player_id: str) -> Dict[str, Any]:
    """Get trade history for a specific player"""
    try:
        if not player_id:
            return create_response(400, {"error": "Missing player ID"})

        trades = load_from_s3(TRADES_KEY)

        # Filter trades involving this player
        player_trades = [
            trade
            for trade in trades
            if trade.get("seller_id") == player_id or trade.get("buyer_id") == player_id
        ]

        # Sort by most recent first
        player_trades.sort(key=lambda x: x.get("completed_at", ""), reverse=True)

        print(f"Retrieved {len(player_trades)} trades for player {player_id}")
        return create_response(
            200, {"trades": player_trades, "total": len(player_trades)}
        )

    except Exception as e:
        print(f"Error getting trade history: {str(e)}")
        return create_response(500, {"error": "Failed to get trade history"})


def load_from_s3(key: str) -> List[Dict[str, Any]]:
    """Load JSON data from S3"""
    try:
        response = s3.get_object(Bucket=BUCKET_NAME, Key=key)
        content = response["Body"].read().decode("utf-8")
        return json.loads(content)
    except s3.exceptions.NoSuchKey:
        # File doesn't exist yet, return empty list
        print(f"S3 key {key} not found, returning empty list")
        return []
    except Exception as e:
        print(f"Error loading from S3: {str(e)}")
        return []


def save_to_s3(key: str, data: List[Dict[str, Any]]) -> None:
    """Save JSON data to S3"""
    try:
        json_content = json.dumps(data, indent=2, default=str)
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=key,
            Body=json_content.encode("utf-8"),
            ContentType="application/json",
        )
        print(f"Saved data to S3: {key}")
    except Exception as e:
        print(f"Error saving to S3: {str(e)}")
        raise


def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Create a properly formatted API Gateway response"""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": (
                "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            ),
            "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
        },
        "body": json.dumps(body, default=str),
    }
