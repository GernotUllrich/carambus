namespace :region_taggings do

  desc "Update region_id for all models that include RegionTaggable"
  task update_all_region_ids: :environment do
    dbu_id = Region.find_by_shortname("DBU").id
    Region.all.each do |region|
      # next unless region.id  == 1
      if region.id == dbu_id
      else
        party_ids = []
        club_ids = []
        league_ids = []
        location_ids = []
        seeding_ids = []
        tournament_ids = []

        club_ids |= region.club_ids
        SeasonParticipation.joins(:club).where(clubs: { id: club_ids }).update_all(region_id: region.id)
        Player.joins(:season_participations => :club).where(clubs: { id: club_ids }).update_all(region_id: region.id)
        ClubLocation.joins(:club).where(clubs: { id: club_ids }).update_all(region_id: region.id)
        location_ids |= Location.joins(:club_locations => :club).where(clubs: { id: club_ids }).ids

        tournament_ids |= region.tournament_ids
        tournament_ids |= region.organized_tournament_ids
        league_ids |= region.organized_league_ids

        Tournament.where(id: tournament_ids).update_all(region_id: region.id)
        Game.joins(:tournament).where(tournaments: { id: tournament_ids }).update_all(region_id: region.id)
        GameParticipation.joins(:game => :tournament).where(tournaments: { id: tournament_ids }).update_all(region_id: region.id)
        Player.joins(:game_participations => {:game => :tournament}).where(tournaments: { id: tournament_ids }).update_all(region_id: region.id)
        Team.joins(:tournament).where(tournaments: { id: tournament_ids }).update_all(region_id: region.id)
        Seeding.where(tournament_id: tournament_ids , tournament_type: "Region").update_all(region_id: region.id)
        Club.joins(:organized_tournaments).where(tournaments: { id: tournament_ids }).update_all(region_id: region.id)

        League.where(id: league_ids).update_all(region_id: region.id)
        LeagueTeam.joins(:league).where(leagues: { id: league_ids }).update_all(region_id: region.id)
        Party.joins(:league).where(leagues: { id: league_ids }).update_all(region_id: region.id)

        region.organized_tournaments.update_all(region_id: region.id)
        region.organized_leagues.update_all(region_id: region.id)

        Club.where(id: club_ids).update_all(region_id: region.id)

        Location.where(id: location_ids).update_all(region_id: region.id)
        Table.joins(:location).where(locations: {id: location_ids}).update_all(region_id: region.id)
        party_ids |=Party.joins(:location).where(locations: {id: location_ids}).ids

        Party.where(id: party_ids).update_all(region_id: region.id)
        PartyGame.joins(:party).where(parties: { id: party_ids }).update_all(region_id: region.id)
        seeding_ids |= Seeding.joins(:league_team => :parties_a).where(parties: { id: party_ids }).ids
        seeding_ids |= Seeding.joins(:league_team => :parties_b).where(parties: { id: party_ids }).ids
        seeding_ids |= Seeding.joins(:league_team => :parties_as_host).where(parties: { id: party_ids }).ids

        Seeding.where(id: seeding_ids).update_all(region_id: region.id)

        Player.joins(:seedings).where(seedings: { id: seeding_ids }).update_all(region_id: region.id)

        Region.where(id: region.id).update_all(region_id: region.id)
      end
    end
  end

  desc "Update region tagging for all models that include RegionTaggable"
  task update_all: :environment do
    if Carambus.config.carambus_api_url.present?
      puts "region tagging allowed only in API Server!"
      exit
    end
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
          # Force update of region tagging
          record.send(:update_region_tagging)

          # Count successful updates
          if record.region_id.present?
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
          Rails.logger.error("Error updating region tagging for #{description} ID #{record.id}: #{e.message}\n#{e.backtrace.join("\n")}")
        end
      end

      puts "\nCompleted #{description}: #{total_updated} records updated with region tagging"
    end

    puts "\nSummary:"
    puts "Total records processed: #{total_processed}"
    puts "Total records with region tagging: #{total_updated}"
  end

  desc "Verify region tagging for all models"
  task verify: :environment do
    models_to_verify = [
      Region, Club, Tournament, League, Party, Location,
      LeagueTeam, Game, PartyGame, GameParticipation,
      Player, SeasonParticipation, Seeding
    ]

    models_to_verify.each do |model|
      puts "\nVerifying #{model.name}..."

      # Count records with and without region_id
      total = model.count
      with_region_id = model.where.not(region_id: nil).count
      without_region_id = total - with_region_id

      puts "Total records: #{total}"
      puts "Records with region_id: #{with_region_id}"
      puts "Records without region_id: #{without_region_id}"

      if without_region_id > 0
        puts "Records without region_id:"
        model.where(region_id: nil)
             .limit(5)
             .each do |record|
          puts "  ID: #{record.id}"
        end
        puts "  ..." if without_region_id > 5
      end
    end
  end

  desc "Set global_context flag for records that participate in global events"
  task set_global_context: :environment do
    models_to_process = [
      Tournament, League, Party, GameParticipation, Player
    ]

    total_processed = 0
    total_global = 0

    models_to_process.each do |model|
      puts "\nProcessing #{model.name} for global context..."

      records = model.all
      count = records.count
      puts "Found #{count} records"

      records.find_each(batch_size: 1000).with_index do |record, index|
        begin
          if record.respond_to?(:global_context?) && record.global_context?
            record.update_column(:global_context, true)
            total_global += 1
          end

          if (index + 1) % 100 == 0
            print "."
            STDOUT.flush
          end

          total_processed += 1
        rescue StandardError => e
          puts "\nError processing #{model.name} ID #{record.id}: #{e.message}"
        end
      end

      puts "\nCompleted #{model.name}: #{total_global} records marked as global context"
    end

    puts "\nSummary:"
    puts "Total records processed: #{total_processed}"
    puts "Total records with global context: #{total_global}"
  end

  desc "Update existing versions with region_id and global_context"
  task update_existing_versions: :environment do
    puts "Updating existing versions with region_id and global_context..."
    
    # Get all models that include RegionTaggable
    models_with_region_taggable = [
      Region, Club, Tournament, League, Party, Location,
      LeagueTeam, Game, PartyGame, GameParticipation,
      Player, SeasonParticipation, Seeding
    ]

    total_versions_updated = 0

    models_with_region_taggable.each do |model_class|
      puts "\nProcessing versions for #{model_class.name}..."
      
      model_class.find_each do |record|
        begin
          # Update the record's region_id and global_context
          region_id = record.find_associated_region_id
          global_context = record.global_context?
          
          record.update_columns(
            region_id: region_id,
            global_context: global_context
          )
          
          # Update all versions for this record
          record.versions.each do |version|
            version.update_columns(
              region_id: region_id,
              global_context: global_context
            )
            total_versions_updated += 1
          end
        rescue StandardError => e
          Rails.logger.error("Error updating versions for #{model_class.name} ID #{record.id}: #{e.message}")
        end
      end
    end

    puts "\nSummary:"
    puts "Total versions updated: #{total_versions_updated}"
  end
end
