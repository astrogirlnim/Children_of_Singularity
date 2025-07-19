import json
import boto3
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Any
from botocore.exceptions import ClientError

# Initialize S3 client
s3 = boto3.client("s3")

# Configuration - updated with actual bucket name
BUCKET_NAME = "children-of-singularity-releases"
LISTINGS_KEY = "trading/listings.json"
TRADES_KEY = "trading/completed_trades.json"


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for trading API
    Handles: GET /listings, POST /listings,
    POST /listings/{listing_id}/buy, GET /history/{player_id}
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
        elif method == "POST" and "/buy" in path:
            # Handle both /buy/{listing_id} and /listings/{listing_id}/buy patterns
            listing_id = path_parameters.get("listing_id") or path_parameters.get("id")
            if not listing_id:
                # Try to extract from path
                import re

                match = re.search(r"/([\w\-]+)/buy", path)
                if match:
                    listing_id = match.group(1)
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
        listings = load_from_s3(LISTINGS_KEY)[0]  # Only data, ignore ETag for reads

        # Filter only active listings
        active_listings = [
            listing for listing in listings if listing.get("status") == "active"
        ]

        # Sort by creation date (newest first)
        active_listings.sort(key=lambda x: x.get("created_at", ""), reverse=True)

        return create_response(
            200, {"listings": active_listings, "total": len(active_listings)}
        )

    except Exception as e:
        print(f"Error getting listings: {str(e)}")
        return create_response(500, {"error": "Failed to fetch listings"})


def create_listing(listing_data: Dict[str, Any]) -> Dict[str, Any]:
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
            if field not in listing_data:
                return create_response(400, {"error": f"Missing field: {field}"})

        # Validate data types and values
        if (
            not isinstance(listing_data.get("quantity"), int)
            or listing_data["quantity"] <= 0
        ):
            return create_response(
                400, {"error": "Quantity must be a positive integer"}
            )

        if (
            not isinstance(listing_data.get("asking_price"), int)
            or listing_data["asking_price"] <= 0
        ):
            return create_response(
                400, {"error": "Asking price must be a positive integer"}
            )

        # Create listing object
        listing = {
            "listing_id": str(uuid.uuid4()),
            "seller_id": listing_data["seller_id"],
            "seller_name": listing_data["seller_name"],
            "item_type": listing_data["item_type"],
            "item_name": listing_data["item_name"],
            "quantity": listing_data["quantity"],
            "asking_price": listing_data["asking_price"],
            "description": listing_data.get("description", ""),
            "status": "active",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }

        # Add to listings with retry on concurrent writes
        max_retries = 3
        for attempt in range(max_retries):
            try:
                listings, etag = load_from_s3(LISTINGS_KEY)
                listings.append(listing)
                save_to_s3_with_etag(LISTINGS_KEY, listings, etag)
                break
            except ClientError as e:
                if (
                    e.response["Error"]["Code"] == "PreconditionFailed"
                    and attempt < max_retries - 1
                ):
                    print(f"Concurrent write detected, retrying attempt {attempt + 1}")
                    continue
                else:
                    raise e

        print(
            f"Created listing {listing['listing_id']}: "
            f"{listing['item_name']} for {listing['asking_price']} credits"
        )

        return create_response(201, {"success": True, "listing": listing})

    except Exception as e:
        print(f"Error creating listing: {str(e)}")
        return create_response(500, {"error": "Failed to create listing"})


def buy_listing(listing_id: str, buyer_data: Dict[str, Any]) -> Dict[str, Any]:
    """Purchase a trading listing with concurrency protection"""
    try:
        if not listing_id:
            return create_response(400, {"error": "Missing listing ID"})

        # Validate buyer data
        if "buyer_id" not in buyer_data or "buyer_name" not in buyer_data:
            return create_response(400, {"error": "Missing buyer_id or buyer_name"})

        # Implement optimistic locking with retries
        max_retries = 3
        for attempt in range(max_retries):
            try:
                # Load current listings with ETag
                listings, etag = load_from_s3(LISTINGS_KEY)

                # Find the listing
                listing_index = None
                target_listing = None

                for i, listing in enumerate(listings):
                    if (
                        listing["listing_id"] == listing_id
                        and listing["status"] == "active"
                    ):
                        listing_index = i
                        target_listing = listing
                        break

                if not target_listing:
                    return create_response(
                        404, {"error": "Listing not found or already sold"}
                    )

                # Prevent self-purchase
                if target_listing["seller_id"] == buyer_data["buyer_id"]:
                    return create_response(
                        400, {"error": "Cannot buy your own listing"}
                    )

                # Validate expected price if provided (prevents price changes during purchase)
                if "expected_price" in buyer_data:
                    if target_listing["asking_price"] != buyer_data["expected_price"]:
                        return create_response(
                            409,
                            {
                                "error": "Price changed",
                                "current_price": target_listing["asking_price"],
                                "expected_price": buyer_data["expected_price"],
                            },
                        )

                # Mark listing as sold
                listings[listing_index]["status"] = "sold"
                listings[listing_index]["buyer_id"] = buyer_data["buyer_id"]
                listings[listing_index]["buyer_name"] = buyer_data["buyer_name"]
                listings[listing_index]["sold_at"] = datetime.now(
                    timezone.utc
                ).isoformat()

                # Save updated listings with ETag check (atomic operation)
                save_to_s3_with_etag(LISTINGS_KEY, listings, etag)

                # If we get here, the atomic write succeeded
                break

            except ClientError as e:
                if e.response["Error"]["Code"] == "PreconditionFailed":
                    if attempt < max_retries - 1:
                        print(
                            f"Concurrent purchase detected, retrying attempt {attempt + 1}"
                        )
                        continue
                    else:
                        return create_response(
                            409, {"error": "Item was purchased by another player"}
                        )
                else:
                    raise e

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

        # Save trade record (with retry for concurrent writes)
        max_retries = 3
        for attempt in range(max_retries):
            try:
                trades, trades_etag = load_from_s3(TRADES_KEY)
                trades.append(trade_record)
                save_to_s3_with_etag(TRADES_KEY, trades, trades_etag)
                break
            except ClientError as e:
                if (
                    e.response["Error"]["Code"] == "PreconditionFailed"
                    and attempt < max_retries - 1
                ):
                    print(f"Concurrent trade logging, retrying attempt {attempt + 1}")
                    continue
                else:
                    # Trade completed but logging failed - not critical
                    print(f"Warning: Trade completed but logging failed: {str(e)}")
                    break

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

        trades = load_from_s3(TRADES_KEY)[0]  # Only data, ignore ETag for reads

        # Filter trades involving this player
        player_trades = [
            trade
            for trade in trades
            if trade.get("seller_id") == player_id or trade.get("buyer_id") == player_id
        ]

        # Sort by most recent first
        player_trades.sort(key=lambda x: x.get("completed_at", ""), reverse=True)

        return create_response(
            200, {"trades": player_trades, "total": len(player_trades)}
        )

    except Exception as e:
        print(f"Error getting trade history: {str(e)}")
        return create_response(500, {"error": "Failed to fetch trade history"})


def load_from_s3(key: str) -> tuple[List[Dict[str, Any]], str]:
    """Load JSON data from S3 with ETag for optimistic locking"""
    try:
        response = s3.get_object(Bucket=BUCKET_NAME, Key=key)
        content = response["Body"].read().decode("utf-8")
        etag = response["ETag"].strip('"')  # Remove quotes from ETag
        data = json.loads(content)
        print(f"Loaded from S3: {key} (ETag: {etag})")
        return data, etag
    except s3.exceptions.NoSuchKey:
        # File doesn't exist yet, return empty list with no ETag
        print(f"S3 key {key} not found, returning empty list")
        return [], None
    except Exception as e:
        print(f"Error loading from S3: {str(e)}")
        return [], None


def save_to_s3_with_etag(
    key: str, data: List[Dict[str, Any]], expected_etag: str = None
) -> None:
    """Save JSON data to S3 with ETag conditional write"""
    try:
        json_content = json.dumps(data, indent=2, default=str)

        # Prepare put_object parameters
        put_params = {
            "Bucket": BUCKET_NAME,
            "Key": key,
            "Body": json_content.encode("utf-8"),
            "ContentType": "application/json",
        }

        # Add conditional write if ETag provided
        if expected_etag:
            put_params["IfMatch"] = expected_etag

        s3.put_object(**put_params)
        print(f"Saved data to S3: {key} (conditional: {expected_etag is not None})")

    except ClientError as e:
        if e.response["Error"]["Code"] == "PreconditionFailed":
            print(f"ETag mismatch - concurrent write detected for {key}")
            raise e
        else:
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
