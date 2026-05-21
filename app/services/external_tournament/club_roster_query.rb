# frozen_string_literal: true

module ExternalTournament
  # Plan 18-01 (Club/Player-Discovery): read-only, region-scoped Substrat fuer die
  # App-seitige Spielerzuordnung (loest das start_game "Player not resolved"-Problem,
  # indem der Operator vorab offizielle Spieler mit cc_id + dbu_nr zuordnen kann).
  #
  #   - clubs(region)           -> Clubs der Region (mit cc_id) fuer den Club-Picker
  #   - players(region:, club:) -> in der laufenden Saison SPIELBERECHTIGTE Spieler des
  #                                Clubs, je cc_id + dbu_nr
  #
  # Reine Reads, idempotent, keine Seiteneffekte. Legt KEINE Player/Gaeste an.
  #
  # Eligibility (D-18-01-A): strikt SeasonParticipation status="active" der
  # Season.current_season. temporary/guest/nil sind ausgeschlossen; das status-Feld
  # wird pro Spieler mitgeliefert (App-Transparenz).
  # Region-Scope (D-18-01-D): Club.cc_id ist nur regional eindeutig -> jeder Lookup
  # region-scoped (vgl. project_cc_id_not_unique / location_cc_id-Bug 15-07).
  class ClubRosterQuery
    ACTIVE = "active"

    def self.current_season
      Season.current_season
    end

    # Region-scoped Club-Lookup ueber cc_id (regional eindeutig).
    def self.find_club(region, club_cc_id)
      return nil if region.blank? || club_cc_id.blank?
      region.clubs.find_by(cc_id: club_cc_id)
    end

    # Clubs der Region mit cc_id (Schluessel fuer club_players), stabil sortiert.
    def self.clubs(region)
      return [] if region.blank?
      region.clubs.where.not(cc_id: nil).order(:shortname, :name).map { |c| club_hash(c) }
    end

    # Spielberechtigte (status "active") Spieler des Clubs in der laufenden Saison.
    def self.players(region:, club:, season: current_season)
      return [] if club.blank? || season.blank?
      SeasonParticipation
        .where(season_id: season.id, club_id: club.id, status: ACTIVE)
        .includes(:player)
        .map { |sp| serialize_player(sp) }
        .compact
        .sort_by { |h| [h[:lastname].to_s.downcase, h[:firstname].to_s.downcase] }
    end

    def self.club_hash(club)
      return nil if club.blank?
      {cc_id: club.cc_id, shortname: club.shortname, name: club.name}
    end

    def self.serialize_player(season_participation)
      player = season_participation.player
      return nil if player.blank?
      {
        cc_id: player.cc_id,
        firstname: player.firstname,
        lastname: player.lastname,
        dbu_nr: player.dbu_nr&.to_s,
        status: season_participation.status
      }
    end
  end
end
