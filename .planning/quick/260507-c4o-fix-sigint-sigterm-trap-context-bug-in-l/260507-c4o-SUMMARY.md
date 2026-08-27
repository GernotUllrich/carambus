---
phase: quick-260507-c4o
plan: "01"
subsystem: mcp-server
tags: [bugfix, signal-handling, trap-context, mcp]
key-files:
  modified:
    - lib/mcp_server/transport/boot.rb
decisions:
  - "Option B gewählt: $stderr.write statt Logger — direktes IO, kein Mutex, trap-context-safe"
  - "Inline-Kommentar mit Pitfall-8-Verweis im Trap-Body ergänzt, Header-Kommentar unverändert"
metrics:
  duration: "< 5 min"
  completed: "2026-05-07"
  tasks_completed: 1
  files_changed: 1
  commit: f28b40b5
---

# Quick 260507-c4o: SIGINT/SIGTERM Trap-Context-Bug behoben

**One-liner:** `$stderr.write` ersetzt `Rails.logger.info` im Signal-Trap — eliminiert Ruby ThreadError durch Mutex-Akquisition im Trap-Kontext.

## Was wurde geändert

`lib/mcp_server/transport/boot.rb` Zeile 22: `Rails.logger.info "[mcp-server] caught SIG#{sig}, exiting"` wurde durch direkten `$stderr.write("[mcp-server] caught SIG#{sig}, exiting\n")` ersetzt. Zusätzlich wurde ein dreizeiliger Inline-Kommentar eingefügt, der den Pitfall-8-Kontext aus `40-RESEARCH.md §4` direkt im Trap-Body dokumentiert.

## Warum

`Logger` akquiriert intern einen Mutex. Ruby verbietet Mutex-Akquisition im `Signal.trap`-Kontext (`ThreadError: can't be called from trap context`). Ctrl-C bzw. SIGTERM auf `bin/mcp-server` hat deshalb mit einem ThreadError-Stacktrace auf STDERR gecrasht, statt sauber zu beenden. MCP-Clients (Claude Desktop / Code) spawnen `bin/mcp-server` als Subprocess und müssen ihn per SIGTERM zuverlässig beenden können.

## Akzeptanzkriterien — alle erfüllt

| Kriterium | Ergebnis |
|-----------|----------|
| `grep -c '$stderr.write.*caught SIG'` == 1 | 1 |
| `grep -c 'Rails.logger.*caught SIG'` == 0 | 0 |
| `grep -c 'Pitfall 8'` >= 1 | 2 |
| `wc -l` <= 36 | 35 |
| `$stdout`/`puts`/`print` im Trap-Block | keiner |
| `Boot.respond_to?(:run)` | true |

## Commit

- `f28b40b5` — fix(quick-260507-c4o): $stderr.write statt Rails.logger im SIGINT/SIGTERM-Trap

## Self-Check: PASSED

- Datei `lib/mcp_server/transport/boot.rb` existiert und enthält `$stderr.write.*caught SIG`.
- Commit `f28b40b5` ist im git-Log vorhanden.
- Kein neuer Test erforderlich (Trap-Kontext ist in-process nicht unit-testbar ohne Subprocess-Spawn — dokumentiert in PLAN.md §context/interfaces).
- Pitfall-8-Trail erhalten (Header-Kommentar Zeile 3 + Inline-Kommentar im Trap-Body).
