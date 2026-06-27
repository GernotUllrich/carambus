# frozen_string_literal: true

require "test_helper"

# Characterization tests for Party (216 lines).
# Per D-06: no AASM — test associations, computed properties, and boolean flags.
class PartyTest < ActiveSupport::TestCase
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

  test "intermediate_result returns [0, 0]" do
    # CHARACTERIZATION / BASELINE für Phase 47-02 (intermediate_result-Fix).
    # party.rb:187 schließt die Methode mit `return [0, 0]` kurz (Code darunter tot).
    # Folge: das echte gescrapte Mannschaftsergebnis wird IGNORIERT —
    # @party.data["result"] ist "3:1", intermediate_result liefert trotzdem [0, 0].
    assert_equal "3:1", @party.data["result"]
    assert_equal [0, 0], @party.intermediate_result
    # Diese [0,0]-Quelle speist ZWEI Stellen im party_monitor_reflex:
    #   - finish_round (reflex:222): points_l == points_r → loopt immer zu prepare_next_round!
    #   - close_party  (reflex:370): game_points/match_points werden immer "0:0"/Remis
    # Wenn 47-02 den Kurzschluss durch die echte Ergebnisrechnung ersetzt,
    # MUSS diese Assertion bewusst angepasst werden (Safety-Net-Marker).
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
