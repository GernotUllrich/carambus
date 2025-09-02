#!/bin/bash
BASENAME=$1

if [ -z "$BASENAME" ]; then
  echo "Error: BASENAME parameter is required"
  echo "Usage: $0 <basename>"
  exit 1
fi

# Check if the puma service is running by looking for the socket file
if [ -S "/var/www/${BASENAME}/shared/sockets/puma-production.sock" ] && pgrep -f "puma.*${BASENAME}" > /dev/null
then
  echo "Service is running, performing phased-restart"
  cd /var/www/${BASENAME}/current; RAILS_ENV=production /var/www/.rbenv/shims/bundle exec pumactl -F /var/www/${BASENAME}/shared/config/puma.rb phased-restart
else
  echo "Service is not running, starting service"
  cd /var/www/${BASENAME}/current; sudo systemctl start puma-${BASENAME}.service
fi

