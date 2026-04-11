# frozen_string_literal: true

require "test_helper"
require_relative "../../support/party_monitor_test_helper"

class PartyMonitor::ResultProcessorTest < ActiveSupport::TestCase
  include PartyMonitorTestHelper

  self.use_transactional_tests = true

  setup do
    result = create_party_monitor_with_party
    @pm = result[:party_monitor]
    @party = result[:party]
  end

  teardown do
    PartyMonitor.allow_change_tables = nil
  end

  test "initializes with party_monitor reference" do
    rp = PartyMonitor::ResultProcessor.new(@pm)
    assert_instance_of PartyMonitor::ResultProcessor, rp
  end

  test "write_game_result_data is private on ResultProcessor" do
    rp = PartyMonitor::ResultProcessor.new(@pm)
    assert rp.respond_to?(:write_game_result_data, true), "write_game_result_data should be private on ResultProcessor"
    refute rp.respond_to?(:write_game_result_data), "write_game_result_data should not be public"
  end

  test "add_result_to is private on ResultProcessor" do
    rp = PartyMonitor::ResultProcessor.new(@pm)
    assert rp.respond_to?(:add_result_to, true), "add_result_to should be private on ResultProcessor"
    refute rp.respond_to?(:add_result_to), "add_result_to should not be public"
  end

  test "accumulate_results delegates to service and runs without error" do
    assert_nothing_raised { @pm.accumulate_results }
  end

  test "report_result preserves TournamentMonitor.transaction scope" do
    source = File.read(Rails.root.join("app/services/party_monitor/result_processor.rb"))
    assert_match(/TournamentMonitor\.transaction/, source,
      "report_result must use TournamentMonitor.transaction (not PartyMonitor.transaction)")
  end

  test "write_game_result_data is NOT defined on PartyMonitor model" do
    refute @pm.respond_to?(:write_game_result_data, true),
      "write_game_result_data must NOT be on PartyMonitor model"
  end

  test "add_result_to is NOT defined on PartyMonitor model" do
    refute @pm.respond_to?(:add_result_to, true),
      "add_result_to must NOT be on PartyMonitor model"
  end
end
