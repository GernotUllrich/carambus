# frozen_string_literal: true

namespace :test do
  desc "Setup test databases for all scenarios"
  task :setup_all do
    scenarios = %w[master bcw api phat]
    
    puts "\n" + "=" * 80
    puts "  SETTING UP TEST DATABASES FOR ALL SCENARIOS"
    puts "=" * 80 + "\n"
    
    scenarios.each do |scenario|
      scenario_path = "/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_#{scenario}"
      
      if Dir.exist?(scenario_path)
        puts "\n▶ Setting up carambus_#{scenario}_test..."
        
        Dir.chdir(scenario_path) do
          # Drop existing test db (ignore errors if it doesn't exist)
          system("RAILS_ENV=test bin/rails db:drop 2>/dev/null")
          
          # Create and setup
          if system("RAILS_ENV=test bin/rails db:create db:schema:load")
            puts "  ✓ carambus_#{scenario}_test database ready"
          else
            puts "  ✗ Failed to setup carambus_#{scenario}_test"
          end
        end
      else
        puts "  ⊘ Skipping #{scenario} (directory not found)"
      end
    end
    
    puts "\n" + "=" * 80
    puts "  SETUP COMPLETE"
    puts "=" * 80 + "\n"
  end
  
  desc "Reset test database (drop, create, load schema)"
  task reset: :environment do
    puts "Resetting test database..."
    
    Rake::Task['db:drop'].invoke
    Rake::Task['db:create'].invoke
    Rake::Task['db:schema:load'].invoke
    
    puts "✓ Test database reset complete"
  end
  
  desc "Clean test database (remove test data but keep schema)"
  task clean: :environment do
    puts "Cleaning test database..."
    
    # Only remove records with IDs >= 50_000_000 (test data)
    ActiveRecord::Base.connection.tables.each do |table|
      next if table.in?(%w[schema_migrations ar_internal_metadata])
      
      begin
        model = table.classify.constantize
        if model.column_names.include?('id')
          count = model.where('id >= ?', 50_000_000).delete_all
          puts "  Cleaned #{count} records from #{table}" if count > 0
        end
      rescue NameError
        # Skip tables without models
      end
    end
    
    puts "✓ Test database cleaned"
  end
  
  desc "Verify test database setup"
  task verify: :environment do
    puts "\nVerifying test database setup..."
    
    begin
      # Check connection
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "  ✓ Database connection OK"
      
      # Check required tables
      required_tables = %w[tournaments tournament_plans seedings games players regions seasons disciplines]
      required_tables.each do |table|
        if ActiveRecord::Base.connection.table_exists?(table)
          puts "  ✓ Table '#{table}' exists"
        else
          puts "  ✗ Table '#{table}' missing"
        end
      end
      
      # Check fixtures can load
      Rake::Task['db:fixtures:load'].invoke
      puts "  ✓ Fixtures loaded successfully"
      
      # Check test data IDs
      [Tournament, Player, Seeding].each do |model|
        test_count = model.where('id >= ?', 50_000_000).count
        puts "  ✓ #{model.name}: #{test_count} test records"
      end
      
      puts "\n✓ Test database verification passed"
    rescue => e
      puts "\n✗ Test database verification failed: #{e.message}"
      exit 1
    end
  end
end

namespace :db do
  namespace :test do
    desc "Prepare test database (create if needed, load schema, load fixtures)"
    task prepare_with_fixtures: :environment do
      Rake::Task['db:test:prepare'].invoke
      Rake::Task['db:fixtures:load'].invoke
      puts "✓ Test database prepared with fixtures"
    end
  end
end
