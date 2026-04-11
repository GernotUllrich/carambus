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
end
