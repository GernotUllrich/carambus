# frozen_string_literal: true

# Plan 21-04 (Slice C): Berechnet `players.age_class` + `players.gender` aus der
# Player→seedings→tournament→tournament_cc→category_cc-Kette der **zwei abgeschlossenen
# Vorsaisons** je Region und persistiert die Ergebnisse. Hebt D-v0.6-AGECLASS (Phase 20)
# auf, sobald Daten persistiert sind.
#
# Decisions (Plan 21-04 — siehe `.paul/phases/21-clubcloud-admin-scraping/CONTEXT.md`):
#   D-21-04-DISC-A Saisonfenster = die 2 abgeschlossenen Vorsaisons (current-1, current-2) —
#     gleiche Saison-String-Sort-Logik wie PlayerClassCalculator (Plan 21-01).
#   D-21-04-DISC-B age_class = `category_cc.name` mit MAX(`category_cc.min_age`) über alle
#     qualifizierten seedings; bei MAX(min_age)=0 → NULL (sonst Lieferung semantisch leerer
#     Strings wie "Grand Prix"/"NDM" — siehe 21-04-SNIFF-FINDINGS.md Sektion 2).
#   D-21-04-DISC-C gender = `category_cc.sex` der **jüngsten seedings** (MAX(tournament_start));
#     Tiebreak deterministisch via Seeding-ID-DESC bei gleich-altem tournament_start.
#   D-21-04-DISC-D Coverage-Fallback = NULL persistieren wenn keine qualifizierten seedings
#     (oder MAX(min_age)=0 für age_class). KEINE Lügen-Defaults.
#   D-21-04-DISC-E NBV-Pilot. Andere Regionen späterer Slice.
#   D-21-04-DISC-G Persistierung als DB-Spalten (kein Compute-on-read).
#
# Polymorphic-Hinweis: `Seeding.tournament` ist polymorph (Tournament + InternationalTournament).
# Wir filtern via `tournament_type: "Tournament"` (reguläre Karambol-Karambol-Turniere), da nur
# diese via tournament_cc auf NBV-Context verknüpft sind. International-Tournaments haben kein
# tournament_cc.
#
# Usage:
#   PlayerAgeClassGenderHeuristic.call(region: Region.find_by(shortname: "NBV"))  # NBV-Pilot
#   PlayerAgeClassGenderHeuristic.call                                            # alle Regionen
#   PlayerAgeClassGenderHeuristic.call(region: ..., dry_run: true)                # nichts persistieren
class PlayerAgeClassGenderHeuristic < ApplicationService
  Result = Struct.new(
    :region, :seasons, :visited, :updated, :with_age_class, :with_gender, :both_null, :skipped,
    keyword_init: true
  )

  attr_reader :region, :dry_run

  def initialize(kwargs = {})
    @region = kwargs[:region]
    @dry_run = kwargs.fetch(:dry_run, false)
  end

  def call
    seasons = previous_two_seasons
    region_label = region&.shortname || "ALL"

    if seasons.empty?
      return Result.new(
        region: region_label, seasons: [], visited: 0, updated: 0,
        with_age_class: 0, with_gender: 0, both_null: 0, skipped: 0
      )
    end

    # Pre-filter NBV-Tournaments via tournament_cc.tournament_id (FK-Richtung von
    # tournament_ccs auf tournaments — siehe 21-04-SNIFF-FINDINGS.md Sektion 5).
    nbv_tcs = TournamentCc.where(context: scoped_context, season: seasons)
      .where.not(tournament_id: nil)
    tournament_ids_to_tc = nbv_tcs.pluck(:tournament_id, :category_cc_id).to_h

    return empty_result(region_label, seasons) if tournament_ids_to_tc.empty?

    # Distinct Player-IDs mit qualifizierten Seedings.
    player_ids = Seeding.where(tournament_type: "Tournament", tournament_id: tournament_ids_to_tc.keys)
      .where.not(player_id: nil)
      .distinct
      .pluck(:player_id)

    # Vorab CategoryCc-Lookup (id → {name, sex, min_age}) für die NBV-Subset.
    category_ids = tournament_ids_to_tc.values.compact.uniq
    categories = CategoryCc.where(id: category_ids).index_by(&:id)

    stats = {visited: 0, updated: 0, with_age_class: 0, with_gender: 0, both_null: 0, skipped: 0}

    Player.where(id: player_ids).find_each(batch_size: 100) do |player|
      stats[:visited] += 1
      seedings = player.seedings
        .where(tournament_type: "Tournament", tournament_id: tournament_ids_to_tc.keys)

      age_class = compute_age_class(seedings, tournament_ids_to_tc, categories)
      gender = compute_gender(seedings, tournament_ids_to_tc, categories)

      stats[:with_age_class] += 1 if age_class
      stats[:with_gender] += 1 if gender
      stats[:both_null] += 1 if age_class.nil? && gender.nil?

      # D-21-04-DISC-D: nur updaten wenn mindestens 1 Wert berechnet wurde —
      # nicht-überschreiben vorheriger Werte bei leerem Befund (Idempotenz für Inactive).
      if age_class.nil? && gender.nil?
        stats[:skipped] += 1
        next
      end

      next if dry_run

      # Behavior-Preservation: nur die 2 Slice-C-Spalten anfassen.
      player.update_columns(age_class: age_class, gender: gender)
      stats[:updated] += 1
    end

    Result.new(
      region: region_label,
      seasons: seasons,
      **stats
    )
  end

  # ----- Pure-Function-Helpers (testable ohne DB-Setup) -----

  # D-21-04-DISC-B: Pure function — MAX(min_age) → name, NULL bei MAX=0 / leerem Input.
  # Args: Array of { min_age: int, name: str }
  def self.pick_age_class(candidates)
    return nil if candidates.empty?
    filtered = candidates.reject { |c| c[:min_age].to_i.zero? }
    return nil if filtered.empty?
    filtered.max_by { |c| c[:min_age] }[:name]
  end

  # D-21-04-DISC-C: Pure function — jüngste-seedings-sex gewinnt (sorted DESC).
  # Args: Array of { sex: str, _sort_key: comparable } already sorted DESC.
  def self.pick_gender(sorted_candidates)
    sorted_candidates.each do |c|
      return c[:sex] if c[:sex].present?
    end
    nil
  end

  private

  def scoped_context
    return region.shortname.downcase if region
    nil # for region-all-mode: caller-responsible to filter context elsewhere
  end

  # D-21-04-DISC-A: gleiche String-Sortier-Logik wie PlayerClassCalculator (Plan 21-01).
  # "YYYY/YYYY+1" sortiert lexicographisch chronologisch.
  def previous_two_seasons
    current = Season.current_season
    return [] unless current

    Season.where("name < ?", current.name)
      .order(name: :desc)
      .limit(2)
      .pluck(:name)
  end

  def compute_age_class(seedings, tournament_ids_to_tc, categories)
    candidates = seedings.filter_map do |s|
      cat_id = tournament_ids_to_tc[s.tournament_id]
      next nil unless cat_id
      cat = categories[cat_id]
      next nil unless cat
      {min_age: cat.min_age.to_i, name: cat.name}
    end
    self.class.pick_age_class(candidates)
  end

  def compute_gender(seedings, tournament_ids_to_tc, categories)
    # Lade tournament.date für die seedings — N+1 vermieden via bulk-pluck.
    # Tournaments hat `date`, nicht `tournament_start` (das liegt auf tournament_ccs).
    # Production-Bug-Fix 2026-05-26.
    seeding_data = seedings.joins("INNER JOIN tournaments t ON t.id = seedings.tournament_id")
      .pluck(:id, :tournament_id, "t.date")

    # Sortiere DESC nach tournament.date (= "jüngste seedings"), tiebreak DESC seeding.id.
    sorted_candidates = seeding_data.sort_by { |sid, _tid, ts| [-(ts&.to_i || 0), -sid] }
      .filter_map do |_sid, tid, _ts|
        cat_id = tournament_ids_to_tc[tid]
        cat = categories[cat_id] if cat_id
        cat ? {sex: cat.sex} : nil
      end
    self.class.pick_gender(sorted_candidates)
  end

  def empty_result(region_label, seasons)
    Result.new(
      region: region_label, seasons: seasons, visited: 0, updated: 0,
      with_age_class: 0, with_gender: 0, both_null: 0, skipped: 0
    )
  end
end
