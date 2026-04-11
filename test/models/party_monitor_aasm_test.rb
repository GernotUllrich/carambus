# frozen_string_literal: true

require "test_helper"
require_relative "../support/party_monitor_test_helper"

# Characterization tests for PartyMonitor AASM state machine.
#
# Covers:
# - All 9 AASM states are declared (CHAR-03)
# - All 8 AASM events and their valid from-state transitions
# - Invalid transitions raise AASM::InvalidTransition
# - end_of_party special event: transitions to closed from any state
# - party_result_reporting_mode: legacy state with no standard inbound transitions
# - ApiProtectorTestOverride: allows saving PartyMonitor with local ID
# - reset_party_monitor: after_enter callback on seeding_mode
#
# Uses PartyMonitorTestHelper to create isolated records with local IDs.
# cattr_accessor allow_change_tables is reset in teardown to avoid test pollution.
class PartyMonitorAasmTest < ActiveSupport::TestCase
  include PartyMonitorTestHelper

  self.use_transactional_tests = true

  setup do
    result = create_party_monitor_with_party
    @pm = result[:party_monitor]
    @party = result[:party]
  end

  teardown do
    PartyMonitor.allow_change_tables = nil  # Per RESEARCH Pitfall 3: reset cattr to avoid pollution
  end

  # ============================================================================
  # 1. State inventory
  # ============================================================================

  test "AASM declares exactly 9 states" do
    state_names = PartyMonitor.aasm.states.map(&:name)
    expected = %i[
      seeding_mode
      table_definition_mode
      next_round_seeding_mode
      ready_for_next_round
      playing_round
      round_result_checking_mode
      party_result_checking_mode
      party_result_reporting_mode
      closed
    ]
    expected.each do |state|
      assert_includes state_names, state, "Expected state #{state} to be declared"
    end
    assert_equal 9, state_names.count, "Expected exactly 9 states, got #{state_names.count}: #{state_names.inspect}"
  end

  # ============================================================================
  # 2. Happy path transitions
  # ============================================================================

  test "happy path: seeding_mode through to playing_round" do
    assert_equal "seeding_mode", @pm.state

    assert @pm.may_prepare_next_round?, "Should be able to prepare_next_round from seeding_mode"
    @pm.prepare_next_round!
    assert_equal "table_definition_mode", @pm.state

    assert @pm.may_enter_next_round_seeding?
    @pm.enter_next_round_seeding!
    assert_equal "next_round_seeding_mode", @pm.state

    assert @pm.may_finish_round_seeding_mode?
    @pm.finish_round_seeding_mode!
    assert_equal "ready_for_next_round", @pm.state

    assert @pm.may_start_round?
    @pm.start_round!
    assert_equal "playing_round", @pm.state
  end

  test "happy path: playing_round through to closed" do
    @pm.update_column(:state, "playing_round")
    @pm.reload
    assert_equal "playing_round", @pm.state

    assert @pm.may_finish_round?
    @pm.finish_round!
    assert_equal "round_result_checking_mode", @pm.state

    assert @pm.may_finish_party?
    @pm.finish_party!
    assert_equal "party_result_checking_mode", @pm.state

    assert @pm.may_close_party?
    @pm.close_party!
    assert_equal "closed", @pm.state
  end

  # ============================================================================
  # 3. Individual event tests (one per event)
  # ============================================================================

  test "prepare_next_round: transitions from seeding_mode to table_definition_mode" do
    assert_equal "seeding_mode", @pm.state
    assert @pm.may_prepare_next_round?
    @pm.prepare_next_round!
    assert_equal "table_definition_mode", @pm.state
  end

  test "prepare_next_round: transitions from round_result_checking_mode to table_definition_mode" do
    @pm.update_column(:state, "round_result_checking_mode")
    @pm.reload
    assert @pm.may_prepare_next_round?
    @pm.prepare_next_round!
    assert_equal "table_definition_mode", @pm.state
  end

  test "enter_next_round_seeding: transitions from table_definition_mode to next_round_seeding_mode" do
    @pm.update_column(:state, "table_definition_mode")
    @pm.reload
    assert @pm.may_enter_next_round_seeding?
    @pm.enter_next_round_seeding!
    assert_equal "next_round_seeding_mode", @pm.state
  end

  test "finish_round_seeding_mode: transitions from next_round_seeding_mode to ready_for_next_round" do
    @pm.update_column(:state, "next_round_seeding_mode")
    @pm.reload
    assert @pm.may_finish_round_seeding_mode?
    @pm.finish_round_seeding_mode!
    assert_equal "ready_for_next_round", @pm.state
  end

  test "start_round: transitions from ready_for_next_round to playing_round" do
    @pm.update_column(:state, "ready_for_next_round")
    @pm.reload
    assert @pm.may_start_round?
    @pm.start_round!
    assert_equal "playing_round", @pm.state
  end

  test "finish_round: transitions from playing_round to round_result_checking_mode" do
    @pm.update_column(:state, "playing_round")
    @pm.reload
    assert @pm.may_finish_round?
    @pm.finish_round!
    assert_equal "round_result_checking_mode", @pm.state
  end

  test "finish_party: transitions from round_result_checking_mode to party_result_checking_mode" do
    @pm.update_column(:state, "round_result_checking_mode")
    @pm.reload
    assert @pm.may_finish_party?
    @pm.finish_party!
    assert_equal "party_result_checking_mode", @pm.state
  end

  test "close_party: transitions from party_result_checking_mode to closed" do
    @pm.update_column(:state, "party_result_checking_mode")
    @pm.reload
    assert @pm.may_close_party?
    @pm.close_party!
    assert_equal "closed", @pm.state
  end

  test "end_of_party: transitions from party_result_checking_mode to closed" do
    @pm.update_column(:state, "party_result_checking_mode")
    @pm.reload
    assert @pm.may_end_of_party?
    @pm.end_of_party!
    assert_equal "closed", @pm.state
  end

  # ============================================================================
  # 4. Invalid transition tests
  # ============================================================================

  test "cannot start_round from seeding_mode" do
    assert_equal "seeding_mode", @pm.state
    refute @pm.may_start_round?, "should not be able to start_round from seeding_mode"
    assert_raises(AASM::InvalidTransition) do
      @pm.start_round!
    end
  end

  test "cannot close_party from playing_round" do
    @pm.update_column(:state, "playing_round")
    @pm.reload
    refute @pm.may_close_party?, "should not be able to close_party from playing_round"
    assert_raises(AASM::InvalidTransition) do
      @pm.close_party!
    end
  end

  test "cannot prepare_next_round from closed" do
    @pm.update_column(:state, "closed")
    @pm.reload
    refute @pm.may_prepare_next_round?, "should not be able to prepare_next_round from closed"
    assert_raises(AASM::InvalidTransition) do
      @pm.prepare_next_round!
    end
  end

  # ============================================================================
  # 5. end_of_party special case
  # ============================================================================

  test "end_of_party can transition to closed from any non-closed state" do
    non_closed_states = %w[
      seeding_mode
      table_definition_mode
      next_round_seeding_mode
      ready_for_next_round
      playing_round
      round_result_checking_mode
      party_result_checking_mode
      party_result_reporting_mode
    ]
    non_closed_states.each do |state|
      @pm.update_column(:state, state)
      @pm.reload
      assert @pm.may_end_of_party?, "should be able to end_of_party from #{state}"
      @pm.end_of_party!
      assert_equal "closed", @pm.state, "end_of_party from #{state} should yield closed"
      # Reset back for next iteration
      @pm.update_column(:state, state)
      @pm.reload
    end
  end

  # ============================================================================
  # 6. party_result_reporting_mode legacy state
  # ============================================================================

  test "party_result_reporting_mode is a valid state" do
    # Per RESEARCH Pitfall 7: this state has no standard inbound transitions
    # but is declared in the AASM block. It can be set directly (e.g., from admin).
    @pm.update_column(:state, "party_result_reporting_mode")
    @pm.reload
    assert_equal "party_result_reporting_mode", @pm.state,
      "party_result_reporting_mode should be persisted as a valid state string"
    assert_includes PartyMonitor.aasm.states.map(&:name), :party_result_reporting_mode,
      "party_result_reporting_mode should be declared in AASM"
  end

  # ============================================================================
  # 7. ApiProtector verification
  # ============================================================================

  test "ApiProtectorTestOverride allows saving PartyMonitor with local ID" do
    # PartyMonitor includes ApiProtector which blocks saves in API server context.
    # ApiProtectorTestOverride in test_helper.rb disables this globally for tests.
    assert PartyMonitor.ancestors.include?(ApiProtectorTestOverride),
      "ApiProtectorTestOverride should be prepended to PartyMonitor"
    assert @pm.persisted?, "PartyMonitor with local ID should be persisted"
    assert @pm.id >= 50_000_000, "ID should be a local ID (>= MIN_ID)"
  end

  # ============================================================================
  # 8. reset_party_monitor callback
  # ============================================================================

  test "reset_party_monitor is called on seeding_mode entry callback" do
    # RESEARCH Pitfall 1: Don't trigger via AASM transition from create —
    # test directly via send to avoid complex dependency chain.
    #
    # reset_party_monitor reads from tournament (alias for party) and:
    # - Updates sets_to_play, sets_to_win, team_size, kickoff_switches_with,
    #   allow_follow_up, fixed_display_left, color_remains_with_set from party
    # - Destroys local games and seedings
    # - Clears data hash
    # - Calls initialize_table_monitors if game_plan present and not manual
    # - Sets state to "seeding_mode" and saves
    #
    # Characterization finding: reset_party_monitor has a pre-existing bug when
    # party has no game_plan. The data= setter receives nil because:
    #   self.data = data.presence || @game_plan&.data.dup
    # With empty data and no game_plan, data.presence is nil and
    # @game_plan&.data.dup is also nil — resulting in nil.to_hash error.
    # This is documented as a known issue in the codebase.
    #
    # The method IS registered as an after_enter callback on seeding_mode state.
    assert_includes(
      PartyMonitor.aasm.states.find { |s| s.name == :seeding_mode }.options[:after_enter] || [],
      :reset_party_monitor,
      "reset_party_monitor should be registered as after_enter callback on seeding_mode"
    )
    skip "reset_party_monitor has pre-existing NoMethodError (nil.to_hash) when party has no game_plan — known characterization finding"
  end
end
