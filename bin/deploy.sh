#!/bin/bash

# =============================================================================
# Carambus Deployment Script
# =============================================================================
# This script replicates Capistrano deployment steps for server-side execution.
# It runs on the server and automatically detects the deployment path from the
# current directory structure.
#
# Usage: /var/www/<basename>/current/bin/deploy.sh [branch] [revision]
#
# Examples:
#   /var/www/carambus/current/bin/deploy.sh
#   /var/www/carambus/current/bin/deploy.sh master
#   /var/www/carambus_bcw/current/bin/deploy.sh develop abc123
#
# IMPORTANT: Do NOT run this script with 'bundle exec'!
# Run it directly: sh bin/deploy.sh or bash bin/deploy.sh
# =============================================================================

set -e  # Exit on error

# Check if running under bundle exec (not recommended)
if [ -n "$BUNDLE_GEMFILE" ]; then
    echo "⚠️  WARNING: This script is running under 'bundle exec'."
    echo "⚠️  This may cause issues with bundler configuration."
    echo "⚠️  Recommended: Run without bundle exec: sh bin/deploy.sh"
    echo ""
    # Unset bundler environment variables to avoid conflicts
    unset BUNDLE_GEMFILE
    unset BUNDLE_APP_CONFIG
    unset RUBYOPT
fi

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

# =============================================================================
# Detect Deployment Path from Current Directory
# =============================================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine DEPLOY_PATH based on script location
if [[ "$SCRIPT_DIR" == */current/bin ]]; then
    # Running from /var/www/<basename>/current/bin/deploy.sh
    DEPLOY_PATH=$(dirname $(dirname "$SCRIPT_DIR"))
    log_info "Detected deployment path from 'current': $DEPLOY_PATH"
elif [[ "$SCRIPT_DIR" == */releases/*/bin ]]; then
    # Running from /var/www/<basename>/releases/<timestamp>/bin/deploy.sh
    DEPLOY_PATH=$(dirname $(dirname $(dirname "$SCRIPT_DIR")))
    log_info "Detected deployment path from 'releases': $DEPLOY_PATH"
elif [[ "$SCRIPT_DIR" == */bin ]]; then
    # Fallback: assume script is in <deploy_path>/bin or similar
    DEPLOY_PATH=$(dirname "$SCRIPT_DIR")
    log_warning "Could not detect standard Capistrano structure, using parent: $DEPLOY_PATH"
else
    log_error "Could not determine deployment path from script location: $SCRIPT_DIR"
    exit 1
fi

# Ensure DEPLOY_PATH ends with /
if [[ ! "$DEPLOY_PATH" =~ /$ ]]; then
    DEPLOY_PATH="${DEPLOY_PATH}/"
fi

# Extract basename from DEPLOY_PATH
BASENAME=$(basename "${DEPLOY_PATH%/}")

log_success "Deployment configuration detected"
log_info "  Deploy path: $DEPLOY_PATH"
log_info "  Basename: $BASENAME"

# =============================================================================
# Parse Arguments
# =============================================================================

BRANCH="${1:-master}"
REVISION="${2:-$BRANCH}"

log_info "Branch: $BRANCH"
log_info "Revision: $REVISION"

# =============================================================================
# Detect Application Name and Ruby Version
# =============================================================================

# =============================================================================
# Set Application Name (Repository Name)
# =============================================================================
# All carambus instances (carambus, carambus_bcw, carambus_phat, etc.)
# use the same repository: carambus.git
# The difference is only in the deployment path and configuration.

APPLICATION_NAME="carambus"
log_info "Repository: $APPLICATION_NAME (fixed for all carambus instances)"

# Try to read Ruby version - prioritize .ruby-version file
if [ -f "${DEPLOY_PATH}current/.ruby-version" ]; then
    RUBY_VERSION=$(cat "${DEPLOY_PATH}current/.ruby-version" | tr -d '[:space:]')
    log_info "Ruby version from .ruby-version: $RUBY_VERSION"
elif [ -f "${DEPLOY_PATH}current/Gemfile" ]; then
    # Fallback: try to extract from Gemfile (direct version, not 'file:' reference)
    RUBY_VERSION=$(grep "^ruby ['\"]" "${DEPLOY_PATH}current/Gemfile" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -n "$RUBY_VERSION" ]; then
        log_info "Ruby version from Gemfile: $RUBY_VERSION"
    fi
fi

# Final fallback
if [ -z "$RUBY_VERSION" ]; then
    RUBY_VERSION="3.3.6"
    log_warning "Could not detect Ruby version, using default: $RUBY_VERSION"
else
    log_info "Ruby version: $RUBY_VERSION"
fi

# =============================================================================
# Setup Paths
# =============================================================================

REPO_PATH="${DEPLOY_PATH}repo"
RELEASES_PATH="${DEPLOY_PATH}releases"
SHARED_PATH="${DEPLOY_PATH}shared"
CURRENT_PATH="${DEPLOY_PATH}current"
REVISION_DATE=$(date +%Y%m%d%H%M%S)
NEW_RELEASE_PATH="${RELEASES_PATH}/${REVISION_DATE}"

log_info "Release timestamp: $REVISION_DATE"
log_info "New release path: $NEW_RELEASE_PATH"

# =============================================================================
# Setup rbenv Environment
# =============================================================================

export RBENV_ROOT="$HOME/.rbenv"
export PATH="$RBENV_ROOT/shims:$RBENV_ROOT/bin:$PATH"
export RBENV_VERSION="$RUBY_VERSION"

# =============================================================================
# Step 1: Create Directory Structure
# =============================================================================

log_step "Creating directory structure..."

/usr/bin/env mkdir -p "${SHARED_PATH}" "${RELEASES_PATH}"
/usr/bin/env mkdir -p "${SHARED_PATH}/log"
/usr/bin/env mkdir -p "${SHARED_PATH}/tmp/pids"
/usr/bin/env mkdir -p "${SHARED_PATH}/tmp/cache"
/usr/bin/env mkdir -p "${SHARED_PATH}/tmp/sockets"
/usr/bin/env mkdir -p "${SHARED_PATH}/public/system"
/usr/bin/env mkdir -p "${SHARED_PATH}/storage"
/usr/bin/env mkdir -p "${SHARED_PATH}/config/credentials"
/usr/bin/env mkdir -p "${SHARED_PATH}/config/environments"
/usr/bin/env mkdir -p "${SHARED_PATH}/bundle"

log_success "Directory structure created"

# =============================================================================
# Step 2: Git Operations
# =============================================================================

log_step "Updating git repository..."

# Get repository URL
REPO_URL="git@github.com:GernotUllrich/${APPLICATION_NAME}.git"

log_info "Repository URL: $REPO_URL"

# Check if we have SSH access to GitHub
# Note: ssh -T returns exit code 1 even on success, so we check the output
set +e  # Temporarily disable exit on error
SSH_CHECK=$(ssh -T git@github.com 2>&1)
SSH_EXIT_CODE=$?
set -e  # Re-enable exit on error

if echo "$SSH_CHECK" | grep -q "successfully authenticated"; then
    log_info "GitHub SSH access: OK"
else
    log_error "No SSH access to GitHub detected."
    log_error "SSH test output: $SSH_CHECK"
    log_error "SSH exit code: $SSH_EXIT_CODE"
    log_error ""
    log_error "This script needs SSH access to GitHub to clone/update the repository."
    log_error ""
    log_error "Solutions:"
    log_error "  1. Add the server's SSH key to your GitHub account:"
    log_error "     cat ~/.ssh/id_rsa.pub"
    log_error "     Then add it at: https://github.com/settings/keys"
    log_error "  2. Or use a Deploy Key for the specific repository"
    log_error "  3. Or use Capistrano which uses SSH agent forwarding: cap production deploy"
    exit 1
fi

# Initialize or update repository
if [ ! -d "$REPO_PATH" ]; then
    log_info "Cloning repository..."
    /usr/bin/env git clone --mirror "$REPO_URL" "$REPO_PATH"
else
    log_info "Updating repository..."
    # Always set the correct URL in case it changed (e.g., basename != application)
    cd "$REPO_PATH" && /usr/bin/env git remote set-url origin "$REPO_URL"
    cd "$REPO_PATH" && /usr/bin/env git remote update --prune
fi

log_success "Repository updated"

# =============================================================================
# Step 3: Create New Release
# =============================================================================

log_step "Creating new release..."

/usr/bin/env mkdir -p "$NEW_RELEASE_PATH"

# Extract code from git
cd "$REPO_PATH" && /usr/bin/env git archive "$REVISION" | /usr/bin/env tar -x -f - -C "$NEW_RELEASE_PATH"

# Create REVISION file
cd "$REPO_PATH" && /usr/bin/env git rev-list --max-count=1 "$REVISION" > "$NEW_RELEASE_PATH/REVISION"

# Create REVISION_TIME file
cd "$REPO_PATH" && /usr/bin/env git --no-pager log -1 --pretty=format:"%ct" "$REVISION" > "$NEW_RELEASE_PATH/REVISION_TIME"

log_success "Release created"

# =============================================================================
# Step 4: Create Symlinks for Shared Files
# =============================================================================

log_step "Creating symlinks for shared files..."

/usr/bin/env mkdir -p "${NEW_RELEASE_PATH}/config"
/usr/bin/env mkdir -p "${NEW_RELEASE_PATH}/config/environments"
/usr/bin/env mkdir -p "${NEW_RELEASE_PATH}/config/credentials"

# Linked files (from deploy.rb)
linked_files=(
    "config/database.yml"
    "config/carambus.yml"
    "config/nginx.conf"
    "config/puma.rb"
    "config/environments/production.rb"
    "config/env.production"
)

for file in "${linked_files[@]}"; do
    target="${NEW_RELEASE_PATH}/${file}"
    source="${SHARED_PATH}/${file}"

    # Remove if exists
    if [ -f "$target" ] || [ -L "$target" ]; then
        /usr/bin/env rm "$target"
    fi

    # Create symlink if source exists
    if [ -f "$source" ]; then
        /usr/bin/env ln -s "$source" "$target"
        log_info "  Linked: $file"
    else
        log_warning "  Skipped (not in shared): $file"
    fi
done

log_success "Shared files linked"

# =============================================================================
# Step 5: Create Symlinks for Shared Directories
# =============================================================================

log_step "Creating symlinks for shared directories..."

# Linked directories (from deploy.rb) - NOTE: bundle is NOT symlinked yet
linked_dirs=(
    "log"
    "tmp/pids"
    "tmp/cache"
    "tmp/sockets"
    "public/system"
    "storage"
    "config/credentials"
)

for dir in "${linked_dirs[@]}"; do
    target="${NEW_RELEASE_PATH}/${dir}"
    source="${SHARED_PATH}/${dir}"

    # Create parent directory if needed
    parent_dir=$(dirname "$target")
    /usr/bin/env mkdir -p "$parent_dir"

    # Remove if exists
    if [ -d "$target" ] || [ -L "$target" ]; then
        /usr/bin/env rm -rf "$target"
    fi

    # Create symlink
    /usr/bin/env ln -s "$source" "$target"
    log_info "  Linked: $dir"
done

log_success "Shared directories linked"

# =============================================================================
# Step 6: Bundle Install
# =============================================================================

log_step "Installing Ruby dependencies..."

cd "$NEW_RELEASE_PATH"

# Unset BUNDLE_GEMFILE to avoid using the old current release's Gemfile
unset BUNDLE_GEMFILE
unset BUNDLE_APP_CONFIG

# Remove the .bundle directory if it exists to start fresh
if [ -d ".bundle" ]; then
    /usr/bin/env rm -rf ".bundle"
fi

# Configure bundler with explicit settings (not using --local to avoid .bundle/config issues)
log_info "  Configuring bundler..."
RAILS_ENV=production $RBENV_ROOT/bin/rbenv exec bundle config set --local path "${SHARED_PATH}/bundle"
RAILS_ENV=production $RBENV_ROOT/bin/rbenv exec bundle config set --local without 'development test'

# Install gems - if it fails with git checkout error, clean bundle cache and retry
log_info "  Running bundle install..."
set +e  # Temporarily disable exit on error
BUNDLE_OUTPUT=$(RAILS_ENV=production $RBENV_ROOT/bin/rbenv exec bundle install --jobs 4 2>&1)
BUNDLE_EXIT_CODE=$?
set -e  # Re-enable exit on error

if [ $BUNDLE_EXIT_CODE -ne 0 ]; then
    # Check if error is due to git gems not checked out
    if echo "$BUNDLE_OUTPUT" | grep -q "is not yet checked out"; then
        log_warning "Bundle install failed: Git gems not checked out"
        log_info "  Cleaning bundle cache and retrying..."
        /usr/bin/env rm -rf "${SHARED_PATH}/bundle"
        /usr/bin/env rm -rf ".bundle"

        # Reconfigure bundler after cleaning
        RAILS_ENV=production $RBENV_ROOT/bin/rbenv exec bundle config set --local path "${SHARED_PATH}/bundle"
        RAILS_ENV=production $RBENV_ROOT/bin/rbenv exec bundle config set --local without 'development test'

        # Retry bundle install
        log_info "  Retrying bundle install..."
        RAILS_ENV=production $RBENV_ROOT/bin/rbenv exec bundle install --jobs 4
    else
        # Other error - show output and exit
        echo "$BUNDLE_OUTPUT"
        exit 1
    fi
fi

log_success "Ruby dependencies installed"

# =============================================================================
# Step 7: Install JavaScript Dependencies
# =============================================================================

log_step "Installing JavaScript dependencies..."

cd "$NEW_RELEASE_PATH"

# Check if yarn is available
if command -v yarn &> /dev/null; then
    /usr/bin/env yarn install
    log_success "JavaScript dependencies installed"
else
    log_warning "Yarn not found, skipping JavaScript dependencies"
fi

# =============================================================================
# Step 8: Build Frontend Assets
# =============================================================================

log_step "Building frontend assets..."

cd "$NEW_RELEASE_PATH"

if command -v yarn &> /dev/null; then
    # Build JavaScript with esbuild
    log_info "  Building JavaScript..."
    /usr/bin/env yarn build

    # Build CSS with Tailwind
    log_info "  Building CSS..."
    /usr/bin/env yarn build:css

    # Ensure builds directory exists
    /usr/bin/env mkdir -p app/assets/builds

    log_success "Frontend assets built"
else
    log_warning "Yarn not found, skipping frontend asset build"
fi

# =============================================================================
# Step 9: Precompile Rails Assets
# =============================================================================

log_step "Precompiling Rails assets..."

cd "$NEW_RELEASE_PATH"

RAILS_ENV=production $RBENV_ROOT/bin/rbenv exec bundle exec rails assets:precompile

log_success "Rails assets precompiled"

# =============================================================================
# Step 10: Run Database Migrations
# =============================================================================

log_step "Running database migrations..."

cd "$NEW_RELEASE_PATH"

RAILS_ENV=production $RBENV_ROOT/bin/rbenv exec bundle exec rails db:migrate

log_success "Database migrations completed"

# =============================================================================
# Step 11: Update Current Symlink
# =============================================================================

log_step "Updating current symlink..."

# Create temporary symlink
/usr/bin/env ln -s "$NEW_RELEASE_PATH" "${RELEASES_PATH}/current"

# Move to final location (atomic operation)
/usr/bin/env mv -T "${RELEASES_PATH}/current" "$CURRENT_PATH"

log_success "Current symlink updated"

# =============================================================================
# Step 12: Restart Puma
# =============================================================================

log_step "Restarting Puma..."

if [ -f "${CURRENT_PATH}/bin/manage-puma.sh" ]; then
    sudo "${CURRENT_PATH}/bin/manage-puma.sh" "$BASENAME"
    log_success "Puma restarted"
else
    log_warning "manage-puma.sh not found, skipping Puma restart"
fi

# =============================================================================
# Step 13: Log Deployment
# =============================================================================

log_step "Logging deployment..."

DEPLOY_USER=$(whoami)

# Get the actual git commit hash that was deployed
cd "$REPO_PATH"
ACTUAL_COMMIT=$(git rev-parse "$REVISION")

echo "Branch $BRANCH (at $ACTUAL_COMMIT) deployed as release $REVISION_DATE by $DEPLOY_USER" >> "${DEPLOY_PATH}revisions.log"

log_success "Deployment logged"

# =============================================================================
# Step 14: Cleanup Old Releases
# =============================================================================

log_step "Cleaning up old releases..."

# Keep only the last 5 releases
cd "$RELEASES_PATH"
RELEASES_TO_REMOVE=$(ls -t | tail -n +6)

if [ -n "$RELEASES_TO_REMOVE" ]; then
    echo "$RELEASES_TO_REMOVE" | while read release; do
        log_info "  Removing old release: $release"
        rm -rf "$release"
    done
    log_success "Old releases cleaned up"
else
    log_info "No old releases to clean up"
fi

# =============================================================================
# Deployment Complete
# =============================================================================

echo ""
log_success "======================================================================"
log_success "  Deployment completed successfully!"
log_success "======================================================================"
log_success "  Release: $REVISION_DATE"
log_success "  Branch: $BRANCH"
log_success "  Commit: $ACTUAL_COMMIT"
log_success "  Application: $APPLICATION_NAME ($BASENAME)"
log_success "======================================================================"
echo ""
