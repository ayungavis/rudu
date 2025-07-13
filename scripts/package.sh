#!/bin/bash

# Package creation script for rudu
# This script creates packages for various Linux distributions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY_NAME="rudu"
VERSION="${VERSION:-$(grep '^version = ' "$PROJECT_DIR/Cargo.toml" | sed 's/version = "\(.*\)"/\1/')}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Build the binary
build_binary() {
    log "Building $BINARY_NAME v$VERSION..."
    cd "$PROJECT_DIR"
    cargo build --release
    
    if [ ! -f "target/release/$BINARY_NAME" ]; then
        error "Binary not found after build"
    fi
}

# Create DEB package
create_deb() {
    log "Creating DEB package..."
    
    local pkg_dir="$PROJECT_DIR/dist/deb"
    local bin_dir="$pkg_dir/usr/local/bin"
    local doc_dir="$pkg_dir/usr/share/doc/$BINARY_NAME"
    local man_dir="$pkg_dir/usr/share/man/man1"
    
    # Create directory structure
    mkdir -p "$bin_dir" "$doc_dir" "$man_dir"
    mkdir -p "$pkg_dir/DEBIAN"
    
    # Copy binary
    cp "$PROJECT_DIR/target/release/$BINARY_NAME" "$bin_dir/"
    chmod 755 "$bin_dir/$BINARY_NAME"
    
    # Copy documentation
    cp "$PROJECT_DIR/README.md" "$doc_dir/"
    
    # Create control file
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: $BINARY_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Maintainer: ayungavis <your-email@example.com>
Description: Fast, parallel Rust CLI tool for analyzing directory sizes
 A modern, performant alternative to du with a focus on identifying
 space-consuming directories quickly using parallel processing.
EOF
    
    # Build package
    cd "$PROJECT_DIR/dist"
    dpkg-deb --build deb "${BINARY_NAME}_${VERSION}_amd64.deb"
    
    log "DEB package created: dist/${BINARY_NAME}_${VERSION}_amd64.deb"
}

# Create RPM spec file
create_rpm_spec() {
    log "Creating RPM spec file..."
    
    local spec_dir="$PROJECT_DIR/dist/rpm"
    mkdir -p "$spec_dir"
    
    cat > "$spec_dir/$BINARY_NAME.spec" << EOF
Name:           $BINARY_NAME
Version:        $VERSION
Release:        1%{?dist}
Summary:        Fast, parallel Rust CLI tool for analyzing directory sizes

License:        MIT
URL:            https://github.com/ayungavis/rudu
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust cargo
Requires:       glibc

%description
A modern, performant alternative to du with a focus on identifying
space-consuming directories quickly using parallel processing.

%prep
%autosetup

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 755 target/release/%{name} %{buildroot}%{_bindir}/%{name}

%files
%{_bindir}/%{name}
%doc README.md

%changelog
* $(date +'%a %b %d %Y') ayungavis <your-email@example.com> - $VERSION-1
- Initial package
EOF
    
    log "RPM spec file created: dist/rpm/$BINARY_NAME.spec"
}

# Create Arch Linux PKGBUILD
create_pkgbuild() {
    log "Creating Arch Linux PKGBUILD..."
    
    local arch_dir="$PROJECT_DIR/dist/arch"
    mkdir -p "$arch_dir"
    
    cat > "$arch_dir/PKGBUILD" << EOF
# Maintainer: ayungavis <your-email@example.com>
pkgname=$BINARY_NAME
pkgver=$VERSION
pkgrel=1
pkgdesc="Fast, parallel Rust CLI tool for analyzing directory sizes"
arch=('x86_64')
url="https://github.com/ayungavis/rudu"
license=('MIT')
depends=('glibc')
makedepends=('rust' 'cargo')
source=("\$pkgname-\$pkgver.tar.gz::https://github.com/ayungavis/rudu/archive/v\$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
    cd "\$pkgname-\$pkgver"
    cargo build --release --locked
}

package() {
    cd "\$pkgname-\$pkgver"
    install -Dm755 "target/release/\$pkgname" "\$pkgdir/usr/bin/\$pkgname"
    install -Dm644 README.md "\$pkgdir/usr/share/doc/\$pkgname/README.md"
}
EOF
    
    log "PKGBUILD created: dist/arch/PKGBUILD"
}

# Create AppImage
create_appimage() {
    log "Creating AppImage..."
    
    local appdir="$PROJECT_DIR/dist/AppDir"
    mkdir -p "$appdir/usr/bin"
    
    # Copy binary
    cp "$PROJECT_DIR/target/release/$BINARY_NAME" "$appdir/usr/bin/"
    
    # Create desktop file
    cat > "$appdir/$BINARY_NAME.desktop" << EOF
[Desktop Entry]
Name=rudu
Exec=rudu
Icon=rudu
Type=Application
Categories=System;
EOF
    
    # Create AppRun
    cat > "$appdir/AppRun" << EOF
#!/bin/bash
SELF=\$(readlink -f "\$0")
HERE=\${SELF%/*}
export PATH="\${HERE}/usr/bin/:\${PATH}"
exec "\${HERE}/usr/bin/$BINARY_NAME" "\$@"
EOF
    chmod +x "$appdir/AppRun"
    
    # Download appimagetool if needed
    if [ ! -f "$PROJECT_DIR/dist/appimagetool" ]; then
        log "Downloading appimagetool..."
        wget -O "$PROJECT_DIR/dist/appimagetool" \
            "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x "$PROJECT_DIR/dist/appimagetool"
    fi
    
    # Create AppImage
    cd "$PROJECT_DIR/dist"
    ./appimagetool AppDir "$BINARY_NAME-$VERSION-x86_64.AppImage"
    
    log "AppImage created: dist/$BINARY_NAME-$VERSION-x86_64.AppImage"
}

# Calculate checksums for releases
calculate_checksums() {
    log "Calculating checksums for release assets..."

    local base_url="https://github.com/ayungavis/rudu"

    echo "# Checksums for rudu v$VERSION"
    echo "# Generated on $(date)"
    echo ""

    # Source tarball
    echo "## Source"
    local source_url="$base_url/archive/v$VERSION.tar.gz"
    echo "URL: $source_url"
    if command -v curl >/dev/null 2>&1; then
        local source_sha=$(curl -sL "$source_url" | shasum -a 256 | cut -d' ' -f1)
        echo "SHA256: $source_sha"
    else
        echo "SHA256: (curl not available - calculate manually)"
    fi
    echo ""

    # Release binaries
    echo "## Release Binaries"
    for asset in \
        "rudu-linux-x86_64.tar.gz" \
        "rudu-linux-x86_64-musl.tar.gz" \
        "rudu-macos-x86_64.tar.gz" \
        "rudu-macos-aarch64.tar.gz" \
        "rudu-windows-x86_64.zip"
    do
        local asset_url="$base_url/releases/download/v$VERSION/$asset"
        echo "Asset: $asset"
        echo "URL: $asset_url"
        if command -v curl >/dev/null 2>&1; then
            local asset_sha=$(curl -sL "$asset_url" | shasum -a 256 | cut -d' ' -f1)
            echo "SHA256: $asset_sha"
        else
            echo "SHA256: (curl not available - calculate manually)"
        fi
        echo ""
    done
}

# Main function
main() {
    log "Creating packages for $BINARY_NAME v$VERSION..."

    # Create dist directory
    mkdir -p "$PROJECT_DIR/dist"

    # Build binary
    build_binary

    # Create packages based on arguments
    case "${1:-all}" in
        deb)
            create_deb
            ;;
        rpm)
            create_rpm_spec
            ;;
        arch)
            create_pkgbuild
            ;;
        appimage)
            create_appimage
            ;;
        checksums)
            calculate_checksums
            ;;
        all)
            create_deb
            create_rpm_spec
            create_pkgbuild
            create_appimage
            ;;
        *)
            echo "Usage: $0 [deb|rpm|arch|appimage|checksums|all]"
            exit 1
            ;;
    esac

    log "Packaging complete!"
}

main "$@" 