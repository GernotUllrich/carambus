#!/bin/bash
cd /var/www/carambus/current
BEANSTALK_URL=beanstalk://localhost:11300 RAILS_ENV=production ~/.rbenv/shims/bundle exec script/worker.rb stop
