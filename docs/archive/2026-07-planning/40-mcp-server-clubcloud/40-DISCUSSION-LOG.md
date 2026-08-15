# Phase 40: MCP Server für ClubCloud-Schnittstelle - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-07
**Phase:** 40-mcp-server-clubcloud
**Areas discussed:** A. Knowledge Surface, B. Auth & CC-Backend, C. Architektur & Stack, D. Zielgruppe & Use Cases

---

## Pre-discussion routing

User came in with: *"Ich möchte gern mit dem Wissen aus dem Interface zur ClubCloud einen MCP Server bauen, der verschiedene Aspekte der Schnittstelle behandelt."*

Routed via `/gsd-do` → `/gsd-discuss-phase`. Phase 40 did not exist yet; user opted for "Neue Phase 40 in carambus_api". `/gsd-add-phase` ran but the CLI mis-numbered (took max(999.1)+1 = 1000); manually corrected to Phase 40 inserted between Phase 39 and the Backlog section, committed as `e06f14d1`.

## Pre-existing context loaded

- `.planning/PROJECT.md` — Current milestone is v7.1 (UX Polish & i18n Debt). v7.2 is "ClubCloud Integration (Endrangliste, CC API finalization, credentials delegation)". → Milestone-mismatch flagged in Deferred Ideas.
- `.planning/REQUIREMENTS.md` — v7.1 has 6 requirements (UX-POL-01..03, I18N-01..02, DATA-01). Phase 40 is unmapped. No conflict, just out of milestone scope.
- `.planning/STATE.md` — Recent activity is Phase 38.x BK-family tiebreak work and Phase 39 DTP-backed parameter ranges.
- No prior CONTEXT.md files reference MCP, ClubCloud-as-AI-surface, or audience targeting — Phase 40 is the first.
- Codebase scout: identified `app/services/region_cc/club_cloud_client.rb` (PATH_MAP with ~100 actions), 9 syncers, mirror models, and the existing `clubcloud-admin-appendix-DRAFT.md`. No existing MCP library in `Gemfile` / `package.json`.

## Todo cross-reference

`gsd-tools todo match-phase 40` returned 2 todos with score 0.6:
- `2026-05-06-detail-form-mehrsatzspiel-toggle-not-persisting-sets-to-win.md` — spurious keyword match.
- `2026-05-06-implement-bk-tiebreak-nachstoss-canonical-spec.md` — spurious keyword match.

Both reviewed and **not folded** — captured in CONTEXT.md `<deferred>` under "Reviewed Todos".

---

## Area A: Knowledge Surface

### Q1: Welche Wissens-Schichten exponieren? (multiSelect)

| Option | Description | Selected |
|--------|-------------|----------|
| Workflow-Doku | Organisatorisches CC-Wissen aus appendix + site/managers — Resources mit URIs | ✓ |
| Technical-API-Map | ~100 PATH_MAP-Actions als durchsuchbare Resources / lookup tool | ✓ |
| Live-Lookups (Carambus-DB + ggf. CC) | Tools die Carambus-Models abfragen, ggf. Fallback zu Live-CC | ✓ |
| Action-Execution (write) | Tools die CC-Mutationen auslösen — Player anlegen, Result hochladen | ✓ |

**User's choice:** All four — recorded as D-01.

### Q2: Live-Lookups Quelle?

| Option | Description | Selected |
|--------|-------------|----------|
| Nur Carambus-DB | Lookups nur gegen lokale Models | |
| Beide, mit Fallback | Primär DB, fallback Live-CC bei force-refresh | ✓ |
| Nur Live-CC-API | Direkter Pass-through zu CC-PHP-API | |

**User's choice:** Beide mit Fallback — recorded as D-02.

### Q3: Write-Safety-Pattern?

| Option | Description | Selected |
|--------|-------------|----------|
| Dry-run-default + explicit armed | `armed: bool` parameter, spiegelt ClubCloudClient-Pattern | |
| Two-step: prepare + commit | Token-basiertes Commit | |
| Allowlist + role check | Kuratierte Tool-Allowlist, jeweils Schema + Role-Validation | ✓ |
| Kein write in Phase 40 | Write-Schicht nach Phase 40.1 verschieben | |

**User's choice:** Allowlist + role check — recorded as D-03. (The `armed`-pattern still appears in D-19 as the *user-visible contract* for the proof-of-concept write tool — these decisions are complementary, not exclusive.)

### Q4: PATH_MAP Auto-Mapping vs. kuratiert?

| Option | Description | Selected |
|--------|-------------|----------|
| Kuratierte Allowlist | ~10–20 manuell beschriebene Actions | ✓ |
| Auto-Mapping aller Einträge | Alle ~100 automatisch | |
| Hybrid | Curated + Meta-Tool `lookup_cc_action(name)` | |

**User's choice:** Kuratierte Allowlist — recorded as D-04.

### Q5: Sprache der Workflow-Doku-Resources?

| Option | Description | Selected |
|--------|-------------|----------|
| DE | Source ist DE, Zielgruppe DE | ✓ |
| EN | AI-Effizienz, aber Translation-Kosten | |
| Beide | Per-Locale Resources | |

**User's choice:** DE — recorded as D-05.

### Q6: URI-Schema für MCP-Resources?

| Option | Description | Selected |
|--------|-------------|----------|
| Custom-Scheme `cc://...` | Eigenes Scheme, namensraum-isoliert | ✓ |
| HTTPS-URLs | Browser-öffenbar, mischt Domänen | |
| Pfad-only `/cc/...` | Schlank, aber MCP-Konvention bevorzugt Scheme | |

**User's choice:** `cc://...` — recorded as D-06.

### Q7: Workflow-Doku-Bundling?

| Option | Description | Selected |
|--------|-------------|----------|
| Pro Szenario eine Resource | Jedes Szenario eigene Resource + Meta-Resources | ✓ |
| Eine große Doku-Resource | Komplette appendix als single resource | |
| Hierarchisch: Index + Sub-Pages | `cc://workflow/index` + sub-resources | |

**User's choice:** Pro Szenario eine Resource — recorded as D-07.

---

## Area B: Auth & CC-Backend

### Q1: Backend?

| Option | Description | Selected |
|--------|-------------|----------|
| Production-CC + Mock-Mode | Standard ist Live-CC, Mock via ENV-Flag | ✓ |
| Test/Staging-CC zuerst | Erst Test-Backend, später Production | |
| Nur Mock / dokumentarisch | Kein echter CC-Zugriff in Phase 40 | |

**User's choice:** Production-CC + Mock-Mode — recorded as D-08.

### Q2: Credentials?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-User via MCP-Client-Config | mcp.json ENV-Vars: CC_USERNAME, CC_PASSWORD, CC_FED_ID | ✓ |
| Zentral in Carambus-Credentials | config/credentials/{env}.yml.enc | |
| OAuth-ähnlich via Carambus | Carambus delegiert Auth | |
| Read-only ohne Credentials | Server hat keine eigenen Creds | |

**User's choice:** Per-User via MCP-Client-Config — recorded as D-09.

### Q3: Session-Handling?

| Option | Description | Selected |
|--------|-------------|----------|
| Lazy login + in-memory cache | Erste Tool-Call → Login, PHPSESSID cached, TTL 30min | ✓ |
| Pre-login bei Server-Start | Login beim Boot, Heartbeat | |
| Per-request | Jeder Tool-Call eigener Login | |

**User's choice:** Lazy login + in-memory cache — recorded as D-10.

### Q4: Role-Check?

| Option | Description | Selected |
|--------|-------------|----------|
| Trust CC + parse error | Tool macht Call, parst CC-Permission-Error sauber | ✓ |
| Pre-check via CC-User-Profile | Cache User-Rollen-Liste, lokal validieren | |
| Hardcoded role-mapping per tool | Pro Tool steht erforderliche Rolle im Code | |

**User's choice:** Trust CC + parse error — recorded as D-11.

---

## Area C: Architektur & Stack

### Q1: Tech-Stack?

| Option | Description | Selected |
|--------|-------------|----------|
| Ruby | Anthropic MCP Ruby SDK, direkter Model-Access | ✓ |
| Node/TypeScript | Verbreitetster MCP-Stack, separate API nötig | |
| Python | MCP SDK reif, aber nicht im Projekt | |

**User's choice:** Ruby — recorded as D-12.

### Q2: Hosting/Repo?

| Option | Description | Selected |
|--------|-------------|----------|
| In carambus_api | lib/mcp_server/ oder app/services/mcp/ | ✓ |
| Eigenes Repo `carambus-mcp` | Separater Lifecycle | |
| Als Rails-Engine | lib/engines/carambus_mcp/ | |

**User's choice:** In carambus_api — recorded as D-13.

### Q3: Transport?

| Option | Description | Selected |
|--------|-------------|----------|
| stdio | MCP-Standard, lokal, kein Port | ✓ |
| HTTP / SSE | Multi-Client, Network-Auth | |
| Beide | stdio default + HTTP optional | |

**User's choice:** stdio — recorded as D-14.

### Q4: Pfad?

| Option | Description | Selected |
|--------|-------------|----------|
| lib/mcp_server/ + bin/mcp-server | Trennung, leicht extrahierbar | ✓ |
| app/services/mcp/ | Service-Style, Rails-Boot-Overhead | |
| Rails-Engine | Strukturiert, für stdio overkill | |

**User's choice:** lib/mcp_server/ + bin/mcp-server — recorded as D-13/D-14 wiring.

### Q5: Rails-Boot?

| Option | Description | Selected |
|--------|-------------|----------|
| Ja — Rails-Boot im bin/mcp-server | require config/environment beim Start | ✓ |
| Nein — standalone Ruby ohne Rails | HTTP-Calls an Rails-App | |
| Hybrid — lazy Rails-Boot | Erst beim DB-Call laden | |

**User's choice:** Rails-Boot im bin/mcp-server — recorded as D-15.

### Q6: Tests?

| Option | Description | Selected |
|--------|-------------|----------|
| Minitest unter test/mcp_server/ | Standard-Carambus-Pattern | ✓ |
| Separate test/ in lib/mcp_server/ | Eigenes Test-Verzeichnis | |
| Beides: Unit + E2E | Unit unter test/, E2E unter test/system/ | |

**User's choice:** test/mcp_server/ — recorded as D-16. (One E2E integration test mentioned as additional in CONTEXT.md.)

---

## Area D: Zielgruppe & Use Cases

### Q1: Audiences (multiSelect)?

| Option | Description | Selected |
|--------|-------------|----------|
| Carambus-Entwickler in Claude Code | Code-Buddy, PATH_MAP-Exploration | ✓ |
| Turnierleiter in Claude Desktop | Workflow-Hilfe | ✓ |
| Externe / API-Konsumenten | v8.0+ | |
| CI / Automation | Headless auth | |

**User's choice:** Devs + Turnierleiter — recorded as D-17.

### Q2: Acceptance-Story?

| Option | Description | Selected |
|--------|-------------|----------|
| Workflow-Hilfe + 1 read-Lookup | Minimaler Read-Pfad | ✓ |
| Workflow-Hilfe + 1 read + 1 write | Voller End-to-End-Pfad inkl. Schreiben | |
| Code-Buddy: PATH_MAP-Exploration | Devs primär, kein Live-CC | |

**User's choice:** Workflow-Hilfe + 1 read — recorded as D-18.

### Q3: Write-Scope in Phase 40?

| Option | Description | Selected |
|--------|-------------|----------|
| Architektur ja, 1 Write-Tool als Proof | Allowlist voll, 1 Write als POC gegen Mock | ✓ |
| Architektur ja, keine Writes implementiert | Allowlist-Schema definiert, keine Tools | |
| Volle Writes in Phase 40 | Alle Allowlist-Tools implementiert | |

**User's choice:** Architektur + 1 Proof — recorded as D-19.

### Q4: Tool-Sprache?

| Option | Description | Selected |
|--------|-------------|----------|
| EN | AI-Effizienz, MCP-Konvention | ✓ |
| DE | Konsistent mit Doku-Resources | |
| Beide via Locale-Negotiation | Komplex, kein klarer Vorteil | |

**User's choice:** EN — recorded as D-20.

---

## Claude's Discretion

(Captured in CONTEXT.md `<decisions>` → "Claude's Discretion" subsection.)

- Exact JSON-schema field shapes per tool
- Internal module structure under `lib/mcp_server/`
- Logging strategy (Rails.logger vs. dedicated MCP_LOGGER)
- Initial set of 5–7 scenarios for D-07 Workflow Resources
- Shape of `cc://api/*` resources (raw vs. structured)
- Mock-mode implementation (VCR vs. hand-written stubs)

## Deferred Ideas (raised during discussion)

(Captured in CONTEXT.md `<deferred>`.)

- Full write allowlist → Phase 40.1 (proposed)
- HTTP/SSE transport → future phase
- External / API consumers → v8.0+
- CI / Automation use case → future phase
- PATH_MAP auto-mapping → no phase planned
- `[SME-CONFIRM]` resolution in workflow appendix → orthogonal doc-promotion workflow
- Multi-tenancy → v8.0+
- Pre-cached role lookup → only revisit if D-11 UX insufficient
- **Milestone-mismatch flag** — Phase 40 is in v7.1 (UX Polish) but is thematically v7.2 (ClubCloud Integration). User accepted current placement; flagged for future milestone-kickoff.
