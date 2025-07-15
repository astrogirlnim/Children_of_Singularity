#!/bin/bash

# release-manager.sh
# Release management script for Children of the Singularity
# Handles version tagging, local releases, and GitHub integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Function to print colored output
print_status() {
    case $1 in
        "ERROR")   echo -e "${RED}❌ $2${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $2${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $2${NC}" ;;
        "INFO")    echo -e "${BLUE}📋 $2${NC}" ;;
        "RELEASE") echo -e "${PURPLE}🚀 $2${NC}" ;;
        *)         echo "📋 $2" ;;
    esac
}

# Function to validate version format
validate_version() {
    local version="$1"
    if [[ ! $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_status "ERROR" "Invalid version format. Use vX.Y.Z (e.g., v1.0.0)"
        return 1
    fi
    return 0
}

# Function to check git status
check_git_status() {
    print_status "INFO" "Checking git status..."

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_status "ERROR" "Not in a git repository"
        return 1
    fi

    if [ -n "$(git status --porcelain)" ]; then
        print_status "WARNING" "Working directory is not clean"
        git status --short
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "INFO" "Aborted by user"
            return 1
        fi
    fi

    print_status "SUCCESS" "Git status check passed"
    return 0
}

# Function to create and push git tag
create_git_tag() {
    local version="$1"
    local message="$2"

    print_status "INFO" "Creating git tag: $version"

    if git tag -l | grep -q "^$version$"; then
        print_status "ERROR" "Tag $version already exists"
        print_status "INFO" "Delete with: git tag -d $version"
        return 1
    fi

    git tag -a "$version" -m "$message"
    print_status "SUCCESS" "Created tag: $version"

    read -p "Push tag to remote? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        git push origin "$version"
        print_status "SUCCESS" "Pushed tag to remote"
    else
        print_status "INFO" "Tag created locally only"
    fi
}

# Function to delete git tag (local and remote)
delete_git_tag() {
    local version="$1"

    print_status "INFO" "Deleting git tag: $version"

    # Delete local tag
    if git tag -l | grep -q "^$version$"; then
        git tag -d "$version"
        print_status "SUCCESS" "Deleted local tag: $version"
    else
        print_status "WARNING" "Local tag $version not found"
    fi

    # Delete remote tag
    if git ls-remote --tags origin | grep -q "refs/tags/$version$"; then
        read -p "Delete remote tag $version? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            git push --delete origin "$version"
            print_status "SUCCESS" "Deleted remote tag: $version"
        fi
    else
        print_status "INFO" "Remote tag $version not found"
    fi
}

# Function to list releases (local and remote)
list_releases() {
    print_status "INFO" "Listing releases..."

    echo
    print_status "INFO" "Local tags:"
    if git tag -l "v*" | head -10; then
        local tag_count=$(git tag -l "v*" | wc -l)
        if [ "$tag_count" -gt 10 ]; then
            print_status "INFO" "... and $((tag_count - 10)) more"
        fi
    else
        print_status "INFO" "No local tags found"
    fi

    echo
    print_status "INFO" "Remote tags:"
    if git ls-remote --tags origin | grep "refs/tags/v" | sed 's/.*refs\/tags\///' | head -10; then
        echo
    else
        print_status "INFO" "No remote tags found"
    fi

    echo
    print_status "INFO" "GitHub releases:"
    if command -v gh > /dev/null 2>&1; then
        gh release list --limit 5 2>/dev/null || print_status "WARNING" "GitHub CLI not authenticated or repo not found"
    else
        print_status "WARNING" "GitHub CLI (gh) not installed"
        print_status "INFO" "Install with: brew install gh"
    fi
}

# Function to trigger GitHub Actions release workflow
trigger_github_release() {
    local version="$1"
    local prerelease="${2:-false}"

    print_status "RELEASE" "Triggering GitHub Actions release workflow..."

    if ! command -v gh > /dev/null 2>&1; then
        print_status "ERROR" "GitHub CLI (gh) is required to trigger workflows"
        print_status "INFO" "Install with: brew install gh"
        return 1
    fi

    if ! gh auth status > /dev/null 2>&1; then
        print_status "ERROR" "GitHub CLI not authenticated"
        print_status "INFO" "Run: gh auth login"
        return 1
    fi

    print_status "INFO" "Starting workflow with version: $version (prerelease: $prerelease)"

    gh workflow run "release.yml" \
        --field version="$version" \
        --field prerelease="$prerelease"

    print_status "SUCCESS" "Release workflow triggered"
    print_status "INFO" "Monitor progress: gh run list --workflow=release.yml"
    print_status "INFO" "View logs: gh run view --log"
}

# Function to show help
show_help() {
    echo "🚀 Children of the Singularity Release Manager"
    echo "=============================================="
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  create <version> [message]     - Create and push git tag (e.g., v1.0.0)"
    echo "  delete <version>              - Delete git tag (local and remote)"
    echo "  list                          - List existing releases and tags"
    echo "  github <version> [pre]        - Trigger GitHub Actions release"
    echo "  local <version> [s3]          - Build local release (uses build.sh)"
    echo "  s3 <action> <version> [opts]  - Manage S3 releases"
    echo "  status                        - Show git, local, and S3 release status"
    echo "  help                          - Show this help message"
    echo
    echo "S3 Actions:"
    echo "  s3 upload <version>           - Upload existing local release to S3"
    echo "  s3 download <version>         - Download release from S3"
    echo "  s3 list [filter]              - List S3 releases"
    echo "  s3 urls <version> [duration]  - Generate download URLs (default: 24h)"
    echo "  s3 public <version> [true]    - Make release publicly accessible"
    echo
    echo "Examples:"
    echo "  $0 create v1.0.0 'Initial release'"
    echo "  $0 local v1.0.0 true         # Build locally and upload to S3"
    echo "  $0 github v1.0.0             # Production release"
    echo "  $0 github v1.1.0-beta true   # Pre-release"
    echo "  $0 s3 upload v1.0.0          # Upload existing release to S3"
    echo "  $0 s3 urls v1.0.0 3600       # 1-hour download URLs"
    echo "  $0 delete v1.0.0             # Remove tag"
    echo
    echo "Notes:"
    echo "  - Version must follow vX.Y.Z format"
    echo "  - GitHub CLI (gh) required for GitHub operations"
    echo "  - Git repository must be clean for releases"
    echo
}

# Function to build local release
build_local_release() {
    local version="$1"
    local upload_to_s3="${2:-false}"

    print_status "RELEASE" "Building local release: $version"

    if [ ! -f "build.sh" ]; then
        print_status "ERROR" "build.sh not found in current directory"
        return 1
    fi

    # Set version environment variable
    export VERSION="$version"
    export BUILD_NUMBER="local"
    export COMMIT_HASH=$(git rev-parse --short HEAD)

    # Enable S3 upload if requested
    if [ "$upload_to_s3" = "true" ]; then
        export USE_S3_STORAGE=true
        print_status "INFO" "S3 upload enabled for this release"
    fi

    print_status "INFO" "Running build.sh release..."
    ./build.sh release

    print_status "SUCCESS" "Local release completed"
    print_status "INFO" "Check releases/$version/ for output"

    # Show S3 information if uploaded
    if [ "$upload_to_s3" = "true" ] && command -v "./scripts/s3-manager.sh" &> /dev/null; then
        print_status "INFO" "S3 release information:"
        ./scripts/s3-manager.sh list-releases "$version"
    fi
}

# Function to manage S3 releases
manage_s3_release() {
    local action="$1"
    local version="$2"
    local options="$3"

    case "$action" in
        "upload")
            if [ -z "$version" ]; then
                print_status "ERROR" "Version required for S3 upload"
                return 1
            fi

            local release_dir="releases/$version"
            if [ ! -d "$release_dir" ]; then
                print_status "ERROR" "Local release directory not found: $release_dir"
                print_status "INFO" "Build the release first with: $0 local $version"
                return 1
            fi

            print_status "RELEASE" "Uploading release $version to S3..."
            if ./scripts/s3-manager.sh upload-release "$version" "$release_dir"; then
                print_status "SUCCESS" "Release uploaded to S3"
                print_status "INFO" "Generating download URLs..."
                ./scripts/s3-manager.sh get-urls "$version" 86400
            else
                print_status "ERROR" "Failed to upload release to S3"
                return 1
            fi
            ;;
        "download")
            if [ -z "$version" ]; then
                print_status "ERROR" "Version required for S3 download"
                return 1
            fi

            print_status "RELEASE" "Downloading release $version from S3..."
            if ./scripts/s3-manager.sh download-release "$version" "downloads/$version"; then
                print_status "SUCCESS" "Release downloaded from S3"
                print_status "INFO" "Files available in: downloads/$version/"
            else
                print_status "ERROR" "Failed to download release from S3"
                return 1
            fi
            ;;
        "list")
            print_status "RELEASE" "Listing S3 releases..."
            ./scripts/s3-manager.sh list-releases "$version"
            ;;
        "urls")
            if [ -z "$version" ]; then
                print_status "ERROR" "Version required for download URLs"
                return 1
            fi

            local duration="${options:-86400}"  # 24 hours default
            print_status "RELEASE" "Generating download URLs for $version..."
            ./scripts/s3-manager.sh get-urls "$version" "$duration"
            ;;
        "public")
            if [ -z "$version" ]; then
                print_status "ERROR" "Version required for public access"
                return 1
            fi

            local make_public="${options:-false}"
            print_status "RELEASE" "Setting public access for $version..."
            ./scripts/s3-manager.sh sync-public "$version" "$make_public"
            ;;
        *)
            print_status "ERROR" "Unknown S3 action: $action"
            print_status "INFO" "Available actions: upload, download, list, urls, public"
            return 1
            ;;
    esac
}

# Function to show status
show_status() {
    print_status "INFO" "Release Status"
    echo "=============================================="

    echo
    print_status "INFO" "Git Information:"
    echo "  Branch: $(git branch --show-current)"
    echo "  Commit: $(git rev-parse --short HEAD)"
    echo "  Clean:  $([ -z "$(git status --porcelain)" ] && echo "Yes" || echo "No")"

    echo
    print_status "INFO" "Latest Tags:"
    git tag -l "v*" | sort -V | tail -5 | sed 's/^/  /'

    echo
    print_status "INFO" "Local Releases:"
    if [ -d "releases" ]; then
        find releases -maxdepth 1 -type d -name "v*" | sort | tail -5 | sed 's/releases\///; s/^/  /'
    else
        echo "  None found"
    fi

    echo
    print_status "INFO" "S3 Integration:"
    if command -v "./scripts/s3-manager.sh" &> /dev/null; then
        if ./scripts/s3-manager.sh check &> /dev/null; then
            echo "  ✅ S3 manager available and configured"
            # Show recent S3 releases
            echo
            print_status "INFO" "Recent S3 Releases:"
            ./scripts/s3-manager.sh list-releases 2>/dev/null | head -5 | sed 's/^/  /' || echo "  No S3 releases found"
        else
            echo "  ⚠️  S3 manager available but not configured"
        fi
    else
        echo "  ❌ S3 manager not found"
    fi

    echo
    print_status "INFO" "GitHub CLI Status:"
    if command -v gh > /dev/null 2>&1; then
        if gh auth status > /dev/null 2>&1; then
            echo "  ✅ Installed and authenticated"
        else
            echo "  ⚠️  Installed but not authenticated"
        fi
    else
        echo "  ❌ Not installed"
    fi
}

# Main script logic
case "${1:-help}" in
    "create")
        version="$2"
        message="${3:-Release $version}"

        if [ -z "$version" ]; then
            print_status "ERROR" "Version required"
            show_help
            exit 1
        fi

        validate_version "$version" || exit 1
        check_git_status || exit 1
        create_git_tag "$version" "$message"
        ;;

    "delete")
        version="$2"

        if [ -z "$version" ]; then
            print_status "ERROR" "Version required"
            exit 1
        fi

        delete_git_tag "$version"
        ;;

    "list")
        list_releases
        ;;

    "github")
        version="$2"
        prerelease="${3:-false}"

        if [ -z "$version" ]; then
            print_status "ERROR" "Version required"
            exit 1
        fi

        validate_version "$version" || exit 1
        trigger_github_release "$version" "$prerelease"
        ;;

    "local")
        version="$2"
        upload_s3="$3"

        if [ -z "$version" ]; then
            print_status "ERROR" "Version required"
            exit 1
        fi

        validate_version "$version" || exit 1
        check_git_status || exit 1
        build_local_release "$version" "$upload_s3"
        ;;

    "s3")
        action="$2"
        version="$3"
        options="$4"

        if [ -z "$action" ]; then
            print_status "ERROR" "S3 action required"
            print_status "INFO" "Available actions: upload, download, list, urls, public"
            exit 1
        fi

        if ! command -v "./scripts/s3-manager.sh" &> /dev/null; then
            print_status "ERROR" "S3 manager script not found"
            exit 1
        fi

        manage_s3_release "$action" "$version" "$options"
        ;;

    "status")
        show_status
        ;;

    "help"|*)
        show_help
        ;;
esac
