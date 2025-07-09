namespace :version_cleanup do
  desc "Update all PaperTrail versions with correct region_id and global_context values"
  task update_region_data: :environment do
    puts "Starting version cleanup for region_id and global_context..."
    
    # Get all models that include RegionTaggable
    models_with_region_taggable = [
      Region, Club, Tournament, League, Party, Location,
      LeagueTeam, Game, PartyGame, GameParticipation,
      Player, SeasonParticipation, Seeding
    ]

    total_versions_updated = 0
    total_records_processed = 0

    models_with_region_taggable.each do |model_class|
      puts "\nProcessing #{model_class.name}..."
      
      # Process in batches to avoid memory issues
      model_class.find_in_batches(batch_size: 1000) do |batch|
        batch.each do |record|
          begin
            # Get the correct region_id and global_context for this record
            region_id = record.find_associated_region_id
            global_context = record.global_context?

            # Update the record itself if needed
            if record.region_id != region_id || record.global_context != global_context
              record.update_columns(
                region_id: region_id,
                global_context: global_context
              )
            end

            # Update all versions for this record in a single SQL operation
            versions_updated = PaperTrail::Version.where(
              item_type: model_class.name,
              item_id: record.id
            ).update_all(
              region_id: region_id,
              global_context: global_context
            )

            total_versions_updated += versions_updated
            total_records_processed += 1

          rescue StandardError => e
            Rails.logger.error("Error processing #{model_class.name} ID #{record.id}: #{e.message}")
            puts "Error processing #{model_class.name} ID #{record.id}: #{e.message}"
          end
        end
      end

      puts "  Completed #{model_class.name}: #{total_records_processed} records processed"
    end

    puts "\nCleanup Summary:"
    puts "================="
    puts "Total records processed: #{total_records_processed}"
    puts "Total versions updated: #{total_versions_updated}"
  end

  desc "Update all PaperTrail versions using efficient SQL operations (FASTEST)"
  task update_region_data_sql: :environment do
    puts "Starting SQL-based version cleanup for region_id and global_context..."
    
    # Get all models that include RegionTaggable
    models_with_region_taggable = [
      Region, Club, Tournament, League, Party, Location,
      LeagueTeam, Game, PartyGame, GameParticipation,
      Player, SeasonParticipation, Seeding
    ]

    total_versions_updated = 0

    models_with_region_taggable.each do |model_class|
      puts "\nProcessing #{model_class.name} with SQL..."
      
      begin
        # Build the SQL update statement based on the model type
        sql = build_version_update_sql(model_class)
        
        if sql
          # Execute the SQL update
          result = ActiveRecord::Base.connection.execute(sql)
          versions_updated = result.cmd_tuples
          total_versions_updated += versions_updated
          
          puts "  Updated #{versions_updated} versions for #{model_class.name}"
        else
          puts "  No SQL update available for #{model_class.name} - skipping"
        end
        
      rescue StandardError => e
        Rails.logger.error("Error processing #{model_class.name}: #{e.message}")
        puts "Error processing #{model_class.name}: #{e.message}"
      end
    end

    puts "\nSQL Cleanup Summary:"
    puts "===================="
    puts "Total versions updated: #{total_versions_updated}"
  end

  desc "Update versions for a specific model type"
  task :update_model, [:model_name] => :environment do |task, args|
    model_name = args[:model_name]
    
    if model_name.blank?
      puts "Please specify a model name: rails version_cleanup:update_model[ModelName]"
      exit
    end

    begin
      model_class = model_name.constantize
    rescue NameError
      puts "Model '#{model_name}' not found"
      exit
    end

    unless model_class.included_modules.include?(RegionTaggable)
      puts "Model '#{model_name}' does not include RegionTaggable"
      exit
    end

    puts "Updating versions for #{model_class.name}..."
    
    total_versions_updated = 0
    total_records_processed = 0

    model_class.find_in_batches(batch_size: 1000) do |batch|
      batch.each do |record|
        begin
          # Get the correct region_id and global_context for this record
          region_id = record.find_associated_region_id
          global_context = record.global_context?

          # Update the record itself if needed
          if record.region_id != region_id || record.global_context != global_context
            record.update_columns(
              region_id: region_id,
              global_context: global_context
            )
          end

          # Update all versions for this record in a single SQL operation
          versions_updated = PaperTrail::Version.where(
            item_type: model_class.name,
            item_id: record.id
          ).update_all(
            region_id: region_id,
            global_context: global_context
          )

          total_versions_updated += versions_updated
          total_records_processed += 1

        rescue StandardError => e
          Rails.logger.error("Error processing #{model_class.name} ID #{record.id}: #{e.message}")
          puts "Error processing #{model_class.name} ID #{record.id}: #{e.message}"
        end
      end
    end

    puts "\nSummary for #{model_class.name}:"
    puts "Total records processed: #{total_records_processed}"
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
      
      model_class.find_each do |record|
        begin
          expected_region_id = record.find_associated_region_id
          expected_global_context = record.global_context?

          # Check if record itself is correct
          if record.region_id != expected_region_id || record.global_context != expected_global_context
            puts "  Record #{record.id}: region_id mismatch (expected: #{expected_region_id}, got: #{record.region_id})" if record.region_id != expected_region_id
            puts "  Record #{record.id}: global_context mismatch (expected: #{expected_global_context}, got: #{record.global_context})" if record.global_context != expected_global_context
            total_errors += 1
          end

          # Check versions
          record.versions.each do |version|
            if version.region_id != expected_region_id || version.global_context != expected_global_context
              puts "  Version #{version.id} for #{model_class.name} #{record.id}: region_id mismatch (expected: #{expected_region_id}, got: #{version.region_id})" if version.region_id != expected_region_id
              puts "  Version #{version.id} for #{model_class.name} #{record.id}: global_context mismatch (expected: #{expected_global_context}, got: #{version.global_context})" if version.global_context != expected_global_context
              total_errors += 1
            end
          end

        rescue StandardError => e
          puts "  Error verifying #{model_class.name} ID #{record.id}: #{e.message}"
          total_errors += 1
        end
      end
    end

    if total_errors == 0
      puts "\n✅ All versions have correct region data!"
    else
      puts "\n❌ Found #{total_errors} errors in version region data"
    end
  end

  private

  def build_version_update_sql(model_class)
    table_name = model_class.table_name
    model_name = model_class.name
    
    case model_class.name
    when 'Region'
      # Regions are their own region
      <<~SQL
        UPDATE versions 
        SET region_id = versions.item_id, global_context = false
        WHERE item_type = '#{model_name}' 
        AND (region_id IS NULL OR region_id != item_id OR global_context != false)
      SQL
    when 'Club'
      # Clubs get their region_id from the clubs table
      <<~SQL
        UPDATE versions 
        SET region_id = clubs.region_id, global_context = clubs.global_context
        FROM clubs 
        WHERE versions.item_type = '#{model_name}' 
        AND versions.item_id = clubs.id
        AND (versions.region_id IS NULL OR versions.region_id != clubs.region_id OR versions.global_context != clubs.global_context)
      SQL
    when 'Tournament'
      # Tournaments get region_id from organizer if it's a Region
      <<~SQL
        UPDATE versions 
        SET region_id = CASE 
          WHEN tournaments.organizer_type = 'Region' THEN tournaments.organizer_id 
          ELSE NULL 
        END,
        global_context = CASE 
          WHEN tournaments.organizer_type = 'Region' AND regions.shortname = 'DBU' THEN true
          ELSE false
        END
        FROM tournaments 
        LEFT JOIN regions ON regions.id = tournaments.organizer_id
        WHERE versions.item_type = '#{model_name}' 
        AND versions.item_id = tournaments.id
        AND (versions.region_id IS NULL OR versions.region_id != CASE 
          WHEN tournaments.organizer_type = 'Region' THEN tournaments.organizer_id 
          ELSE NULL 
        END OR versions.global_context != CASE 
          WHEN tournaments.organizer_type = 'Region' AND regions.shortname = 'DBU' THEN true
          ELSE false
        END)
      SQL
    when 'League'
      # Leagues get region_id from organizer if it's a Region
      <<~SQL
        UPDATE versions 
        SET region_id = CASE 
          WHEN leagues.organizer_type = 'Region' THEN leagues.organizer_id 
          ELSE NULL 
        END,
        global_context = CASE 
          WHEN leagues.organizer_type = 'Region' AND regions.shortname = 'DBU' THEN true
          ELSE false
        END
        FROM leagues 
        LEFT JOIN regions ON regions.id = leagues.organizer_id
        WHERE versions.item_type = '#{model_name}' 
        AND versions.item_id = leagues.id
        AND (versions.region_id IS NULL OR versions.region_id != CASE 
          WHEN leagues.organizer_type = 'Region' THEN leagues.organizer_id 
          ELSE NULL 
        END OR versions.global_context != CASE 
          WHEN leagues.organizer_type = 'Region' AND regions.shortname = 'DBU' THEN true
          ELSE false
        END)
      SQL
    when 'Party'
      # Parties get region_id from their league's organizer
      <<~SQL
        UPDATE versions 
        SET region_id = CASE 
          WHEN leagues.organizer_type = 'Region' THEN leagues.organizer_id 
          ELSE NULL 
        END,
        global_context = CASE 
          WHEN leagues.organizer_type = 'Region' AND regions.shortname = 'DBU' THEN true
          ELSE false
        END
        FROM parties 
        LEFT JOIN leagues ON leagues.id = parties.league_id
        LEFT JOIN regions ON regions.id = leagues.organizer_id
        WHERE versions.item_type = '#{model_name}' 
        AND versions.item_id = parties.id
        AND (versions.region_id IS NULL OR versions.region_id != CASE 
          WHEN leagues.organizer_type = 'Region' THEN leagues.organizer_id 
          ELSE NULL 
        END OR versions.global_context != CASE 
          WHEN leagues.organizer_type = 'Region' AND regions.shortname = 'DBU' THEN true
          ELSE false
        END)
      SQL
    when 'Game'
      # Games get region_id from their tournament
      <<~SQL
        UPDATE versions 
        SET region_id = CASE 
          WHEN tournaments.organizer_type = 'Region' THEN tournaments.organizer_id 
          ELSE tournaments.region_id
        END,
        global_context = CASE 
          WHEN tournaments.organizer_type = 'Region' AND regions.shortname = 'DBU' THEN true
          ELSE false
        END
        FROM games 
        LEFT JOIN tournaments ON tournaments.id = games.tournament_id
        LEFT JOIN regions ON regions.id = tournaments.organizer_id
        WHERE versions.item_type = '#{model_name}' 
        AND versions.item_id = games.id
        AND (versions.region_id IS NULL OR versions.region_id != CASE 
          WHEN tournaments.organizer_type = 'Region' THEN tournaments.organizer_id 
          ELSE tournaments.region_id
        END OR versions.global_context != CASE 
          WHEN tournaments.organizer_type = 'Region' AND regions.shortname = 'DBU' THEN true
          ELSE false
        END)
      SQL
    when 'Location'
      # Locations get region_id from organizer if it's a Region
      <<~SQL
        UPDATE versions 
        SET region_id = CASE 
          WHEN locations.organizer_type = 'Region' THEN locations.organizer_id 
          ELSE NULL 
        END,
        global_context = false
        FROM locations 
        WHERE versions.item_type = '#{model_name}' 
        AND versions.item_id = locations.id
        AND (versions.region_id IS NULL OR versions.region_id != CASE 
          WHEN locations.organizer_type = 'Region' THEN locations.organizer_id 
          ELSE NULL 
        END OR versions.global_context != false)
      SQL
    when 'Player'
      # Players get region_id from their primary club
      <<~SQL
        UPDATE versions 
        SET region_id = clubs.region_id, global_context = clubs.global_context
        FROM players 
        LEFT JOIN season_participations ON season_participations.player_id = players.id
        LEFT JOIN clubs ON clubs.id = season_participations.club_id
        WHERE versions.item_type = '#{model_name}' 
        AND versions.item_id = players.id
        AND clubs.id = (
          SELECT club_id FROM season_participations 
          WHERE player_id = players.id 
          ORDER BY created_at DESC 
          LIMIT 1
        )
        AND (versions.region_id IS NULL OR versions.region_id != clubs.region_id OR versions.global_context != clubs.global_context)
      SQL
    when 'SeasonParticipation'
      # SeasonParticipations get region_id from their club
      <<~SQL
        UPDATE versions 
        SET region_id = clubs.region_id, global_context = clubs.global_context
        FROM season_participations 
        LEFT JOIN clubs ON clubs.id = season_participations.club_id
        WHERE versions.item_type = '#{model_name}' 
        AND versions.item_id = season_participations.id
        AND (versions.region_id IS NULL OR versions.region_id != clubs.region_id OR versions.global_context != clubs.global_context)
      SQL
    else
      # For other models, return nil to skip
      nil
    end
  end
end 