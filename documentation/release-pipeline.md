# 🚀 Release Pipeline Documentation

This document explains how to use the automated release pipeline for Children of the Singularity with AWS S3 integration.

## Overview

The release pipeline consists of:
- **Local Build System**: Enhanced `build.sh` script for development and local releases
- **Release Manager**: `scripts/release-manager.sh` for managing versions and triggering releases
- **AWS S3 Integration**: `scripts/s3-manager.sh` for cloud storage and distribution
- **GitHub Actions**: Automated multi-platform builds and release creation with S3 upload
- **Production Configuration**: Automated injection of production settings for releases
- **Release Cleanup**: Automatic deletion of old releases (keeps only the latest)

## 🔐 Required GitHub Repository Configuration

### Critical Secrets (Required for Full Functionality)

Configure these in **Settings** → **Secrets and variables** → **Actions** → **Secrets**:

| Secret | Description | Example | Required For |
|--------|-------------|---------|--------------|
| `API_GATEWAY_ENDPOINT` | AWS API Gateway URL for trading | `https://abc123.execute-api.us-east-2.amazonaws.com/prod` | Trading marketplace |
| `WEBSOCKET_URL` | WebSocket endpoint for multiplayer | `wss://abc123.execute-api.us-east-2.amazonaws.com/prod` | Multiplayer lobby |
| `AWS_ACCESS_KEY_ID` | AWS access key for S3 operations | `AKIA...` | S3 storage (optional) |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for S3 operations | `secret...` | S3 storage (optional) |

### Optional Variables (Have Sensible Defaults)

Configure these in **Settings** → **Secrets and variables** → **Actions** → **Variables**:

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `AWS_REGION` | AWS region for your services | `us-west-2` | `us-east-2` |
| `S3_BUCKET_NAME` | S3 bucket for releases | `children-of-singularity-releases` | `my-game-releases` |
| `USE_S3_STORAGE` | Enable S3 features | `false` | `true` |
| `USE_S3_ASSETS` | Enable S3 asset management | `false` | `true` |

### Configuration Priority Matrix

| Configuration Level | Priority | Usage |
|---------------------|----------|-------|
| **🔴 Critical** | `API_GATEWAY_ENDPOINT`, `WEBSOCKET_URL` | Core game functionality |
| **🟡 Optional** | AWS credentials | Enhanced S3 features |
| **🟢 Nice-to-have** | AWS region, bucket settings | Customization |

**Note**: The pipeline works without optional secrets - missing secrets trigger graceful fallbacks.

## Development Environment Setup

### 1. Local Configuration

Create your local environment files:

```bash
# Setup development environment
./setup_dev_env.sh

# Or manually copy templates
cp trading.env.template trading.env
cp lobby.env.template lobby.env
cp infrastructure_setup.env.template infrastructure_setup.env

# Edit with your actual endpoints
# trading.env: Update API_GATEWAY_ENDPOINT
# lobby.env: Update WEBSOCKET_URL  
# infrastructure_setup.env: Complete deployment configuration
```

### 2. Infrastructure Setup Template

The new `infrastructure_setup.env.template` provides comprehensive deployment configuration:

```bash
# Copy and configure
cp infrastructure_setup.env.template infrastructure_setup.env

# Update all YOUR_* placeholders with actual values:
API_GATEWAY_ENDPOINT=https://your-api-id.execute-api.your-region.amazonaws.com/prod
WEBSOCKET_URL=wss://your-api-id.execute-api.your-region.amazonaws.com/prod
AWS_REGION=your-region
```

This file is referenced by:
- TradingConfig.gd for API endpoint loading
- LobbyController.gd for WebSocket URL loading  
- build_config.sh for production configuration injection
- GitHub Actions for CI/CD pipeline configuration

## Quick Start

### 1. Setup GitHub Repository

```bash
# Configure repository secrets (critical)
# Go to: Settings → Secrets and variables → Actions → Secrets
# Add: API_GATEWAY_ENDPOINT, WEBSOCKET_URL
# Add: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (if using S3)

# Configure repository variables (optional)
# Go to: Settings → Secrets and variables → Actions → Variables  
# Add: USE_S3_STORAGE=true, AWS_REGION=us-east-2, etc.
```

### 2. Create a New Release

```bash
# Create a git tag and trigger automated release
./scripts/release-manager.sh create v1.0.0 "Initial release"
./scripts/release-manager.sh github v1.0.0

# Or create a pre-release
./scripts/release-manager.sh github v1.1.0-beta true

# Local release with S3 upload
./scripts/release-manager.sh local v1.0.0 true
```

### 3. AWS S3 Setup (Optional but Recommended)

```bash
# Install AWS CLI
brew install awscli  # macOS
# or pip install awscli

# Configure AWS credentials
aws configure

# Setup S3 bucket for releases
./scripts/s3-manager.sh setup

# Test S3 connection
./scripts/s3-manager.sh check

# Upload documentation to S3
./scripts/s3-manager.sh upload-doc
```

### 4. Monitor Release Progress

```bash
# Check workflow status
gh run list --workflow=release.yml

# View real-time logs  
gh run view --log
```

### 5. Download and Test

Once the workflow completes, releases are available at:
`https://github.com/GauntletAI/Children_of_Singularity/releases`

## GitHub Actions Workflow (Updated)

### New Features & Improvements

**🔧 Production Configuration Injection**
- Automatically creates production `.env` files from GitHub secrets
- Applies `build_config.sh production inject` before building
- Falls back to templates if secrets aren't configured

**🔍 Enhanced Verification**
- Verifies project structure and Godot installation
- Confirms export templates are properly installed
- Validates export presets configuration
- Comprehensive path verification for S3 operations

**🧹 Automated Cleanup**
- Restores original configuration files after builds
- Removes temporary files created during build process
- Runs even if previous steps fail (`if: always()`)

### Workflow Steps

1. **🏷️ Version Check**: Generate version numbers and determine if release should proceed
2. **🎮 Build Game**:
   - **Setup Environment**: Install Godot 4.4.1 and export templates
   - **Verify Configuration**: Check project structure and export settings
   - **Configure Production**: Inject production settings from secrets
   - **Download Assets**: Get assets from S3 if configured
   - **Build Platforms**: Create Windows, macOS, and Linux builds
   - **Create Archives**: Generate compressed release packages
   - **Upload to S3**: Store releases with extended retention (if enabled)
   - **Cleanup**: Restore original configuration files
3. **🏷️ Create Release**:
   - Creates GitHub release with detailed notes
   - Uploads all platform archives
   - Generates S3 download URLs (if enabled)

### Triggers

The release workflow triggers on:
1. **Git tags**: Push a tag matching `v*` pattern (e.g., `v1.0.0`)
2. **Push to main/master**: Creates development releases
3. **PR merge to main/master**: Creates pre-releases
4. **Manual dispatch**: Run manually from GitHub Actions tab with custom options

### Platform Support

| Platform | Archive Format | Export Preset | Notes |
|----------|---------------|---------------|--------|
| Windows | ZIP | Windows Desktop | .exe executable |
| macOS | ZIP | macOS | Universal .app bundle |
| Linux | TAR.GZ | Linux/X11 | .x86_64 executable |

## Build System

### Local Development

```bash
# Development/testing
./build.sh dev          # Run game in development mode
./build.sh debug        # Validate without graphics
./build.sh status       # Check build environment

# Local building (requires Godot export templates)
./build.sh dist         # Build distribution packages
./build.sh release      # Build complete release packages
./build.sh clean        # Clean build directories

# S3 integration (requires AWS CLI configured)
./build.sh upload-assets        # Upload development assets to S3
./build.sh download-assets      # Download assets from S3
./build.sh s3-status           # Show S3 storage information

# Environment variables for S3
export USE_S3_STORAGE=true     # Enable S3 upload for releases
export USE_S3_ASSETS=true      # Enable S3 for assets
export S3_BUCKET_NAME=my-bucket # Override default bucket name
```

### Production Configuration System

The build system now supports automatic production configuration injection:

```bash
# Apply production configuration (done automatically in GitHub Actions)
./build_config.sh production inject

# Restore development configuration
./build_config.sh production restore
```

This system:
- Injects real API endpoints into TradingConfig.gd
- Updates WebSocket URLs in LobbyController.gd  
- Backs up original files with `.original` extension
- Can be safely run locally for testing production builds

### Release Manager

```bash
# Version management
./scripts/release-manager.sh create v1.0.0 "Release message"
./scripts/release-manager.sh delete v1.0.0
./scripts/release-manager.sh list

# Local releases
./scripts/release-manager.sh local v1.0.0        # Local only
./scripts/release-manager.sh local v1.0.0 true   # Local + S3 upload

# S3 release management
./scripts/release-manager.sh s3 upload v1.0.0    # Upload existing release
./scripts/release-manager.sh s3 download v1.0.0  # Download from S3
./scripts/release-manager.sh s3 list             # List S3 releases
./scripts/release-manager.sh s3 urls v1.0.0      # Get download URLs
./scripts/release-manager.sh s3 public v1.0.0    # Make publicly accessible

# GitHub integration
./scripts/release-manager.sh github v1.0.0
./scripts/release-manager.sh status              # Shows local + S3 status
```

### S3 Manager (Direct Usage)

```bash
# Setup and configuration
./scripts/s3-manager.sh setup                    # Create bucket and policies
./scripts/s3-manager.sh check                    # Verify AWS configuration

# Release management
./scripts/s3-manager.sh upload-release v1.0.0 releases/v1.0.0/
./scripts/s3-manager.sh download-release v1.0.0
./scripts/s3-manager.sh list-releases
./scripts/s3-manager.sh get-urls v1.0.0 86400    # 24-hour URLs

# Asset management
./scripts/s3-manager.sh upload-assets assets/ sprites/
./scripts/s3-manager.sh download-assets sprites/ assets/

# Maintenance
./scripts/s3-manager.sh cleanup-dev 7            # Clean builds older than 7 days
./scripts/s3-manager.sh storage-info             # Show storage usage
```

## Documentation Management

The documentation system is fully integrated with the S3 release pipeline:

### Upload Documentation

```bash
# Upload all documentation
./scripts/s3-manager.sh upload-doc

# Upload specific sections
./scripts/s3-manager.sh upload-doc documentation/core_concept/ core_concept/
./scripts/s3-manager.sh upload-doc documentation/design/ design/

# List uploaded documentation
./scripts/s3-manager.sh list-doc
```

### Documentation Structure in S3

```
s3://children-of-singularity-releases/documentation/
├── BrainLift/                   # AI learning and concepts
├── core_concept/                # Project rules and guidelines
├── design/                      # Visual assets and design docs
├── godot_summarized/            # Godot engine documentation
├── security/                    # Security setup guides
└── README.md                    # Auto-generated index
```

### Documentation Features

- **Automatic Indexing**: README.md is auto-generated with structure overview
- **Version Control**: Documentation versioned alongside releases
- **Metadata Tracking**: Upload timestamps and content types
- **Access Control**: Same security model as release artifacts

## Release Versioning

### Version Format
- **Production**: `v1.0.0`, `v1.2.5`, `v2.0.0`
- **Pre-release**: `v1.1.0-beta`, `v2.0.0-rc1`
- **Development**: `v1.0.0-build.123` (auto-generated)

### Semantic Versioning
- **Major** (v2.0.0): Breaking changes, major new features
- **Minor** (v1.2.0): New features, backward compatible
- **Patch** (v1.0.1): Bug fixes, small improvements

## Prerequisites

### For Local Development
- Godot 4.4.1 installed and in PATH
- Git repository with clean working directory

### For Distribution Builds
- Godot export templates installed
- Export presets configured (automated in CI/CD)

### For GitHub Integration
- GitHub CLI (`gh`) installed and authenticated
- Proper repository permissions
- **Repository secrets configured** (API_GATEWAY_ENDPOINT, WEBSOCKET_URL)

### For S3 Integration (Optional)
- AWS CLI installed and configured
- AWS account with S3 access
- GitHub repository variables configured:
  - `USE_S3_STORAGE=true` (enable S3 in GitHub Actions)
  - `S3_BUCKET_NAME` (optional, defaults to `children-of-singularity-releases`)
  - `AWS_REGION` (optional, defaults to `us-west-2`)
- GitHub repository secrets configured:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`

## Installation Guide

### GitHub CLI Setup
```bash
# Install (macOS)
brew install gh

# Authenticate
gh auth login

# Verify
gh auth status
```

### Godot Export Templates
```bash
# In Godot Editor:
# 1. Go to Editor → Manage Export Templates...
# 2. Download templates for version 4.4.1
# 3. Or download from: https://downloads.tuxfamily.org/godotengine/4.4.1/
```

### AWS S3 Setup
```bash
# Install AWS CLI (macOS)
brew install awscli

# Install AWS CLI (Linux/Ubuntu)
# Install dependencies first
sudo apt-get update && sudo apt-get install -y curl unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-west-2), Output format (json)

# Test configuration
aws sts get-caller-identity

# Setup S3 bucket and policies
./scripts/s3-manager.sh setup
```

### GitHub Repository Configuration
```bash
# Set repository variables (Settings → Secrets and variables → Actions → Variables)
USE_S3_STORAGE=true
S3_BUCKET_NAME=children-of-singularity-releases  # optional
AWS_REGION=us-west-2                             # optional

# Set repository secrets (Settings → Secrets and variables → Actions → Secrets)
API_GATEWAY_ENDPOINT=https://your-api.execute-api.region.amazonaws.com/prod
WEBSOCKET_URL=wss://your-api.execute-api.region.amazonaws.com/prod
AWS_ACCESS_KEY_ID=your_access_key_id             # optional
AWS_SECRET_ACCESS_KEY=your_secret_access_key     # optional
```

## Release Process

### Standard Release

1. **Prepare Release**
   ```bash
   # Ensure clean working directory
   git status

   # Check current status
   ./scripts/release-manager.sh status
   ```

2. **Create Version Tag**
   ```bash
   # Create and push tag
   ./scripts/release-manager.sh create v1.0.0 "Description of changes"
   ```

3. **Trigger Automated Build**
   ```bash
   # Start GitHub Actions workflow
   ./scripts/release-manager.sh github v1.0.0
   ```

4. **Monitor Progress**
   ```bash
   # Check workflow status
   gh run list --workflow=release.yml

   # View detailed logs
   gh run view --log
   ```

5. **Verify Release**
   - Check GitHub releases page
   - Download and test each platform
   - Verify release notes are correct
   - Test trading marketplace and multiplayer lobby functionality

### Emergency Release Cleanup

```bash
# Delete problematic release
./scripts/release-manager.sh delete v1.0.0

# Clean local artifacts
./build.sh clean

# Start fresh
./scripts/release-manager.sh create v1.0.1 "Bug fix release"
```

## Generated Release Assets

Each release includes:

### Platform Archives (GitHub Releases)
- `Children_of_Singularity_v1.0.0_Windows.zip`
- `Children_of_Singularity_v1.0.0_macOS.zip`  
- `Children_of_Singularity_v1.0.0_Linux.tar.gz`

### S3 Storage (if enabled)
- Same archives stored in S3 with extended retention
- Automatic lifecycle management (Standard → IA → Glacier)
- Pre-signed download URLs for secure access
- Release manifest with build metadata

### Content Structure
```
Children_of_Singularity_v1.0.0_Windows.zip
├── Children_of_Singularity.exe     # Game executable
├── README.md                       # Project information
└── LICENSE                         # License file
```

### Release Notes
Auto-generated with:
- Build information (version, commit, date)
- Platform download links
- Installation instructions
- System requirements
- Game features overview
- Known issues
- Support information

## Troubleshooting

### Common Issues

**Missing GitHub Secrets**
```bash
# Check if secrets are configured
# Go to: Settings → Secrets and variables → Actions

# Required secrets:
API_GATEWAY_ENDPOINT=https://your-api.execute-api.region.amazonaws.com/prod
WEBSOCKET_URL=wss://your-api.execute-api.region.amazonaws.com/prod

# Optional (for S3):
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
```

**Export Templates Missing**
```bash
# Check status
./build.sh status

# Install templates in Godot Editor:
# Editor → Manage Export Templates → Download
```

**GitHub CLI Not Authenticated**
```bash
# Re-authenticate
gh auth login

# Check status
gh auth status
```

**Build Failures**
```bash
# Check export presets
./build.sh status

# Clean and retry
./build.sh clean
./scripts/release-manager.sh local v1.0.0
```

**Production Configuration Issues**
```bash
# Test configuration injection locally
./build_config.sh production inject

# Check if files were created
ls -la trading.env lobby.env

# Restore if needed
./build_config.sh production restore
```

**Release Cleanup Issues**
```bash
# Manual cleanup
gh release list
gh release delete v1.0.0

# Or use script
./scripts/release-manager.sh delete v1.0.0
```

### Debugging

**Verbose Workflow Logs**
```bash
# View detailed logs with timestamps
gh run view --log

# Follow specific job
gh run view --job=build-game --log
```

**Local Testing**
```bash
# Test build locally before GitHub release
./scripts/release-manager.sh local v1.0.0-test

# Check output
ls -la releases/v1.0.0-test/
```

**Configuration Testing**
```bash
# Test production configuration locally
./build_config.sh production inject
./build.sh debug  # Validate project
./build_config.sh production restore
```

## Security Considerations

- Release artifacts are excluded from git (`.gitignore`)
- GitHub token permissions limited to releases scope
- No sensitive data in release notes or artifacts
- Export templates verified during build process
- S3 access uses IAM credentials with least-privilege permissions
- Pre-signed URLs for secure, time-limited downloads
- Releases naturally versioned by path structure (v1.0.0/, v1.1.0/) - no S3 versioning needed
- Lifecycle policies prevent indefinite storage costs
- **Production secrets never committed to repository**
- **Configuration files automatically cleaned up after builds**

## Performance

- **Build Time**: ~5-10 minutes for all platforms (+ 1-2 minutes for S3 upload)
- **Artifact Size**: ~50-100MB per platform
- **Cleanup**: Old releases deleted before new ones created
- **Retention**: Build artifacts kept for 1 day in GitHub Actions, extended retention in S3
- **S3 Storage Classes**:
  - Standard (0-30 days)
  - Standard-IA (30-90 days)
  - Glacier (90+ days)
  - Development builds auto-deleted after 7 days

## Recent Improvements (v2024.1)

### ✅ Fixed Critical Issues
- **Environment File Handling**: Removed missing .env files from export presets
- **Production Configuration**: Added automatic injection of production settings
- **Path Verification**: Enhanced validation of project structure and dependencies
- **Export Template Verification**: Confirmed Godot setup before building
- **Graceful Fallbacks**: Pipeline works even without optional secrets configured

### 🔧 Enhanced Features
- **Infrastructure Template**: New `infrastructure_setup.env.template` for deployment
- **Comprehensive Logging**: Better error messages and debugging information
- **Automated Cleanup**: Proper restoration of configuration files
- **Security Improvements**: No secrets in committed files, proper credential handling

### 🚀 Performance Optimizations
- **Parallel Operations**: Optimized build steps for faster execution
- **Smart Caching**: Improved asset download and verification processes
- **Error Recovery**: Better handling of transient failures and retries

---

## Support

For issues with the release pipeline:
1. Check this documentation
2. Review GitHub Actions logs
3. Verify repository secrets are configured
4. Test locally with release manager
5. Check Godot export preset configuration

**Pro Tips:**
- Always configure API_GATEWAY_ENDPOINT and WEBSOCKET_URL secrets for full functionality
- Test locally before creating GitHub releases
- Use semantic versioning consistently
- Include meaningful commit messages in release tags
- Monitor GitHub Actions workflow runs
- Keep export templates updated with Godot version
- Use infrastructure_setup.env.template for team development coordination
