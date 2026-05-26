# frozen_string_literal: true

module ExternalTournament
  # Plan 21-05 (v0.6 Slice B): Meldelisten-Discovery fuer die externe Turnier-App.
  # Liefert die RegistrationListCc-Records einer Region (deadline, qualifying_date, status,
  # discipline, category) plus optionale tournament_cc-Verknuepfung. Read-only, region-scoped,
  # keine Seiteneffekte. Datenquelle: RegistrationSyncer (Plan 14-G.14) — der Syncer-Cron ist
  # heute auskommentiert (D-21-DISC-C), daher ist current_season-Coverage in der Praxis
  # 0 Records; Default-Saison-Calls liefern entsprechend leere Arrays bis Slice E den Cron
  # re-aktiviert. Live-Verify auf historische Saison (z.B. ?season=2022/2023) prueft die
  # Endpoint-Mechanik vorerst.
  #
  # Decisions (Plan 21-05, 2026-05-26):
  #   D-21-05-A Eigene Bridge-Resource (Endpoint 16), NICHT in categories embedded — folgt
  #     passiver Read-Schicht-Konvention aus 21-01/02/03/04 (D-21-03-DISC-E /
  #     D-21-04-DISC-F-Pattern fortgesetzt).
  #   D-21-05-B Default-Saison = Season.current_season; explizites unaufloesbares season →
  #     season_resolved=false (Controller rendert 404). Sniff-Befund: Cron-Defer macht
  #     Default-Calls leer — App-Team-Hinweis in Doku.
  #   D-21-05-C NBV-Pilot (Live-Verify nur NBV); Endpoint funktioniert technisch fuer jede
  #     Region.
  #   D-21-05-D tournament_cc-Reverse-Lookup als optionaler Sub-Hash im Payload; bulk-load
  #     via index_by (KEIN N+1). Bei Doppel-Verknuepfung deterministisch erste via order(:id).
  #   D-21-05-E status-Filter optional + exakter Match (kein Fuzzy/ILIKE; Statuswerte sind
  #     enum-artig). Tippfehler → leeres Array, KEIN 422.
  #   D-21-05-F Status-Hardcoded-Bug in registration_syncer.rb:107 (hardcoded "Freigegeben")
  #     DEFERRED — gehoert zu Slice E (Cron-Re-Enable + Bug-Fix gemeinsam). 21-05 spiegelt
  #     was in der DB steht.
  class RegistrationListQuery
    Result = Struct.new(:season, :items, :season_resolved, :discipline_resolved,
      :category_resolved, keyword_init: true)

    def self.call(region:, season: nil, discipline: nil, category: nil, status: nil)
      season_obj = resolve_season(season)
      return empty(season_resolved: false) if season.present? && season_obj.nil?

      disciplines = resolve_disciplines(discipline)
      return empty(season: season_obj, discipline_resolved: false) if discipline.present? && disciplines.empty?

      category_obj = resolve_category(region, category)
      return empty(season: season_obj, category_resolved: false) if category.present? && category_obj.nil?

      scope = RegistrationListCc
        .where(context: region.shortname.downcase, season_id: season_obj&.id)
        .includes(:season, :discipline, :category_cc)
      scope = scope.where(discipline_id: disciplines.map(&:id)) if disciplines.any?
      scope = scope.where(category_cc_id: category_obj.id) if category_obj
      scope = scope.where(status: status) if status.present?

      records = scope.order(:deadline, :id).to_a
      tc_by_list = bulk_tournament_cc(records)

      Result.new(
        season: season_obj,
        items: records.map { |rec| serialize(rec, tc_by_list[rec.id]) },
        season_resolved: true,
        discipline_resolved: true,
        category_resolved: true
      )
    end

    # D-21-05-B: Default current_season; explizit + nicht gefunden → nil (Controller 404).
    def self.resolve_season(name)
      return Season.current_season if name.blank?
      Season.find_by(name: name)
    end

    # Wiederverwendung des RankingQuery-Finders (name oder synonym).
    def self.resolve_disciplines(name)
      return [] if name.blank?
      ExternalTournament::RankingQuery.find_disciplines(name)
    end

    # Category-Lookup region-scoped (CategoryCc.context=shortname.downcase, exakter Name).
    def self.resolve_category(region, name)
      return nil if name.blank?
      CategoryCc.find_by(context: region.shortname.downcase, name: name)
    end

    # D-21-05-D: Bulk-Reverse-Lookup TournamentCc → KEIN N+1. Bei Doppel-Verknuepfung
    # (unwahrscheinlich) deterministisch erste via order(:id).
    def self.bulk_tournament_cc(records)
      list_ids = records.map(&:id)
      return {} if list_ids.empty?
      TournamentCc.where(registration_list_cc_id: list_ids).order(:id)
        .each_with_object({}) { |tc, h| h[tc.registration_list_cc_id] ||= tc }
    end

    def self.serialize(rec, tc)
      {
        cc_id: rec.cc_id,
        name: rec.name,
        deadline: rec.deadline&.iso8601,
        qualifying_date: rec.qualifying_date&.iso8601,
        status: rec.status,
        season: rec.season&.name,
        discipline: rec.discipline && {id: rec.discipline.id, name: rec.discipline.name},
        category_cc: rec.category_cc && {id: rec.category_cc.id, name: rec.category_cc.name},
        tournament_cc: tc && {id: tc.id, name: tc.name, date: tc.tournament_start&.iso8601}
      }
    end

    def self.empty(season: nil, season_resolved: true, discipline_resolved: true, category_resolved: true)
      Result.new(season: season, items: [], season_resolved: season_resolved,
        discipline_resolved: discipline_resolved, category_resolved: category_resolved)
    end
  end
end
