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
end
