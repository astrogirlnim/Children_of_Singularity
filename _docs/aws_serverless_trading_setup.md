# AWS Serverless Trading Marketplace Setup Guide

This guide walks through setting up the serverless AWS infrastructure for the Children of the Singularity trading marketplace.

## 🎯 Architecture Overview

```
Game Client (Godot) → API Gateway → Lambda Function → S3 Storage
                                    ↓
                              Trading Data (JSON)
```

**Components:**
- **AWS Lambda**: Serverless function handling trading logic
- **S3**: JSON file storage for listings and trade history  
- **API Gateway**: HTTP endpoints with CORS support
- **IAM**: Secure access roles and policies

## 📋 Prerequisites

1. **AWS CLI** installed and configured
2. **AWS Account** with programmatic access
3. **Infrastructure secrets** file: `infrastructure_setup.env`

## 🚀 Quick Setup

### Step 1: Prepare Infrastructure Configuration

Copy the `infrastructure_setup.env` file and update with your AWS account details:

```bash
# Copy template
cp infrastructure_setup.env my_infrastructure.env

# Edit with your AWS account ID and preferred region
nano my_infrastructure.env
```

**Required Values to Update:**
- `AWS_ACCOUNT_ID`: Your 12-digit AWS account ID
- `AWS_REGION`: Your preferred AWS region (e.g., us-east-2)
- `S3_BUCKET_NAME`: Your existing S3 bucket name

### Step 2: Create IAM Role and Policies

```bash
# Load your environment variables
source my_infrastructure.env

# Create Lambda execution role
aws iam create-role \
    --role-name $LAMBDA_ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json

# Attach basic Lambda execution permissions
aws iam attach-role-policy \
    --role-name $LAMBDA_ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create S3 access policy
aws iam create-policy \
    --policy-name $S3_POLICY_NAME \
    --policy-document file://s3-policy.json

# Attach S3 policy to Lambda role
aws iam attach-role-policy \
    --role-name $LAMBDA_ROLE_NAME \
    --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$S3_POLICY_NAME
```

### Step 3: Initialize S3 Storage

```bash
# Create trading data structure in your S3 bucket
aws s3api put-object \
    --bucket $S3_BUCKET_NAME \
    --key $S3_TRADING_PREFIX \
    --content-length 0

# Initialize empty trading files
echo '[]' | aws s3 cp - s3://$S3_BUCKET_NAME/$S3_LISTINGS_KEY
echo '[]' | aws s3 cp - s3://$S3_BUCKET_NAME/$S3_TRADES_KEY

# Verify setup
aws s3 ls s3://$S3_BUCKET_NAME/trading/
```

### Step 4: Deploy Lambda Function

```bash
# Package Lambda function
cd backend
zip -r $LAMBDA_ZIP_FILE trading_lambda.py

# Create Lambda function
aws lambda create-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --runtime $LAMBDA_RUNTIME \
    --role arn:aws:iam::$AWS_ACCOUNT_ID:role/$LAMBDA_ROLE_NAME \
    --handler trading_lambda.lambda_handler \
    --zip-file fileb://$LAMBDA_ZIP_FILE \
    --timeout $LAMBDA_TIMEOUT \
    --memory-size $LAMBDA_MEMORY_SIZE \
    --region $AWS_REGION
```

### Step 5: Set Up API Gateway

```bash
# Create REST API
API_ID=$(aws apigateway create-rest-api \
    --name children-singularity-trading-api \
    --query 'id' --output text)

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --query 'items[?path==`/`].id' --output text)

# Create /listings resource
RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_ID \
    --path-part listings \
    --query 'id' --output text)

# Add GET method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method GET \
    --authorization-type NONE

# Add POST method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE

# Set up Lambda integrations
LAMBDA_URI="arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$LAMBDA_FUNCTION_NAME/invocations"

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri $LAMBDA_URI

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri $LAMBDA_URI

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
    --function-name $LAMBDA_FUNCTION_NAME \
    --statement-id allow-api-gateway \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$AWS_REGION:$AWS_ACCOUNT_ID:$API_ID/*/*"

# Deploy API
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name $API_GATEWAY_STAGE

# Your API endpoint is now:
echo "API Endpoint: https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/$API_GATEWAY_STAGE"
```

## 🎮 Godot Configuration

Update your game configuration:

1. **Create trading config file**: The game will create `user://trading_config.json` on first run
2. **Update API endpoint**: Edit the config file with your API Gateway URL:

```json
{
  "api_base_url": "https://your-api-id.execute-api.your-region.amazonaws.com/prod",
  "listings_endpoint": "/listings",
  "timeout_seconds": 30,
  "enable_debug_logs": true
}
```

## 🧪 Testing

Test your deployment:

```bash
# Test GET listings
curl -X GET "https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/prod/listings"

# Expected response: {"listings": [], "total": 0}
```

## 📊 Monitoring & Costs

### CloudWatch Monitoring
- **Lambda metrics**: Invocations, duration, errors
- **API Gateway metrics**: Request count, latency, 4xx/5xx errors
- **S3 metrics**: Storage usage, request metrics

### Cost Estimation
- **Lambda**: $0.20 per 1M requests + $0.0000166667 per GB-second
- **S3**: $0.023 per GB stored + $0.0004 per 1,000 requests
- **API Gateway**: $3.50 per million API calls

**Typical monthly costs for MVP**: $0.50 - $2.00

## 🔒 Security Best Practices

1. **IAM Principle of Least Privilege**: Lambda role only has S3 access to trading folder
2. **CORS Configuration**: API Gateway configured for your game domain
3. **No Secrets in Code**: All infrastructure details in `.env` files
4. **S3 Bucket Policies**: Restrict access to trading data only
5. **Rate Limiting**: API Gateway includes built-in throttling

## 🚨 Troubleshooting

### Lambda Function Issues
```bash
# Check Lambda logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/$LAMBDA_FUNCTION_NAME"

# Get recent logs
aws logs filter-log-events \
    --log-group-name "/aws/lambda/$LAMBDA_FUNCTION_NAME" \
    --start-time $(date -d '1 hour ago' +%s)000
```

### API Gateway Issues
```bash
# Test Lambda function directly
aws lambda invoke \
    --function-name $LAMBDA_FUNCTION_NAME \
    --payload '{"httpMethod": "GET", "path": "/listings"}' \
    response.json

cat response.json
```

### S3 Access Issues
```bash
# Check S3 bucket permissions
aws s3api get-bucket-policy --bucket $S3_BUCKET_NAME

# Verify trading files exist
aws s3 ls s3://$S3_BUCKET_NAME/trading/ --recursive
```

## 🔄 Updates & Maintenance

### Update Lambda Function
```bash
# Package new version
cd backend
zip -r trading_lambda.zip trading_lambda.py

# Update function code
aws lambda update-function-code \
    --function-name $LAMBDA_FUNCTION_NAME \
    --zip-file fileb://trading_lambda.zip
```

### Backup Trading Data
```bash
# Download current trading data
aws s3 sync s3://$S3_BUCKET_NAME/trading/ ./backups/trading-$(date +%Y%m%d)/
```

## 📈 Scaling Considerations

The serverless architecture automatically handles scaling:

- **Lambda**: Concurrency up to 10,000 simultaneous executions
- **API Gateway**: Rate limiting and throttling built-in
- **S3**: Unlimited storage and requests

For high-traffic games (10,000+ concurrent users), consider:
- **DynamoDB**: Replace S3 with DynamoDB for better performance
- **CloudFront**: Add CDN for global API distribution
- **Lambda Reserved Concurrency**: Guarantee performance for critical functions

---

**🎉 Your serverless trading marketplace is now live and ready for players!**
