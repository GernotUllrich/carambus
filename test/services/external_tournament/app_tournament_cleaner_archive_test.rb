# frozen_string_literal: true

require "test_helper"

# Plan 41-01 (Nachtrag), erweitert durch 41-02.
#
# ZWECK: `ARCHIVE_AWARE` an das tatsaechliche Verhalten koppeln. Der Archiv-Endpoint meldet
# den Wert als `durable` an carambus_app — eine Konstante, die man von Hand pflegt, waere
# genau die Angabe, die beim Ausliefern vergessen wird. Dieser Test faellt, wenn Konstante
# und Sweep auseinanderlaufen, und zwar in BEIDE Richtungen.
class AppTournamentCleanerArchiveTest < ActiveSupport::TestCase
  BASE_ID = 56_000_000

  setup do
    @tournament = Tournament.create!(
      id: BASE_ID + 1, title: "Archiv-GC-Test", season: seasons(:current),
      organizer: regions(:nbv), organizer_type: "Region",
      manual_assignment: true, end_date: 1.day.ago,
      data: {"archived_at" => Time.current.iso8601}
    )
  end

  teardown do
    Tournament.where(id: BASE_ID + 1).destroy_all
  end

  def sweep_sees?(tournament)
    ExternalTournament::AppTournamentCleaner
      .send(:new)
      .send(:closed_local_app_tournaments)
      .map(&:id)
      .include?(tournament.id)
  rescue NoMethodError
    # Fallback, falls der Cleaner Klassenmethoden nutzt
    ExternalTournament::AppTournamentCleaner
      .send(:closed_local_app_tournaments)
      .map(&:id)
      .include?(tournament.id)
  end

  test "ARCHIVE_AWARE beschreibt das tatsaechliche Verhalten des Sweeps" do
    seen = sweep_sees?(@tournament)

    if ExternalTournament::AppTournamentCleaner::ARCHIVE_AWARE
      refute seen,
        "ARCHIVE_AWARE ist true, aber der Sweep sammelt das archivierte Turnier trotzdem ein — " \
        "der Endpoint meldet carambus_app dann faelschlich `durable: true`"
    else
      assert seen,
        "ARCHIVE_AWARE ist false, aber der Sweep verschont das archivierte Turnier bereits — " \
        "dann ist die Konstante zu aktualisieren (Plan 41-02), sonst meldet der Endpoint " \
        "unnoetig `durable: false`"
    end
  end

  test "ein nicht archiviertes Turnier im selben Zustand wird immer eingesammelt" do
    @tournament.update!(data: {})
    assert sweep_sees?(@tournament),
      "Die Gegenprobe: ohne Archiv-Markierung muss der Sweep greifen — sonst koennte ein " \
      "zu breiter Filter alles verschonen und der erste Test waere trotzdem gruen"
  end
end
