#!/bin/bash

# build.sh
# Build script for Children of the Singularity desktop game
# Handles development runs, production builds, and release packaging

set -e

echo "🎮 Children of the Singularity Build System"
echo "============================================"

# Version information
VERSION=${GITHUB_REF_NAME:-"dev-$(date +%Y%m%d-%H%M%S)"}
BUILD_NUMBER=${GITHUB_RUN_NUMBER:-"local"}
COMMIT_HASH=${GITHUB_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    case $1 in
        "ERROR")
            echo -e "${RED}❌ $2${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ $2${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $2${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}📋 $2${NC}"
            ;;
        *)
            echo "📋 $2"
            ;;
    esac
}

# Check if we're in the right directory
if [ ! -f "project.godot" ]; then
    print_status "ERROR" "Not in the project root directory. Please run from the Children_of_Singularity directory."
    exit 1
fi

# Function to run the game in development mode
run_dev() {
    print_status "INFO" "Starting Children of the Singularity in development mode..."
    print_status "INFO" "Press Ctrl+C to stop the game"
    print_status "INFO" "Game logs will appear below:"
    echo "============================================"

    # Run the game directly
    godot --run-project .
}

# Function to run the game in debug mode (validation only)
run_debug() {
    print_status "INFO" "Running game validation checks..."
    print_status "INFO" "This will check project files without running the game"

    # Check main scene exists
    if [ ! -f "scenes/zones/ZoneMain3D.tscn" ]; then
        print_status "ERROR" "Main scene file not found: scenes/zones/ZoneMain3D.tscn"
        exit 1
    fi

    # Check critical game files
    critical_files=(
        "scripts/PlayerShip3D.gd"
        "scripts/ZoneMain3D.gd"
        "scripts/DebrisObject3D.gd"
        "scripts/SpaceStationModule3D.gd"
    )

    for file in "${critical_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_status "ERROR" "Critical file missing: $file"
            exit 1
        else
            print_status "SUCCESS" "Found: $file"
        fi
    done

    # Test script parsing without running
    print_status "INFO" "Checking GDScript syntax..."
    godot --headless --check-only . 2>/dev/null

    if [ $? -eq 0 ]; then
        print_status "SUCCESS" "All GDScript files have valid syntax!"
    else
        print_status "WARNING" "Some script syntax issues detected"
    fi

    print_status "SUCCESS" "Game project validation complete!"
}

# Function to check export templates
check_export_templates() {
    print_status "INFO" "Checking export templates..."

    TEMPLATE_PATH="$HOME/Library/Application Support/Godot/export_templates/4.4.1.stable"

    if [ ! -d "$TEMPLATE_PATH" ]; then
        print_status "WARNING" "Export templates not found at: $TEMPLATE_PATH"
        print_status "INFO" "To build for distribution, you need to:"
        print_status "INFO" "1. Open Godot Editor"
        print_status "INFO" "2. Go to Editor -> Manage Export Templates..."
        print_status "INFO" "3. Download templates for version 4.4.1"
        print_status "INFO" "Or download from: https://downloads.tuxfamily.org/godotengine/4.4.1/"
        return 1
    else
        print_status "SUCCESS" "Export templates found!"
        return 0
    fi
}

# Function to build for distribution (if templates available)
build_dist() {
    print_status "INFO" "Preparing distribution build..."

    # Check templates first
    if ! check_export_templates; then
        print_status "ERROR" "Cannot build distribution without export templates"
        exit 1
    fi

    # Create build directories
    mkdir -p builds/{macos,windows,linux}

    # Export for macOS (current platform)
    print_status "INFO" "Building for macOS..."
    if godot --headless --export "macOS" builds/macos/Children_of_Singularity.app 2>/dev/null; then
        print_status "SUCCESS" "macOS build complete: builds/macos/Children_of_Singularity.app"
    else
        print_status "ERROR" "macOS build failed"
    fi

    # Export for Windows
    print_status "INFO" "Building for Windows..."
    if godot --headless --export "Windows Desktop" builds/windows/Children_of_Singularity.exe 2>/dev/null; then
        print_status "SUCCESS" "Windows build complete: builds/windows/Children_of_Singularity.exe"
    else
        print_status "WARNING" "Windows build failed (may need Windows export templates)"
    fi

    # Export for Linux
    print_status "INFO" "Building for Linux..."
    if godot --headless --export "Linux/X11" builds/linux/Children_of_Singularity.x86_64 2>/dev/null; then
        print_status "SUCCESS" "Linux build complete: builds/linux/Children_of_Singularity.x86_64"
    else
        print_status "WARNING" "Linux build failed (may need Linux export templates)"
    fi
}

# Function to show build status
show_status() {
    print_status "INFO" "Build Status:"
    echo "============================================"

    # Check if builds exist
    if [ -d "builds" ]; then
        if [ -e "builds/macos/Children_of_Singularity.app" ]; then
            print_status "SUCCESS" "macOS build: builds/macos/Children_of_Singularity.app"
        fi

        if [ -e "builds/windows/Children_of_Singularity.exe" ]; then
            print_status "SUCCESS" "Windows build: builds/windows/Children_of_Singularity.exe"
        fi

        if [ -e "builds/linux/Children_of_Singularity.x86_64" ]; then
            print_status "SUCCESS" "Linux build: builds/linux/Children_of_Singularity.x86_64"
        fi
    else
        print_status "INFO" "No distribution builds found. Run './build.sh dist' to create them."
    fi

    check_export_templates
}

# Function to build release packages for all platforms
build_release() {
    print_status "INFO" "Building release packages for all platforms..."
    print_status "INFO" "Version: $VERSION (Build #$BUILD_NUMBER, Commit: $COMMIT_HASH)"

    # Check for export templates
    check_export_templates

    # Create release directory structure
    local release_dir="releases/$VERSION"
    mkdir -p "$release_dir"

    # Download assets from S3 if available
    download_assets_from_s3

    # Build for all platforms
    build_platform "Windows Desktop" "windows" "$release_dir/windows" ".exe"
    build_platform "macOS" "macos" "$release_dir/macos" ".app"
    build_platform "Linux/X11" "linux" "$release_dir/linux" ""

    # Create compressed archives
    create_release_archives "$release_dir"

    # Generate release notes
    generate_release_notes "$release_dir"

    # Upload release to S3 if configured
    upload_release_to_s3 "$VERSION" "$release_dir"

    print_status "SUCCESS" "Release build completed: $release_dir"
}

# Function to build for a specific platform
build_platform() {
    local platform_name="$1"
    local preset_name="$2"
    local output_dir="$3"
    local extension="$4"

    print_status "INFO" "Building for $platform_name..."

    mkdir -p "$output_dir"
    local output_file="$output_dir/Children_of_Singularity$extension"

    # Export the game
    if godot --headless --export-release "$preset_name" "$output_file" .; then
        print_status "SUCCESS" "Built for $platform_name: $output_file"

        # Copy additional assets if needed
        if [ -f "README.md" ]; then
            cp "README.md" "$output_dir/"
        fi
        if [ -f "LICENSE" ]; then
            cp "LICENSE" "$output_dir/"
        fi

    else
        print_status "ERROR" "Failed to build for $platform_name"
        return 1
    fi
}

# Function to create compressed release archives
create_release_archives() {
    local release_dir="$1"

    print_status "INFO" "Creating release archives..."

    cd "$release_dir"

    # Create zip archives for each platform
    if [ -d "windows" ]; then
        zip -r "Children_of_Singularity_${VERSION}_Windows.zip" windows/
        print_status "SUCCESS" "Created Windows archive"
    fi

    if [ -d "macos" ]; then
        zip -r "Children_of_Singularity_${VERSION}_macOS.zip" macos/
        print_status "SUCCESS" "Created macOS archive"
    fi

    if [ -d "linux" ]; then
        tar -czf "Children_of_Singularity_${VERSION}_Linux.tar.gz" linux/
        print_status "SUCCESS" "Created Linux archive"
    fi

    cd - > /dev/null
}

# Function to generate release notes
generate_release_notes() {
    local release_dir="$1"
    local notes_file="$release_dir/RELEASE_NOTES.md"

    print_status "INFO" "Generating release notes..."

    cat > "$notes_file" << EOF
# Children of the Singularity - Release $VERSION

**Build Information:**
- Version: $VERSION
- Build Number: $BUILD_NUMBER
- Commit: $COMMIT_HASH
- Build Date: $(date)

## Platform Downloads

| Platform | Download | Notes |
|----------|----------|--------|
| Windows | Children_of_Singularity_${VERSION}_Windows.zip | Windows 10+ (64-bit) |
| macOS | Children_of_Singularity_${VERSION}_macOS.zip | macOS 10.15+ (Universal) |
| Linux | Children_of_Singularity_${VERSION}_Linux.tar.gz | Linux (64-bit) |

## Installation

### Windows
1. Download and extract the Windows zip file
2. Run \`Children_of_Singularity.exe\`

### macOS
1. Download and extract the macOS zip file
2. Run \`Children_of_Singularity.app\`
3. If blocked by security, right-click and select "Open"

### Linux
1. Download and extract the Linux tar.gz file
2. Make executable: \`chmod +x Children_of_Singularity\`
3. Run: \`./Children_of_Singularity\`

## Game Features

- **3D Space Exploration**: Navigate through procedurally populated space zones
- **Debris Collection**: Collect valuable space debris and artifacts
- **Space Station Trading**: Interact with modular space stations
- **Resource Management**: Manage collected resources and ship upgrades
- **Dynamic Environment**: Real-time debris spawning and despawning system

## System Requirements

- **Minimum**:
  - OS: Windows 10 / macOS 10.15 / Ubuntu 18.04
  - CPU: 2 GHz dual-core processor
  - Memory: 4 GB RAM
  - Graphics: Integrated graphics or dedicated GPU
  - Storage: 500 MB available space

- **Recommended**:
  - OS: Windows 11 / macOS 12+ / Ubuntu 20.04+
  - CPU: 3 GHz quad-core processor
  - Memory: 8 GB RAM
  - Graphics: Dedicated GPU with 2GB VRAM
  - Storage: 1 GB available space

## Controls

- **WASD** / **Arrow Keys**: Move ship
- **Mouse**: Camera control
- **Space**: Collect debris (when near)
- **Escape**: Pause/Menu

## Known Issues

- Export templates required for building from source
- Some debris may occasionally flicker during collection

## Support

For issues or feedback, please visit our GitHub repository.

---

*Built with Godot 4.4.1*
EOF

    print_status "SUCCESS" "Generated release notes: $notes_file"
}

# Function to download assets from S3 if available
download_assets_from_s3() {
    if [ "$USE_S3_ASSETS" = "true" ]; then
        print_status "INFO" "Checking for assets in S3..."

        if command -v "./scripts/s3-manager.sh" &> /dev/null; then
            # Download latest assets from S3
            ./scripts/s3-manager.sh download-assets latest-assets assets/ 2>/dev/null || {
                print_status "WARNING" "Failed to download assets from S3, using local assets"
            }
        else
            print_status "WARNING" "S3 manager not found, using local assets only"
        fi
    fi
}

# Function to upload release to S3 if configured
upload_release_to_s3() {
    local version="$1"
    local release_dir="$2"

    if [ "$USE_S3_STORAGE" = "true" ]; then
        print_status "INFO" "Uploading release to S3..."

        if command -v "./scripts/s3-manager.sh" &> /dev/null; then
            # Set environment variables for S3 manager
            export BUILD_NUMBER="$BUILD_NUMBER"
            export COMMIT_HASH="$COMMIT_HASH"

            if ./scripts/s3-manager.sh upload-release "$version" "$release_dir"; then
                print_status "SUCCESS" "Release uploaded to S3"

                # Generate download URLs
                print_status "INFO" "Generating download URLs..."
                ./scripts/s3-manager.sh get-urls "$version" 86400 > "$release_dir/download-urls.txt"

            else
                print_status "WARNING" "Failed to upload release to S3"
            fi
        else
            print_status "WARNING" "S3 manager not found, skipping S3 upload"
        fi
    fi
}

# Function to upload development assets to S3
upload_dev_assets() {
    if [ "$USE_S3_ASSETS" = "true" ]; then
        print_status "INFO" "Uploading development assets to S3..."

        if command -v "./scripts/s3-manager.sh" &> /dev/null; then
            # Upload key asset directories
            for asset_dir in assets/sprites assets/textures; do
                if [ -d "$asset_dir" ]; then
                    local asset_key=$(basename "$asset_dir")
                    ./scripts/s3-manager.sh upload-assets "$asset_dir/" "dev/$asset_key/" || {
                        print_status "WARNING" "Failed to upload $asset_dir to S3"
                    }
                fi
            done

            # Mark as latest assets
            ./scripts/s3-manager.sh upload-assets assets/ latest-assets/ || {
                print_status "WARNING" "Failed to upload latest assets marker"
            }

            print_status "SUCCESS" "Development assets uploaded to S3"
        else
            print_status "WARNING" "S3 manager not found, skipping asset upload"
        fi
    fi
}

# Function to download documentation assets from S3
download_documentation_assets() {
    if [ "$USE_S3_ASSETS" = "true" ]; then
        print_status "INFO" "Downloading documentation assets from S3..."

        if command -v "./scripts/s3-manager.sh" &> /dev/null; then
            # Download documentation assets if they don't exist locally
            if [ ! -d "documentation/design" ] || [ -z "$(ls -A documentation/design 2>/dev/null)" ]; then
                ./scripts/s3-manager.sh download-assets documentation/ documentation/design/ 2>/dev/null || {
                    print_status "WARNING" "Failed to download documentation assets from S3"
                    print_status "INFO" "Documentation assets are stored in S3, not locally"
                    return 1
                }
                print_status "SUCCESS" "Documentation assets downloaded from S3"
            else
                print_status "INFO" "Documentation assets already exist locally"
            fi
        else
            print_status "WARNING" "S3 manager not found, cannot download documentation assets"
            return 1
        fi
    else
        print_status "INFO" "S3 assets disabled, documentation assets should be available locally"
    fi
}

# Function to clean old releases (keep only latest N releases)
clean_old_releases() {
    local keep_count=${1:-1}

    print_status "INFO" "Cleaning old releases (keeping latest $keep_count)..."

    # Clean local releases
    if [ -d "releases" ]; then
        # List releases by modification time and remove old ones
        cd releases
        ls -1t | tail -n +$((keep_count + 1)) | xargs -r rm -rf
        cd - > /dev/null
        print_status "SUCCESS" "Cleaned local old releases"
    else
        print_status "INFO" "No local releases directory found"
    fi

    # Clean S3 releases if configured
    if [ "$USE_S3_STORAGE" = "true" ] && command -v "./scripts/s3-manager.sh" &> /dev/null; then
        print_status "INFO" "Cleaning old development builds in S3..."
        ./scripts/s3-manager.sh cleanup-dev 7 || {
            print_status "WARNING" "Failed to clean S3 development builds"
        }
    fi
}

# Main script logic
case "${1:-help}" in
    "dev"|"run")
        run_dev
        ;;
    "debug"|"test")
        run_debug
        ;;
    "dist"|"build")
        build_dist
        ;;
    "release")
        build_release
        ;;
    "clean-releases")
        clean_old_releases "${2:-1}"
        ;;
    "upload-assets")
        upload_dev_assets
        ;;
    "download-assets")
        if [ "$USE_S3_ASSETS" != "true" ]; then
            export USE_S3_ASSETS=true
        fi
        download_assets_from_s3
        ;;
    "upload-docs")
        if command -v "./scripts/s3-manager.sh" &> /dev/null; then
            ./scripts/s3-manager.sh upload-assets documentation/design/ documentation/
            print_status "SUCCESS" "Documentation assets uploaded to S3"
        else
            print_status "ERROR" "S3 manager not found"
            exit 1
        fi
        ;;
    "download-docs")
        if [ "$USE_S3_ASSETS" != "true" ]; then
            export USE_S3_ASSETS=true
        fi
        download_documentation_assets
        ;;
    "s3-status")
        if command -v "./scripts/s3-manager.sh" &> /dev/null; then
            ./scripts/s3-manager.sh storage-info
        else
            print_status "ERROR" "S3 manager not found"
            exit 1
        fi
        ;;
    "status")
        show_status
        ;;
    "clean")
        print_status "INFO" "Cleaning build directories..."
        rm -rf builds/ releases/
        print_status "SUCCESS" "Build directories cleaned"
        ;;
    "help"|*)
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Commands:"
        echo "  dev, run          - Run the game in development mode (default)"
        echo "  debug, test       - Validate game logic without graphics"
        echo "  dist, build       - Build distribution packages (requires export templates)"
        echo "  release           - Build complete release packages for all platforms"
        echo "  clean-releases    - Clean old releases (usage: clean-releases [keep_count])"
        echo "  upload-assets     - Upload development assets to S3"
        echo "  download-assets   - Download assets from S3"
        echo "  upload-docs       - Upload documentation assets to S3"
        echo "  download-docs     - Download documentation assets from S3"
        echo "  s3-status         - Show S3 storage information"
        echo "  status            - Show current build status"
        echo "  clean             - Remove build and release directories"
        echo "  help              - Show this help message"
        echo ""
        echo "S3 Environment Variables:"
        echo "  USE_S3_STORAGE=true    - Enable S3 upload for releases"
        echo "  USE_S3_ASSETS=true     - Enable S3 download/upload for assets"
        echo "  S3_BUCKET_NAME         - S3 bucket name (default: children-of-singularity-releases)"
        echo "  AWS_REGION             - AWS region (default: us-west-2)"
        echo ""
        echo "Examples:"
        echo "  $0 dev                          # Run the game for development/testing"
        echo "  $0 debug                        # Test game logic"
        echo "  $0 dist                         # Build for distribution"
        echo "  USE_S3_STORAGE=true $0 release  # Build and upload to S3"
        echo "  $0 upload-assets                # Upload assets to S3"
        echo "  $0 upload-docs                  # Upload documentation assets to S3"
        echo "  $0 download-docs                # Download documentation assets from S3"
        echo "  $0 s3-status                    # Check S3 storage usage"
        ;;
esac
