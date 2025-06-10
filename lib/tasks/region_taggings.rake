namespace :region_taggings do
  desc "Update region taggings for all models that include RegionTaggable"
  task update_all: :environment do
    # Define the order of models to process, from most basic to most dependent
    models_to_process = [
      # Basic models
      { model: Region, description: "Regions" },
      { model: Club, description: "Clubs" },
      { model: Tournament, description: "Tournaments" },
      { model: League, description: "Leagues" },
      { model: Party, description: "Parties" },
      
      # Models that depend on basic models
      { model: Location, description: "Locations" },
      { model: LeagueTeam, description: "League Teams" },
      { model: Game, description: "Games" },
      { model: PartyGame, description: "Party Games" },
      { model: GameParticipation, description: "Game Participations" },
      
      # Most dependent models
      { model: Player, description: "Players" },
      { model: SeasonParticipation, description: "Season Participations" },
      { model: Seeding, description: "Seedings" }
    ]

    total_processed = 0
    total_updated = 0

    models_to_process.each do |model_info|
      model = model_info[:model]
      description = model_info[:description]
      
      puts "\nProcessing #{description}..."
      
      # Get all records for this model
      records = model.all
      count = records.count
      
      puts "Found #{count} #{description.downcase}"
      
      # Process in batches to avoid memory issues
      records.find_each(batch_size: 1000).with_index do |record, index|
        begin
          # Force update of region taggings
          record.send(:update_region_taggings)
          
          # Count successful updates
          if record.region_taggings.any?
            total_updated += 1
          end
          
          # Progress indicator
          if (index + 1) % 100 == 0
            print "."
            STDOUT.flush
          end
          
          total_processed += 1
        rescue StandardError => e
          puts "\nError processing #{description} ID #{record.id}: #{e.message}"
          Rails.logger.error("Error updating region taggings for #{description} ID #{record.id}: #{e.message}\n#{e.backtrace.join("\n")}")
        end
      end
      
      puts "\nCompleted #{description}: #{total_updated} records updated with region taggings"
    end

    puts "\nSummary:"
    puts "Total records processed: #{total_processed}"
    puts "Total records with region taggings: #{total_updated}"
  end

  desc "Verify region taggings for all models"
  task verify: :environment do
    models_to_verify = [
      Region, Club, Tournament, League, Party, Location, 
      LeagueTeam, Game, PartyGame, GameParticipation,
      Player, SeasonParticipation, Seeding
    ]

    models_to_verify.each do |model|
      puts "\nVerifying #{model.name}..."
      
      # Count records with and without region taggings
      total = model.count
      with_taggings = model.joins(:region_taggings).distinct.count
      without_taggings = total - with_taggings
      
      puts "Total records: #{total}"
      puts "Records with region taggings: #{with_taggings}"
      puts "Records without region taggings: #{without_taggings}"
      
      if without_taggings > 0
        puts "Records without region taggings:"
        model.left_joins(:region_taggings)
             .where(region_taggings: { id: nil })
             .limit(5)
             .each do |record|
          puts "  ID: #{record.id}"
        end
        puts "  ..." if without_taggings > 5
      end
    end
  end

  desc "Clean up invalid region taggings"
  task cleanup: :environment do
    puts "Cleaning up invalid region taggings..."
    
    # Remove taggings for non-existent records
    invalid_taggings = RegionTagging.where.not(
      taggable_type: [
        'Region', 'Club', 'Tournament', 'League', 'Party', 'Location',
        'LeagueTeam', 'Game', 'PartyGame', 'GameParticipation',
        'Player', 'SeasonParticipation', 'Seeding'
      ]
    )
    
    if invalid_taggings.any?
      puts "Found #{invalid_taggings.count} taggings with invalid taggable_type"
      invalid_taggings.destroy_all
    end

    # Remove taggings for non-existent regions
    invalid_region_taggings = RegionTagging.where.not(
      region_id: Region.pluck(:id)
    )
    
    if invalid_region_taggings.any?
      puts "Found #{invalid_region_taggings.count} taggings with invalid region_id"
      invalid_region_taggings.destroy_all
    end

    # Remove taggings for non-existent records
    models_to_check = [
      Region, Club, Tournament, League, Party, Location,
      LeagueTeam, Game, PartyGame, GameParticipation,
      Player, SeasonParticipation, Seeding
    ]

    models_to_check.each do |model|
      invalid_taggings = RegionTagging.where(taggable_type: model.name)
                                    .where.not(taggable_id: model.pluck(:id))
      
      if invalid_taggings.any?
        puts "Found #{invalid_taggings.count} taggings for non-existent #{model.name} records"
        invalid_taggings.destroy_all
      end
    end

    puts "Cleanup completed"
  end
end 