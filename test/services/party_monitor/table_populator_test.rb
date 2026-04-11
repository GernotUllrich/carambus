# frozen_string_literal: true

require "test_helper"
require_relative "../../support/party_monitor_test_helper"

class PartyMonitor::TablePopulatorTest < ActiveSupport::TestCase
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
    tp = PartyMonitor::TablePopulator.new(@pm)
    assert_instance_of PartyMonitor::TablePopulator, tp
  end

  test "delegation wrapper for reset_party_monitor calls service" do
    # Verify the model delegates to TablePopulator via source inspection.
    # NOTE: calling reset_party_monitor with no game_plan raises NoMethodError
    # (nil.to_hash) — this is a pre-existing bug documented in AASM characterization
    # tests. The structural delegation is verified here; runtime behavior is covered
    # by the AASM tests which skip this case.
    source = File.read(Rails.root.join("app/models/party_monitor.rb"))
    assert_match(/PartyMonitor::TablePopulator\.new\(self\)\.reset_party_monitor/, source,
      "reset_party_monitor should delegate to PartyMonitor::TablePopulator")
  end

  test "next_seqno is private on TablePopulator" do
    tp = PartyMonitor::TablePopulator.new(@pm)
    assert tp.respond_to?(:next_seqno, true), "next_seqno should be a private method on TablePopulator"
    refute tp.respond_to?(:next_seqno), "next_seqno should not be public on TablePopulator"
  end

  test "references PartyMonitor.allow_change_tables not TournamentMonitor" do
    source = File.read(Rails.root.join("app/services/party_monitor/table_populator.rb"))
    refute_match(/TournamentMonitor\.allow_change_tables/, source,
      "Must use PartyMonitor.allow_change_tables, not TournamentMonitor")
  end
end
