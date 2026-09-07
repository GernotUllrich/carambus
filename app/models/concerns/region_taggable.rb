module RegionTaggable
  extend ActiveSupport::Concern

  # Das Version-Tagging passiert seit Phase 47-01 beim SCHREIBEN der Version, ueber
  # die :meta-Option von has_paper_trail (app/models/local_protector.rb). Der frueher
  # hier registrierte after_save/after_destroy-Callback `update_version_region_data`
  # ist entfallen: er rief `find_associated_region_id` nie auf, sondern las die
  # gleichnamige SPALTE des Records — die bei den betroffenen Records leer ist — und
  # ueberschrieb damit auch jeden korrekten Stempel wieder. Bei `destroy` konnte er
  # ohnehin nichts ausrichten, weil `version.item` dort schon `nil` ist.
  #
  # `find_associated_region_id` und `global_context?` bleiben die fachliche Ableitung;
  # aufgerufen wird von beiden nur `find_associated_region_id` (global_context? ist
  # international-blind, siehe Phase-2-Research 2026-07-12).

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
      # Delegiert an Game statt die Kette zu wiederholen — verhaltensgleich zur frueheren
      # Fassung und automatisch mitkorrigiert, wenn der Game-Zweig sich aendert (Liga-Pfad).
      game&.find_associated_region_id
    when PartyGame
      party&.league&.organizer_type == "Region" ? party.league.organizer_id : nil
    when Seeding
      if tournament_id.present?
        # "Tournament", nicht "Region": `Tournament has_many :seedings, as: :tournament` setzt
        # tournament_type auf den Klassennamen. Der frueher hier gepruefte Wert "Region" kann
        # nie zutreffen — der Zweig lief ins Leere und liess in der Prod-Messung vom 2026-09-07
        # 3 619 Seeding-Versionen ungetaggt.
        if tournament_type == "Tournament"
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
      # `tournament` ist hier faktisch polymorph: `Party has_many :games, as: :tournament`
      # setzt tournament_type = "Party", waehrend `belongs_to :tournament` in game.rb NICHT
      # polymorph deklariert ist. Wer blind `tournament.organizer_type` aufruft, trifft bei
      # Liga-Spielen eine Party — die kennt kein organizer_type (NoMethodError, in Phase 47-01
      # ueber 13 PartyTest-Faelle sichtbar geworden). Deshalb ueber tournament_type gehen.
      if tournament_type == "Party"
        league = Party.find_by(id: tournament_id)&.league
        (league&.organizer_type == "Region") ? league.organizer_id : nil
      else
        (tournament&.organizer_type == "Region") ? tournament.organizer_id : tournament&.region_id
      end
    when Player
      # For players, we need to determine the primary region
      # This could be the region of their primary club or most recent participation
      primary_club = clubs.first
      primary_club&.region_id
    when SeasonParticipation
      club&.region_id
    when PlayerRanking
      # Direktes belongs_to :region — die Spalte traegt den Wert bereits.
      region_id
    when TournamentCc
      # branch_cc ist optional; ohne Kette bleibt es bei nil (der FK-Guard in
      # LocalProtector verwirft ohnehin, was nicht auf eine echte Region zeigt).
      branch_cc&.region_cc&.region_id
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
    unless ENV["FORCE_DERIVATION_RETAG"] == "1"
      raise "RegionTaggable.update_existing_versions ist deaktiviert (Recurrence-Schutz). " \
            "Siehe rake region_taggings:update_all_region_id / fix_international_organizer_context. " \
            "Override: FORCE_DERIVATION_RETAG=1."
    end
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

end
