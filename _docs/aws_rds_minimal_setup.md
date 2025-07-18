# AWS RDS Minimal Setup Guide

## Overview

This guide shows how to set up a **minimal** AWS RDS PostgreSQL instance for the **trading marketplace only**. No complex Multi-AZ, authentication, or security layers - just a simple database for player-to-player trading.

## Cost Estimate

- **Development**: ~$12/month (db.t3.micro)
- **Production**: ~$25/month (db.t3.small)

**Total AWS infrastructure cost: $12-25/month** (vs $80-130/month in the original overcomplicated plan)

## Prerequisites

- AWS account with RDS access
- AWS CLI configured (you already have this)
- Basic understanding of PostgreSQL

## Step 1: Create RDS Instance

### Using AWS CLI (Recommended)

```bash
# Create the minimal RDS instance
aws rds create-db-instance \
    --db-instance-identifier children-singularity-trading \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 15.4 \
    --master-username postgres \
    --master-user-password YOUR_SECURE_PASSWORD \
    --allocated-storage 20 \
    --storage-type gp2 \
    --no-multi-az \
    --backup-retention-period 7 \
    --storage-encrypted \
    --publicly-accessible \
    --vpc-security-group-ids YOUR_SECURITY_GROUP_ID \
    --db-name trading_marketplace \
    --region us-east-2

# Check creation status
aws rds describe-db-instances --db-instance-identifier children-singularity-trading
```

### Using AWS Console (Alternative)

1. Go to AWS RDS Console
2. Click "Create database"
3. Choose "PostgreSQL"
4. Template: **Free tier** (for development)
5. Settings:
   - DB instance identifier: `children-singularity-trading`
   - Master username: `postgres`
   - Master password: (your secure password)
6. Instance configuration:
   - DB instance class: `db.t3.micro`
   - Storage: 20 GB, General Purpose SSD (gp2)
   - **Disable** Multi-AZ deployment
7. Connectivity:
   - **Enable** public access (for development)
   - Security group: Create new or use existing
8. Additional configuration:
   - Initial database name: `trading_marketplace`
   - Backup retention: 7 days
   - **Enable** encryption at rest
9. Click "Create database"

## Step 2: Configure Security Group

```bash
# Create security group for RDS access
aws ec2 create-security-group \
    --group-name children-singularity-rds \
    --description "RDS access for Children of Singularity trading"

# Allow PostgreSQL access (port 5432) from your IP
aws ec2 authorize-security-group-ingress \
    --group-name children-singularity-rds \
    --protocol tcp \
    --port 5432 \
    --cidr YOUR_IP_ADDRESS/32

# For development, allow access from anywhere (LESS SECURE)
# aws ec2 authorize-security-group-ingress \
#     --group-name children-singularity-rds \
#     --protocol tcp \
#     --port 5432 \
#     --cidr 0.0.0.0/0
```

## Step 3: Get Connection Information

```bash
# Get the RDS endpoint
aws rds describe-db-instances \
    --db-instance-identifier children-singularity-trading \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text
```

Example output: `children-singularity-trading.abcd1234.us-east-2.rds.amazonaws.com`

## Step 4: Test Connection

```bash
# Test connection using psql
psql -h children-singularity-trading.abcd1234.us-east-2.rds.amazonaws.com \
     -U postgres \
     -d trading_marketplace \
     -p 5432

# Or test using a simple connection check
pg_isready -h children-singularity-trading.abcd1234.us-east-2.rds.amazonaws.com \
           -p 5432 \
           -U postgres
```

## Step 5: Initialize Database Schema

```bash
# Run the trading schema
psql -h YOUR_RDS_ENDPOINT \
     -U postgres \
     -d trading_marketplace \
     -f data/postgres/trading_schema.sql
```

## Step 6: Update Environment Variables

Create a simple `.env` file for the backend:

```bash
# Backend environment variables
DB_HOST=children-singularity-trading.abcd1234.us-east-2.rds.amazonaws.com
DB_NAME=trading_marketplace
DB_USER=postgres
DB_PASSWORD=your_secure_password
DB_PORT=5432

# Simple API key for basic protection
TRADING_API_KEY=your_simple_api_key_here
```

## Connection String Format

For the Python backend:

```python
DATABASE_URL = "postgresql://postgres:password@host:5432/trading_marketplace"
```

For testing:

```bash
export DATABASE_URL="postgresql://postgres:password@children-singularity-trading.abcd1234.us-east-2.rds.amazonaws.com:5432/trading_marketplace"
```

## Monitoring and Maintenance

### Check Database Status

```bash
# Check instance status
aws rds describe-db-instances \
    --db-instance-identifier children-singularity-trading \
    --query 'DBInstances[0].DBInstanceStatus'

# Check available storage
aws rds describe-db-instances \
    --db-instance-identifier children-singularity-trading \
    --query 'DBInstances[0].AllocatedStorage'
```

### Backup and Restore

```bash
# Manual backup (automatic backups are already enabled)
aws rds create-db-snapshot \
    --db-instance-identifier children-singularity-trading \
    --db-snapshot-identifier trading-manual-backup-$(date +%Y%m%d)

# List backups
aws rds describe-db-snapshots \
    --db-instance-identifier children-singularity-trading
```

## Cleanup (When No Longer Needed)

```bash
# Delete the RDS instance (CAREFUL - THIS DELETES ALL DATA)
aws rds delete-db-instance \
    --db-instance-identifier children-singularity-trading \
    --skip-final-snapshot

# Or with final snapshot for safety
aws rds delete-db-instance \
    --db-instance-identifier children-singularity-trading \
    --final-db-snapshot-identifier final-snapshot-$(date +%Y%m%d)
```

## Troubleshooting

### Connection Issues

1. **Check security group**: Ensure port 5432 is open from your IP
2. **Check public accessibility**: Must be enabled for external connections
3. **Check endpoint**: Use the exact endpoint from AWS console
4. **Check credentials**: Verify username/password

### Performance Issues

1. **Monitor storage**: RDS will auto-scale but check usage
2. **Check connections**: db.t3.micro supports ~100 connections max
3. **Monitor CPU**: Upgrade to db.t3.small if needed

### Cost Monitoring

```bash
# Check current month costs (approximate)
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-02-01 \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE
```

## Scaling to Production

When ready for production:

1. **Upgrade instance**: Change to `db.t3.small` or larger
2. **Increase storage**: Scale from 20GB to 50-100GB
3. **Enable Multi-AZ**: For high availability (increases cost)
4. **Restrict access**: Remove public accessibility, use VPC
5. **Enable monitoring**: CloudWatch metrics and alarms

## Security Best Practices

1. **Use strong passwords**: Generate random passwords
2. **Rotate credentials**: Change passwords regularly
3. **Limit access**: Only allow necessary IP addresses
4. **Enable SSL**: Force SSL connections in production
5. **Monitor access**: Enable VPC Flow Logs and CloudTrail

This setup gives you exactly what you need: **a simple database for trading, nothing more**.
