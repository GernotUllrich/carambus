namespace :region_taggings do

  desc "Update region_id for all models that include RegionTaggable"
  task update_all_region_id: :environment do
    dbu_id = Region.find_by_shortname("DBU").id
    # clear all region_id tags
    [
      SeasonParticipation, Region, Player, ClubLocation, Location, Table,
      Game, GameParticipation, Seeding, League, LeagueTeam, Party, PartyGame,
      GamePlan
    ].each do |model|
      model.update_all(region_id: nil, global_context: false)
    end
    Region.all.each do |region|
      party_ids = []
      club_ids = []
      region_id = region.id
      league_ids = []
      location_ids = []
      seeding_ids = []
      tournament_ids = []
      global_player_ids = []

      unless region.id == dbu_id
        club_ids |= region.club_ids
        SeasonParticipation.joins(:club).where(clubs: { id: club_ids }).update_all(region_id: region.id)
        Player.joins(:season_participations => :club).where(clubs: { id: club_ids }).update_all(region_id: region.id)
        Club.where(id: club_ids).update_all(region_id: region.id)
        ClubLocation.joins(:club).where(clubs: { id: club_ids }).update_all(region_id: region.id)
        location_ids |= Location.joins(:club_locations => :club).where(clubs: { id: club_ids }).ids
        Location.where(id: location_ids).update_all(region_id: region.id)
        Table.joins(:location).where(locations: { id: location_ids }).update_all(region_id: region.id)
      end

      tournament_ids |= region.tournament_ids
      tournament_ids |= region.organized_tournament_ids
      tournament_ids |= Tournament.where(organizer_type: "Club", organizer_id: club_ids).ids
      league_ids |= region.organized_league_ids

      Tournament.where(id: tournament_ids).update_all(region_id: region.id)
      Tournament.where(id: tournament_ids).update_all(global_context: true) if region.id == dbu_id
      Game.joins(:tournament).where(tournaments: { id: tournament_ids }).update_all(region_id: region.id)
      Game.joins(:tournament).where(tournaments: { id: tournament_ids }).update_all(global_context: true) if region.id == dbu_id
      GameParticipation.joins(:game => :tournament).where(tournaments: { id: tournament_ids }).update_all(region_id: region.id)
      GameParticipation.joins(:game => :tournament).where(tournaments: { id: tournament_ids }).update_all(global_context: true) if region.id == dbu_id
      if region.id == dbu_id
        global_player_ids |= Player.joins(:game_participations => { :game => :tournament }).where(tournaments: { id: tournament_ids }).ids
      end
      Team.joins(:tournament).where(tournaments: { id: tournament_ids }).update_all(global_context: true) if region.id == dbu_id
      Seeding.where(tournament_id: tournament_ids, tournament_type: "Region").update_all(region_id: region.id)
      Seeding.where(tournament_id: tournament_ids, tournament_type: "Region").update_all(global_context: true) if region.id == dbu_id

      League.where(id: league_ids).update_all(region_id: region.id)
      League.where(id: league_ids).update_all(global_context: true) if region.id == dbu_id
      LeagueTeam.joins(:league).where(leagues: { id: league_ids }).update_all(region_id: region.id)
      LeagueTeam.joins(:league).where(leagues: { id: league_ids }).update_all(global_context: true) if region.id == dbu_id
      party_ids = Party.joins(:league).where(leagues: { id: league_ids }).ids
      Party.where(id: party_ids).update_all(region_id: region.id)
      Party.where(id: party_ids).update_all(global_context: true) if region.id == dbu_id
      PartyGame.joins(:party).where(parties: { id: party_ids }).update_all(region_id: region.id)
      PartyGame.joins(:party).where(parties: { id: party_ids }).update_all(global_context: true) if region.id == dbu_id
      seeding_ids |= Seeding.joins(:league_team => :parties_a).where(parties: { id: party_ids }).ids
      seeding_ids |= Seeding.joins(:league_team => :parties_b).where(parties: { id: party_ids }).ids
      seeding_ids |= Seeding.joins(:league_team => :parties_as_host).where(parties: { id: party_ids }).ids
      Seeding.where(id: seeding_ids).update_all(region_id: region.id)
      Seeding.where(id: seeding_ids).update_all(global_context: true) if region.id == dbu_id
      if region.id == dbu_id
        global_player_ids |= Player.joins(:seedings).where(seedings: { id: seeding_ids }).ids
      end
      if region.id == dbu_id
        Player.where(id: global_player_ids).update_all(global_context: true)
        SeasonParticipation.joins(:player).where(players: { id: global_player_ids }).update_all(global_context: true)
        Club.joins(:season_participations => :player).where(players: { id: global_player_ids }).update_all(global_context: true)
        Region.joins(:clubs => { :season_participations => :player }).where(players: { id: global_player_ids }).update_all(global_context: true)
      end

      Region.where(id: region_id).update_all(region_id: region.id)
    end
  end

  desc "Update region taggings for all models that include RegionTaggable"
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
end
