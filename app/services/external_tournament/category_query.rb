# frozen_string_literal: true

module ExternalTournament
  # Plan 20-02 (v0.6 F4): Kategorie-/Klassen-Discovery fuer die externe Turnier-App.
  # Liefert die Selektor-Listen fuer die Turnier-Anlage: player_classes (Leistungsklassen via
  # discipline.player_classes), age_classes + genders (aus category_ccs der Region) sowie ein
  # reiches categories[]-Array. Read-only, region-scoped, keine Seiteneffekte.
  # Referenz: HANDOFF-to-carambus-setup-discovery.md (Endpoint 2a).
  #
  # Decisions (Plan 20-02, 2026-05-25):
  #   D-20-02-A player_classes-Quelle = discipline.player_classes (wie 20-01, sortiert
  #     PLAYER_CLASS_ORDER) — KEINE PlayerRanking/Saison; bewusste Ueberlappung mit 20-01.
  #   D-20-02-B discipline-Param OPTIONAL: mit → disziplin-skopierte Listen; ohne → region-weite
  #     Kategorie-Listen + player_classes=[]; vorhandener aber unaufloesbarer Name →
  #     discipline_resolved=false (Controller rendert 404).
  #   D-20-02-C category_cc-Region-Scope via context=shortname.downcase; Disziplin-Scope via
  #     branch_ccs.discipline_id.
  #   D-20-02-D Payload = flache Convenience-Listen (player_classes/age_classes/genders) PLUS
  #     reiches categories[] ({name,sex,min_age,max_age,status}); KEIN Status-Filter in v1.
  #   D-20-02-E season=current_season (informativ); genders als CategoryCc::SEX_MAP-Keys (M/F/U);
  #     per-Spieler age_class/gender DEFERRED (D-v0.6-AGECLASS → Phase 21).
  class CategoryQuery
    Result = Struct.new(:season, :player_classes, :age_classes, :genders, :categories,
      :discipline_resolved, keyword_init: true)

    # Player-Klassen-Ordnung (worst -> best) aus dem Discipline-Modell (wie DisciplineQuery).
    PLAYER_CLASS_ORDER = Discipline::PLAYER_CLASS_ORDER
    SEX_ORDER = %w[M F U].freeze

    def self.call(region:, discipline_name: nil)
      return empty(discipline_resolved: true) if region.blank?

      disciplines = resolve_disciplines(discipline_name)
      # D-20-02-B: discipline angegeben aber nicht aufloesbar -> Controller macht 404.
      return empty(discipline_resolved: false) if discipline_name.present? && disciplines.empty?

      category_ccs = category_scope(region, disciplines).to_a

      Result.new(
        season: Season.current_season,
        player_classes: player_classes_for(disciplines),
        age_classes: category_ccs.map(&:name).compact.reject(&:blank?).uniq.sort,
        genders: sorted_genders(category_ccs),
        categories: serialize_categories(category_ccs),
        discipline_resolved: true
      )
    end

    def self.empty(discipline_resolved:)
      Result.new(season: Season.current_season, player_classes: [], age_classes: [],
        genders: [], categories: [], discipline_resolved: discipline_resolved)
    end

    # D-20-02-B: exakter Name, sonst Synonym — RankingQuery-Finder wiederverwenden (DRY).
    def self.resolve_disciplines(name)
      return [] if name.blank?
      ExternalTournament::RankingQuery.find_disciplines(name)
    end

    # D-20-02-C: Region via context=shortname.downcase; Disziplin via branch_ccs.discipline_id.
    def self.category_scope(region, disciplines)
      scope = CategoryCc.where(context: region.shortname.downcase)
      return scope if disciplines.empty?
      scope.joins(:branch_cc).where(branch_ccs: {discipline_id: disciplines.map(&:id)})
    end

    # D-20-02-A: union der discipline.player_classes-Shortnames, sortiert PLAYER_CLASS_ORDER
    # (worst->best; Unbekannte ans Ende alpha). Ohne Disziplin -> [].
    def self.player_classes_for(disciplines)
      return [] if disciplines.empty?
      shortnames = disciplines.flat_map { |d| d.player_classes.map(&:shortname) }.compact.uniq
      shortnames.sort_by do |sn|
        idx = PLAYER_CLASS_ORDER.index(sn)
        idx ? [0, idx, ""] : [1, 0, sn.to_s]
      end
    end

    # D-20-02-E: distinct sex (M/F/U) geordnet nach SEX_ORDER; Unbekannte ans Ende alpha.
    def self.sorted_genders(category_ccs)
      category_ccs.map(&:sex).compact.reject(&:blank?).uniq.sort_by do |s|
        idx = SEX_ORDER.index(s)
        idx ? [0, idx, ""] : [1, 0, s.to_s]
      end
    end

    # D-20-02-D: reiches categories[]; KEIN Status-Filter (status nur als Feld).
    def self.serialize_categories(category_ccs)
      category_ccs.map do |c|
        {name: c.name, sex: c.sex, min_age: c.min_age, max_age: c.max_age, status: c.status}
      end.sort_by { |h| [h[:name].to_s, h[:min_age].to_i] }
    end
  end
end
