# Package Manager Registration Guide for rudu

This document provides step-by-step instructions for registering `rudu` with various package managers.

## Prerequisites

1. Ensure you have a stable release (v0.1.0 or later)
2. All binaries are built and available in GitHub releases
3. Calculate SHA256 checksums for all release assets

## Package Managers

### 1. Homebrew (macOS)

**Status:** ✅ Formula ready, needs tap setup

**Steps:**
1. Create a tap repository: `ayungavis/homebrew-tap`
2. Calculate SHA256: `curl -sL https://github.com/ayungavis/rudu/archive/v0.1.0.tar.gz | shasum -a 256`
3. Update `homebrew/rudu.rb` with correct SHA256
4. Copy formula to tap repository
5. Users install with: `brew tap ayungavis/tap && brew install rudu`

### 2. Cargo (crates.io)

**Status:** ✅ Ready to publish

**Steps:**
1. `cargo login` (with your crates.io token)
2. `cargo publish`
3. Users install with: `cargo install rudu`

### 3. Arch Linux (AUR)

**Status:** ✅ PKGBUILD ready

**Steps:**
1. Run `./scripts/package.sh arch` to generate PKGBUILD
2. Create AUR account and SSH key
3. Clone AUR repo: `git clone ssh://aur@aur.archlinux.org/rudu.git`
4. Copy PKGBUILD and update checksums with `updpkgsums`
5. Test with `makepkg -si`
6. Submit: `git add . && git commit -m "Initial import" && git push`

### 4. Debian/Ubuntu

**Status:** ✅ DEB package script ready

**Steps:**
1. Run `./scripts/package.sh deb` to create .deb package
2. For official repos: Submit to Debian mentors or Ubuntu PPA
3. Users install with: `sudo dpkg -i rudu_0.1.0_amd64.deb`

### 5. Red Hat/Fedora/CentOS

**Status:** ✅ RPM spec ready

**Steps:**
1. Run `./scripts/package.sh rpm` to create spec file
2. Build RPM: `rpmbuild -ba dist/rpm/rudu.spec`
3. For official repos: Submit to Fedora Package Review
4. Users install with: `sudo rpm -i rudu-0.1.0-1.rpm`

### 6. Scoop (Windows)

**Status:** ✅ Manifest ready

**Steps:**
1. Calculate SHA256 for Windows release
2. Update `scoop/rudu.json` with correct hash
3. Submit PR to scoop-extras bucket
4. Users install with: `scoop install rudu`

### 7. Chocolatey (Windows)

**Status:** ✅ Package ready

**Steps:**
1. Calculate SHA256 for Windows release
2. Update `chocolatey/tools/chocolateyinstall.ps1` with correct checksum
3. Create account on chocolatey.org
4. Submit package for moderation
5. Users install with: `choco install rudu`

### 8. Nix/NixOS

**Status:** ✅ Expression ready

**Steps:**
1. Calculate nix hash: `nix-prefetch-github ayungavis rudu --rev v0.1.0`
2. Update `nix/rudu.nix` with correct hashes
3. Submit PR to nixpkgs repository
4. Users install with: `nix-env -iA nixpkgs.rudu`

## Automation

Consider setting up GitHub Actions to automatically:
1. Calculate checksums when releases are created
2. Update package manager configurations
3. Submit to package repositories (where APIs are available)

## Maintenance

When releasing new versions:
1. Update version numbers in all package configurations
2. Recalculate all checksums
3. Update package repositories
4. Test installations on different platforms
