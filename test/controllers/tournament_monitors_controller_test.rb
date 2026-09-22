# frozen_string_literal: true

require "test_helper"

class TournamentMonitorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"
    @club_admin = users(:club_admin)
    @tournament = tournaments(:local)
    sign_in @club_admin
    # Create a TournamentMonitor for tests that need one
    @tournament_monitor = TournamentMonitor.create!(
      tournament: @tournament,
      state: "new_tournament_monitor",
      balls_goal: 30,
      innings_goal: 25,
      timeout: 0,
      timeouts: 2
    )
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
    @tournament_monitor&.destroy rescue nil
  end

  # ---------------------------------------------------------------------------
  # Auth guard: ensure_tournament_director
  # ---------------------------------------------------------------------------

  test "ensure_tournament_director redirects basic user to root" do
    sign_out @club_admin
    sign_in users(:one)
    get tournament_monitor_url(@tournament_monitor)
    assert_redirected_to root_path
  end

  # Plan 23-01: Der Rundenwechsel gehoert dem Turnierleiter. Bis 23-01 loeste ihn der gruene
  # Knopf am Scoreboard aus — von jedem, der am Tisch stand (NDM-Vorfall 2026-09-20).
  test "23-01: advance_round verlangt das Turnierleiter-Recht" do
    sign_out @club_admin
    sign_in users(:one)

    post advance_round_tournament_monitor_url(@tournament_monitor)

    assert_redirected_to root_path,
      "Ohne Turnierleiter-Recht darf die Runde nicht geschaltet werden koennen"
  end

  # Bis 2026-09-23 wurde der Knopf-Block von KEINEM Test unter einem echten Request gerendert —
  # weder an der alten Stelle (_round_status) noch an der neuen. Das Fixture-Turnier hat keine
  # round_no-gefuehrten Spiele, also blieb der Zweig immer uebersprungen. Ein Tippfehler darin
  # waere erst dem Betreiber aufgefallen. Dieser Test schliesst die Luecke.
  test "23-01: bei kompletter Runde erscheint der Rundenknopf auf der Seite" do
    Carambus.config.carambus_api_url = "http://local.test"

    # show.html.erb:118 umschliesst den GESAMTEN unteren Bereich (current_games, game_results)
    # mit `tournament_plan.present? && tournament_monitor.data.present?`. Ein frisch angelegter
    # Monitor hat `data == {}`, und `{}.present?` ist FALSE — ohne diese Zeile rendert die Seite
    # den Ergebnisbereich gar nicht, und der Test faende den Knopf auch dann nicht, wenn er da
    # waere. (Projekt-Entscheidung 2026-09-05: `present?` ist kein Leer-Test fuer serialisierte
    # Felder.)
    @tournament_monitor.update!(data: {"current_round" => 1})

    # Eine gefuehrte, komplette Runde: Spiele mit round_no == current_round, alle beendet,
    # id >= MIN_ID (sonst greift live_games nicht — Lehre aus 06-01).
    2.times do |i|
      @tournament.games.create!(id: 63_000_000 + i, gname: "group1:#{i}", round_no: 1,
        group_no: 1, data: {}, ended_at: Time.current)
    end

    assert @tournament_monitor.round_tracked?, "Vorbedingung: die Runde ist gefuehrt"
    assert @tournament_monitor.round_complete?, "Vorbedingung: kein offenes Spiel mehr"

    get tournament_monitor_url(@tournament_monitor)

    assert_response :success
    assert_match(/advance_round/, response.body,
      "Bei kompletter Runde muss der Turnierleiter den Rundenwechsel ausloesen koennen")
  end

  test "23-01: bei offener Runde erscheint der Rundenknopf NICHT" do
    Carambus.config.carambus_api_url = "http://local.test"

    @tournament_monitor.update!(data: {"current_round" => 1}) # siehe Kommentar oben (show.html.erb:118)

    @tournament.games.create!(id: 63_000_010, gname: "group1:1", round_no: 1, group_no: 1,
      data: {}, ended_at: Time.current)
    @tournament.games.create!(id: 63_000_011, gname: "group1:2", round_no: 1, group_no: 1,
      data: {}, ended_at: nil) # noch offen

    refute @tournament_monitor.round_complete?, "Vorbedingung: ein Spiel ist noch offen"

    get tournament_monitor_url(@tournament_monitor)

    assert_response :success
    refute_match(/advance_round/, response.body,
      "Solange ein Spiel laeuft, darf die Runde nicht abschliessbar sein")
  end

  # Nachbesserung 2026-09-23, vom Betreiber gemeldet: "Runde abschliessen" sass in der
  # Statuszeile ganz oben (_round_status), die Ergebnisfelder 50 Zeilen weiter unten in
  # _game_results. `button_to` erzeugt ein EIGENES <form> — wer oben klickte, verwarf still
  # alles, was er unten getippt hatte, und danach waren die Spiele abgeloest und gar nicht
  # mehr editierbar. Belegt am Fall: 6:6 auf 6:5 geaendert, Knopf geklickt, 6:6 geblieben.
  test "23-01: der Rundenknopf steht im Ergebnis-Bereich, nicht in der Statuszeile" do
    status_src = File.read(Rails.root.join("app/views/tournament_monitors/_round_status.html.erb"))
    results_src = File.read(Rails.root.join("app/views/tournament_monitors/_game_results.html.erb"))

    refute_match(/advance_round_tournament_monitor_path/, status_src,
      "Der Knopf darf nicht in die Statuszeile zurueckwandern — dort ist er von den " \
      "Eingabefeldern getrennt und verwirft sie beim Klick")
    assert_match(/advance_round_tournament_monitor_path/, results_src,
      "Der Knopf gehoert unter die Ergebnistabelle, wo korrigiert wird")
  end

  # `button_to` erzeugt ein eigenes <form>. Innerhalb des update_games-form_tag waere das
  # verschachtelt und damit ungueltiges HTML — Browser brechen das innere Formular auf, und
  # welcher Knopf dann was abschickt, ist nicht mehr vorhersagbar.
  test "23-01: der Rundenknopf steht AUSSERHALB des update_games-Formulars" do
    src = File.read(Rails.root.join("app/views/tournament_monitors/_game_results.html.erb"))

    tabellenende = src.rindex("</table>")
    knopf = src.index("advance_round_tournament_monitor_path")

    assert_not_nil tabellenende, "Vorbedingung: die Ergebnistabelle existiert"
    assert_not_nil knopf, "Vorbedingung: der Knopf existiert"
    assert_operator knopf, :>, tabellenende,
      "Der button_to muss NACH dem Tabellenende und damit ausserhalb des form_tag stehen — " \
      "verschachtelte Formulare sind ungueltiges HTML"
  end

  # Der Guard sitzt im Modell (round_ready_for_advance?), nicht nur in der View: ein direkter
  # POST auf eine nicht abschlussbereite Runde muss abgelehnt werden, nicht durchlaufen.
  test "23-01: advance_round lehnt eine nicht abschlussbereite Runde ab" do
    post advance_round_tournament_monitor_url(@tournament_monitor)

    assert_redirected_to tournament_monitor_path(@tournament_monitor)
    assert_equal I18n.t("tournament_monitors.round_status.advance_rejected"), flash[:alert]
  end

  # ---------------------------------------------------------------------------
  # Auth guard: ensure_local_server
  # ---------------------------------------------------------------------------

  test "ensure_local_server redirects to tournaments when no carambus_api_url" do
    Carambus.config.carambus_api_url = nil
    get tournament_monitor_url(@tournament_monitor)
    assert_redirected_to tournaments_path
  end

  # ---------------------------------------------------------------------------
  # Index — only requires sign-in, no local_server or director guard
  # ---------------------------------------------------------------------------

  test "should get index" do
    get tournament_monitors_url
    assert_response :success
  end

  # ---------------------------------------------------------------------------
  # CRUD actions (local server + club_admin signed in)
  # ---------------------------------------------------------------------------

  test "should show tournament_monitor" do
    get tournament_monitor_url(@tournament_monitor)
    assert_response :success
  end

  test "should get edit" do
    get edit_tournament_monitor_url(@tournament_monitor)
    assert_response :success
  end

  test "should update tournament_monitor" do
    patch tournament_monitor_url(@tournament_monitor), params: {
      tournament_monitor: {
        balls_goal: 35,
        innings_goal: 30,
        timeout: 0,
        timeouts: 2
      }
    }
    assert_redirected_to tournament_monitor_url(@tournament_monitor)
  end

  test "should destroy tournament_monitor" do
    assert_difference("TournamentMonitor.count", -1) do
      delete tournament_monitor_url(@tournament_monitor)
    end
    assert_redirected_to tournament_monitors_url
    @tournament_monitor = nil # already destroyed, skip teardown destroy
  end

  # ---------------------------------------------------------------------------
  # Game pipeline actions — no games/table_monitors exist, so these redirect
  # ---------------------------------------------------------------------------

  test "switch_players redirects when no game_id given" do
    post switch_players_tournament_monitor_url(@tournament_monitor)
    assert_redirected_to tournament_monitor_path(@tournament_monitor)
  end

  test "start_round_games redirects after processing (no table_monitors to transition)" do
    post start_round_games_tournament_monitor_url(@tournament_monitor)
    assert_redirected_to tournament_monitor_path(@tournament_monitor)
  end

  test "update_games redirects when no game_id params" do
    post update_games_tournament_monitor_url(@tournament_monitor)
    assert_redirected_to tournament_monitor_path(@tournament_monitor)
  end

end
