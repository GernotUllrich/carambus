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
      # next unless region.id  == dbu_id
      organic_seeding_ids = []

      # compute organic region dependence top to bottom
      # region -> club -> season_participation -> player
      # region -> club -> club_location -> location
      # region -> location
      # location -> table
      unless region.id == dbu_id
        organic_region_ids = [region.id]
        organic_club_ids = region.club_ids
        organic_season_participation_ids = SeasonParticipation.joins(:club).where(clubs: { id: organic_club_ids }).ids
        organic_player_ids = Player.joins(:season_participations).where(season_participations: { id: organic_season_participation_ids }).ids
        organic_club_location_ids = ClubLocation.joins(:club).where(clubs: { id: organic_club_ids }).ids
        organic_location_ids = Location.joins(:club_locations).where(club_locations: { club_id: organic_club_location_ids }).ids
        organic_location_ids |= Location.where(organizer_type: "Region", organizer_id: region.id).ids
        organic_table_ids = Table.joins(:location).where(locations: { id: organic_location_ids }).ids
      end

      # compute organic region dependence top to bottom on region tournaments
      # region -> tournament -> game -> GameParticipation
      # region -> tournament -> seeding
      # region -> tournament -> location
      # GameParticipation -> player
      # seeding -> player

      # organic_tournament_ids  = region.tournament_ids
      organic_tournament_ids = region.organized_tournament_ids
      organic_tournament_ids |= Tournament.where(organizer_type: "Club", organizer_id: organic_club_ids).ids
      organic_game_ids = Game.joins(:tournament).where(tournaments: { id: organic_tournament_ids }).ids
      organic_game_participation_ids = GameParticipation.joins(game: :tournament).where(tournaments: { id: organic_tournament_ids }).ids
      tournament_player_ids = Player.joins(:game_participations).where(game_participations: { id: organic_game_participation_ids }).ids
      tournament_team_ids = Team.where(id: tournament_player_ids).ids
      Team.where(id: tournament_team_ids).all.each do |team|
        tournament_player_ids |= team.data["players"].map { |h| h["player_id"] }
      end
      organic_seeding_ids |= Seeding.where(tournament_id: organic_tournament_ids, tournament_type: "Tournament").ids
      tournament_player_ids |= Player.joins(:seedings).where(seedings: { id: organic_seeding_ids }).ids

      # compute organic region dependence top to bottom on region leagues
      # region -> league -> league_team
      # region -> league -> party -> party_game
      # region -> league -> party -> seeding
      #
      organic_league_ids = region.organized_league_ids
      organic_league_team_ids = LeagueTeam.joins(:league).where(leagues: { id: organic_league_ids }).ids
      organic_game_plan_ids = GamePlan.joins(:leagues).where(leagues: { id: organic_league_ids }).ids
      organic_party_ids = Party.joins(:league).where(leagues: { id: organic_league_ids }).ids
      organic_party_game_ids = PartyGame.joins(:party).where(parties: { id: organic_party_ids }).ids
      organic_seeding_ids |= Seeding.where(tournament_id: organic_party_ids, tournament_type: "Party").ids
      organic_seeding_ids |= Seeding.joins(:league_team => :parties_a).where(parties: { id: organic_party_ids }).ids
      organic_seeding_ids |= Seeding.joins(:league_team => :parties_b).where(parties: { id: organic_party_ids }).ids
      organic_seeding_ids |= Seeding.joins(:league_team => :parties_as_host).where(parties: { id: organic_party_ids }).ids
      league_player_ids = Player.joins(:seedings).where(seedings: { id: organic_seeding_ids }).ids
      league_player_ids |= Player.joins(:party_a_games).where(party_games: { id: organic_party_game_ids }).ids
      league_player_ids |= Player.joins(:party_b_games).where(party_games: { id: organic_party_game_ids }).ids

      if region.id == dbu_id

        # find global relationships from DBU organs bottom up
        global_player_ids = tournament_player_ids + league_player_ids
        global_season_participation_ids = SeasonParticipation.where(player_id: global_player_ids).ids
        global_club_ids = Club.joins(:season_participations).where(season_participations: { id: global_season_participation_ids }).ids
        global_location_ids = Location.joins(:tournaments).where(tournaments: { id: organic_tournament_ids }).ids
        global_location_ids |= Location.joins(:parties).where(parties: { id: organic_party_ids }).ids
        global_club_location_ids = ClubLocation.joins(:location).where(locations: { id: global_location_ids }).ids
        global_club_ids |= Club.joins(:club_locations).where(club_locations: { id: global_club_location_ids }).ids
        global_region_ids = Region.joins(:clubs).where(clubs: { id: global_club_ids }).ids
        global_table_ids = Table.joins(:location).where(locations: { id: global_location_ids }).ids

        # models which have global context from bottom up
        [Player, SeasonParticipation, Club, ClubLocation, Region, Location, Table].each do |model|
          tag_with_gobal_context(model, eval("global_#{model.name.underscore}_ids"))
        end

        # models which have global context, because they are organic with respect to the DBU region
        [Tournament, Game, GameParticipation, Seeding, League, Party, PartyGame, LeagueTeam, GamePlan].each do |model|
          tag_with_gobal_context(model, eval("organic_#{model.name.underscore}_ids"))
        end
      end

      # tag with region where objects organically relate to
      [Player, SeasonParticipation, ClubLocation, Region, Tournament, Game,
      GameParticipation, Seeding, League, Location, Table,
      Party,  PartyGame, LeagueTeam, Club, GamePlan].each do |model|
        tag_with_region(model, eval("organic_#{model.name.underscore}_ids"), region)
      end
    end
  end

  def tag_with_gobal_context(model, ids)
    model.where(id: ids).update_all(global_context: true)
    PaperTrail::Version.where(item_type: model.name, item_id: ids).update_all(global_context: true)
  end

  def tag_with_region(model, ids, region)
    model.where(id: ids).update_all(region_id: region.id) unless model == Club
    PaperTrail::Version.where(item_type: model.name, item_id: ids).update_all(region_id: region.id)
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
          # Update region_id and global_context for the record
          region_id = record.find_associated_region_id
          global_context = record.global_context?

          if record.region_id != region_id || record.global_context != global_context
            record.update_columns(
              region_id: region_id,
              global_context: global_context
            )
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
