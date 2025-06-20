module RegionTaggable
  extend ActiveSupport::Concern

  included do
    has_many :region_taggings, as: :taggable, dependent: :destroy
    has_many :regions, through: :region_taggings

    after_save :update_region_taggings
    after_destroy :update_region_taggings
  end

  # Custom getter to default to empty array
  def region_ids
    @region_ids ||= []
  end

  # Custom setter
  def region_ids=(value)
    @region_ids = value
  end

  def update_region_taggings
    return if Carambus.config.carambus_api_url.present?

=begin
    # Find all associated regions
    region_ids = find_associated_region_ids
    return if region_ids.nil? || region_ids.empty?

    # Update region taggings
    current_region_ids = region_taggings.pluck(:region_id)

    # Add new region taggings
    (region_ids - current_region_ids).each do |region_id|
      region_taggings.create!(region_id: region_id)
    end

    # Remove old region taggings
    region_taggings.where(region_id: current_region_ids - region_ids).destroy_all
=end

    # Also update version if paper trail is enabled
    if PaperTrail.request.enabled?
      version = versions.last
      if version
        # Use the attr_accessor value if set, otherwise use the calculated region_ids
        version_region_ids = self.region_ids || find_associated_region_ids
        version.update_column(:region_ids, version_region_ids)
      end
    end
  rescue StandardError => e
    Rails.logger.info("Error during region tagging: #{e} #{e.backtrace.join("\n")}")
  end

  def get_region_ids
    region_ids
  end

  def find_associated_region_ids
    case self
    when Region
      [id]
    when Club
      [region_id]
    when Tournament
      [(organizer_type == "Region" ? organizer_id : nil)].compact
    when League
      [(organizer_type == "Region" ? organizer_id : nil)].compact
    when Party
      league ? [(league.organizer_type == "Region" ? league.organizer_id : nil)].compact : []
    when GameParticipation
      if game.tournament ? [
        game.tournament.region_id,
        (game.tournament.organizer_type == "Region" ? game.tournament.organizer_id : nil)
      ].compact.uniq : []
      end
    when PartyGame
      party&.league ? [(party.league.organizer_type == "Region" ? party.league.organizer_id : nil)].compact : []
    when Seeding
      if tournament_id.present?
        if tournament_type == "Region"
          tournament ? [
            tournament.region_id,
            (tournament.organizer_type == "Region" ? tournament.organizer_id : nil)
          ].compact : []
        elsif tournament_type == "Party"
          tournament&.league&.organizer_type == "Region" ?  [tournament.league.organizer.id] : []
        end
      elsif league_team_id.present?
        league_team&.league ? [(league_team.league.organizer_type == "Region" ? league_team.league.organizer_id : nil)].compact : []
      end
    when Location
      [(organizer_type == "Region" ? organizer_id : nil)].compact
    when LeagueTeam
      league ? [(league.organizer_type == "Region" ? league.organizer_id : nil)].compact : []
    when Game
      tournament ? [
        tournament.region_id,
        (tournament.organizer_type == "Region" ? tournament.organizer_id : nil)
      ].compact.uniq : []
    when PartyGame
      party&.league ? [
        (party.league.organizer_type == "Region" ? party.league.organizer_id : nil)
      ].compact.uniq : []
    when GameParticipation
      game ? (game.tournament ? [
        game.tournament.region_id,
        (game.tournament.organizer_type == "Region" ? game.tournament.organizer_id : nil)
      ].compact.uniq : []) : []
    when Player
      [clubs.pluck(:region_id).uniq].compact
    when SeasonParticipation
      [club&.region_id].compact
    end
  end
end
