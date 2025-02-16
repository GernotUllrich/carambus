#!/bin/bash

DEPLOY_PATH="/var/www/carambus/"
REPO_PATH="${DEPLOY_PATH}repo"
RELEASES_PATH="${DEPLOY_PATH}releases"
CURRENT_PATH="${DEPLOY_PATH}current"
REVISION_DATE=$(date +%Y%m%d%H%M%S)
NEW_RELEASE_PATH="${RELEASES_PATH}/$REVISION_DATE"
if [ -z "$REVISION" ]
then
  REVISION="puma"
fi

/usr/bin/env mkdir -p /var/www/carambus/shared /var/www/carambus/releases
/usr/bin/env mkdir -p /var/www/carambus/shared/log /var/www/carambus/shared/tmp/pids /var/www/carambus/shared/tmp/cache /var/www/carambus/shared/tmp/sockets /var/www/carambus/shared/public/system /var/www/carambus/shared/node_modules /var/www/carambus/shared/public/packs /var/www/carambus/shared/public/assets /var/www/carambus/shared/.bundle
/usr/bin/env mkdir -p /var/www/carambus/shared/config /var/www/carambus/shared/config/credentials /var/www/carambus/shared/config/environments
/usr/bin/env mkdir -p ${NEW_RELEASE_PATH}
cd /var/www/carambus/repo && ( /usr/bin/env git remote set-url origin git@github.com:GernotUllrich/carambus.git )
cd /var/www/carambus/repo && ( /usr/bin/env git remote update --prune )
cd /var/www/carambus/repo && (/usr/bin/env git archive ${REVISION} | /usr/bin/env tar -x -f - -C ${NEW_RELEASE_PATH})
if [ "$REVISION" = "puma" ]
then
  cd /var/www/carambus/repo && ( /usr/bin/env git rev-list --max-count=1 ${REVISION} > ${NEW_RELEASE_PATH}/REVISION)
else
  echo "$REVISION" > ${NEW_RELEASE_PATH}/REVISION
fi
cd /var/www/carambus/repo && ( /usr/bin/env git --no-pager log -1 --pretty=format:\"%ct\" puma > ${NEW_RELEASE_PATH}/REVISION_TIME)
/usr/bin/env mkdir -p ${NEW_RELEASE_PATH}/config ${NEW_RELEASE_PATH}/config/credentials ${NEW_RELEASE_PATH}/config/environments
/usr/bin/env ln -s /var/www/carambus/shared/config/database.yml ${NEW_RELEASE_PATH}/config/database.yml
/usr/bin/env ln -s /var/www/carambus/shared/config/master.key ${NEW_RELEASE_PATH}/config/master.key
/usr/bin/env ln -s /var/www/carambus/shared/config/scoreboard_url ${NEW_RELEASE_PATH}/config/scoreboard_url
/usr/bin/env ln -s /var/www/carambus/shared/config/credentials/production.key ${NEW_RELEASE_PATH}/config/credentials/production.key
/usr/bin/env rm ${NEW_RELEASE_PATH}/config/environments/production.rb
/usr/bin/env ln -s /var/www/carambus/shared/config/environments/production.rb ${NEW_RELEASE_PATH}/config/environments/production.rb
/usr/bin/env rm ${NEW_RELEASE_PATH}/config/credentials/production.yml.enc
/usr/bin/env ln -s /var/www/carambus/shared/config/credentials/production.yml.enc ${NEW_RELEASE_PATH}/config/credentials/production.yml.enc
/usr/bin/env rm ${NEW_RELEASE_PATH}/config/puma.rb
/usr/bin/env ln -s /var/www/carambus/shared/config/puma.rb ${NEW_RELEASE_PATH}/config/puma.rb
/usr/bin/env mkdir -p ${NEW_RELEASE_PATH} ${NEW_RELEASE_PATH}/tmp ${NEW_RELEASE_PATH}/public
/usr/bin/env rm -rf ${NEW_RELEASE_PATH}/log
/usr/bin/env ln -s /var/www/carambus/shared/log ${NEW_RELEASE_PATH}/log
/usr/bin/env ln -s /var/www/carambus/shared/tmp/pids ${NEW_RELEASE_PATH}/tmp/pids
/usr/bin/env ln -s /var/www/carambus/shared/tmp/cache ${NEW_RELEASE_PATH}/tmp/cache
/usr/bin/env ln -s /var/www/carambus/shared/tmp/sockets ${NEW_RELEASE_PATH}/tmp/sockets
/usr/bin/env ln -s /var/www/carambus/shared/public/system ${NEW_RELEASE_PATH}/public/system
/usr/bin/env ln -s /var/www/carambus/shared/node_modules ${NEW_RELEASE_PATH}/node_modules
/usr/bin/env ln -s /var/www/carambus/shared/public/packs ${NEW_RELEASE_PATH}/public/packs
/usr/bin/env ln -s /var/www/carambus/shared/public/assets ${NEW_RELEASE_PATH}/public/assets
/usr/bin/env ln -s /var/www/carambus/shared/.bundle ${NEW_RELEASE_PATH}/.bundle
cd ${NEW_RELEASE_PATH}
RAILS_ENV=production RBENV_ROOT=$HOME/.rbenv RBENV_VERSION=3.2.1 $HOME/.rbenv/bin/rbenv exec bundle config --local deployment true
RAILS_ENV=production RBENV_ROOT=$HOME/.rbenv RBENV_VERSION=3.2.1 $HOME/.rbenv/bin/rbenv exec bundle config --local path /var/www/carambus/shared/bundle
RAILS_ENV=production RBENV_ROOT=$HOME/.rbenv RBENV_VERSION=3.2.1 $HOME/.rbenv/bin/rbenv exec bundle config --local without development:test
RAILS_ENV=production RBENV_ROOT=$HOME/.rbenv RBENV_VERSION=3.2.1 $HOME/.rbenv/bin/rbenv exec bundle install --jobs 4 --quiet
RAILS_ENV=production RBENV_ROOT=$HOME/.rbenv RBENV_VERSION=3.2.1 $HOME/.rbenv/bin/rbenv exec bundle exec rake assets:precompile
RAILS_ENV=production RBENV_ROOT=$HOME/.rbenv RBENV_VERSION=3.2.1 $HOME/.rbenv/bin/rbenv exec bundle exec rake db:migrate
/usr/bin/env ln -s ${NEW_RELEASE_PATH} /var/www/carambus/releases/current
/usr/bin/env mv /var/www/carambus/releases/current /var/www/carambus
sudo /var/www/carambus/current/bin/manage-puma.sh
/usr/bin/env echo "Branch puma (at ${REVISION}) deployed as release ${REVISION_DATE} by gullrich" >> /var/www/carambus/revisions.log
