# frozen_string_literal: true

require "test_helper"
require_relative "../support/party_monitor_test_helper"

# Characterization tests for Party (216 lines).
# Per D-06: no AASM — test associations, computed properties, and boolean flags.
class PartyTest < ActiveSupport::TestCase
  include PartyMonitorTestHelper

  def setup
    @party = parties(:party_one)
  end

  # --- Association tests ---

  test "belongs to league" do
    assert_not_nil @party.league
    assert_instance_of League, @party.league
  end

  test "belongs to league_team_a" do
    assert_not_nil @party.league_team_a
    assert_instance_of LeagueTeam, @party.league_team_a
  end

  test "belongs to league_team_b" do
    assert_not_nil @party.league_team_b
    assert_instance_of LeagueTeam, @party.league_team_b
  end

  test "has many seedings" do
    assert @party.respond_to?(:seedings)
  end

  # --- Computed properties ---

  test "name returns 'TeamA - TeamB' format" do
    # Party#name delegates to league_team_a.name and league_team_b.name
    assert_includes @party.name, "Team Alpha"
    assert_includes @party.name, "Team Beta"
    assert_includes @party.name, " - "
    assert_equal "Team Alpha - Team Beta", @party.name
  end

  # --- intermediate_result (Phase 47-02: rechnet [team_a, team_b] aus game.data["ba_results"]) ---

  test "intermediate_result is [0, 0] when there are no played-game rows" do
    # party_one's PartyMonitor (Fixture) trägt leeres data → keine rows → [0, 0].
    assert_equal [0, 0], @party.intermediate_result
  end

  test "intermediate_result tallies game points from ba_results (Sets1 = team_a)" do
    # 3 Pool-Spiele: team_a (Sets1) gewinnt #1 und #3, team_b #2; Default win=1 → [2, 1].
    res = build_party_with_results([
      {seqno: 1, type: "9-Ball", sets: 7, sets1: 7, sets2: 5},
      {seqno: 2, type: "8-Ball", sets: 7, sets1: 4, sets2: 7},
      {seqno: 3, type: "10-Ball", sets: 7, sets1: 7, sets2: 6}
    ])
    assert_equal [2, 1], res[:party].intermediate_result
  end

  test "intermediate_result defaults win=1/draw=0/lost=0 when game_points config is nil" do
    # Phase-47-01-Befund: manche Parties tragen game_points {win:nil,...} → Default greift.
    res = build_party_with_results([
      {seqno: 1, type: "9-Ball", sets: 7, sets1: 7, sets2: 3,
       game_points: {"win" => nil, "draw" => nil, "lost" => nil}}
    ])
    assert_equal [1, 0], res[:party].intermediate_result
  end

  test "intermediate_result honors explicit game_points weights" do
    res = build_party_with_results([
      {seqno: 1, type: "9-Ball", sets: 7, sets1: 7, sets2: 1,
       game_points: {"win" => 2, "draw" => 1, "lost" => 0}}
    ])
    assert_equal [2, 0], res[:party].intermediate_result
  end

  test "intermediate_result ignores unplayed games and non-game rows" do
    res = build_party_with_results([
      {seqno: 1, type: "9-Ball", sets: 7, sets1: 7, sets2: 2},          # gespielt → team_a
      {seqno: 2, type: "8-Ball", sets: 7, sets1: 3, sets2: 6, played: false} # kein Game → 0
    ])
    party = res[:party]
    pm = party.party_monitor
    pm.update!(data: {"rows" => pm.data["rows"] + [{"type" => "Neue Runde", "r_no" => 2}]})
    party.reload
    assert_equal [1, 0], party.intermediate_result
  end

  test "party_nr assigns party_no if blank and returns it" do
    # party_one has no party_no set (nil). party_nr will assign and save it.
    # The method sets party_no = cc_id - first_cc_id + 1 where first_cc_id is the smallest cc_id in the league.
    # party_one.cc_id = 201, first cc_id in league = 201 (party_one itself), so party_no = 201 - 201 + 1 = 1.
    assert_nil @party.party_no
    result = @party.party_nr
    assert_kind_of Integer, result
    assert result > 0
    # The record should now have party_no persisted
    @party.reload
    assert_not_nil @party.party_no
  end

  # --- Boolean flags ---

  test "manual_assignment returns true" do
    # Per RESEARCH: hardcoded to return true regardless of column value
    assert_equal true, @party.manual_assignment
  end

  test "allow_follow_up responds to boolean" do
    assert @party.respond_to?(:allow_follow_up)
  end

  test "continuous_placements responds to boolean" do
    assert @party.respond_to?(:continuous_placements)
  end

  # --- Data access ---

  test "data stores result hash" do
    # data is serialized as JSON into a Hash
    assert_kind_of Hash, @party.data
    assert @party.data.key?("result")
    assert_equal "3:1", @party.data["result"]
  end
end
