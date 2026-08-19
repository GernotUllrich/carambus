---
phase: quick-260507-njl
plan: "01"
subsystem: mcp-server
tags: [mcp, credentials, rails-credentials, region-lookup, cleanup]
key-decisions:
  - "require_env!-Wächter in cc_session.rb#client_for entfernt — Login läuft über Setting.login_to_cc (Rails Credentials), ENV CC_USERNAME/CC_PASSWORD waren tote Parameter"
  - "BaseTool.default_fed_id auf Region-Lookup umgestellt: Region.find_by(shortname: CC_REGION).region_cc.cc_id ist kanonische Quelle; CC_FED_ID bleibt als Override; defensives rescue StandardError für Mock-Smoke ohne DB"
  - ".mcp.json.example und Doku auf 3-ENV-Schema reduziert (RAILS_ENV, CC_REGION, CARAMBUS_MCP_MOCK) — Klartext-Credentials raus aus Setup-JSON"
  - "require_env!-Methode vollständig entfernt (kein Caller mehr nach Änderung)"
metrics:
  duration: "~25 min"
  completed_date: "2026-05-07"
  tasks_completed: 2
  files_modified: 7
  public_docs_rebuilt: true
---

# Quick-Task 260507-njl: MCP-Credentials-Cleanup — Rails Credentials + Region-Lookup statt ENV

**One-liner:** `require_env!`-Wächter entfernt, `default_fed_id` auf Region-Lookup umgestellt,
`.mcp.json.example` + Manager-/Developer-Doku auf 3-ENV-Schema (kein Klartext mehr).

## Commits

| Hash | Beschreibung |
|------|-------------|
| `d5653ea4` | `refactor(mcp): ENVfreier Boot + Region-Lookup für default_fed_id (quick-260507-njl Task 1)` |
| `862f068a` | `chore(mcp): Doku + .mcp.json.example auf 3-ENV-Schema + mkdocs rebuild (quick-260507-njl Task 2)` |

## Erledigte Tasks

### Task 1: Code + Tests

**`lib/mcp_server/cc_session.rb`**
- `client_for`: `require_env!("CC_USERNAME")` und `require_env!("CC_PASSWORD")` ersetzt durch
  `ENV["CC_USERNAME"].presence` / `ENV["CC_PASSWORD"].presence`
- `require_env!`-Methode vollständig entfernt (war der einzige Caller)

**`lib/mcp_server/tools/base_tool.rb`**
- `default_fed_id` von `ENV["CC_FED_ID"]&.to_i` auf dreistufigen Region-Lookup umgestellt:
  1. ENV `CC_FED_ID` (Override, höchste Prio)
  2. `Region.find_by(shortname: CC_REGION).region_cc.cc_id` (kanonisch)
  3. `nil` + defensives `rescue StandardError` (Mock-Smoke ohne DB)

**`test/mcp_server/cc_session_test.rb`**
- Test "missing CC_USERNAME raises clear error" ersetzt durch
  "missing CC_USERNAME and CC_PASSWORD: client_for darf ENV-frei booten"
- Prüft: `assert_nothing_raised`, `assert_instance_of RegionCc::ClubCloudClient`,
  `assert_nil client.username`, `assert_nil client.userpw`

**`test/mcp_server/tools/cc_fed_id_env_default_test.rb`**
- 3 neue Tests am Ende der Klasse:
  - `default_fed_id: ENV CC_FED_ID unset + CC_REGION=NBV → Region-Lookup liefert cc_id`
  - `default_fed_id: CC_FED_ID-Override beats CC_REGION-Lookup`
  - `default_fed_id: defensives rescue — DB-Fehler liefert nil ohne Exception`

### Task 2: Doku + .mcp.json.example + mkdocs rebuild

**`.mcp.json.example`**
- Env-Block auf 3 Vars reduziert: `RAILS_ENV`, `CC_REGION`, `CARAMBUS_MCP_MOCK`
- `CC_USERNAME`, `CC_PASSWORD`, `CC_FED_ID` entfernt
- `_comment` aktualisiert: Hinweis auf Rails Credentials statt Klartext

**`docs/managers/clubcloud-mcp-setup.de.md`**
- Voraussetzungen: `CC_FED_ID`-Zeile + `CC_USERNAME/CC_PASSWORD`-Zeile ersetzt durch
  Hinweis auf Rails Credentials (Production-Server bereits konfiguriert)
- Schritt 3.3: JSON-Block auf 3-ENV reduziert; Begleittext aktualisiert
- Neue Section 3.3a: lokales Rails Credentials Setup (development.yml.enc)
- Troubleshooting-Header umbenannt: "CC_USERNAME env var not set" → "ClubCloud username not configured"

**`docs/developers/clubcloud-mcp-server.de.md`**
- Section 5 Live-Mode: Block auf `CC_REGION=NBV RAILS_ENV=development bin/mcp-server` reduziert
- Section 5: neue Sub-Sektion "Rails Credentials Setup (für lokales Live-Debug)"
- Section 5 Project-Scope-JSON: 3-ENV-Form
- Section 5 User-Scope `claude mcp add`: 3-ENV-Form; Hinweis "Klartext-Passwort im Home-Dir" → "kein Klartext im Home-Dir"
- Section 6 `BaseTool.default_fed_id`-Tabellenzeile: Region-Lookup-Beschreibung mit `260507-njl`-Referenz
- Section 9 Debugging: Fehlermeldung auf "ClubCloud username not configured" aktualisiert
- Section 11: neuer Closure-Block für `260507-njl`

**`public/docs/`** — rebuild via `bin/rails mkdocs:build` (5.3s, 74 nav elements, 0 build errors)

## Verification-Punkte (8/8 bestätigt)

| # | Check | Ergebnis |
|---|-------|---------|
| 1 | `bin/rails test test/mcp_server/` | **74 runs / 245 assertions / 0 failures / 0 errors / 0 skips** |
| 2 | `grep -c "CC_USERNAME\|CC_PASSWORD\|CC_FED_ID" .mcp.json.example` → 0 | **PASS** |
| 3 | Manager-Doku: keine als-zu-setzende ENV-Anweisung für Credentials | **PASS** (Section 3.3 ohne Credential-ENVs) |
| 4 | `grep -q "260507-njl" docs/developers/clubcloud-mcp-server.de.md` | **PASS** (Section 11 + Section 6) |
| 5 | `grep -q "Region-Lookup" lib/mcp_server/tools/base_tool.rb` | **PASS** |
| 6 | `grep -q 'ENV\["CC_USERNAME"\].presence' lib/mcp_server/cc_session.rb` | **PASS** |
| 7 | Mock-Smoke ohne DB: `CARAMBUS_MCP_MOCK=1 bin/mcp-server` → `"serverInfo"` in Response | **PASS** |
| 8 | `git log -1 --format=%s` enthält `quick-260507-njl` | **PASS** (beide Commits) |

## Test-Counts

| Zeitpunkt | Runs | Assertions | Failures |
|-----------|------|-----------|---------|
| Vor Task 1 (Baseline 260507-m2z) | 71 | 220 | 0 |
| Nach Task 1 | 74 | 245 | 0 |
| Nach Task 2 (final) | 74 | 245 | 0 |

Netto: +3 Runs (3 neue Region-Lookup-Tests), +25 Assertions.

## Deviationen vom Plan

**1. [Rule 1 - Bug] `require_env!`-Methode vollständig entfernt (nicht nur "vorerst stehen lassen")**

- Gefunden während: Task 1 Step 1
- Plan-Vorgabe: "stehen lassen falls nur Definition übrig"
- Tatsächlich: `grep -rn "require_env!" lib/mcp_server/ test/mcp_server/` → nur noch die Definition selbst
- Fix: Plan-Instruktion sagt explizit "wenn nur Definition selbst übrig ist: Methode entfernen" — diesem Pfad gefolgt, Methode entfernt

**2. [Rule 1 - Bug] Debugging-Cookbook (Section 9) aktualisiert**

- Gefunden während: Task 2 Dokumentations-Sweep
- Issue: Section 9 "Tool gibt unerwartet error?: true" erwähnte noch `RuntimeError "CC_USERNAME env var not set"` — diese Fehlermeldung existiert nicht mehr
- Fix: Fehlermeldung auf `"ClubCloud username not configured for region: ..."` (aus `Setting.login_to_cc`) aktualisiert

## Bekannte Stubs

Keine. Alle Änderungen sind vollständig implementiert und getestet.

## Self-Check: PASSED

Alle 7 Source-Files vorhanden, beide Commits (`d5653ea4`, `862f068a`) im Log bestätigt.
