module RegionTaggable
  extend ActiveSupport::Concern

  included do
    after_save :tag_version_with_regions
    after_destroy :tag_version_with_regions
  end

  private

  def tag_version_with_regions
    begin
      return if Carambus.config.carambus_api_url.present?
      return unless PaperTrail.request.enabled?

      # Get the last version for this record
      version = versions.last
      return unless version

      if previous_changes.present?
        # Find all associated regions
        region_ids = find_associated_region_ids
        return if region_ids.nil? || region_ids.empty?

        # Update the version with the region_ids
        version.update_column(:region_ids, region_ids)
      end
      return true
    rescue StandardError => e
      Rails.logger.info("Error during tagging: #{e} #{e.backtrace.join("\n")}")
    end
  end

  def find_associated_region_ids
    case self
    when Region
      [id]
    when Club
      [region_id, find_dbu_region_id_if_global].compact
    when Tournament
      [region_id, (organizer_type == "Region" ? organizer_id : nil), find_dbu_region_id_if_global].compact
    when League
      [(organizer_type == "Region" ? organizer_id : nil), find_dbu_region_id_if_global].compact
    when Party
      league ? [(league.organizer_type == "Region" ? league.organizer_id : nil), find_dbu_region_id_if_global].compact : []
    when GameParticipation
      if game&.tournament_type == 'Tournament'
        game.tournament ? [
          game.tournament.region_id,
          (game.tournament.organizer_type == "Region" ? game.tournament.organizer_id : nil),
          find_dbu_region_id_if_global
        ].compact : []
      elsif game&.tournament_type == 'Party'
        game.tournament&.league ? [(game.tournament.league.organizer_type == "Region" ? game.tournament.league.organizer_id : nil), find_dbu_region_id_if_global].compact : []
      end
    when Game
      if tournament_type == 'Tournament'
        tournament ? [
          tournament.region_id,
          (tournament.organizer_type == "Region" ? tournament.organizer_id : nil),
          find_dbu_region_id_if_global
        ].compact : []
      elsif tournament_type == 'Party'
        tournament&.league ? [(tournament.league.organizer_type == "Region" ? tournament.league.organizer_id : nil), find_dbu_region_id_if_global].compact : []
      end
    when PartyGame
      party&.league ? [(party.league.organizer_type == "Region" ? party.league.organizer_id : nil), find_dbu_region_id_if_global].compact : []
    when Seeding
      if tournament_id.present?
        tournament ? [
          tournament.region_id,
          (tournament.organizer_type == "Region" ? tournament.organizer_id : nil),
          find_dbu_region_id_if_global
        ].compact : []
      elsif league_team_id.present?
        league_team&.league ? [(league_team.league.organizer_type == "Region" ? league_team.league.organizer_id : nil), find_dbu_region_id_if_global].compact : []
      end
    when Location
      [(organizer_type == "Region" ? organizer_id : nil), find_dbu_region_id_if_global].compact
    when Player
      [clubs.pluck(:region_id).uniq, find_dbu_region_id_if_global].flatten.compact
    when LeagueTeam
      league ? [(league.organizer_type == "Region" ? league.organizer_id : nil), find_dbu_region_id_if_global].compact : []
    when SeasonParticipation
      [club&.region_id, find_dbu_region_id_if_global].compact
    end
  end

  def find_dbu_region_id_if_global
    dbu_region = Region.find_by_shortname('DBU')
    return nil unless dbu_region

    case self
    when Club
      # Include DBU if any of the club's players have participated in DBU tournaments
      return dbu_region.id if players.joins(game_participations: { game: :tournament }).exists?(games: { tournaments: { organizer_type: 'Region', organizer_id: dbu_region.id } }) ||
        league_teams.joins(:league).exists?(leagues: { organizer_type: 'Region', organizer_id: dbu_region.id })
    when Tournament
      # Include DBU if tournament is organized by DBU
      return dbu_region.id if organizer_type == 'Region' && organizer_id == dbu_region.id
    when League
      # Include DBU if league is organized by DBU
      return dbu_region.id if organizer_type == 'Region' && organizer_id == dbu_region.id
    when Party
      # Include DBU if party's league is organized by DBU
      return dbu_region.id if league&.organizer_type == 'Region' && league&.organizer_id == dbu_region.id
    when GameParticipation
      # Include DBU if game is part of a DBU tournament or party
      return dbu_region.id if game&.tournament&.organizer_type == 'Region' && game&.tournament&.organizer_id == dbu_region.id ||
                             tournament&.league&.organizer_type == 'Region' && tournament&.league&.organizer_id == dbu_region.id
    when Game
      # Include DBU if game is part of a DBU tournament or party
      return dbu_region.id if tournament&.organizer_type == 'Region' && tournament&.organizer_id == dbu_region.id ||
                             tournament&.league&.organizer_type == 'Region' && tournament&.league&.organizer_id == dbu_region.id
    when PartyGame
      # Include DBU if party's league is organized by DBU
      return dbu_region.id if party&.league&.organizer_type == 'Region' && party&.league&.organizer_id == dbu_region.id
    when Seeding
      # Include DBU if seeding is for a DBU tournament or league
      return dbu_region.id if tournament&.organizer_type == 'Region' && tournament&.organizer_id == dbu_region.id ||
                             league_team&.league&.organizer_type == 'Region' && league_team&.league&.organizer_id == dbu_region.id
    when Location
      # Include DBU if location is used by DBU
      return dbu_region.id if organizer_type == 'Region' && organizer_id == dbu_region.id
    when Player
      # Include DBU if player participates in DBU tournaments or leagues
      return dbu_region.id if game_participations.joins(game: :tournament).exists?(games: { tournaments: { organizer_type: 'Region', organizer_id: dbu_region.id } }) ||
                             season_participations.joins(club: { league_teams: :league }).exists?(clubs: { league_teams: { leagues: { organizer_type: 'Region', organizer_id: dbu_region.id } } })
    when LeagueTeam
      # Include DBU if team's league is organized by DBU
      return dbu_region.id if league&.organizer_type == 'Region' && league&.organizer_id == dbu_region.id
    when SeasonParticipation
      # Include DBU if club participates in DBU tournaments or leagues
      return dbu_region.id if club&.organized_tournaments.exists?(organizer_type: 'Region', organizer_id: dbu_region.id) ||
                             club&.league_teams.joins(:league).exists?(leagues: { organizer_type: 'Region', organizer_id: dbu_region.id })
    end
    nil
  end
end
