#!/bin/bash
if ps aux | grep puma.carambus_production | grep -v grep
then
  echo "Service is running, performing phased-restart"
  cd /var/www/carambus/current; RAILS_ENV=production /var/www/.rbenv/shims/bundle exec pumactl -F /var/www/carambus/shared/config/puma.rb phased-restart
else
  echo "Service is not running, starting service"
  cd /var/www/carambus/current; RAILS_ENV=production /var/www/.rbenv/shims/bundle exec puma -C /var/www/carambus/shared/config/puma.rb -e production --state /var/www/carambus/shared/tmp/pids/puma.state
fi
