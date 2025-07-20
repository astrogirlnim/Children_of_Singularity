"""
Children of the Singularity - WebSocket Lobby Lambda Function
Handles real-time player position synchronization in the 2D trading lobby.

This function manages:
- WebSocket connections ($connect, $disconnect)
- Position updates (pos action)
- Broadcasting player positions to all connected clients
- Connection cleanup with TTL in DynamoDB

Architecture:
- DynamoDB: LobbyConnections table stores active connections
- API Gateway: WebSocket API with route-based message handling
- Lambda: Serverless position broadcasting with sub-100ms latency
"""

import json
import boto3
import time
import logging
from typing import Dict, List, Any, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
apigateway_management = None  # Will be initialized per request with endpoint

# Environment variables
TABLE_NAME = "LobbyConnections"
TTL_SECONDS = 3600  # 1 hour connection timeout

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for WebSocket lobby connections.

    Routes:
    - $connect: Player joins lobby
    - $disconnect: Player leaves lobby
    - pos: Player position update
    - $default: Fallback for unknown actions
    """
    try:
        # Extract route and connection info
        route_key = event.get('requestContext', {}).get('routeKey', '$default')
        connection_id = event.get('requestContext', {}).get('connectionId')
        domain_name = event.get('requestContext', {}).get('domainName')
        stage = event.get('requestContext', {}).get('stage')

        logger.info(f"Processing route: {route_key} for connection: {connection_id}")

        # Initialize API Gateway Management client for this request
        global apigateway_management
        endpoint_url = f"https://{domain_name}/{stage}"
        apigateway_management = boto3.client('apigatewaymanagementapi', endpoint_url=endpoint_url)

        # Route to appropriate handler
        if route_key == '$connect':
            return handle_connect(event, connection_id)
        elif route_key == '$disconnect':
            return handle_disconnect(event, connection_id)
        elif route_key == 'pos':
            return handle_position_update(event, connection_id)
        else:
            return handle_default(event, connection_id)

    except Exception as e:
        logger.error(f"Error processing WebSocket request: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }

def handle_connect(event: Dict[str, Any], connection_id: str) -> Dict[str, Any]:
    """
    Handle new player connecting to lobby.

    - Store connection in DynamoDB with TTL
    - Extract player_id from query parameters
    - Initialize player position to lobby center
    - Broadcast join message to other players
    """
    try:
        # Extract player_id from query parameters
        query_params = event.get('queryStringParameters') or {}
        player_id = query_params.get('pid', f'player_{connection_id[:8]}')

        logger.info(f"Player {player_id} connecting with connection {connection_id}")

        # Store connection in DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        current_time = int(time.time())
        ttl_timestamp = current_time + TTL_SECONDS

        # Default lobby center position (matches LobbyZone2D coordinates)
        default_x = 400.0  # Player spawn position in lobby
        default_y = 300.0

        table.put_item(
            Item={
                'connectionId': connection_id,
                'player_id': player_id,
                'x': default_x,
                'y': default_y,
                'connected_at': current_time,
                'ttl': ttl_timestamp,
                'last_update': current_time
            }
        )

        logger.info(f"Stored connection for player {player_id} at position ({default_x}, {default_y})")

        # Broadcast join message to all other connected players
        join_message = {
            'type': 'join',
            'id': player_id,
            'x': default_x,
            'y': default_y
        }

        broadcast_to_all_except(join_message, connection_id)

        # Send welcome message to connecting player with current lobby state
        welcome_message = {
            'type': 'welcome',
            'your_id': player_id,
            'lobby_players': get_current_lobby_players(connection_id)
        }

        send_to_connection(connection_id, welcome_message)

        return {'statusCode': 200}

    except Exception as e:
        logger.error(f"Error handling connect for {connection_id}: {str(e)}")
        return {'statusCode': 500}

def handle_disconnect(event: Dict[str, Any], connection_id: str) -> Dict[str, Any]:
    """
    Handle player disconnecting from lobby.

    - Remove connection from DynamoDB
    - Broadcast leave message to remaining players
    - Clean up any stale connections
    """
    try:
        table = dynamodb.Table(TABLE_NAME)

        # Get player info before deletion
        response = table.get_item(Key={'connectionId': connection_id})
        player_info = response.get('Item')

        if player_info:
            player_id = player_info.get('player_id', 'unknown')
            logger.info(f"Player {player_id} disconnecting with connection {connection_id}")

            # Remove from DynamoDB
            table.delete_item(Key={'connectionId': connection_id})

            # Broadcast leave message to remaining players
            leave_message = {
                'type': 'leave',
                'id': player_id
            }

            broadcast_to_all_except(leave_message, connection_id)

        else:
            logger.warning(f"No player info found for disconnecting connection {connection_id}")

        return {'statusCode': 200}

    except Exception as e:
        logger.error(f"Error handling disconnect for {connection_id}: {str(e)}")
        return {'statusCode': 500}

def handle_position_update(event: Dict[str, Any], connection_id: str) -> Dict[str, Any]:
    """
    Handle player position update in lobby.

    - Parse position from WebSocket message body
    - Update position in DynamoDB
    - Broadcast position to all other connected players
    - Rate limiting and validation
    """
    try:
        # Parse message body
        body = event.get('body', '{}')
        if isinstance(body, str):
            message = json.loads(body)
        else:
            message = body

        # Extract position coordinates
        x = message.get('x')
        y = message.get('y')

        # Validate position data
        if not isinstance(x, (int, float)) or not isinstance(y, (int, float)):
            logger.warning(f"Invalid position data from {connection_id}: x={x}, y={y}")
            return {'statusCode': 400}

        # Validate position bounds (lobby screen size)
        if x < -100 or x > 1100 or y < -100 or y > 500:
            logger.warning(f"Position out of bounds from {connection_id}: ({x}, {y})")
            return {'statusCode': 400}

        # Update position in DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        current_time = int(time.time())

        # Get current player info
        response = table.get_item(Key={'connectionId': connection_id})
        player_info = response.get('Item')

        if not player_info:
            logger.warning(f"No player info found for position update from {connection_id}")
            return {'statusCode': 404}

        player_id = player_info.get('player_id')

        # Rate limiting: Don't update more than once per 100ms
        last_update = player_info.get('last_update', 0)
        if current_time - last_update < 0.1:  # 100ms rate limit
            return {'statusCode': 200}  # Silently ignore rapid updates

        # Update position in database
        table.update_item(
            Key={'connectionId': connection_id},
            UpdateExpression='SET x = :x, y = :y, last_update = :time',
            ExpressionAttributeValues={
                ':x': x,
                ':y': y,
                ':time': current_time
            }
        )

        # Broadcast position update to all other players
        position_message = {
            'type': 'pos',
            'id': player_id,
            'x': x,
            'y': y
        }

        broadcast_to_all_except(position_message, connection_id)

        logger.debug(f"Updated position for {player_id} to ({x}, {y})")

        return {'statusCode': 200}

    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON in position update from {connection_id}: {str(e)}")
        return {'statusCode': 400}
    except Exception as e:
        logger.error(f"Error handling position update for {connection_id}: {str(e)}")
        return {'statusCode': 500}

def handle_default(event: Dict[str, Any], connection_id: str) -> Dict[str, Any]:
    """
    Handle unknown or malformed WebSocket messages.

    - Log unrecognized actions for debugging
    - Send error response to client
    - Maintain connection stability
    """
    try:
        body = event.get('body', '{}')
        logger.warning(f"Unknown message from {connection_id}: {body}")

        error_message = {
            'type': 'error',
            'message': 'Unknown action. Supported actions: pos'
        }

        send_to_connection(connection_id, error_message)

        return {'statusCode': 200}

    except Exception as e:
        logger.error(f"Error handling default route for {connection_id}: {str(e)}")
        return {'statusCode': 500}

def broadcast_to_all_except(message: Dict[str, Any], exclude_connection_id: str) -> None:
    """
    Broadcast message to all connected players except specified connection.

    - Query all active connections from DynamoDB
    - Send message to each connection via API Gateway
    - Remove stale connections that fail to receive messages
    """
    try:
        table = dynamodb.Table(TABLE_NAME)

        # Get all active connections
        response = table.scan()
        connections = response.get('Items', [])

        logger.info(f"Broadcasting to {len(connections)} connections (excluding {exclude_connection_id})")

        stale_connections = []

        for connection in connections:
            connection_id = connection['connectionId']

            # Skip the excluded connection
            if connection_id == exclude_connection_id:
                continue

            # Try to send message
            if not send_to_connection(connection_id, message):
                stale_connections.append(connection_id)

        # Clean up stale connections
        for stale_connection_id in stale_connections:
            logger.info(f"Removing stale connection: {stale_connection_id}")
            table.delete_item(Key={'connectionId': stale_connection_id})

    except Exception as e:
        logger.error(f"Error broadcasting message: {str(e)}")

def send_to_connection(connection_id: str, message: Dict[str, Any]) -> bool:
    """
    Send message to specific WebSocket connection.

    Returns True if successful, False if connection is stale.
    """
    try:
        apigateway_management.post_to_connection(
            ConnectionId=connection_id,
            Data=json.dumps(message)
        )
        return True

    except apigateway_management.exceptions.GoneException:
        logger.warning(f"Connection {connection_id} is gone")
        return False
    except Exception as e:
        logger.error(f"Error sending to connection {connection_id}: {str(e)}")
        return False

def get_current_lobby_players(exclude_connection_id: str) -> List[Dict[str, Any]]:
    """
    Get list of all current lobby players for welcome message.

    Returns list of player data with positions.
    """
    try:
        table = dynamodb.Table(TABLE_NAME)
        response = table.scan()
        connections = response.get('Items', [])

        players = []
        for connection in connections:
            if connection['connectionId'] != exclude_connection_id:
                players.append({
                    'id': connection.get('player_id'),
                    'x': connection.get('x'),
                    'y': connection.get('y')
                })

        return players

    except Exception as e:
        logger.error(f"Error getting current lobby players: {str(e)}")
        return []

def cleanup_expired_connections() -> None:
    """
    Manually clean up expired connections (TTL backup).

    DynamoDB TTL should handle this automatically, but this provides
    additional cleanup for edge cases.
    """
    try:
        table = dynamodb.Table(TABLE_NAME)
        current_time = int(time.time())

        response = table.scan()
        connections = response.get('Items', [])

        expired_count = 0
        for connection in connections:
            ttl = connection.get('ttl', current_time + 1)
            if ttl <= current_time:
                table.delete_item(Key={'connectionId': connection['connectionId']})
                expired_count += 1

        if expired_count > 0:
            logger.info(f"Cleaned up {expired_count} expired connections")

    except Exception as e:
        logger.error(f"Error cleaning up expired connections: {str(e)}")

# Performance monitoring
def log_performance_metrics(start_time: float, operation: str) -> None:
    """Log performance metrics for monitoring."""
    duration = time.time() - start_time
    logger.info(f"Operation '{operation}' completed in {duration:.3f}s")
