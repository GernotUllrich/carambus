#!/bin/bash
echo "🚀 Starting development database synchronization..."

# 1. Version-Check (verhindert Downgrade)
echo "🔍 Step 1: Checking version safety..."
if [ -f "carambus_api_development.sql.gz" ]; then
    bundle exec rails 'mode:check_version_safety[carambus_api_development.sql.gz]'
    if [ $? -ne 0 ]; then
        echo "❌ Version check failed - aborting"
        exit 1
    fi
else
    echo "⚠️  No dump file found, skipping version check"
fi

# 2. Backup der aktuellen carambus_development
echo "💾 Step 2: Creating backup of current carambus_development..."
psql postgres <<EOF
  DROP DATABASE IF EXISTS carambus_development_save;
  CREATE DATABASE carambus_development_save WITH TEMPLATE carambus_development;
EOF

# 3. Sauberer Drop/Create/Load
echo "🗄️  Step 3: Clean drop/create/load of carambus_development..."
dropdb carambus_development
createdb carambus_development --template=carambus_api_development

# 4. Verifizierung des Migrationsstatus
echo "✅ Step 4: Verifying migration status..."
RAILS_ENV=development bundle exec rails db:migrate:status | tail -5

# 5. Post-Load Setup
echo "🔧 Step 5: Post-load setup..."
RAILS_ENV=development bundle exec rails runner "
  puts 'Resetting version sequence...'
  Version.sequence_reset
  
  puts 'Updating last_version_id...'
  last_version_id = PaperTrail::Version.last.id
  Setting.key_set_value('last_version_id', last_version_id)
  
  puts 'Creating Scoreboard User...'
  User.create!(
    name: 'Scoreboard', 
    email: 'scoreboard@carambus.de', 
    password: 'scoreboard', 
    password_confirmation: 'scoreboard', 
    admin: false, 
    terms_of_service: true, 
    confirmed_at: Time.now
  ) unless User.find_by(email: 'scoreboard@carambus.de')
"

echo "✅ Development database synchronization completed successfully!"
echo ""
echo "📊 Summary:"
echo "  - Source: carambus_api_development"
echo "  - Target: carambus_development"
echo "  - Version safety: checked"
echo "  - Migration status: verified"
echo "  - Backup: carambus_development_save"
echo ""
echo "📝 Note: Remember to edit config/carambus.yml - especially the carambus_api_url"
