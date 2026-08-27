---
phase: 40-mcp-server-clubcloud
plan: 03
type: execute
wave: 2
depends_on: ["40-01"]
files_modified:
  - lib/mcp_server/resources/api_surface.rb
  - test/mcp_server/resources/api_surface_test.rb
autonomous: true
requirements: [D-01, D-04, D-06, D-17]
requirements_addressed: [D-01, D-04, D-06, D-17]
user_setup: []

must_haves:
  truths:
    - "MCP server, when booted, exposes EXACTLY 15 resources at URIs `cc://api/{action}` corresponding to the curated PATH_MAP allowlist (10 read lookups + 4 write/admin actions + 1 dashboard root `home`) — within D-04's 10-20 range. Locked count fixes Warning 5 (was inconsistent 13 vs 15)."
    - "Each `cc://api/{action}` resource, when read, returns a structured Markdown excerpt: action name, HTTP method (GET vs POST), path, read_only flag, used_by syncer reference (if any), MCP-tool-wrapping reference"
    - "`McpServer::Resources::ApiSurface.all` returns Array<MCP::Resource> with exactly 15 entries (locked, asserted by drift-guard test against PATH_MAP keys)"
    - "ApiSurface respects D-04 — only the 15 curated actions are exposed, NOT all ~100 PATH_MAP entries (auto-mapping is explicitly forbidden)"
    - "Plan 03 does NOT register its own resources_read_handler — Plan 01's central dispatcher routes `cc://api/{action}` to `ApiSurface.read(action:)` (per revision Blockers 2+3, Wave-2 conflict-free with Plan 02)"
  artifacts:
    - path: "lib/mcp_server/resources/api_surface.rb"
      provides: "MCP::Resource registrations for cc://api/{action} for the 15 curated PATH_MAP entries (D-04 allowlist) + .read(action:) class method (NO handler registration — Plan 01 owns it)"
      min_lines: 100
    - path: "test/mcp_server/resources/api_surface_test.rb"
      provides: "Tests verifying exact 15-entry curated list, URI shape, content includes path + read_only flag + drift-guard against PATH_MAP"
      min_lines: 50
  key_links:
    - from: "lib/mcp_server/resources/api_surface.rb"
      to: "RegionCc::ClubCloudClient::PATH_MAP"
      via: "constant reference + key whitelist"
      pattern: "RegionCc::ClubCloudClient::PATH_MAP\\["
    - from: "lib/mcp_server/server.rb (Plan 01 central dispatcher)"
      to: "ApiSurface.read(action:)"
      via: "case-statement URI dispatch in install_central_read_handler"
      pattern: "ApiSurface\\.read\\(action:"
---

<objective>
Build the technical CC-API-surface resource family — exposes the curated 15-entry
PATH_MAP allowlist as MCP resources at `cc://api/{action}`. Audience (a) per D-17
(Carambus developers in Claude Code) needs this to explore the CC integration
surface from inside a chat without leaving for the source file.

D-04 explicitly forbids auto-mapping all ~100 PATH_MAP entries — this plan only
exposes the curated 15 (the same actions Plans 04-05 wrap as tools, plus `home`
as the dashboard root). The allowlist is locked by RESEARCH §"Curated PATH_MAP
Allowlist".

**Revision 2026-05-07 changes (Warning 5 + Blockers 2+3):**
- Locked count is **15** (was inconsistent: must_haves said 13, code had 15, test asserted 15). All references now consistently say "15 entries (10 read lookups + 4 write/admin actions + 1 dashboard root `home`)" within D-04's 10-20 allowance.
- Plan 03 no longer calls `server.resources_read_handler`. Plan 01's `Server.install_central_read_handler` dispatches `cc://api/{action}` URIs to `ApiSurface.read(action:)`. Plan 03 only owns the data, the resource list (`.all`), and the read class method.

Output: A registry class `McpServer::Resources::ApiSurface` that auto-loads via
Plan 01's dynamic registry, plus tests verifying exact-15-count, URI shape, and
PATH_MAP drift guard.
</objective>

<execution_context>
@/Users/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/workflows/execute-plan.md
@/Users/gullrich/DEV/carambus/carambus_api/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@.planning/phases/40-mcp-server-clubcloud/40-CONTEXT.md
@.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md
@app/services/region_cc/club_cloud_client.rb

@lib/mcp_server/server.rb

<interfaces>
<!-- Existing constant this plan reads -->

From app/services/region_cc/club_cloud_client.rb:20-422:
```ruby
class RegionCc::ClubCloudClient
  PATH_MAP = {
    "home" => ["", true],
    "showLeagueList" => ["/admin/report/showLeagueList.php", true],
    "showLeague" => ["/admin/league/showLeague.php", true],
    # ... (15 curated entries used by Plan 03; ~100 total in PATH_MAP)
    "releaseMeldeliste" => ["/admin/einzel/meldelisten/releaseMeldeliste.php", false],
    # ... ~80 other entries (NOT exposed per D-04)
  }.freeze
end
```

From lib/mcp_server/server.rb (Plan 01 — central dispatcher):
```ruby
when %r{\Acc://api/(?<action>[\w-]+)\z}
  if defined?(McpServer::Resources::ApiSurface)
    content = McpServer::Resources::ApiSurface.read(action: $~[:action])
    [{ uri: uri, mimeType: "text/markdown", text: content }]
  end
```

Plan 03 must therefore expose:
  - `ApiSurface.all` → Array<MCP::Resource> (size 15)
  - `ApiSurface.read(action:)` → String (markdown content)
  - **NO `install_read_handler` method** (Plan 01 central dispatcher per Blockers 2+3)
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Implement ApiSurface registry class with curated 15-entry allowlist (.all + .read, NO handler)</name>
  <files>lib/mcp_server/resources/api_surface.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md (section "Curated PATH_MAP Allowlist (D-04 Empfehlung)" — locks the 15-entry list)
    - /Users/gullrich/DEV/carambus/carambus_api/app/services/region_cc/club_cloud_client.rb (lines 17-422 — verify all 15 actions exist in PATH_MAP)
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/resources/workflow_scenarios.rb (Plan 02 sibling — copy `.all + .read` pattern; do NOT copy install_read_handler — none exists)
  </read_first>
  <behavior>
    - `ApiSurface.all` returns 15 MCP::Resource instances
    - URIs are exactly: `cc://api/home`, `cc://api/showLeagueList`, `cc://api/showLeague`, `cc://api/showMeisterschaftenList`, `cc://api/showMeisterschaft`, `cc://api/showMeldelistenList`, `cc://api/showMeldeliste`, `cc://api/showTeam`, `cc://api/showClubList`, `cc://api/showAnnounceList`, `cc://api/spielbericht`, `cc://api/showCategory`, `cc://api/showSerie`, `cc://api/suche`, `cc://api/releaseMeldeliste` → exactly **15** entries
    - Breakdown: 10 read lookups (`showLeagueList`, `showLeague`, `showMeisterschaftenList`, `showMeisterschaft`, `showMeldelistenList`, `showMeldeliste`, `showTeam`, `showClubList`, `spielbericht`, `suche`) + 4 write/admin (`showAnnounceList`, `showCategory`, `showSerie`, `releaseMeldeliste`) + 1 dashboard root (`home`) = 15. Within D-04's 10-20 allowance.
    - Each resource description identifies it as part of the curated D-04 allowlist
    - `read(action:)` returns Markdown of the form:
      ```
      # CC Action: {action}

      **Path:** {path}
      **Read-Only:** {true|false}
      **Used by Syncer:** {syncer or "—"}
      **Wrapped by MCP-Tool:** `{tool_name or "(exposed as resource only)"}`

      ## Verwendung im MCP-Server
      {description}

      ## Quellen
      ...
      ```
  </behavior>
  <action>
    Step 1 — Create `lib/mcp_server/resources/api_surface.rb`:
    ```ruby
    # frozen_string_literal: true
    # ApiSurface — Exposes curated PATH_MAP-Subset (D-04 Allowlist) als MCP-Resources
    # unter cc://api/{action}. NICHT alle ~100 PATH_MAP-Entries (D-04 verbietet auto-mapping).
    # Locked count: exactly 15 entries (10 read lookups + 4 write/admin + 1 dashboard root `home`).
    # Within D-04's 10-20 allowance.
    #
    # IMPORTANT (revision 2026-05-07 Blockers 2+3): Plan 01's `Server.install_central_read_handler`
    # owns the resources_read_handler. This class only exposes `.all` (resource list) + `.read(action:)`
    # (content lookup). NO `install_read_handler` here — that would conflict with Plan 02 in Wave 2.

    module McpServer
      module Resources
        class ApiSurface
          # 15 curated entries — locked per RESEARCH §"Curated PATH_MAP Allowlist (D-04 Empfehlung)".
          # Breakdown:
          #   10 read lookups (wrapped by Plan 04 read tools): showLeagueList, showLeague,
          #     showMeisterschaftenList, showMeisterschaft, showMeldelistenList, showMeldeliste,
          #     showTeam, showClubList, spielbericht, suche
          #   4 write/admin (wrapped or referenced by Plan 05): showAnnounceList, showCategory,
          #     showSerie, releaseMeldeliste
          #   1 dashboard root: home
          # Total: 15 (within D-04 10-20 range).
          ALLOWLIST = %w[
            home
            showLeagueList
            showLeague
            showMeisterschaftenList
            showMeisterschaft
            showMeldelistenList
            showMeldeliste
            showTeam
            showClubList
            showAnnounceList
            spielbericht
            showCategory
            showSerie
            suche
            releaseMeldeliste
          ].freeze

          # Mapping action → syncer-reference (extracted from RESEARCH §"Curated PATH_MAP Allowlist").
          USED_BY_SYNCER = {
            "showLeagueList" => "league_syncer.rb",
            "showLeague" => "league_syncer.rb",
            "showMeisterschaftenList" => "tournament_syncer.rb",
            "showMeisterschaft" => "tournament_syncer.rb",
            "showMeldelistenList" => "registration_syncer.rb",
            "showMeldeliste" => "registration_syncer.rb",
            "showTeam" => "league_syncer.rb",
            "showClubList" => "club_syncer.rb",
            "showAnnounceList" => "club_syncer.rb",
            "spielbericht" => "party_syncer.rb",
            "showCategory" => "tournament_syncer.rb",
            "showSerie" => "tournament_syncer.rb",
            "suche" => "(cross-syncer)",
            "releaseMeldeliste" => "(none — Plan 05 write-tool)"
          }.freeze

          # Mapping action → MCP-tool-name (Plans 04/05 EN-named per D-20).
          WRAPPED_BY_TOOL = {
            "showLeagueList" => "cc_lookup_league",
            "showLeague" => "cc_lookup_league",
            "showMeisterschaftenList" => "cc_lookup_tournament",
            "showMeisterschaft" => "cc_lookup_tournament",
            "showMeldelistenList" => "cc_lookup_teilnehmerliste",
            "showMeldeliste" => "cc_lookup_teilnehmerliste",
            "showTeam" => "cc_lookup_team",
            "showClubList" => "cc_lookup_club",
            "showAnnounceList" => "cc_lookup_club",
            "spielbericht" => "cc_lookup_spielbericht",
            "showCategory" => "cc_lookup_category",
            "showSerie" => "cc_lookup_serie",
            "suche" => "cc_search_player",
            "releaseMeldeliste" => "cc_finalize_teilnehmerliste"
          }.freeze

          def self.all
            ALLOWLIST.map do |action|
              entry = RegionCc::ClubCloudClient::PATH_MAP[action]
              next nil unless entry  # Defensive — ALLOWLIST should match PATH_MAP exactly
              MCP::Resource.new(
                uri: "cc://api/#{action}",
                name: "api-#{action}",
                title: "CC Action: #{action}",
                description: "Curated CC-API action (D-04 allowlist) — path: #{entry[0]}, read_only: #{entry[1]}",
                mime_type: "text/markdown"
              )
            end.compact
          end

          # Called by Plan 01's central read-handler dispatcher.
          # Returns String (markdown content) — never raises.
          def self.read(action:)
            return not_in_allowlist(action) unless ALLOWLIST.include?(action)
            entry = RegionCc::ClubCloudClient::PATH_MAP[action]
            return missing(action) unless entry

            path, read_only = entry
            syncer = USED_BY_SYNCER[action] || "—"
            tool_name = WRAPPED_BY_TOOL[action] || "(exposed as resource only)"

            <<~MARKDOWN
              # CC Action: #{action}

              **Path:** `#{path}`
              **Read-Only:** #{read_only}
              **Used by Syncer:** #{syncer}
              **Wrapped by MCP-Tool:** `#{tool_name}`

              ## Verwendung im MCP-Server

              Diese CC-Action gehört zur **D-04 curated allowlist** (Phase 40, 15 Entries total). Sie wird vom MCP-Server
              entweder als Read-Lookup-Tool (Plan 04) oder als Write-Tool (Plan 05, nur `releaseMeldeliste`
              shipped als Proof) exponiert — oder ist eine reine Resource ohne Tool-Wrapper.

              ## Quellen

              - PATH_MAP-Eintrag: `app/services/region_cc/club_cloud_client.rb`
              - Allowlist-Begründung: `.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md`
                (Sektion "Curated PATH_MAP Allowlist")
            MARKDOWN
          end

          def self.not_in_allowlist(action)
            "# CC-Action `#{action}` nicht in Allowlist\n\n" \
              "Per D-04 sind nur 15 curated Actions als MCP-Resources exponiert. " \
              "Andere PATH_MAP-Einträge sind absichtlich nicht erreichbar."
          end

          def self.missing(action)
            "# CC-Action `#{action}` nicht in PATH_MAP\n\n" \
              "Allowlist-Konfigurationsfehler — Action fehlt in PATH_MAP."
          end
        end
      end
    end
    ```

    Step 2 — Verify 15 resources are picked up by `McpServer::Server.build` (Plan 01 dynamic registry):
    ```
    bundle exec rails runner "puts McpServer::Resources::ApiSurface.all.size"
    ```
    Must output `15`.
  </action>
  <verify>
    <automated>bundle exec rails runner "puts McpServer::Resources::ApiSurface.all.size; puts McpServer::Resources::ApiSurface.all.map(&:uri).first(3).inspect"</automated>
  </verify>
  <acceptance_criteria>
    - `lib/mcp_server/resources/api_surface.rb` exists with `frozen_string_literal: true` on line 2
    - `bundle exec rails runner "puts McpServer::Resources::ApiSurface::ALLOWLIST.size"` outputs `15`
    - `bundle exec rails runner "puts McpServer::Resources::ApiSurface.all.size"` outputs `15`
    - All URIs match `cc://api/{action}` shape: `bundle exec rails runner "puts McpServer::Resources::ApiSurface.all.all? { |r| r.uri =~ %r{\\Acc://api/[\\w-]+\\z} }"` outputs `true`
    - `read(action: "releaseMeldeliste")` includes `cc_finalize_teilnehmerliste` reference
    - `read(action: "showLeagueList")` includes `league_syncer.rb`
    - All 15 ALLOWLIST entries map to existing PATH_MAP keys (drift guard validated by Task 2)
    - **No install_read_handler method** (per Blockers 2+3): `grep -c "install_read_handler\|resources_read_handler" lib/mcp_server/resources/api_surface.rb` returns 0
    - **No conditional refactor instruction** (per Blocker 3): `grep -c "if SDK only allows one handler\|refactor.*server\\.rb" lib/mcp_server/resources/api_surface.rb` returns 0
    - **Locked count consistency**: `grep -c "15 entries\|15 curated\|exactly 15\|15 (within D-04" lib/mcp_server/resources/api_surface.rb` returns >= 2 (header comment + dispatcher comment)
  </acceptance_criteria>
  <done>ApiSurface registry compiled; 15 resources exposed at `cc://api/{action}` URIs; D-04 allowlist enforced (no auto-mapping); NO read-handler registration (Blockers 2+3 satisfied); count consistency locked (Warning 5 fix).</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: ApiSurface tests + server-build integration</name>
  <files>test/mcp_server/resources/api_surface_test.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/resources/api_surface.rb (just-written file)
    - /Users/gullrich/DEV/carambus/carambus_api/test/mcp_server/resources/workflow_scenarios_test.rb (Plan 02 reference for test style — likely landed in same wave but if missing reference Plan 01 server_smoke_test.rb instead)
  </read_first>
  <behavior>
    - Test 1: `.all` returns 15 MCP::Resource instances (locked count, Warning 5 fix)
    - Test 2: All URIs match `cc://api/{action}` regex
    - Test 3: All actions in ALLOWLIST exist as keys in `RegionCc::ClubCloudClient::PATH_MAP` (drift guard)
    - Test 4: `.read(action: "releaseMeldeliste")` markdown contains `cc_finalize_teilnehmerliste` (D-04 mapping correct)
    - Test 5: `.read(action: "showLeagueList")` markdown contains `league_syncer.rb`
    - Test 6: `.read(action: "nonexistent")` returns "nicht in Allowlist" body (no raise)
    - Test 7: `McpServer::Server.build.resources` includes 15 cc://api/* resources
  </behavior>
  <action>
    Create `test/mcp_server/resources/api_surface_test.rb`:
    ```ruby
    # frozen_string_literal: true
    require "test_helper"

    class McpServer::Resources::ApiSurfaceTest < ActiveSupport::TestCase
      test "all returns 15 curated MCP::Resource instances (D-04 allowlist locked, Warning 5 fix)" do
        resources = McpServer::Resources::ApiSurface.all
        assert_equal 15, resources.size, "ALLOWLIST size drifted — update test or revise allowlist"
        assert resources.all? { |r| r.is_a?(MCP::Resource) }
      end

      test "all URIs match cc://api/{action}" do
        McpServer::Resources::ApiSurface.all.each do |r|
          assert_match %r{\Acc://api/[\w-]+\z}, r.uri
        end
      end

      test "all ALLOWLIST entries exist in PATH_MAP (drift guard)" do
        missing = McpServer::Resources::ApiSurface::ALLOWLIST.reject { |k| RegionCc::ClubCloudClient::PATH_MAP.key?(k) }
        assert_empty missing, "ALLOWLIST entries missing from PATH_MAP: #{missing.inspect}"
      end

      test "read(action: 'releaseMeldeliste') cross-references cc_finalize_teilnehmerliste tool (D-04 mapping)" do
        md = McpServer::Resources::ApiSurface.read(action: "releaseMeldeliste")
        assert_match(/cc_finalize_teilnehmerliste/, md)
        assert_match(/Read-Only.*false/, md)
      end

      test "read(action: 'showLeagueList') names the syncer (D-04 mapping)" do
        md = McpServer::Resources::ApiSurface.read(action: "showLeagueList")
        assert_match(/league_syncer\.rb/, md)
      end

      test "read(action: unknown) returns not-in-allowlist body (no exception)" do
        md = McpServer::Resources::ApiSurface.read(action: "nonexistent")
        assert_match(/nicht in Allowlist/, md)
      end

      test "server.build includes 15 cc://api/* resources" do
        server = McpServer::Server.build
        api_uris = server.resources.map(&:uri).select { |u| u.start_with?("cc://api/") }
        assert_equal 15, api_uris.size
      end
    end
    ```

    Run:
    ```
    bin/rails test test/mcp_server/resources/api_surface_test.rb
    ```
    7 tests, all must pass.
  </action>
  <verify>
    <automated>bin/rails test test/mcp_server/resources/api_surface_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - `test/mcp_server/resources/api_surface_test.rb` exists with `frozen_string_literal: true` on line 2
    - `bin/rails test test/mcp_server/resources/api_surface_test.rb` reports `7 runs, 0 failures, 0 errors`
    - Drift-guard test (Test 3) explicitly checks PATH_MAP keys to catch future renames: `grep "all ALLOWLIST entries exist in PATH_MAP" test/mcp_server/resources/api_surface_test.rb` returns 1 line
    - Locked count: Test 1 asserts `15`, NOT `13` (Warning 5 fix)
  </acceptance_criteria>
  <done>7 tests pass; D-04 15-entry curated allowlist enforced and protected against drift; server.build picks up the 15 resources via Plan 01 dynamic registry.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| MCP-client → server.resources/read | URI controlled by client; Plan 01 central dispatcher delegates to ApiSurface.read which validates against ALLOWLIST |
| server → PATH_MAP constant | read-only reference, no mutation |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-40-03-01 | Information Disclosure | Resource leaks credentials/tokens via PATH_MAP excerpt | accept | PATH_MAP contains URL paths only, no secrets; verified by reading lines 17-422 |
| T-40-03-02 | Tampering | Allowlist-bypass via cc://api/{arbitrary action} | mitigate | `read(action:)` whitelists against `ALLOWLIST` constant; "nicht in Allowlist" returned for non-listed actions (Test 6); Plan 01 dispatcher additionally regex-validates URI shape |
| T-40-03-03 | Elevation of Privilege | Auto-mapping all 100 PATH_MAP entries (D-04 violation) | mitigate | Manual ALLOWLIST array of EXACTLY 15 entries; drift-guard test (Test 3); D-04 explicitly in plan and code comment |
</threat_model>

<verification>
- 15 cc://api/* resources registered (D-04 curated, no auto-mapping)
- All ALLOWLIST keys exist in PATH_MAP (drift guard)
- read(action:) returns markdown with action path, read_only flag, syncer cross-ref, and MCP-tool cross-ref (D-04 + D-20)
- 7 tests pass
- `McpServer::Server.build.resources.size` total >= 5 (workflow) + 15 (api) = 20
- **Plan 03 does NOT touch server.rb** — `git diff --stat lib/mcp_server/server.rb` for this plan should show 0 changes; only Plan 01 owns server.rb (Wave 2 conflict-free with Plan 02)
</verification>

<success_criteria>
- ApiSurface exposes exactly 15 curated CC-actions (locked, Warning 5 fix), NOT all 100
- Each action's resource markdown identifies the wrapping MCP-tool name (Plan 04/05) and the syncer that uses it
- D-04 allowlist enforcement is verified by automated drift-guard test
- All 7 tests pass
- Same-wave with Plan 02 (no file overlap with workflow_scenarios.rb / workflow_meta.rb; neither touches server.rb)
</success_criteria>

<output>
After completion, create `.planning/phases/40-mcp-server-clubcloud/40-03-SUMMARY.md` documenting:
- Final ALLOWLIST entry count (locked: 15)
- Confirmation that Plan 03 does NOT call `resources_read_handler` (Blockers 2+3 audit)
- Path-map drift findings (if any allowlist entries needed adjustment because PATH_MAP key was renamed since RESEARCH was written)
</output>
</content>
</invoke>