#!/bin/bash
if ps aux | grep puma.carambus_api_production | grep -v grep
then
  echo "Service is running, performing phased-restart"
  cd /var/www/carambus_api/current; RAILS_ENV=production /var/www/.rbenv/shims/bundle exec pumactl -F /var/www/carambus_api/shared/config/puma.rb phased-restart
else
  echo "Service is not running, starting service"
  cd /var/www/carambus_api/current; RAILS_ENV=production /var/www/.rbenv/shims/bundle exec puma -C /var/www/carambus_api/shared/config/puma.rb -e production --state /var/www/carambus_api/shared/tmp/pids/puma.state
fi
