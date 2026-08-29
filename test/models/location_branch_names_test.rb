# frozen_string_literal: true

require "test_helper"

# `Location#branch_names` — die Sparten, die an den Tischen eines Spielorts gespielt werden.
#
# Grundlage des Kalender-Links am Scoreboard. MEHRERE je Ort, weil eine Tischart mehrere
# Sparten traegt: auf dem kleinen Billard und dem Match Billard wird sowohl Karambol als auch
# Kegel gespielt (Betreiber-Auskunft 2026-08-29).
#
# ⚠️ Die Tischarten werden hier explizit angelegt. Der Fixture-TableKind heisst "Karambol" —
# ein Name, den es in `TableKind::TABLE_KINDS` gar nicht gibt (real sind es "Match Billard",
# "Small Billard", "Pool", ...). Er taugt deshalb nicht als Grundlage dieser Tests.
class LocationBranchNamesTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @location.tables.destroy_all
    @next_table_id = 50_900_000
  end

  def table_kind!(name)
    TableKind.find_or_create_by!(name: name) { |tk| tk.short = name.first(2) }
  end

  def tisch!(kind_name)
    @next_table_id += 1
    Table.create!(id: @next_table_id, name: "Tisch #{@next_table_id}",
      location: @location, table_kind: table_kind!(kind_name))
  end

  # Der Fall BC Wedel: 4x Match, 4x Small Billard.
  test "ein Karambol-Ort traegt auch Kegel" do
    tisch!("Match Billard")
    tisch!("Small Billard")

    assert_equal ["Karambol", "Kegel"], @location.reload.branch_names,
      "kleines und Match Billard sind beide doppelt belegt"
  end

  test "Half Match Billard traegt nur Karambol" do
    tisch!("Half Match Billard")

    assert_equal ["Karambol"], @location.reload.branch_names,
      "dort wurde Kegel nicht genannt"
  end

  # Der Fall Pinneberg: 16 Pool, 6 Snooker.
  test "ein Pool-und-Snooker-Ort schraenkt auf genau diese beiden ein" do
    tisch!("Pool")
    tisch!("Snooker")

    assert_equal ["Pool", "Snooker"], @location.reload.branch_names,
      "Karambol und Kegel fallen weg — das ist eine sinnvolle Einschraenkung"
  end

  test "ein reiner Pool-Ort liefert nur Pool" do
    tisch!("Pool")

    assert_equal ["Pool"], @location.reload.branch_names
  end

  test "ein Ort ohne Tische liefert nichts" do
    assert_empty @location.reload.branch_names,
      "ein unvollstaendig gepflegter Ort darf nicht auf Sparten filtern, die er nicht kennt"
  end

  test "nur unbekannte Tischarten liefern nichts" do
    tisch!("Weltraumbillard")

    assert_empty @location.reload.branch_names
  end

  test "eine unbekannte Tischart wird uebergangen statt zu werfen" do
    tisch!("Match Billard")
    tisch!("Weltraumbillard")

    assert_equal ["Karambol", "Kegel"], @location.reload.branch_names
  end

  # Sonst filterte der Parameter nichts weg und der Chip waere nur Laerm.
  test "ein Ort, der alle Sparten abdeckt, liefert nichts" do
    tisch!("Pool")
    tisch!("Snooker")
    tisch!("Small Billard")

    assert_empty @location.reload.branch_names,
      "Pool + Snooker + Karambol + Kegel = alles, also keine Einschraenkung"
  end

  # Sonst wechselte der `branch`-Parameter des Links seinen Wortlaut je nach Tischsortierung.
  test "die Reihenfolge haengt nicht an der Reihenfolge der Tische" do
    tisch!("Snooker")
    tisch!("Pool")
    erste = @location.reload.branch_names

    @location.tables.destroy_all
    tisch!("Pool")
    tisch!("Snooker")

    assert_equal erste, @location.reload.branch_names
  end
end
