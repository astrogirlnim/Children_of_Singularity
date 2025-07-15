# ☁️ AWS S3 Integration Guide

This guide covers the AWS S3 integration for the Children of the Singularity release pipeline, providing cloud storage for build artifacts and extended retention.

## Overview

The S3 integration provides:
- **Extended Retention**: Releases stored beyond GitHub's limitations
- **Cost Optimization**: Automatic lifecycle management (Standard → IA → Glacier)
- **Secure Access**: Pre-signed URLs for time-limited downloads
- **Asset Management**: Development asset syncing and backup
- **Build Caching**: Faster builds by reusing assets from cloud storage

## Architecture

```
Local Development → S3 Assets → Build Process → S3 Releases → Distribution
      ↓                ↓              ↓            ↓
   Assets Upload   Asset Download   Build Upload  Download URLs
```

### S3 Bucket Structure

```
s3://children-of-singularity-releases/
├── releases/
│   ├── v1.0.0/
│   │   ├── Children_of_Singularity_v1.0.0_Windows.zip
│   │   ├── Children_of_Singularity_v1.0.0_macOS.zip
│   │   ├── Children_of_Singularity_v1.0.0_Linux.tar.gz
│   │   ├── RELEASE_NOTES.md
│   │   └── manifest.json
│   ├── v1.1.0/
│   └── LATEST (points to latest stable release)
├── assets/
│   ├── sprites/
│   ├── textures/
│   └── latest-assets/ (symlink to current assets)
└── dev-builds/
    ├── 2024-01-15/
    └── 2024-01-16/ (auto-deleted after 7 days)
```

## Setup Guide

### 1. AWS Account Setup

1. **Create AWS Account** (if you don't have one)
   - Visit [aws.amazon.com](https://aws.amazon.com)
   - Sign up for free tier account

2. **Create IAM User for S3 Access**
   ```bash
   # Using AWS CLI (after initial setup)
   aws iam create-user --user-name children-singularity-s3

   # Create access key
   aws iam create-access-key --user-name children-singularity-s3
   ```

3. **Set IAM Permissions**

   Create IAM policy (`s3-release-policy.json`):
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "s3:CreateBucket",
                   "s3:ListBucket",
                   "s3:GetBucketLocation",
                   "s3:GetBucketVersioning",
                   "s3:PutBucketVersioning",
                   "s3:PutBucketLifecycleConfiguration",
                   "s3:GetBucketLifecycleConfiguration"
               ],
               "Resource": "arn:aws:s3:::children-of-singularity-releases"
           },
           {
               "Effect": "Allow",
               "Action": [
                   "s3:PutObject",
                   "s3:GetObject",
                   "s3:DeleteObject",
                   "s3:PutObjectAcl",
                   "s3:GetObjectVersion"
               ],
               "Resource": "arn:aws:s3:::children-of-singularity-releases/*"
           }
       ]
   }
   ```

   Attach policy:
   ```bash
   aws iam put-user-policy --user-name children-singularity-s3 --policy-name S3ReleaseAccess --policy-document file://s3-release-policy.json
   ```

### 2. Local Environment Setup

1. **Install AWS CLI**
   ```bash
   # macOS
   brew install awscli

   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Windows
   # Download and run: https://awscli.amazonaws.com/AWSCLIV2.msi
   ```

2. **Configure AWS Credentials**
   ```bash
   aws configure
   # AWS Access Key ID: [Your Access Key]
   # AWS Secret Access Key: [Your Secret Key]
   # Default region name: us-west-2
   # Default output format: json
   ```

3. **Test Configuration**
   ```bash
   aws sts get-caller-identity
   # Should show your AWS account information
   ```

4. **Setup S3 Bucket**
   ```bash
   ./scripts/s3-manager.sh setup
   # Creates bucket, enables versioning, sets lifecycle policies
   ```

### 3. GitHub Repository Configuration

1. **Set Repository Variables**

   Go to: `Settings → Secrets and variables → Actions → Variables`

   Add these variables:
   ```
   USE_S3_STORAGE=true
   S3_BUCKET_NAME=children-of-singularity-releases  # Optional
   AWS_REGION=us-west-2                             # Optional
   ```

2. **Set Repository Secrets**

   Go to: `Settings → Secrets and variables → Actions → Secrets`

   Add these secrets:
   ```
   AWS_ACCESS_KEY_ID=[Your IAM User Access Key]
   AWS_SECRET_ACCESS_KEY=[Your IAM User Secret Key]
   ```

## Usage Guide

### Local Development

```bash
# Upload development assets to S3
./build.sh upload-assets

# Download assets from S3 (useful for team collaboration)
./build.sh download-assets

# Check S3 storage information
./build.sh s3-status

# Build release with S3 upload
USE_S3_STORAGE=true ./build.sh release
```

### Release Management

```bash
# Create local release and upload to S3
./scripts/release-manager.sh local v1.0.0 true

# Upload existing local release to S3
./scripts/release-manager.sh s3 upload v1.0.0

# Download release from S3
./scripts/release-manager.sh s3 download v1.0.0

# Generate download URLs (24 hours)
./scripts/release-manager.sh s3 urls v1.0.0

# List all S3 releases
./scripts/release-manager.sh s3 list

# Make release publicly accessible (use with caution)
./scripts/release-manager.sh s3 public v1.0.0 true
```

### Direct S3 Manager Usage

```bash
# Setup and maintenance
./scripts/s3-manager.sh setup
./scripts/s3-manager.sh check
./scripts/s3-manager.sh storage-info

# Release operations
./scripts/s3-manager.sh upload-release v1.0.0 releases/v1.0.0/
./scripts/s3-manager.sh download-release v1.0.0
./scripts/s3-manager.sh list-releases
./scripts/s3-manager.sh get-urls v1.0.0 86400

# Asset operations
./scripts/s3-manager.sh upload-assets assets/ sprites/
./scripts/s3-manager.sh download-assets sprites/ assets/

# Maintenance
./scripts/s3-manager.sh cleanup-dev 7
```

## Cost Management

### Storage Classes and Lifecycle

The S3 integration automatically manages costs through lifecycle policies:

1. **Standard Storage** (0-30 days): $0.023/GB/month
   - New releases for immediate access

2. **Standard-IA** (30-90 days): $0.0125/GB/month
   - Older releases, less frequent access

3. **Glacier** (90+ days): $0.004/GB/month
   - Archive storage for compliance/backup

4. **Development Builds**: Auto-deleted after 7 days

### Cost Estimation

For a typical game release (~150MB total):
- **Monthly cost**: ~$0.01-0.05 per release
- **Annual cost**: ~$0.50-2.00 for 10 releases
- **Benefits**: Unlimited downloads, global CDN, 99.999999999% durability

### Monitoring Costs

```bash
# Check storage usage
./scripts/s3-manager.sh storage-info

# AWS CLI cost monitoring
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-02-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## Security Best Practices

### Access Control

1. **Use IAM User** (not root account)
2. **Least Privilege**: Only S3 permissions needed
3. **Rotate Keys**: Regularly update access keys
4. **Monitor Access**: Enable CloudTrail logging

### Data Protection

1. **Versioning**: Enabled by default
2. **Encryption**: S3 server-side encryption
3. **Pre-signed URLs**: Time-limited access
4. **Private Bucket**: No public read by default

### GitHub Secrets Management

1. **Environment Separation**: Different credentials for staging/production
2. **Secret Rotation**: Update GitHub secrets when rotating AWS keys
3. **Audit Access**: Monitor GitHub Actions logs

## Troubleshooting

### Common Issues

1. **AWS CLI Not Found**
   ```bash
   # Install AWS CLI
   brew install awscli  # macOS
   pip install awscli   # Python
   ```

2. **Permission Denied**
   ```bash
   # Check credentials
   aws sts get-caller-identity

   # Verify S3 permissions
   aws s3 ls s3://children-of-singularity-releases
   ```

3. **Bucket Already Exists**
   ```bash
   # Choose different bucket name
   export S3_BUCKET_NAME=your-unique-bucket-name
   ./scripts/s3-manager.sh setup
   ```

4. **GitHub Actions Failing**
   - Verify repository secrets are set
   - Check AWS credentials haven't expired
   - Ensure `USE_S3_STORAGE=true` variable is set

### Debug Mode

```bash
# Enable debug output
AWS_CLI_LOG_LEVEL=debug ./scripts/s3-manager.sh check

# Verbose S3 operations
aws s3 sync --debug source/ s3://bucket/destination/
```

### Support Commands

```bash
# Test S3 connection
./scripts/s3-manager.sh check

# Show AWS configuration
aws configure list

# Test upload/download
echo "test" | ./scripts/s3-manager.sh upload-assets - test.txt
./scripts/s3-manager.sh download-assets test.txt -
```

## Advanced Configuration

### Custom Bucket Names

```bash
# Use custom bucket name
export S3_BUCKET_NAME=my-custom-game-releases
./scripts/s3-manager.sh setup
```

### Different AWS Regions

```bash
# Use different region
export AWS_REGION=eu-west-1
./scripts/s3-manager.sh setup
```

### Cross-Region Replication

For enhanced disaster recovery, set up cross-region replication:

```bash
# Create replication bucket
aws s3 mb s3://children-singularity-backup --region eu-west-1

# Configure replication (requires AWS Console or complex CLI setup)
```

### CDN Integration

Integrate with CloudFront for global distribution:

1. Create CloudFront distribution
2. Point origin to S3 bucket
3. Update download URLs to use CloudFront domain

## Migration Guide

### From Local-Only Releases

1. **Backup Existing Releases**
   ```bash
   mkdir -p releases-backup
   cp -r releases/ releases-backup/
   ```

2. **Upload Historical Releases**
   ```bash
   for version in releases/v*/; do
     version_name=$(basename "$version")
     ./scripts/s3-manager.sh upload-release "$version_name" "$version"
   done
   ```

3. **Verify Uploads**
   ```bash
   ./scripts/s3-manager.sh list-releases
   ```

### From Other Cloud Providers

Use AWS CLI sync or migration tools:

```bash
# Example: From Google Cloud Storage
gsutil -m cp -r gs://old-bucket/* ./temp/
./scripts/s3-manager.sh upload-assets temp/ migrated/
```

## Monitoring and Alerts

### CloudWatch Metrics

Set up monitoring for:
- Storage usage
- Request counts
- Error rates
- Cost increases

### SNS Notifications

Create alerts for:
- Unexpected storage growth
- Failed uploads
- Cost threshold breaches

```bash
# Example: Create cost alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "S3-Cost-Alert" \
  --alarm-description "Alert when S3 costs exceed $10" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold
```

---

## Support

For S3 integration issues:
1. Check this documentation
2. Review AWS S3 documentation
3. Test with `./scripts/s3-manager.sh check`
4. Verify GitHub repository secrets/variables
5. Monitor CloudTrail for API errors

**Remember**: S3 integration is optional but recommended for production releases and team collaboration.
