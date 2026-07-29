# frozen_string_literal: true

require "test_helper"

# Plan 36-01: Ranglisten-Erfassung auf dem Region Server.
#
# Fixture-Hinweis wie bei den Geschwisterseiten: tournaments(:local) haengt an regions(:nbv) — einer
# CC-Region. Fuer den CC-losen Weg wird der Organizer auf regions(:bbv) umgehaengt (BBV steht in
# Region::SHORTNAMES_CC bewusst auskommentiert, seit v0.5 NuLiga).
class Tournaments::RankingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament = tournaments(:local)
    @tournament.update_columns(organizer_id: regions(:bbv).id, region_id: regions(:bbv).id)

    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"

    @anna = Player.create!(lastname: "ANNA", firstname: "Anna", fl_name: "A. Anna", dbu_nr: 411_111)
    @bodo = Player.create!(lastname: "BODO", firstname: "Bodo", fl_name: "B. Bodo", dbu_nr: 422_222)
    @seedings = [@anna, @bodo].each_with_index.map do |player, ix|
      @tournament.seedings.create!(player_id: player.id, position: ix + 1)
    end

    sign_in users(:system_admin)
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  def save_ranking(entries)
    post tournament_ranking_path(@tournament), params: {rankings: entries}
  end

  # --- Anzeige (AC-1) ---------------------------------------------------------

  test "GET zeigt je gemeldetem Spieler eine Zeile mit den Spalten der Disziplin" do
    get tournament_ranking_path(@tournament)

    assert_response :success
    assert_select "form[action=?]", tournament_ranking_path(@tournament)
    names = css_select("input").map { |input| input["name"] }
    RegionServer::RankingSchema.for(@tournament.reload).input_fields.each do |field|
      assert_includes names, "rankings[#{@seedings.first.id}][#{field.key}]",
        "Feld #{field.key} fehlt im Formular"
    end
  end

  test "berechnete Felder erscheinen nicht als Eingabe" do
    get tournament_ranking_path(@tournament)

    # GD ergibt sich bei Karambol aus Baellen und Aufnahmen — es einzutippen waere eine zweite,
    # womoeglich abweichende Wahrheit.
    assert_select "input[name=?]", "rankings[#{@seedings.first.id}][GD]", false
  end

  test "der Spielername steht in der Zeile, wird aber nicht eingetippt" do
    get tournament_ranking_path(@tournament)

    assert_select "td", text: @anna.fullname
    assert_select "input[name=?]", "rankings[#{@seedings.first.id}][Name]", false
  end

  # --- Vorbefuellung (AC-2) ---------------------------------------------------

  test "ohne erfasste Spiele sind die Felder leer" do
    get tournament_ranking_path(@tournament)

    assert_select "input[name=?][value=?]", "rankings[#{@seedings.first.id}][Bälle]", "", false
    assert_select "input[name=?]", "rankings[#{@seedings.first.id}][Bälle]" do |inputs|
      assert inputs.first["value"].blank?, "ohne Spiele darf nichts vorgeschlagen werden"
    end
  end

  test "erfasste Spiele befuellen Baelle und Aufnahmen vor, nicht aber Rang und Punkte" do
    RegionServer::GameResultWriter.new(
      tournament: @tournament, gname: "Gruppe A", seqno: 1, ended_at: Time.current,
      participations: [
        {player: @anna, result: 100, innings: 25, hs: 9},
        {player: @bodo, result: 80, innings: 25, hs: 6}
      ]
    ).call

    get tournament_ranking_path(@tournament)

    assert_select "input[name=?]", "rankings[#{@seedings.first.id}][Bälle]" do |inputs|
      assert_equal "100", inputs.first["value"]
    end
    assert_select "input[name=?]", "rankings[#{@seedings.first.id}][Rang]" do |inputs|
      assert inputs.first["value"].blank?, "der Platz traegt die Turnierlogik und wird nicht geraten"
    end
    assert_select "input[name=?]", "rankings[#{@seedings.first.id}][Punkte]" do |inputs|
      assert inputs.first["value"].blank?, "die Punkte tragen die Serienlogik"
    end
  end

  test "gespeicherte Werte gewinnen ueber den Vorschlag" do
    RegionServer::GameResultWriter.new(
      tournament: @tournament, gname: "Gruppe A", seqno: 1, ended_at: Time.current,
      participations: [
        {player: @anna, result: 100, innings: 25, hs: 9},
        {player: @bodo, result: 80, innings: 25, hs: 6}
      ]
    ).call
    save_ranking(@seedings.first.id.to_s => {"Bälle" => "77", "Aufn" => "25"})

    get tournament_ranking_path(@tournament)

    # Sonst schriebe die naechste Speicherung die Korrektur des Sportwarts wieder zurueck.
    assert_select "input[name=?]", "rankings[#{@seedings.first.id}][Bälle]" do |inputs|
      assert_equal "77", inputs.first["value"]
    end
  end

  # --- Speichern (AC-3) -------------------------------------------------------

  test "POST schreibt die Rangliste auf die Seedings" do
    save_ranking(@seedings.first.id.to_s => {"Rang" => "1", "Bälle" => "160", "Aufn" => "40",
                                             "HS" => "14", "Punkte" => "6"})

    assert_redirected_to tournament_ranking_path(@tournament)
    entry = @seedings.first.reload.data.dig("result", "Gesamtrangliste")

    assert_equal 1, entry["Rang"]
    assert_equal 160, entry["Bälle"]
    assert_equal "carambus", @seedings.first.reload.data["result_source"]
  end

  test "leere Zeilen werden nicht gespeichert" do
    save_ranking(@seedings.first.id.to_s => {"Rang" => "", "Bälle" => "", "Aufn" => ""})

    assert_nil @seedings.first.reload.data.dig("result", "Gesamtrangliste")
  end

  test "eine gescrapte Rangliste bleibt unangetastet und wird gemeldet" do
    @seedings.first.update_column(:data, {"result" => {"Gesamtrangliste" => {"Bälle" => 999}}})

    save_ranking(@seedings.first.id.to_s => {"Rang" => "1", "Bälle" => "10", "Aufn" => "10"})

    assert_equal 999, @seedings.first.reload.data.dig("result", "Gesamtrangliste", "Bälle")
    assert_match(/1/, flash[:notice].to_s)
  end

  # --- Abgrenzung -------------------------------------------------------------

  test "die Seite fuehrt nicht ins Turniermanagement" do
    get tournament_ranking_path(@tournament)

    assert_response :success
    assert_select "a[href=?]", finalize_modus_tournament_path(@tournament), false,
      "kein Weg in die Modus-Findung"
    assert_select "a[href=?]", tournament_monitor_tournament_path(@tournament), false,
      "kein Weg in den TableMonitor"
  end

  # --- Gates (AC-6) -----------------------------------------------------------

  test "auf dem API-Server ist die Seite nicht erreichbar" do
    Carambus.config.carambus_api_url = nil

    get tournament_ranking_path(@tournament)

    assert_redirected_to tournaments_path
  end

  test "CC-Turniere werden abgewiesen" do
    @tournament.update_column(:organizer_id, regions(:nbv).id)

    get tournament_ranking_path(@tournament)

    assert_redirected_to tournament_path(@tournament)
  end

  test "ohne manage_teilnehmerliste-Recht ist Speichern abgewiesen" do
    sign_out users(:system_admin)
    sign_in users(:one)

    save_ranking(@seedings.first.id.to_s => {"Rang" => "1", "Bälle" => "10", "Aufn" => "10"})

    assert_redirected_to tournament_path(@tournament)
    assert_nil @seedings.first.reload.data.dig("result", "Gesamtrangliste")
  end

  # --- Panel (AC-6) -----------------------------------------------------------

  test "das Region-Server-Panel fuehrt alle drei Wege" do
    get tournament_path(@tournament)

    assert_response :success
    assert_select "a[href=?]", tournament_entry_list_path(@tournament)
    assert_select "a[href=?]", tournament_game_results_path(@tournament)
    assert_select "a[href=?]", tournament_ranking_path(@tournament)
  end
end
