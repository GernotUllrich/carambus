# frozen_string_literal: true

require "test_helper"

class TournamentMonitorsControllerTest < ActionDispatch::IntegrationTest
  # Der WOERTLICHE render-Aufruf, nicht nur der Partial-Name: die Kommentare in _game_results und
  # _current_games nennen `_advance_round_button` ebenfalls. Eine Suche nach dem blossen Namen
  # faende den Kommentar und bliebe gruen, auch wenn der Aufruf geloescht waere — in der
  # Gegenprobe vom 2026-09-23 genau so passiert.
  RENDER_AUFRUF = 'render partial: "tournament_monitors/advance_round_button"'

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

    # Betreiber-Wunsch 2026-09-23: derselbe Knopf an ZWEI Orten — am Fuss von "Aktuelle Spiele"
    # und unter der Ergebnistabelle. Gezaehlt wird die Formular-action, nicht der Sichttext:
    # die Beschriftung wechselt in der letzten Runde ("Turnier abschliessen").
    assert_equal 2, response.body.scan(%r{/advance_round"}).size,
      "Der Knopf muss an beiden Orten ankommen — faellt eine der beiden render-Stellen weg, " \
      "merkt es sonst erst der Betreiber am Display"
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
    # Betreiber-Befund 2026-09-23: Bis hierher stand hier ein assert_match — der gelbe Hinweis
    # "nachtraegliche Korrektur" erschien fuer JEDES abgeloeste Spiel. Nach einem
    # Rundenabschluss ist das jedes Spiel der Runde (der Tisch gibt sein Spiel ab,
    # table_populator.rb:950), und an keinem davon war etwas korrigiert worden. Der Hinweis
    # behauptet ein Ereignis; er darf also nur stehen, wo eines stattgefunden hat.
    refute_match(/#{Regexp.escape(I18n.t("tournament_monitors.round_status.correction_manual"))}/,
      response.body,
      "Ein bloss abgeloestes Spiel wurde nicht korrigiert — der Hinweis darf hier nicht stehen")
  end

  test "Der Korrektur-Hinweis erscheint erst nach einer tatsaechlichen Korrektur" do
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament_monitor.update!(data: {"current_round" => 1})
    mit_lokaler_meldung!
    game = abgeloestes_spiel_mit_schnappschuss!(id: 66_000_030, a: 30, b: 30)

    assert_nil game.data["manual_correction_at"],
      "VORBEDINGUNG: an diesem Spiel wurde noch nichts von Hand geaendert"

    post update_games_tournament_monitor_url(@tournament_monitor), params: {
      "game_id" => [game.id.to_s],
      "resulta" => ["30"], "resultb" => ["29"],
      "inningsa" => ["10"], "inningsb" => ["10"],
      "hsa" => ["5"], "hsb" => ["5"]
    }

    assert game.reload.data["manual_correction_at"].present?,
      "Die Korrektur muss sich am Spiel vermerken — sonst kann die Tabelle sie nicht zeigen"

    get tournament_monitor_url(@tournament_monitor)

    assert_response :success
    assert_match(/#{Regexp.escape(I18n.t("tournament_monitors.round_status.correction_manual"))}/,
      response.body,
      "Nach einer echten Korrektur soll der Turnierleiter sehen, an welchem Spiel er war")
  end

  # Ein beendetes Spiel so, wie die Tabelle es zeigt: die Beteiligungen tragen die Werte, die
  # das Formular in die Felder schreibt und beim Absenden unveraendert zurueckliefert.
  def beendetes_spiel!(id:, seqno:, a:, b:, innings: 10, hs: 5)
    game = @tournament.games.create!(id: id, gname: "group1:#{seqno}", round_no: 1,
      group_no: 1, seqno: seqno, data: {}, ended_at: 1.hour.ago)
    GameParticipation.create!(game: game, player: players(:nbv_ullrich), role: "playera",
      result: a, innings: innings, hs: hs)
    GameParticipation.create!(game: game, player: players(:nbv_andresen), role: "playerb",
      result: b, innings: innings, hs: hs)
    game
  end

  # Betreiber-Befund 2026-09-23 (zweite Meldung): "Jetzt kann ich sogar noch nach
  # Rundenabschluss aendern mit der Wirkung, dass ALLE gelaufenen Spiele den Aenderungshinweis
  # bekommen."
  #
  # Ursache: Das update_games-Formular schickt JEDE editierbare Zeile mit — der Controller
  # schreibt sie alle neu, auch die unveraenderten. Die Marke aus dem ersten Anlauf sass an
  # "wurde geschrieben", nicht an "wurde geaendert". Ein einziger Klick auf "update" markierte
  # damit das ganze Feld.
  test "Ein update ohne Wertaenderung markiert kein Spiel" do
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament_monitor.update!(data: {"current_round" => 1})
    eins = beendetes_spiel!(id: 66_000_040, seqno: 1, a: 30, b: 29)
    zwei = beendetes_spiel!(id: 66_000_041, seqno: 2, a: 30, b: 12)

    # Exakt das, was das Formular zeigt — nichts angefasst, nur abgeschickt.
    post update_games_tournament_monitor_url(@tournament_monitor), params: {
      "game_id" => [eins.id.to_s, zwei.id.to_s],
      "resulta" => ["30", "30"], "resultb" => ["29", "12"],
      "inningsa" => ["10", "10"], "inningsb" => ["10", "10"],
      "hsa" => ["5", "5"], "hsb" => ["5", "5"]
    }

    assert_nil eins.reload.data["manual_correction_at"],
      "Unveraendert abgeschickt ist keine Korrektur — der Hinweis darf hier nicht entstehen"
    assert_nil zwei.reload.data["manual_correction_at"],
      "Und schon gar nicht flaechendeckend fuer jedes Spiel der Runde"
  end

  test "Ein update markiert nur das Spiel, dessen Werte sich geaendert haben" do
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament_monitor.update!(data: {"current_round" => 1})
    unveraendert = beendetes_spiel!(id: 66_000_050, seqno: 1, a: 30, b: 29)
    geaendert = beendetes_spiel!(id: 66_000_051, seqno: 2, a: 30, b: 12)

    post update_games_tournament_monitor_url(@tournament_monitor), params: {
      "game_id" => [unveraendert.id.to_s, geaendert.id.to_s],
      "resulta" => ["30", "30"], "resultb" => ["29", "14"], # nur das zweite Spiel: 12 -> 14
      "inningsa" => ["10", "10"], "inningsb" => ["10", "10"],
      "hsa" => ["5", "5"], "hsb" => ["5", "5"]
    }

    assert_nil unveraendert.reload.data["manual_correction_at"],
      "Das unberuehrte Spiel darf nicht mitmarkiert werden, nur weil es im selben POST lag"
    assert geaendert.reload.data["manual_correction_at"].present?,
      "Das tatsaechlich geaenderte Spiel muss die Marke bekommen"
    assert_equal 14, geaendert.game_participations.where(role: "playerb").first.result,
      "Und die Korrektur selbst muss natuerlich weiterhin ankommen"
  end

  # ── Betreiber-Entscheidung 2026-09-23: abgeschlossene Runden sind zu ───────
  #
  # Gemeldet: "Jetzt kann ich sogar noch nach Rundenabschluss aendern. Ueberall bleibt die Zeile
  # im Edit modus." Bis dahin blieb jedes beendete Spiel dauerhaft editierbar (aus 24-01:
  # `!abgeloest || ended_at.present?`). Die Faehigkeit aus 24-01 bleibt fuer die LAUFENDE Runde.

  test "Ein Spiel aus einer abgeschlossenen Runde zeigt keine Eingabefelder mehr" do
    Carambus.config.carambus_api_url = "http://local.test"
    mit_lokaler_meldung!
    alt = beendetes_spiel!(id: 66_000_060, seqno: 1, a: 30, b: 29)
    @tournament_monitor.update!(data: {"current_round" => 2}) # Runde 1 ist durch

    get tournament_monitor_url(@tournament_monitor)

    assert_response :success
    refute_match(/value="#{alt.id}"/, response.body,
      "Ohne game_id-Feld kommt die Zeile im POST nicht an — genau das ist hier gewollt")
    refute_match(/name="resulta\[\]"/, response.body,
      "Nach dem Rundenabschluss darf die Zeile nicht im Edit-Modus stehen")
  end

  test "Ein Spiel der laufenden Runde bleibt editierbar, auch abgeloest" do
    Carambus.config.carambus_api_url = "http://local.test"
    mit_lokaler_meldung!
    aktuell = beendetes_spiel!(id: 66_000_061, seqno: 1, a: 30, b: 29)
    @tournament_monitor.update!(data: {"current_round" => 1})

    assert_nil aktuell.table_monitor, "VORBEDINGUNG: das Spiel ist abgeloest"

    get tournament_monitor_url(@tournament_monitor)

    assert_response :success
    assert_match(/value="#{aktuell.id}"/, response.body,
      "Die Faehigkeit aus 24-01 muss fuer die laufende Runde erhalten bleiben")
  end

  test "Ein POST auf eine abgeschlossene Runde aendert nichts" do
    Carambus.config.carambus_api_url = "http://local.test"
    alt = beendetes_spiel!(id: 66_000_070, seqno: 1, a: 30, b: 29)
    @tournament_monitor.update!(data: {"current_round" => 2})

    post update_games_tournament_monitor_url(@tournament_monitor), params: {
      "game_id" => [alt.id.to_s],
      "resulta" => ["30"], "resultb" => ["14"], # Aenderungsversuch 29 -> 14
      "inningsa" => ["10"], "inningsb" => ["10"],
      "hsa" => ["5"], "hsb" => ["5"]
    }

    assert_equal 29, alt.game_participations.where(role: "playerb").first.reload.result,
      "Der Riegel muss auch einen POST abhalten, der die View umgeht"
    assert_nil alt.reload.data["manual_correction_at"],
      "Und er darf schon gar keine Korrektur-Marke hinterlassen"
  end

  # Ohne Rundenfuehrung (round_no nil) gibt es keinen Rundenabschluss. `nil.to_i` ist 0 und waere
  # "kleiner als Runde 1" — ein blinder Vergleich haette solche Turniere komplett gesperrt.
  test "Ohne Rundenfuehrung sperrt der Riegel nicht" do
    Carambus.config.carambus_api_url = "http://local.test"
    ohne_runde = @tournament.games.create!(id: 66_000_080, gname: "group1:1", group_no: 1,
      seqno: 1, round_no: nil, data: {}, ended_at: 1.hour.ago)
    GameParticipation.create!(game: ohne_runde, player: players(:nbv_ullrich), role: "playera",
      result: 30, innings: 10, hs: 5)
    GameParticipation.create!(game: ohne_runde, player: players(:nbv_andresen), role: "playerb",
      result: 29, innings: 10, hs: 5)
    @tournament_monitor.update!(data: {"current_round" => 3})

    post update_games_tournament_monitor_url(@tournament_monitor), params: {
      "game_id" => [ohne_runde.id.to_s],
      "resulta" => ["30"], "resultb" => ["14"],
      "inningsa" => ["10"], "inningsb" => ["10"],
      "hsa" => ["5"], "hsb" => ["5"]
    }

    assert_equal 14, ohne_runde.game_participations.where(role: "playerb").first.reload.result,
      "Ohne round_no gibt es keinen Rundenabschluss — hier darf der Riegel nicht greifen"
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
  # 2026-09-23: Der Knopf steht seither an ZWEI Orten (Betreiber-Wunsch) und ist dafuer nach
  # _advance_round_button ausgelagert — eine Definition, zwei render-Stellen. _game_results und
  # _current_games tragen deshalb nur noch den Aufruf, den button_to traegt die Partial.
  test "23-01: der Rundenknopf steht im Ergebnis-Bereich, nicht in der Statuszeile" do
    status_src = File.read(Rails.root.join("app/views/tournament_monitors/_round_status.html.erb"))
    button_src = File.read(Rails.root.join("app/views/tournament_monitors/_advance_round_button.html.erb"))
    results_src = File.read(Rails.root.join("app/views/tournament_monitors/_game_results.html.erb"))

    refute_match(/advance_round_tournament_monitor_path/, status_src,
      "Der Knopf darf nicht in die Statuszeile zurueckwandern — dort ist er von den " \
      "Eingabefeldern getrennt und verwirft sie beim Klick")
    assert_match(/advance_round_tournament_monitor_path/, button_src,
      "Die gemeinsame Fassung traegt den button_to")
    assert_includes results_src, RENDER_AUFRUF,
      "Der Knopf gehoert unter die Ergebnistabelle, wo korrigiert wird"
  end

  # Betreiber-Wunsch 2026-09-23: zusaetzlich am FUSS von "Aktuelle Spiele - Runde N" — dort sieht
  # der Turnierleiter waehrend der Runde hin. Der Abschnitt hat kein eigenes Formular, hier droht
  # also keine Verschachtelung; der sichere Weg unter der Ergebnistabelle bleibt daneben bestehen.
  test "Rundenknopf steht zusaetzlich am Fuss von 'Aktuelle Spiele'" do
    src = File.read(Rails.root.join("app/views/tournament_monitors/_current_games.html.erb"))

    tabellenende = src.rindex("</table>")
    knopf = src.index(RENDER_AUFRUF)

    assert_not_nil tabellenende, "Vorbedingung: die Spieltabelle existiert"
    assert_not_nil knopf, "Vorbedingung: der Knopf wird gerendert"
    assert_operator knopf, :>, tabellenende,
      "Der Knopf gehoert an den FUSS des Abschnitts, nicht neben die Ueberschrift"
  end

  # `button_to` erzeugt ein eigenes <form>. Innerhalb des update_games-form_tag waere das
  # verschachtelt und damit ungueltiges HTML — Browser brechen das innere Formular auf, und
  # welcher Knopf dann was abschickt, ist nicht mehr vorhersagbar.
  test "23-01: der Rundenknopf steht AUSSERHALB des update_games-Formulars" do
    src = File.read(Rails.root.join("app/views/tournament_monitors/_game_results.html.erb"))

    tabellenende = src.rindex("</table>")
    knopf = src.index(RENDER_AUFRUF)

    assert_not_nil tabellenende, "Vorbedingung: die Ergebnistabelle existiert"
    assert_not_nil knopf, "Vorbedingung: der Knopf wird gerendert"
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
