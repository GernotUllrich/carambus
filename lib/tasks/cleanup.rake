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

  desc "Remove duplicate games, keeping the first with non-blank data (or earliest if all blank)"
  task remove_duplicate_games: :environment do
    duplicates = Game.select('MIN(id) as id, tournament_id, gname, seqno, COUNT(*) as count')
      .group(:tournament_id, :gname, :seqno)
      .having('COUNT(*) > 1')

    duplicates.each do |dup|
      games = Game.where(tournament_id: dup.tournament_id, gname: dup.gname, seqno: dup.seqno).order(:created_at)
      keeper = games.detect { |g| g.data.present? } || games.first
      games.where.not(id: keeper.id).destroy_all
      puts "Removed duplicates for tournament_id=#{dup.tournament_id}, gname=#{dup.gname}, seqno=#{dup.seqno}, kept id=#{keeper.id}"
    end
    puts "Cleanup complete."
  end

  desc "Clean up unnecessary PaperTrail version records that only contain timestamp changes"
  task cleanup_paper_trail_versions: :environment do
    puts "Cleaning up unnecessary PaperTrail version records..."

    # Models that we've configured to ignore updated_at and sync_date
    models_with_ignore_config = [
      'Tournament', 'Game', 'Party', 'League', 'Club', 'Location', 'Region', 'SeasonParticipation'
    ]

    total_deleted = 0

    models_with_ignore_config.each do |model_name|
      puts "\nProcessing #{model_name} versions..."

      # Find versions for this model
      versions = PaperTrail::Version.where(item_type: model_name)

      # Count versions that only have updated_at or sync_date changes
      unnecessary_versions = versions.select do |version|
        next unless version.object_changes.present?

        changes = YAML.load(version.object_changes)
        # Check if the only changes are updated_at or sync_date
        change_keys = changes.keys
        (change_keys == ['updated_at'] || change_keys == ['sync_date'] || change_keys == ['updated_at', 'sync_date']) &&
        # Also check that data field is nil both before and after (for the specific case mentioned)
        (changes['data']&.all?(&:nil?) || !changes.key?('data'))
      end

      if unnecessary_versions.any?
        version_ids = unnecessary_versions.map(&:id)
        PaperTrail::Version.where(id: version_ids).delete_all
        puts "  Deleted #{unnecessary_versions.count} unnecessary version records"
        total_deleted += unnecessary_versions.count
      else
        puts "  No unnecessary version records found"
      end
    end

    puts "\nCleanup complete. Total deleted: #{total_deleted} version records"
  end

  desc "Entfernt regionale Liga-Duplikate, wenn es eine DBU-Liga mit gleichem Namen, Saison und Disziplin gibt. Löscht auch abhängige Parties, PartyGames und LeagueTeams."
  task remove_regional_league_duplicates: :environment do
    dbu_region = Region.find_by(shortname: "DBU")
    raise "DBU-Region nicht gefunden!" unless dbu_region

    dbu_league_keys = League.where(organizer: dbu_region)
      .pluck(:name, :season_id, :discipline_id)
      .uniq

    deleted_leagues = []
    deleted_parties = 0
    deleted_party_games = 0
    deleted_league_teams = 0

    dbu_league_keys.each do |name, season_id, discipline_id|
      regional_leagues = League.where(
        name: name,
        season_id: season_id,
        discipline_id: discipline_id
      ).where.not(organizer: dbu_region)

      regional_leagues.each do |league|
        puts "Lösche Liga: #{league.name} | Saison: #{league.season&.name} | Disziplin: #{league.discipline&.name} | Region: #{league.organizer&.shortname} | ID: #{league.id}"

        # Parties und deren PartyGames löschen
        league.parties.find_each do |party|
          cnt_pg = party.party_games.count
          party.party_games.destroy_all
          deleted_party_games += cnt_pg
          party.destroy
          deleted_parties += 1
        end

        # LeagueTeams löschen
        cnt_lt = league.league_teams.count
        league.league_teams.destroy_all
        deleted_league_teams += cnt_lt

        # Liga selbst löschen
        league.destroy
        deleted_leagues << league
      end
    end

    puts "\nAnzahl gelöschter Ligen: #{deleted_leagues.size}"
    puts "Anzahl gelöschter Parties: #{deleted_parties}"
    puts "Anzahl gelöschter PartyGames: #{deleted_party_games}"
    puts "Anzahl gelöschter LeagueTeams: #{deleted_league_teams}"
  end

  desc "Entfernt alle Ligen mit 'Bundesliga' oder 'Regionalliga' im Namen, wenn Organizer != DBU. Löscht auch abhängige Parties, PartyGames und LeagueTeams."
  task remove_bundesliga_regionalliga_non_dbu: :environment do
    dbu_region = Region.find_by(shortname: "DBU")
    raise "DBU-Region nicht gefunden!" unless dbu_region

    leagues = League.where("name ILIKE ? OR name ILIKE ?", "%bundesliga%", "%regionalliga%")
                   .where.not(organizer: dbu_region)

    deleted_leagues = []
    deleted_parties = 0
    deleted_party_games = 0
    deleted_league_teams = 0

    leagues.find_each do |league|
      puts "Lösche Liga: #{league.name} | Saison: #{league.season&.name} | Disziplin: #{league.discipline&.name} | Region: #{league.organizer&.shortname} | ID: #{league.id}"

      league.parties.find_each do |party|
        cnt_pg = party.party_games.count
        party.party_games.destroy_all
        deleted_party_games += cnt_pg
        party.destroy
        deleted_parties += 1
      end

      cnt_lt = league.league_teams.count
      league.league_teams.destroy_all
      deleted_league_teams += cnt_lt

      league.destroy
      deleted_leagues << league
    end

    puts "\nAnzahl gelöschter Ligen: #{deleted_leagues.size}"
    puts "Anzahl gelöschter Parties: #{deleted_parties}"
    puts "Anzahl gelöschter PartyGames: #{deleted_party_games}"
    puts "Anzahl gelöschter LeagueTeams: #{deleted_league_teams}"
  end

  desc "Entfernt alle DBU-Ligen mit cc_id = nil (inkl. abhängiger Daten)"
  task remove_dbu_leagues_without_cc_id: :environment do
    dbu_region = Region.find_by(shortname: "DBU")
    raise "DBU-Region nicht gefunden!" unless dbu_region

    leagues = League.where(organizer: dbu_region, cc_id: nil)

    deleted_leagues = []
    deleted_parties = 0
    deleted_party_games = 0
    deleted_league_teams = 0

    leagues.find_each do |league|
      puts "Lösche DBU-Liga ohne cc_id: #{league.name} | Saison: #{league.season&.name} | Disziplin: #{league.discipline&.name} | ID: #{league.id}"

      league.parties.find_each do |party|
        cnt_pg = party.party_games.count
        party.party_games.destroy_all
        deleted_party_games += cnt_pg
        party.destroy
        deleted_parties += 1
      end

      cnt_lt = league.league_teams.count
      league.league_teams.destroy_all
      deleted_league_teams += cnt_lt

      league.destroy
      deleted_leagues << league
    end

    puts "\nAnzahl gelöschter DBU-Ligen ohne cc_id: #{deleted_leagues.size}"
    puts "Anzahl gelöschter Parties: #{deleted_parties}"
    puts "Anzahl gelöschter PartyGames: #{deleted_party_games}"
    puts "Anzahl gelöschter LeagueTeams: #{deleted_league_teams}"
  end

  desc "Clean up parties with nil team references and duplicates"
  task parties: :environment do
    puts "Cleaning up parties with nil league_team references..."
    party_ids = Party.where(league_team_a_id: nil).or(Party.where(league_team_b_id: nil)).map(&:id)
    Party.where(id: party_ids).destroy_all

    puts "Merging duplicate parties (same teams/date)..."
    groups = Party.group(:league_id, :day_seqno, :league_team_a_id, :league_team_b_id).having('count(*) > 1').count
    groups.each do |keys, count|
      parties = Party.where(
        league_id: keys[0],
        day_seqno: keys[1],
        league_team_a_id: keys[2],
        league_team_b_id: keys[3]
      ).to_a
      # Sort in Ruby: prefer party with a result, then by created_at
      parties = parties.sort_by { |p| [p.data['result'].present? ? 0 : 1, p.created_at] }
      keep = parties.first
      (parties - [keep]).each do |dup|
        # Reassign party_games
        PartyGame.where(party_id: dup.id).update_all(party_id: keep.id)
        puts "Deleting duplicate party ##{dup.id} (keeping ##{keep.id})"
        dup.delete
      end
    end

    puts "Cleaning up orphaned party_games..."
    party_ids = Party.ids
    party_ids_from_party_games = PartyGame.select(:party_id).map(&:party_id).uniq
    orphan_party_ids = party_ids_from_party_games - party_ids
    PartyGame.where(party_id: orphan_party_ids).delete_all

    puts "Cleanup complete."
  end

  def hash_diff(first, second)
    first
      .dup
      .delete_if { |k, v| second[k] == v }
      .merge!(second.dup.delete_if { |k, _v| first.key?(k) })
  end
end
