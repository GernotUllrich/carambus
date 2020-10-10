#!/bin/bash
cd /var/www/web1.carambus.de/web/current
BEANSTALK_URL=beanstalk://localhost:11300 RAILS_ENV=development bundle exec script/worker.rb stop