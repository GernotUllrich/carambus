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
    zurueck = doc.at_css("[data-action='click->table-monitor#undo']")
    assert zurueck, "Ohne diesen Knopf ist der Protokoll-Editor eine Sackgasse — der " \
      "vorhandene undo-Weg liegt unter dem Backdrop und ist nicht klickbar"

    assert_equal "table-monitor", zurueck["data-controller"],
      "Gleiche Verdrahtung wie am Scoreboard (_scoreboard.html.erb:197) — kein eigener Reflex"
    assert_equal @tm.id.to_s, zurueck["data-id"],
      "TableMonitorReflex#undo liest element.dataset[:id] (:370); ohne data-id findet er " \
      "den Monitor nicht"
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
    assert doc.at_css("[data-action='click->table-monitor#undo']"),
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
end
