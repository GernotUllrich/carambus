---
quick_id: 260516-x7g
type: quick
plan: 1
working_directory: /Users/gullrich/DEV/carambus/carambus_nbv
worktree: /Users/gullrich/DEV/carambus/carambus_bcw/.claude/worktrees/agent-afc68344ece5ec5ea
scenario: bcw
tags: [mcp, clubcloud, bugfix, multi-player, save-buffer, phase-14-G.13-vorbote]
status: code-complete
commits:
  - hash: f6bdaf97
    branch: worktree-agent-afc68344ece5ec5ea
    subject: "fix(phase-14): Multi-Player-Save-Bug in cc_register_for_tournament (Quick 260516-x7g, Plan 14-G.13 Vorbote)"
files_modified:
  - lib/mcp_server/tools/register_for_tournament.rb
  - test/mcp_server/tools/register_for_tournament_test.rb
metrics:
  test_runs: 25
  test_assertions: 115
  test_failures: 0
  test_errors: 0
  test_skips: 0
  mcp_sweep_runs: 251
  mcp_sweep_failures: 0
  loc_added: 285
  loc_removed: 43
---

# Quick 260516-x7g: Multi-Player-Save-Bug-Fix in cc_register_for_tournament

## One-Liner

cc_register_for_tournament: Multi-Player-Pfad (`player_cc_ids: [...]`) implementiert
via N×add + 1×save + 1×verify, ersetzt buggy N×(add+save), behebt Buffer-Flush-Verlust.

## Was wurde gefixt

**Bug:** Sequenzielle Multi-Player-Register-Calls verloren alle Vorgänger-Adds — nur
der zuletzt gemeldete Spieler landete in der CC-Meldeliste.

**Empirische Ursache (HAR 2026-05-16):** Jeder `editMeldelisteSave` flusht den
CC-Edit-Buffer; der vorherige `addPlayerToMeldeliste`-Eintrag geht verloren. HAR
`cc_add-cc_remove-roundtrip-meissner-2026-05-16.har` zeigt cc_add+remove Roundtrip
OHNE `editMeldelisteSave` — was die Buffer-Flush-These bestätigt.

**Fix (Pattern aus `cc_assign_player_to_teilnehmerliste`, stabil seit Plan 07-04):**

1. Schema-Erweiterung um `player_cc_ids: array<int>` + `player_names: array<str>`
2. Body-Refactor:
   - N × `addPlayerToMeldeliste` (Loop, KEIN save dazwischen)
   - 1 × `saveMeldeliste` am Ende (committet alle Buffer-Adds atomar)
   - 1 × `showCommittedMeldeliste` verify (matcht alle player_cc_ids im HTML)
3. Atomare Pre-Validation-Semantik: bei Fail eines Players werden ALLE abgelehnt
4. Backwards-Compat: `player_cc_id` (singular) bleibt; intern auf `[player_cc_id]`
   normalisiert; Single-Player-Pfad ruft weiterhin genau 3 POSTs (1×add+1×save+1×verify)

## SKILL extend-before-build angewendet

- Helpers (`_validate_*`, `consistency_check`, `parse_cc_error`, `format_pre_read_status`,
  `find_player_in_region`) UNVERÄNDERT.
- `resolve_player_cc_id_from_name`-Convenience-Wrapper unverändert — Tool ruft ihn
  pro Name in einer Loop auf (analog `cc_assign_player_to_teilnehmerliste`).
- Bestehende Plan-Anker-Kommentare (Plan 10-05.1, Plan 11-04, Plan 14-G.12) bleiben
  verbatim. Neue Stellen mit Anker "Plan 14-G.13 (Quick 260516-x7g)".
- Kein neuer State-Machine-Pfad, keine neuen Abstractions — single-player wird
  einfach als 1-Element-Array-Spezialfall vom Multi-Player-Pfad bedient.

## Tests

8 neue Tests M1-M8:

- **M1** — DRY-RUN mit `player_cc_ids: [10024, 11683]` listet beide Player-IDs.
- **M2** — armed:true ruft N×add + 1×save + 1×verify in genau dieser Reihenfolge;
  `add`-Calls senden die richtigen player_cc_ids in Reihenfolge.
- **M3** — Verify-Response mit beiden Markern → `verified_in_committed_list: true`,
  `verified_player_cc_ids: [10024, 11683]`, `missing_player_cc_ids: []`.
- **M4** — Partial-Verify (nur 10024 matched) → `verified_in_committed_list: false`,
  `missing_player_cc_ids: [11683]` (zur späteren Audit-Trail-Coverage als
  `read_back_status: "partial"`).
- **M5** — Backwards-Compat: Single-Player-Input ruft genau 3 POSTs (1×add+1×save+1×verify).
- **M6** — Weder `player_cc_id` noch `player_cc_ids` gesetzt → klare Diagnose
  "missing player input".
- **M7** — Beide gesetzt → exactly-one-rule error.
- **M8** — Pre-Validation-Fail eines Players blockiert alle (atomare Semantik) +
  KEIN armed-POST darf abgesetzt werden.

**Bestehende 3 Tests adaptiert** (Output-Text-Format vereinheitlicht; Call-Signatur unverändert):

- "armed:false ... mit allen ID-Werten" → neuer Format `Would register 1 player(s) [99999]`
- "armed:true Mock-Success ruft 3 POSTs" → neuer Format `Registered 0/1 player(s)`
- "Validation: fehlendes player_cc_id" → neuer Format `missing player input`

**Test-Suite final:**
```
25 runs, 115 assertions, 0 failures, 0 errors, 0 skips
```

**MCP-Multi-Tool-Sweep (Regression-Check):**
```
251 runs, 933 assertions, 0 failures, 0 errors, 39 skips (pre-existing)
```

`bundle exec standardrb lib/mcp_server/tools/register_for_tournament.rb` exit 0.

## Manual-CC-Roundtrip-Smoketest (User-Aufgabe)

Der Smoketest läuft gegen den laufenden MCP-Server auf
`http://localhost:3010/mcp?stateless=1` (carambus_nbv production-DB-sync,
dev-credentials gesetzt).

### Sequenz: 4 Players in einem Tool-Call (Multi-Variante) → erwartet alle 4 in committed Meldeliste

```bash
# Hinweis: jq optional — ohne pipe direkt curl mit -s verifizieren.
curl -X POST "http://localhost:3010/mcp?stateless=1" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"tools/call",
    "params":{
      "name":"cc_register_for_tournament",
      "arguments":{
        "meldeliste_cc_id":1310,
        "player_cc_ids":[10024,11683,10031,10032],
        "club_cc_id":1010,
        "fed_id":20,
        "branch_cc_id":8,
        "season":"2025/2026",
        "armed":true
      }
    }
  }'

# Verify in Output:
#   "verified_in_committed_list: true"
#   "verified_player_cc_ids: [10024, 11683, 10031, 10032]"
#   "missing_player_cc_ids:  []"

# Logs prüfen (Latenz-Marker):
grep '\[CC-LATENCY\]' log/development.log | tail -10
```

### Verify-Read-Back (separat)

```bash
# Mit cc_lookup_teilnehmerliste oder direkt CC-Web-UI prüfen, dass alle 4 Spieler in
# der CC-Meldeliste sichtbar sind.
curl -X POST "http://localhost:3010/mcp?stateless=1" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "id":2,
    "method":"tools/call",
    "params":{
      "name":"cc_lookup_teilnehmerliste",
      "arguments":{"tournament_cc_id":<X>}
    }
  }'
```

### Cleanup (optional, falls Test-Daten nicht permanent bleiben sollen)

```bash
# Falls cc_unregister_for_tournament Multi-Player kann; sonst pro Player einzeln.
# Aktuell ist cc_unregister NICHT in Scope dieses Quick-Tasks — manuell via CC-Web-UI
# entfernen, falls nötig.
```

## Erfolgskriterien (für User-Validation)

- [ ] Tool-Call mit `player_cc_ids: [A,B,C,D]` zeigt im Output:
  - `verified_in_committed_list: true`
  - `verified_player_cc_ids: [A, B, C, D]`
  - `missing_player_cc_ids: []`
- [ ] CC-Web-UI bestätigt alle 4 Spieler in der Meldeliste
- [ ] Audit-Trail-Entry hat `read_back_status: "match"` (single JSON-Line in
  log/audit_trail.log; Plan-10-05.1-Format)
- [ ] Bestehende Single-Player-Aufrufe (Sportwart-Workflows von vor diesem Fix)
  laufen byte-identisch wie zuvor

## Commit-Details

- **Hash:** `f6bdaf97`
- **Branch:** `worktree-agent-afc68344ece5ec5ea` (worktree-lokal, kein push noch)
- **Files:** 2 (lib/mcp_server/tools/register_for_tournament.rb,
  test/mcp_server/tools/register_for_tournament_test.rb)
- **LoC:** +285 / -43

## Self-Check: PASSED

- Commit `f6bdaf97` exists in worktree HEAD.
- Files `lib/mcp_server/tools/register_for_tournament.rb` and
  `test/mcp_server/tools/register_for_tournament_test.rb` modified per plan
  spec.
- All 25 tests GREEN (8 new M1-M8 + 17 existing).
- standardrb clean.
- MCP-Sweep (251 tests) ohne Regression.
- KEIN push, KEIN deploy (per User-Memory `feedback_deploys_user_executes.md`
  + Plan-Schritt 3).
- ROADMAP.md NICHT verändert (Quick-Task läuft separat von Phase-Cycle).
