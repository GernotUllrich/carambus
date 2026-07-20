# Phase 40: MCP Server für ClubCloud-Schnittstelle - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a Ruby-based MCP server (Anthropic's official Ruby SDK) that exposes ClubCloud-relevant knowledge from Carambus to AI agents. Knowledge sources are: organizational workflow documentation (`.planning/clubcloud-admin-appendix-DRAFT.md` and `site/managers/clubcloud-*`), the technical CC-API surface captured in `RegionCc::ClubCloudClient::PATH_MAP` (~100 actions), the Carambus-side CC-mirror models (`RegionCc`, `LeagueCc`, `TournamentCc`), and a curated allowlist of write actions against the live CC-API.

Phase 40 acceptance = end-to-end read path working (workflow doc resource + read lookup tool, both invokable from Claude Desktop and Claude Code) **plus** the write architecture standing **plus** one write tool as proof against the mock backend. Full write coverage and external/multi-user audiences are explicitly out of scope and deferred.

</domain>

<decisions>
## Implementation Decisions

### A. Knowledge Surface

- **D-01:** The server exposes four layers — (1) workflow documentation as MCP resources, (2) the technical CC-API surface (PATH_MAP) as resources, (3) read lookups as MCP tools, (4) write actions as MCP tools (allowlist).
- **D-02:** Live lookups query Carambus-DB models (`RegionCc`, `LeagueCc`, `TournamentCc`) by default; on force-refresh or cache-miss, the same tool falls back to a live `RegionCc::ClubCloudClient.get` call against the CC-API.
- **D-03:** Write tools follow an allowlist pattern: each permitted CC action is exposed as a named MCP tool with its own JSON schema; non-allowlisted CC mutations are unreachable via MCP. The full allowlist is partially implemented in Phase 40 — see D-13.
- **D-04:** The ~100 `PATH_MAP` entries are NOT auto-mapped to MCP tools/resources. Instead, a curated allowlist of ~10–20 high-value actions is exposed, each manually authored with description + JSON schema.
- **D-05:** Workflow-doc resources are authored and served in **German** (DE). The source material is DE, the audience for Workflow-Doku (Turnierleiter) is DE-speaking, and we avoid translation round-trip cost.
- **D-06:** Resources use a custom URI scheme `cc://...`. Examples: `cc://workflow/scenarios/teilnehmerliste-finalisieren`, `cc://api/showLeagueList`, `cc://carambus/region/2`.
- **D-07:** The workflow appendix (`clubcloud-admin-appendix-DRAFT.md`) is split per-scenario: each of the 5–7 scenarios (Teilnehmerliste finalisieren, Result upload, Player anlegen, etc.) becomes its own resource at `cc://workflow/scenarios/{name}`, plus meta-resources for the role model and glossary.

### B. Auth & CC-Backend

- **D-08:** Default backend is the **production ClubCloud API** (the same PHP backend `RegionCc::ClubCloudClient` already calls). A mock mode is gated by an ENV flag (e.g. `CARAMBUS_MCP_MOCK=1`) for local development and CI — no real network calls when set.
- **D-09:** Credentials are configured **per MCP-client installation** via the client's `mcp.json` (or equivalent). The server reads `CC_USERNAME`, `CC_PASSWORD`, and `CC_FED_ID` from its environment. Each MCP-client effectively acts with the rights of that user.
- **D-10:** Session handling: lazy login + in-memory `PHPSESSID` cache with TTL ~30 min. On the first tool call requiring auth, the server logs in; subsequent calls reuse the cookie. On session expiry (HTTP redirect to login or 403), the server transparently re-logs in once. No persistence layer.
- **D-11:** Permission validation for write tools is **trust-CC-and-parse-error**: the tool issues the CC call; if CC rejects with a permission error, the server parses CC's response and returns a structured MCP error (e.g. "Your role is *Member* but action requires *Club-Sportwart*"). No pre-flight role lookup, no cached role list.

### C. Architektur & Stack

- **D-12:** Implementation language is **Ruby**, using Anthropic's official `mcp` Ruby SDK. Reason: direct in-process access to `RegionCc::ClubCloudClient` and the 9 syncers in `app/services/region_cc/` without a second HTTP hop, and consistency with the rest of the Carambus codebase.
- **D-13:** Server code lives **inside `carambus_api`** under `lib/mcp_server/` (server entrypoint, tool registry, resource registry, schemas). The executable is `bin/mcp-server`, registered in MCP-client configs.
- **D-14:** Transport is **stdio** only in Phase 40. The MCP client spawns `bin/mcp-server` as a child process and speaks JSON-RPC over stdin/stdout. No port, no network surface, no HTTP transport. HTTP/SSE is deferred (see Deferred Ideas).
- **D-15:** `bin/mcp-server` boots the full Rails environment (`require_relative '../config/environment'`) at startup. One-time ~3–5s boot latency; per-tool-call no Rails-load overhead. Models and services are accessed in-process.
- **D-16:** Tests live under `test/mcp_server/` using Minitest (project standard). The mock mode from D-08 is used to stub CC calls. Coverage target: smoke test per tool/resource + one E2E integration test that spawns `bin/mcp-server` and exchanges MCP-protocol messages with a stub client.

### D. Zielgruppe & Use Cases

- **D-17:** Two primary audiences: (a) **Carambus developers in Claude Code** — for code understanding, PATH_MAP exploration, syncer-pattern questions; (b) **Turnierleiter (sportwarts) in Claude Desktop** — for workflow help and CC scenario walkthroughs. External/API consumers and CI/automation are out of scope for Phase 40.
- **D-18:** Phase 40 acceptance story (the demo that must work end-to-end): "*Als Turnierleiter frage ich 'wie finalisiere ich die Teilnehmerliste', bekomme die Anleitung aus `cc://workflow/scenarios/teilnehmerliste-finalisieren`, und kann mit Folge-Frage 'gibt es eine Teilnehmerliste in CC für Turnier X' den Live-Lookup-Tool nutzen.*" — that is, the read pathway working for both audiences.
- **D-19:** Write architecture (the allowlist mechanism, JSON schemas, role-error parsing from D-03 and D-11) is **fully implemented** in Phase 40, but only **one** write tool ships as proof — recommended: `cc_finalize_teilnehmerliste` running against the mock backend. The remaining ~3–5 write tools (e.g. `cc_add_player`, `cc_upload_result`) are deferred to Phase 40.1.
- **D-20:** Tool names, descriptions, and JSON-schema texts are written in **English**. Reason: AI models call tools more reliably with English schemas, and tool-name conventions are English-dominant in the MCP ecosystem. Resource *content* remains German per D-05 — only the tool surface is EN.

### Claude's Discretion

- Exact JSON-schema field shapes per tool (parameter names, validation rules) — researcher and planner will flesh these out per tool.
- Internal module structure under `lib/mcp_server/` (e.g. `tools/`, `resources/`, `schemas/`, `transport/`) — apply Carambus conventions.
- Logging strategy for the MCP server (Rails.logger vs. dedicated `MCP_LOGGER` like `Tournament`'s `DEBUG_LOGGER`) — pick what matches existing patterns.
- Choice of which 5–7 scenarios from the appendix become D-07 resources first — pick the ones marked clearest in `clubcloud-admin-appendix-DRAFT.md`.
- Specific shape of the `cc://api/*` resource format (raw PATH_MAP excerpt vs. structured doc) — design when implementing.
- Mock-mode implementation detail (VCR-recorded fixtures vs. hand-written stubs) — reuse the project's VCR pattern under `test/snapshots/vcr/` if it fits.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### ClubCloud Workflow Knowledge (source for D-05/D-07 Workflow Resources)
- `.planning/clubcloud-admin-appendix-DRAFT.md` — Roles model, scenarios (Teilnehmerliste-Finalisierung, Result-Upload, Player anlegen, etc.), troubleshooting. Many entries are flagged `[SME-CONFIRM]` — Phase 40 does not resolve these flags; resources expose the doc as-is including the markers.
- `site/managers/clubcloud-integration/` — Manager-facing CC integration walkthrough.
- `site/managers/clubcloud_credentials/` — Credentials handling guidance for human users.
- `site/managers/clubcloud_upload_feedback/` — Upload error patterns.
- `site/developers/clubcloud-upload/` — Developer-facing upload internals.

### ClubCloud Technical Surface (source for D-04 curated PATH_MAP)
- `app/services/region_cc/club_cloud_client.rb` — HTTP transport, complete `PATH_MAP` constant mapping ~100 CC action names to URL paths and read-only flags. The class header doc and PATH_MAP comments are the canonical inventory.
- `app/services/region_cc/branch_syncer.rb`
- `app/services/region_cc/club_syncer.rb`
- `app/services/region_cc/competition_syncer.rb`
- `app/services/region_cc/game_plan_syncer.rb`
- `app/services/region_cc/league_syncer.rb`
- `app/services/region_cc/metadata_syncer.rb`
- `app/services/region_cc/party_syncer.rb`
- `app/services/region_cc/registration_syncer.rb`
- `app/services/region_cc/tournament_syncer.rb` — Each syncer is a worked example of how PATH_MAP entries are composed into real CC operations; planner uses these to pick which actions belong in the curated allowlist.

### Carambus-Side CC Mirror Models (source for D-02 read lookups)
- `app/models/region_cc.rb`
- `app/models/league_cc.rb`
- `app/models/tournament_cc.rb`
- `app/services/league/club_cloud_scraper.rb` — League-side CC scraper (separate from RegionCc syncers).

### Project-Level Constraints
- `.planning/PROJECT.md` — Brownfield Rails 7.2 app, Ruby 3.2.1, Minitest (NOT RSpec). Note: Phase 40 sits in **v7.1 (UX Polish & i18n Debt)** but is thematically v7.2 work — see Deferred Ideas for the milestone-mismatch flag.
- `CLAUDE.md` — `LocalProtector` concern (`id < 50_000_000` = global, must not mutate on local servers), service convention `app/services/{namespace}/`, Minitest under `test/{type}/`, `frozen_string_literal: true` everywhere, German comments for business logic / English for technical terms.

### External (read while implementing)
- Anthropic MCP Ruby SDK documentation (gem name + version to be resolved by researcher; SDK is the dependency that gets added to `Gemfile`).
- MCP protocol spec (URI schemes, tool/resource conventions, JSON-RPC envelope).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`RegionCc::ClubCloudClient`** — Full HTTP transport stack with session handling (PHPSESSID cookie), GET/POST/multipart-POST, and a built-in dry-run convention via `opts[:armed].blank?`. Phase 40's write tools should call this client directly rather than reimplementing CC HTTP. The `armed` flag pattern is the model for D-19's proof-of-concept write tool.
- **`PATH_MAP` constant** in `club_cloud_client.rb` — Inventory of ~100 CC actions with URL paths and `read_only` boolean flags. The curated D-04 allowlist is selected *from* this map, not parallel to it.
- **9 syncer classes under `app/services/region_cc/`** — Worked examples of how to compose PATH_MAP calls into business operations. Read these to decide which actions are "tool-worthy" for the allowlist (D-04, D-13, D-19).
- **Mirror models** `RegionCc`, `LeagueCc`, `TournamentCc` — The lookup targets for D-02 read tools. Already populated by the existing syncers, so MCP read-lookups inherit their freshness.

### Established Patterns

- **Service-Namespace under `app/services/{namespace}/`** (e.g. `region_cc/`, `umb/`, `bk2/`, `league/`) — Phase 40 follows this when needed, but the MCP server itself lives under `lib/mcp_server/` (D-13) since it has a non-Rails entrypoint.
- **`ApplicationService` pattern** — Single public `.call` class method. MCP tool implementations may delegate into ApplicationService-shaped helpers, but the MCP-tool wrapper itself follows the SDK's tool-class convention.
- **`armed: true` dry-run convention** — Already established in `ClubCloudClient` for write operations. D-19's write tools reuse this exact idiom to stay consistent.
- **Minitest under `test/{type}/`** — Phase 40 uses `test/mcp_server/` for unit tests and (per D-16) potentially `test/system/mcp_server_test.rb` for one E2E integration test.
- **`frozen_string_literal: true`** at top of every Ruby file — applies to all new Phase 40 code.
- **VCR cassettes under `test/snapshots/vcr/`** — for tests that exercise external HTTP. Phase 40's mock mode (D-08) may reuse this convention if the planner finds it appropriate.
- **`LocalProtector` concern** — global vs. local record discipline (`id < 50_000_000`). MCP write tools that create CC-side records must respect this; tests disable it via the `LocalProtectorTestOverride` already established in `test_helper.rb`.

### Integration Points

- **`bin/mcp-server`** — New executable, the entry point MCP clients spawn. Boots Rails (D-15), instantiates the MCP server, registers tools/resources, blocks on stdio I/O.
- **`lib/mcp_server/`** — New top-level location. Suggested initial sub-structure (researcher to confirm): `lib/mcp_server/server.rb` (registration/wiring), `lib/mcp_server/tools/` (one file per tool), `lib/mcp_server/resources/` (one file per resource family), `lib/mcp_server/schemas/` (JSON schemas if extracted).
- **`Gemfile`** — Add the official `mcp` Ruby gem (and any peer deps the SDK requires). Place in main group, not `:development` — production needs it.
- **Rails autoload** — `lib/` is not autoloaded in Rails by default; either add `lib/mcp_server` to `config.autoload_paths` (Zeitwerk-compatible) or `require` explicitly from `bin/mcp-server`. Researcher decides which fits Carambus's existing `lib/` usage.
- **Existing CC integration in `app/services/region_cc/`** — Read-only consumed; Phase 40 does not modify these classes.

</code_context>

<specifics>
## Specific Ideas

- **Reuse, don't reimplement, the CC HTTP layer.** `RegionCc::ClubCloudClient` already handles session cookies, multipart POSTs, and the dry-run idiom. Phase 40's MCP tools should construct an instance of this client (with credentials from D-09 env vars) and call its existing methods. Any new HTTP code under `lib/mcp_server/` is a smell.
- **The `armed: true` write-confirmation pattern is the *user-visible* contract.** Tools surface this in their JSON schema (`armed: boolean, default: false`). Without `armed: true`, the tool returns a structured "what would happen" response — exactly mirroring the existing `ClubCloudClient` convention.
- **Workflow-doc resources are DE; tool surface is EN.** This split is intentional (D-05 + D-20). Don't unify either way.
- **`[SME-CONFIRM]` markers stay in resources unchanged.** The appendix doc has unverified claims; Phase 40 surfaces them as-is rather than resolving them. Resolution belongs to a separate doc-promotion workflow.

</specifics>

<deferred>
## Deferred Ideas

### Out of Scope for Phase 40 (captured for future phases)

- **Full write allowlist** — The remaining ~3–5 write tools beyond the D-19 proof (e.g. `cc_add_player`, `cc_upload_result`, `cc_create_team`) → **Phase 40.1** (proposed).
- **HTTP / SSE transport** — Multi-client, networked deployment of the MCP server. Stdio-only suffices for Phase 40 (D-14). → Future phase tied to multi-user / hosted deployment.
- **External / API-consumer audience** — Other apps or clubs consuming Carambus's CC knowledge over MCP. Requires multi-tenancy, robust auth boundaries, audit logging. → v8.0+
- **CI / Automation use case** — Headless auth (no MCP client running interactively), scheduled jobs invoking MCP tools. Implies a different auth strategy than D-09. → Future phase.
- **`PATH_MAP` auto-mapping** — Auto-generating MCP resources/tools from every PATH_MAP entry. Currently rejected (D-04) in favor of curated allowlist; could be revisited if curation can't keep up. → No phase planned.
- **Resolving `[SME-CONFIRM]` markers** in the workflow appendix — Phase 36c → v7.1 Phase F doc-promotion; orthogonal to MCP server work.
- **Multi-tenancy** (multiple clubs/regions sharing one MCP server) — out of scope; single-installation per MCP-client per D-09.
- **Pre-cached role lookup** for permission checks — explicitly rejected (D-11); revisit only if "trust + parse error" UX proves insufficient.

### Milestone-mismatch flag (raised during discussion)

- **Phase 40 is in milestone v7.1 (UX Polish & i18n Debt) but is thematically v7.2 work** — `PROJECT.md` lists *"v7.2 ClubCloud Integration (Endrangliste auto-calculation, CC API finalization, credentials delegation)"* in the deferred section. Phase 40 likely belongs there. Options for the planner / next milestone-kickoff: (a) leave Phase 40 in v7.1 as a one-off (current state), (b) shift to v7.2 when v7.2 starts, (c) defer Phase 40 execution until v7.2. Discuss-phase flagged this; the user accepted Phase 40 in v7.1 for now. No action this phase — note for future milestone planning.

### Reviewed Todos (not folded)

- *Detail-Form "Mehrsatzspiel"-Toggle persistiert sets_to_win/sets_to_play nicht* — surfaced by todo-match (score 0.6, spurious keyword match). Unrelated to Phase 40.
- *Implement BK-Family Tiebreak & Nachstoß Canonical Spec* — surfaced by todo-match (score 0.6, spurious keyword match). Unrelated to Phase 40.

</deferred>

---

*Phase: 40-mcp-server-clubcloud*
*Context gathered: 2026-05-07*
