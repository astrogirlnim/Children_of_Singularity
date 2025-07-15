#!/bin/bash

# build.sh
# Build script for Children of the Singularity desktop game
# Handles development runs and production builds

set -e

echo "🎮 Children of the Singularity Build System"
echo "============================================"

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
    "status")
        show_status
        ;;
    "clean")
        print_status "INFO" "Cleaning build directories..."
        rm -rf builds/
        print_status "SUCCESS" "Build directories cleaned"
        ;;
    "help"|*)
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  dev, run    - Run the game in development mode (default)"
        echo "  debug, test - Validate game logic without graphics"
        echo "  dist, build - Build distribution packages (requires export templates)"
        echo "  status      - Show current build status"
        echo "  clean       - Remove build directories"
        echo "  help        - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 dev      # Run the game for development/testing"
        echo "  $0 debug    # Test game logic"
        echo "  $0 dist     # Build for distribution"
        echo "  $0 status   # Check build status"
        ;;
esac
