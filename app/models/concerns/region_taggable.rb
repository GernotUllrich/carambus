module RegionTaggable
  extend ActiveSupport::Concern

  included do
    # Note: Version region_id and global_context are automatically set by PaperTrail initializer
    # No need for after_save callbacks here
    after_save :update_version_region_data
    after_destroy :update_version_region_data
  end

  def find_associated_region_id
    case self
    when Region
      id
    when Club
      region_id
    when Tournament
      organizer_type == "Region" ? organizer_id : nil
    when League
      organizer_type == "Region" ? organizer_id : nil
    when Party
      league&.organizer_type == "Region" ? league.organizer_id : nil
    when GameParticipation
      if game&.tournament
        game.tournament.organizer_type == "Region" ? game.tournament.organizer_id : game.tournament.region_id
      end
    when PartyGame
      party&.league&.organizer_type == "Region" ? party.league.organizer_id : nil
    when Seeding
      if tournament_id.present?
        if tournament_type == "Region"
          tournament&.organizer_type == "Region" ? tournament.organizer_id : tournament&.region_id
        elsif tournament_type == "Party"
          tournament&.league&.organizer_type == "Region" ? tournament.league.organizer_id : nil
        end
      elsif league_team_id.present?
        league_team&.league&.organizer_type == "Region" ? league_team.league.organizer_id : nil
      end
    when Location
      organizer_type == "Region" ? organizer_id : nil
    when LeagueTeam
      league&.organizer_type == "Region" ? league.organizer_id : nil
    when Game
      tournament&.organizer_type == "Region" ? tournament.organizer_id : tournament&.region_id
    when Player
      # For players, we need to determine the primary region
      # This could be the region of their primary club or most recent participation
      primary_club = clubs.first
      primary_club&.region_id
    when SeasonParticipation
      club&.region_id
    end
  end

  def global_context?
    # Determine if this record has global context (participates in global events)
    case self
    when Tournament
      # Tournaments organized by DBU or with global scope
      organizer_type == "Region" && organizer&.shortname == "DBU"
    when League
      # Leagues organized by DBU
      organizer_type == "Region" && organizer&.shortname == "DBU"
    when Party
      # Parties in DBU leagues
      league&.organizer_type == "Region" && league.organizer&.shortname == "DBU"
    when GameParticipation
      # Participations in DBU tournaments
      game&.tournament&.organizer_type == "Region" && game.tournament.organizer&.shortname == "DBU"
    when Player
      # Players participating in DBU events
      game_participations.joins(game: :tournament)
                         .where(tournaments: { organizer_type: "Region" })
                         .where(tournaments: { organizer: Region.find_by(shortname: "DBU") })
                         .exists?
    else
      false
    end
  end

  # Class method to update all existing versions for this model
  def self.update_existing_versions
    # Get all models that include RegionTaggable
    models_with_region_taggable = [
      Region, Club, Tournament, League, Party, Location,
      LeagueTeam, Game, PartyGame, GameParticipation,
      Player, SeasonParticipation, Seeding
    ]

    models_with_region_taggable.each do |model_class|
      puts "Updating versions for #{model_class.name}..."

      model_class.find_each do |record|
        begin
          # Update the record's region_id and global_context
          region_id = record.find_associated_region_id
          global_context = record.global_context?

          record.update_columns(
            region_id: region_id,
            global_context: global_context
          )

          # Update all versions for this record
          record.versions.each do |version|
            version.update_columns(
              region_id: region_id,
              global_context: global_context
            )
          end
        rescue StandardError => e
          Rails.logger.error("Error updating versions for #{model_class.name} ID #{record.id}: #{e.message}")
        end
      end
    end
  end

  def update_version_region_data
    return unless PaperTrail.request.enabled?

    # Update the most recent version for this record
    record_versions = self.versions rescue []
    if record_versions.any?
      latest_version = record_versions.last
      if latest_version && previous_changes.present?
         latest_item = latest_version.item
        region_id = latest_item.region_id if latest_item.respond_to?(:region_id)
        global_context = latest_item.global_context if latest_item.respond_to?(:global_context)

        latest_version.update_columns(
          region_id: region_id,
          global_context: global_context
        ) if latest_item.respond_to?(:region_id) || latest_item.respond_to?(:global_context)
      end
    end
  rescue StandardError => e
    Rails.logger.warn("Error updating version region data: #{e.message}")
  end
end
