#!/bin/bash
cd ~/projects/carambus
echo "save the old carambus_development database"
psql postgres <<EOF
  DROP DATABASE IF EXISTS carambus_development_save;
  CREATE DATABASE carambus_development_save WITH TEMPLATE carambus_development;
EOF
echo "Make a backup of the local changes to the database with >50000000 ids"
RAILS_ENV=development bundle exec rake carambus:filter_local_changes_from_sql_dump

pg_dump -t schema_migrations -t users -t pages carambus_api_development > schema_migrations_users_pages_backup.sql
  echo "Drop the new database and clone from the old one"
dropdb carambus_api_development
createdb carambus_api_development -T carambus2_api_development
echo "Drop unused tables in new db"
psql carambus_api_development <<EOF
	DROP TABLE IF EXISTS account_invitations CASCADE;
	DROP TABLE IF EXISTS account_users CASCADE;
	DROP TABLE IF EXISTS accounts CASCADE;
	DROP TABLE IF EXISTS action_mailbox_inbound_emails CASCADE;
	DROP TABLE IF EXISTS action_text_embeds CASCADE;
	DROP TABLE IF EXISTS action_text_rich_texts CASCADE;
	DROP TABLE IF EXISTS addresses CASCADE;
	DROP TABLE IF EXISTS announcements CASCADE;
	DROP TABLE IF EXISTS api_tokens CASCADE;
	DROP TABLE IF EXISTS connected_accounts CASCADE;
	DROP TABLE IF EXISTS inbound_webhooks CASCADE;
	DROP TABLE IF EXISTS noticed_events CASCADE;
	DROP TABLE IF EXISTS noticed_notifications CASCADE;
	DROP TABLE IF EXISTS notification_tokens CASCADE;
	DROP TABLE IF EXISTS notifications CASCADE;
	DROP TABLE IF EXISTS pay_charges CASCADE;
	DROP TABLE IF EXISTS pay_payment_methods CASCADE;
	DROP TABLE IF EXISTS pay_subscriptions CASCADE;
	DROP TABLE IF EXISTS pay_webhooks CASCADE;
	DROP TABLE IF EXISTS pay_merchants CASCADE;
	DROP TABLE IF EXISTS pay_customers CASCADE;
	DROP TABLE IF EXISTS plans CASCADE;
EOF
echo "Drop schema_migrations, users and pages to be clean for reload"
psql carambus_api_development <<EOF
	DROP TABLE IF EXISTS schema_migrations CASCADE;
	DROP TABLE IF EXISTS users CASCADE;
	DROP TABLE IF EXISTS pages CASCADE;
EOF
echo "reload new data from backup"
psql carambus_api_development <<EOF
	\i schema_migrations_users_pages_backup.sql;
EOF
