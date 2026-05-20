# frozen_string_literal: true

require "test_helper"

# Plan 17-02: LocalTournamentCreator — lokales App-Turnier ohne Plan + Lean-TournamentMonitor.
module ExternalTournament
  class LocalTournamentCreatorTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @location = locations(:one)
    end

    teardown do
      Tournament.where(external_id: %w[app-tourn-1]).each do |t|
        t.tournament_monitor&.destroy
        t.destroy
      end
    end

    test "legt lokales Turnier ohne Plan an, mit Lean-Monitor, idempotent" do
      result = LocalTournamentCreator.new(region: @nbv, payload: {
        external_id: "app-tourn-1",
        title: "App Cup",
        location: {id: @location.id}
      }).call

      assert result.created?
      t = result.tournament
      assert_equal "app-tourn-1", t.external_id
      assert_nil t.tournament_plan_id, "kein TournamentPlan"
      assert t.manual_assignment, "manual_assignment=true"
      assert_equal @nbv.id, t.region_id
      assert_equal "Region", t.organizer_type
      assert_equal @nbv.id, t.organizer_id
      assert_equal seasons(:current).id, t.season_id, "season=current (2025/2026)"
      assert_equal @location.id, t.location_id
      assert t.tournament_monitor.present?, "schlanker TournamentMonitor erstellt (kein Crash ohne Plan)"

      again = LocalTournamentCreator.new(region: @nbv, payload: {external_id: "app-tourn-1", title: "App Cup"}).call
      assert_not again.created?, "2. Aufruf idempotent"
      assert_equal t.id, again.tournament.id
      assert_equal 1, Tournament.where(region_id: @nbv.id, external_id: "app-tourn-1").count
    end

    test "raises ohne external_id" do
      assert_raises(ArgumentError) do
        LocalTournamentCreator.new(region: @nbv, payload: {title: "x"}).call
      end
    end
  end
end
