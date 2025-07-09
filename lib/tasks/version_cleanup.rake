namespace :version_cleanup do
  desc "Copy region_id and global_context from items to their versions (FASTEST)"
  task copy_region_data_sql: :environment do
    puts "Copying region_id and global_context from items to versions..."
    
    # Get all models that include RegionTaggable
    models_with_region_taggable = [
      Region, Club, Tournament, League, Party, Location,
      LeagueTeam, Game, PartyGame, GameParticipation,
      Player, SeasonParticipation, Seeding
    ]

    total_versions_updated = 0

    models_with_region_taggable.each do |model_class|
      puts "\nProcessing #{model_class.name}..."
      
      begin
        # Simple SQL to copy region_id and global_context from items to versions
        sql = <<~SQL
          UPDATE versions 
          SET region_id = #{model_class.table_name}.region_id, 
              global_context = #{model_class.table_name}.global_context
          FROM #{model_class.table_name}
          WHERE versions.item_type = '#{model_class.name}' 
          AND versions.item_id = #{model_class.table_name}.id
          AND (versions.region_id IS NULL OR 
               versions.region_id != #{model_class.table_name}.region_id OR 
               versions.global_context != #{model_class.table_name}.global_context)
        SQL
        
        # Execute the SQL update
        result = ActiveRecord::Base.connection.execute(sql)
        versions_updated = result.cmd_tuples
        total_versions_updated += versions_updated
        
        puts "  Updated #{versions_updated} versions for #{model_class.name}"
        
      rescue StandardError => e
        Rails.logger.error("Error processing #{model_class.name}: #{e.message}")
        puts "Error processing #{model_class.name}: #{e.message}"
      end
    end

    puts "\nCleanup Summary:"
    puts "================="
    puts "Total versions updated: #{total_versions_updated}"
  end

  desc "Copy region_id and global_context from items to their versions (Ruby-based)"
  task copy_region_data: :environment do
    puts "Copying region_id and global_context from items to versions..."
    
    # Get all models that include RegionTaggable
    models_with_region_taggable = [
      Region, Club, Tournament, League, Party, Location,
      LeagueTeam, Game, PartyGame, GameParticipation,
      Player, SeasonParticipation, Seeding
    ]

    total_versions_updated = 0

    models_with_region_taggable.each do |model_class|
      puts "\nProcessing #{model_class.name}..."
      
      # Find versions that need updating for this model
      versions_to_update = PaperTrail::Version.where(item_type: model_class.name)
                                             .joins("INNER JOIN #{model_class.table_name} ON #{model_class.table_name}.id = versions.item_id")
                                             .where("versions.region_id IS NULL OR 
                                                    versions.region_id != #{model_class.table_name}.region_id OR 
                                                    versions.global_context != #{model_class.table_name}.global_context")
      
      versions_updated = versions_to_update.update_all(
        "region_id = #{model_class.table_name}.region_id, global_context = #{model_class.table_name}.global_context"
      )
      
      total_versions_updated += versions_updated
      puts "  Updated #{versions_updated} versions for #{model_class.name}"
    end

    puts "\nCleanup Summary:"
    puts "================="
    puts "Total versions updated: #{total_versions_updated}"
  end

  desc "Show statistics about version region data"
  task stats: :environment do
    puts "Version Region Data Statistics"
    puts "=============================="
    
    # Get all models that include RegionTaggable
    models_with_region_taggable = [
      Region, Club, Tournament, League, Party, Location,
      LeagueTeam, Game, PartyGame, GameParticipation,
      Player, SeasonParticipation, Seeding
    ]

    models_with_region_taggable.each do |model_class|
      total_versions = PaperTrail::Version.where(item_type: model_class.name).count
      versions_with_region = PaperTrail::Version.where(item_type: model_class.name).where.not(region_id: nil).count
      versions_with_global = PaperTrail::Version.where(item_type: model_class.name, global_context: true).count
      
      puts "\n#{model_class.name}:"
      puts "  Total versions: #{total_versions}"
      puts "  With region_id: #{versions_with_region}"
      puts "  With global_context: #{versions_with_global}"
      puts "  Without region_id: #{total_versions - versions_with_region}"
    end

    # Overall statistics
    total_versions = PaperTrail::Version.count
    total_with_region = PaperTrail::Version.where.not(region_id: nil).count
    total_with_global = PaperTrail::Version.where(global_context: true).count
    
    puts "\nOverall Statistics:"
    puts "=================="
    puts "Total versions: #{total_versions}"
    puts "With region_id: #{total_with_region}"
    puts "With global_context: #{total_with_global}"
    puts "Without region_id: #{total_versions - total_with_region}"
  end

  desc "Verify that all versions have correct region data"
  task verify: :environment do
    puts "Verifying version region data..."
    
    # Get all models that include RegionTaggable
    models_with_region_taggable = [
      Region, Club, Tournament, League, Party, Location,
      LeagueTeam, Game, PartyGame, GameParticipation,
      Player, SeasonParticipation, Seeding
    ]

    total_errors = 0

    models_with_region_taggable.each do |model_class|
      puts "\nVerifying #{model_class.name}..."
      
      # Find versions that don't match their items
      mismatched_versions = PaperTrail::Version.where(item_type: model_class.name)
                                              .joins("INNER JOIN #{model_class.table_name} ON #{model_class.table_name}.id = versions.item_id")
                                              .where("versions.region_id IS NULL OR 
                                                     versions.region_id != #{model_class.table_name}.region_id OR 
                                                     versions.global_context != #{model_class.table_name}.global_context")
      
      error_count = mismatched_versions.count
      total_errors += error_count
      
      if error_count > 0
        puts "  Found #{error_count} versions with incorrect region data"
      else
        puts "  ✅ All versions have correct region data"
      end
    end

    if total_errors == 0
      puts "\n✅ All versions have correct region data!"
    else
      puts "\n❌ Found #{total_errors} versions with incorrect region data"
    end
  end
end 