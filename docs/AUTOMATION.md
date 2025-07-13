# Package Manager Automation

This document describes the automated workflows for maintaining package manager configurations and submissions.

## Overview

The project includes four main automation workflows:

1. **Prepare Release** - Updates version in Cargo.toml and creates git tags
2. **Package Manager Updates** - Automatically updates package configurations when releases are published
3. **Submit to Package Repositories** - Automates submissions to package repositories where APIs are available
4. **Test Package Installations** - Validates that packages install and work correctly

## Workflows

### 1. Prepare Release (`.github/workflows/prepare-release.yml`)

**Triggers:**

- Manually via workflow dispatch

**What it does:**

- Updates version in Cargo.toml
- Updates version references in README.md
- Runs cargo check to ensure project builds
- Updates Cargo.lock
- Commits and pushes changes
- Optionally creates and pushes git tag

**Outputs:**

- Updated version in repository
- Git tag ready for release creation

### 2. Package Manager Updates (`.github/workflows/package-managers.yml`)

**Triggers:**

- Automatically when a release is published
- Manually via workflow dispatch

**What it does:**

- Calculates SHA256 checksums for all release assets
- Updates package manager configuration files with new version and checksums
- Updates Homebrew tap repository (if configured)
- Generates Linux package configurations (DEB, RPM, Arch)
- Creates AUR submission artifacts

**Outputs:**

- Updated package configuration files committed to repository
- AUR PKGBUILD artifact for manual submission
- Comprehensive summary of what was updated

### 3. Submit to Package Repositories (`.github/workflows/submit-packages.yml`)

**Triggers:**

- Automatically after Package Manager Updates workflow completes
- Manually via workflow dispatch

**What it does:**

- Publishes to crates.io (if `CRATES_TOKEN` secret is configured)
- Updates Homebrew tap repository
- Creates submission guides for manual package repositories
- Generates detailed instructions for AUR, Scoop, Chocolatey, etc.

**Outputs:**

- Package published to crates.io
- Updated Homebrew tap
- Submission guide artifacts with step-by-step instructions

### 4. Test Package Installations (`.github/workflows/test-packages.yml`)

**Triggers:**

- Automatically after Package Manager Updates workflow completes
- Manually via workflow dispatch

**What it does:**

- Tests Cargo installation from crates.io
- Tests Homebrew installation from tap
- Tests Linux package builds (DEB, AppImage, Arch PKGBUILD)
- Tests Nix expression build
- Runs integration tests to verify functionality

**Outputs:**

- Validation that packages install correctly
- Integration test results

## Setup Requirements

### Required Secrets

Add these secrets to your GitHub repository settings:

1. **`CRATES_TOKEN`** (Required for crates.io publishing)

   - Get from [crates.io/me](https://crates.io/me)
   - Used to automatically publish to crates.io

2. **`PACKAGE_UPDATE_TOKEN`** (Recommended for version updates)

   - Personal Access Token with repo permissions
   - Used to commit version updates and package configurations back to repository
   - Falls back to `GITHUB_TOKEN` if not provided (may have limited permissions)

3. **`HOMEBREW_TAP_TOKEN`** (Optional, for Homebrew tap updates)
   - Personal Access Token with repo permissions
   - Used to update your homebrew-tap repository
   - Falls back to `GITHUB_TOKEN` if not provided

### Repository Setup

1. **Homebrew Tap Repository**

   - Create a repository named `homebrew-tap` in your GitHub account
   - The workflow will automatically update it when releases are published

2. **Package Configuration Files**
   - All package manager configurations are automatically maintained
   - Files are updated and committed back to the repository

## Usage

### Automatic Usage (Recommended)

1. **Prepare a release** by running the Prepare Release workflow
2. **Create a GitHub release** using the created tag
3. **Package Manager Updates workflow** runs automatically
4. **Submit to Package Repositories workflow** runs automatically after updates complete
5. **Test Package Installations workflow** runs to validate everything works

### Manual Usage

You can trigger workflows manually for testing or specific versions:

```bash
# Prepare a release (updates Cargo.toml version and creates tag)
gh workflow run prepare-release.yml -f version=0.1.1 -f create_tag=true

# Trigger package manager updates for a specific version
gh workflow run package-managers.yml -f version=v0.1.1

# Submit to specific repositories
gh workflow run submit-packages.yml -f version=v0.1.1 -f repositories=crates,homebrew

# Test package installations
gh workflow run test-packages.yml -f version=v0.1.1
```

## Workflow Outputs

### Artifacts

Each workflow creates downloadable artifacts:

- **AUR PKGBUILD** - Ready-to-submit Arch Linux package
- **Package Submission Guide** - Detailed instructions for manual submissions
- **Checksums** - SHA256 hashes for all release assets

### Workflow Summaries

Each workflow provides a detailed summary showing:

- What was successfully updated/submitted
- What requires manual action
- Next steps and instructions

## Manual Submission Steps

Some package repositories require manual submission:

### 1. Arch Linux (AUR)

1. Download the AUR PKGBUILD artifact
2. Follow the instructions in the artifact
3. Submit to AUR using SSH

### 2. Scoop (Windows)

1. Fork the scoop-extras repository
2. Copy the updated `scoop/rudu.json` to the bucket
3. Submit a pull request

### 3. Chocolatey (Windows)

1. Create an account on chocolatey.org
2. Package the `chocolatey/` directory contents
3. Submit for moderation review

### 4. Nix/NixOS

1. Fork the nixpkgs repository
2. Add the `nix/rudu.nix` expression
3. Submit a pull request

### 5. Official Linux Repositories

1. Use generated DEB/RPM packages as starting points
2. Follow distribution-specific submission processes
3. Find sponsors for package reviews

## Monitoring

### Workflow Status

Monitor workflow status in the GitHub Actions tab:

- Green checkmarks indicate successful automation
- Yellow indicators show skipped steps
- Red X marks indicate failures that need attention

### Package Status

Check package availability:

- **crates.io**: [crates.io/crates/rudu](https://crates.io/crates/rudu)
- **Homebrew**: `brew info ayungavis/tap/rudu`
- **AUR**: [aur.archlinux.org/packages/rudu](https://aur.archlinux.org/packages/rudu)

## Troubleshooting

### Common Issues

1. **Checksum Calculation Fails**

   - Ensure release assets are properly uploaded
   - Check that asset names match expected patterns

2. **crates.io Publishing Fails**

   - Verify `CRATES_TOKEN` secret is set correctly
   - Check that version doesn't already exist

3. **Homebrew Tap Update Fails**
   - Verify `HOMEBREW_TAP_TOKEN` has correct permissions
   - Ensure tap repository exists and is accessible

### Manual Recovery

If automation fails, you can:

1. Download the generated artifacts
2. Follow the manual submission guides
3. Use the calculated checksums to update configurations manually

## Extending Automation

To add support for new package managers:

1. Create configuration files in appropriate directories
2. Add update logic to `package-managers.yml`
3. Add submission logic to `submit-packages.yml` (if API available)
4. Add testing logic to `test-packages.yml`
5. Update this documentation
