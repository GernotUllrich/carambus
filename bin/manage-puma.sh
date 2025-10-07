#!/bin/bash

# Try to get BASENAME from command line argument
BASENAME=$1

# If not provided, try to determine from current directory
if [ -z "$BASENAME" ]; then
  echo "DEBUG: No BASENAME provided, trying to determine automatically"

  # Check if we're in a deployment directory
  if [[ "$PWD" == */current ]]; then
    # Extract basename from path like /var/www/carambus/current
    BASENAME=$(basename $(dirname "$PWD"))
    echo "DEBUG: Extracted BASENAME from current path: $BASENAME"
  elif [[ "$PWD" == */releases/* ]]; then
    # Extract basename from path like /var/www/carambus/releases/20250903210755
    BASENAME=$(echo "$PWD" | sed 's|.*/\([^/]*\)/releases/.*|\1|')
    echo "DEBUG: Extracted BASENAME from releases path: $BASENAME"
  else
    # Try to get from environment variable or config
    if [ -f "config/deploy.rb" ]; then
      echo "DEBUG: Found config/deploy.rb, trying to extract BASENAME"
      BASENAME=$(grep "set :basename" config/deploy.rb | sed 's/.*set :basename, *"\([^"]*\)".*/\1/')
      echo "DEBUG: Extracted BASENAME from deploy.rb: '$BASENAME'"
    fi

    # If still not found, try environment variable
    if [ -z "$BASENAME" ]; then
      BASENAME="$DEPLOY_BASENAME"
      echo "DEBUG: Using DEPLOY_BASENAME environment variable: '$BASENAME'"
    fi

    # Last resort: try to guess from current directory name
    if [ -z "$BASENAME" ]; then
      BASENAME=$(basename "$PWD")
      echo "DEBUG: Using current directory name as BASENAME: '$BASENAME'"
    fi
  fi
fi

if [ -z "$BASENAME" ]; then
  echo "Error: BASENAME parameter is required"
  echo "Usage: $0 <basename>"
  echo "Or set DEPLOY_BASENAME environment variable"
  echo "Or run from a deployment directory"
  exit 1
fi

echo "Using BASENAME: $BASENAME"

# Check if the puma service is running by looking for the socket file
if [ -S "/var/www/${BASENAME}/shared/sockets/puma-production.sock" ] && pgrep -f "puma.*${BASENAME}" > /dev/null
then
  echo "Service is running, performing graceful phased-restart"
  cd /var/www/${BASENAME}/current
  # Use pumactl for graceful phased restart (zero downtime)
  RAILS_ENV=production bundle exec pumactl phased-restart
else
  echo "Service is not running, starting service"
  cd /var/www/${BASENAME}/current
  sudo systemctl start puma-${BASENAME}.service
fi

