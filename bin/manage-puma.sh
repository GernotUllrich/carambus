#!/bin/bash
BASENAME=$1
if pgrep -f "puma.${BASENAME}_production" > /dev/null

then
  echo "Service is running, performing phased-restart"
  cd /var/www/${BASENAME}/current; RAILS_ENV=production sudo /var/www/.rbenv/shims/bundle exec pumactl -F /var/www/${BASENAME}/shared/config/puma.rb phased-restart
else
  echo "Service is not running, starting service"
  cd /var/www/${BASENAME}/current; sudo systemctl start puma-${BASENAME}.service
fi

