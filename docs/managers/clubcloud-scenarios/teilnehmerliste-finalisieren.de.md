# Teilnehmerliste in ClubCloud finalisieren

> **Status:** Aus `.planning/clubcloud-admin-appendix-DRAFT.md` (Phase 36c) extrahiert. `[SME-CONFIRM]`-Marker bleiben verbatim — Auflösung in einem zukünftigen Doc-Promotion-Workflow.

## Szenario

**Carambus-Symptom:** Der Turnierleiter versucht Spielergebnisse hochzuladen und bekommt eine Fehlermeldung wie "Teilnehmerliste ist noch nicht finalisiert in ClubCloud". **[SME-CONFIRM]** den genauen Fehlertext, den der Benutzer sieht.

**Ursache:** ClubCloud akzeptiert keine Einzel- oder CSV-Ergebnis-Uploads, solange die Teilnehmerliste für das betreffende Turnier auf der CC-Seite nicht als "finalisiert" markiert ist. Die Finalisierung ist eine Einweg-Aktion, die die Teilnehmerliste sperrt, damit CC die Identität jedes Ergebnisses vertrauen kann.

## Aktuelle Handhabung (v7.0)

Der Turnierleiter öffnet einen zweiten Browser-Tab, meldet sich in ClubCloud an, navigiert zur Admin-Seite des Turniers, klickt auf den Button "Teilnehmerliste finalisieren" (oder entsprechendes — **[SME-CONFIRM]** die genaue CC-UI-Bezeichnung), bestätigt und kehrt dann zu Carambus zurück, um den Upload erneut zu versuchen.

## Übergabe wenn der Turnierleiter nicht die nötige Berechtigung hat

Wenn der Turnierleiter NICHT über Club-Sportwart- oder höhere CC-Rechte verfügt, muss die Finalisierung von jemandem durchgeführt werden, der diese Rechte hat. In der Praxis gibt es folgende Möglichkeiten:

1. **Telefonanruf beim Club-Sportwart** — der Turnierleiter ruft den Sportwart des Vereins an, bittet ihn die Liste zu finalisieren, wartet auf Bestätigung und versucht dann den Upload erneut.
2. **Geteilte CC-Zugangsdaten** **[SME-CONFIRM]** — einige Veranstaltungsorte haben historisch eine gemeinsame Club-Sportwart-Anmeldung gepflegt, die jedem Turnierleiter bekannt war. Diese Praxis ist fragil (Passworthygiene, Prüfpfad) und sollte nicht als Empfehlung dokumentiert werden.
3. **Turnier-Vorbereitung** — der Club-Sportwart finalisiert die Teilnehmerliste am Tag vor dem Turnier, bevor der Turnierleiter überhaupt ankommt. Das erfordert, die endgültige Teilnehmerliste 24 Stunden im Voraus zu kennen, was nicht immer möglich ist (Last-Minute-Anmeldungen, Ersatzspieler, kurzfristige Absagen).

## Geplante Handhabung (v7.1)

Carambus CCI-04 wird einen Button "Teilnehmerliste finalisieren" innerhalb von Carambus hinzufügen, der die CC-API direkt aufruft. Wenn der aktuelle Carambus-Benutzer die erforderliche CC-Rolle hat, reicht ein Klick. Wenn nicht, erstellt Carambus einen Übergabebericht mit der genauen Person zum Anrufen und dem genauen Wiederaufnahmepunkt, an dem man nach Abschluss der Finalisierung weitermachen kann. Siehe `.planning/milestones/v7.1-REQUIREMENTS.md` CCI-04..08.

## Carambus-Sicht

Wenn der Carambus-Server das MCP-Tool `cc_lookup_teilnehmerliste` (Plan 04) erreicht, prüft es den Status der Liste. Das Write-Tool `cc_finalize_teilnehmerliste` (Plan 05) führt die Finalisierung über die `releaseMeldeliste`-Action aus. Der Aufruf setzt mindestens Club-Sportwart-Rechte auf CC-Seite voraus; bei fehlender Berechtigung antwortet CC mit einem Fehler, den der Server per D-11 trust-CC-and-parse-error-Pattern als strukturierten MCP-Fehler weiterreicht.

*Quelle: .planning/clubcloud-admin-appendix-DRAFT.md (Phase 36c, 2026-04-14). [SME-CONFIRM]-Marker bleiben unaufgelöst — Resolution in einem zukünftigen Doc-Promotion-Workflow.*
