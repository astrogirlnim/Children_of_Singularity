# 🚀 Release Pipeline Documentation

This document explains how to use the automated release pipeline for Children of the Singularity.

## Overview

The release pipeline consists of:
- **Local Build System**: Enhanced `build.sh` script for development and local releases
- **Release Manager**: `scripts/release-manager.sh` for managing versions and triggering releases
- **GitHub Actions**: Automated multi-platform builds and release creation
- **Release Cleanup**: Automatic deletion of old releases (keeps only the latest)

## Quick Start

### 1. Create a New Release

```bash
# Create a git tag and trigger automated release
./scripts/release-manager.sh create v1.0.0 "Initial release"
./scripts/release-manager.sh github v1.0.0

# Or create a pre-release
./scripts/release-manager.sh github v1.1.0-beta true
```

### 2. Monitor Release Progress

```bash
# Check workflow status
gh run list --workflow=release.yml

# View real-time logs  
gh run view --log
```

### 3. Download and Test

Once the workflow completes, releases are available at:
`https://github.com/GauntletAI/Children_of_Singularity/releases`

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
```

### Release Manager

```bash
# Version management
./scripts/release-manager.sh create v1.0.0 "Release message"
./scripts/release-manager.sh delete v1.0.0
./scripts/release-manager.sh list

# Local releases
./scripts/release-manager.sh local v1.0.0

# GitHub integration
./scripts/release-manager.sh github v1.0.0
./scripts/release-manager.sh status
```

## GitHub Actions Workflow

### Triggers

The release workflow triggers on:
1. **Git tags**: Push a tag matching `v*` pattern (e.g., `v1.0.0`)
2. **Manual dispatch**: Run manually from GitHub Actions tab

### Workflow Steps

1. **🧹 Cleanup Old Releases**: Deletes all existing releases to keep only the latest
2. **🎮 Build Game**: 
   - Uses Godot 4.4.1 in Docker container
   - Builds for Windows, macOS, and Linux
   - Creates compressed archives for each platform
   - Generates comprehensive release notes
3. **🏷️ Create Release**: 
   - Creates new GitHub release
   - Uploads all platform archives
   - Adds detailed release notes with installation instructions

### Platform Support

| Platform | Archive Format | Export Preset | Notes |
|----------|---------------|---------------|--------|
| Windows | ZIP | Windows Desktop | .exe executable |
| macOS | ZIP | macOS | Universal .app bundle |
| Linux | TAR.GZ | Linux/X11 | .x86_64 executable |

## Release Versioning

### Version Format
- **Production**: `v1.0.0`, `v1.2.5`, `v2.0.0`
- **Pre-release**: `v1.1.0-beta`, `v2.0.0-rc1`

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

### Platform Archives
- `Children_of_Singularity_v1.0.0_Windows.zip`
- `Children_of_Singularity_v1.0.0_macOS.zip`  
- `Children_of_Singularity_v1.0.0_Linux.tar.gz`

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

## Security Considerations

- Release artifacts are excluded from git (`.gitignore`)
- GitHub token permissions limited to releases scope
- No sensitive data in release notes or artifacts
- Export templates verified during build process

## Performance

- **Build Time**: ~5-10 minutes for all platforms
- **Artifact Size**: ~50-100MB per platform
- **Cleanup**: Old releases deleted before new ones created
- **Retention**: Build artifacts kept for 1 day in GitHub Actions

---

## Support

For issues with the release pipeline:
1. Check this documentation
2. Review GitHub Actions logs
3. Test locally with release manager
4. Check Godot export preset configuration

**Pro Tips:**
- Always test locally before creating GitHub releases
- Use semantic versioning consistently
- Include meaningful commit messages in release tags
- Monitor GitHub Actions workflow runs
- Keep export templates updated with Godot version 