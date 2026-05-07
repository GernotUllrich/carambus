# Endrangliste in ClubCloud eintragen

> **Status:** Aus `.planning/clubcloud-admin-appendix-DRAFT.md` (Phase 36c) extrahiert. `[SME-CONFIRM]`-Marker bleiben verbatim — Auflösung in einem zukünftigen Doc-Promotion-Workflow.

## Szenario

**Carambus-Symptom:** Das Turnier ist beendet. Die Ergebnisse sind über den spielweisen Upload in CC vorhanden, aber die abschließende Rangliste (Endrangliste) ist noch leer, weil CC sie nie automatisch aus den Spielergebnissen berechnet hat. **[SME-CONFIRM]** — berechnet CC irgendeine Rangliste automatisch, oder ist die Endrangliste immer ein separater manueller Eintrag? Die v7.0-Review-Notizen deuten auf Letzteres hin (F-36-34).

**Ursache:** ClubCloud berechnet derzeit keine Rangliste aus hochgeladenen Spielergebnissen. Die Endrangliste ist eine separate Datenentität, die von einem Menschen mit der richtigen CC-Rolle manuell eingetragen werden muss.

## Aktuelle Handhabung (v7.0)

Der Turnierleiter (oder Club-Sportwart, je nach Berechtigungen) schaut sich die abgeschlossenen Spiele in Carambus oder auf Papier an, berechnet die abschließende Rangliste entsprechend den Regeln der Disziplin und trägt sie manuell in die CC-Admin-Benutzeroberfläche ein. Dies ist fehleranfällig und zeitaufwendig.

## Geplante Handhabung (v7.1)

Carambus CCI-01 wird die Endrangliste aus dem Spielbaum in Ruby berechnen und in einem Vorschau-Bildschirm präsentieren. CCI-02 lässt den Turnierleiter sie überprüfen und korrigieren (insbesondere für Unentschieden, die eine manuelle Auflösung erforderten — die Stechen-Lücke aus v7.2 ist hier relevant). CCI-03 lädt die überprüfte Endrangliste per CC-API mit einem Klick hoch.

## Carambus-Sicht

Die automatische Endranglisten-Berechnung in ClubCloud ist ein geplantes Feature des v7.2 ClubCloud-Integration-Meilensteins und auf eine zukünftige Phase verschoben (per CONTEXT.md `<deferred>`). In Phase 40 fokussiert sich der MCP-Server auf Read-Lookups und die Write-Tool-Proof (`cc_finalize_teilnehmerliste`). Die Endranglisten-Funktion (`cc_submit_endrangliste`) ist Teil der Phase-40.1-Erweiterung.

*Quelle: .planning/clubcloud-admin-appendix-DRAFT.md (Phase 36c, 2026-04-14). [SME-CONFIRM]-Marker bleiben unaufgelöst — Resolution in einem zukünftigen Doc-Promotion-Workflow.*
