namespace :region_taggings do

  desc "Update region_ids for all models that include RegionTaggable"
  task update_all_region_ids: :environment do
    dbu_id = Region.find_by_shortname("DBU").id
    Region.all.each do |region|
      # next unless region.id  == 1
      if region.id == dbu_id
      else
        party_ids = []
        club_ids = []
        region_ids = [region.id]
        league_ids = []
        location_ids = []
        seeding_ids = []
        tournament_ids = []

        club_ids |= region.club_ids
        SeasonParticipation.joins(:club).where(clubs: { id: club_ids }).update_all(region_ids: [region.id])
        Player.joins(:season_participations => :club).where(clubs: { id: club_ids }).update_all(region_ids: [region.id])
        ClubLocation.joins(:club).where(clubs: { id: club_ids }).update_all(region_ids: [region.id])
        location_ids |= Location.joins(:club_locations => :club).where(clubs: { id: club_ids }).ids
        # region.clubs.find_each(batch_size: 1000) do |club|
        #   #club.season_participations.update_all(region_ids: [region.id])
        #   # club.season_participations.find_each(batch_size: 1000) do |season_participation|
        #   #   #season_participation.update_columns(region_ids: season_participation.region_ids.extract(dbu_id) | [region.id])
        #   #   player_ids |= [season_participation.player_id]
        #   # end
        #   #club.club_locations.update_all(region_ids: [region.id])
        #   # club.club_locations.find_each(batch_size: 1000) do |club_location|
        #   #   #club_location.update_columns(region_ids: club_location.region_ids.extract(dbu_id) | [region.id])
        #   #   location_ids |= [club_location.location_id]
        #   # end
        # end

        tournament_ids |= region.tournament_ids
        tournament_ids |= region.organized_tournament_ids
        league_ids |= region.organized_league_ids

        Tournament.where(id: tournament_ids).update_all(region_ids: [region.id])
        Game.joins(:tournament).where(tournaments: { id: tournament_ids }).update_all(region_ids: [region.id])
        GameParticipation.joins(:game => :tournament).where(tournaments: { id: tournament_ids }).update_all(region_ids: [region.id])
        Player.joins(:game_participations => {:game => :tournament}).where(tournaments: { id: tournament_ids }).update_all(region_ids: [region.id])
        Team.joins(:tournament).where(tournaments: { id: tournament_ids }).update_all(region_ids: [region.id])
        Seeding.where(tournament_id: tournament_ids , tournament_type: "Region").update_all(region_ids: [region.id])
        Club.joins(:organized_tournaments).where(tournaments: { id: tournament_ids }).update_all(region_ids: [region.id])
        # Tournament.where(id: tournament_ids).find_each(batch_size: 1000) do |tournament|
        #   #tournament.update_columns(region_ids: tournament.region_ids.extract(dbu_id) | [region.id])
        #   seeding_ids |= tournament.seeding_ids
        #   #tournament.games.update_all(region_ids: [region.id])
        #   # tournament.games.find_each(batch_size: 1000) do |game|
        #   #   game.update_columns(region_ids: game.region_ids.extract(dbu_id) | [region.id])
        #   # end
        #   #tournament.teams.update_all(region_ids: [region.id])
        #   # tournament.teams.find_each(batch_size: 1000) do |team|
        #   #   team.update_columns(region_ids: team.region_ids.extract(dbu_id) | [region.id])
        #   # end
        #   #club_ids |= tournament.where(organizer_type = "Club").find_each(batch_size: 1000).map(&:id)
        # end

        League.where(id: league_ids).update_all(region_ids: [region.id])
        LeagueTeam.joins(:league).where(leagues: { id: league_ids }).update_all(region_ids: [region.id])
        Party.joins(:league).where(leagues: { id: league_ids }).update_all(region_ids: [region.id])
        # League.where(id: league_ids).find_each(batch_size: 1000) do |league|
        #   #league.region_ids = league.region_ids.extract(dbu_id) | [region.id]
        #   # league.league_teams.update_all(region_ids: [region.id])
        #   # league.league_teams.find_each(batch_size: 1000) do |league_team|
        #   #   league_team.update_columns(region_ids: league_team.region_ids.extract(dbu_id) | [region.id])
        #   # end
        #   party_ids |= league.party_ids
        # end
        #
        region.organized_tournaments.update_all(region_ids: [region.id])
        # region.organized_tournaments.find_each(batch_size: 1000) do |tournament|
        #   tournament.region_ids = tournament.region_ids.extract(dbu_id) | [region.id]
        # end
        region.organized_leagues.update_all(region_ids: [region.id])
        # region.organized_leagues.find_each(batch_size: 1000) do |league|
        #   league.region_ids = league.region_ids.extract(dbu_id) | [region.id]
        # end

        Club.where(id: club_ids).update_all(region_ids: [region.id])
        # Club.where(id: club_ids).find_each(batch_size: 1000) do |club|
        #   club.update_columns(region_ids: club.region_ids.extract(dbu_id) | [region.id])
        # end
        #
        Location.where(id: location_ids).update_all(region_ids: [region.id])
        Table.joins(:location).where(locations: {id: location_ids}).update_all(region_ids: [region.id])
        party_ids |=Party.joins(:location).where(locations: {id: location_ids}).ids
        # Location.where(id: location_ids).find_each(batch_size: 1000) do |location|
        #   #location.tables.update_all(region_ids: [region.id])
        #   # location.tables.find_each(batch_size: 1000) do |table|
        #   #   table.update_columns(region_ids: table.region_ids.extract(dbu_id) | [region.id])
        #   # end
        #   party_ids |= location.party_ids
        # end

        Party.where(id: party_ids).update_all(region_ids: [region.id])
        PartyGame.joins(:party).where(parties: { id: party_ids }).update_all(region_ids: [region.id])
        seeding_ids |= Seeding.joins(:league_team => :parties_a).where(parties: { id: party_ids }).ids
        seeding_ids |= Seeding.joins(:league_team => :parties_b).where(parties: { id: party_ids }).ids
        seeding_ids |= Seeding.joins(:league_team => :parties_as_host).where(parties: { id: party_ids }).ids
        # Party.where(id: party_ids).find_each(batch_size: 1000) do |party|
        #   #party.update_columns(region_ids: party.region_ids.extract(dbu_id) | [region.id])
        #   party.party_games.update_all(region_ids: [region.id])
        #   # party.party_games.find_each(batch_size: 1000) do |party_game|
        #   #   party_game.update_columns(region_ids: party_game.region_ids.extract(dbu_id) | [region.id])
        #   # end
        #   seeding_ids |= party.seedings
        # end

        Seeding.where(id: seeding_ids).update_all(region_ids: [region.id])

        Player.joins(:seedings).where(seedings: { id: seeding_ids }).update_all(region_ids: [region.id])
        # Seeding.where(id: seeding_ids).find_each(batch_size: 1000) do |seeding|
        #   #seeding.update_columns(region_ids: seeding.region_ids.extract(dbu_id) | [region.id])
        #   player_ids |= [seeding.player]
        # end

        # Player.where(id: player_ids).update_all(region_ids: [region.id])
        # Player.where(id: player_ids).find_each(batch_size: 1000) do |player|
        #   player.update_columns(region_ids: player.region_ids.extract(dbu_id) | [region.id])
        # end

        Region.where(id: region_ids).update_all(region_ids: [region.id])
        # Region.where(id: region_ids).find_each(batch_size: 1000) do |region_|
        #   region_.update_columns(region_ids: region_.region_ids.extract(dbu_id) | [region.id])
        # end
      end
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
