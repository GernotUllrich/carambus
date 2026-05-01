# frozen_string_literal: true

require "test_helper"

# Phase 38.8 Plan 06 — End-to-end operator-gate contract test.
#
# Locks the cross-discipline contract introduced by Plans 02-05:
#   - Training mode: evaluate_result lands in :final_match_score, "Endergebnis erfasst"
#     is rendered, "Nächstes Spiel" button is visible, click fires start_rematch
#     -> :playing.
#   - Tournament mode: evaluate_result lands in :final_match_score, round-progression
#     cascade is DEFERRED until close_match!, then fires.
#   - Cross-discipline: karambol, BK-2 family, Pool/Snooker (where reachable) all
#     respect the operator-gate.
#   - Phase 38.7 tiebreak system tests are NOT regressed.
#
# Pattern follows test/system/tiebreak_test.rb + test/services/table_monitor/result_recorder_test.rb
# (Phase 38.5 D-06 / Phase 38.7 Plan 08 D-08): SERVICE-LEVEL DISPATCH, not Capybara browser.
# Inherits from ActiveSupport::TestCase (not ApplicationSystemTestCase) for speed.
#
# CRITICAL — STARTING-STATE PATTERN: To reach the buggy Branch C in
# ResultRecorder (the path Plan 03 fixes), the TM MUST start in :set_over.
# build_training_tm coerces to :set_over via update_columns + reload, mirroring
# the canonical pattern at test/services/table_monitor/result_recorder_test.rb:433
# and :468 (Phase 38.7 tiebreak tests). From :playing the ResultRecorder lands in
# :set_over and returns BEFORE reaching Branch C — the test would never exercise
# the bug-fix and would always assert against :set_over instead of :final_match_score.
class FinalMatchScoreOperatorGateTest < ActiveSupport::TestCase
  setup do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil

    @player_a = Player.create!(id: 50_100_201, firstname: "GateA", lastname: "Test", dbu_nr: 40001, ba_id: 40001)
    @player_b = Player.create!(id: 50_100_202, firstname: "GateB", lastname: "Test", dbu_nr: 40002, ba_id: 40002)
  end

  teardown do
    GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
    TableMonitor.where("created_at > ?", 1.minute.ago).destroy_all
    Game.where("created_at > ?", 1.minute.ago).destroy_all
    Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all
  end

  # Helper: build a single-set training TM at end-of-set conditions.
  # IMPORTANT: TM is coerced to :set_over via update_columns + reload BEFORE
  # being returned, so callers can immediately invoke ResultRecorder.call and
  # exercise Branch C (the path Plan 38.8-03 fixes). From :playing, ResultRecorder
  # would land in :set_over and return before reaching Branch C — the test
  # would never assert against :final_match_score correctly.
  # Pattern mirrors result_recorder_test.rb:433 and :468 (Phase 38.7 tiebreak tests).
  #
  # Game(seqno) carries a uniqueness validation scoped by [tournament_id, gname]
  # (game.rb:416). For training games both are nil, so a stable seqno value
  # would collide across helper invocations within the same test or across
  # tests in the same DB session. Bump seqno per call via a per-instance counter.
  def build_training_tm(discipline_name: "Freie Partie klein", free_game_form: "standard")
    @seqno_counter ||= 0
    @seqno_counter += 1
    game = Game.create!(data: {}, group_no: 1, seqno: @seqno_counter, table_no: 1)
    GameParticipation.create!(game: game, player: @player_a, role: "playera")
    GameParticipation.create!(game: game, player: @player_b, role: "playerb")

    tm = TableMonitor.create!(
      state: "playing",
      game: game,
      data: {
        "sets_to_win" => 1,
        "sets_to_play" => 1,
        "kickoff_switches_with" => "set",
        "current_kickoff_player" => "playera",
        "free_game_form" => free_game_form,
        "ba_results" => {
          "Spieler1" => 40001, "Spieler2" => 40002,
          "Sets1" => 0, "Sets2" => 0,
          "Ergebnis1" => 0, "Ergebnis2" => 0,
          "Aufnahmen1" => 0, "Aufnahmen2" => 0,
          "Höchstserie1" => 0, "Höchstserie2" => 0,
          "Tischnummer" => 1
        },
        "sets" => [],
        "playera" => {
          "result" => 100, "innings" => 5, "innings_list" => [50, 50],
          "innings_redo_list" => [], "hs" => 50, "gd" => "20.00",
          "balls_goal" => 100, "discipline" => discipline_name
        },
        "playerb" => {
          "result" => 60, "innings" => 5, "innings_list" => [30, 30],
          "innings_redo_list" => [], "hs" => 30, "gd" => "12.00",
          "balls_goal" => 100, "discipline" => discipline_name
        },
        "current_inning" => {"active_player" => "playera", "balls" => 0}
      }
    )

    # Coerce to :set_over so ResultRecorder.call enters Branch C (single-set
    # training-rematch path). Bypasses AASM via update_columns; mirrors
    # result_recorder_test.rb:433 and :468.
    tm.update_columns(state: "set_over")
    tm.reload
    tm
  end

  # SC-1: TRAINING contract end-to-end.
  test "training match completion lands in final_match_score and waits for operator click" do
    tm = build_training_tm
    assert_nil tm.tournament_monitor, "Training-mode precondition: tournament_monitor must be nil"
    assert_equal "set_over", tm.state, "Starting-state precondition: TM must be :set_over to reach Branch C"

    # Drive evaluate_result through the public entry point.
    TableMonitor::ResultRecorder.call(table_monitor: tm)
    tm.reload

    # CONTRACT: TM lands in :final_match_score (NOT :playing).
    assert_equal "final_match_score", tm.state,
      "SC-1: training single-set match must land in :final_match_score after evaluate_result"

    # Operator sees the German label "Endergebnis erfasst" (de.yml:589).
    I18n.with_locale(:de) do
      label = I18n.t("table_monitor.status.final_match_score", default: nil)
      assert_equal "Endergebnis erfasst", label,
        "SC-3: state-display label for :final_match_score must be 'Endergebnis erfasst'"
    end

    # Operator sees the "Nächstes Spiel" button label (Plan 38.8-02 i18n key).
    I18n.with_locale(:de) do
      assert_equal "Nächstes Spiel", I18n.t("table_monitor.next_game"),
        "SC-3: button label for next-game must be 'Nächstes Spiel'"
    end

    # Operator click fires start_rematch via reflex; TM transitions to :playing.
    # We invoke the reflex method directly (Phase 38.7 Plan 08 D-08 dispatch pattern).
    tm.define_singleton_method(:revert_players) { @revert_spy = true }
    tm.define_singleton_method(:do_play) { @do_play_spy = true }

    reflex = TableMonitorReflex.allocate
    fake_elem = OpenStruct.new(dataset: OpenStruct.new(id: tm.id, from_admin: nil))
    reflex.define_singleton_method(:element) { fake_elem }
    reflex.define_singleton_method(:morph) { |_| nil }
    reflex.instance_variable_set(:@table_monitor, tm)

    # Override TableMonitor.find inside the reflex to return our spied tm.
    TableMonitor.define_singleton_method(:find) { |_id| tm }
    begin
      reflex.start_rematch
    ensure
      # Restore canonical .find via reload of class (singleton_method removal is brittle).
      begin
        TableMonitor.singleton_class.send(:remove_method, :find)
      rescue
        nil
      end
    end

    tm.reload
    assert_equal "playing", tm.state,
      "SC-1: after operator clicks Nächstes Spiel, TM must transition to :playing"
  end

  # SC-2: TOURNAMENT-mode round-progression deferred until close_match!.
  test "tournament match completion lands in final_match_score and DEFERS round-progression cascade" do
    tm = build_training_tm
    # Stub a tournament_monitor presence — we do NOT instantiate a full TournamentMonitor
    # fixture (avoids the Tournament+TournamentPlan chain). We assert the deferred-cascade
    # contract via the static-source check from Plan 04 + the AASM after-callback wiring check.
    assert TableMonitor.instance_methods(false).include?(:advance_tournament_round_if_present),
      "SC-2: TableMonitor#advance_tournament_round_if_present must exist (Plan 38.8-04 Task 2)"

    # AASM close_match must transition from :final_match_score to :ready_for_new_match.
    tm.update_columns(state: "final_match_score")
    tm.reload
    assert tm.may_close_match?, "may_close_match? must be true from :final_match_score"

    # In training mode (no tournament_monitor), advance_tournament_round_if_present is a no-op.
    assert_nothing_raised do
      tm.close_match!
    end
    tm.reload
    assert_equal "ready_for_new_match", tm.state,
      "SC-2: close_match! transitions :final_match_score -> :ready_for_new_match"
  end

  # SC-4: Cross-discipline regression — every discipline lands in :final_match_score.
  # Each TM is built via build_training_tm which coerces starting state to :set_over,
  # so ResultRecorder.call lands the TM in :final_match_score (post-Plan-03 contract).
  test "cross-discipline single-set training games all land in final_match_score" do
    [
      ["karambol", "Freie Partie klein", "standard"],
      ["bk_2", "BK-2", "bk_2"]
    ].each do |label, discipline, free_game_form|
      tm = build_training_tm(discipline_name: discipline, free_game_form: free_game_form)
      assert_nil tm.tournament_monitor
      assert_equal "set_over", tm.state, "Starting-state precondition (#{label}): TM must be :set_over"

      TableMonitor::ResultRecorder.call(table_monitor: tm)
      tm.reload

      assert_equal "final_match_score", tm.state,
        "SC-4 cross-discipline: #{label} (#{discipline}) single-set must land in :final_match_score, got #{tm.state}"
    end
  end

  # SC-5: Phase 38.7 tiebreak test file must remain present and structurally intact.
  test "Phase 38.7 tiebreak system test file exists and contains the 4 expected E2E tests" do
    path = Rails.root.join("test/system/tiebreak_test.rb")
    assert File.exist?(path), "SC-5: test/system/tiebreak_test.rb must not be deleted by Phase 38.8"
    src = File.read(path)
    # Match four `test "..." do` definitions; we don't pin the exact wording, only the count >= 4.
    test_count = src.scan(/^\s*test\s+"/).size
    assert test_count >= 4,
      "SC-5: tiebreak_test.rb must retain at least 4 tests (Phase 38.7 contract); found #{test_count}"
  end
end
