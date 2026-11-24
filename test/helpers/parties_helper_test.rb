# frozen_string_literal: true

require "test_helper"

# Phase 38.7 Plan 07 — Unit tests for PartiesHelper#tiebreak_indicator (D-12).
#
# The helper renders a localized "(Stechen <Player>)" suffix in the
# Spielbericht-PDF (`parties/_spielbericht.html.erb`) when
# `game.data['ba_results']['TiebreakWinner']` is 1 (player A) or 2 (player B).
# Per the plan's threat model:
#   - T-38.7-07-01: Player shortname is rendered via i18n `t` helper, which
#     auto-escapes (no html_safe).
#   - T-38.7-07-02: Defense-in-depth — invalid TiebreakWinner values must
#     return empty string (forged values from a tampered DB row must not
#     break PDF rendering).
#
# `row[:game]` in `_spielbericht.html.erb` is a `PartyGame` instance with
# `player_a` / `player_b` belongs_to `Player` associations. We use a
# fixture-loaded Player + a non-persisted `PartyGame.new` so the helper
# tests do not depend on a `games.yml` fixture (which does not exist) and
# do not touch the DB.
class PartiesHelperTest < ActionView::TestCase
  include PartiesHelper

  setup do
    @player_a = players(:jaspers)
    @player_b = players(:cho)
    # PartyGame is the model passed to the helper from `_spielbericht.html.erb`
    # (via `row[:game]`). We avoid `save!` so LocalProtector doesn't apply.
    @game = PartyGame.new(player_a: @player_a, player_b: @player_b)
  end

  # ---- T1: TiebreakWinner=1 → Player A's shortname ----
  test "tiebreak_indicator returns localized 'Stechen <PlayerA>' when TiebreakWinner=1" do
    @game.data = {"ba_results" => {"TiebreakWinner" => 1}}
    result = tiebreak_indicator(@game)

    assert_match(/Stechen|Tiebreak/, result,
      "must include the localized 'Stechen' (DE) or 'Tiebreak' (EN) word")
    expected_role = @player_a.shortname.presence || @player_a.fullname.to_s
    assert_match(expected_role, result.to_s,
      "must include playera's shortname/fullname (#{expected_role.inspect})")
    assert result.start_with?(" "),
      "must have leading space so it appends cleanly to the score column"
  end

  # ---- T2: TiebreakWinner=2 → Player B's shortname ----
  test "tiebreak_indicator returns localized 'Stechen <PlayerB>' when TiebreakWinner=2" do
    @game.data = {"ba_results" => {"TiebreakWinner" => 2}}
    result = tiebreak_indicator(@game)

    expected_role = @player_b.shortname.presence || @player_b.fullname.to_s
    assert_match(expected_role, result.to_s,
      "must include playerb's shortname/fullname (#{expected_role.inspect})")
  end

  # ---- T3: TiebreakWinner key absent → empty string (legacy regression) ----
  test "tiebreak_indicator returns empty string when TiebreakWinner key is absent" do
    @game.data = {"ba_results" => {"Sets1" => 1, "Sets2" => 1}}
    assert_equal "", tiebreak_indicator(@game),
      "legacy non-tiebreak rendering must be preserved (no suffix)"
  end

  # ---- T4: nil game → empty string (defensive) ----
  test "tiebreak_indicator returns empty string for nil game (defensive)" do
    assert_equal "", tiebreak_indicator(nil),
      "nil game must not raise (helper is called inside ERB safe-navigation path)"
  end

  # ---- T5: Invalid TiebreakWinner value → empty string (defense-in-depth, T-38.7-07-02) ----
  test "tiebreak_indicator returns empty string for invalid TiebreakWinner values (defense-in-depth)" do
    @game.data = {"ba_results" => {"TiebreakWinner" => 99}}
    assert_equal "", tiebreak_indicator(@game),
      "forged/invalid TiebreakWinner integers must not render a suffix"

    @game.data = {"ba_results" => {"TiebreakWinner" => "X"}}
    assert_equal "", tiebreak_indicator(@game),
      "forged string TiebreakWinner values must not render a suffix"
  end

  # ---- Spielbericht ohne GamePlan (BillardArea, NuLiga, einzelne ClubCloud-Ligen) ----
  def game_with(data) = PartyGame.new(data: data)

  test "spielbericht_ergebnis liest NuLiga-String, CC- und BA-Hash" do
    assert_equal "6:5", spielbericht_ergebnis(game_with("result" => "6:5", "match_points" => "1:0"))
    assert_equal "2:1", spielbericht_ergebnis(game_with("result" => {"Ergebnis:" => "2:1", "Punkte:" => "1:0"}))
    assert_equal "5 : 3", spielbericht_ergebnis(game_with("result" => {"Ergebnis" => "5 : 3"}))
    assert_equal "61 : 65 / 20 : 21", spielbericht_ergebnis(game_with("result" => {"Bälle:" => "61 : 65", "Aufn.:" => "20 : 21"}))
    assert_nil spielbericht_ergebnis(game_with({}))
    assert_nil spielbericht_ergebnis(nil)
  end

  test "spielbericht_details ohne Ergebnis-Schlüssel, leer bei String-Ergebnis" do
    assert_equal({"Punkte:" => "1:0"}, spielbericht_details(game_with("result" => {"Ergebnis:" => "2:1", "Punkte:" => "1:0"})))
    assert_equal({}, spielbericht_details(game_with("result" => {"Ergebnis" => "5 : 3"})))
    assert_equal({}, spielbericht_details(game_with("result" => "6:5")))
  end

  test "spielbericht_spielpunkte aus NuLiga match_points oder CC Punkte:, sonst nil" do
    assert_equal [1, 0], spielbericht_spielpunkte(game_with("result" => "6:5", "match_points" => "1:0"))
    assert_equal [0, 1], spielbericht_spielpunkte(game_with("result" => {"Ergebnis:" => "0:2", "Punkte:" => "0:1"}))
    assert_nil spielbericht_spielpunkte(game_with("result" => {"Ergebnis" => "5 : 3"}))
  end

  test "ohne GamePlan: Zeilen sind die Einzelspiele nach seqno, Endstand aus Spielpunkten" do
    league = League.new(name: "Kreisliga")
    party = Party.new(league: league)
    party.party_games.build(seqno: 2, discipline: disciplines(:branch_pool), data: {"result" => "3:8", "match_points" => "0:1"})
    party.party_games.build(seqno: 1, data: {"result" => "6:5", "match_points" => "1:0"})
    party.party_games.build(seqno: 3, data: {"result" => "7:3", "match_points" => "1:0"})

    rows = spielbericht_rows(party)

    assert_equal [1, 2, 3, nil], rows.map { |r| r[:game]&.seqno }
    assert_equal "Gesamtsumme", rows.last[:type]
    assert_equal disciplines(:branch_pool).name, rows[1][:type]
    assert_equal [2, 1], spielbericht_endstand_einfach(party)
  end

  test "ohne GamePlan und ohne Spielpunkte (BillardArea): keine Gesamtsumme" do
    party = Party.new(league: League.new(name: "Bezirksliga"))
    party.party_games.build(seqno: 1, data: {"result" => {"Ergebnis" => "5 : 3"}})

    rows = spielbericht_rows(party)

    assert_equal 1, rows.size
    assert_equal "5 : 3", spielbericht_ergebnis(rows.first[:game])
  end
end
