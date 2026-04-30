# frozen_string_literal: true

require "test_helper"

class GameTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Phase 38.7 Plan 04 — Game.derive_tiebreak_required tests (D-04, D-05, D-13).
  #
  # 4-Level-Hierarchie:
  #   1. Tournament.data['tiebreak_on_draw']                      (highest)
  #   2. TournamentPlan.executor_params['g{group_no}']['tiebreak_on_draw']
  #   3. Discipline.data['tiebreak_on_draw']
  #   4. false                                                    (default)
  #
  # Sparse-override semantics (D-05): each level's data is queried via `data.key?`,
  # NOT `data[].present?`. An explicit `false` at any level overrides `true` at
  # lower levels. A missing key falls through to the next level.
  # ---------------------------------------------------------------------------

  # Tournament has `serialize :data, coder: JSON, type: Hash`, so callers must pass a Hash —
  # the resolver receives the already-deserialized Hash via tournament.data. Discipline +
  # TournamentPlan use plain text columns, so the resolver receives the raw JSON string and
  # must parse it itself. Both shapes are exercised below.

  test "derive_tiebreak_required returns true when Tournament.data sets tiebreak_on_draw=true" do
    tournament = Tournament.new(data: {"tiebreak_on_draw" => true})
    assert_equal true, Game.derive_tiebreak_required(tournament: tournament)
  end

  test "derive_tiebreak_required returns false when Tournament.data sets tiebreak_on_draw=false (sparse override)" do
    tournament = Tournament.new(data: {"tiebreak_on_draw" => false})
    discipline = Discipline.new(data: '{"tiebreak_on_draw":true}')
    assert_equal false, Game.derive_tiebreak_required(tournament: tournament, discipline: discipline),
      "Explicit Tournament=false must override Discipline=true (D-05 sparse semantics)"
  end

  test "derive_tiebreak_required falls through to TournamentPlan when Tournament has no key" do
    tournament = Tournament.new(data: {})
    tournament_plan = TournamentPlan.new(executor_params: '{"g1":{"tiebreak_on_draw":true}}')
    assert_equal true, Game.derive_tiebreak_required(
      tournament: tournament,
      tournament_plan: tournament_plan,
      group_no: "1"
    )
  end

  test "derive_tiebreak_required falls through to Discipline when Tournament + Plan have no key" do
    tournament = Tournament.new(data: {})
    tournament_plan = TournamentPlan.new(executor_params: '{"g1":{"balls":100}}')
    discipline = Discipline.new(data: '{"tiebreak_on_draw":true}')
    assert_equal true, Game.derive_tiebreak_required(
      tournament: tournament,
      tournament_plan: tournament_plan,
      group_no: "1",
      discipline: discipline
    )
  end

  test "derive_tiebreak_required returns false when no level has the key (default)" do
    assert_equal false, Game.derive_tiebreak_required(
      tournament: Tournament.new(data: {}),
      discipline: Discipline.new(data: "{}")
    )
  end

  test "derive_tiebreak_required ignores TournamentPlan key for wrong group_no" do
    tournament = Tournament.new(data: {})
    tournament_plan = TournamentPlan.new(executor_params: '{"g2":{"tiebreak_on_draw":true}}')
    discipline = Discipline.new(data: "{}")
    # Looking up group_no=1, but key sits on g2 — must fall through to Discipline (no key) → false
    assert_equal false, Game.derive_tiebreak_required(
      tournament: tournament,
      tournament_plan: tournament_plan,
      group_no: "1",
      discipline: discipline
    )
  end

  test "derive_tiebreak_required works in training mode (no Tournament, no Plan, BK-2 default true via Plan 01)" do
    discipline = Discipline.new(data: '{"tiebreak_on_draw":true}')
    assert_equal true, Game.derive_tiebreak_required(discipline: discipline),
      "D-13: training matches with BK-2 / BK-2kombi default to true via Discipline.data"
  end

  test "derive_tiebreak_required returns false when all args are nil (defensive default)" do
    assert_equal false, Game.derive_tiebreak_required
  end

  test "derive_tiebreak_required tolerates corrupt JSON in tournament_plan.executor_params" do
    tournament = Tournament.new(data: {})
    tournament_plan = TournamentPlan.new(executor_params: "{not valid json")
    discipline = Discipline.new(data: '{"tiebreak_on_draw":true}')
    assert_nothing_raised do
      result = Game.derive_tiebreak_required(
        tournament: tournament,
        tournament_plan: tournament_plan,
        group_no: "1",
        discipline: discipline
      )
      assert_equal true, result, "Corrupt plan JSON must NOT crash; falls through to Discipline default"
    end
  end

  test "derive_tiebreak_required accepts pre-parsed Hash for data fields (Tournament.data may be deserialized)" do
    # Tournament's data column is JSON-serialized via `serialize :data, coder: JSON, type: Hash`,
    # so reads return a Hash even when the underlying column is text. Confirm the resolver handles
    # the Hash branch in parse_data_hash.
    tournament = Tournament.new(data: {"tiebreak_on_draw" => true})
    assert_equal true, Game.derive_tiebreak_required(tournament: tournament),
      "Robustness: data may already be a Hash via the JSON serializer"
  end

  test "derive_tiebreak_required uses fixture-loaded BK-2 discipline and returns true (Plan 01 contract)" do
    bk2 = disciplines(:bk_2)
    assert_equal true, Game.derive_tiebreak_required(discipline: bk2),
      "Contract with Plan 01: BK-2 fixture must carry tiebreak_on_draw=true so training matches default to true"
  end
end
