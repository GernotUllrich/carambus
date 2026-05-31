# frozen_string_literal: true

module ExternalTournament
  # Plan 23-01 T3b (Seeding-Unification): Datenquelle gewechselt von
  # RegistrationListCc auf TournamentCc — die meldeliste-Felder leben jetzt
  # direkt auf TCc (Plan 23-01 T1a). RL/RC werden in T1b gedroppt.
  #
  # Payload-Vertrag bleibt stabil (D-21-05-* + D-23-01-A): cc_id, name, deadline,
  # qualifying_date, status, season, discipline, category_cc, tournament_cc-Sub-Hash.
  # `cc_id` = TCc.meldeliste_cc_id (war RL.cc_id). `tournament_cc` ist jetzt der
  # Self-Sub-Hash (Felder aus demselben Record), bleibt aber im Payload damit
  # externe Konsumenten unverändert arbeiten können.
  #
  # Status-Filter (D-21-05-E) ist no-op geworden — der ehemalige RL.status
  # ("Freigegeben"/"Gemeldet") wird im neuen Datenmodell nicht persistiert.
  # Filter-Aufrufe mit status: werden ignoriert; Payload-Feld bleibt für
  # Vertragstreue, ist aber nil.
  class RegistrationListQuery
    Result = Struct.new(:season, :items, :season_resolved, :discipline_resolved,
      :category_resolved, keyword_init: true)

    def self.call(region:, season: nil, discipline: nil, category: nil, status: nil)
      _ = status # bewusst ungenutzt — T3b no-op (siehe Modul-Header)

      season_obj = resolve_season(season)
      return empty(season_resolved: false) if season.present? && season_obj.nil?

      disciplines = resolve_disciplines(discipline)
      return empty(season: season_obj, discipline_resolved: false) if discipline.present? && disciplines.empty?

      category_obj = resolve_category(region, category)
      return empty(season: season_obj, category_resolved: false) if category.present? && category_obj.nil?

      scope = TournamentCc
        .where(context: region.shortname.downcase, season: season_obj&.name)
        .where.not(meldeliste_cc_id: nil)
        .includes(:discipline, :category_cc)
      scope = scope.where(discipline_id: disciplines.map(&:id)) if disciplines.any?
      scope = scope.where(category_cc_id: category_obj.id) if category_obj

      records = scope.order(:meldeliste_deadline, :id).to_a

      Result.new(
        season: season_obj,
        items: records.map { |rec| serialize(rec) },
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

    def self.serialize(rec)
      {
        cc_id: rec.meldeliste_cc_id,
        name: rec.name,
        deadline: rec.meldeliste_deadline&.iso8601,
        qualifying_date: rec.meldeliste_qualifying_date&.iso8601,
        status: nil,
        season: rec.season,
        discipline: rec.discipline && {id: rec.discipline.id, name: rec.discipline.name},
        category_cc: rec.category_cc && {id: rec.category_cc.id, name: rec.category_cc.name},
        tournament_cc: {id: rec.id, name: rec.name, date: rec.tournament_start&.iso8601}
      }
    end

    def self.empty(season: nil, season_resolved: true, discipline_resolved: true, category_resolved: true)
      Result.new(season: season, items: [], season_resolved: season_resolved,
        discipline_resolved: discipline_resolved, category_resolved: category_resolved)
    end
  end
end
