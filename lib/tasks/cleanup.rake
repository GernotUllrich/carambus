# lib/tasks/cleanup.rake
namespace :cleanup do
  desc "Remove records not associated with the local server's region"
  task remove_non_region_records: :environment do
    region_id = Location[Carambus.config.location_id].organizer_id
    raise "No location_id configured in Carambus.config.location_id" unless Carambus.config.location_id.present?
    raise "This task can only be run on a local server" unless ApplicationRecord.local_server?

    region = Region.find(region_id)
    dbu = Region.find_by_shortname("DBU")
    dbu_id = dbu.id
    puts "Cleaning up records not associated with region: #{region.name} (#{region.shortname})"

    # Track statistics
    stats = {}

    # First, find all regions that should be kept
    keep_region_ids = [region_id, dbu_id]
    
    # Add regions of clubs that participate in DBU events
    keep_region_ids += Club.joins(:tournaments)
                          .where(tournaments: { organizer_type: 'Region', organizer_id: dbu_id })
                          .pluck(:region_id)
                          .uniq
    
    # Add regions of clubs that have players in DBU events
    keep_region_ids += Club.joins(:players => { game_participations: { game: :tournament } })
                          .where(tournaments: { organizer_type: 'Region', organizer_id: dbu_id })
                          .pluck(:region_id)
                          .uniq
    
    # Add regions of clubs that have teams in DBU leagues
    keep_region_ids += Club.joins(:league_teams => :league)
                          .where(leagues: { organizer_type: 'Region', organizer_id: dbu_id })
                          .pluck(:region_id)
                          .uniq

    keep_region_ids = keep_region_ids.uniq

    # Clean up each model that includes RegionTaggable
    [
      SeasonParticipation,
      Player,
      Club,
      PartyGame,
      Party,
      GameParticipation,
      Game,
      Seeding,
      LeagueTeam,
      League,
      Tournament,
      Table,
      Location,
      Region,
    ].each do |model|
      puts "\nProcessing #{model.name}..."

      # Get records that should be kept
      keep_ids = case model.name
                 when 'Region'
                   keep_region_ids
                 when 'Club'
                   model.where(region_id: region_id)
                        .or(model.where(id: model.joins(:tournaments)
                                               .where(tournaments: { organizer_type: 'Region', organizer_id: dbu_id })
                                               .pluck(:id)))
                        .or(model.where(id: model.joins(:league_teams => :league)
                                               .where(leagues: { organizer_type: 'Region', organizer_id: dbu_id })
                                               .pluck(:id)))
                        .or(model.where(id: model.joins(:players => { game_participations: { game: :tournament } })
                                               .where(tournaments: { organizer_type: 'Region', organizer_id: dbu_id })
                                               .pluck(:id)))
                        .pluck(:id)
                 when 'Tournament'
                   model.where(region_id: region_id)
                        .or(model.where(organizer: region))
                        .or(model.where(organizer_type: 'Region', organizer_id: dbu_id))
                        .or(model.where(id: model.joins(:game_participations => :player)
                                               .where(players: { clubs: { region_id: region_id } })
                                               .pluck(:id)))
                        .pluck(:id)
                 when 'League'
                   model.where(organizer: region)
                        .or(model.where(organizer_type: 'Region', organizer_id: dbu_id))
                        .or(model.where(id: model.joins(:league_teams => { club: :players })
                                               .where(players: { clubs: { region_id: region_id } })
                                               .pluck(:id)))
                        .pluck(:id)
                 when 'Party'
                   model.joins(:league)
                        .where(leagues: { organizer: region })
                        .or(model.joins(:league)
                                .where(leagues: { organizer_type: 'Region', organizer_id: dbu_id }))
                        .or(model.where(id: model.joins(:game_participations => :player)
                                               .where(players: { clubs: { region_id: region_id } })
                                               .pluck(:id)))
                        .pluck(:id)
                 when 'GameParticipation'
                   model.joins("LEFT JOIN games ON game_participations.game_id = games.id")
                        .joins("LEFT JOIN tournaments ON games.tournament_id = tournaments.id AND games.tournament_type = 'Tournament'")
                        .joins("LEFT JOIN parties ON games.tournament_id = parties.id AND games.tournament_type = 'Party'")
                        .joins("LEFT JOIN leagues ON parties.league_id = leagues.id")
                        .where("tournaments.region_id = ? OR tournaments.organizer_id = ? OR leagues.organizer_id = ? OR tournaments.organizer_id = ? OR leagues.organizer_id = ? OR game_participations.player_id IN (SELECT id FROM players WHERE id IN (SELECT player_id FROM clubs_players WHERE club_id IN (SELECT id FROM clubs WHERE region_id = ?)))",
                               region_id, region_id, region_id, dbu_id, dbu_id, region_id)
                        .pluck(:id)
                 when 'Game'
                   model.joins("LEFT JOIN tournaments ON games.tournament_id = tournaments.id AND games.tournament_type = 'Tournament'")
                        .joins("LEFT JOIN parties ON games.tournament_id = parties.id AND games.tournament_type = 'Party'")
                        .joins("LEFT JOIN leagues ON parties.league_id = leagues.id")
                        .where("tournaments.region_id = ? OR tournaments.organizer_id = ? OR leagues.organizer_id = ? OR tournaments.organizer_id = ? OR leagues.organizer_id = ? OR games.id IN (SELECT game_id FROM game_participations WHERE player_id IN (SELECT id FROM players WHERE id IN (SELECT player_id FROM clubs_players WHERE club_id IN (SELECT id FROM clubs WHERE region_id = ?))))",
                               region_id, region_id, region_id, dbu_id, dbu_id, region_id)
                        .pluck(:id)
                 when 'Seeding'
                   model.joins("LEFT JOIN tournaments ON seedings.tournament_id = tournaments.id")
                        .joins("LEFT JOIN league_teams ON seedings.league_team_id = league_teams.id")
                        .joins("LEFT JOIN leagues ON league_teams.league_id = leagues.id")
                        .where("tournaments.region_id = ? OR leagues.organizer_id = ? OR tournaments.organizer_id = ? OR leagues.organizer_id = ? OR seedings.player_id IN (SELECT id FROM players WHERE id IN (SELECT player_id FROM clubs_players WHERE club_id IN (SELECT id FROM clubs WHERE region_id = ?)))",
                               region_id, region_id, dbu_id, dbu_id, region_id)
                        .pluck(:id)
                 when 'PartyGame'
                   model.joins(:party => :league)
                        .where(leagues: { organizer: region })
                        .or(model.joins(:party => :league)
                                .where(leagues: { organizer_type: 'Region', organizer_id: dbu_id }))
                        .or(model.where(id: model.joins(:game_participations => :player)
                                               .where(players: { clubs: { region_id: region_id } })
                                               .pluck(:id)))
                        .pluck(:id)
                 when 'Table'
                   model.joins(:location)
                        .where(locations: { organizer: region })
                        .or(model.joins(:location)
                                .where(locations: { organizer_type: 'Region', organizer_id: dbu_id }))
                        .or(model.where(id: model.joins(:games => { game_participations: :player })
                                               .where(players: { clubs: { region_id: region_id } })
                                               .pluck(:id)))
                        .pluck(:id)
                 when 'Location'
                   model.where(organizer: region)
                        .or(model.where(organizer_type: 'Region', organizer_id: dbu_id))
                        .or(model.where(id: model.joins(:tables => { games: { game_participations: :player } })
                                               .where(players: { clubs: { region_id: region_id } })
                                               .pluck(:id)))
                        .pluck(:id)
                 when 'Player'
                   model.joins(:clubs)
                        .where(clubs: { region_id: region_id })
                        .or(model.where(id: model.joins(:game_participations => { game: :tournament })
                                               .where(tournaments: { organizer_type: 'Region', organizer_id: dbu_id })
                                               .pluck(:id)))
                        .or(model.where(id: model.joins(:season_participations => { club: { league_teams: :league } })
                                               .where(leagues: { organizer_type: 'Region', organizer_id: dbu_id })
                                               .pluck(:id)))
                        .pluck(:id)
                 when 'LeagueTeam'
                   model.joins(:league)
                        .where(leagues: { organizer: region })
                        .or(model.joins(:league)
                                .where(leagues: { organizer_type: 'Region', organizer_id: dbu_id }))
                        .or(model.where(id: model.joins(:players)
                                               .where(players: { clubs: { region_id: region_id } })
                                               .pluck(:id)))
                        .pluck(:id)
                 when 'SeasonParticipation'
                   model.joins(:club)
                        .where(clubs: { region_id: region_id })
                        .or(model.joins(:club)
                                .where(clubs: { id: Club.joins(:tournaments)
                                                      .where(tournaments: { organizer_type: 'Region', organizer_id: dbu_id })
                                                      .pluck(:id) }))
                        .or(model.joins(:club)
                                .where(clubs: { id: Club.joins(:league_teams => :league)
                                                      .where(leagues: { organizer_type: 'Region', organizer_id: dbu_id })
                                                      .pluck(:id) }))
                        .or(model.joins(:player)
                                .where(players: { clubs: { region_id: region_id } }))
                        .pluck(:id)
                 end

      # Get total count before cleanup
      total_before = model.count

      # Delete records not in keep_ids
      if keep_ids.present?
        # Use transaction and set unprotected flag for each record
        deleted = model.where.not(id: keep_ids).count
        model.where.not(id: keep_ids).delete_all
      end

      # Update statistics
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
