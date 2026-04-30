# frozen_string_literal: true

require "test_helper"

class GameTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Phase 38.7 Plan 04 — Game.derive_tiebreak_required tests (D-04, D-05).
  #
  # 3-Level-Hierarchie (Discipline-Level entfernt 2026-04-30 per User-Feedback —
  # Tiebreak ist unabhängig von Discipline; Trainings-Sources werden in einer
  # Folge-Phase als direkte Game.data['tiebreak_required']-Bake umgesetzt):
  #   1. Tournament.data['tiebreak_on_draw']                      (highest)
  #   2. TournamentPlan.executor_params['g{group_no}']['tiebreak_on_draw']
  #   3. false                                                    (default)
  #
  # Sparse-override semantics (D-05): each level's data is queried via `data.key?`,
  # NOT `data[].present?`. An explicit `false` at any level overrides `true` at
  # lower levels. A missing key falls through to the next level.
  # ---------------------------------------------------------------------------

  test "derive_tiebreak_required returns true when Tournament.data sets tiebreak_on_draw=true" do
    tournament = Tournament.new(data: {"tiebreak_on_draw" => true})
    assert_equal true, Game.derive_tiebreak_required(tournament: tournament)
  end

  test "derive_tiebreak_required returns false when Tournament.data sets tiebreak_on_draw=false (sparse override)" do
    tournament = Tournament.new(data: {"tiebreak_on_draw" => false})
    tournament_plan = TournamentPlan.new(executor_params: '{"g1":{"tiebreak_on_draw":true}}')
    assert_equal false, Game.derive_tiebreak_required(
      tournament: tournament,
      tournament_plan: tournament_plan,
      group_no: "1"
    ),
      "Explicit Tournament=false must override TournamentPlan=true (D-05 sparse semantics)"
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

  test "derive_tiebreak_required returns false in training mode (no Tournament, no Plan)" do
    # Training-mode tiebreak is owned by a follow-up gap-closure plan
    # (carambus.yml quick_game_presets, free_game detail-form toggle, BK-2kombi
    # auto-detect). Those bake `Game.data['tiebreak_required']` directly without
    # going through this resolver. Without those sources, the resolver returns
    # false in training — which is the correct intermediate state.
    assert_equal false, Game.derive_tiebreak_required
  end

  test "derive_tiebreak_required returns false when no level has the key (default)" do
    assert_equal false, Game.derive_tiebreak_required(tournament: Tournament.new(data: {}))
  end

  test "derive_tiebreak_required ignores TournamentPlan key for wrong group_no" do
    tournament = Tournament.new(data: {})
    tournament_plan = TournamentPlan.new(executor_params: '{"g2":{"tiebreak_on_draw":true}}')
    # Looking up group_no=1, but key sits on g2 — must fall through to default (false)
    assert_equal false, Game.derive_tiebreak_required(
      tournament: tournament,
      tournament_plan: tournament_plan,
      group_no: "1"
    )
  end

  test "derive_tiebreak_required tolerates corrupt JSON in tournament_plan.executor_params" do
    tournament = Tournament.new(data: {"tiebreak_on_draw" => true})
    tournament_plan = TournamentPlan.new(executor_params: "{not valid json")
    assert_nothing_raised do
      # Corrupt plan JSON must NOT crash; Tournament-level `true` resolves first
      # so corruption at lower levels never matters here.
      result = Game.derive_tiebreak_required(
        tournament: tournament,
        tournament_plan: tournament_plan,
        group_no: "1"
      )
      assert_equal true, result
    end
  end

  test "derive_tiebreak_required accepts pre-parsed Hash for Tournament.data" do
    # Tournament's data column is JSON-serialized via `serialize :data, coder: JSON, type: Hash`,
    # so reads return a Hash even when the underlying column is text. Confirm the resolver handles
    # the Hash branch in parse_data_hash.
    tournament = Tournament.new(data: {"tiebreak_on_draw" => true})
    assert_equal true, Game.derive_tiebreak_required(tournament: tournament),
      "Robustness: data may already be a Hash via the JSON serializer"
  end
end
