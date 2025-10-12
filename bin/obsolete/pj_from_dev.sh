#!/bin/bash
echo "ASSUME WE ARE IN THE CORRECT DESTINATION FOLDERm
echo "make a backup of carambus_development_gernot"
psql postgres <<EOF
  DROP DATABASE IF EXISTS carambus_development_gernot_save;
  CREATE DATABASE carambus_development_gernot_save WITH TEMPLATE carambus_development_gernot;
EOF
echo "create a new carambus_development_gernot from the carambus_development"
psql postgres <<EOF
  DROP DATABASE IF EXISTS carambus_development_pj;
  CREATE DATABASE carambus_development_pj WITH TEMPLATE carambus_development_gernot;
EOF
echo "edit config/carambus.yml - especially the carambus_api_url"
echp "Sequence Reset Version.sequence_reset"
rails c <<EOF
  Version.sequence_reset
EOF
echo "Create Scoreboard User - ist fest eingebrannt in api server"
echo "Update last_version_id:"
rails c <<EOF
  last_version_id = PaperTrail::Version.last.id
  Setting.key_set_value("last_version_id", last_version_id)
EOF
