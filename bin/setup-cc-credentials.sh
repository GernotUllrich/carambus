#!/bin/bash
# Script zum Einrichten der ClubCloud Credentials
# Verwendung: ./bin/setup-cc-credentials.sh [development|production]

set -e

ENVIRONMENT="${1:-development}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Validate environment
if [[ "$ENVIRONMENT" != "development" && "$ENVIRONMENT" != "production" ]]; then
    error "Invalid environment: $ENVIRONMENT"
    error "Usage: $0 [development|production]"
    exit 1
fi

log "Setting up ClubCloud Credentials for $ENVIRONMENT environment"
echo ""

# Check if credentials already exist
CREDENTIALS_FILE="$PROJECT_ROOT/config/credentials/$ENVIRONMENT.yml.enc"
KEY_FILE="$PROJECT_ROOT/config/credentials/$ENVIRONMENT.key"

if [[ -f "$CREDENTIALS_FILE" ]]; then
    info "Credentials file already exists: $CREDENTIALS_FILE"
    read -p "Do you want to edit existing credentials? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Aborted by user"
        exit 0
    fi
fi

if [[ ! -f "$KEY_FILE" ]]; then
    warning "Key file does not exist yet: $KEY_FILE"
    info "It will be created automatically when you save the credentials"
fi

echo ""
log "Instructions:"
echo "  1. The editor will open with your credentials file"
echo "  2. Add the following structure (replace with your actual credentials):"
echo ""
echo "clubcloud:"
echo "  nbv:"
echo "    username: \"your-email@example.com\""
echo "    password: \"your-password\""
echo ""
echo "  3. Save and close the editor"
echo "  4. The credentials will be encrypted automatically"
echo ""

if [[ "$ENVIRONMENT" == "development" ]]; then
    info "For development, you can use test credentials or your personal NBV credentials"
else
    warning "For production, use the official ClubCloud credentials!"
fi

echo ""
read -p "Press ENTER to continue..."

# Open credentials editor
cd "$PROJECT_ROOT"

if command -v nano &> /dev/null; then
    EDITOR=nano rails credentials:edit --environment "$ENVIRONMENT"
elif command -v vim &> /dev/null; then
    EDITOR=vim rails credentials:edit --environment "$ENVIRONMENT"
else
    rails credentials:edit --environment "$ENVIRONMENT"
fi

# Verify credentials were created
if [[ -f "$CREDENTIALS_FILE" ]]; then
    log "✓ Credentials file created: $CREDENTIALS_FILE"
else
    error "Credentials file was not created!"
    exit 1
fi

if [[ -f "$KEY_FILE" ]]; then
    log "✓ Key file created: $KEY_FILE"
    warning "IMPORTANT: Keep this key file safe and DO NOT commit it to git!"
    warning "Location: $KEY_FILE"
else
    error "Key file was not created!"
    exit 1
fi

echo ""
log "Testing credentials..."

# Test if credentials can be read
if rails runner -e "$ENVIRONMENT" "
  begin
    creds = Rails.application.credentials.clubcloud
    if creds.present?
      puts '✓ Credentials loaded successfully'
      creds.each do |context, config|
        puts \"  - Context: #{context}\"
        puts \"    Username: #{config[:username] || '(not set)'}\"
        puts \"    Password: #{config[:password].present? ? '***SET***' : '(not set)'}\"
      end
      exit 0
    else
      puts '✗ No clubcloud section found in credentials'
      exit 1
    end
  rescue => e
    puts \"✗ Error reading credentials: #{e.message}\"
    exit 1
  end
" 2>&1; then
    echo ""
    log "✅ Setup completed successfully!"
else
    echo ""
    error "Failed to read credentials. Please check the format."
    exit 1
fi

echo ""
info "Next steps:"
echo "  1. Backup your key file: cp $KEY_FILE ~/carambus_credentials_backup/"
echo "  2. Test ClubCloud login: rails runner 'Setting.login_to_cc'"
echo "  3. Read documentation: docs/clubcloud_credentials.md"
echo ""
log "Done!"

