# frozen_string_literal: true

require "test_helper"

# Bk2::AdvanceMatchState-Smoke-Tests nach Cleanup. Die Klasse hält nur noch
# initialize_bk2_state! (read-only Konfig-Seeding für Views) — Multiset-Logik
# ist im legacy karambol-Pfad, BK-Regeln sind als Guards in TableMonitor.
class Bk2::AdvanceMatchStateTest < ActiveSupport::TestCase
  setup do
    @tm = TableMonitor.create!(
      state: "playing",
      data: {
        "free_game_form" => "bk2_kombi",
        "bk2_options" => {
          "first_set_mode" => "direkter_zweikampf",
          "balls_goal" => 70,
          "direkter_zweikampf_max_shots_per_turn" => 2,
          "serienspiel_max_innings_per_set" => 5
        }
      }
    )
  end

  test "initialize_bk2_state! seeds bk2_state with derived config" do
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    state = @tm.reload.data["bk2_state"]

    assert_equal 1, state["current_set_number"]
    assert_equal "direkter_zweikampf", state["current_phase"]
    assert_equal "direkter_zweikampf", state["first_set_mode"]
    assert_equal 70, state["balls_goal"]
    assert_equal 70, state["set_target_points"]
    assert_equal 2, state["shots_left_in_turn"]
    assert_equal 0, state["innings_left_in_set"]
    assert_equal({"playera" => 0, "playerb" => 0}, state["sets_won"])
  end

  test "initialize_bk2_state! is idempotent (no-op when bk2_state already present)" do
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    @tm.reload.data["bk2_state"]["current_set_number"] = 99
    @tm.save!

    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    assert_equal 99, @tm.reload.data["bk2_state"]["current_set_number"],
      "second init must not overwrite existing state"
  end

  test "initialize_bk2_state! seeds SP-first config when first_set_mode=serienspiel" do
    @tm.update!(data: @tm.data.merge("bk2_options" => @tm.data["bk2_options"].merge("first_set_mode" => "serienspiel")))
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    state = @tm.reload.data["bk2_state"]

    assert_equal "serienspiel", state["current_phase"]
    assert_equal 0, state["shots_left_in_turn"]
    assert_equal 5, state["innings_left_in_set"]
  end

  test "initialize_bk2_state! re-seeds with new first_set_mode after caller deletes stale bk2_state" do
    # Quick 260501-wfv regression: shootout reflex flips bk2_options.first_set_mode
    # from DZ to SP and must wipe the stale bk2_state (seeded earlier in GameSetup)
    # so the re-call actually re-seeds. Without the delete, init_state_if_missing!
    # early-returns and bk2_state.first_set_mode stays "direkter_zweikampf" — the
    # exact bug this test pins.

    # Step 1: initial DZ-seed (mirrors GameSetup#perform_start_game).
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    initial = @tm.reload.data["bk2_state"]
    assert_equal "direkter_zweikampf", initial["first_set_mode"]
    assert_equal "direkter_zweikampf", initial["current_phase"]
    assert_equal 2, initial["shots_left_in_turn"]
    assert_equal 0, initial["innings_left_in_set"]

    # Step 2: operator picks SP at the shootout — reflex updates bk2_options
    # AND clears stale bk2_state (the fix this test pins).
    @tm.data["bk2_options"]["first_set_mode"] = "serienspiel"
    @tm.data.delete("bk2_state")
    @tm.save!

    # Step 3: subsequent initialize_bk2_state! call (still in the reflex) must re-seed.
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    state = @tm.reload.data["bk2_state"]

    # Step 4: bk2_state reflects the operator's SP pick, not the stale DZ seed.
    assert_equal "serienspiel", state["first_set_mode"],
      "bk2_state.first_set_mode must follow the just-picked mode"
    assert_equal "serienspiel", state["current_phase"],
      "current_phase for set 1 must equal the just-picked first_set_mode"
    assert_equal 5, state["innings_left_in_set"],
      "SP-mode set 1 must seed innings_left_in_set from sp_max"
    assert_equal 0, state["shots_left_in_turn"],
      "SP-mode set 1 must zero shots_left_in_turn"
  end

  test "initialize_bk2_state! falls back to defaults when bk2_options missing" do
    @tm.update!(data: {"free_game_form" => "bk2_kombi"})
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    state = @tm.reload.data["bk2_state"]

    assert_equal "direkter_zweikampf", state["first_set_mode"]
    assert_equal 50, state["balls_goal"]
    assert_equal 2, state["shots_left_in_turn"]
  end

  # ---------------------------------------------------------------------------
  # Phase 38.5 D-03 — rebake_at_set_open! orchestration delegate
  # ---------------------------------------------------------------------------
  # Tests for the new class method that delegates to BkParamResolver.bake!
  # at set boundaries for BK-2kombi matches.

  test "Phase 38.5 D-03: rebake_at_set_open! delegates to BkParamResolver.bake!" do
    # Save original and re-alias to stub. We cannot remove_method the singleton
    # method or we'd lose the real BkParamResolver.bake! for sibling tests.
    original = BkParamResolver.method(:bake!)
    recorded = []
    BkParamResolver.define_singleton_method(:bake!) { |arg| recorded << arg }

    Bk2::AdvanceMatchState.rebake_at_set_open!(@tm)

    assert_equal 1, recorded.length, "bake! must be called exactly once"
    assert_same @tm, recorded.first, "bake! must receive the TableMonitor argument"
  ensure
    # Restore the original module method by re-binding it.
    BkParamResolver.define_singleton_method(:bake!, original) if original
  end

  test "Phase 38.5 D-03: rebake_at_set_open! is idempotent across DZ -> SP set flip" do
    @tm.data["playera"] = {"discipline" => "BK2-Kombi"}
    @tm.data["sets"] = []
    @tm.save!

    # Set 1 (no sets closed yet) — DZ phase, effective_discipline=bk_2plus
    Bk2::AdvanceMatchState.rebake_at_set_open!(@tm)
    first_eff = @tm.data["effective_discipline"]
    first_allow = @tm.data["allow_negative_score_input"]
    first_credit = @tm.data["negative_credits_opponent"]

    # Re-run on same TM with same data — must produce identical values (idempotent)
    Bk2::AdvanceMatchState.rebake_at_set_open!(@tm)
    assert_equal first_eff, @tm.data["effective_discipline"], "second bake same set must be idempotent"
    assert_equal first_allow, @tm.data["allow_negative_score_input"]
    assert_equal first_credit, @tm.data["negative_credits_opponent"]

    # Simulate set 1 close: push a closed set
    @tm.data["sets"] = [{"Innings1" => [1], "Innings2" => [0]}]

    Bk2::AdvanceMatchState.rebake_at_set_open!(@tm)
    second_eff = @tm.data["effective_discipline"]

    # Set 1 (DZ-first) -> bk_2plus; Set 2 -> bk_2 (SP phase)
    assert_equal "bk_2plus", first_eff, "set 1 (DZ) must resolve to bk_2plus"
    assert_equal "bk_2", second_eff, "set 2 (SP) must resolve to bk_2"
  end
end
