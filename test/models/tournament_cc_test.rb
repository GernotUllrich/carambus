# frozen_string_literal: true

require "test_helper"

# Plan 14-G.7 / Task 3 / F11: TournamentCc#effective_season-Helper-Tests.
# Verifies Backfill-Verhalten: primary `season`-Field, fallback aus tournament_start
# (Juli-Cutoff via Season.season_from_date).
class TournamentCcTest < ActiveSupport::TestCase
  test "effective_season returns season when present" do
    tcc = TournamentCc.new(season: "2025/2026", tournament_start: Date.new(2025, 9, 15))
    assert_equal "2025/2026", tcc.effective_season
  end

  test "effective_season falls back to season derived from tournament_start when season nil" do
    season = Season.find_by(name: "2025/2026") ||
      Season.find_by(name: "#{Date.today.year}/#{Date.today.year + 1}")
    skip "Season fixture not available" unless season

    tcc = TournamentCc.new(season: nil, tournament_start: season.name.split("/").first.to_i.then { |y| Date.new(y, 10, 1) })
    derived = Season.season_from_date(tcc.tournament_start.to_date)
    skip "Could not derive season for fixture date" unless derived

    assert_equal derived.name, tcc.effective_season
  end

  test "effective_season returns nil when both season and tournament_start are nil" do
    tcc = TournamentCc.new(season: nil, tournament_start: nil)
    assert_nil tcc.effective_season
  end
end
