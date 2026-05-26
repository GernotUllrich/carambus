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
    #
    # Plan 20-03 (F5): optionaler player_class-Filter (Leistungsklasse, disziplin-gebunden).
    # Plan 21-01 (D-21-01-D): Filter-Semantik = "X ODER BESSER" via PLAYER_CLASS_ORDER
    #   (worst→best). Ersetzt das urspruengliche "exakt X" (D-20-03-D superseded), weil
    #   in der STO-Praxis Spieler aus tieferen Klassen einspringen koennen — die App soll
    #   diese sehen. Ein unbekannter player_class-Wert wird vom Controller mit 422
    #   abgefangen; hier liefert der Service defensiv ein leeres Set.
    #
    #   - discipline (Discipline|nil): wenn gesetzt, wird je Spieler die Leistungsklasse aus
    #     PlayerRanking ermittelt + als Feld :player_class mitgeliefert (D-20-03-A).
    #   - ranking_season (Season|nil): Saison fuer die Klassen-Ermittlung (Vorsaison-Default
    #     wird vom Controller bestimmt, D-20-03-B); season bleibt die Eligibility-Saison.
    #   - player_class (String|nil): wenn gesetzt, werden nur Spieler mit Klasse player_class
    #     ODER BESSER zurueckgegeben (Spieler ohne passendes Ranking RAUS).
    # Ohne discipline ist die Rueckgabe BYTE-IDENTISCH zum bisherigen Verhalten (kein :player_class).
    def self.players(region:, club:, season: current_season, discipline: nil, player_class: nil, ranking_season: nil)
      return [] if club.blank? || season.blank?
      participations = SeasonParticipation
        .where(season_id: season.id, club_id: club.id, status: ACTIVE)
        .includes(:player)
        .to_a

      class_by_player_id = discipline ? player_class_map(region, discipline, ranking_season, participations) : nil

      rows = participations.map { |sp| serialize_player(sp, class_by_player_id) }.compact
      rows = filter_by_class_or_better(rows, player_class) if player_class.present?
      rows.sort_by { |h| [h[:lastname].to_s.downcase, h[:firstname].to_s.downcase] }
    end

    # D-21-01-D: filtert auf "Klasse X ODER BESSER" via PLAYER_CLASS_ORDER (worst→best).
    # Spieler ohne Ranking (:player_class nil) sind ausgeschlossen. Unbekannter
    # player_class-Wert -> leere Liste (Controller faengt 422 ab).
    def self.filter_by_class_or_better(rows, player_class)
      order = Discipline::PLAYER_CLASS_ORDER
      idx = order.index(player_class)
      return [] if idx.nil?
      allowed = order[idx..].to_set
      rows.select { |h| h[:player_class] && allowed.include?(h[:player_class]) }
    end

    # D-20-03-A/B: player_id -> player_class-Shortname aus PlayerRanking (player_class_id ->
    # PlayerClass.shortname), region+disziplin+ranking_season-scoped. Batch (kein N+1). Erstes
    # Ranking je Spieler gewinnt (in der Praxis genau eines pro Disziplin/Saison/Region).
    def self.player_class_map(region, discipline, ranking_season, participations)
      return {} if region.blank? || discipline.blank?
      player_ids = participations.map(&:player_id).compact.uniq
      return {} if player_ids.empty?
      scope = PlayerRanking.where(region_id: region.id, discipline_id: discipline.id, player_id: player_ids)
      scope = scope.where(season_id: ranking_season.id) if ranking_season
      pcid_by_player = {}
      scope.each { |r| pcid_by_player[r.player_id] ||= r.player_class_id }
      shortname_by_id = PlayerClass.where(id: pcid_by_player.values.compact.uniq).pluck(:id, :shortname).to_h
      pcid_by_player.transform_values { |pcid| shortname_by_id[pcid] }
    end

    def self.club_hash(club)
      return nil if club.blank?
      {cc_id: club.cc_id, shortname: club.shortname, name: club.name}
    end

    # class_by_player_id: nil -> kein :player_class-Feld (behavior-preserving, D-20-03);
    # Hash -> :player_class-Feld (Shortname oder nil falls der Spieler kein Ranking hat).
    def self.serialize_player(season_participation, class_by_player_id = nil)
      player = season_participation.player
      return nil if player.blank?
      row = {
        cc_id: player.cc_id,
        firstname: player.firstname,
        lastname: player.lastname,
        dbu_nr: player.dbu_nr&.to_s,
        status: season_participation.status
      }
      row[:player_class] = class_by_player_id[player.id] if class_by_player_id
      row
    end
  end
end
