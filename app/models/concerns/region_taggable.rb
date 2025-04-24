module RegionTaggable
  extend ActiveSupport::Concern

  included do
    after_save :tag_version_with_regions
    after_destroy :tag_version_with_regions
  end

  private

  def tag_version_with_regions
    return if Carambus.config.carambus_api_url.present?
    return unless PaperTrail.request.enabled?

    # Get the last version for this record
    version = versions.last
    return unless version

    if previous_changes.present?
      # Find all associated regions
      region_ids = find_associated_region_ids
      return if region_ids.empty?

      # Update the version with the region_ids
      version.update_column(:region_ids, region_ids)
    end
  end

  def find_associated_region_ids
    case self
    when Region
      [id]
    when Club
      [region_id]
    when Tournament
      [region_id, (organizer_type == "Region" ? organizer_id : nil)].compact
    when League
      [(organizer_type == "Region" ? organizer_id : nil)].compact
    when Party
      league ? [(league.organizer_type == "Region" ? league.organizer_id : nil)].compact : []
    when GameParticipation
      if game&.tournament_type == 'Tournament'
        game.tournament ? [
          game.tournament.region_id,
          (game.tournament.organizer_type == "Region" ? game.tournament.organizer_id : nil)
        ].compact : []
      elsif tournament_type == 'Party'
        tournament&.league ? [(tournament.league.organizer_type == "Region" ? tournament.league.organizer_id : nil)].compact : []
      end
    when Game
      if tournament_type == 'Tournament'
        tournament ? [
          tournament.region_id,
          (tournament.organizer_type == "Region" ? tournament.organizer_id : nil)
        ].compact : []
      elsif tournament_type == 'Party'
        tournament&.league ? [(tournament.league.organizer_type == "Region" ? tournament.league.organizer_id : nil)].compact : []
      end
    when PartyGame
      party&.league ? [(party.league.organizer_type == "Region" ? party.league.organizer_id : nil)].compact : []
    when Seeding
      if tournament_id.present?
        tournament ? [
          tournament.region_id,
          (tournament.organizer_type == "Region" ? tournament.organizer_id : nil)
        ].compact : []
      elsif league_team_id.present?
        league_team&.league ? [(league_team.league.organizer_type == "Region" ? league.organizer_id : nil)].compact : []
      end
    when Location
      [(organizer_type == "Region" ? organizer_id : nil)].compact
    when Player
      clubs.pluck(:region_id).uniq
    when LeagueTeam
      league ? [(league.organizer_type == "Region" ? league.organizer_id : nil)].compact : []
    when SeasonParticipation
      [club&.region_id].compact
    end
  end
end
