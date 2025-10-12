#!/bin/bash
# Puma wrapper script for systemd service
# This script ensures proper rbenv initialization and working directory
# Usage: puma-wrapper.sh [basename]

# Get basename from argument or environment variable
BASENAME="${1:-${PUMA_BASENAME}}"

if [ -z "$BASENAME" ]; then
    echo "Error: BASENAME not provided. Usage: $0 <basename> or set PUMA_BASENAME environment variable"
    exit 1
fi

# Change to the application directory
cd "/var/www/$BASENAME/current" || {
    echo "Error: Cannot change to /var/www/$BASENAME/current"
    exit 1
}

# Set up rbenv environment
export RBENV_ROOT="/var/www/.rbenv"
export PATH="/var/www/.rbenv/shims:$PATH"

# Start Puma with the config file using rbenv shims
exec /var/www/.rbenv/shims/bundle exec puma -C "/var/www/$BASENAME/shared/config/puma.rb"
