# lib/tasks/cleanup.rake
namespace :cleanup do
  desc "Remove records not associated with the local server's region"
  task remove_non_region_records: :environment do
    region_id = Location[Carambus.config.location_id].organizer_id
    raise "No location_id configured in Carambus.config.location_id" unless Carambus.config.location_id.present?
    raise "This task can only be run on a local server" unless ApplicationRecord.local_server?

    region = Region.find(region_id)
    puts "Cleaning up records not associated with region: #{region.name} (#{region.shortname})"

    # Track statistics
    stats = {}

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
      Location,
      Region,
    ].each do |model|
      puts "\nProcessing #{model.name}..."

      # Get records that should be kept
      keep_ids = case model.name
                 when 'Region'
                   [region_id]
                 when 'Club'
                   model.where(region_id: region_id).pluck(:id)
                 when 'Tournament'
                   model.where(region_id: region_id).or(
                     model.where(organizer: region)
                   ).pluck(:id)
                 when 'League'
                   model.where(organizer: region).pluck(:id)
                 when 'Party'
                   model.joins(:league).where(leagues: { organizer: region }).pluck(:id)
                 when 'GameParticipation'
                   model.joins("LEFT JOIN games ON game_participations.game_id = games.id")
                        .joins("LEFT JOIN tournaments ON games.tournament_id = tournaments.id AND games.tournament_type = 'Tournament'")
                        .joins("LEFT JOIN parties ON games.tournament_id = parties.id AND games.tournament_type = 'Party'")
                        .joins("LEFT JOIN leagues ON parties.league_id = leagues.id")
                        .where("tournaments.region_id = ? OR tournaments.organizer_id = ? OR leagues.organizer_id = ?",
                               region_id, region_id, region_id)
                        .pluck(:id)
                 when 'Game'
                   model.joins("LEFT JOIN tournaments ON games.tournament_id = tournaments.id AND games.tournament_type = 'Tournament'")
                        .joins("LEFT JOIN parties ON games.tournament_id = parties.id AND games.tournament_type = 'Party'")
                        .joins("LEFT JOIN leagues ON parties.league_id = leagues.id")
                        .where("tournaments.region_id = ? OR tournaments.organizer_id = ? OR leagues.organizer_id = ?",
                               region_id, region_id, region_id)
                        .pluck(:id)
                 when 'Seeding'
                   model.joins("LEFT JOIN tournaments ON seedings.tournament_id = tournaments.id")
                        .joins("LEFT JOIN league_teams ON seedings.league_team_id = league_teams.id")
                        .joins("LEFT JOIN leagues ON league_teams.league_id = leagues.id")
                        .where("tournaments.region_id = ? or OR leagues.organizer_id = ?",
                               region_id, region_id)
                        .pluck(:id)
                 when 'PartyGame'
                   model.joins(:party => :league).where(leagues: { organizer: region }).pluck(:id)
                 when 'Location'
                   model.where(organizer: region).pluck(:id)
                 when 'Player'
                   model.joins(:clubs).where(clubs: { region_id: region_id }).pluck(:id)
                 when 'LeagueTeam'
                   model.joins(:league).where(leagues: { organizer: region }).pluck(:id)
                 when 'SeasonParticipation'
                   model.joins(:club).where(clubs: { region_id: region_id }).pluck(:id)
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
