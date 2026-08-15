# frozen_string_literal: true

require "test_helper"

# Plan 29-02: Gesamtrangliste aus den Monitor-Aggregaten je Seeding schreiben.
#
# Die beiden Fallen, gegen die hier gezielt getestet wird (Befunde aus 29-01 / der 29-02-Planung):
#   - `Bälle` UND `Punkte` muessen BEIDE gesetzt sein, sonst deutet carambus.rake:740 still um
#   - die Spieler-Schluessel in rankings["total"] sind mal Integer, mal String (JSON-Round-Trip)
class Tournament::FinalRankingWriterTest < ActiveSupport::TestCase
  setup do
    @region = regions(:nbv)
    # Die Fixtures kennen keinen Disziplin-Baum — dort ist jede Disziplin ihre eigene Wurzel.
    # In Produktion haengt "Dreiband gross" ueber `super_discipline` an "Karambol"; genau daran
    # entscheidet `update_ranking_tables` (carambus.rake:721) und damit auch dieser Writer.
    # Der Baum wird hier aufgebaut, statt den Guard im Service aufzuweichen.
    # Der Wurzelname muss EXAKT "Karambol" sein — daran entscheidet der Guard.
    @karambol = Discipline.find_by(name: "Karambol") || Discipline.create!(name: "Karambol")
    @discipline = Discipline.create!(name: "Dreiband gross 29-02", super_discipline: @karambol)

    @tournament = Tournament.create!(
      title: "LM Dreiband",
      shortname: "LM3B29",
      season: seasons(:current),
      organizer: @region,
      region_id: @region.id,
      discipline: @discipline,
      date: Time.zone.local(2025, 10, 11, 10, 0)
    )

    @player_a = Player.create!(lastname: "ERSTER", firstname: "Anna", fl_name: "A. Erster")
    @player_b = Player.create!(lastname: "ZWEITER", firstname: "Bert", fl_name: "B. Zweiter")

    @seeding_a = @tournament.seedings.create!(player_id: @player_a.id, position: 1)
    @seeding_b = @tournament.seedings.create!(player_id: @player_b.id, position: 2)

    @monitor = build_monitor(string_keys: false)
  end

  # rankings["total"] wie der TournamentMonitor sie aufbaut (result_processor.rb:444 + :228).
  #
  # `data` wird NACH dem Anlegen gesetzt: der initiale AASM-State ruft `do_reset_tournament_monitor`,
  # und das setzt `data: {}` (table_populator.rb:542). Ein `data:` im create! waere also wirkungslos.
  def build_monitor(string_keys:)
    key_a = string_keys ? @player_a.id.to_s : @player_a.id
    key_b = string_keys ? @player_b.id.to_s : @player_b.id

    monitor = TournamentMonitor.create!(tournament: @tournament)
    monitor.update!(
      data: {
        "rankings" => {
          "total" => {
            key_a => {"points" => 4, "result" => 120, "innings" => 106, "hs" => 5,
                      "bed" => 1.29, "gd" => 1.132, "rank" => 1},
            key_b => {"points" => 2, "result" => 44, "innings" => 105, "hs" => 3,
                      "bed" => 0.75, "gd" => 0.419, "rank" => 2}
          }
        }
      }
    )
    @tournament.reload
    monitor
  end

  def writer(armed: false, tournament: @tournament)
    Tournament::FinalRankingWriter.new(tournament: tournament, armed: armed)
  end

  def gesamtrangliste(seeding)
    seeding.reload.data.dig("result", "Gesamtrangliste")
  end

  test "dry-run schreibt nichts, meldet aber was entstehen wuerde" do
    result = writer.call

    assert_equal 2, result.seedings_written
    assert_equal 2, result.planned.size
    assert_nil gesamtrangliste(@seeding_a)
    assert_nil gesamtrangliste(@seeding_b)
  end

  test "ARMED schreibt den Karambol-Zielsatz" do
    writer(armed: true).call

    entry = gesamtrangliste(@seeding_a)
    assert_equal 1, entry["Rang"]
    assert_equal 120, entry["Bälle"]
    assert_equal 106, entry["Aufn"]
    assert_equal 5, entry["HS"]
    assert_equal 4, entry["Punkte"]
    assert_in_delta 1.132, entry["GD"], 0.0001
    assert_in_delta 1.29, entry["BED"], 0.0001
  end

  # Der Kern der Auflage aus 29-01 §4.3: fehlt `Bälle`, deutet carambus.rake:740 `Punkte` still zu
  # `Bälle` um — und zaehlt Partiepunkte als Baelle.
  test "Baelle UND Punkte sind beide gesetzt und unterscheidbar" do
    writer(armed: true).call

    entry = gesamtrangliste(@seeding_a)
    assert entry.key?("Bälle"), "Bälle fehlt — der stille Umdeut-Fallback wuerde greifen"
    assert entry.key?("Punkte"), "Punkte fehlt"
    refute_equal entry["Bälle"], entry["Punkte"],
      "Baelle und Partiepunkte duerfen nicht denselben Wert tragen (hier 120 vs 4)"
  end

  # GD/BED muessen Float bleiben: die Aggregation macht `v.is_a?(Float) ? v : v.to_i`
  # (carambus.rake:765) — ein Integer wuerde 1.132 auf 1 abschneiden.
  test "GD und BED sind Float, nicht Integer" do
    writer(armed: true).call

    entry = gesamtrangliste(@seeding_a)
    assert_kind_of Float, entry["GD"]
    assert_kind_of Float, entry["BED"]
  end

  test "Platzierung kommt aus rankings rank — der Sieger hat Rang 1" do
    writer(armed: true).call

    assert_equal 1, gesamtrangliste(@seeding_a)["Rang"]
    assert_equal 2, gesamtrangliste(@seeding_b)["Rang"]
  end

  # JSON-Round-Trip: aus der DB gelesen sind alle Schluessel Strings.
  test "String-Schluessel in rankings total funktionieren genauso" do
    @monitor.destroy
    @monitor = build_monitor(string_keys: true)

    writer(armed: true).call

    assert_equal 1, gesamtrangliste(@seeding_a)["Rang"]
    assert_equal 120, gesamtrangliste(@seeding_a)["Bälle"]
  end

  test "zweiter Lauf erzeugt dasselbe Ergebnis ohne zu vervielfachen" do
    writer(armed: true).call
    first = gesamtrangliste(@seeding_a)

    writer(armed: true).call
    second = gesamtrangliste(@seeding_a)

    assert_equal first, second
    assert_equal 1, @seeding_a.reload.data["result"].keys.size
  end

  # Schutzlinie: eine aus der ClubCloud gescrapte Gesamtrangliste wird nie ueberschrieben.
  test "fremde Gesamtrangliste bleibt unangetastet" do
    scraped = {"Rang" => 9, "Punkte" => "99", "Name" => "Aus der CC"}
    @seeding_a.update!(data: {"result" => {"Gesamtrangliste" => scraped}})

    result = writer(armed: true).call

    assert_equal scraped, gesamtrangliste(@seeding_a)
    assert_equal 1, result.skipped_foreign_result
    assert_equal 1, result.seedings_written, "das andere Seeding wird trotzdem geschrieben"
  end

  test "ohne TournamentMonitor passiert nichts" do
    @monitor.destroy
    @tournament.reload

    result = writer(armed: true).call

    assert_equal 1, result.skipped_no_monitor
    assert_equal 0, result.seedings_written
    assert_nil gesamtrangliste(@seeding_a)
  end

  test "Nicht-Karambol wird uebersprungen statt halb bedient" do
    pool_root = Discipline.create!(name: "Pool 29-02")
    pool = Discipline.create!(name: "9-Ball 29-02", super_discipline: pool_root)
    @tournament.update!(discipline: pool)

    result = writer(armed: true).call

    assert_equal 1, result.skipped_discipline
    assert_equal 0, result.seedings_written
    assert_nil gesamtrangliste(@seeding_a)
  end

  # AC-1 ("die Detailseite zeigt das Ergebnis") laesst sich auf der Authority nicht durchspielen —
  # ApiProtector verbietet dort TournamentMonitor, es gibt keine echten Turnierlaeufe. Was sich
  # pruefen laesst: dass die geschriebene Struktur vom Anzeigepfad tatsaechlich gerendert wird.
  # `Seeding.result_display` ist genau die Methode, die die Turnier-Detailseite dafuer benutzt.
  test "die geschriebene Struktur wird vom Anzeigepfad gerendert" do
    writer(armed: true).call

    html = Seeding.result_display(@seeding_a.reload)

    assert html.present?, "result_display liefert nichts fuer die geschriebene Gesamtrangliste"
    assert_includes html, "Gesamtrangliste"
    assert_includes html, "120", "die erspielten Baelle fehlen in der Anzeige"
  end

  # Plan 29-02 T2: Ein Fehler beim Schreiben der Rangliste darf den Turnier-Abschluss nicht
  # verhindern. Das ist die Zusage, die den Einhaengepunkt ueberhaupt vertretbar macht — ein
  # haengengebliebenes Turnier waere schlimmer als eine fehlende Rangliste.
  test "Fehler im Writer bricht den Turnier-Abschluss nicht ab" do
    processor = TournamentMonitor::ResultProcessor.new(@monitor)

    Tournament::FinalRankingWriter.stub(:new, ->(*) { raise "Boom" }) do
      assert_nothing_raised { processor.write_final_ranking }
    end
  end

  test "Monitor ohne rankings wird gemeldet" do
    @monitor.update!(data: {})

    result = writer(armed: true).call

    assert_equal 1, result.skipped_no_results
    assert_equal 0, result.seedings_written
  end
end
