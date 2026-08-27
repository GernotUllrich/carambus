---
status: resolved
trigger: "Scoreboard shows old innings_list panel instead of ProtokollEditor at game end (Freie Partie klein)"
created: 2026-05-23T00:00:00Z
updated: 2026-05-23T00:00:00Z
---

## Current Focus

hypothesis: Primary root cause CONFIRMED via static analysis: key_a/key_b reflex unconditionally write assign_attributes(panel_state:"pointer_mode") then save AFTER terminate_current_inning on the SAME in-memory object, overwriting the protocol_final that set_game_over already committed to DB. A separate FAST PATH job path also reads a stale panel_state snapshot.
test: Static code trace through all panel_state write paths with state==set_over
expecting: Panel renders old innings_list when panel_state is not in [protocol, protocol_edit, protocol_final]
next_action: RESOLVED 2026-05-24 (FINAL `49284aec`) — before_save-Invariante: state==set_over => panel_state="protocol_final" (app/models/table_monitor.rb#enforce_protocol_final_panel_at_set_over). Pfad-unabhaengiger Chokepoint -> Scoreboard schaltet IMMER direkt in den ProtokollEditor (final-mode, "Fertig"=confirm_result advanced), nie der seltene "...OK?"/altes-innings_list-Umweg. User-bestaetigt: normalerweise direkt Editor, nur selten der Umweg. Bypass-Switch = player_controlled? (tournament.player_controlled?; steuert locked_scoreboard/wait_check, NICHT die Panel-Wahl). Zwischenfix b5d6a72c (protocol_modal_should_be_open? || set_over?) war FALSCH (oeffnete Modal im VIEW-mode -> "Fertig"=close_protocol -> Falle) und wurde in 49284aec zurueckgenommen. Test table_monitor_protocol_modal_test.rb (5, before_save). Regression 135/0. Commits master (NICHT gepusht): 9b47f330 (Reflex-Guards, defense-in-depth) + b5d6a72c (revertiert) + 49284aec (finaler Fix). Deploy = Tip 49284aec.
ALT (Iteration 2, b5d6a72c — Override, FALSCH/revertiert): ECHTE WURZEL via Live-State (production TM #50000002): state="set_over", panel_state="inputs" (current_element "add_10"), APP-/Bridge-Spiel (game.data external_id/tournament_external_id, player_controlled). Der erste Fix `9b47f330` (key_a/key_b/foul pointer_mode-Guards) war UNVOLLSTAENDIG — der panel_state kommt hier aus dem Karambol-EINGABE-MODUS (panel_state="inputs", an 5+ Stellen gesetzt: add_n/numbers/...), nicht aus pointer_mode. Robuster pfad-unabhaengiger Fix `b5d6a72c`: protocol_modal_should_be_open? liefert bei set_over? IMMER true (app/models/table_monitor.rb:684). Damit kein altes innings_list-Panel + Protokoll-Modal offen, egal welcher Pfad den panel_state hinterlaesst. Test test/models/table_monitor_protocol_modal_test.rb (4). Regression 134/0. Beide Commits master, NICHT gepusht — User deployt. Frueheres next_action (nur 9b47f330) war voreilig "resolved".
ALT (unvollstaendig): Fix committed `9b47f330` (carambus_master, master, NICHT gepusht). Strategie B: das unbedingte `assign_attributes(panel_state:"pointer_mode")` in key_a/key_b/balls_left/foul_two/foul_one mit `unless @table_monitor.set_over?` geguardet (7 Stellen; `outside` Z.106 bewusst unberührt). Regressionstest test/reflexes/table_monitor_reflex_test.rb (4/6). Regression 130 runs / 0 failures; geänderte Zeilen standardrb-clean. Globaler Model-Eingriff (protocol_modal_should_be_open? || set_over?) + Render-Chokepoint als optionale Härtung VERWORFEN (größerer Blast-Radius; Pool/Snooker-Verhalten). User pusht selbst.

## Symptoms

expected: Bei Spielende (Set/Partie vorbei) zeigt das Scoreboard den ProtokollEditor (Game-Protocol-Modal, current_element=confirm_result)
actual: SELTEN erscheint stattdessen das alte per-Spieler-Panel mit der Aufn/Pkt/∑-Tabelle (render_innings_list); beobachtet bei Disziplin "Freie Partie klein" (Karambol, table_kind Small Billard)
errors: Keine Exceptions. Reines Render-/State-Problem.
reproduction: Nicht zuverlässig reproduzierbar — tritt relativ selten auf (Race Condition). Disziplin karambol/freie_partie_klein.
started: "Ganz altes Problem", tritt wiederkehrend selten auf.

## Eliminated

- hypothesis: Render selbst liefert falsches Template durch options-Race im TableMonitorJob
  evidence: TableMonitorJob L251-254 macht deep_dup von options_snapshot vor dem Render. Das schützt options aber nicht panel_state — panel_state kommt direkt vom table_monitor-Objekt das freshly geladen wird (L35). options-Race ist kein Faktor für panel_state.
  timestamp: 2026-05-23

- hypothesis: evaluate_panel_and_current (L1023-1096) setzt panel_state auf etwas anderes
  evidence: Methode ist nur aktiv wenn remote_control_detected == true (L1024), das immer false zurückgibt (L542-543: "TODO: Test remote control"). Dieser Pfad ist inaktiv.
  timestamp: 2026-05-23

- hypothesis: TableMonitorValidationJob ist die Hauptursache der Race
  evidence: Dieser Job setzt state = 'set_over' direkt via write_attribute (L158, L163, L174) und überschreibt panel_state auf "pointer_mode" (L49). ABER: Es gibt keine perform_later-Aufrufe für diesen Job im gesamten App-Code (grep zeigt keinen Aufrufer). Der Job scheint "tot" zu sein — kein aktiver Aufrufpfad gefunden. Er bleibt als theoretisches Risiko (AASM-bypass via direct assignment), aber ist nicht der wahrscheinlichste Auslöser.
  timestamp: 2026-05-23

- hypothesis: TableMonitorClockJob überschreibt panel_state
  evidence: ClockJob ruft nur update_columns(timer_job_id:) auf (L49) und rendert nur Timer-HTML. Kein panel_state-Write.
  timestamp: 2026-05-23

## Evidence

- timestamp: 2026-05-23
  checked: app/views/table_monitors/_player_score_panel.html.erb L110, L227-228
  found: Render-Zweig: `if !table_monitor.set_over? || table_monitor.protocol_modal_should_be_open?` → Live-Scoreboard; `else` → render_innings_list (alte Tabelle). Die alte Tabelle erscheint GENAU wenn state=="set_over" UND panel_state ∉ {protocol, protocol_edit, protocol_final}.
  implication: Das alte Panel ist ein direkter Indikator für state=set_over + panel_state=something_else. Root Cause MUSS ein panel_state-Überschreib-Pfad sein der NACH set_game_over läuft.

- timestamp: 2026-05-23
  checked: app/models/table_monitor.rb L546-561 (set_game_over), L341 (AASM after_enter)
  found: set_game_over wird als AASM after_enter-Callback auf state :set_over ausgelöst. Es setzt panel_state="protocol_final" + current_element="confirm_result" und ruft save. Dieser save triggert after_update_commit → enqueued TableMonitorJob("") für full scoreboard render.
  implication: Die korrekte Persistenz findet INNERHALB des terminate_current_inning-Transaktionsblocks statt (L1149-1158: TableMonitor.transaction { ... save! → evaluate_result → end_of_set! → set_game_over → save }). Das DB-Record hat panel_state="protocol_final" nach diesem Block.

- timestamp: 2026-05-23
  checked: app/reflexes/table_monitor_reflex.rb L137-178 (key_a) und L199-240 (key_b)
  found: PRIMARY RACE PATH. In beiden key_a und key_b:
    STEP 1 (L147/161): terminate_current_inning wird aufgerufen → läuft tief durch → end_of_set! → set_game_over setzt panel_state="protocol_final" → save auf dem GLEICHEN @table_monitor-Objekt.
    STEP 2 (L152-153): do_play wird aufgerufen (no-op wenn kein timeout).
    STEP 3 (L153/164): assign_attributes(panel_state: "pointer_mode", current_element: "pointer_mode") → ÜBERSCHREIBT panel_state="protocol_final" auf dem in-memory Objekt.
    STEP 4 (L177): @table_monitor.save → schreibt panel_state="pointer_mode" in die DB. LOST UPDATE.
  implication: DIREKTE, DETERMINISTISCHE Überschreibung. Dies ist KEINE klassische Race Condition zwischen zwei Threads/Jobs — es ist ein single-threaded lost-update-Bug auf dem GLEICHEN Objekt innerhalb eines einzigen reflex-Aufrufs.

- timestamp: 2026-05-23
  checked: app/reflexes/table_monitor_reflex.rb L153/164 vs L147/161 — Ausführungsreihenfolge
  found: Wenn terminate_current_inning() das Ziel erreicht (result==:goal_reached via evaluate_result → end_of_set!), setzt set_game_over panel_state="protocol_final" per save(). Danach führt key_a/key_b BEDINGUNGSLOS assign_attributes(panel_state:"pointer_mode") aus — kein guard prüft ob wir inzwischen in set_over gewechselt sind.
  implication: Der Bug tritt IMMER auf wenn das Ziel GENAU beim key_a/key_b-Press erreicht wird (letzter Punkt durch die A/B-Taste), was erklärt warum er bei Karambol vorkommt (Aufnahme-Abschluss per A/B-Taste). Die "seltene" Beobachtung ergibt sich daraus, dass das Ziel nur bei der letzten Aufnahme erreicht wird — aber wenn es passiert, ist der Bug deterministisch.

- timestamp: 2026-05-23
  checked: app/reflexes/table_monitor_reflex.rb L81-97 (nnn_enter): set_n_balls → assign_attributes(panel_state: change_to_pointer_mode → "pointer_mode") → save. Model L1131.
  found: nnn_enter ruft @table_monitor.set_n_balls(@table_monitor.nnn, true) auf. set_n_balls (L1126-1142): assign_attributes(panel_state: change_to_pointer_mode ? "pointer_mode" : panel_state) → wenn change_to_pointer_mode=true (was nnn_enter immer als zweiten Parameter übergibt), setzt panel_state="pointer_mode" VOR save(). Dann ruft save → evaluate_result → end_of_set! → set_game_over → save (setzt protocol_final). Danach ruft set_n_balls nochmals save wenn result==:goal_reached (L1133). Dann ruft nnn_enter @table_monitor.save (L96) — und überschreibt panel_state=protocol_final mit pointer_mode NICHT nochmals (weil set_game_over auf demselben Objekt assign_attributes machte). ABER: Die assign_attributes(panel_state:"pointer_mode") in set_n_balls (L1131) passiert VOR dem save/evaluate_result-Pfad, also panel_state wird dann von set_game_over zurückgesetzt. nnn_enter scheint weniger problematisch als key_a/b.
  implication: nnn_enter ist ein sekundäres Risiko — der timing ist besser als bei key_a/b. Hauptproblem bleibt key_a/key_b.

- timestamp: 2026-05-23
  checked: app/reflexes/table_monitor_reflex.rb L309-313 (undo), L317-325 (redo), L327-351 (minus_n), L437-462 (add_n), L464-472 (set_balls), L917-928 (balls_left), L930-940 (foul_two), L942-950 (foul_one)
  found: Alle diese Reflexe setzen panel_state="inputs" oder "pointer_mode" auf dem Objekt. Diese setzen aber NICHT terminate_current_inning auf dem gleichen Pfad. Wenn der TM in state==set_over ist und einer dieser Reflexe ausgelöst wird (z.B. durch Doppelklick, Netzwerk-Duplikat), würde panel_state überschrieben werden. Keine Guards prüfen ob state==set_over vor dem panel_state-Write.
  implication: Sekundärer Risikopfad: race zwischen zwei Reflex-Aufrufen oder ungewollter zweiter Input.

- timestamp: 2026-05-23
  checked: app/models/table_monitor.rb L79-154 (after_update_commit) — FAST PATH vs SLOW PATH
  found: FAST PATH (L134-144): Wenn nur ein Spieler-Score ändert → TableMonitorJob.perform_later(id, "player_score_panel", player: player_key). Dieser Job lädt eine FRISCHE TableMonitor-Instanz (TableMonitorJob L35: TableMonitor.find(table_monitor_id)). Wenn dieser Job ZWISCHEN dem set_game_over-save (panel_state="protocol_final") und dem nachfolgenden @table_monitor.save aus key_a (panel_state="pointer_mode") enqueued und ausgeführt wird, rendert er korrekt protocol_final. Wenn er aber erst NACH dem key_a-save ausgeführt wird, rendert er die falsche pointer_mode.
  implication: Der Job liest immer fresh aus DB. Das Problem ist dass die DB zu diesem Zeitpunkt panel_state="pointer_mode" enthält, weil key_a's abschließendes save() das überschrieben hat. Der Job ist kein Verursacher, zeigt aber das falsche Ergebnis.

- timestamp: 2026-05-23
  checked: DB schema — lock_version Spalte, optimistic locking
  found: Kein lock_version in table_monitors-Schema. Kein with_lock, kein Rowlock irgendwo im TM-Code. Keine Absicherung gegen lost updates.
  implication: Multiple parallele Saves auf demselben Record sind vollständig ungeschützt.

- timestamp: 2026-05-23
  checked: app/services/table_monitor/result_recorder.rb L412-547 (perform_evaluate_result)
  found: In perform_evaluate_result, für den non-simple-set (Karambol) Pfad (L464-476): if was_playing && !is_simple_set → @tm.end_of_set! if may_end_of_set? → @tm.panel_state = "protocol_final" → @tm.current_element = ... → perform_save_result → @tm.save!. Dieser Pfad setzt panel_state direkt auf dem @tm-Objekt und speichert. Aber das ist DERSELBE @table_monitor aus key_a. Nach evaluate_result kehrt der Code zu key_a zurück wo assign_attributes(panel_state:"pointer_mode") UNCONDITIONAL folgt.
  implication: Bestätigt den key_a/key_b-Pfad als Hauptschuldigen.

- timestamp: 2026-05-23
  checked: app/services/table_monitor/result_recorder.rb L322 (perform_switch_to_next_set)
  found: perform_switch_to_next_set setzt assign_attributes(state: "playing", panel_state: "pointer_mode") und save!. Dieser Pfad ist für Multi-Satz-Spiele. Für single-set Karambol (Freie Partie klein) ist sets_to_win typisch 1 → Branch C (L498-521) → acknowledge_result! → ... → kein switch_to_next_set. Kein Issue hier für den beobachteten Fall.
  implication: perform_switch_to_next_set ist kein Faktor für Freie Partie klein.

- timestamp: 2026-05-23
  checked: app/jobs/table_monitor_validation_job.rb L155-179
  found: validate_game_state setzt table_monitor.state = 'set_over' DIREKT (kein AASM-Event), was after_enter-Callback set_game_over NICHT triggert. Zusätzlich: validate_score_update (L49) setzt panel_state="pointer_mode" unconditional. ABER: Kein Aufrufer für TableMonitorValidationJob gefunden im gesamten Codebase (grep nach 'TableMonitorValidationJob.perform_later' oder 'TableMonitorValidationJob.new' liefert nichts in app/). Dieser Job ist tot code.
  implication: Theoretisch hochgefährliches Pattern (AASM-bypass + panel_state-Reset), aber praktisch inaktiv. Bleibt Risiko falls der Job reaktiviert wird.

## Resolution

root_cause: |
  PRIMARY (deterministischer single-threaded lost-update):
  In key_a und key_b (table_monitor_reflex.rb) wird nach terminate_current_inning()
  (das intern → evaluate_result → end_of_set! → set_game_over → panel_state="protocol_final" → save führt)
  UNCONDITIONAL assign_attributes(panel_state: "pointer_mode", current_element: "pointer_mode")
  auf dem selben @table_monitor-Objekt aufgerufen, gefolgt von @table_monitor.save.
  Dieses abschließende save überschreibt panel_state="protocol_final" zurück zu "pointer_mode" in der DB.
  Das nachfolgende scoreboard-render (via after_update_commit → TableMonitorJob) liest die DB-Werte,
  findet state="set_over" + panel_state="pointer_mode", rendert den else-Zweig: render_innings_list.

  Diese Sequenz ist NICHT eine klassische concurrent race (zwei Threads), sondern ein single-threaded
  lost-update: Objekt A setzt panel_state=protocol_final via save(), dann setzt DASSELBE Objekt A
  panel_state=pointer_mode via assign_attributes (ohne reload), dann save überschreibt.

  Die "seltenheit" erklärt sich damit, dass der Bug nur eintritt wenn die A/B-Taste GENAU den
  letzten Punkt bringt (das Ziel wird beim Press erreicht). In allen anderen Fällen tritt
  terminate_current_inning gar nicht auf (oder end_of_set? false), und assign_attributes-Schreibung
  ist harmlos. Der karambol-Freie-Partie-Klein-Kontext ist typisch weil dort A/B-Taste
  häufig die Aufnahmen abschließt.

fix: KEIN Fix implementiert (diagnose-only mode). Strategien siehe unten.
verification: N/A
files_changed: []
