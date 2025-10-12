#!/bin/bash
echo "🚀 Starting API database synchronization from carambus2..."

# 1. Dump von carambus2_api_production auf Server
echo "📤 Step 1: Creating dump on API server..."
ssh api "pg_dump -Uwww_data carambus2_api_production |gzip > carambus2_api_production.sql.gz"

# 2. Download des Dumps
echo "📥 Step 2: Downloading dump to local backup..."
cd /Volumes/SSD980PRO2TB/BACKUP/carambus
scp api:carambus2_api_production.sql.gz .

# 3. Version-Check (verhindert Downgrade)
echo "🔍 Step 3: Checking version safety..."
gunzip -f carambus2_api_production.sql.gz
cd ~/projects/carambus
bundle exec rails 'mode:check_version_safety[carambus2_api_production.sql]'
if [ $? -ne 0 ]; then
    echo "❌ Version check failed - aborting"
    exit 1
fi

# 4. Backup der aktuellen carambus_api_development
echo "💾 Step 4: Creating backup of current carambus_api_development..."
psql postgres <<EOF
  DROP DATABASE IF EXISTS carambus_api_development_save;
  CREATE DATABASE carambus_api_development_save WITH TEMPLATE carambus_api_development;
EOF

# 5. Backup von schema_migrations, users und pages
echo "💾 Step 5: Backing up schema_migrations, users, and pages..."
pg_dump -t schema_migrations -t users -t pages carambus_api_development > schema_migrations_users_pages_backup.sql

# 6. Sauberer Drop/Create/Load
echo "🗄️  Step 6: Clean drop/create/load of carambus_api_development..."
dropdb carambus_api_development
createdb carambus_api_development

echo "📥 Loading data from carambus2_api_production.sql..."
psql carambus_api_development < /Volumes/SSD980PRO2TB/BACKUP/carambus/carambus2_api_production.sql

# 7. Verifizierung des Migrationsstatus
echo "✅ Step 7: Verifying migration status..."
RAILS_ENV=development bundle exec rails db:migrate:status | tail -5

# 8. Post-Load Setup
echo "🔧 Step 8: Post-load setup..."
RAILS_ENV=development bundle exec rails runner <<EOF
  puts "Resetting version sequence..."
  Version.sequence_reset
  
  puts "Updating last_version_id..."
  last_version_id = PaperTrail::Version.last.id
  Setting.key_set_value("last_version_id", last_version_id)
EOF

echo "✅ API database synchronization completed successfully!"
echo ""
echo "📊 Summary:"
echo "  - Source: carambus2_api_production (server)"
echo "  - Target: carambus_api_development (local)"
echo "  - Version safety: checked"
echo "  - Migration status: verified"
echo "  - Backup: carambus_api_development_save"
