#!/bin/bash

# s3-manager.sh
# AWS S3 management script for Children of the Singularity release pipeline
# Handles uploading/downloading assets, builds, and release artifacts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Default S3 configuration
S3_BUCKET_NAME="${S3_BUCKET_NAME:-children-of-singularity-releases}"
S3_REGION="${AWS_REGION:-us-west-2}"
AWS_PROFILE="${AWS_PROFILE:-default}"

# Function to print colored output
print_status() {
    case $1 in
        "ERROR")   echo -e "${RED}❌ $2${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $2${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $2${NC}" ;;
        "INFO")    echo -e "${BLUE}📋 $2${NC}" ;;
        "S3")      echo -e "${PURPLE}☁️  $2${NC}" ;;
        *)         echo "📋 $2" ;;
    esac
}

# Function to check AWS CLI installation and configuration
check_aws_cli() {
    print_status "INFO" "Checking AWS CLI installation and configuration..."

    if ! command -v aws &> /dev/null; then
        print_status "ERROR" "AWS CLI is not installed"
        print_status "INFO" "Install with: brew install awscli (macOS) or pip install awscli"
        return 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_status "ERROR" "AWS credentials not configured"
        print_status "INFO" "Configure with: aws configure"
        print_status "INFO" "Or set environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
        return 1
    fi

    print_status "SUCCESS" "AWS CLI configured and authenticated"

    # Show current AWS identity
    local aws_identity=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
    print_status "INFO" "AWS Account: $aws_identity"

    return 0
}

# Function to create S3 bucket if it doesn't exist
create_bucket() {
    print_status "S3" "Setting up S3 bucket: $S3_BUCKET_NAME"

    # Check if bucket exists
    if aws s3api head-bucket --bucket "$S3_BUCKET_NAME" &> /dev/null; then
        print_status "SUCCESS" "S3 bucket already exists: $S3_BUCKET_NAME"
    else
        print_status "INFO" "Creating S3 bucket: $S3_BUCKET_NAME in region $S3_REGION"

        if [ "$S3_REGION" = "us-east-1" ]; then
            # us-east-1 doesn't need LocationConstraint
            aws s3api create-bucket --bucket "$S3_BUCKET_NAME"
        else
            aws s3api create-bucket \
                --bucket "$S3_BUCKET_NAME" \
                --region "$S3_REGION" \
                --create-bucket-configuration LocationConstraint="$S3_REGION"
        fi

        print_status "SUCCESS" "S3 bucket created: $S3_BUCKET_NAME"
    fi

    # Configure bucket settings
    setup_bucket_policies
}

# Function to set up bucket policies and configuration
setup_bucket_policies() {
    print_status "S3" "Configuring S3 bucket policies and settings..."

    # Skip bucket versioning - releases are already versioned by path (v1.0.0, v1.1.0, etc.)
    # and development assets are versioned by Git LFS
    print_status "INFO" "Skipping bucket versioning (not needed - releases versioned by path, assets by Git LFS)"

    # Set up lifecycle configuration to manage costs (non-critical)
    print_status "INFO" "Setting up lifecycle policies..."
    cat > /tmp/lifecycle-config.json << EOF
{
    "Rules": [
        {
            "ID": "ManageReleaseArtifacts",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "releases/"
            },
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "STANDARD_IA"
                },
                {
                    "Days": 90,
                    "StorageClass": "GLACIER"
                }
            ]
        },
        {
            "ID": "CleanupDevelopmentBuilds",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "dev-builds/"
            },
            "Expiration": {
                "Days": 7
            }
        },
        {
            "ID": "ManageAssets",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "assets/"
            },
            "Transitions": [
                {
                    "Days": 60,
                    "StorageClass": "STANDARD_IA"
                }
            ]
        }
    ]
}
EOF

    if aws s3api put-bucket-lifecycle-configuration \
        --bucket "$S3_BUCKET_NAME" \
        --lifecycle-configuration file:///tmp/lifecycle-config.json 2>/dev/null; then
        print_status "SUCCESS" "Lifecycle policies configured"
    else
        print_status "WARNING" "Could not set lifecycle policies (permission denied) - continuing without lifecycle management"
    fi

    # Clean up temp file
    rm -f /tmp/lifecycle-config.json

    print_status "SUCCESS" "S3 bucket configuration completed (with available permissions)"
}

# Function to upload release artifacts to S3
upload_release() {
    local version="$1"
    local release_dir="$2"

    if [ -z "$version" ] || [ -z "$release_dir" ]; then
        print_status "ERROR" "Usage: upload_release <version> <release_directory>"
        return 1
    fi

    if [ ! -d "$release_dir" ]; then
        print_status "ERROR" "Release directory not found: $release_dir"
        return 1
    fi

    print_status "S3" "Uploading release $version to S3..."

    local s3_path="s3://$S3_BUCKET_NAME/releases/$version/"

    # Upload with metadata
    aws s3 sync "$release_dir" "$s3_path" \
        --metadata "version=$version,upload-date=$(date -u +%Y-%m-%dT%H:%M:%SZ),build-number=${BUILD_NUMBER:-unknown}" \
        --storage-class STANDARD \
        --no-progress

    print_status "SUCCESS" "Release $version uploaded to: $s3_path"

    # Create a latest release link
    if [[ ! "$version" =~ -(alpha|beta|rc) ]]; then
        print_status "INFO" "Creating latest release link..."
        echo "$version" | aws s3 cp - "s3://$S3_BUCKET_NAME/releases/LATEST"
    fi

    # Generate and upload release manifest
    create_release_manifest "$version" "$s3_path"
}

# Function to download release artifacts from S3
download_release() {
    local version="$1"
    local target_dir="${2:-downloads/$version}"

    if [ -z "$version" ]; then
        print_status "ERROR" "Usage: download_release <version> [target_directory]"
        return 1
    fi

    print_status "S3" "Downloading release $version from S3..."

    local s3_path="s3://$S3_BUCKET_NAME/releases/$version/"

    # Create target directory
    mkdir -p "$target_dir"

    # Download release
    if aws s3 sync "$s3_path" "$target_dir" --no-progress; then
        print_status "SUCCESS" "Release $version downloaded to: $target_dir"
    else
        print_status "ERROR" "Failed to download release $version"
        return 1
    fi
}

# Function to upload development assets
upload_assets() {
    local asset_path="$1"
    local s3_key="$2"

    if [ -z "$asset_path" ] || [ -z "$s3_key" ]; then
        print_status "ERROR" "Usage: upload_assets <local_path> <s3_key>"
        return 1
    fi

    if [ ! -e "$asset_path" ]; then
        print_status "ERROR" "Asset path not found: $asset_path"
        return 1
    fi

    print_status "S3" "Uploading assets to S3..."

    local s3_path="s3://$S3_BUCKET_NAME/assets/$s3_key"

    if [ -d "$asset_path" ]; then
        # Upload directory
        aws s3 sync "$asset_path" "$s3_path" --no-progress
    else
        # Upload single file
        aws s3 cp "$asset_path" "$s3_path" --no-progress
    fi

    print_status "SUCCESS" "Assets uploaded to: $s3_path"
}

# Function to download development assets
download_assets() {
    local s3_key="$1"
    local target_path="${2:-assets/}"

    if [ -z "$s3_key" ]; then
        print_status "ERROR" "Usage: download_assets <s3_key> [target_path]"
        return 1
    fi

    print_status "S3" "Downloading assets from S3..."

    local s3_path="s3://$S3_BUCKET_NAME/assets/$s3_key"

    # Create target directory if needed
    if [[ "$target_path" == */ ]]; then
        mkdir -p "$target_path"
    else
        mkdir -p "$(dirname "$target_path")"
    fi

    if aws s3 sync "$s3_path" "$target_path" --no-progress 2>/dev/null || aws s3 cp "$s3_path" "$target_path" --no-progress; then
        print_status "SUCCESS" "Assets downloaded to: $target_path"
    else
        print_status "ERROR" "Failed to download assets from: $s3_path"
        return 1
    fi
}

# Function to upload documentation
upload_documentation() {
    local doc_path="${1:-documentation/}"
    local s3_key="${2:-}"

    if [ ! -d "$doc_path" ]; then
        print_status "ERROR" "Documentation directory not found: $doc_path"
        return 1
    fi

    print_status "S3" "Uploading documentation to S3..."

    local s3_path
    if [ -n "$s3_key" ]; then
        s3_path="s3://$S3_BUCKET_NAME/documentation/$s3_key"
    else
        s3_path="s3://$S3_BUCKET_NAME/documentation/"
    fi

    # Upload documentation with metadata
    aws s3 sync "$doc_path" "$s3_path" \
        --metadata "content-type=documentation,upload-date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --no-progress

    print_status "SUCCESS" "Documentation uploaded to: $s3_path"

    # Create documentation index if it doesn't exist
    create_documentation_index
}

# Function to download documentation
download_documentation() {
    local s3_key="${1:-}"
    local target_path="${2:-documentation/}"

    print_status "S3" "Downloading documentation from S3..."

    local s3_path
    if [ -n "$s3_key" ]; then
        s3_path="s3://$S3_BUCKET_NAME/documentation/$s3_key"
    else
        s3_path="s3://$S3_BUCKET_NAME/documentation/"
    fi

    # Create target directory if needed
    mkdir -p "$(dirname "$target_path")"

    if aws s3 sync "$s3_path" "$target_path" --no-progress; then
        print_status "SUCCESS" "Documentation downloaded to: $target_path"
    else
        print_status "ERROR" "Failed to download documentation from: $s3_path"
        return 1
    fi
}

# Function to create documentation index
create_documentation_index() {
    print_status "INFO" "Creating documentation index..."

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    cat > /tmp/doc-index.md << EOF
# Children of the Singularity - Documentation Index

This documentation is automatically synchronized with the S3 bucket for release management.

## Documentation Structure

- **BrainLift/**: AI learning and concept development notes
- **core_concept/**: Core project rules, tech stack, and UI guidelines
- **design/**: Visual assets, sprites, and design documentation
- **godot_summarized/**: Godot engine documentation and tutorials
- **security/**: Security setup and guidelines

## Release Integration

This documentation is part of the automated release pipeline:
- Uploaded to: \`s3://$S3_BUCKET_NAME/documentation/\`
- Synchronized with local \`documentation/\` directory
- Versioned alongside releases

Last updated: $timestamp

## Available Commands

\`\`\`bash
# Upload documentation
./scripts/s3-manager.sh upload-doc

# Download documentation
./scripts/s3-manager.sh download-doc

# List documentation
./scripts/s3-manager.sh list-doc
\`\`\`
EOF

    # Upload index
    aws s3 cp "/tmp/doc-index.md" "s3://$S3_BUCKET_NAME/documentation/README.md" --no-progress

    # Clean up
    rm -f "/tmp/doc-index.md"

    print_status "SUCCESS" "Documentation index created"
}

# Function to list documentation in S3
list_documentation() {
    local filter="${1:-}"

    print_status "S3" "Listing documentation in S3 bucket..."

    if [ -n "$filter" ]; then
        aws s3 ls "s3://$S3_BUCKET_NAME/documentation/" --recursive | grep "$filter" | sort -k1,2
    else
        aws s3 ls "s3://$S3_BUCKET_NAME/documentation/" --recursive | sort -k1,2
    fi

    echo
    print_status "INFO" "Documentation structure:"
    aws s3 ls "s3://$S3_BUCKET_NAME/documentation/" | awk '{print "  " $2}' | sort
}

# Function to list releases in S3
list_releases() {
    local prefix="${1:-}"

    print_status "S3" "Listing releases in S3 bucket..."

    if [ -n "$prefix" ]; then
        aws s3 ls "s3://$S3_BUCKET_NAME/releases/" | grep "$prefix" | sort -k1,2
    else
        aws s3 ls "s3://$S3_BUCKET_NAME/releases/" | sort -k1,2
    fi

    # Show latest release
    if aws s3 ls "s3://$S3_BUCKET_NAME/releases/LATEST" &> /dev/null; then
        echo
        print_status "INFO" "Latest stable release:"
        aws s3 cp "s3://$S3_BUCKET_NAME/releases/LATEST" - 2>/dev/null | sed 's/^/  /'
    fi
}

# Function to create release manifest
create_release_manifest() {
    local version="$1"
    local s3_path="$2"

    print_status "INFO" "Creating release manifest..."

    cat > /tmp/release-manifest.json << EOF
{
    "version": "$version",
    "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "build_number": "${BUILD_NUMBER:-unknown}",
    "commit_hash": "${COMMIT_HASH:-unknown}",
    "s3_location": "$s3_path",
    "platforms": []
}
EOF

    # Add platform information if files exist
    local manifest_path="/tmp/release-manifest.json"

    # Check for platform builds and add to manifest
    for platform in windows macos linux; do
        local platform_files=$(aws s3 ls "$s3_path" | grep -i "$platform" | wc -l)
        if [ "$platform_files" -gt 0 ]; then
            # Use jq if available, otherwise use basic approach
            if command -v jq &> /dev/null; then
                jq ".platforms += [\"$platform\"]" "$manifest_path" > "/tmp/manifest-temp.json"
                mv "/tmp/manifest-temp.json" "$manifest_path"
            fi
        fi
    done

    # Upload manifest
    aws s3 cp "$manifest_path" "$s3_path/manifest.json" --no-progress

    # Clean up
    rm -f "$manifest_path"

    print_status "SUCCESS" "Release manifest created and uploaded"
}

# Function to get download URLs for a release
get_download_urls() {
    local version="$1"
    local duration="${2:-3600}"  # 1 hour default

    if [ -z "$version" ]; then
        print_status "ERROR" "Usage: get_download_urls <version> [duration_seconds]"
        return 1
    fi

    print_status "S3" "Generating pre-signed download URLs for release $version..."

    local s3_path="s3://$S3_BUCKET_NAME/releases/$version/"

    # List all files in the release
    aws s3 ls "$s3_path" --recursive | while read -r line; do
        local file_path=$(echo "$line" | awk '{print $4}')
        local file_name=$(basename "$file_path")

        if [[ "$file_name" =~ \.(zip|tar\.gz|exe|app)$ ]]; then
            local download_url=$(aws s3 presign "s3://$S3_BUCKET_NAME/$file_path" --expires-in "$duration")
            echo "Platform: $(echo "$file_name" | grep -oE '(Windows|macOS|Linux)' | head -1)"
            echo "File: $file_name"
            echo "URL: $download_url"
            echo "Expires: $(date -d "+$duration seconds" 2>/dev/null || date -v "+${duration}S" 2>/dev/null || echo "in $duration seconds")"
            echo "---"
        fi
    done
}

# Function to sync release to CDN or public access
sync_to_public() {
    local version="$1"
    local make_public="${2:-false}"

    if [ -z "$version" ]; then
        print_status "ERROR" "Usage: sync_to_public <version> [make_public]"
        return 1
    fi

    print_status "S3" "Syncing release $version for public access..."

    local s3_path="s3://$S3_BUCKET_NAME/releases/$version/"

    # Set public read access if requested
    if [ "$make_public" = "true" ]; then
        print_status "WARNING" "Making release publicly accessible"
        aws s3 sync "$s3_path" "$s3_path" \
            --acl public-read \
            --metadata-directive REPLACE \
            --no-progress

        print_status "SUCCESS" "Release $version is now publicly accessible"
        echo "Public URL base: https://$S3_BUCKET_NAME.s3.$S3_REGION.amazonaws.com/releases/$version/"
    else
        print_status "INFO" "Use pre-signed URLs for secure access"
        get_download_urls "$version" 86400  # 24 hours
    fi
}

# Function to clean up old development builds
cleanup_dev_builds() {
    local days_old="${1:-7}"

    print_status "S3" "Cleaning up development builds older than $days_old days..."

    # Calculate cutoff date
    local cutoff_date
    if command -v gdate &> /dev/null; then
        cutoff_date=$(gdate -d "$days_old days ago" +%Y-%m-%d)
    else
        cutoff_date=$(date -d "$days_old days ago" +%Y-%m-%d 2>/dev/null || date -v "-${days_old}d" +%Y-%m-%d)
    fi

    print_status "INFO" "Removing dev builds older than $cutoff_date"

    # List and delete old builds
    aws s3 ls "s3://$S3_BUCKET_NAME/dev-builds/" | while read -r line; do
        local build_date=$(echo "$line" | awk '{print $1}')
        if [[ "$build_date" < "$cutoff_date" ]]; then
            local build_path=$(echo "$line" | awk '{print $2}')
            if [ -n "$build_path" ]; then
                print_status "INFO" "Removing old build: $build_path"
                aws s3 rm "s3://$S3_BUCKET_NAME/dev-builds/$build_path" --recursive --no-progress
            fi
        fi
    done

    print_status "SUCCESS" "Development build cleanup completed"
}

# Function to show storage usage and costs
show_storage_info() {
    print_status "S3" "S3 bucket storage information..."

    echo
    print_status "INFO" "Bucket contents:"
    aws s3 ls "s3://$S3_BUCKET_NAME" --recursive --human-readable --summarize

    echo
    print_status "INFO" "Storage breakdown by prefix:"
    for prefix in releases assets dev-builds; do
        echo -n "  $prefix: "
        aws s3 ls "s3://$S3_BUCKET_NAME/$prefix/" --recursive --summarize 2>/dev/null | tail -1 | awk '{print $3 " " $4}' || echo "0 B"
    done

    echo
    print_status "INFO" "Recent uploads (last 10):"
    aws s3 ls "s3://$S3_BUCKET_NAME" --recursive | sort -k1,2 | tail -10 | awk '{print "  " $1 " " $2 " " $4}'
}

# Function to show help
show_help() {
    echo "☁️  Children of the Singularity S3 Manager"
    echo "==========================================="
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Setup Commands:"
    echo "  setup                          - Create and configure S3 bucket"
    echo "  check                          - Check AWS CLI and credentials"
    echo
    echo "Release Commands:"
    echo "  upload-release <version> <dir> - Upload release artifacts"
    echo "  download-release <version>     - Download release artifacts"
    echo "  list-releases [filter]         - List releases in S3"
    echo "  get-urls <version> [duration]  - Generate download URLs"
    echo "  sync-public <version> [true]   - Make release publicly accessible"
    echo
    echo "Asset Commands:"
    echo "  upload-assets <path> <key>     - Upload development assets"
    echo "  download-assets <key> [path]   - Download development assets"
    echo
    echo "Documentation Commands:"
    echo "  upload-doc <path> [key]        - Upload documentation"
    echo "  download-doc [key] [path]     - Download documentation"
    echo "  list-doc [filter]             - List documentation"
    echo
    echo "Maintenance Commands:"
    echo "  cleanup-dev [days]             - Clean old dev builds (default: 7 days)"
    echo "  storage-info                   - Show storage usage information"
    echo
    echo "Environment Variables:"
    echo "  S3_BUCKET_NAME                 - S3 bucket name (default: children-of-singularity-releases)"
    echo "  AWS_REGION                     - AWS region (default: us-west-2)"
    echo "  AWS_PROFILE                    - AWS profile (default: default)"
    echo "  AWS_ACCESS_KEY_ID              - AWS access key"
    echo "  AWS_SECRET_ACCESS_KEY          - AWS secret key"
    echo
    echo "Examples:"
    echo "  $0 setup                       # Initial setup"
    echo "  $0 upload-release v1.0.0 releases/v1.0.0"
    echo "  $0 download-release v1.0.0"
    echo "  $0 get-urls v1.0.0 86400      # 24-hour URLs"
    echo "  $0 upload-assets assets/ sprites/"
    echo "  $0 upload-doc documentation/core_concept/"
    echo
}

# Main script logic
case "${1:-help}" in
    "setup")
        check_aws_cli || exit 1
        create_bucket
        ;;
    "check")
        check_aws_cli
        ;;
    "upload-release")
        check_aws_cli || exit 1
        upload_release "$2" "$3"
        ;;
    "download-release")
        check_aws_cli || exit 1
        download_release "$2" "$3"
        ;;
    "list-releases")
        check_aws_cli || exit 1
        list_releases "$2"
        ;;
    "get-urls")
        check_aws_cli || exit 1
        get_download_urls "$2" "$3"
        ;;
    "sync-public")
        check_aws_cli || exit 1
        sync_to_public "$2" "$3"
        ;;
    "upload-assets")
        check_aws_cli || exit 1
        upload_assets "$2" "$3"
        ;;
    "download-assets")
        check_aws_cli || exit 1
        download_assets "$2" "$3"
        ;;
    "upload-doc")
        check_aws_cli || exit 1
        upload_documentation "$2" "$3"
        ;;
    "download-doc")
        check_aws_cli || exit 1
        download_documentation "$2" "$3"
        ;;
    "list-doc")
        check_aws_cli || exit 1
        list_documentation "$2"
        ;;
    "cleanup-dev")
        check_aws_cli || exit 1
        cleanup_dev_builds "$2"
        ;;
    "storage-info")
        check_aws_cli || exit 1
        show_storage_info
        ;;
    "help"|*)
        show_help
        ;;
esac
