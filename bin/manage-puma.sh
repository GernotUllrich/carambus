#!/bin/bash
BASENAME=$1

if [ -z "$BASENAME" ]; then
  echo "Error: BASENAME parameter is required"
  echo "Usage: $0 <basename>"
  exit 1
fi

# Debug output
echo "DEBUG: Checking for socket file: /var/www/${BASENAME}/shared/sockets/puma-production.sock"
echo "DEBUG: Socket file exists: $([ -S "/var/www/${BASENAME}/shared/sockets/puma-production.sock" ] && echo "YES" || echo "NO")"
echo "DEBUG: Checking for puma process with pattern: puma.*${BASENAME}"
echo "DEBUG: Puma process found: $(pgrep -f "puma.*${BASENAME}" > /dev/null && echo "YES" || echo "NO")"

# Check if the puma service is running by looking for the socket file
if [ -S "/var/www/${BASENAME}/shared/sockets/puma-production.sock" ] && pgrep -f "puma.*${BASENAME}" > /dev/null
then
  echo "Service is running, performing phased-restart"
  cd /var/www/${BASENAME}/current; RAILS_ENV=production /var/www/.rbenv/shims/bundle exec pumactl -F /var/www/${BASENAME}/shared/config/puma.rb phased-restart
else
  echo "Service is not running, starting service"
  cd /var/www/${BASENAME}/current; sudo systemctl start puma-${BASENAME}.service
fi

