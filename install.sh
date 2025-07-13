#!/bin/bash

# rudu installer script
# This script detects the platform and downloads the appropriate binary

set -e

# Configuration
REPO="ayungavis/rudu"
BINARY_NAME="rudu"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Detect platform
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case $os in
        linux*)
            case $arch in
                x86_64)
                    # Check if we should use musl for better compatibility
                    if should_use_musl; then
                        echo "rudu-linux-x86_64-musl"
                    else
                        echo "rudu-linux-x86_64"
                    fi
                    ;;
                *)
                    error "Unsupported architecture: $arch"
                    ;;
            esac
            ;;
        darwin*)
            case $arch in
                x86_64)
                    echo "rudu-macos-x86_64"
                    ;;
                arm64)
                    echo "rudu-macos-aarch64"
                    ;;
                *)
                    error "Unsupported architecture: $arch"
                    ;;
            esac
            ;;
        cygwin*|mingw*|msys*)
            case $arch in
                x86_64)
                    echo "rudu-windows-x86_64"
                    ;;
                *)
                    error "Unsupported architecture: $arch"
                    ;;
            esac
            ;;
        *)
            error "Unsupported operating system: $os"
            ;;
    esac
}

# Check if we should use musl binary for better compatibility
should_use_musl() {
    # Check for older distributions that might have glibc compatibility issues
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            centos|rhel|rocky|almalinux)
                # Use musl for RHEL-based distributions
                return 0
                ;;
            alpine)
                # Alpine uses musl by default
                return 0
                ;;
            debian|ubuntu)
                # Check version for older Debian/Ubuntu
                case "$VERSION_ID" in
                    16.04|18.04|8|9)
                        return 0
                        ;;
                esac
                ;;
        esac
    fi

    # Check glibc version if available
    if command -v ldd >/dev/null 2>&1; then
        local glibc_version=$(ldd --version 2>/dev/null | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
        if [ -n "$glibc_version" ]; then
            # Use musl if glibc is older than 2.31 (approximate threshold)
            local major=$(echo "$glibc_version" | cut -d. -f1)
            local minor=$(echo "$glibc_version" | cut -d. -f2)
            if [ "$major" -lt 2 ] || ([ "$major" -eq 2 ] && [ "$minor" -lt 31 ]); then
                return 0
            fi
        fi
    fi

    # Default to glibc version
    return 1
}

# Get latest release version
get_latest_version() {
    local version=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$version" ]; then
        error "Failed to get latest version"
    fi
    echo "$version"
}

# Download and install binary
install_binary() {
    local platform=$1
    local version=$2
    local temp_dir=$(mktemp -d)

    log "Downloading $BINARY_NAME $version for $platform..."

    # Determine file extension and download URL
    if [[ $platform == *"windows"* ]]; then
        local archive_name="$platform.zip"
        local download_url="https://github.com/$REPO/releases/download/$version/$archive_name"
    else
        local archive_name="$platform.tar.gz"
        local download_url="https://github.com/$REPO/releases/download/$version/$archive_name"
    fi

    # Download the archive
    if ! curl -L -o "$temp_dir/$archive_name" "$download_url"; then
        error "Failed to download $download_url"
    fi

    # Extract the binary
    log "Extracting binary..."
    if [[ $platform == *"windows"* ]]; then
        if ! unzip -q "$temp_dir/$archive_name" -d "$temp_dir"; then
            error "Failed to extract archive"
        fi
        # Windows binary has .exe extension
        local binary_name="$BINARY_NAME.exe"
    else
        if ! tar -xzf "$temp_dir/$archive_name" -C "$temp_dir"; then
            error "Failed to extract archive"
        fi
        local binary_name="$BINARY_NAME"
    fi
    
    # Install the binary
    log "Installing to $INSTALL_DIR..."
    if [ ! -w "$INSTALL_DIR" ]; then
        log "Need sudo privileges to install to $INSTALL_DIR"
        sudo mv "$temp_dir/$binary_name" "$INSTALL_DIR/$BINARY_NAME"
        sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"
    else
        mv "$temp_dir/$binary_name" "$INSTALL_DIR/$BINARY_NAME"
        chmod +x "$INSTALL_DIR/$BINARY_NAME"
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    log "Installation complete!"
    log "Run '$BINARY_NAME --help' to get started"
}

# Main installation flow
main() {
    log "Installing $BINARY_NAME..."
    
    # Check dependencies
    if ! command -v curl >/dev/null 2>&1; then
        error "curl is required but not installed"
    fi

    # Detect platform
    local platform=$(detect_platform)
    log "Detected platform: $platform"

    # Provide additional info for musl selection
    if [[ $platform == *"musl"* ]]; then
        log "Using musl binary for better compatibility with your system"
    fi

    # Check appropriate extraction tool based on platform
    if [[ $platform == *"windows"* ]]; then
        if ! command -v unzip >/dev/null 2>&1; then
            error "unzip is required but not installed"
        fi
    else
        if ! command -v tar >/dev/null 2>&1; then
            error "tar is required but not installed"
        fi
    fi

    # Get latest version
    local version=$(get_latest_version)
    log "Latest version: $version"

    # Install binary
    install_binary "$platform" "$version"
    
    # Verify installation
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        log "Verification successful: $($BINARY_NAME --version)"
    else
        warn "Binary installed but not found in PATH. You may need to add $INSTALL_DIR to your PATH"
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "rudu installer script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --version, -v Show version information"
        echo ""
        echo "Environment variables:"
        echo "  INSTALL_DIR   Installation directory (default: /usr/local/bin)"
        echo ""
        echo "The installer automatically detects your platform and selects the"
        echo "appropriate binary (glibc or musl) for maximum compatibility."
        echo ""
        echo "Examples:"
        echo "  $0                    # Install to /usr/local/bin"
        echo "  INSTALL_DIR=~/.local/bin $0  # Install to ~/.local/bin"
        exit 0
        ;;
    --version|-v)
        get_latest_version
        exit 0
        ;;
    *)
        main
        ;;
esac 