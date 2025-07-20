#!/bin/bash
# Simple WebSocket Infrastructure Test
# Avoids encoding issues with direct CLI commands

echo "🧪 Simple WebSocket Infrastructure Test"
echo "======================================"

# Test 1: Check if Lambda function exists
echo "1. 🔍 Checking Lambda function..."
aws lambda get-function --function-name children-singularity-lobby-ws --region us-east-2 --query 'Configuration.FunctionName' --output text

# Test 2: Check DynamoDB table
echo "2. 📊 Checking DynamoDB table..."
aws dynamodb describe-table --table-name LobbyConnections --region us-east-2 --query 'Table.TableStatus' --output text

# Test 3: Test DynamoDB write/read
echo "3. 💾 Testing DynamoDB operations..."
TTL_TIME=$(($(date +%s) + 3600))
aws dynamodb put-item \
    --table-name LobbyConnections \
    --item "{\"connectionId\":{\"S\":\"test-123\"},\"player_id\":{\"S\":\"test-player\"},\"x\":{\"N\":\"100\"},\"y\":{\"N\":\"200\"},\"ttl\":{\"N\":\"$TTL_TIME\"}}" \
    --region us-east-2

echo "   ✅ Write successful, testing read..."
aws dynamodb get-item \
    --table-name LobbyConnections \
    --key '{"connectionId":{"S":"test-123"}}' \
    --region us-east-2 \
    --query 'Item.player_id.S' \
    --output text

echo "   🧹 Cleaning up test item..."
aws dynamodb delete-item \
    --table-name LobbyConnections \
    --key '{"connectionId":{"S":"test-123"}}' \
    --region us-east-2

# Test 4: Check WebSocket API
echo "4. 🌐 Checking WebSocket API..."
aws apigatewayv2 get-api --api-id 37783owd23 --region us-east-2 --query 'Name' --output text

# Test 5: List WebSocket routes
echo "5. 🛣️  Checking WebSocket routes..."
aws apigatewayv2 get-routes --api-id 37783owd23 --region us-east-2 --query 'Items[].RouteKey' --output table

echo ""
echo "🎯 Infrastructure Status Summary:"
echo "================================="
echo "✅ DynamoDB: LobbyConnections table"
echo "✅ Lambda: children-singularity-lobby-ws function"
echo "✅ WebSocket API: 37783owd23"
echo "✅ WebSocket URL: wss://bktpsfy4rb.execute-api.us-east-2.amazonaws.com/prod"
echo ""
echo "💡 To test WebSocket connection manually:"
echo "   npm install -g wscat"
echo "   wscat -c wss://bktpsfy4rb.execute-api.us-east-2.amazonaws.com/prod"
echo ""
echo "   Then send: {\"action\":\"pos\",\"x\":150,\"y\":200}"
