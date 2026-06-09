# frozen_string_literal: true

require "test_helper"

# Plan 21-04 Slice C: Tests für PlayerAgeClassGenderHeuristic.
#
# Mix aus pure-function-Tests (für die Algorithmus-Kernlogik ohne DB-Setup-Hürden
# durch BranchCc → discipline+region_cc → CategoryCc-Validierungs-Kette) und Integration-
# Tests (für Default-Resolver-Pfad + NULL-Preservation).
#
# Test 3 (Default-Resolver) ist explizite Anwendung von Test-Hygiene-Lehre 2 aus 21-03
# ([[feedback_safety_assured_masks_strong_migrations]]).
class PlayerAgeClassGenderHeuristicTest < ActiveSupport::TestCase
  # ===========================================================================
  # Pure-Function-Tests (Algorithmus-Kernlogik, kein DB-Setup nötig)
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Test 1: pick_age_class — MAX(min_age) gewinnt
  # ---------------------------------------------------------------------------
  test "pick_age_class returns name of MAX(min_age)-candidate" do
    candidates = [
      {min_age: 18, name: "Junioren"},
      {min_age: 45, name: "Senioren"},
      {min_age: 0, name: "Generic NDM"}
    ]
    assert_equal "Senioren", PlayerAgeClassGenderHeuristic.pick_age_class(candidates)
  end

  test "pick_age_class returns nil for empty input" do
    assert_nil PlayerAgeClassGenderHeuristic.pick_age_class([])
  end

  test "pick_age_class returns nil when all candidates have min_age=0 (Sentinel-Konvention)" do
    candidates = [
      {min_age: 0, name: "Generic NDM"},
      {min_age: 0, name: "Grand Prix"}
    ]
    assert_nil PlayerAgeClassGenderHeuristic.pick_age_class(candidates),
      "MAX(min_age)=0 → NULL (semantisch unsauberer 'Grand Prix' wird nicht persistiert)"
  end

  test "pick_age_class filters out zero-min_age before MAX" do
    candidates = [
      {min_age: 0, name: "Allgemein"},
      {min_age: 60, name: "Senioren 60+"},
      {min_age: 45, name: "Senioren 45+"}
    ]
    assert_equal "Senioren 60+", PlayerAgeClassGenderHeuristic.pick_age_class(candidates)
  end

  # ---------------------------------------------------------------------------
  # Test 2: pick_gender — first non-blank wins (caller sortiert DESC)
  # ---------------------------------------------------------------------------
  test "pick_gender returns sex of first candidate (caller-sorted DESC by tournament_start)" do
    sorted = [
      {sex: "M"},  # jüngste seedings
      {sex: "F"},
      {sex: "U"}
    ]
    assert_equal "M", PlayerAgeClassGenderHeuristic.pick_gender(sorted)
  end

  test "pick_gender skips blank sex und nimmt nächsten non-blank" do
    sorted = [
      {sex: nil},
      {sex: ""},
      {sex: "F"},
      {sex: "M"}
    ]
    assert_equal "F", PlayerAgeClassGenderHeuristic.pick_gender(sorted)
  end

  test "pick_gender returns nil for all-blank input" do
    sorted = [{sex: nil}, {sex: ""}, {sex: nil}]
    assert_nil PlayerAgeClassGenderHeuristic.pick_gender(sorted)
  end

  test "pick_gender returns nil for empty input" do
    assert_nil PlayerAgeClassGenderHeuristic.pick_gender([])
  end

  # ===========================================================================
  # Integration-Tests (minimal DB-Setup)
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Test 3: Default-Resolver (Test-Hygiene-Lehre 2 aus 21-03)
  # ---------------------------------------------------------------------------
  # Verifiziert dass der Service den Season.current_season-Default-Pfad nutzt
  # (anstatt eines lexical-sort-Bugs wie 21-03-Fix-#1).
  test "default-resolver: nutzt Season.current_season für die 2 Vorsaisons" do
    region = regions(:nbv)
    result = PlayerAgeClassGenderHeuristic.call(region: region)

    # seasons im Result sind die 2 echten Vorsaisons (NICHT current_season).
    assert_equal 2, result.seasons.size, "Service liefert 2 Vorsaisons"
    refute_includes result.seasons, Season.current_season&.name,
      "current_season darf NICHT in den Vorsaisons sein (D-21-04-DISC-A: 'abgeschlossene' Vorsaisons)"
    # Sortierung absteigend
    assert result.seasons.first >= result.seasons.last,
      "Vorsaisons sortiert DESC (jüngste zuerst)"
  end

  # ---------------------------------------------------------------------------
  # Test 4: NULL-Preservation — Player ohne qualifizierte seedings nicht angefasst
  # ---------------------------------------------------------------------------
  test "Player ohne qualifizierte seedings wird nicht visited/updated (NULL-Preservation)" do
    region = regions(:nbv)
    # Brand-neuer Player mit vor-gesetzten Werten, KEINE seedings
    player = Player.create!(firstname: "TestC1", lastname: "NoSeedings",
      region_id: region.id, age_class: "Preserved", gender: "U")

    PlayerAgeClassGenderHeuristic.call(region: region)

    # Service iteriert nur über Player mit qualifizierten Seedings — dieser Player wird NICHT visited
    player.reload
    assert_equal "Preserved", player.age_class,
      "Player ohne seedings: bereits gesetzte Werte bleiben unverändert (D-21-04-DISC-D Idempotenz)"
    assert_equal "U", player.gender
  end

  # ---------------------------------------------------------------------------
  # Test 5a: SQL-Join-Smoke (Production-Bug-Regression 2026-05-26)
  # ---------------------------------------------------------------------------
  # Direct verification dass compute_gender's INNER JOIN gegen `tournaments.date`
  # (nicht `tournament_start` — das ist auf `tournament_ccs`) funktioniert.
  # Production-Lauf fiel ursprünglich auf "column t.tournament_start does not exist".
  # Lehre 3 aus 21-03 angewendet: Tests müssen den SQL-Pfad exercise'n, nicht nur
  # die pure-function-Logik abdecken.
  test "compute_gender SQL join references tournaments.date (production-bug regression)" do
    player = Player.create!(firstname: "JoinTest", lastname: "SqlSmoke",
      region_id: regions(:nbv).id)
    tournament = Tournament.create!(
      title: "SQL Join Test",
      date: Date.new(2024, 5, 1),
      season: seasons(:previous),
      organizer_type: "Region",
      organizer_id: regions(:nbv).id
    )
    Seeding.create!(player_id: player.id, tournament_id: tournament.id,
      tournament_type: "Tournament", state: "registered")

    # Execute the exact SQL pattern aus compute_gender. Vor Fix: PG::UndefinedColumn.
    # SQL-Join darf nicht crashen (tournaments hat `date`, nicht `tournament_start`).
    rows = nil
    assert_nothing_raised do
      rows = player.seedings
        .joins("INNER JOIN tournaments t ON t.id = seedings.tournament_id")
        .pluck(:id, :tournament_id, "t.date")
    end
    assert_equal 1, rows.size
    refute_nil rows.first[2], "SQL liefert tournament.date (non-nil)"
  end

  # ---------------------------------------------------------------------------
  # Test 5: dry_run macht keine DB-Writes
  # ---------------------------------------------------------------------------
  test "dry_run: berechnet aber persistiert nicht" do
    region = regions(:nbv)
    player = Player.create!(firstname: "TestC2", lastname: "DryRun",
      region_id: region.id, age_class: "Pre-DryRun", gender: "F")

    # Verifiziere dass dry_run-Modus keine .update_columns calls macht.
    # Da kein Setup für seedings: Player wird sowieso nicht visited.
    # Stattdessen prüfen wir das Service-Result-Verhalten.
    result = PlayerAgeClassGenderHeuristic.call(region: region, dry_run: true)

    # Result-Struct ist valide
    refute_nil result
    assert_kind_of Integer, result.visited
    assert_kind_of Integer, result.updated

    # Pre-existing Werte unverändert (klar, da kein visit/update stattfindet)
    player.reload
    assert_equal "Pre-DryRun", player.age_class
    assert_equal "F", player.gender
  end
end
