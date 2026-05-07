# NL-Szenario-Harness

Datengetriebener Test-Runner, der YAML-Szenarien unter `cases/` lädt und sie als Minitest-Tests gegen die im Server registrierten MCP-Tools fährt — als ergänzendes Format zu den existierenden Unit- und Integrationstests in `test/mcp_server/`.

**Zweck:** Reproduzierbare „Was würde der Turniermanager fragen?"-Szenarien — getrennt vom Mocking-Detail eines einzelnen Tool-Tests, sichtbar als kuratierte Szenario-Liste, leicht erweiterbar ohne Ruby-Kenntnisse.

## YAML-Format

```yaml
---
name: "<Kurzbezeichnung des Szenarios>"
description: |
  Wer fragt warum? Welcher Effekt soll eintreten?
mock: true                # Pflichtfeld — Production-Schutz
steps:
  - tool: <tool-name>     # exakt wie tool_name im Tool definiert (z. B. cc_lookup_region)
    args:                 # Keys werden 1:1 zu kwargs an Tool.call(**args)
      shortname: "NBV"
    expect:
      error: false        # erwartet response.error? (true/false)
      content_includes:   # Liste von Strings, die im content[*][:text] vorkommen müssen
        - "NBV"
        - "Niedersächsischer Billard-Verband"
```

**Pflichtfelder:** `name`, `mock: true`, `steps[].tool`.
**Optional:** `description`, `steps[].args`, `steps[].expect.error`, `steps[].expect.content_includes`.

## Neuen Fall hinzufügen

1. Neue Datei `cases/<sprechender-name>.yml` anlegen.
2. `mock: true` setzen — Pflicht, sonst schlägt der Runner fehl.
3. Mindestens einen Step mit `tool` definieren. Die Tool-Namen sind die `tool_name`-Macros aus `lib/mcp_server/tools/*.rb` (z. B. `cc_lookup_region`, `cc_search_player`, `cc_finalize_teilnehmerliste`). Eine vollständige Übersicht findet sich in `.paul/phases/01-inventory-and-harness/INVENTORY.md`.
4. `args` als Hash setzen — Keys werden symbolisiert und als kwargs an `Tool.call(**args)` übergeben.
5. `expect` formulieren — minimal `error: false`, idealerweise mit `content_includes` als grober Inhaltsprobe.

Die Datei wird automatisch beim nächsten Testlauf entdeckt — kein Eintrag in einer Registry nötig.

## Ausführen

```bash
# Nur das Scenario-Runner-Test:
bin/rails test test/mcp_server/scenarios/scenario_runner_test.rb

# Komplette MCP-Test-Suite (inkl. Scenario-Runner):
bin/rails test test/mcp_server/

# Einzelnes Szenario debuggen:
bin/rails test test/mcp_server/scenarios/scenario_runner_test.rb -n "/Lookup Region: NBV/"
```

## Mock-Mode-Disziplin (wichtig)

Der Runner setzt `CARAMBUS_MCP_MOCK=1` im `setup` und stellt es im `teardown` wieder her. Tools holen ihren CC-Client über `McpServer::CcSession.client_for`, das im Mock-Mode den `McpServer::Tools::MockClient` zurückgibt — **niemals echten ClubCloud-Traffic**. Das schützt das harte Erfolgskriterium aus PROJECT.md („kein Prod-Daten-Schaden").

`McpServer::CcSession` weigert sich zusätzlich, in `Rails.env.production?` mit Mock-Mode zu starten (Defense-in-Depth). Selbst falls jemand `mock: true` vergessen würde, würde der Runner den Test mit einer Assertion abbrechen.

## Format-Erweiterungen (Phase 2+)

Der Phase-1-Runner ist absichtlich minimal: ein Step → ein Tool-Call → strukturelle Assertion. In Phase 2 (Walking Skeleton Turnieranmeldung) wird das Format erweitert, wahrscheinlich um:

- Multi-Step-Sequenzen mit Variablen-Übergabe zwischen Steps (z. B. `tournament_id` aus Step 1 in Step 2 verwenden)
- Resource-Reads (`resource: cc://workflow/scenarios/anmeldung-erstellen`)
- Rückfragen-Simulation (Tool fragt zurück, Szenario beantwortet)
- Strukturierte Assertions (JSONPath statt nur Substring)

Bis dahin: Erweiterungen bitte erst dann hinzufügen, wenn ein konkreter Phase-2-Plan sie braucht — keine Generalisierung auf Vorrat.

## Verhältnis zu anderen Tests

| Suite | Zweck | Wann nutzen |
|-------|-------|-------------|
| `test/mcp_server/tools/*_test.rb` | Unit-Tests pro Tool — Validierungen, Pfad-Verzweigungen | Beim Bau eines Tools / Bug-Fix in einem Tool |
| `test/mcp_server/integration/stdio_e2e_test.rb` | End-to-end JSON-RPC über echten Subprocess | Als Phase-Abschluss-Smoke-Test (langsam, Rails-Boot) |
| `test/mcp_server/scenarios/` (dieses) | Datengetriebene NL-Szenarien — „was fragt der Turniermanager?" | Als kuratierte, schnelle Mock-Smoke-Suite, die die Lebenszyklen vom Anwenderstandpunkt abdeckt |

Die drei Ebenen sind komplementär — keine ersetzt eine andere.
