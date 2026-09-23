# frozen_string_literal: true

require "test_helper"

# Phase 25 Plan 01 — der Bestätigungsknopf trägt das Endergebnis auf sich selbst.
#
# Warum Render-Level und warum gegen das KNOPF-ELEMENT:
#
# Das Ergebnis steht heute bereits im Modal — im Kopf (Z. 44-90). Ein Test, der
# nur `assert_includes html, "30"` schreibt, wäre von Anfang an grün und würde
# nichts belegen. Der Befund der Phase ist eine BLICKFÜHRUNG: Ergebnis im Kopf,
# Knopf am Fuß, dazwischen die gesamte Protokolltabelle. Auf dem Touch-Display
# im Vereinslokal schaut man dorthin, wo der Finger hingeht.
#
# Deshalb prüfen diese Tests den Textinhalt des Knopf-Elements selbst.
#
# Spec-Korrektur am Checkpoint (Betreiber, 2026-09-23): NICHT beide Kurznamen um die
# Punktzahl, sondern die Punktzahl gross und darunter der Ausgang in Worten
# ("Sieger: <Kurzname>" bzw. "Unentschieden"). Ohne die Namen vertraegt die
# Punktzahl text-4xl statt text-2xl — die Zahl wird dadurch besser lesbar.
#
# Die Erwartungen stehen als I18n.t(...) da, nicht als deutscher Text: so bricht der
# Test nicht an einer Umformulierung, faengt aber einen fehlenden oder falschen
# Schluessel sehr wohl.
#
# Muster übernommen von test/integration/tiebreak_modal_form_wiring_test.rb
# (ApplicationController.render + Nokogiri) — dort entstanden, weil vier grüne
# Tests einen Bug durchgelassen hatten, der die Kette View→DOM→Reflex nie anfasste.
class GameProtocolConfirmButtonTest < ActionDispatch::IntegrationTest
  def setup
    @tm = table_monitors(:one)
  end

  def teardown
    if @game&.persisted?
      @tm.update_columns(
        game_id: nil, state: "new",
        panel_state: "pointer_mode",
        current_element: "pointer_mode"
      )
      @tm.update!(data: {})
      @game.reload.destroy
    end
  end

  # Bringt den TableMonitor ins Protokoll-Endbild.
  # current_element steuert, welche der beiden Knopf-Fassungen rendert:
  #   "tiebreak_winner_choice" → Tiebreak-Submit  (Partial Z. 170)
  #   alles andere             → confirm_result
  def prepare_final(result_a:, result_b:, current_element:, tiebreak_required: false)
    @game = Game.create!(
      data: {"tiebreak_required" => tiebreak_required},
      group_no: 1, seqno: 1, table_no: 1
    )
    @tm.update!(
      data: {
        "free_game_form" => "karambol",
        "playera" => {"discipline" => "Dreiband", "result" => result_a, "innings" => 30,
                      "balls_goal" => 80, "innings_redo_list" => [0]},
        "playerb" => {"discipline" => "Dreiband", "result" => result_b, "innings" => 30,
                      "balls_goal" => 80, "innings_redo_list" => [0]},
        "innings_goal" => 30,
        "allow_follow_up" => false
      }
    )
    @tm.update_columns(
      game_id: @game.id,
      panel_state: "protocol_final",
      current_element: current_element
    )
    @tm.reload
  end

  def render_modal
    html = ApplicationController.render(
      partial: "table_monitors/game_protocol_modal",
      locals: {table_monitor: @tm, full_screen: true, modal_hidden: false}
    )
    Nokogiri::HTML.fragment(html)
  end

  # ---------------------------------------------------------------
  # T1 (AC-1): Der Regelfall-Knopf trägt das Ergebnis.
  # ---------------------------------------------------------------
  test "T1: confirm_result-Knopf traegt Ergebnis und Kurznamen in seinem eigenen Textinhalt" do
    prepare_final(result_a: 30, result_b: 29, current_element: "protocol_final")

    doc = render_modal
    button = doc.at_css("button[data-reflex='click->GameProtocolReflex#confirm_result']")
    assert button, "Der confirm_result-Knopf muss im Endbild rendern"

    text = button.text

    assert_includes text, "30",
      "Das Ergebnis von Spieler A muss AUF DEM KNOPF stehen, nicht nur im Kopf des Modals — " \
      "auf dem Touch-Display liegt der Kopf im Moment der Entscheidung ausserhalb des Blickfelds"
    assert_includes text, "29",
      "Das Ergebnis von Spieler B muss AUF DEM KNOPF stehen"

    assert_includes text, I18n.t("table_monitor.protocol.winner_label", name: "Spieler A"),
      "Der Ausgang gehoert in Worten auf den Knopf — eine nackte Zahlenpaarung ist " \
      "darauf angewiesen, dass links/rechts wie im Kopf gelesen wird"

    refute_includes text, "Spieler B",
      "Nur der Sieger wird genannt (Betreiber am Checkpoint: \"Namen brauchen nicht " \
      "beide drin stehen\") — beide Namen machten die Zeile lang und die Zahl klein"

    refute_includes text, I18n.t("table_monitor.protocol.draw"),
      "Bei 30:29 ist es kein Unentschieden"
  end

  # ---------------------------------------------------------------
  # T2 (AC-2): Der Tiebreak-Knopf trägt die (unentschiedene) Punktzahl.
  #
  # Die SIEGERWAHL bleibt bei den Radio-Buttons (Partial Z. 218-233) — die
  # stehen direkt ueber dem Knopf, also im Blickfeld. Getrennt vom Knopf ist
  # dort nur die Punktzahl. Deshalb braucht diese Fassung kein JavaScript.
  # ---------------------------------------------------------------
  test "T2: Tiebreak-Submit-Knopf traegt die unentschiedene Punktzahl" do
    prepare_final(result_a: 80, result_b: 80,
      current_element: "tiebreak_winner_choice",
      tiebreak_required: true)

    doc = render_modal
    button = doc.at_css("button[type='submit'][form='tiebreak-form-#{@tm.id}']")
    assert button, "Der Tiebreak-Submit-Knopf muss im tiebreak_winner_choice-Zustand rendern"

    assert_includes button.text, "80",
      "Die unentschiedene Punktzahl muss AUF DEM KNOPF stehen — auch beim Stechen " \
      "wird bestaetigt, was gezaehlt wurde"

    assert_includes button.text, I18n.t("table_monitor.protocol.draw"),
      "Beim Stechen ist der Sieger serverseitig noch nicht bekannt — auf dem Knopf " \
      "steht deshalb der Gleichstand, nicht ein Sieger"
  end

  # ---------------------------------------------------------------
  # Plan 27-01: Der Rueckweg ins Spiel.
  #
  # Betreiber am Display (2026-09-23): Stand 21:20, Ziel 30. Spieler B will +10 -2 eingeben.
  # Die +10 trifft GENAU das Ballziel — das Spiel endet sofort, der Protokoll-Editor oeffnet,
  # und es gibt kein Zurueck. Korrigieren ja, weiterspielen nein.
  #
  # ⚠️ Der Mechanismus war vollstaendig vorhanden: AASM-Event `undo` (table_monitor.rb:460),
  # Reflex (table_monitor_reflex.rb:367), Stimulus-Aktion (table_monitor_controller.js:62) und
  # sogar das Bedienelement (_scoreboard.html.erb:197, der Text "Partie beendet-OK?"). Es lag
  # nur unter dem Modal-Backdrop (`absolute inset-0 bg-black bg-opacity-70`) und war nicht
  # klickbar. Diese Tests halten fest, dass es im Modal SELBST erreichbar ist.
  # ---------------------------------------------------------------
  test "T4: das Protokoll-Modal bietet den Rueckweg ins Spiel an" do
    prepare_final(result_a: 21, result_b: 28, current_element: "protocol_final")

    doc = render_modal
    zurueck = doc.at_css("[data-reflex='click->GameProtocolReflex#back_to_game']")
    assert zurueck, "Ohne diesen Knopf ist der Protokoll-Editor eine Sackgasse"

    assert_equal @tm.id.to_s, zurueck["data-id"],
      "Der Reflex laedt den Monitor ueber data-id"

    # ⚠️ Spec-Korrektur 2026-09-23: NICHT auf table-monitor#undo verdrahten. Das ruft
    # TableMonitor#undo (table_monitor.rb:1482) — eine eigene Methode, die das gleichnamige
    # AASM-Ereignis UEBERSCHATTET und die letzte EINGABE zurueticknimmt statt des Zustands.
    # Am Display belegt: state blieb set_over, playera.result fiel von 21 auf 20.
    refute doc.at_css("[data-action='click->table-monitor#undo']"),
      "table-monitor#undo ist das Eingabe-Undo, nicht der Rueckweg ins Spiel. Diese Zeile ist " \
      "die einzige automatische Wache gegen den Fehler, der am 2026-09-23 eine Runde gekostet " \
      "hat — ein Test der Methode selbst scheitert an der Fixture (TableMonitor#undo braucht " \
      "current_inning und PaperTrail-Versionen)."
  end

  # ---------------------------------------------------------------
  # T5 (AC-2): Betreiber-Festlegung vom 2026-09-23, woertlich:
  # "Auch wenn das Spiel mit dem Ergebnis abgeschlossen waere."
  #
  # Der Rueckweg darf NICHT an eine Bedingung ueber das Ergebnis geknuepft werden. Genau der
  # gemeldete Fall war ja einer, in dem das Ergebnis (30 = Ballziel) das Spiel regulaer
  # beendet — und trotzdem falsch eingegeben war. Dieser Test verhindert, dass jemand spaeter
  # eine "nur wenn das Ziel verfehlt ist"-Bedingung einbaut.
  # ---------------------------------------------------------------
  test "T5: der Rueckweg erscheint AUCH bei einem Ergebnis, das das Spiel beendet" do
    prepare_final(result_a: 21, result_b: 30, current_element: "protocol_final")

    doc = render_modal
    assert doc.at_css("[data-reflex='click->GameProtocolReflex#back_to_game']"),
      "Bei 21:30 gegen Ballziel 30 ist das Spiel regulaer zu Ende — der Rueckweg muss " \
      "trotzdem da sein (Betreiber: \"Auch wenn das Spiel mit dem Ergebnis abgeschlossen waere\")"
  end

  # ---------------------------------------------------------------
  # T3: Gleichstand OHNE Tiebreak-Pflicht am Regelfall-Knopf.
  #
  # Deckt den else-Zweig der verdict-Logik ab. Der Kopf des Modals behandelt
  # diesen Fall schon heute (winner_a und winner_b beide false, Partial Z. 25-26),
  # also ist er erreichbar und darf nicht stillschweigend einen Sieger erfinden.
  # Ueber die Acceptance Criteria hinaus — bewusst, weil es der Zweig ist, der
  # am leichtesten unbemerkt bricht.
  # ---------------------------------------------------------------
  test "T3: Gleichstand ohne Tiebreak zeigt Unentschieden statt eines Siegers" do
    prepare_final(result_a: 42, result_b: 42, current_element: "protocol_final")

    doc = render_modal
    button = doc.at_css("button[data-reflex='click->GameProtocolReflex#confirm_result']")
    assert button, "Der confirm_result-Knopf muss auch bei Gleichstand rendern"

    text = button.text
    assert_includes text, "42", "Die Punktzahl gehoert auf den Knopf"
    assert_includes text, I18n.t("table_monitor.protocol.draw"),
      "Bei 42:42 ohne Tiebreak-Pflicht darf kein Sieger behauptet werden"
    refute_includes text, I18n.t("table_monitor.protocol.winner_label", name: "Spieler A"),
      "Kein Sieger bei Gleichstand"
    refute_includes text, I18n.t("table_monitor.protocol.winner_label", name: "Spieler B"),
      "Kein Sieger bei Gleichstand"
  end

  # ---------------------------------------------------------------
  # T6 (AC-2b): Der Zustand muss WIRKLICH wechseln.
  #
  # Diese Pruefung fehlte in der ersten Fassung von Plan 27-01, und genau deshalb war der
  # erste Entwurf gruen und funktionierte trotzdem nicht: er pruefte nur Markup. Verdrahtet
  # war er auf TableMonitor#undo — die ueberschattende Methode, die die letzte Eingabe
  # zuruecknimmt. Der Zustand blieb set_over, die before_save-Invariante zwang
  # protocol_final sofort wieder herbei, der Editor sprang zurueck.
  # ---------------------------------------------------------------
  test "T6: der Rueckweg bringt den Monitor nach playing und gibt das Panel frei" do
    prepare_final(result_a: 21, result_b: 30, current_element: "protocol_final")
    # prepare_final setzt nur panel_state — es war fuer Render-Tests gebaut, wo der
    # AASM-Zustand keine Rolle spielt. T6 misst den Zustandswechsel, braucht ihn also echt.
    @tm.update_columns(state: "set_over")
    @tm.reload
    assert_equal "set_over", @tm.state, "VORBEDINGUNG"
    assert_equal "protocol_final", @tm.panel_state, "VORBEDINGUNG"

    # Wie im Reflex: der Save loest sonst einen Broadcast aus, der im Test die
    # Scoreboard-View rendert und dort scheitert.
    @tm.suppress_broadcast = true
    @tm.aasm.fire!(:undo)
    @tm.suppress_broadcast = false

    assert_equal "playing", @tm.reload.state,
      "aasm.fire!(:undo) muss den Zustandsuebergang set_over -> playing ausloesen"
    refute_equal "protocol_final", @tm.panel_state,
      "Die Invariante (table_monitor.rb:662) gibt protocol_final frei, sobald set_over " \
      "verlassen ist — der Reflex muss daran nicht drehen"

    # ⚠️ GRENZE DIESES TESTS: geprueft ist hier nur der ZUSTANDSWECHSEL. Der Reflex nimmt
    # zusaetzlich die letzte Eingabe zurueck (`@table_monitor.undo`) — das laesst sich mit
    # dieser schlanken Fixture nicht pruefen: `TableMonitor#undo` (:1482) braucht
    # `data["current_inning"]` und PaperTrail-Versionen und wirft sonst ausserhalb von
    # production (:1549). Diese Haelfte ist am Display belegt (Betreiber, 2026-09-23) und im
    # Reflex gegen Fehlschlag abgesichert.
  end

  # ---------------------------------------------------------------
  # T7 (AC-2c): Bei Satzspielen wird der Rueckweg nicht angeboten.
  #
  # result_recorder.rb:477-480 schreibt dort beim Satzende zusaetzlich
  # perform_save_current_set nach data["sets"]. Ein Zurueck muesste den gespeicherten Satz
  # mitnehmen — eigene Frage, bewusst ausserhalb dieser Phase.
  # ---------------------------------------------------------------
  test "T7: bei einem Satzspiel erscheint kein Rueckweg" do
    prepare_final(result_a: 2, result_b: 1, current_element: "protocol_final")
    # simple_set_game? (table_monitor.rb:1859) verlangt free_game_form "pool" (und eine
    # Disziplin ungleich "14.1 endlos") oder "snooker".
    @tm.update!(data: @tm.data.merge(
      "free_game_form" => "pool",
      "sets_to_win" => 3,
      "sets" => [{"Ergebnis1" => 1, "Ergebnis2" => 0}]
    ))
    @tm.reload
    assert @tm.simple_set_game?, "VORBEDINGUNG: der Monitor muss ein Satzspiel sein"

    refute render_modal.at_css("[data-reflex='click->GameProtocolReflex#back_to_game']"),
      "Bei Satzspielen ist ein Zurueck nicht folgenlos (data[\"sets\" ] wurde schon geschrieben)"
  end
end
