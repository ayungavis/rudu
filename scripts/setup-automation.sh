#!/bin/bash

# Setup script for package manager automation
# This script helps configure the required repositories and secrets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) is required but not installed"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        error "Git is required but not installed"
        exit 1
    fi
    
    # Check if logged into GitHub CLI
    if ! gh auth status &> /dev/null; then
        error "Please login to GitHub CLI first: gh auth login"
        exit 1
    fi
    
    log "Dependencies check passed"
}

# Get repository information
get_repo_info() {
    log "Getting repository information..."
    
    # Get current repository
    REPO_URL=$(git remote get-url origin)
    REPO_NAME=$(basename "$REPO_URL" .git)
    REPO_OWNER=$(basename "$(dirname "$REPO_URL")" | sed 's/.*://')
    
    info "Repository: $REPO_OWNER/$REPO_NAME"
    
    # Verify this is the rudu repository
    if [ "$REPO_NAME" != "rudu" ]; then
        warn "This doesn't appear to be the rudu repository"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Setup Homebrew tap repository
setup_homebrew_tap() {
    log "Setting up Homebrew tap repository..."
    
    TAP_REPO="$REPO_OWNER/homebrew-tap"
    
    # Check if tap repository exists
    if gh repo view "$TAP_REPO" &> /dev/null; then
        info "Homebrew tap repository already exists: $TAP_REPO"
    else
        info "Creating Homebrew tap repository: $TAP_REPO"
        gh repo create "$TAP_REPO" --public --description "Homebrew tap for $REPO_OWNER's packages"
        
        # Clone and setup the tap
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        gh repo clone "$TAP_REPO"
        cd "homebrew-tap"
        
        # Create Formula directory and copy formula
        mkdir -p Formula
        cp "$PROJECT_DIR/homebrew/rudu.rb" Formula/
        
        # Initial commit
        git add .
        git commit -m "Initial tap setup with rudu formula"
        git push
        
        cd "$PROJECT_DIR"
        rm -rf "$TEMP_DIR"
        
        log "Homebrew tap repository created and initialized"
    fi
}

# Setup GitHub secrets
setup_secrets() {
    log "Setting up GitHub repository secrets..."
    
    # CRATES_TOKEN
    if gh secret list | grep -q "CRATES_TOKEN"; then
        info "CRATES_TOKEN secret already exists"
    else
        warn "CRATES_TOKEN secret not found"
        echo "To publish to crates.io, you need to add your crates.io API token as a secret."
        echo "1. Go to https://crates.io/me"
        echo "2. Generate a new API token"
        echo "3. Run: gh secret set CRATES_TOKEN"
        echo ""
        read -p "Do you want to set it now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Enter your crates.io API token:"
            read -s CRATES_TOKEN
            echo "$CRATES_TOKEN" | gh secret set CRATES_TOKEN
            log "CRATES_TOKEN secret set"
        fi
    fi
    
    # HOMEBREW_TAP_TOKEN (optional)
    if gh secret list | grep -q "HOMEBREW_TAP_TOKEN"; then
        info "HOMEBREW_TAP_TOKEN secret already exists"
    else
        warn "HOMEBREW_TAP_TOKEN secret not found (optional)"
        echo "For automatic Homebrew tap updates, you can add a personal access token."
        echo "This is optional - the workflow will use GITHUB_TOKEN as fallback."
        echo ""
        read -p "Do you want to set HOMEBREW_TAP_TOKEN? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "1. Go to https://github.com/settings/tokens"
            echo "2. Generate a new token with 'repo' permissions"
            echo "3. Enter the token below:"
            read -s HOMEBREW_TAP_TOKEN
            echo "$HOMEBREW_TAP_TOKEN" | gh secret set HOMEBREW_TAP_TOKEN
            log "HOMEBREW_TAP_TOKEN secret set"
        fi
    fi
}

# Test workflow permissions
test_workflows() {
    log "Testing workflow setup..."
    
    # Check if workflows directory exists
    if [ ! -d "$PROJECT_DIR/.github/workflows" ]; then
        error "Workflows directory not found"
        exit 1
    fi
    
    # Check if our workflows exist
    WORKFLOWS=(
        "package-managers.yml"
        "submit-packages.yml"
        "test-packages.yml"
    )
    
    for workflow in "${WORKFLOWS[@]}"; do
        if [ -f "$PROJECT_DIR/.github/workflows/$workflow" ]; then
            info "✓ $workflow found"
        else
            warn "✗ $workflow not found"
        fi
    done
    
    log "Workflow setup check complete"
}

# Display setup summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "Package Manager Automation Setup Summary"
    echo "=========================================="
    echo ""
    info "Repository: $REPO_OWNER/$REPO_NAME"
    info "Homebrew Tap: $REPO_OWNER/homebrew-tap"
    echo ""
    echo "Next Steps:"
    echo "1. Create a release to trigger the automation workflows"
    echo "2. Monitor workflow runs in the GitHub Actions tab"
    echo "3. Download artifacts for manual package submissions"
    echo "4. Check docs/AUTOMATION.md for detailed usage instructions"
    echo ""
    echo "Manual Workflow Triggers:"
    echo "  gh workflow run package-managers.yml -f version=v0.1.0"
    echo "  gh workflow run submit-packages.yml -f version=v0.1.0"
    echo "  gh workflow run test-packages.yml -f version=v0.1.0"
    echo ""
    echo "For more information, see: docs/AUTOMATION.md"
    echo "=========================================="
}

# Main function
main() {
    echo "Package Manager Automation Setup"
    echo "================================"
    echo ""
    
    check_dependencies
    get_repo_info
    setup_homebrew_tap
    setup_secrets
    test_workflows
    show_summary
    
    log "Setup complete!"
}

# Run main function
main "$@"
