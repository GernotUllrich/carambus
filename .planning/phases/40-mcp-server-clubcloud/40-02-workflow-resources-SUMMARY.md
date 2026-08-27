---
phase: 40-mcp-server-clubcloud
plan: "02"
subsystem: infra
tags: [mcp, ruby-sdk, resources, markdown, clubcloud, workflow-doku, deutsch]

requires:
  - phase: 40-01-foundation
    provides: McpServer::Server.build mit zentralem resources_read_handler-Dispatcher; MCP::Resource-Klasse verfügbar

provides:
  - 5 DE-Markdown-Dateien unter docs/managers/clubcloud-scenarios/ (Szenarien + Meta-Ressourcen)
  - McpServer::Resources::WorkflowScenarios.all + .read(slug:) — 3 MCP::Resource-Instanzen
  - McpServer::Resources::WorkflowMeta.all + .read(key:) — 2 MCP::Resource-Instanzen
  - 11 Minitest-Tests grün (6 WorkflowScenarios + 5 WorkflowMeta)

affects:
  - 40-03-api-resources (gleiche Wave-2-Konfliktfreiheit — kein eigener Handler)
  - 40-04-read-tools (D-18 Acceptance-Story-Foundation: cc://workflow/scenarios/teilnehmerliste-finalisieren verfügbar)
  - 40-05-write-tool (cc-roles.de.md erklärt D-11 trust-CC-and-parse-error-Pattern)

tech-stack:
  added: []
  patterns:
    - "SCENARIOS/META-Hash als Slug-Whitelist (T-40-02-01 Path-Traversal-Schutz — kein Pathname-Join mit unkontrolliertem Input)"
    - "Plan 01 zentraler resources_read_handler-Dispatcher bleibt unangetastet — Plan 02 exponiert nur .all + .read"
    - "DE-Markdown-Content unter docs/managers/clubcloud-scenarios/ mit [SME-CONFIRM]-Markern verbatim aus DRAFT"

key-files:
  created:
    - docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md
    - docs/managers/clubcloud-scenarios/player-anlegen.de.md
    - docs/managers/clubcloud-scenarios/endrangliste-eintragen.de.md
    - docs/managers/clubcloud-scenarios/cc-roles.de.md
    - docs/managers/clubcloud-scenarios/cc-glossary.de.md
    - lib/mcp_server/resources/workflow_scenarios.rb
    - lib/mcp_server/resources/workflow_meta.rb
    - test/mcp_server/resources/workflow_scenarios_test.rb
    - test/mcp_server/resources/workflow_meta_test.rb
  modified: []

key-decisions:
  - "Plan 02 registriert KEINEN eigenen resources_read_handler — Plan 01's zentraler Dispatcher in server.rb übernimmt gesamtes Routing (Wave-2-Konfliktfreiheit gesichert)"
  - "[SME-CONFIRM]-Marker aus DRAFT bleiben verbatim unaufgelöst in allen 5 DE-Markdown-Dateien (Resolution in Phase F oder separatem Doc-Promotion-Workflow)"
  - "Alle 5 Dateien enthalten [SME-CONFIRM]-Marker (5/5) — Info 12 erlaubt 4 oder 5; Glossar-Datei enthält 1 inferenz-markierten Begriff (Branch)"

patterns-established:
  - "Pattern: Resource-Klasse exponiert .all (Array<MCP::Resource>) + .read (String) — Plan 01 Dispatcher übernimmt Routing-Verantwortung"
  - "Pattern: Whitelist-Hash (SCENARIOS / META) als erste Verteidigung gegen Path-Traversal — unbekannte Keys/Slugs → Not-Found-String (keine Exception)"

requirements-completed: [D-01, D-05, D-06, D-07, D-17, D-18]

duration: 5min
completed: "2026-05-07"
---

# Phase 40 Plan 02: Workflow-Resources Summary

**5 DE-Markdown-Workflow-Szenarien aus DRAFT extrahiert + 2 MCP-Resource-Klassen (WorkflowScenarios.all/.read + WorkflowMeta.all/.read) mit 11 grünen Tests — Plan 01's zentraler Dispatcher bleibt unangetastet**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-07T04:27:47Z
- **Completed:** 2026-05-07T04:32:14Z
- **Tasks:** 3
- **Files erstellt:** 9

## Accomplishments

- 5 DE-Markdown-Dateien unter `docs/managers/clubcloud-scenarios/` aus `.planning/clubcloud-admin-appendix-DRAFT.md` extrahiert — alle `[SME-CONFIRM]`-Marker verbatim erhalten (5/5 Dateien enthalten Marker, Plan-Spec erlaubt 4 oder 5)
- `McpServer::Resources::WorkflowScenarios.all` gibt 3 `MCP::Resource`-Instanzen für `cc://workflow/scenarios/*`; `.read(slug:)` liest DE-Markdown von Disk
- `McpServer::Resources::WorkflowMeta.all` gibt 2 `MCP::Resource`-Instanzen für `cc://workflow/roles` und `cc://workflow/glossary`; `.read(key:)` liest entsprechende DE-Markdown-Datei
- 11 Minitest-Tests grün — inklusive `server.build`-Integrationstests, die verifizieren dass Plan 01's zentraler Dispatcher alle 5 `cc://workflow/*`-URIs korrekt registriert

## Task Commits

Jeder Task wurde atomar committed:

1. **Task 1: 5 DE Markdown-Dateien extrahiert** — `1ff0d55b` (docs)
2. **Task 2: WorkflowScenarios + WorkflowMeta implementiert** — `d04ae748` (feat)
3. **Task 3: Resource-Tests erstellt** — `a30f6ed5` (test)

## Files Created/Modified

- `docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md` — Szenario 1: Teilnehmerliste finalisieren (aus DRAFT-Sektion "Scenario 1")
- `docs/managers/clubcloud-scenarios/player-anlegen.de.md` — Szenario 2: Spieler nicht in CC-DB (aus DRAFT-Sektion "Scenario 2")
- `docs/managers/clubcloud-scenarios/endrangliste-eintragen.de.md` — Szenario 3: Endrangliste eintragen (aus DRAFT-Sektion "Scenario 3")
- `docs/managers/clubcloud-scenarios/cc-roles.de.md` — Rollenmodell-Tabelle mit D-11-Referenz
- `docs/managers/clubcloud-scenarios/cc-glossary.de.md` — Glossar mit 7 Begriffen (Branch, Endrangliste, Meldeliste, Spielbericht, Spielerdatenbank, Sportwart-Ebenen, Teilnehmerliste)
- `lib/mcp_server/resources/workflow_scenarios.rb` — WorkflowScenarios-Klasse mit SCENARIOS-Whitelist-Hash
- `lib/mcp_server/resources/workflow_meta.rb` — WorkflowMeta-Klasse mit META-Hash
- `test/mcp_server/resources/workflow_scenarios_test.rb` — 6 Tests für WorkflowScenarios
- `test/mcp_server/resources/workflow_meta_test.rb` — 5 Tests für WorkflowMeta

## Quellzuordnung (D-07 Pflicht)

| Datei | DRAFT-Quelle | Abschnitt |
|-------|-------------|-----------|
| `teilnehmerliste-finalisieren.de.md` | `.planning/clubcloud-admin-appendix-DRAFT.md` | "Scenario 1: Teilnehmerliste needs finalization in CC" |
| `player-anlegen.de.md` | `.planning/clubcloud-admin-appendix-DRAFT.md` | "Scenario 2: A participant is not in the CC player database" |
| `endrangliste-eintragen.de.md` | `.planning/clubcloud-admin-appendix-DRAFT.md` | "Scenario 3: The tournament needs an Endrangliste in CC" |
| `cc-roles.de.md` | `.planning/clubcloud-admin-appendix-DRAFT.md` | "The ClubCloud role model" |
| `cc-glossary.de.md` | `.planning/clubcloud-admin-appendix-DRAFT.md` | Querschnitt aus allen Abschnitten (Branch, Meldeliste, etc.) |

## Audit: Plan 02 ruft resources_read_handler NICHT auf (Blockers 2+3)

```
grep -c "install_read_handler\|resources_read_handler" \
  lib/mcp_server/resources/workflow_scenarios.rb \
  lib/mcp_server/resources/workflow_meta.rb
→ 0 / 0  (verifiziert)
```

Plan 02 hat `server.rb` **nicht modifiziert** — Wave-2-Konfliktfreiheit gesichert.

## [SME-CONFIRM]-Marker-Zählung (Info 12)

Dateien mit mindestens einem `[SME-CONFIRM]`-Marker: **5 von 5**

- `teilnehmerliste-finalisieren.de.md`: 2 Marker (Fehlertext, UI-Wording)
- `player-anlegen.de.md`: 4 Marker (Preflight-Fehler, Gast-Mechanismus, 2x)
- `endrangliste-eintragen.de.md`: 1 Marker (automatische Berechnung)
- `cc-roles.de.md`: 1 Marker (Rollennames + Turnierleiter-Finalisierungsrechte)
- `cc-glossary.de.md`: 1 Marker (Branch-Definition inferiert)

**Gesamt: 5 Dateien** (Plan-Spec erlaubt 4 oder 5 — ✓ erfüllt)

## Decisions Made

- **Wave-2-Konfliktfreiheit:** Plan 02 registriert keinen eigenen `resources_read_handler`. Plan 01's `install_central_read_handler` in `server.rb` routet `cc://workflow/scenarios/*` und `cc://workflow/(roles|glossary)` an `WorkflowScenarios.read(slug:)` / `WorkflowMeta.read(key:)`. Plans 02 + 03 können parallel laufen.
- **5/5 [SME-CONFIRM]-Marker:** Alle fünf Dateien enthalten mindestens einen Marker. Das Glossar enthält einen inferred-Definition-Marker für "Branch" (nicht explizit im DRAFT definiert, aber im CC-API-Kontext verwendet). Info 12 erlaubt 4 oder 5 — damit erfüllt.
- **Keine Exception aus .read:** Unbekannte Slugs/Keys geben einen menschenlesbaren Not-Found-String zurück statt eine Exception zu werfen — konsistent mit dem MCP trust-CC-and-parse-error-Pattern (D-11).

## Deviations from Plan

### Auto-fixierte Probleme

**1. [Rule 1 - Bug] grep-Prüfung auf `resources_read_handler` traf Kommentare**
- **Found during:** Task 2 (Implementierung, Verifikationsschritt)
- **Issue:** Die Akzeptanzkriterien prüfen per `grep -c "install_read_handler|resources_read_handler"` dass kein Handler-Aufruf existiert. Initialversion der Kommentare in `workflow_scenarios.rb` enthielt den Begriff `resources_read_handler` in einem erläuternden Kommentar → grep zählte 1 statt 0.
- **Fix:** Kommentar umformuliert ("besitzt den zentralen Dispatcher" statt "besitzt den resources_read_handler") — fachliche Aussage identisch, grep-Check besteht.
- **Files modified:** `lib/mcp_server/resources/workflow_scenarios.rb`
- **Verification:** `grep -c "install_read_handler\|resources_read_handler" ... → 0/0`
- **Committed in:** `d04ae748` (Task 2 commit)

---

**Total Deviations:** 1 auto-fixed (Rule 1 — Kommentar-Wording)
**Impact:** Kein Scope-Creep. Fachlicher Inhalt des Kommentars identisch — nur grep-kompatible Formulierung.

## Issues Encountered

Keine. Alle Akzeptanzkriterien auf Anhieb erfüllt (nach Kommentar-Fix).

## User Setup Required

Keine — Plan 02 enthält keine externe Service-Konfiguration. Die DE-Markdown-Dateien unter `docs/managers/clubcloud-scenarios/` werden von der `docs_auto_rebuild`-Infrastruktur (Listen-Watcher) bei `mkdocs build` eingeschlossen, sofern `mkdocs.yml` die Sektion referenziert (nicht Teil dieses Plans).

## Next Phase Readiness

- **Plan 03 (api-resources):** Kann unabhängig starten — gleiche Wave-2-Architektur (`.all` + `.read(action:)` exponieren, kein eigener Handler).
- **Plan 04 (read-tools):** D-18 Acceptance-Story-Foundation komplett — `cc://workflow/scenarios/teilnehmerliste-finalisieren` ist lesbar über Plan 01's Dispatcher.
- **Plan 05 (write-tool):** `cc-roles.de.md` dokumentiert das D-11 trust-CC-and-parse-error-Pattern für Fehlerbehandlung.
- **Kein Blocker** für weitere Wave-2-Ausführung.

## Known Stubs

Keine. Alle `.read`-Methoden geben echten Disk-Content zurück, nicht Hardcoded-Strings. Not-Found-Bodies sind definiertes Fehlerverhalten, keine Platzhalter.

## Self-Check: PASSED

- FOUND: `docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md`
- FOUND: `lib/mcp_server/resources/workflow_scenarios.rb`
- FOUND: `lib/mcp_server/resources/workflow_meta.rb`
- FOUND: `test/mcp_server/resources/workflow_scenarios_test.rb`
- FOUND: `test/mcp_server/resources/workflow_meta_test.rb`
- Commit `1ff0d55b` (Task 1) — verifiziert
- Commit `d04ae748` (Task 2) — verifiziert
- Commit `a30f6ed5` (Task 3) — verifiziert

---
*Phase: 40-mcp-server-clubcloud*
*Completed: 2026-05-07*
