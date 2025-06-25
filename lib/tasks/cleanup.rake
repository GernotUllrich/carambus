# lib/tasks/cleanup.rake
namespace :cleanup do
  desc "Remove records not associated with the local server's region"
  task remove_non_region_records: :environment do
    region = Region.find_by_shortname(Carambus.config.context)
    region_id = region.id
    # dbu = Region.find_by_shortname("DBU")
    # dbu_id = dbu.id
    # puts "Cleaning up records not associated with region: #{region.name} (#{region.shortname})"
    #
    # # Track statistics
    # stats = {}
    #
    # # Step 1: Find all core records we want to keep
    # puts "\nFinding core records to keep..."
    #
    # # Find all tournaments we want to keep
    # tournament_ids = Tournament.where(id: [
    #   # Tournaments in our region
    #   Tournament.where(region_id: region_id).select(:id).map(&:id),
    #   # Tournaments organized by our region
    #   Tournament.where(organizer: region).select(:id).map(&:id),
    #   # Tournaments organized by DBU
    #   Tournament.where(organizer_type: 'Region', organizer_id: dbu_id).select(:id).map(&:id)
    # ].flatten).pluck(:id).uniq
    #
    # tournament_seeding_ids = Seeding.where(tournament_id: tournament_ids, tournament_type: "Region")
    #
    # # Find all leagues we want to keep
    # league_ids = League.where(organizer: region)
    #                   .or(League.where(organizer_type: 'Region', organizer_id: dbu_id))
    #                   .pluck(:id)
    # league_seeding_ids = Seeding.where(tournament_id: tournament_ids, tournament_type: "Region")
    # seeding_ids = tournament_seeding_ids + league_seeding_ids
    #
    # # Find all parties in our leagues
    # party_ids = Party.joins(:league)
    #                 .where(league_id: league_ids)
    #                 .pluck(:id)
    #
    # # Find all party games in our parties
    # party_game_ids = PartyGame.where(party_id: party_ids)
    #                          .pluck(:id)
    #
    # # Find all regions we want to keep
    # region_ids = Region.where(id: [
    #   # Our region and DBU
    #   [region_id, dbu_id],
    #   # Regions of clubs that participate in DBU tournaments
    #   Region.joins(:clubs => :organized_tournaments)
    #         .where(tournaments: { organizer_type: 'Region', organizer_id: dbu_id })
    #         .select(:id).map(&:id),
    #   # Regions of clubs that have players in DBU tournaments
    #   Region.joins(:clubs => { :players => { :game_participations => { :game => :tournament } } })
    #         .where(tournaments: { organizer_type: 'Region', organizer_id: dbu_id })
    #         .select(:id).map(&:id),
    #   # Regions of clubs that have teams in DBU leagues
    #   Region.joins(:clubs => { :league_teams => :league })
    #         .where(leagues: { organizer_type: 'Region', organizer_id: dbu_id })
    #         .select(:id).map(&:id)
    # ].flatten).pluck(:id).uniq
    #
    # # Find all locations we want to keep
    # location_ids = Location.where(id: [
    #   # Locations organized by our regions
    #   Location.where(organizer_type: 'Region', organizer_id: [region_id, dbu_id])
    #          .select(:id).map(&:id),
    #   # Locations used by our tables
    #   Location.joins(:tables => { :games => { :game_participations => :player } })
    #          .where(players: { id: player_ids })
    #          .select(:id).map(&:id)
    # ].flatten).pluck(:id).uniq
    #
    # # Find all tables we want to keep
    # table_ids = Table.where(id: [
    #   # Tables in our locations
    #   Table.where(location_id: location_ids)
    #        .select(:id).map(&:id),
    #   # Tables used in our games
    #   Table.joins(:games => { :game_participations => :player })
    #        .where(players: { id: player_ids })
    #        .select(:id).map(&:id)
    # ].flatten).pluck(:id).uniq
    #
    # # First find clubs from direct associations
    # initial_club_ids = Club.where(id: [
    #   # Clubs in our region
    #   Club.where(region_id: region_id).select(:id).map(&:id),
    #   # Clubs that organize tournaments for DBU
    #   Club.joins(:organized_tournaments)
    #       .where(tournaments: { organizer_type: 'Region', organizer_id: dbu_id })
    #       .select(:id).map(&:id),
    #   # Clubs that have league teams in DBU leagues
    #   Club.joins(:league_teams => :league)
    #       .where(leagues: { organizer_type: 'Region', organizer_id: dbu_id })
    #       .select(:id).map(&:id)
    # ].flatten).pluck(:id).uniq
    #
    # # Find all games related to our tournaments and parties
    # game_ids = Game.where(id: [
    #   # Games in tournaments
    #   Game.where(tournament_id: tournament_ids, tournament_type: 'Tournament')
    #       .select(:id).map(&:id),
    #   # Games in parties
    #   Game.joins(:party_games => :party)
    #       .where(parties: { id: party_ids })
    #       .select(:id).map(&:id)
    # ].flatten).pluck(:id).uniq
    #
    # # Find initial set of players from games and party games
    # player_ids = Player.where(id: [
    #   Player.joins(:seedings)
    #         .where(seedings: {id: seeding_ids}).map(&:id),
    #   # Players involved in our games
    #   Player.joins(:game_participations)
    #         .where(game_participations: { game_id: game_ids })
    #         .select(:id).map(&:id),
    #   # Players involved in our party games (as player_a or player_b)
    #   Player.joins(:party_a_games)
    #         .where(party_a_games: { id: party_game_ids })
    #         .select(:id).map(&:id),
    #   Player.joins(:party_b_games)
    #         .where(party_b_games: { id: party_game_ids })
    #         .select(:id).map(&:id),
    #   # Players in our initial clubs (through season_participations)
    #   Player.joins(:season_participations => :club)
    #         .where(season_participations: { club_id: initial_club_ids })
    #         .select(:id).map(&:id)
    # ].flatten).pluck(:id).uniq
    #
    # # Find additional clubs through season participations
    # additional_club_ids = Club.joins(:season_participations)
    #                         .where(season_participations: { player_id: player_ids })
    #                         .pluck(:id).uniq
    #
    # # Combine all club IDs
    # club_ids = (initial_club_ids + additional_club_ids).uniq
    #
    # # # Find all players (including those from additional clubs)
    # # player_ids = Player.where(id: [
    # #   initial_player_ids,
    # #   # Players in our additional clubs (through season_participations)
    # #   Player.joins(:season_participations => :club)
    # #         .where(season_participations: { club_id: additional_club_ids })
    # #         .select(:id).map(&:id)
    # # ].flatten).pluck(:id).uniq
    #
    # # Find all season participations for these players in these clubs
    # season_participation_ids = SeasonParticipation.where(player_id: player_ids, club_id: club_ids)
    #                                             .pluck(:id).uniq

    # Step 3: Delete records in correct order (most dependent first)
    puts "\nDeleting records in dependency order..."

    # Define deletion order (most dependent first)
    deletion_order = [
      SeasonParticipationregion,
      GameParticipationregion,
      Gameregion,
      PartyGameregion,
      Partyregion,
      LeagueTeamregion,
      Seeding,
      Playerregion,
      Leagueregion,
      Tournamentregion,
      Tableregion,
      Locationregion,
      Clubregion,
      Regionregion
    ]

    # Delete records in order
    deletion_order.each do |model|

      puts "\nProcessing #{model.name}..."
      total_before = model.count

      keep_ids = model.where("region_id = '?' OR region_id is NULL OR global_context = TRUE", region_id).ids
      deleted = total_before - keep_ids.count
      model.where.not(id: keep_ids).delete_all

      stats[model.name] = {
        before: total_before,
        after: total_before - deleted,
        deleted: deleted
      }

      puts "  Before: #{total_before}"
      puts "  After: #{total_before - deleted}"
      puts "  Deleted: #{deleted}"
    end

    # Print summary
    puts "\nCleanup Summary:"
    puts "================="
    stats.each do |model_name, data|
      puts "#{model_name}:"
      puts "  Before: #{data[:before]}"
      puts "  After: #{data[:after]}"
      puts "  Deleted: #{data[:deleted]}"
    end
  end
end
