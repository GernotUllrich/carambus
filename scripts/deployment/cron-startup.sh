#!/bin/bash

# Copy credentials from mounted volume to local directory
echo "Setting up cron container..."
cp /app/config/credentials/production.* /app/config/credentials/ 2>/dev/null || true

# Load the crontab
echo "Loading crontab..."
crontab /etc/cron.d/carambus

# Start cron in foreground
echo "Starting cron daemon..."
exec cron -f 