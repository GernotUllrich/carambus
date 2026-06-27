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

  # --- record_game_result! (Phase 48-01: Direct-to-Game zeilenweise Direkteingabe) ---

  test "record_game_result! schreibt ba_results (Spieler1/Sets1 = team_a) + ended_at" do
    setup = build_party_for_direct_entry([{seqno: 1, type: "9-Ball", sets: 7}], player_a_ba: 1001, player_b_ba: 2002)
    party = setup[:party]
    row = party.party_monitor.data["rows"].first

    game = party.record_game_result!(row: row, sc1: "7", sc2: "4")
    game.reload
    ba = game.data["ba_results"]

    assert_equal 1001, ba["Spieler1"]
    assert_equal 2002, ba["Spieler2"]
    assert_equal 7, ba["Sets1"]
    assert_equal 4, ba["Sets2"]
    assert_equal 7, ba["Ergebnis1"]
    assert_equal 4, ba["Ergebnis2"]
    assert_not_nil game.ended_at
  end

  test "record_game_result! 14.1: Ergebnis/Aufnahmen/Höchstserie, KEINE Sets bei sets<=1" do
    setup = build_party_for_direct_entry([{seqno: 1, type: "14/1e", sets: 1}], player_a_ba: 1001, player_b_ba: 2002)
    party = setup[:party]
    row = party.party_monitor.data["rows"].first

    game = party.record_game_result!(row: row, sc1: "80", sc2: "55", in1: "20", in2: "20", br1: "15", br2: "9")
    ba = game.reload.data["ba_results"]

    assert_equal 80, ba["Ergebnis1"]
    assert_equal 55, ba["Ergebnis2"]
    assert_nil ba["Sets1"] # sets<=1 → keine Sets-Keys
    assert_equal 20, ba["Aufnahmen1"]
    assert_equal 15, ba["Höchstserie1"]
    assert_equal 9, ba["Höchstserie2"]
  end

  test "intermediate_result rechnet aus per record_game_result! direkt erfassten Ergebnissen" do
    setup = build_party_for_direct_entry([
      {seqno: 1, type: "9-Ball", sets: 7},
      {seqno: 2, type: "8-Ball", sets: 7},
      {seqno: 3, type: "10-Ball", sets: 7}
    ], player_a_ba: 1001, player_b_ba: 2002)
    party = setup[:party]
    rows = party.party_monitor.data["rows"]

    party.record_game_result!(row: rows[0], sc1: "7", sc2: "5") # team_a
    party.record_game_result!(row: rows[1], sc1: "4", sc2: "7") # team_b
    party.record_game_result!(row: rows[2], sc1: "7", sc2: "6") # team_a
    party.reload

    # identisch zum ba_results-Pfad aus 47-02: Default win=1 → [2, 1]
    assert_equal [2, 1], party.intermediate_result
  end

  test "record_game_result! überspringt leere Eingabe (kein ended_at, nil-Return)" do
    setup = build_party_for_direct_entry([{seqno: 1, type: "9-Ball", sets: 7}], player_a_ba: 1001, player_b_ba: 2002)
    party = setup[:party]
    row = party.party_monitor.data["rows"].first

    assert_nil party.record_game_result!(row: row, sc1: "", sc2: "")
    assert_nil party.games.find_by(gname: "1-9-Ball").ended_at
    assert_equal [0, 0], party.intermediate_result # ungespielt → 0
  end

  private

  # Baut eine Party mit PartyMonitor-Rows (player_a/player_b + seqno/type/sets/r_no) + LEEREN
  # Games (gname, ohne ba_results/ended_at) + zwei echten Players mit ba_id — für die
  # Charakterisierung von Party#record_game_result! (Phase 48-01). KEIN echter Lauf.
  def build_party_for_direct_entry(game_specs, player_a_ba:, player_b_ba:)
    result = create_party_monitor_with_party
    party = result[:party]
    party_monitor = result[:party_monitor]
    base = party.id

    player_a = Player.create!(id: base + 10, ba_id: player_a_ba, lastname: "Heim", firstname: "A")
    player_b = Player.create!(id: base + 11, ba_id: player_b_ba, lastname: "Gast", firstname: "B")

    rows = game_specs.map do |s|
      {
        "seqno" => s[:seqno], "type" => s[:type], "sets" => s.fetch(:sets, 1),
        "r_no" => s.fetch(:r_no, 1),
        "player_a" => player_a.id, "player_b" => player_b.id
      }
    end
    party_monitor.update!(data: {"rows" => rows})

    game_specs.each do |s|
      party.games.create!(gname: "#{s[:seqno]}-#{s[:type]}", seqno: s[:seqno])
    end
    party.reload
    {party: party, party_monitor: party_monitor, player_a: player_a, player_b: player_b}
  end
end
