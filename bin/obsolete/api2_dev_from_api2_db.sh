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
