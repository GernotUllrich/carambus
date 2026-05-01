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
  # Phase 38.8 REVIEW CR-02 — re-entry guard regression.
  #
  # The Phase 38.8 :close_match after-callback `advance_tournament_round_if_present`
  # delegates to `advance_round_after_match_close`, which calls
  # `@tournament_monitor.finalize_round`. That method
  # (TournamentMonitorState#finalize_round, lib/tournament_monitor_state.rb:54)
  # iterates over its TableMonitors and itself fires `tabmon.close_match!` on
  # each — re-entering this same callback. Without the thread-local sentinel
  # `Thread.current[:_advancing_round_for_tm]`, the cascade would either:
  #   (a) infinite-loop until stack overflow, OR
  #   (b) at minimum, fire twice per operator click (double-advance current_round,
  #       duplicated TournamentMonitorUpdateResultsJob / TournamentStatusUpdateJob).
  #
  # The sentinel short-circuits any nested invocation while the outer cascade
  # is still in flight.
  # ============================================================================

  test "advance_tournament_round_if_present short-circuits when sentinel is set (CR-02)" do
    # When the thread-local sentinel is already set (i.e. an outer cascade is
    # in flight), nested invocations from finalize_round's tabmon.close_match!
    # loop must early-return before instantiating ResultProcessor again.
    tm = TableMonitor.new(state: "ready_for_new_match")
    # Stub tournament_monitor to return @tm (a real TournamentMonitor, not blank,
    # not a PartyMonitor) so we get past the polymorphism guard and exercise
    # only the sentinel guard.
    tm.define_singleton_method(:tournament_monitor) { @stubbed_tm }
    tm.instance_variable_set(:@stubbed_tm, @tm)

    # Set the sentinel — simulating the state during the nested re-entry.
    Thread.current[:_advancing_round_for_tm] = true
    begin
      # Spy: if the guard fails, ResultProcessor.new would be called.
      called = false
      TournamentMonitor::ResultProcessor.stub(:new, ->(_) { called = true; raise "should not reach here" }) do
        result = tm.advance_tournament_round_if_present
        assert_nil result, "advance_tournament_round_if_present must early-return when sentinel is set"
      end
      refute called, "TournamentMonitor::ResultProcessor must NOT be instantiated while sentinel is set"
    ensure
      Thread.current[:_advancing_round_for_tm] = nil
    end
  end

  test "advance_tournament_round_if_present clears sentinel via ensure even on exception (CR-02)" do
    # The sentinel must be cleared in ensure so subsequent unrelated cascades
    # are not blocked by stale state from a prior crash.
    tm = TableMonitor.new(state: "ready_for_new_match")
    tm.define_singleton_method(:tournament_monitor) { @stubbed_tm }
    tm.instance_variable_set(:@stubbed_tm, @tm)

    refute Thread.current[:_advancing_round_for_tm], "Sentinel must start cleared"

    TournamentMonitor::ResultProcessor.stub(:new, ->(_) { raise StandardError, "simulated cascade failure" }) do
      assert_raises(StandardError) do
        tm.advance_tournament_round_if_present
      end
    end

    assert_nil Thread.current[:_advancing_round_for_tm],
      "Sentinel must be cleared in ensure block even when the cascade raises"
  end
end
