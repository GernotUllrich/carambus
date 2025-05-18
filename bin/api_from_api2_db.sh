#!/bin/bash
echo "Dump on api server"
ssh api "pg_dump -Uwww_data carambus2_api_production |gzip > carambus2_api_production.sql.gz"
echo "Scp to local backup"
cd /Volumes/SSD980PRO2TB/BACKUP/carambus
scp api:carambus2_api_production.sql.gz .
gunzip -f carambus2_api_production.sql.gz
echo "Create local carambus2_api_development"
psql postgres -c "drop database carambus2_api_development;"
psql postgres -c "create database carambus2_api_development;"
psql carambus2_api_development <<EOF
  \i carambus2_api_production.sql
EOF
echo "Local database carambus_api_development should exist and compatible with the new carambus"
echo "save the old carambus_api_development database"
psql postgres <<EOF
  DROP DATABASE IF EXISTS carambus_api_development_save;
  CREATE DATABASE carambus_api_development_save WITH TEMPLATE carambus_api_development;
EOF
echo "Make a backup of the new migration status and users and pages table"
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
