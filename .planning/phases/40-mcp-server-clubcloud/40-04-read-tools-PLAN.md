---
phase: 40-mcp-server-clubcloud
plan: 04
type: execute
wave: 2
depends_on: ["40-01"]
files_modified:
  - lib/mcp_server/tools/lookup_region.rb
  - lib/mcp_server/tools/lookup_league.rb
  - lib/mcp_server/tools/lookup_tournament.rb
  - lib/mcp_server/tools/lookup_teilnehmerliste.rb
  - lib/mcp_server/tools/lookup_team.rb
  - lib/mcp_server/tools/lookup_club.rb
  - lib/mcp_server/tools/lookup_spielbericht.rb
  - lib/mcp_server/tools/lookup_category.rb
  - lib/mcp_server/tools/lookup_serie.rb
  - lib/mcp_server/tools/search_player.rb
  - test/mcp_server/tools/lookup_region_test.rb
  - test/mcp_server/tools/lookup_teilnehmerliste_test.rb
  - test/mcp_server/tools/search_player_test.rb
autonomous: true
requirements: [D-01, D-02, D-04, D-17, D-18, D-20]
requirements_addressed: [D-01, D-02, D-04, D-17, D-18, D-20]
user_setup: []

must_haves:
  truths:
    - "10 read tools are registered in McpServer::Server.build, all with `cc_lookup_*` or `cc_search_*` names per D-20 (EN tool surface)"
    - "D-02 (DB-first) applies to 4 of 10 read tools — `cc_lookup_region`, `cc_lookup_league`, `cc_lookup_tournament`, `cc_lookup_teilnehmerliste` — because Carambus has matching mirror models (Region+RegionCc, LeagueCc, TournamentCc, Tournament). The other 6 tools (`cc_lookup_team`, `cc_lookup_club`, `cc_lookup_spielbericht`, `cc_lookup_category`, `cc_lookup_serie`, `cc_search_player`) are LIVE-ONLY because no Carambus mirror model exists for them. (Warning 6 fix.)"
    - "All tools subclass `McpServer::Tools::BaseTool` (Plan 01) and use `BaseTool.error` for missing-required-parameter responses (D-04 + Pitfall 6)"
    - "`cc_lookup_teilnehmerliste` is the D-18 acceptance-story read pathway: given `tournament_id`, returns whether the Meldeliste exists in CC (DB-first, with status info)"
    - "All 10 tools have JSON-schema descriptions in EN (D-20); tool method `description` ist EN-only"
    - "Tools use SDK API contracts locked by Plan 01 Task 3 SDK-API smoke probe (no conditional hedges remain — Warning 8 fix)"
  artifacts:
    - path: "lib/mcp_server/tools/lookup_region.rb"
      provides: "MCP tool cc_lookup_region — DB-first canonical reference; shape mirrored by 9 other tools"
      min_lines: 30
    - path: "lib/mcp_server/tools/lookup_teilnehmerliste.rb"
      provides: "MCP tool cc_lookup_teilnehmerliste — D-18 acceptance-story read pathway"
      min_lines: 35
    - path: "lib/mcp_server/tools/search_player.rb"
      provides: "MCP tool cc_search_player — uses `suche` PATH_MAP action, no DB-first (live-only)"
      min_lines: 25
  key_links:
    - from: "lib/mcp_server/tools/lookup_*.rb (DB-first 4 tools)"
      to: "Region, RegionCc, LeagueCc, TournamentCc models (DB-first)"
      via: "ActiveRecord find_by"
      pattern: "(Region|LeagueCc|TournamentCc)\\.find_by"
    - from: "lib/mcp_server/tools/lookup_*.rb (all 10)"
      to: "McpServer::CcSession.client_for + .cookie (live fallback)"
      via: "force_refresh branch (DB-first 4) or always (live-only 6)"
      pattern: "cc_session\\.client_for|cc_session\\.cookie"
---

<objective>
Build the 10-tool read-lookup surface — the EN-named (`cc_lookup_*`) tool family
that closes the second half of the D-18 acceptance story. After Plan 02 surfaces
the workflow doc and Plan 04 ships these tools, a Turnierleiter in Claude Desktop
can ask "gibt es eine Teilnehmerliste in CC für Turnier X" and receive a structured
answer.

Per D-02: DB-first applies to the **4 tools with Carambus mirror models** (region,
league, tournament, teilnehmerliste); force-refresh falls back to live CC-call.
The other **6 tools are live-only** (no Carambus mirror exists for team/club/
spielbericht/category/serie/player-search).

**Revision 2026-05-07 changes:**
- Task 1 split into 1a (canonical `cc_lookup_region` + helper) and 1b (9 remaining tools by mechanical replication) per Warning 9 — keeps each task in 15-60 min Claude execution range.
- Live-only count corrected from "3" to "6" with explicit list per Warning 6.
- SDK API hedges removed — Plans rely on Plan 01 Task 3 SDK-API smoke probe results (Warning 8).

Output: 10 MCP::Tool subclasses under `lib/mcp_server/tools/` (per RESEARCH §"Curated
PATH_MAP Allowlist > Read-Tools (10)") + 3 representative tests (one DB-first, one
acceptance-story, one live-only). Other 7 tools share the same shape — tests for
all 10 belong to Plan 06's exhaustive smoke pass.
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
@.planning/phases/40-mcp-server-clubcloud/40-01-SUMMARY.md

@app/services/region_cc/club_cloud_client.rb
@app/models/region.rb
@app/models/region_cc.rb
@app/models/league_cc.rb
@app/models/tournament_cc.rb

@lib/mcp_server/server.rb
@lib/mcp_server/tools/base_tool.rb
@lib/mcp_server/cc_session.rb

<interfaces>
<!-- Plan 01 contracts this plan plugs into -->

From lib/mcp_server/tools/base_tool.rb (Plan 01):
```ruby
class McpServer::Tools::BaseTool < MCP::Tool
  def self.error(message); end                       # MCP::Tool::Response error envelope
  def self.text(message); end                        # MCP::Tool::Response text envelope
  def self.validate_required!(args, required_keys); end # nil on success, error response on failure
  def self.mock_mode?; end                           # true if CARAMBUS_MCP_MOCK=1
  def self.cc_session; McpServer::CcSession; end
end
```

From lib/mcp_server/cc_session.rb (Plan 01 — fully implemented, no placeholder):
```ruby
McpServer::CcSession.client_for     # returns RegionCc::ClubCloudClient or McpServer::Tools::MockClient
McpServer::CcSession.cookie         # returns active PHPSESSID (lazy login + 30-min TTL via Setting.login_to_cc)
```

**SDK API contracts (locked by Plan 01 Task 3 SDK-API smoke probe — see 40-01-SUMMARY.md):**
- `tool_name "cc_..."` is a class-level DSL declaration on MCP::Tool subclasses
- `description "..."` and `input_schema(properties: {}, required: [])` are class-level DSLs
- `annotations(read_only_hint: true, destructive_hint: false)` is a class-level DSL
- `MCP::Tool::Response.new(content_array, error: bool)` constructor; instance has `#error` and `#content` accessors
- These contracts are NOT hedged — Plan 01 verifies them at install time. If they break in a future SDK upgrade, Plan 01 Tests 5+6 fail FIRST.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1a: Implement canonical `cc_lookup_region` tool (1 file + helper convention)</name>
  <files>lib/mcp_server/tools/lookup_region.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md (Pattern 2 — read-tool template, Pitfall 6 — schema is descriptive, section "Curated PATH_MAP Allowlist > Read-Tools (10)")
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-01-SUMMARY.md (SDK API findings)
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/base_tool.rb (Plan 01 base class)
    - /Users/gullrich/DEV/carambus/carambus_api/app/models/region.rb (verify shortname column)
    - /Users/gullrich/DEV/carambus/carambus_api/app/models/region_cc.rb (cc_id column)
  </read_first>
  <behavior>
    Canonical shape that 9 other tools mirror in Task 1b:
    - subclass `McpServer::Tools::BaseTool`
    - `tool_name "cc_lookup_region"` (EN per D-20)
    - `description` (EN, 1-3 sentences)
    - `input_schema` with all parameters typed
    - `annotations(read_only_hint: true, destructive_hint: false)`
    - `self.call(server_context:, **args)` method that:
      1. Validates required params (anyof or required) — return early on failure
      2. Branches on `args[:force_refresh]`: false → DB lookup; true → live CC-call via `cc_session`
      3. Returns `text(...)` with structured JSON or "not found" message
      4. Defensive nil-check before `.to_json`
  </behavior>
  <action>
    Create `lib/mcp_server/tools/lookup_region.rb` as the canonical template:
    ```ruby
    # frozen_string_literal: true
    # cc_lookup_region — DB-first Region lookup by shortname or fed_id (D-02).
    # CANONICAL TEMPLATE — Task 1b mirrors this shape for 9 other read tools.
    # D-18 acceptance-story foundation.

    module McpServer
      module Tools
        class LookupRegion < BaseTool
          tool_name "cc_lookup_region"
          description "Look up a Carambus region by shortname (e.g. 'BCW') or ClubCloud federation ID. " \
                      "Returns region metadata from the local Carambus DB by default; pass force_refresh=true to query CC live."
          input_schema(
            properties: {
              shortname:     { type: "string",  description: "Region shortname like 'BCW'" },
              fed_id:        { type: "integer", description: "ClubCloud federation ID" },
              force_refresh: { type: "boolean", default: false, description: "Bypass DB cache, query CC live" }
            }
          )
          annotations(read_only_hint: true, destructive_hint: false)

          def self.call(shortname: nil, fed_id: nil, force_refresh: false, server_context: nil)
            err = validate_required_anyof!(shortname: shortname, fed_id: fed_id)
            return err if err

            if force_refresh
              return live_lookup(fed_id: fed_id)
            end

            region = if shortname
              Region.find_by(shortname: shortname)
            else
              region_cc = RegionCc.find_by(cc_id: fed_id)
              region_cc&.region
            end

            return error("Region not found in Carambus DB. Try force_refresh: true to query CC.") if region.nil?

            text(format_region(region))
          end

          def self.validate_required_anyof!(shortname:, fed_id:)
            return nil if shortname.present? || fed_id.present?
            error("Missing required parameter: provide at least one of `shortname` or `fed_id`")
          end

          def self.live_lookup(fed_id:)
            return error("Missing required parameter for live lookup: fed_id") if fed_id.blank?
            client = cc_session.client_for
            res, doc = client.get("home", { fedId: fed_id }, { session_id: cc_session.cookie })
            return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
            text("CC live response (status #{res.code}, body length #{doc&.text&.length || 0} chars)")
          end

          def self.format_region(region)
            JSON.generate(
              id: region.id,
              shortname: region.shortname,
              name: region.name,
              cc_id: region.region_cc&.cc_id
            )
          end
        end
      end
    end
    ```
  </action>
  <verify>
    <automated>bundle exec rails runner "tool = McpServer::Tools::LookupRegion; abort('not subclass') unless tool < McpServer::Tools::BaseTool; abort('wrong tool_name') unless tool.respond_to?(:tool_name); puts 'LookupRegion shape OK'"</automated>
  </verify>
  <acceptance_criteria>
    - `lib/mcp_server/tools/lookup_region.rb` exists with `frozen_string_literal: true` on line 2
    - `grep -c "tool_name \"cc_lookup_region\"" lib/mcp_server/tools/lookup_region.rb` returns 1
    - `grep -c "< BaseTool" lib/mcp_server/tools/lookup_region.rb` returns 1
    - `grep -c "read_only_hint: true" lib/mcp_server/tools/lookup_region.rb` returns 1
    - `bundle exec rails runner "puts McpServer::Tools::LookupRegion.respond_to?(:call)"` outputs `true`
  </acceptance_criteria>
  <done>Canonical `cc_lookup_region` tool compiled; serves as the template for Task 1b's 9 mechanical replicas.</done>
</task>

<task type="auto">
  <name>Task 1b: Implement remaining 9 read tools using canonical pattern (mechanical replication)</name>
  <files>lib/mcp_server/tools/lookup_league.rb, lib/mcp_server/tools/lookup_tournament.rb, lib/mcp_server/tools/lookup_teilnehmerliste.rb, lib/mcp_server/tools/lookup_team.rb, lib/mcp_server/tools/lookup_club.rb, lib/mcp_server/tools/lookup_spielbericht.rb, lib/mcp_server/tools/lookup_category.rb, lib/mcp_server/tools/lookup_serie.rb, lib/mcp_server/tools/search_player.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/lookup_region.rb (Task 1a canonical — copy shape)
    - /Users/gullrich/DEV/carambus/carambus_api/app/models/league_cc.rb
    - /Users/gullrich/DEV/carambus/carambus_api/app/models/tournament_cc.rb
    - /Users/gullrich/DEV/carambus/carambus_api/app/services/region_cc/registration_syncer.rb (model for showMeldelistenList composition — Plan 04 lookup_teilnehmerliste mirrors this)
  </read_first>
  <action>
    Mechanically replicate the canonical pattern for 9 tools.

    **DB-first 3 tools (have Carambus mirror models)** — full DB-first + force_refresh branch like LookupRegion:

    - `lookup_league.rb` — `tool_name "cc_lookup_league"`, params `fed_id`, `branch_id`, `season`, `league_id`, `force_refresh`. DB-first via `LeagueCc.find_by(cc_id:, branch_id:, ...)`. Live-fallback: `client.get("showLeague", {leagueId: ..., fedId: ...}, ...)`.

    - `lookup_tournament.rb` — `tool_name "cc_lookup_tournament"`, params `fed_id`, `meisterschaft_id`, `season`, `force_refresh`. DB-first via `TournamentCc.find_by(cc_id: meisterschaft_id)`. Live-fallback: `client.get("showMeisterschaft", ..., ...)`.

    - `lookup_teilnehmerliste.rb` — **D-18 PRIMARY READ TOOL**. `tool_name "cc_lookup_teilnehmerliste"`, params `tournament_id` (Carambus internal), or `meldeliste_id` (CC), `fed_id`, `force_refresh`. Returns whether Meldeliste exists in CC + finalization status. DB-first: look up `Tournament` → its `TournamentCc.cc_id` → check if a corresponding registration mirror exists. Live-fallback: `client.get("showMeldelistenList", {fedId: fed_id}, ...)` then parse with Nokogiri to find row matching `meldeliste_id`. Description should explicitly mention this is the D-18 acceptance-story read pathway.

    **LIVE-ONLY 6 tools (no Carambus mirror)** — skip DB-first, always go live. Description explicitly states "live-only" because no Carambus mirror exists. NO `force_refresh` parameter needed (always live), but include it for API consistency if desired.

    - `lookup_team.rb` — `tool_name "cc_lookup_team"`, params `team_id`, `fed_id`. Live-only via `client.get("showTeam", ...)`. Description: "Live lookup of CC team by id. No Carambus-side mirror — always queries CC."

    - `lookup_club.rb` — `tool_name "cc_lookup_club"`, params `fed_id`, `branch_id`. Live-only via `client.get("showClubList", {fedId: fed_id}, ...)`. Description: "Live lookup of CC clubs by federation. No Carambus-side mirror with cc_id."

    - `lookup_spielbericht.rb` — `tool_name "cc_lookup_spielbericht"`, params `spielbericht_id`. Live-only via `spielbericht` action.

    - `lookup_category.rb` — `tool_name "cc_lookup_category"`, params `category_id`. Live-only via `showCategory` / `showCategoryList`.

    - `lookup_serie.rb` — `tool_name "cc_lookup_serie"`, params `serie_id`, `season`. Live-only via `showSerie` / `showSerienList`.

    - `search_player.rb` — `tool_name "cc_search_player"`, params `query` (string, required, min 2 chars), `fed_id`. Live-only via `suche` PATH_MAP action. Validate `query.length >= 2`.

    All tool files start with the 2-line frozen_string + comment header:
    ```ruby
    # frozen_string_literal: true
    # cc_<name> — <one-line EN description>; <"DB-first per D-02" OR "live-only (no Carambus mirror)">
    ```
    All `description` strings are EN per D-20. All Ruby comments inside tool methods are EN for technical (per CLAUDE.md split).

    Verify all 10 tools auto-register via Plan 01's `McpServer::Server.collect_tools`:
    ```
    bundle exec rails runner "puts McpServer::Server.build.tools.size"
    ```
    Output should show 10 tools (this plan) + 1 (Plan 05) = 11 if Plan 05 has landed, or 10 if Plan 04 alone.
  </action>
  <verify>
    <automated>bundle exec rails runner "tools = McpServer::Server.build.tools.select { |t| t.name.to_s.start_with?('McpServer::Tools::Lookup') || t.name.to_s.end_with?('SearchPlayer') }; puts tools.size"</automated>
  </verify>
  <acceptance_criteria>
    - All 9 tool files exist under `lib/mcp_server/tools/`: `ls lib/mcp_server/tools/lookup_league.rb lib/mcp_server/tools/lookup_tournament.rb lib/mcp_server/tools/lookup_teilnehmerliste.rb lib/mcp_server/tools/lookup_team.rb lib/mcp_server/tools/lookup_club.rb lib/mcp_server/tools/lookup_spielbericht.rb lib/mcp_server/tools/lookup_category.rb lib/mcp_server/tools/lookup_serie.rb lib/mcp_server/tools/search_player.rb | wc -l` returns 9
    - All 9 files have `frozen_string_literal: true` on line 2
    - All 9 tool classes inherit from `McpServer::Tools::BaseTool`
    - Combined with Task 1a: 10 read tools total, all EN-named: `grep -h 'tool_name "cc_' lib/mcp_server/tools/lookup_*.rb lib/mcp_server/tools/search_player.rb | wc -l` returns 10
    - **Live-only count is 6, not 3** (Warning 6 fix): the 6 live-only tools (lookup_team, lookup_club, lookup_spielbericht, lookup_category, lookup_serie, search_player) have NO `find_by` calls: `grep -L "find_by" lib/mcp_server/tools/lookup_team.rb lib/mcp_server/tools/lookup_club.rb lib/mcp_server/tools/lookup_spielbericht.rb lib/mcp_server/tools/lookup_category.rb lib/mcp_server/tools/lookup_serie.rb lib/mcp_server/tools/search_player.rb | wc -l` returns 6 (all 6 are returned by `-L` because they don't contain `find_by`)
    - DB-first count is 4 (with Task 1a): `grep -l "find_by" lib/mcp_server/tools/lookup_region.rb lib/mcp_server/tools/lookup_league.rb lib/mcp_server/tools/lookup_tournament.rb lib/mcp_server/tools/lookup_teilnehmerliste.rb | wc -l` returns 4
    - `cc_lookup_teilnehmerliste` description references D-18 acceptance story: `grep "Teilnehmerliste\|D-18" lib/mcp_server/tools/lookup_teilnehmerliste.rb | wc -l` returns >= 2
    - `bundle exec rails runner "puts McpServer::Tools.constants.select { |c| McpServer::Tools.const_get(c).is_a?(Class) && McpServer::Tools.const_get(c) < McpServer::Tools::BaseTool }.size"` outputs `>= 10`
  </acceptance_criteria>
  <done>9 read-tool files mechanically replicated from canonical; 10 read tools total auto-registered via Plan 01's collect_tools; all using EN tool_name per D-20; live-only/DB-first split is 6/4 (Warning 6 fix).</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Tests — DB-first lookup, live-fallback, D-18 acceptance-story flow, search_player live-only</name>
  <files>test/mcp_server/tools/lookup_region_test.rb, test/mcp_server/tools/lookup_teilnehmerliste_test.rb, test/mcp_server/tools/search_player_test.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/lookup_region.rb (Task 1a canonical)
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/lookup_teilnehmerliste.rb (Task 1b — D-18 tool)
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/search_player.rb (Task 1b — live-only example)
    - /Users/gullrich/DEV/carambus/carambus_api/test/fixtures/regions.yml (existing fixtures — for DB-first test)
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-01-SUMMARY.md (SDK API findings — confirms `response.error` / `response.content.first[:text]` shape)
  </read_first>
  <behavior>
    - LookupRegion test 1 (DB-first happy path): Given Region fixture, returns text response with shortname in JSON body
    - LookupRegion test 2 (DB-first miss): No matching region → error response with "not found"
    - LookupRegion test 3 (validation): No params → error "Missing required parameter"
    - LookupRegion test 4 (force_refresh + missing fed_id): error response
    - LookupTeilnehmerliste test 1 (D-18 acceptance-story DB-first): Given Tournament fixture, returns structured text
    - LookupTeilnehmerliste test 2 (D-18 not-found): Unknown tournament_id → error
    - LookupTeilnehmerliste test 3 (validation): Missing required → error
    - SearchPlayer test 1 (live-only): With CARAMBUS_MCP_MOCK=1, returns text response from MockClient (no DB query)
    - SearchPlayer test 2 (validation): query too short (< 2 chars) → error
    - SearchPlayer test 3 (validation): missing query → error
  </behavior>
  <action>
    Step 1 — Create `test/mcp_server/tools/lookup_region_test.rb`:
    ```ruby
    # frozen_string_literal: true
    require "test_helper"

    class McpServer::Tools::LookupRegionTest < ActiveSupport::TestCase
      setup do
        ENV["CARAMBUS_MCP_MOCK"] = "1"
        McpServer::CcSession.reset!
      end

      teardown do
        ENV["CARAMBUS_MCP_MOCK"] = nil
      end

      test "DB-first happy path: returns region by shortname" do
        region = Region.first
        skip "No region fixtures loaded" unless region
        response = McpServer::Tools::LookupRegion.call(shortname: region.shortname, server_context: nil)
        refute response.error
        body = response.content.first[:text]
        assert_match(/#{region.shortname}/i, body)
      end

      test "DB-first miss: returns not-found error response" do
        response = McpServer::Tools::LookupRegion.call(shortname: "ZZZ-IMPOSSIBLE-#{SecureRandom.hex(4)}", server_context: nil)
        assert response.error
        assert_match(/not found/i, response.content.first[:text])
      end

      test "validation: missing both shortname and fed_id returns error" do
        response = McpServer::Tools::LookupRegion.call(server_context: nil)
        assert response.error
        assert_match(/Missing required parameter|provide at least one/i, response.content.first[:text])
      end

      test "force_refresh requires fed_id" do
        response = McpServer::Tools::LookupRegion.call(shortname: "BCW", force_refresh: true, server_context: nil)
        assert response.error
        assert_match(/fed_id/i, response.content.first[:text])
      end
    end
    ```

    Step 2 — Create `test/mcp_server/tools/lookup_teilnehmerliste_test.rb`:
    ```ruby
    # frozen_string_literal: true
    require "test_helper"

    class McpServer::Tools::LookupTeilnehmerlisteTest < ActiveSupport::TestCase
      setup do
        ENV["CARAMBUS_MCP_MOCK"] = "1"
        McpServer::CcSession.reset!
      end

      teardown do
        ENV["CARAMBUS_MCP_MOCK"] = nil
      end

      test "D-18 acceptance story: lookup by tournament_id returns structured response" do
        tournament = Tournament.first
        skip "No tournament fixtures loaded" unless tournament
        response = McpServer::Tools::LookupTeilnehmerliste.call(tournament_id: tournament.id, server_context: nil)
        body = response.content.first[:text]
        assert(body.length.positive?)
      end

      test "unknown tournament_id returns error response" do
        response = McpServer::Tools::LookupTeilnehmerliste.call(tournament_id: 999_999_999, server_context: nil)
        assert response.error
      end

      test "missing required params returns validation error" do
        response = McpServer::Tools::LookupTeilnehmerliste.call(server_context: nil)
        assert response.error
        assert_match(/Missing required parameter/i, response.content.first[:text])
      end
    end
    ```

    Step 3 — Create `test/mcp_server/tools/search_player_test.rb`:
    ```ruby
    # frozen_string_literal: true
    require "test_helper"

    class McpServer::Tools::SearchPlayerTest < ActiveSupport::TestCase
      setup do
        ENV["CARAMBUS_MCP_MOCK"] = "1"
        McpServer::CcSession.reset!
      end

      teardown do
        ENV["CARAMBUS_MCP_MOCK"] = nil
      end

      test "live-only: triggers MockClient call (no DB lookup)" do
        response = McpServer::Tools::SearchPlayer.call(query: "Mustermann", server_context: nil)
        body = response.content.first[:text]
        assert(body.length.positive?)
        assert_match(/MOCK|mock|search|Mustermann/, body)
      end

      test "validation: query too short returns error" do
        response = McpServer::Tools::SearchPlayer.call(query: "M", server_context: nil)
        assert response.error
        assert_match(/at least 2|too short|min/i, response.content.first[:text])
      end

      test "validation: missing query returns error" do
        response = McpServer::Tools::SearchPlayer.call(server_context: nil)
        assert response.error
      end
    end
    ```

    Run tests:
    ```
    bin/rails test test/mcp_server/tools/lookup_region_test.rb test/mcp_server/tools/lookup_teilnehmerliste_test.rb test/mcp_server/tools/search_player_test.rb
    ```
    Expect 10 tests total (4 + 3 + 3), all passing. Skip-fallback handles missing fixtures.

    Note: `MCP::Tool::Response#error` and `#content` shape is locked by Plan 01 Task 3 SDK-API smoke probe (Warning 8 fix). If those Plan 01 tests pass, this test file's assertions are guaranteed correct shape — no conditional hedging needed.
  </action>
  <verify>
    <automated>bin/rails test test/mcp_server/tools/lookup_region_test.rb test/mcp_server/tools/lookup_teilnehmerliste_test.rb test/mcp_server/tools/search_player_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - All 3 test files exist with `frozen_string_literal: true` on line 2
    - Test run reports `10 runs` (4 + 3 + 3) `0 failures, 0 errors` (skips ok if fixtures missing)
    - SearchPlayer test verifies `CARAMBUS_MCP_MOCK=1` path is exercised (no real network call)
    - LookupRegion happy-path test asserts response is NOT an error and body contains the region shortname
  </acceptance_criteria>
  <done>3 representative test files (one DB-first, one D-18 acceptance, one live-only) cover the 10-tool family's three interaction modes; all 10 tests pass; Plan 06 will add exhaustive smoke tests for the remaining 7 tools.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| MCP-client → tool.call | LLM-supplied parameters; must validate per D-04 + Pitfall 6 |
| tool.call → CC-API (force_refresh path or live-only tools) | HTTPS via existing client; PHPSESSID cookie |
| tool.call → DB | ActiveRecord with parameterized queries (no string-interp SQL) |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-40-04-01 | Information Disclosure | Tool returns more data than read-context warrants | mitigate | `format_region` (and analogues) JSON-encode whitelisted fields only — id/shortname/name/cc_id, not the full row; no PaperTrail-version dumps |
| T-40-04-02 | Tampering | LLM passes SQL-injection-shaped string in shortname | mitigate | ActiveRecord `find_by(shortname: …)` parameterizes; no `where("shortname = '#{...}'")`-style string interp |
| T-40-04-03 | Information Disclosure | Tool error message leaks internal stack trace | mitigate | `error("not found")` returns canned text; rescue StandardError → text only, no `.message`/`.backtrace` |
| T-40-04-04 | Spoofing | force_refresh-path uses stale PHPSESSID after expiry | mitigate | `cc_session.cookie` in Plan 01 enforces TTL + lazy reauth via Setting.login_to_cc; T-40-01-03 disposition holds |
| T-40-04-05 | Information Disclosure | Tool description (EN per D-20) accidentally leaks DE business secret | accept | Tool descriptions are docstrings about CC-API surface, not Carambus-internal logic; verified by reading 10 files |
</threat_model>

<verification>
- 10 read-tool files exist; all auto-registered via Plan 01 dynamic registry
- All tool_names match `cc_lookup_*` / `cc_search_*` (D-20 EN)
- All tools subclass `McpServer::Tools::BaseTool`
- D-02 DB-first behavior verified for the **4 DB-first tools** (lookup_region, lookup_league, lookup_tournament, lookup_teilnehmerliste); the **6 live-only tools** (lookup_team, lookup_club, lookup_spielbericht, lookup_category, lookup_serie, search_player) explicitly skip DB-first per Warning 6
- 10 tests pass
- LocalProtector concern not violated — no `id < 50_000_000` records modified by read tools
</verification>

<success_criteria>
- 10 tools registered: `bundle exec rails runner "puts McpServer::Server.build.tools.select { |t| t.name.to_s.start_with?('McpServer::Tools::Lookup') || t.name.to_s.end_with?('SearchPlayer') }.size"` outputs `10`
- D-18 acceptance pathway exists end-to-end via DB-first + live-fallback in `cc_lookup_teilnehmerliste` (Test 1 of LookupTeilnehmerlisteTest verifies positive case)
- D-02 DB-first contract enforced by the 4 lookup tools that have a Carambus-side mirror (region, league, tournament, teilnehmerliste); the 6 live-only tools (team, club, spielbericht, category, serie, search_player) explicitly skip DB-first via tool docstring (**Warning 6 fix — was inconsistently 3 in old success_criteria**)
- All 10 tests pass; Plan 06 adds exhaustive smoke for remaining 7 tools
- No SDK API hedges remain — Plan 01 Task 3 SDK-API smoke probe locks the contracts (Warning 8 fix)
</success_criteria>

<output>
After completion, create `.planning/phases/40-mcp-server-clubcloud/40-04-SUMMARY.md` documenting:
- Tool-by-tool table: tool_name → DB-first? → mirror model (4) or live-only? → CC action
- Live-only/DB-first split confirmed: 4 DB-first + 6 live-only = 10 total (Warning 6)
- Any LeagueCc / TournamentCc column gaps that complicated DB-first lookups
- Confirmation that SDK API contracts from Plan 01 SUMMARY held during implementation (Warning 8)
- Note for Plan 06: which 7 tools still need exhaustive smoke tests (lookup_league, lookup_tournament, lookup_team, lookup_club, lookup_spielbericht, lookup_category, lookup_serie)
</output>
</content>
</invoke>