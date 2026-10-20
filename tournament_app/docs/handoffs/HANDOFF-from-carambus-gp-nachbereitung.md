# Handoff von Carambus: Nachbereitung 23. DBU Grand Prix Biathlon (17.–18.10.2026)

**Von:** Carambus (Paul, `carambus_bcw`)
**An:** Turnier-App (`tournament_app/`)
**Datum:** 2026-10-20
**Quelle:** Rückmeldung des Betreibers nach dem Turnier

Vier Befunde. **D ist auf der Carambus-Seite gebaut** und braucht nur noch eine Zeile in der
App; **A, B und C liegen bei euch**.

---

## A) Endrunde: Paarungen beim Übergang noch ändern können

**Befund:** Zu Turnierbeginn wurde für das Viertelfinale auf ein anderes Schema gewechselt:
Gruppenerste und -zweite **über Kreuz** statt der Setzung 1–8, 5–4, 3–6, 7–2 aus der
Gesamtrangliste der Gruppenphase. Das ging nur per Patch mit Claude-Hilfe.

**Wunsch des Betreibers:** Beim Übergang in die Endrunde Eingriffsmöglichkeiten in die
Definition der Paarungen — mindestens:

- das Schema wählen (gesetzt nach Rangliste / Gruppen über Kreuz), und
- Paarungen von Hand tauschen,

solange noch kein KO-Spiel gestartet ist (dieselbe Grenze wie bei „✎ Korrigieren“).

**Folge für die Doku:** `docs/managers/tournament-app.*.md` (Abschnitt `#gp-biathlon`, seit
`0734fe08` live) beschreibt nur „KO gesetzt“. Sobald die Wahl da ist, bitte melden — Carambus
zieht die Doku nach.

## B) Spielreihenfolge der Gruppenphase nach dem DBU-Zeitplan

**Befund:** Der DBU-Zeitplan gibt Partie-Nr., Uhrzeit und Tisch fest vor, gruppenübergreifend
verschränkt. Die App bildet ihre Runden selbst. Beim Turnier mussten deshalb die jeweils
fälligen Spiele herausgesucht werden, und die Rundennummern der App passten nicht zu den
Zeitfenstern (der Betreiber hat sie auf dem Zeitplan von Hand als R1–R5 notiert).

Auszug aus dem Zeitplan (Vorrunde, 17.10.; vier Tische, je Zeitfenster vier Partien):

| Zeit | Partien |
|---|---|
| 09:00 | 1, 5, 2, 6 |
| 10:00 | 3, 7, 4, 8 |
| 11:00 | 9, 13, 10, 14 |
| 12:00 | 11, 15, 17, 21 |

**Wunsch:** Die App übernimmt die Reihenfolge des DBU-Zeitplans — Partie-Nr. je Spiel, und
die Runde (`round_no` an `start_game`) = Zeitfenster. Offen: Gibt es die DBU-Spielfolge als
feste Tabelle je Gruppengröße (Ausschreibung/Teilungsliste), oder entsteht sie nur auf dem
Zeitplan-Blatt? Das Foto des Blatts hat der Betreiber; bei Bedarf bitte bei ihm anfragen.

## C) Spieler vertauscht — Ursache finden

**Befund:** Das Vertauschen der Spieler musste beim Turnier händisch in der App nachgearbeitet
werden (fehleranfällig). Der Betreiber: In der **Sicherung vom Turnierende** tauchen alle
Spiele auf, bei denen händisch getauscht wurde.

**Eigentlich sollte das nicht nötig sein:**

- Beim Ausstoßen tauscht `TableMonitor#switch_players` auch die Rollen der
  GameParticipations (`app/models/table_monitor.rb` ~Z. 861), außer bei `fixed_display_left`.
- `acknowledge_result` liefert `participants[]` mit Spieler-Identität je Ergebnis
  (`serialize_ack_participants`).
- `mapAckResult` ordnet darüber zu und fällt nur auf die Position zurück, wenn
  `samePlayer` nicht eindeutig trifft (dann `console.warn`).

**Bitte:** Die End-Sicherung auswerten (der Betreiber stellt sie bereit; auf dem Entwicklungsrechner liegen
nur die Probelauf-Sicherungen vom 13.10.):

1. Welche Spiele haben `gameUI.swapped = true` bzw. ein gedrehtes Ergebnis?
2. Kam das Ergebnis dort per Identität (`byIdentity`) oder per Position?
3. Wenn per Position: Warum traf `samePlayer` nicht — `cc_id`/`dbu_nr` des Plan-Spielers
   gegen `participants[].player`?
4. Oder ging es gar nicht ums Ergebnis, sondern darum, dass die App die Spieler in anderer
   Reihenfolge zeigt als das Scoreboard?

Ein Verdacht zu 3: `samePlayer` vergleicht zuerst die `cc_id` und entscheidet sofort, wenn
beide eine haben — auch wenn die `dbu_nr` übereinstimmt. Die `cc_id` ist nur je Landesverband
eindeutig (vgl. `3a06af63`, 13.10.: zwei Spieler aus BVW und NBV teilen die `cc_id` 10050).

## D) Mehrtägige App-Turniere: `end_date` beim Anlegen — Carambus-Seite fertig

**Befund:** Über Nacht wurden die Tische des Turniers freigegeben und der Monitor
geschlossen, obwohl am Abend schon Spiele angesetzt waren. Ursache: Der Mitternachtslauf
(00:01, `TableReleaser.release_stale_local`) verschont ein lokales App-Turnier nur, wenn sein
`end_date` in der Zukunft liegt — und `POST tournament` nahm bisher kein `end_date` an.
„Ansetzen zurücknehmen“ (`cancel_game`) repariert nur die Folgen.

**Gebaut (`3cc3fbe9`, noch nicht auf bc-wedel deployt):** `POST /api/external_tournament/tournament`
nimmt optional `end_date` an:

- `"YYYY-MM-DD"` = letzter Turniertag; gilt bis **Ende** dieses Tages (sonst gälte das
  Turnier in der Nacht vor dem letzten Tag schon als beendet).
- oder ein ISO-Zeitpunkt.
- Auch beim idempotenten zweiten Aufruf nachreichbar (bestehendes Turnier).
- Ungültig → 422. Fehlt das Feld → Verhalten wie bisher.
- Antwort trägt `tournament.end_date` (ISO).

**Bitte in der App:** Beim Anlegen eines mehrtägigen Turniers den letzten Turniertag als
`end_date` mitschicken (GP: Tag 2). Für ein schon angelegtes Turnier reicht derselbe Aufruf
mit `end_date`.

Der Hinweis in der App „Der Server raeumt App-Turniere nachts noch ab. Bis Carambus das
abstellt, schuetzt nur ein end_date in der Zukunft.“ (`tournament_app/schemes/plan/index.html` ~Z. 2693)
stimmt dann für Turniere mit `end_date` nicht mehr in dieser Schärfe.
