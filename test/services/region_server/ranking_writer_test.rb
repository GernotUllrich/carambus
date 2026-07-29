# frozen_string_literal: true

require "test_helper"

# Plan 36-01: Vorbefuellung und Schreibschicht der Ranglisten-Erfassung.
#
# Die beiden Tests, an denen am meisten haengt: "gescrapte Rangliste bleibt unangetastet" (ohne ihn
# koennte eine Fehlbedienung CC-Ergebnisse loeschen) und "GD wird als Float gespeichert" (ein
# Integer schnitte in carambus.rake:765 still ab und faelschte die Regionalrangliste).
class RegionServer::RankingWriterTest < ActiveSupport::TestCase
  setup do
    @tournament = tournaments(:local)
    @tournament.update_column(:region_id, regions(:nbv).id)
    @anna = Player.create!(lastname: "ANNA", firstname: "Anna", fl_name: "A. Anna", dbu_nr: 311_111)
    @bodo = Player.create!(lastname: "BODO", firstname: "Bodo", fl_name: "B. Bodo", dbu_nr: 322_222)
    @seeding_a = Seeding.create!(tournament: @tournament, player: @anna, position: 1)
    @seeding_b = Seeding.create!(tournament: @tournament, player: @bodo, position: 2)
  end

  def writer
    RegionServer::RankingWriter.new(tournament: @tournament)
  end

  # Die Disziplin-Fixtures tragen keine Hierarchie, `root` ist dort also die Disziplin selbst.
  # Fuer den G/V-Vorschlag braucht es einen Root, den das Schema kennt.
  def switch_to_pool
    pool = Discipline.create!(name: "Pool")
    achtball = Discipline.create!(name: "8-Ball Testzweig", super_discipline: pool)
    @tournament.update_column(:discipline_id, achtball.id)
    @tournament.reload
  end

  # Ein Spiel ueber die Schwesterschicht aus 35-03 — dieselbe Quelle, aus der die Seite spaeter
  # vorbefuellt. Ein handgebautes Game wuerde die Kette nicht abbilden.
  def record_game(seqno:, a_result:, b_result:, a_innings: 20, b_innings: 20, a_hs: 5, b_hs: 4)
    RegionServer::GameResultWriter.new(
      tournament: @tournament,
      gname: "Gruppe A",
      seqno: seqno,
      ended_at: Time.zone.local(2026, 10, 10, 12, 0),
      participations: [
        {player: @anna, result: a_result, innings: a_innings, hs: a_hs},
        {player: @bodo, result: b_result, innings: b_innings, hs: b_hs}
      ]
    ).call
  end

  # --- AC-2: Vorbefuellung ----------------------------------------------------

  test "ohne erfasste Spiele gibt es keine Vorschlaege" do
    suggestions = writer.suggestions

    assert_equal({}, suggestions[@seeding_a.id])
    assert_equal({}, suggestions[@seeding_b.id])
  end

  test "Baelle und Aufnahmen werden summiert, HS als Maximum vorgeschlagen" do
    record_game(seqno: 1, a_result: 100, b_result: 80, a_innings: 25, b_innings: 25, a_hs: 9)
    record_game(seqno: 2, a_result: 60, b_result: 90, a_innings: 15, b_innings: 15, a_hs: 14)

    row = writer.suggestions[@seeding_a.id]

    assert_equal 160, row["Bälle"]
    assert_equal 40, row["Aufn"]
    assert_equal 14, row["HS"], "HS ist das Maximum, nicht die Summe"
  end

  test "Rang und Punkte werden nie vorgeschlagen" do
    record_game(seqno: 1, a_result: 100, b_result: 80)

    row = writer.suggestions[@seeding_a.id]

    assert_not row.key?("Rang"), "der Platz traegt die Turnierlogik"
    assert_not row.key?("Punkte"), "die Punkte tragen die Serienlogik"
  end

  test "Siege und Niederlagen werden bei Pool abgeleitet" do
    switch_to_pool
    record_game(seqno: 1, a_result: 7, b_result: 3)
    record_game(seqno: 2, a_result: 2, b_result: 7)
    record_game(seqno: 3, a_result: 7, b_result: 5)

    assert_equal 2, writer.suggestions[@seeding_a.id]["G"]
    assert_equal 1, writer.suggestions[@seeding_a.id]["V"]
    assert_equal 1, writer.suggestions[@seeding_b.id]["G"]
    assert_equal 2, writer.suggestions[@seeding_b.id]["V"]
  end

  test "Gleichstand zaehlt weder als Sieg noch als Niederlage" do
    switch_to_pool
    record_game(seqno: 1, a_result: 5, b_result: 5)

    assert_equal 0, writer.suggestions[@seeding_a.id]["G"]
    assert_equal 0, writer.suggestions[@seeding_a.id]["V"]
  end

  # --- AC-3: Schreiben --------------------------------------------------------

  test "die erfassten Werte landen in der gelesenen Struktur" do
    result = writer.call(@seeding_a.id => {"Rang" => "1", "Bälle" => "160", "Aufn" => "40", "HS" => "14",
                                           "BED" => "1,250", "Punkte" => "6"})

    assert_equal 1, result.written
    entry = @seeding_a.reload.data.dig("result", "Gesamtrangliste")

    assert_equal 1, entry["Rang"]
    assert_equal 160, entry["Bälle"]
    assert_equal 40, entry["Aufn"]
    assert_equal 6, entry["Punkte"]
  end

  test "die Provenienz-Marke wird gesetzt" do
    writer.call(@seeding_a.id => {"Rang" => "1", "Bälle" => "10", "Aufn" => "10"})

    assert_equal "carambus", @seeding_a.reload.data["result_source"]
  end

  test "Name und Verein kommen aus dem Seeding, nicht aus dem Formular" do
    writer.call(@seeding_a.id => {"Rang" => "1", "Bälle" => "10", "Aufn" => "10"})

    assert_equal @anna.fullname, @seeding_a.reload.data.dig("result", "Gesamtrangliste", "Name")
  end

  test "berechnete Felder werden ergaenzt" do
    writer.call(@seeding_a.id => {"Bälle" => "44", "Aufn" => "105"})

    assert_in_delta 0.419, @seeding_a.reload.data.dig("result", "Gesamtrangliste", "GD"), 0.0001
  end

  test "eine leere Zeile erzeugt keinen Eintrag" do
    result = writer.call(@seeding_a.id => {"Rang" => "", "Bälle" => "", "Aufn" => ""})

    assert_equal 0, result.written
    assert_equal 1, result.skipped_empty
    assert_nil @seeding_a.reload.data.dig("result", "Gesamtrangliste")
  end

  test "nicht eingereichte Seedings bleiben unberuehrt und werden nicht gezaehlt" do
    result = writer.call(@seeding_a.id => {"Rang" => "1", "Bälle" => "10", "Aufn" => "10"})

    assert_equal 1, result.written
    assert_equal 0, result.skipped_empty
    assert_nil @seeding_b.reload.data.dig("result", "Gesamtrangliste")
  end

  test "String-Schluessel aus dem Formular werden ebenso angenommen" do
    result = writer.call(@seeding_a.id.to_s => {"Rang" => "1", "Bälle" => "10", "Aufn" => "10"})

    assert_equal 1, result.written
  end

  # --- AC-4: Schutzlinie ------------------------------------------------------

  test "eine gescrapte Rangliste bleibt unangetastet" do
    fremd = {"Rang" => 3, "Name" => "Fremd", "Bälle" => 999}
    @seeding_a.update_column(:data, {"result" => {"Gesamtrangliste" => fremd}})

    result = writer.call(@seeding_a.id => {"Rang" => "1", "Bälle" => "10", "Aufn" => "10"})

    assert_equal 0, result.written
    assert_equal 1, result.skipped_foreign
    assert_equal 999, @seeding_a.reload.data.dig("result", "Gesamtrangliste", "Bälle")
  end

  test "eine selbst geschriebene Rangliste laesst sich korrigieren" do
    writer.call(@seeding_a.id => {"Rang" => "1", "Bälle" => "10", "Aufn" => "10"})
    result = writer.call(@seeding_a.id => {"Rang" => "2", "Bälle" => "20", "Aufn" => "10"})

    assert_equal 1, result.written
    assert_equal 20, @seeding_a.reload.data.dig("result", "Gesamtrangliste", "Bälle")
  end

  # --- AC-5: Typen ------------------------------------------------------------

  test "GD wird als Float gespeichert, nicht als Integer" do
    writer.call(@seeding_a.id => {"Bälle" => "44", "Aufn" => "105"})
    entry = @seeding_a.reload.data.dig("result", "Gesamtrangliste")

    # carambus.rake:765 macht `v.is_a?(Float) ? v : v.to_i` — ein Integer schnitte 0.419 auf 0 ab.
    assert_instance_of Float, entry["GD"]
  end

  test "BED wird als Float gespeichert" do
    writer.call(@seeding_a.id => {"Bälle" => "10", "Aufn" => "10", "BED" => "0,750"})

    assert_instance_of Float, @seeding_a.reload.data.dig("result", "Gesamtrangliste", "BED")
  end

  test "der Aufnahmefilter der Aggregation ist erfuellbar" do
    writer.call(@seeding_a.id => {"Bälle" => "44", "Aufn" => "105"})
    entry = @seeding_a.reload.data.dig("result", "Gesamtrangliste")

    # carambus.rake:775 nimmt nur Spieler mit Baelle > 0 UND Aufn > 0 in die Regionalrangliste.
    assert entry["Bälle"].to_f.positive?
    assert entry["Aufn"].to_f.positive?
  end

  # --- Bereits Gespeichertes --------------------------------------------------

  test "stored liefert die gespeicherte Rangliste je Seeding" do
    writer.call(@seeding_a.id => {"Rang" => "1", "Bälle" => "10", "Aufn" => "10"})

    stored = RegionServer::RankingWriter.new(tournament: @tournament.reload).stored

    assert_equal 1, stored[@seeding_a.id]["Rang"]
    assert_equal({}, stored[@seeding_b.id])
  end
end
