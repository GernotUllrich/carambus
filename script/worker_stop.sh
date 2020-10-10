#!/bin/bash
cd /var/www/web1.carambus.de/web/current
BEANSTALK_URL=beanstalk://web1.carambus.de:11300 RAILS_ENV=production ~/.rbenv/shims/bundle exec script/worker.rb stop