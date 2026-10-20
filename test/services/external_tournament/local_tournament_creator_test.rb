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
      Tournament.where(external_id: %w[app-tourn-1 app-tourn-md]).each do |t|
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

    # GP Biathlon 17./18.10.2026: der Mitternachtslauf gab die Tische des zweitaegigen
    # App-Turniers frei, weil es kein end_date hatte.
    test "end_date als Datum meint das Tagesende; Mitternachtslauf davor laesst das Turnier stehen" do
      travel_to Time.zone.parse("2026-10-17 10:00") do
        t = LocalTournamentCreator.new(region: @nbv, payload: {external_id: "app-tourn-md", end_date: "2026-10-18"}).call.tournament
        assert_equal Time.zone.parse("2026-10-18").end_of_day.to_i, t.end_date.to_i
      end
      t = Tournament.find_by(external_id: "app-tourn-md")
      releaser = TableReleaser.new
      travel_to(Time.zone.parse("2026-10-18 00:01")) { assert releaser.send(:still_running?, t), "Nacht vor Tag 2: laeuft noch" }
      travel_to(Time.zone.parse("2026-10-19 00:01")) { refute releaser.send(:still_running?, t), "Nacht nach Tag 2: vorbei" }
    end

    test "end_date wird beim idempotenten Aufruf nachgereicht; ohne end_date bleibt es nil" do
      t = LocalTournamentCreator.new(region: @nbv, payload: {external_id: "app-tourn-md"}).call.tournament
      assert_nil t.end_date, "Gegenprobe: ohne Angabe kein end_date (Verhalten wie bisher)"

      again = LocalTournamentCreator.new(region: @nbv, payload: {external_id: "app-tourn-md", end_date: "2026-10-18T22:00:00+02:00"}).call
      assert_not again.created?
      assert_equal Time.zone.parse("2026-10-18T22:00:00+02:00").to_i, again.tournament.reload.end_date.to_i
    end

    test "ungueltiges end_date wird abgelehnt" do
      assert_raises(ArgumentError) do
        LocalTournamentCreator.new(region: @nbv, payload: {external_id: "app-tourn-md", end_date: "morgen"}).call
      end
    end
  end
end
