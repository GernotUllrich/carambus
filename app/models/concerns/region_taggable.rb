module RegionTaggable
  extend ActiveSupport::Concern

  included do
    after_save :tag_version_with_region
    after_destroy :tag_version_with_region
  end

  private

  def tag_version_with_region
    return unless PaperTrail.request.enabled?

    # Get the last version for this record
    version = versions.last
    return unless version

    # Find the associated region
    region_id = find_associated_region_id
    return unless region_id

    # Update the version with the region_id
    version.update_column(:region_id, region_id)
  end

  def find_associated_region_id
    case self
    when Region
      id
    when Club
      region_id
    when Tournament
      region_id || organizer&.region_id
    when League
      organizer&.region_id
    when Party
      league&.organizer&.region_id
    when Game
      if tournament_type == 'Tournament'
        tournament&.region_id || tournament&.organizer&.region_id
      elsif tournament_type == 'Party'
        tournament&.league&.organizer&.region_id
      end
    when PartyGame
      party&.league&.organizer&.region_id
    when Location
      organizer&.region_id
    when Player
      clubs.first&.region_id
    when LeagueTeam
      league&.organizer&.region_id
    when SeasonParticipation
      club&.region_id
    end
  end
end
