# Spieler in ClubCloud anlegen

> **Status:** Aus `.planning/clubcloud-admin-appendix-DRAFT.md` (Phase 36c) extrahiert. `[SME-CONFIRM]`-Marker bleiben verbatim — Auflösung in einem zukünftigen Doc-Promotion-Workflow.

## Szenario

**Carambus-Symptom:** Die Vorprüfung bei der Finalisierung der Teilnehmerliste (oder der Upload selbst) lehnt einen Teilnehmer ab, weil er keinen passenden CC-Spielerdatensatz hat. **[SME-CONFIRM]** ob die Vorprüfung heute eine klare Fehlermeldung oder eine verwirrende Meldung liefert.

**Ursache:** Jeder Ergebnis-Upload wird einer CC-Spieler-ID zugeordnet. Wenn ein in Carambus bekannter Teilnehmer keinen CC-Datensatz hat, hat CC keine Möglichkeit, das Ergebnis zuzuordnen.

## Typische Ursachen

1. **Neuer Spieler** — jemand, der sein erstes Turnier spielt und noch nie in CC registriert wurde. Der Verein soll ihn vor dem Turnier registrieren, aber in der Praxis wird dies oft übersehen.
2. **Spieler aus einem anderen Verein** — der Spieler existiert in CC, aber unter dem Roster eines anderen Vereins, und die Turnierkonfiguration verweist auf ein bestimmtes Vereins-Roster.
3. **Tippfehler** — der Name des Spielers in Carambus stimmt aufgrund einer Schreib- oder Formatierungsdifferenz nicht genau mit dem CC-Datensatz überein.
4. **Gast** — jemand, der als einmaliger Gast spielt und NICHT in die CC-Spielerdatenbank aufgenommen werden sollte. **[SME-CONFIRM]** ob CC überhaupt einen "Gast"-Mechanismus hat oder ob Gäste anders behandelt werden (z.B. vom Upload ausgeschlossen). **[SME-CONFIRM]**

## Aktuelle Handhabung (v7.0)

- **Tippfehler-Fall:** Der Turnierleiter korrigiert den Namen in Carambus, sodass er mit CC übereinstimmt.
- **Neuer Spieler / anderer Verein / echter Fehlfall:** Jemand mit Club-Sportwart+-Rechten in CC muss den Spielerdatensatz hinzufügen, bevor der Upload fortgesetzt werden kann. Gleiche Übergabe-Abfolge wie in Szenario 1.
- **Gast-Fall:** **[SME-CONFIRM]** — wahrscheinlich manuell vom Upload ausgeschlossen; wahrscheinlich fehleranfällig.

## Geplante Handhabung (v7.1)

Carambus CCI-05 (Vorprüfung) + CCI-06 (Fehlender-Spieler-Flow) werden die fehlende-Spieler-Situation BEVOR der Turnierleiter den Upload versucht aufzeigen, mit einer klaren Liste fehlender Namen und den verfügbaren Optionen je nach der aktuellen CC-Rolle des Benutzers:

- Wenn der Benutzer Club-Sportwart+-Rechte hat: Ein-Klick-Hinzufügen zu CC.
- Wenn nicht: Übergabebericht mit den fehlenden Namen, der Ziel-CC-Rolle und einer Rückrufnummer aus dem Credentials-Profil (CCI-07).

## Carambus-Sicht

Das MCP-Tool `cc_search_player` (Plan 04 Read-Tool) ermöglicht die Suche nach Spielern in der CC-Datenbank, um zu prüfen, ob ein Spieler bereits registriert ist. Ein zukünftiges Write-Tool `cc_add_player` (auf Phase 40.1 verschoben) würde den eigentlichen Anlege-Prozess in CC automatisieren. Bis dahin muss die Spieleranlage manuell im CC-Admin-UI durch eine Person mit Club-Sportwart+-Rechten erfolgen.

*Quelle: .planning/clubcloud-admin-appendix-DRAFT.md (Phase 36c, 2026-04-14). [SME-CONFIRM]-Marker bleiben unaufgelöst — Resolution in einem zukünftigen Doc-Promotion-Workflow.*
