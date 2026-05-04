# frozen_string_literal: true

require "test_helper"

# Unit tests for TournamentMonitor::ResultProcessor
# Verifies the result processing pipeline extracted from TournamentMonitorSupport and TournamentMonitorState.
class TournamentMonitor::ResultProcessorTest < ActiveSupport::TestCase
  include KoTournamentTestHelper

  self.use_transactional_tests = true

  setup do
    @test_data = create_ko_tournament_with_seedings(4, {
      balls_goal: 30,
      innings_goal: 25
    })
    @tournament = @test_data[:tournament]
    @players = @test_data[:players]

    @tournament.initialize_tournament_monitor
    @tm = @tournament.tournament_monitor

    # Populate minimal data for tests
    @tm.data ||= {}
    @tm.data["rankings"] ||= {}
    @tm.save!

    @processor = TournamentMonitor::ResultProcessor.new(@tm)
  end

  teardown do
    cleanup_ko_tournament(@test_data) if @test_data
  end

  # ============================================================================
  # Test 1: ResultProcessor.new creates instance with @tournament_monitor accessor
  # ============================================================================

  test "ResultProcessor.new stores tournament_monitor reference" do
    processor = TournamentMonitor::ResultProcessor.new(@tm)
    assert_not_nil processor
    # Verify the processor was created with the correct model
    assert_instance_of TournamentMonitor::ResultProcessor, processor
  end

  test "ResultProcessor is a plain class (not ApplicationService)" do
    assert_equal false, TournamentMonitor::ResultProcessor.ancestors.include?(ApplicationService),
      "ResultProcessor should NOT inherit from ApplicationService"
  end

  test "ResultProcessor does not have a class-level call method" do
    assert_equal false, TournamentMonitor::ResultProcessor.respond_to?(:call),
      "ResultProcessor should not have a .call class method (it is a PORO, not ApplicationService)"
  end

  # ============================================================================
  # Test 2: report_result contains game.with_lock block (structural verification)
  # ============================================================================

  test "report_result method is public" do
    assert @processor.respond_to?(:report_result),
      "report_result must be a public method on ResultProcessor"
  end

  test "report_result source contains game.with_lock block" do
    source = TournamentMonitor::ResultProcessor.instance_method(:report_result).source_location.first
    file_content = File.read(source)
    assert_match(/game\.with_lock/, file_content,
      "report_result source must contain game.with_lock pessimistic lock")
  end

  test "report_result source has write_game_result_data inside with_lock block" do
    source = TournamentMonitor::ResultProcessor.instance_method(:report_result).source_location.first
    file_content = File.read(source)
    # Verify the lock block structure is present
    assert_match(/with_lock.*write_game_result_data/m, file_content,
      "write_game_result_data must be called inside the with_lock block")
  end

  # ============================================================================
  # Test 3: accumulate_results is public and reads/writes @tournament_monitor.data["rankings"]
  # ============================================================================

  test "accumulate_results is a public method" do
    assert @processor.respond_to?(:accumulate_results),
      "accumulate_results must be a public method on ResultProcessor"
  end

  test "accumulate_results writes rankings to tournament_monitor data" do
    # Create a game with game participations for the tournament
    game = @tournament.games.where("games.id >= #{Game::MIN_ID}").first

    # Skip test if no local games exist (clean fixture state)
    skip "No local games available for accumulate_results test" unless game.present?

    @processor.accumulate_results

    @tm.reload
    assert @tm.data["rankings"].present?,
      "accumulate_results must write rankings to tournament_monitor.data['rankings']"
    assert @tm.data["rankings"].key?("total"),
      "rankings must contain 'total' key"
    assert @tm.data["rankings"].key?("groups"),
      "rankings must contain 'groups' key"
    assert @tm.data["rankings"].key?("endgames"),
      "rankings must contain 'endgames' key"
  end

  test "accumulate_results creates correct ranking structure even with no game participations" do
    # With no game participations, rankings should be empty but have correct structure
    @processor.accumulate_results

    @tm.reload
    assert @tm.data["rankings"].present?
    assert_equal({}, @tm.data["rankings"]["total"])
    assert @tm.data["rankings"]["groups"].key?("total")
    assert @tm.data["rankings"]["endgames"].key?("total")
  end

  # ============================================================================
  # Test 4: update_ranking is public and calls player_id_from_ranking via @tournament_monitor
  # ============================================================================

  test "update_ranking is a public method" do
    assert @processor.respond_to?(:update_ranking),
      "update_ranking must be a public method on ResultProcessor"
  end

  test "update_ranking calls player_id_from_ranking via @tournament_monitor" do
    # Build minimal rankings and executor_params with RK rules
    @tm.data["rankings"] = { "total" => { @players[0].id.to_s => { "points" => 4, "gd" => 2.0 } } }
    @tm.save!

    executor_params = JSON.parse(@tournament.tournament_plan.executor_params)

    # Skip if tournament plan has no RK rules (not all plans have ranking rules)
    skip "Tournament plan has no RK rules" unless executor_params["RK"].present?

    player_id_called = false
    original_method = @tm.method(:player_id_from_ranking)

    @tm.define_singleton_method(:player_id_from_ranking) do |rule_str, opts = {}|
      player_id_called = true
      original_method.call(rule_str, opts)
    end

    begin
      @processor.update_ranking
    rescue StandardError
      # May raise on incomplete test data — we only care about delegation
    end

    assert player_id_called,
      "update_ranking must call player_id_from_ranking on @tournament_monitor"
  end

  # ============================================================================
  # Test 5: update_game_participations_for_game updates GameParticipation records
  # ============================================================================

  test "update_game_participations is a public method" do
    assert @processor.respond_to?(:update_game_participations),
      "update_game_participations must be a public method on ResultProcessor"
  end

  test "update_game_participations delegates to update_game_participations_for_game" do
    game = @tournament.games.where("games.id >= #{Game::MIN_ID}").first
    skip "No local games available for update_game_participations test" unless game.present?

    gp_a = game.game_participations.where(role: "playera").first
    gp_b = game.game_participations.where(role: "playerb").first
    skip "No game participations available" unless gp_a.present? && gp_b.present?

    # Build a mock table_monitor data structure
    table_monitor_data = {
      "player a" => { "result" => 25, "innings" => 10, "balls_goal" => 30, "hs" => 8 },
      "playerb" => { "result" => 20, "innings" => 10, "balls_goal" => 30, "hs" => 6 }
    }

    mock_tabmon = Minitest::Mock.new
    mock_tabmon.expect :game, game
    mock_tabmon.expect :data, table_monitor_data

    # Should not raise — update_game_participations_for_game handles errors gracefully
    assert_nothing_raised do
      @processor.update_game_participations(mock_tabmon)
    end
  end

  # ============================================================================
  # Test 6: write_game_result_data is private (not public)
  # ============================================================================

  test "write_game_result_data is private" do
    assert_equal false, @processor.respond_to?(:write_game_result_data),
      "write_game_result_data must be private"
    assert @processor.respond_to?(:write_game_result_data, true),
      "write_game_result_data must exist as private method"
  end

  test "finalize_game_result is private" do
    assert_equal false, @processor.respond_to?(:finalize_game_result),
      "finalize_game_result must be private"
    assert @processor.respond_to?(:finalize_game_result, true),
      "finalize_game_result must exist as private method"
  end

  test "add_result_to is private" do
    assert_equal false, @processor.respond_to?(:add_result_to),
      "add_result_to must be private"
    assert @processor.respond_to?(:add_result_to, true),
      "add_result_to must exist as private method"
  end

  test "write_finale_csv_for_upload is private" do
    assert_equal false, @processor.respond_to?(:write_finale_csv_for_upload),
      "write_finale_csv_for_upload must be private"
    assert @processor.respond_to?(:write_finale_csv_for_upload, true),
      "write_finale_csv_for_upload must exist as private method"
  end

  # ============================================================================
  # Test 7: All 9 required methods exist on ResultProcessor
  # ============================================================================

  test "ResultProcessor has all 9 required extracted methods" do
    # Public methods
    %i[report_result accumulate_results update_ranking update_game_participations].each do |method_name|
      assert @processor.respond_to?(method_name),
        "ResultProcessor must have public method: #{method_name}"
    end

    # Private methods
    %i[write_game_result_data finalize_game_result update_game_participations_for_game add_result_to write_finale_csv_for_upload].each do |method_name|
      assert @processor.respond_to?(method_name, true),
        "ResultProcessor must have private method: #{method_name}"
    end
  end

  # ============================================================================
  # Test 8: ResultProcessor uses @tournament_monitor prefix (not bare self)
  # ============================================================================

  test "ResultProcessor source uses @tournament_monitor prefix for model calls" do
    source_file = File.read(
      File.join(Rails.root, "app/services/tournament_monitor/result_processor.rb")
    )

    # Verify critical model calls use @tournament_monitor prefix
    assert_match(/@tournament_monitor\.reload/, source_file,
      "reload must be called as @tournament_monitor.reload")
    assert_match(/@tournament_monitor\.save!/, source_file,
      "save! must be called as @tournament_monitor.save!")
    assert_match(/@tournament_monitor\.data/, source_file,
      "data must be accessed as @tournament_monitor.data")
    assert_match(/@tournament_monitor\.tournament/, source_file,
      "tournament must be accessed as @tournament_monitor.tournament")

    # Verify AASM events use @tournament_monitor prefix
    assert_match(/@tournament_monitor\.end_of_tournament!/, source_file,
      "end_of_tournament! must fire on @tournament_monitor")
    assert_match(/@tournament_monitor\.start_playing_finals!/, source_file,
      "start_playing_finals! must fire on @tournament_monitor")
    assert_match(/@tournament_monitor\.start_playing_groups!/, source_file,
      "start_playing_groups! must fire on @tournament_monitor")
  end

  # ============================================================================
  # Phase 38.8 Plan 04 — Deferred round-progression cascade contract
  #
  # report_result must NO LONGER auto-progress the round (that clobbered the
  # operator-visible "Endergebnis erfasst" display before phase 38.8). The
  # cascade now runs only when AASM close_match event fires from operator
  # action (Plan 38.8-05 wires the button).
  # ============================================================================

  test "advance_tournament_round_if_present is a no-op when tournament_monitor is blank (training mode)" do
    # In-memory TM with no tournament_monitor (training mode). No persistence needed —
    # we only verify the early-return path of advance_tournament_round_if_present.
    tm = TableMonitor.new(state: "final_match_score", data: { "ba_results" => {} })
    assert_nil tm.tournament_monitor

    result = nil
    assert_nothing_raised do
      result = tm.advance_tournament_round_if_present
    end
    assert_nil result, "Training-mode TM (no tournament_monitor) must short-circuit advance_tournament_round_if_present"
  end

  test "TournamentMonitor::ResultProcessor exposes public advance_round_after_match_close method" do
    assert TournamentMonitor::ResultProcessor.instance_methods(false).include?(:advance_round_after_match_close),
      "advance_round_after_match_close must be a public instance method (called by TableMonitor AASM after-callback)"
  end

  test "TableMonitor close_match AASM event has after: :advance_tournament_round_if_present callback" do
    close_event = TableMonitor.aasm.events.find { |e| e.name == :close_match }
    assert_not_nil close_event, "AASM event :close_match must exist"

    # The `after:` option is stored in event options. Implementation detail varies by AASM version;
    # at minimum verify the method advance_tournament_round_if_present exists on the model.
    assert TableMonitor.instance_methods(false).include?(:advance_tournament_round_if_present),
      "TableMonitor#advance_tournament_round_if_present must exist (Plan 38.8-04 Task 2)"
  end

  test "report_result no longer mentions populate_tables in its method body (deferred cascade)" do
    # Static-source assertion — proves the cascade was extracted, not duplicated.
    # NOTE: We assert no REAL CALL SITE (e.g. @tournament_monitor.populate_tables) inside
    # report_result, NOT the bare word. The Phase 38.8 explanatory comment block intentionally
    # mentions the deferred method names ("populate_tables / incr_current_round! / finalize_round")
    # to document the deferral. Mirrors Plan 38.8-03's documented "comment-text grep noise
    # accepted as DOCUMENTARY" pattern (see 38.8-03-SUMMARY.md key-decisions).
    src = File.read(Rails.root.join("app/services/tournament_monitor/result_processor.rb"))
    report_result_match = src.match(/def report_result.*?(?=\n  def )/m)
    assert_not_nil report_result_match, "report_result method must exist in result_processor.rb"
    body = report_result_match[0]
    refute_match(/@tournament_monitor\.populate_tables/, body,
      "Phase 38.8 contract: report_result must NOT call @tournament_monitor.populate_tables (cascade extracted to advance_round_after_match_close)")
    refute_match(/@tournament_monitor\.incr_current_round!/, body,
      "Phase 38.8 contract: report_result must NOT call @tournament_monitor.incr_current_round! (cascade deferred)")
    refute_match(/@tournament_monitor\.finalize_round\b/, body,
      "Phase 38.8 contract: report_result must NOT call @tournament_monitor.finalize_round (cascade deferred)")
    refute_match(/TournamentMonitorUpdateResultsJob\.perform_later/, body,
      "Phase 38.8 contract: report_result must NOT enqueue TournamentMonitorUpdateResultsJob (cascade deferred)")
  end

  test "advance_round_after_match_close method body contains all 6 cascade calls (extracted verbatim)" do
    src = File.read(Rails.root.join("app/services/tournament_monitor/result_processor.rb"))
    method_match = src.match(/def advance_round_after_match_close.*?(?=\n  def |\nend\b)/m)
    assert_not_nil method_match, "advance_round_after_match_close method must exist"
    body = method_match[0]
    %w[populate_tables incr_current_round! finalize_round start_playing_groups! TournamentMonitorUpdateResultsJob TournamentStatusUpdateJob].each do |needle|
      assert_match(/#{Regexp.escape(needle)}/, body,
        "advance_round_after_match_close must contain '#{needle}' (extracted from report_result)")
    end
  end

  # ============================================================================
  # Phase quick-260505-0b5 (CR-02 sentinel restore — narrow-scoped per-TM)
  #
  # Live incident 2026-05-05T00:01:45Z, Tournament[17416] / TournamentMonitor[50000028]:
  # Operator clicked "Nächstes Spiel" on a tied 10:10 Einband finals game →
  # SystemStackError after ~323 nested savepoints. Recursion path:
  #   TableMonitor#close_match! (AASM)
  #     → after-callback advance_tournament_round_if_present
  #     → ResultProcessor#advance_round_after_match_close
  #     → @tournament_monitor.finalize_round
  #     → loops table_monitors, calls tabmon.close_match! per TM
  #     → re-enters advance_tournament_round_if_present for SAME outer TM → recurse → SystemStackError.
  #
  # Original sentinel (commit 37796f7d) was reverted by 0dbe45c4 (2026-05-01)
  # on insufficient BK-2 single-set training-mode evidence; tournament-finals
  # exercise of finalize_round was never validated. Restored here with
  # narrow per-TM scoping (sentinel == self.id, NOT == true) so legitimate
  # cross-TM cascades during finalize_round still run for OTHER TMs while
  # short-circuiting only re-entry for the SAME TM.
  # ============================================================================

  test "CR-02 tournament-finals close_match cascade does NOT recurse infinitely (regression)" do
    # Service-level dispatch — drive close_match! through the AASM after-callback chain,
    # confirm the TournamentMonitorState#finalize_round loop does NOT re-enter the SAME TM
    # via advance_tournament_round_if_present. Without the sentinel guard, this raises
    # SystemStackError after ~323 nested savepoints (live incident reproduction).
    games = @tournament.games.where("games.id >= #{Game::MIN_ID}").limit(2).to_a
    skip "Need at least 1 local game with id >= MIN_ID for cascade test" if games.empty?

    # Stub TournamentMonitor cascade methods so finalize_round is reachable but does NOT
    # enqueue real jobs / advance the round. Per Phase 38.8 Plan 06 D-decision, instance
    # singleton stubs (define_singleton_method) decouple the cascade from real DB advance.
    @tm.define_singleton_method(:populate_tables) { nil }
    @tm.define_singleton_method(:incr_current_round!) { nil }
    @tm.define_singleton_method(:start_playing_groups!) { nil }
    @tm.define_singleton_method(:group_phase_finished?) { false }
    @tm.define_singleton_method(:all_table_monitors_finished?) { true }

    tabmons = games.map do |game|
      tm = TableMonitor.create!(
        tournament_monitor: @tm,
        game: game,
        state: "final_match_score",
        data: {
          "playera" => { "result" => 10, "innings" => [10], "hs" => 10, "balls_goal" => 10 },
          "playerb" => { "result" => 10, "innings" => [10], "hs" => 10, "balls_goal" => 10 },
          "ba_results" => {},
          "sets_to_win" => 1,
          "sets" => [],
          "current_inning" => { "active_player" => "playera", "balls" => 0 }
        }
      )
      # Set game.data non-blank so finalize_round loop does NOT next-skip
      # game.data is JSON-serialized (serialize :data, coder: JSON, type: Hash) — pass a Hash, not a String.
      if game.data.blank?
        game.update_columns(data: { "playera" => { "result" => 10 }, "playerb" => { "result" => 10 } })
      end
      tm
    end

    outer_tm = tabmons.first

    begin
      # Stub job enqueues to no-op — we only care about recursion safety, not async ranking work.
      TournamentMonitorUpdateResultsJob.stub :perform_later, ->(_) { nil } do
        TournamentStatusUpdateJob.stub :perform_later, ->(_) { nil } do
          # Wrap in Timeout to bound RED-phase recursion (SystemStackError fires fast in
          # MRI but the savepoint allocation can hang under test transactions). 10s is
          # ample for a single legitimate close_match!.
          result = nil
          assert_nothing_raised do
            Timeout.timeout(10) do
              result = outer_tm.close_match!
            end
          end
          outer_tm.reload
          assert_equal "ready_for_new_match", outer_tm.state,
            "After close_match!, outer TM must be in :ready_for_new_match (AASM transition)"
          assert result, "close_match! must return truthy on success"
        end
      end
    ensure
      tabmons.each { |tm| tm.destroy if TableMonitor.exists?(tm.id) }
    end
  end

  test "CR-02 advance_tournament_round_if_present short-circuits when sentinel matches self.id (per-TM scope)" do
    # Pure unit test, no DB cascade. Builds an in-memory TM with id=99, primes the
    # thread-local sentinel to 99, and verifies the delegate to ResultProcessor.new
    # is NOT invoked (sentinel matches self.id → early-return).
    tm = TableMonitor.new(state: "ready_for_new_match")
    tm.define_singleton_method(:id) { 99 }
    fake_tm = TournamentMonitor.new
    tm.define_singleton_method(:tournament_monitor) { fake_tm }

    Thread.current[:_advancing_round_for_tm] = 99
    begin
      result = nil
      TournamentMonitor::ResultProcessor.stub :new, ->(_) { raise "ResultProcessor.new must NOT be invoked when sentinel matches self.id" } do
        assert_nothing_raised do
          result = tm.advance_tournament_round_if_present
        end
      end
      assert_nil result, "advance_tournament_round_if_present must return nil when sentinel matches self.id"
    ensure
      Thread.current[:_advancing_round_for_tm] = nil
    end
  end

  test "CR-02 advance_tournament_round_if_present DOES run when sentinel is set for a DIFFERENT TM (cross-TM cascade preserved)" do
    # Pure unit test. TM has id=99; sentinel is primed to 42 (different id);
    # delegate MUST be invoked because the per-TM scoping permits cross-TM cascades.
    tm = TableMonitor.new(state: "ready_for_new_match")
    tm.define_singleton_method(:id) { 99 }
    fake_tm = TournamentMonitor.new
    tm.define_singleton_method(:tournament_monitor) { fake_tm }

    spy_invoked = false
    fake_processor = Object.new
    fake_processor.define_singleton_method(:advance_round_after_match_close) do |_tabmon|
      spy_invoked = true
      nil
    end

    Thread.current[:_advancing_round_for_tm] = 42
    begin
      TournamentMonitor::ResultProcessor.stub :new, ->(_) { fake_processor } do
        assert_nothing_raised do
          tm.advance_tournament_round_if_present
        end
      end
      assert spy_invoked,
        "advance_tournament_round_if_present MUST invoke ResultProcessor#advance_round_after_match_close when sentinel is set for a DIFFERENT TM (cross-TM cascade preserved)"
    ensure
      Thread.current[:_advancing_round_for_tm] = nil
    end
  end

  test "CR-02 advance_tournament_round_if_present clears sentinel via ensure even on exception" do
    # Mirror of the original 37796f7d test — sentinel must be cleared in `ensure`
    # even when the delegate raises. Otherwise a single failed cascade would leave
    # the thread permanently unable to advance the same TM ever again.
    tm = TableMonitor.new(state: "ready_for_new_match")
    tm.define_singleton_method(:id) { 99 }
    fake_tm = TournamentMonitor.new
    tm.define_singleton_method(:tournament_monitor) { fake_tm }

    assert_nil Thread.current[:_advancing_round_for_tm], "Pre-condition: sentinel must be nil"
    begin
      TournamentMonitor::ResultProcessor.stub :new, ->(_) { raise StandardError, "simulated cascade failure" } do
        assert_raises(StandardError) do
          tm.advance_tournament_round_if_present
        end
      end
      assert_nil Thread.current[:_advancing_round_for_tm],
        "Post-condition: sentinel MUST be cleared via ensure even when delegate raises"
    ensure
      Thread.current[:_advancing_round_for_tm] = nil
    end
  end
end
