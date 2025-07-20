#!/bin/bash
# lobby-setup.sh - Complete automated setup for WebSocket Lobby Infrastructure
# Creates DynamoDB table, WebSocket API Gateway, Lambda function, and IAM permissions

set -e  # Exit on any error

echo "🚀 Setting up WebSocket Lobby Infrastructure for Children of the Singularity..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Source existing environment configuration
if [ -f "infrastructure_setup.env" ]; then
    source infrastructure_setup.env
    echo -e "${GREEN}✅ Loaded existing infrastructure configuration${NC}"
else
    echo -e "${RED}❌ infrastructure_setup.env not found. Please ensure it exists.${NC}"
    exit 1
fi

# Set default values for lobby-specific configuration
export LOBBY_TABLE_NAME="LobbyConnections"
export LOBBY_LAMBDA_FUNCTION_NAME="children-singularity-lobby-ws"
export LOBBY_LAMBDA_ROLE_NAME="children-singularity-lobby-lambda-role"
export LOBBY_POLICY_NAME="children-singularity-lobby-dynamodb-policy"

# Verify AWS CLI is configured
echo -e "${BLUE}🔍 Verifying AWS configuration...${NC}"
aws sts get-caller-identity > /dev/null || {
    echo -e "${RED}❌ AWS CLI not configured. Please run 'aws configure' first.${NC}"
    exit 1
}

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✅ AWS Account ID: $AWS_ACCOUNT_ID${NC}"
echo -e "${GREEN}✅ AWS Region: $AWS_REGION${NC}"

# Step 1: Create DynamoDB Table
echo -e "\n${BLUE}📊 Step 1: Creating DynamoDB table '$LOBBY_TABLE_NAME'...${NC}"

# Check if table already exists
if aws dynamodb describe-table --table-name $LOBBY_TABLE_NAME --region $AWS_REGION > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  DynamoDB table '$LOBBY_TABLE_NAME' already exists${NC}"
else
    aws dynamodb create-table \
        --table-name $LOBBY_TABLE_NAME \
        --attribute-definitions \
            AttributeName=connectionId,AttributeType=S \
        --key-schema \
            AttributeName=connectionId,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region $AWS_REGION

    echo -e "${GREEN}✅ DynamoDB table created successfully${NC}"

    # Wait for table to be active
    echo -e "${BLUE}⏳ Waiting for table to become active...${NC}"
    aws dynamodb wait table-exists --table-name $LOBBY_TABLE_NAME --region $AWS_REGION

    # Enable TTL for automatic cleanup
    aws dynamodb update-time-to-live \
        --table-name $LOBBY_TABLE_NAME \
        --time-to-live-specification Enabled=true,AttributeName=ttl \
        --region $AWS_REGION

    echo -e "${GREEN}✅ TTL enabled for automatic connection cleanup${NC}"
fi

# Step 2: Create WebSocket API Gateway
echo -e "\n${BLUE}🌐 Step 2: Creating WebSocket API Gateway...${NC}"

# Create WebSocket API
export WEBSOCKET_API_ID=$(aws apigatewayv2 create-api \
    --name children-singularity-lobby-websocket \
    --protocol-type WEBSOCKET \
    --route-selection-expression "\$request.body.action" \
    --query 'ApiId' --output text)

echo -e "${GREEN}✅ Created WebSocket API: $WEBSOCKET_API_ID${NC}"

# Step 3: Create IAM Role for Lambda
echo -e "\n${BLUE}🔐 Step 3: Creating IAM role and policies...${NC}"

# Create trust policy for Lambda
cat > /tmp/lobby-lambda-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Check if role already exists
if aws iam get-role --role-name $LOBBY_LAMBDA_ROLE_NAME > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  IAM role '$LOBBY_LAMBDA_ROLE_NAME' already exists${NC}"
else
    # Create IAM role
    aws iam create-role \
        --role-name $LOBBY_LAMBDA_ROLE_NAME \
        --assume-role-policy-document file:///tmp/lobby-lambda-trust-policy.json

    echo -e "${GREEN}✅ Created IAM role: $LOBBY_LAMBDA_ROLE_NAME${NC}"
fi

# Attach basic Lambda execution policy
aws iam attach-role-policy \
    --role-name $LOBBY_LAMBDA_ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create DynamoDB and API Gateway access policy
cat > /tmp/lobby-dynamodb-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:$AWS_REGION:$AWS_ACCOUNT_ID:table/$LOBBY_TABLE_NAME"
    },
    {
      "Effect": "Allow",
      "Action": [
        "execute-api:ManageConnections"
      ],
      "Resource": "arn:aws:execute-api:$AWS_REGION:$AWS_ACCOUNT_ID:$WEBSOCKET_API_ID/*"
    }
  ]
}
EOF

# Check if policy already exists
if aws iam get-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$LOBBY_POLICY_NAME > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  IAM policy '$LOBBY_POLICY_NAME' already exists${NC}"
else
    # Create and attach DynamoDB policy
    aws iam create-policy \
        --policy-name $LOBBY_POLICY_NAME \
        --policy-document file:///tmp/lobby-dynamodb-policy.json

    echo -e "${GREEN}✅ Created IAM policy: $LOBBY_POLICY_NAME${NC}"
fi

# Attach policy to role
aws iam attach-role-policy \
    --role-name $LOBBY_LAMBDA_ROLE_NAME \
    --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$LOBBY_POLICY_NAME

echo -e "${GREEN}✅ Attached policies to Lambda role${NC}"

# Step 4: Deploy Lambda Function
echo -e "\n${BLUE}⚡ Step 4: Deploying Lambda function...${NC}"

# Wait for IAM role to propagate
echo -e "${BLUE}⏳ Waiting for IAM role to propagate...${NC}"
sleep 10

# Package Lambda function
cd backend
if [ -f "trading_lobby_ws.zip" ]; then
    rm trading_lobby_ws.zip
fi
zip -r trading_lobby_ws.zip trading_lobby_ws.py

# Check if Lambda function already exists
if aws lambda get-function --function-name $LOBBY_LAMBDA_FUNCTION_NAME --region $AWS_REGION > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Lambda function '$LOBBY_LAMBDA_FUNCTION_NAME' already exists, updating code...${NC}"

    # Update existing function
    aws lambda update-function-code \
        --function-name $LOBBY_LAMBDA_FUNCTION_NAME \
        --zip-file fileb://trading_lobby_ws.zip \
        --region $AWS_REGION
else
    # Create new Lambda function
    aws lambda create-function \
        --function-name $LOBBY_LAMBDA_FUNCTION_NAME \
        --runtime python3.12 \
        --role arn:aws:iam::$AWS_ACCOUNT_ID:role/$LOBBY_LAMBDA_ROLE_NAME \
        --handler trading_lobby_ws.lambda_handler \
        --zip-file fileb://trading_lobby_ws.zip \
        --timeout 30 \
        --memory-size 256 \
        --region $AWS_REGION

    # Set environment variables separately using a temporary file
    cat > /tmp/lambda-env.json << EOF
{
  "Variables": {
    "TABLE_NAME": "$LOBBY_TABLE_NAME",
    "WSS_URL": "https://$WEBSOCKET_API_ID.execute-api.$AWS_REGION.amazonaws.com/prod"
  }
}
EOF

    aws lambda update-function-configuration \
        --function-name $LOBBY_LAMBDA_FUNCTION_NAME \
        --environment file:///tmp/lambda-env.json \
        --region $AWS_REGION

    echo -e "${GREEN}✅ Lambda function deployed successfully${NC}"
fi

cd ..

# Step 5: Create API Gateway integrations and routes
echo -e "\n${BLUE}🔗 Step 5: Setting up API Gateway integrations...${NC}"

export LAMBDA_ARN="arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$LOBBY_LAMBDA_FUNCTION_NAME"

# Create Lambda integration
export INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id $WEBSOCKET_API_ID \
    --integration-type AWS_PROXY \
    --integration-uri $LAMBDA_ARN \
    --integration-method POST \
    --query 'IntegrationId' --output text)

echo -e "${GREEN}✅ Created Lambda integration: $INTEGRATION_ID${NC}"

# Create routes
aws apigatewayv2 create-route \
    --api-id $WEBSOCKET_API_ID \
    --route-key '$connect' \
    --target integrations/$INTEGRATION_ID

aws apigatewayv2 create-route \
    --api-id $WEBSOCKET_API_ID \
    --route-key '$disconnect' \
    --target integrations/$INTEGRATION_ID

aws apigatewayv2 create-route \
    --api-id $WEBSOCKET_API_ID \
    --route-key 'pos' \
    --target integrations/$INTEGRATION_ID

aws apigatewayv2 create-route \
    --api-id $WEBSOCKET_API_ID \
    --route-key '$default' \
    --target integrations/$INTEGRATION_ID

echo -e "${GREEN}✅ Created WebSocket routes${NC}"

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
    --function-name $LOBBY_LAMBDA_FUNCTION_NAME \
    --statement-id allow-websocket-api-gateway \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$AWS_REGION:$AWS_ACCOUNT_ID:$WEBSOCKET_API_ID/*" \
    --region $AWS_REGION 2>/dev/null || echo -e "${YELLOW}⚠️  Lambda permission already exists${NC}"

# Step 6: Deploy WebSocket API
echo -e "\n${BLUE}🚀 Step 6: Deploying WebSocket API...${NC}"

aws apigatewayv2 create-deployment \
    --api-id $WEBSOCKET_API_ID \
    --stage-name prod

export WEBSOCKET_URL="wss://$WEBSOCKET_API_ID.execute-api.$AWS_REGION.amazonaws.com/prod"

echo -e "${GREEN}✅ WebSocket API deployed successfully${NC}"
echo -e "${GREEN}🌐 WebSocket endpoint: $WEBSOCKET_URL${NC}"

# Step 7: Update configuration files
echo -e "\n${BLUE}📝 Step 7: Updating configuration files...${NC}"

# Update lobby configuration with actual WebSocket URL
sed -i.bak "s/WEBSOCKET_API_ID/$WEBSOCKET_API_ID/g" infrastructure/lobby_config.json
echo -e "${GREEN}✅ Updated infrastructure/lobby_config.json${NC}"

# Update infrastructure setup environment file
cat >> infrastructure_setup.env << EOF

# Lobby WebSocket Configuration (added by lobby-setup.sh)
WEBSOCKET_API_ID=$WEBSOCKET_API_ID
WEBSOCKET_URL=$WEBSOCKET_URL
LOBBY_TABLE_NAME=$LOBBY_TABLE_NAME
LOBBY_LAMBDA_FUNCTION_NAME=$LOBBY_LAMBDA_FUNCTION_NAME
LOBBY_LAMBDA_ROLE_NAME=$LOBBY_LAMBDA_ROLE_NAME
LOBBY_POLICY_NAME=$LOBBY_POLICY_NAME
EOF

echo -e "${GREEN}✅ Updated infrastructure_setup.env with lobby configuration${NC}"

# Step 8: Run basic tests
echo -e "\n${BLUE}🧪 Step 8: Running infrastructure tests...${NC}"

# Test DynamoDB table
echo -e "${BLUE}Testing DynamoDB table access...${NC}"
aws dynamodb put-item \
    --table-name $LOBBY_TABLE_NAME \
    --item '{
        "connectionId": {"S": "test-connection-123"},
        "player_id": {"S": "test-player"},
        "x": {"N": "100"},
        "y": {"N": "200"},
        "ttl": {"N": "'$(date -d '+1 hour' +%s)'"}
    }' --region $AWS_REGION

# Verify item was created
aws dynamodb get-item \
    --table-name $LOBBY_TABLE_NAME \
    --key '{"connectionId": {"S": "test-connection-123"}}' \
    --region $AWS_REGION > /dev/null

# Clean up test item
aws dynamodb delete-item \
    --table-name $LOBBY_TABLE_NAME \
    --key '{"connectionId": {"S": "test-connection-123"}}' \
    --region $AWS_REGION

echo -e "${GREEN}✅ DynamoDB table test passed${NC}"

# Test Lambda function
echo -e "${BLUE}Testing Lambda function...${NC}"
aws lambda invoke \
    --function-name $LOBBY_LAMBDA_FUNCTION_NAME \
    --payload '{
        "requestContext": {
            "connectionId": "test123",
            "routeKey": "$connect",
            "domainName": "'$WEBSOCKET_API_ID'.execute-api.'$AWS_REGION'.amazonaws.com",
            "stage": "prod"
        },
        "queryStringParameters": {"pid": "player_test"}
    }' \
    /tmp/lambda_response.json --region $AWS_REGION > /dev/null

if [ -f "/tmp/lambda_response.json" ]; then
    echo -e "${GREEN}✅ Lambda function test passed${NC}"
    rm /tmp/lambda_response.json
fi

# Cleanup temporary files
rm -f /tmp/lobby-lambda-trust-policy.json
rm -f /tmp/lobby-dynamodb-policy.json

echo -e "\n${GREEN}🎉 WebSocket Lobby Infrastructure deployment complete!${NC}"
echo -e "\n${BLUE}📊 Deployment Summary:${NC}"
echo -e "  📋 DynamoDB Table: $LOBBY_TABLE_NAME"
echo -e "  ⚡ Lambda Function: $LOBBY_LAMBDA_FUNCTION_NAME"
echo -e "  🌐 WebSocket API ID: $WEBSOCKET_API_ID"
echo -e "  🔗 WebSocket URL: $WEBSOCKET_URL"
echo -e "  💰 Estimated Monthly Cost: $0.88"

echo -e "\n${BLUE}📝 Next Steps:${NC}"
echo -e "  1. Copy infrastructure/lobby_config.json to your Godot project's user://lobby_config.json"
echo -e "  2. Implement LobbyController.gd in Godot for WebSocket client"
echo -e "  3. Test WebSocket connection from game"
echo -e "  4. Monitor costs and performance in AWS Console"

echo -e "\n${YELLOW}🧪 Manual Testing:${NC}"
echo -e "  # Install wscat for testing (if not installed)"
echo -e "  npm install -g wscat"
echo -e ""
echo -e "  # Test WebSocket connection"
echo -e "  wscat -c $WEBSOCKET_URL"
echo -e ""
echo -e "  # Send test position update (in wscat):"
echo -e "  {\"action\": \"pos\", \"x\": 150, \"y\": 200}"

echo -e "\n${GREEN}✅ Lobby infrastructure setup completed successfully!${NC}"
