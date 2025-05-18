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
    rescue StandardError => e
      Rails.logger.info("Error during tagging: #{e} #{e.backtrace.join("\n")}")
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
      game.tournament ? [
        game.tournament.region_id,
        (game.tournament.organizer_type == "Region" ? game.tournament.organizer_id : nil)
      ].compact : []
    when Game
      tournament ? [
        tournament.region_id,
        (tournament.organizer_type == "Region" ? tournament.organizer_id : nil)
      ].compact : []
    when PartyGame
      party&.league ? [(party.league.organizer_type == "Region" ? party.league.organizer_id : nil)].compact : []
    when Seeding
      if tournament_id.present?
        tournament ? [
          tournament.region_id,
          (tournament.organizer_type == "Region" ? tournament.organizer_id : nil)
        ].compact : []
      elsif league_team_id.present?
        league_team&.league ? [(league_team.league.organizer_type == "Region" ? league_team.league.organizer_id : nil)].compact : []
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
