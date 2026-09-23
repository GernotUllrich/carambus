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

  # ── Plan 24-01: Korrektur abgeloester Spiele ───────────────────────────────
  #
  # Vom Betreiber gemeldet 2026-09-23: 30:29 abgeschickt, Log meldet "validation PASSED,
  # updating...", in der DB steht 30:30. In Task 1 reproduziert: der tmp_results-Schnappschuss
  # gewinnt gegen die uebergebenen Werte (result_processor.rb:603).
  # Dazu kam: zwei von vier Spielen trugen gar kein `game_id` im POST, weil
  # `editable_game = game.table_monitor.present?` fuer abgeloeste Spiele false ist.

  # Die Ergebnistabelle filtert doppelt: `games.id >= Seeding::MIN_ID` UND ein `game_scope`,
  # der ohne lokale Meldungen auf `games.id < MIN_ID` steht (_game_results.html.erb:5,43).
  # Beide zusammen sind dann leer — das Fixture-Turnier hat keine lokale Meldung, also zeigt
  # die Tabelle gar nichts. Ohne diese Zeile testen die Render-Tests ins Leere.
  def mit_lokaler_meldung!
    Seeding.create!(id: 66_900_001, tournament: @tournament, player: players(:nbv_ullrich),
      position: 1, state: "seeded")
  end

  def abgeloestes_spiel_mit_schnappschuss!(id:, a:, b:)
    game = @tournament.games.create!(id: id, gname: "group1:1", round_no: 1, group_no: 1,
      seqno: 1, data: {}, ended_at: 1.hour.ago)
    GameParticipation.create!(game: game, player: players(:nbv_ullrich), role: "playera", result: a)
    GameParticipation.create!(game: game, player: players(:nbv_andresen), role: "playerb", result: b)
    game.deep_merge_data!("tmp_results" => {
      "playera" => {"result" => a, "innings" => 10, "hs" => 5, "balls_goal" => 30},
      "playerb" => {"result" => b, "innings" => 10, "hs" => 5, "balls_goal" => 30}
    })
    game.save!
    game.reload
  end

  test "24-01: Korrektur an einem abgeloesten Spiel kommt an und haelt" do
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament_monitor.update!(data: {"current_round" => 1})
    game = abgeloestes_spiel_mit_schnappschuss!(id: 66_000_001, a: 30, b: 30)

    assert_nil game.table_monitor, "VORBEDINGUNG: das Spiel ist abgeloest"
    assert game.data["tmp_results"].present?, "VORBEDINGUNG: der Schnappschuss steht"

    post update_games_tournament_monitor_url(@tournament_monitor), params: {
      "game_id" => [game.id.to_s],
      "resulta" => ["30"], "resultb" => ["29"],
      "inningsa" => ["10"], "inningsb" => ["10"],
      "hsa" => ["5"], "hsb" => ["5"]
    }

    gpb = game.game_participations.where(role: "playerb").first.reload
    assert_equal 29, gpb.result,
      "Die Korrektur muss ankommen — genau das ging bis 24-01 nicht"

    assert_equal 29, game.reload.data.dig("tmp_results", "playerb", "result"),
      "Der Schnappschuss wird MITGESCHRIEBEN (Betreiber-Entscheidung), sonst dreht er die " \
      "Korrektur beim naechsten Schreiber zurueck"
    assert_equal 29, game.data.dig("ba_results", "Ergebnis2"),
      "ba_results traegt den korrigierten Stand — sonst meldet die ClubCloud das alte Ergebnis"
  end

  test "24-01: ein unbespieltes Spiel ohne Tisch bleibt nicht editierbar" do
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament_monitor.update!(data: {"current_round" => 1})
    mit_lokaler_meldung!
    offen = @tournament.games.create!(id: 66_000_010, gname: "group1:2", round_no: 1,
      group_no: 1, seqno: 2, data: {}, ended_at: nil)

    get tournament_monitor_url(@tournament_monitor)

    assert_response :success
    refute_match(/value="#{offen.id}"/, response.body,
      "Ein unbespieltes Spiel ohne Tisch hat nichts zu korrigieren und darf keine leeren " \
      "Eingabefelder zeigen")
  end

  test "24-01: ein beendetes abgeloestes Spiel IST editierbar" do
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament_monitor.update!(data: {"current_round" => 1})
    mit_lokaler_meldung!
    game = abgeloestes_spiel_mit_schnappschuss!(id: 66_000_020, a: 30, b: 30)

    get tournament_monitor_url(@tournament_monitor)

    assert_response :success
    # `hidden_field_tag` schiebt ein id-Attribut zwischen name und value — deshalb beide
    # Bestandteile einzeln pruefen statt eine feste Attributreihenfolge zu erwarten.
    assert_match(/name="game_id\[\]"/, response.body,
      "Ohne game_id-Feld kommt die Zeile im POST gar nicht an — das war die Ursache von " \
      "\"Ich kann nichts aendern\"")
    assert_match(/value="#{game.id}"/, response.body,
      "Und zwar fuer genau dieses abgeloeste Spiel")
    assert_match(/#{Regexp.escape(I18n.t("tournament_monitors.round_status.correction_detached"))}/,
      response.body,
      "Der Turnierleiter soll sehen, dass er in eine abgeschlossene Runde greift")
  end

  # ── Plan 26-01: Die Korrektur am Tisch kommt an ────────────────────────────
  #
  # Vom Betreiber beim UAT zu Phase 25 gemeldet (2026-09-23, Turnier 18935, group2:2-3):
  # 29:30 ueber den update-Knopf eingetragen. Scoreboard, obere Tabelle und ClubCloud zeigten
  # 29:30 — die Partieergebnis-Tabelle und die Rangliste blieben bei 30:30.
  #
  # Ursache: `tournament_monitors_controller.rb:116` verzweigt mit `if table_monitor.blank?`.
  # Der in 24-01 gebaute Pfad, der den Schnappschuss ZUERST korrigiert, greift also nur bei
  # einem Spiel OHNE TableMonitor. Steht das Spiel noch auf seinem Tisch — seit Plan 23-01 der
  # Normalfall fuer das LETZTE Spiel einer Runde, weil die Rundenkaskade nicht mehr am Tisch
  # haengt —, laeuft der alte Zweig, und `result_processor.rb:603` zieht den alten
  # Schnappschuss vor.
  #
  # Die Luecke entsteht erst aus Plan 23-01 + 24-01 zusammen, keiner von beiden allein.
  #
  # Gemessener Ausgangszustand (Game 50016208 / TableMonitor 50000008), gesichert in
  # .paul/befunde/2026-09-23-korrektur-auf-dem-tisch.json:
  #   TableMonitor.data.playera.result = 29   (korrigiert)
  #   GameParticipation playera.result = 30   (alt), points 1 statt 0
  #   game.data.tmp_results.playera.result = 30 (alt)

  # Wie abgeloestes_spiel_mit_schnappschuss!, aber MIT Tisch — das ist der ganze Unterschied.
  def spiel_am_tisch_mit_schnappschuss!(id:, a:, b:)
    game = @tournament.games.create!(id: id, gname: "group1:1", round_no: 1, group_no: 1,
      seqno: 1, data: {}, ended_at: 1.hour.ago)
    GameParticipation.create!(game: game, player: players(:nbv_ullrich), role: "playera", result: a)
    GameParticipation.create!(game: game, player: players(:nbv_andresen), role: "playerb", result: b)
    # ⚠️ Game#data ist ueberschrieben (game.rb:95) — `game.data[...] = ` waere ein stilles No-op.
    game.deep_merge_data!("tmp_results" => {
      "playera" => {"result" => a, "innings" => 10, "hs" => 5, "balls_goal" => 30},
      "playerb" => {"result" => b, "innings" => 10, "hs" => 5, "balls_goal" => 30}
    })
    game.save!

    tm = table_monitors(:one)
    tm.update!(data: {
      "free_game_form" => "karambol",
      "playera" => {"discipline" => "Dreiband", "result" => a, "innings" => 10,
                    "balls_goal" => 30, "hs" => 5, "innings_redo_list" => [0]},
      "playerb" => {"discipline" => "Dreiband", "result" => b, "innings" => 10,
                    "balls_goal" => 30, "hs" => 5, "innings_redo_list" => [0]},
      "innings_goal" => 25,
      "allow_follow_up" => false
    })
    tm.update_columns(game_id: game.id, state: "final_match_score",
      panel_state: "protocol_final", current_element: "protocol_final")
    [game.reload, tm.reload]
  end

  test "26-01: Korrektur an einem Spiel AM TISCH kommt in den Beteiligungen an" do
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament_monitor.update!(data: {"current_round" => 1})
    game, tm = spiel_am_tisch_mit_schnappschuss!(id: 66_000_100, a: 30, b: 30)

    assert tm.present?, "VORBEDINGUNG: das Spiel steht noch auf seinem Tisch"
    assert_equal tm.id, game.table_monitor&.id, "VORBEDINGUNG: der Tisch haengt am Spiel"
    assert game.data["tmp_results"].present?, "VORBEDINGUNG: der alte Schnappschuss steht"

    post update_games_tournament_monitor_url(@tournament_monitor), params: {
      "game_id" => [game.id.to_s],
      "resulta" => ["29"], "resultb" => ["30"],
      "inningsa" => ["10"], "inningsb" => ["10"],
      "hsa" => ["5"], "hsb" => ["5"]
    }

    gpa = game.game_participations.where(role: "playera").first.reload
    gpb = game.game_participations.where(role: "playerb").first.reload

    assert_equal 29, gpa.result,
      "Die Korrektur muss in der GameParticipation ankommen — bis 26-01 gewann hier der alte " \
      "Schnappschuss (result_processor.rb:603), weil der 24-01-Pfad nur bei table_monitor.blank? greift"
    assert_equal 30, gpb.result, "Der unveraenderte Wert bleibt stehen"

    # Die Signatur des Fehlers: 30 gegen 30 rechnet die Punkteformel (result_processor.rb:615-624)
    # als Unentschieden. Bei 29:30 muss playerb 2 Punkte bekommen, playera 0.
    assert_equal 0, gpa.points, "Bei 29:30 hat playera verloren — 1 Punkt waere das alte 30:30"
    assert_equal 2, gpb.points, "Bei 29:30 hat playerb gewonnen"
  end

  test "26-01: der Schnappschuss im Spiel wird mitkorrigiert" do
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament_monitor.update!(data: {"current_round" => 1})
    game, = spiel_am_tisch_mit_schnappschuss!(id: 66_000_101, a: 30, b: 30)

    post update_games_tournament_monitor_url(@tournament_monitor), params: {
      "game_id" => [game.id.to_s],
      "resulta" => ["29"], "resultb" => ["30"],
      "inningsa" => ["10"], "inningsb" => ["10"],
      "hsa" => ["5"], "hsb" => ["5"]
    }

    game.reload
    assert_equal 29, game.data.dig("tmp_results", "playera", "result"),
      "Der Schnappschuss muss den korrigierten Stand tragen — sonst dreht er die Korrektur " \
      "beim naechsten Schreiber zurueck (game_setup.rb:312 spielt ihn auf den Tisch zurueck)"
    assert_equal 29, game.data.dig("ba_results", "Ergebnis1"),
      "ba_results traegt den korrigierten Stand — sonst gehen ClubCloud und lokale DB auseinander"
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
