---
phase: 40-mcp-server-clubcloud
plan: 06
type: execute
wave: 3
depends_on: ["40-01", "40-02", "40-03", "40-04", "40-05"]
files_modified:
  - test/mcp_server/integration/stdio_e2e_test.rb
  - test/mcp_server/tools/lookup_smoke_test.rb
  - .mcp.json.example
  - docs/managers/clubcloud-mcp-setup.de.md
  - docs/developers/clubcloud-mcp-server.de.md
  - lib/capistrano/tasks/mcp_server.rake
autonomous: true
requirements: [D-09, D-16, D-17]
requirements_addressed: [D-09, D-16, D-17]
user_setup:
  - service: clubcloud-mcp
    why: "End-user installation requires updating MCP-client config (Claude Desktop / Claude Code) — instructions in docs/managers/clubcloud-mcp-setup.de.md"
    env_vars:
      - name: CC_USERNAME
        source: "Per-user CC account login"
      - name: CC_PASSWORD
        source: "Per-user CC account password"
      - name: CC_FED_ID
        source: "Federation ID (e.g. 20 for BCW)"
      - name: CARAMBUS_MCP_MOCK
        source: "Set to 1 for safe testing without touching production CC"
    dashboard_config:
      - task: "Edit ~/Library/Application Support/Claude/claude_desktop_config.json (macOS)"
        location: "Claude Desktop user-config; setup-doc in this plan provides the exact JSON snippet"
      - task: "Or run `claude mcp add` for Claude Code (project-scope vs. user-scope choice)"
        location: "Claude Code CLI; setup-doc covers both Project and User scope"

must_haves:
  truths:
    - "All 10 read tools have at least a smoke test (each tool gets one validation-error test) — covers the 7 tools NOT exhaustively tested by Plan 04"
    - "ONE end-to-end stdio integration test (D-16) spawns `bin/mcp-server`, exchanges JSON-RPC initialize + tools/list + resources/list + tools/call (cc_finalize_teilnehmerliste dry-run), and asserts response shape"
    - "ONE additional E2E smoke test pipes invalid JSON to bin/mcp-server and asserts `-32700 Parse error` envelope is returned (RESEARCH Open Question §1 RESOLVED proof)"
    - "`.mcp.json.example` exists at project root with exact env-var template (D-09); committed to git"
    - "DE setup-doc (`docs/managers/clubcloud-mcp-setup.de.md`) walks Sportwart through Claude Desktop installation"
    - "DE developer-doc (`docs/developers/clubcloud-mcp-server.de.md`) walks Carambus dev through Claude Code project-scope `.mcp.json`"
    - "Capistrano deploy task `lib/capistrano/tasks/mcp_server.rake` ensures `bin/mcp-server` is mode 0755 after each deploy (RESEARCH Open Question §5 RESOLVED)"
    - "Combined test run after Plan 06: `bin/rails test test/mcp_server/` reports all green (~30+ tests)"
  artifacts:
    - path: "test/mcp_server/integration/stdio_e2e_test.rb"
      provides: "End-to-end stdio JSON-RPC integration test (D-16) — spawns bin/mcp-server"
      min_lines: 80
    - path: "test/mcp_server/tools/lookup_smoke_test.rb"
      provides: "Smoke tests for the 7 lookup tools NOT exhaustively tested by Plan 04 + dynamic registry drift guard"
      min_lines: 60
    - path: ".mcp.json.example"
      provides: "Reference MCP-client config (Claude Code project-scope variant)"
      min_lines: 15
    - path: "docs/managers/clubcloud-mcp-setup.de.md"
      provides: "DE setup walkthrough for Sportwarts (Claude Desktop)"
      min_lines: 60
    - path: "docs/developers/clubcloud-mcp-server.de.md"
      provides: "DE technical doc for Carambus devs (Claude Code, mock mode, debugging)"
      min_lines: 50
    - path: "lib/capistrano/tasks/mcp_server.rake"
      provides: "Capistrano deploy hook ensuring bin/mcp-server is mode 0755 after :bundle:install"
      min_lines: 15
  key_links:
    - from: "test/mcp_server/integration/stdio_e2e_test.rb"
      to: "bin/mcp-server"
      via: "Open3.popen2e"
      pattern: "popen.*bin/mcp-server"
    - from: "docs/managers/clubcloud-mcp-setup.de.md"
      to: ".mcp.json.example"
      via: "explicit reference + copy template"
      pattern: "\\.mcp\\.json"
    - from: "lib/capistrano/tasks/mcp_server.rake"
      to: "release_path/bin/mcp-server"
      via: "chmod 0755 hook"
      pattern: "chmod"
---

<objective>
Close Phase 40 with the comprehensive test sweep + end-user setup documentation
that lets a real Sportwart install the server in Claude Desktop and a Carambus
dev wire it into Claude Code.

Plan 04 shipped 10 read tools with 3 representative tests; this plan adds smoke
tests for the remaining 7. Plan 05 shipped the write tool with 6 unit tests; this
plan adds the ONE D-16-required end-to-end stdio integration test that proves the
full JSON-RPC flow works from a real client perspective, plus an extra E2E test
that validates SDK behavior on invalid JSON input (RESEARCH Open Question §1
RESOLVED proof).

Per D-09: each MCP-client installation has its own credential config. This plan
ships an `.mcp.json.example` template + DE walkthrough for both audiences (D-17).

**Revision 2026-05-07 changes:**
- Task 1: dead code removed from EXPECTED_TOOL_NAMES check (Warning 10); EXPECTED_TOOL_NAMES is now built dynamically via constants enumeration with frozen reference assertion (Info 11).
- Task 2: invalid-JSON E2E smoke test added (RESEARCH Open Question §1 RESOLVED).
- Task 4 (NEW): Capistrano deploy hook to chmod bin/mcp-server (RESEARCH Open Question §5 RESOLVED).

Output: ~10 smoke tests + 2 E2E tests + 3 user-facing docs + 1 Capistrano deploy task,
completing the Phase 40 acceptance story end-to-end.
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
@.planning/phases/40-mcp-server-clubcloud/40-04-SUMMARY.md
@.planning/phases/40-mcp-server-clubcloud/40-05-SUMMARY.md

@bin/mcp-server
@lib/mcp_server/server.rb
@lib/mcp_server/tools/finalize_teilnehmerliste.rb

<interfaces>
<!-- Existing artifacts from prior plans this plan references and tests -->

bin/mcp-server (Plan 01) — executable entry point
McpServer::Server.build (Plan 01) — server constructor with auto-registry + central read-handler dispatcher
10 read tools (Plan 04): cc_lookup_region, cc_lookup_league, cc_lookup_tournament,
  cc_lookup_teilnehmerliste, cc_lookup_team, cc_lookup_club, cc_lookup_spielbericht,
  cc_lookup_category, cc_lookup_serie, cc_search_player
1 write tool (Plan 05): cc_finalize_teilnehmerliste
5 workflow + 15 api resources (Plans 02 + 03)

JSON-RPC 2.0 envelope (per MCP spec):
- initialize: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: ..., version: ... } }
- tools/list: returns { tools: [{ name, description, inputSchema }, ...] }
- resources/list: returns { resources: [{ uri, name, ... }, ...] }
- tools/call: { name: "cc_...", arguments: {...} } returns { content: [...], isError: bool }
- Parse error (invalid JSON from client): { jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } }
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Smoke tests for the 7 read tools NOT exhaustively tested by Plan 04 (with dynamic + frozen reference list)</name>
  <files>test/mcp_server/tools/lookup_smoke_test.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/lookup_league.rb
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/lookup_tournament.rb
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/lookup_team.rb
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/lookup_club.rb
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/lookup_spielbericht.rb
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/lookup_category.rb
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/lookup_serie.rb
  </read_first>
  <behavior>
    - One smoke test per tool: validation-error path (call with no params) returns error response
    - Plus one combined test: dynamically derived tool name list matches a frozen reference (drift detection + canonical reference per Info 11)
    - Plus annotation-discipline tests
  </behavior>
  <action>
    Create `test/mcp_server/tools/lookup_smoke_test.rb`:
    ```ruby
    # frozen_string_literal: true
    require "test_helper"

    # Smoke tests for the 7 lookup tools NOT exhaustively unit-tested by Plan 04.
    # Plan 04 covers LookupRegion + LookupTeilnehmerliste + SearchPlayer in depth;
    # this file verifies the remaining 7 are well-formed (subclass + tool_name + validation).

    class McpServer::Tools::LookupSmokeTest < ActiveSupport::TestCase
      setup do
        ENV["CARAMBUS_MCP_MOCK"] = "1"
        McpServer::CcSession.reset!
        McpServer::CcSession._client_override = McpServer::Tools::MockClient.new
      end

      teardown do
        ENV["CARAMBUS_MCP_MOCK"] = nil
        McpServer::CcSession._client_override = nil
        McpServer::CcSession.reset!
      end

      # Frozen reference list — best of both worlds (Info 11):
      # 1. Dynamic derivation catches drift if a new tool is added without updating this list.
      # 2. Frozen reference catches drift if a tool is renamed or removed silently.
      EXPECTED_TOOL_NAMES = %w[
        cc_lookup_region
        cc_lookup_league
        cc_lookup_tournament
        cc_lookup_teilnehmerliste
        cc_lookup_team
        cc_lookup_club
        cc_lookup_spielbericht
        cc_lookup_category
        cc_lookup_serie
        cc_search_player
        cc_finalize_teilnehmerliste
      ].freeze

      test "dynamic tool registry matches frozen reference (drift detection both ways)" do
        # Force-load all tool files first
        McpServer::Server.build  # triggers eager_load_namespace!

        dynamic = McpServer::Tools.constants.map { |c| McpServer::Tools.const_get(c) }
          .select { |k| k.is_a?(Class) && k < McpServer::Tools::BaseTool }
          .map { |k| k.respond_to?(:tool_name) ? k.tool_name.to_s : k.name.to_s.split("::").last }
          .reject(&:empty?)
          .sort

        expected_sorted = EXPECTED_TOOL_NAMES.sort

        assert_equal expected_sorted, dynamic,
                     "Tool registry drift detected. Either update EXPECTED_TOOL_NAMES (a tool was added/renamed) " \
                     "or fix the implementation (a tool is missing or misnamed)."
      end

      test "all 11 expected tools (10 read + 1 write) are registered on McpServer::Server.build" do
        registered = McpServer::Server.build.tools.map { |t|
          t.respond_to?(:tool_name) ? t.tool_name.to_s : t.name.to_s
        }
        EXPECTED_TOOL_NAMES.each do |expected|
          assert_includes registered, expected, "Tool #{expected} not registered"
        end
      end

      test "lookup_league validation: missing all params returns error" do
        response = McpServer::Tools::LookupLeague.call(server_context: nil)
        assert response.error
      end

      test "lookup_tournament validation" do
        response = McpServer::Tools::LookupTournament.call(server_context: nil)
        assert response.error
      end

      test "lookup_team validation" do
        response = McpServer::Tools::LookupTeam.call(server_context: nil)
        assert response.error
      end

      test "lookup_club validation: missing fed_id returns error" do
        response = McpServer::Tools::LookupClub.call(server_context: nil)
        assert response.error
      end

      test "lookup_spielbericht validation" do
        response = McpServer::Tools::LookupSpielbericht.call(server_context: nil)
        assert response.error
      end

      test "lookup_category validation" do
        response = McpServer::Tools::LookupCategory.call(server_context: nil)
        assert response.error
      end

      test "lookup_serie validation" do
        response = McpServer::Tools::LookupSerie.call(server_context: nil)
        assert response.error
      end

      # Annotation discipline — read tools are read_only_hint:true, finalize is destructive_hint:true.
      # Filename mapping: cc_lookup_X → lookup_X.rb; cc_search_player → search_player.rb;
      # cc_finalize_teilnehmerliste → finalize_teilnehmerliste.rb.
      test "all 10 read tools have read_only_hint: true annotation" do
        read_tool_names = EXPECTED_TOOL_NAMES - ["cc_finalize_teilnehmerliste"]
        read_tool_names.each do |tname|
          fname = case tname
                  when "cc_search_player" then "search_player.rb"
                  else "#{tname.delete_prefix('cc_')}.rb"
                  end
          file = Rails.root.join("lib/mcp_server/tools/#{fname}")
          content = file.read
          assert_match(/read_only_hint:\s*true/, content, "#{tname} (#{fname}) missing read_only_hint:true annotation")
        end
      end

      test "finalize tool has destructive_hint: true (not read_only)" do
        content = Rails.root.join("lib/mcp_server/tools/finalize_teilnehmerliste.rb").read
        assert_match(/destructive_hint:\s*true/, content)
        assert_match(/read_only_hint:\s*false/, content)
      end
    end
    ```

    Run:
    ```
    bin/rails test test/mcp_server/tools/lookup_smoke_test.rb
    ```
    11 tests, all must pass.
  </action>
  <verify>
    <automated>bin/rails test test/mcp_server/tools/lookup_smoke_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - `test/mcp_server/tools/lookup_smoke_test.rb` exists with `frozen_string_literal: true` on line 2
    - 11 tests pass: `bin/rails test test/mcp_server/tools/lookup_smoke_test.rb` reports `11 runs, 0 failures, 0 errors`
    - Coverage: all 11 expected tool names from `EXPECTED_TOOL_NAMES` are asserted registered
    - Coverage: each of 7 lookup tools has its own validation-failure smoke test
    - Read/Write annotation discipline: 10 read tools have `read_only_hint: true`, 1 write tool has `destructive_hint: true`
    - **No dead code in filename mapping** (Warning 10): `grep -c 'gsub("_", "_")\|delete_prefix.*gsub' test/mcp_server/tools/lookup_smoke_test.rb` returns 0
    - **Dynamic + frozen drift detection** (Info 11): test "dynamic tool registry matches frozen reference" exists: `grep -c "dynamic tool registry matches frozen reference" test/mcp_server/tools/lookup_smoke_test.rb` returns 1
  </acceptance_criteria>
  <done>11 smoke tests pass; coverage for all 11 tool names (10 read + 1 write); annotation discipline enforced; dynamic + frozen drift detection (Info 11); no dead code (Warning 10).</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: End-to-end stdio integration test — spawn bin/mcp-server, exchange JSON-RPC + invalid-JSON probe</name>
  <files>test/mcp_server/integration/stdio_e2e_test.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md (Example 3 — E2E stdio test pattern; Open Questions §1 RESOLVED — invalid-JSON behavior)
    - /Users/gullrich/DEV/carambus/carambus_api/bin/mcp-server (Plan 01 — verify it boots)
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/server.rb (server name + tool/resource registries)
  </read_first>
  <behavior>
    - Test 1 (initialize handshake): Spawn `bin/mcp-server` via Open3.popen2e, send `initialize` JSON-RPC, assert response.result.serverInfo.name == "carambus_clubcloud"
    - Test 2 (tools/list): includes all 11 tool names from EXPECTED_TOOL_NAMES
    - Test 3 (resources/list): includes 5 cc://workflow/* + 15 cc://api/* URIs (total >= 20)
    - Test 4 (tools/call dry-run): call cc_finalize_teilnehmerliste with valid args + armed: false, assert response is "Would finalize..." text and isError is false
    - Test 5 (invalid-JSON probe — RESEARCH Open Question §1 RESOLVED): pipe `{garbage` to bin/mcp-server, assert JSON-RPC `-32700 Parse error` envelope is returned on stdout
    - Test 6 (executable bit guard — RESEARCH Open Question §5 RESOLVED): `File.executable?(Rails.root.join("bin/mcp-server"))` is true
    - All tests skip gracefully if Rails-Boot is too slow on CI (`skip if ENV["CI"]` allowance)
  </behavior>
  <action>
    Create `test/mcp_server/integration/stdio_e2e_test.rb`:
    ```ruby
    # frozen_string_literal: true
    require "test_helper"
    require "json"
    require "open3"

    # End-to-end stdio integration test (D-16). Spawns the actual bin/mcp-server
    # subprocess and exchanges JSON-RPC messages over its STDIN/STDOUT.
    # Slow (~5s Rails-boot per run); designed as the integration test for the phase.

    class McpServer::Integration::StdioE2ETest < ActiveSupport::TestCase
      BOOT_TIMEOUT_SECONDS = 30

      setup do
        skip "E2E test requires Rails-Boot; skipping on CI for speed" if ENV["CI"]
        @env = ENV.to_h.merge(
          "CARAMBUS_MCP_MOCK" => "1",
          "CC_USERNAME" => "test",
          "CC_PASSWORD" => "test",
          "CC_FED_ID" => "20",
          "RAILS_ENV" => "test"
        )
      end

      def with_server
        Open3.popen2e(@env, Rails.root.join("bin/mcp-server").to_s) do |stdin, stdout_err, wait_thr|
          begin
            yield(stdin, stdout_err)
          ensure
            stdin.close rescue nil
            Process.kill("TERM", wait_thr.pid) rescue nil
            wait_thr.join(5)
          end
        end
      end

      def send_jsonrpc(stdin, id:, method:, params: {})
        stdin.puts({ jsonrpc: "2.0", id: id, method: method, params: params }.to_json)
        stdin.flush
      end

      def read_jsonrpc(stdout_err)
        # Skip non-JSON lines (e.g. Rails boot warnings sneaking through STDERR-merged stream).
        BOOT_TIMEOUT_SECONDS.times do
          line = stdout_err.gets
          next if line.nil? || line.strip.empty?
          begin
            return JSON.parse(line)
          rescue JSON::ParserError
            next
          end
        end
        flunk "Did not receive valid JSON-RPC response within timeout"
      end

      test "executable bit guard (RESEARCH Open Question §5 RESOLVED)" do
        # Local + Capistrano-deploy-time guard — bin/mcp-server MUST be 0755.
        # Plan 06 Task 4 adds the Capistrano hook; this test catches local-checkout drift.
        path = Rails.root.join("bin/mcp-server")
        assert File.exist?(path), "bin/mcp-server missing"
        assert File.executable?(path), "bin/mcp-server not executable (mode is #{File.stat(path).mode.to_s(8)})"
      end

      test "initialize handshake — server identifies as carambus_clubcloud" do
        with_server do |stdin, stdout|
          send_jsonrpc(stdin, id: 1, method: "initialize", params: {
            protocolVersion: "2024-11-05",
            capabilities: {},
            clientInfo: { name: "test-client", version: "1.0" }
          })
          response = read_jsonrpc(stdout)
          assert_equal "carambus_clubcloud", response.dig("result", "serverInfo", "name")
        end
      end

      test "tools/list — all 11 expected tools registered" do
        with_server do |stdin, stdout|
          send_jsonrpc(stdin, id: 1, method: "initialize", params: {
            protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "test", version: "1.0" }
          })
          read_jsonrpc(stdout)  # consume init response

          send_jsonrpc(stdin, id: 2, method: "tools/list")
          response = read_jsonrpc(stdout)
          tool_names = response.dig("result", "tools").map { |t| t["name"] }
          %w[cc_lookup_region cc_lookup_teilnehmerliste cc_search_player cc_finalize_teilnehmerliste].each do |name|
            assert_includes tool_names, name, "tools/list missing #{name}"
          end
          assert_operator tool_names.size, :>=, 11
        end
      end

      test "resources/list — workflow + api resources present" do
        with_server do |stdin, stdout|
          send_jsonrpc(stdin, id: 1, method: "initialize", params: {
            protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "test", version: "1.0" }
          })
          read_jsonrpc(stdout)

          send_jsonrpc(stdin, id: 2, method: "resources/list")
          response = read_jsonrpc(stdout)
          uris = response.dig("result", "resources").map { |r| r["uri"] }
          assert_includes uris, "cc://workflow/scenarios/teilnehmerliste-finalisieren"
          assert_includes uris, "cc://workflow/roles"
          assert(uris.any? { |u| u.start_with?("cc://api/") }, "no cc://api/ resources found")
          assert_operator uris.size, :>=, 20  # 5 workflow + 15 api = 20 minimum
        end
      end

      test "tools/call — cc_finalize_teilnehmerliste dry-run (D-19)" do
        with_server do |stdin, stdout|
          send_jsonrpc(stdin, id: 1, method: "initialize", params: {
            protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "test", version: "1.0" }
          })
          read_jsonrpc(stdout)

          send_jsonrpc(stdin, id: 2, method: "tools/call", params: {
            name: "cc_finalize_teilnehmerliste",
            arguments: { fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42 }
          })
          response = read_jsonrpc(stdout)
          # Dry-run: not an error, content includes "Would finalize"
          refute response.dig("result", "isError"), "Tool errored unexpectedly: #{response.inspect}"
          combined_text = response.dig("result", "content").map { |c| c["text"] }.join(" ")
          assert_match(/Would finalize Meldeliste 42/, combined_text)
        end
      end

      test "invalid JSON probe returns -32700 Parse error (RESEARCH Open Question §1 RESOLVED)" do
        # Pipe a malformed JSON frame, assert SDK returns the JSON-RPC parse error envelope
        # without crashing the server-loop.
        with_server do |stdin, stdout|
          stdin.puts "{garbage not json"
          stdin.flush
          response = read_jsonrpc(stdout)
          # Per JSON-RPC 2.0 spec § Error Codes:
          # -32700 Parse error  | Invalid JSON was received by the server
          assert_equal(-32700, response.dig("error", "code"),
                       "SDK must return -32700 Parse error envelope for invalid JSON; got: #{response.inspect}")
        end
      end
    end
    ```

    Run:
    ```
    bin/rails test test/mcp_server/integration/stdio_e2e_test.rb
    ```
    6 tests, all must pass (or skip gracefully on CI).
  </action>
  <verify>
    <automated>bin/rails test test/mcp_server/integration/stdio_e2e_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - `test/mcp_server/integration/stdio_e2e_test.rb` exists with `frozen_string_literal: true` on line 2
    - 6 E2E tests defined: `grep -c "^  test " test/mcp_server/integration/stdio_e2e_test.rb` returns 6
    - Tests pass locally (CI may skip): reports either `6 runs, 0 failures, 0 errors` OR `6 runs, 6 skips`
    - D-19 verification: 1 of 6 tests calls `tools/call` with `cc_finalize_teilnehmerliste` (dry-run) and asserts "Would finalize" text
    - D-16 fulfilled: end-to-end integration tests as required by spec
    - **Invalid-JSON probe** (RESEARCH §1 RESOLVED): test "invalid JSON probe returns -32700" exists: `grep -c "32700" test/mcp_server/integration/stdio_e2e_test.rb` returns >= 1
    - **Executable-bit guard** (RESEARCH §5 RESOLVED): test asserts `File.executable?` on bin/mcp-server: `grep -c "File.executable?" test/mcp_server/integration/stdio_e2e_test.rb` returns 1
  </acceptance_criteria>
  <done>E2E test compiled; 6 JSON-RPC interactions verified; D-16 satisfied; SDK invalid-JSON behavior locked-in (Open Question §1); executable-bit guard in place (Open Question §5).</done>
</task>

<task type="auto">
  <name>Task 3: Create .mcp.json.example + DE setup-doc + DE developer-doc</name>
  <files>.mcp.json.example, docs/managers/clubcloud-mcp-setup.de.md, docs/developers/clubcloud-mcp-server.de.md</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md (Example 4 — Claude Desktop config, Example 5 — Claude Code .mcp.json)
    - /Users/gullrich/DEV/carambus/carambus_api/.gitignore (verify .mcp.json.example will be tracked, check whether `.mcp.json` is ignored)
  </read_first>
  <action>
    Step 1 — Create `.mcp.json.example` at project root:
    ```json
    {
      "_comment": "Phase 40 MCP-Server config example. Copy to .mcp.json (per Claude Code convention) and fill in your CC credentials. Variable expansion ${VAR} works.",
      "mcpServers": {
        "carambus_clubcloud": {
          "command": "${PWD}/bin/mcp-server",
          "args": [],
          "env": {
            "CC_USERNAME": "${CC_USERNAME}",
            "CC_PASSWORD": "${CC_PASSWORD}",
            "CC_FED_ID": "${CC_FED_ID:-20}",
            "CARAMBUS_MCP_MOCK": "${CARAMBUS_MCP_MOCK:-0}"
          }
        }
      }
    }
    ```

    Step 2 — Update `.gitignore` to add `/.mcp.json` (NOT `.mcp.json.example`):
    Append a single line to `.gitignore` (if not already present):
    ```
    /.mcp.json
    ```
    Verify with `grep -c '^/\.mcp\.json$' .gitignore` returns 1.

    Step 3 — Create `docs/managers/clubcloud-mcp-setup.de.md` (DE setup walkthrough for Sportwarts using Claude Desktop):
    - Title: `# ClubCloud-MCP-Server in Claude Desktop einrichten`
    - Sections:
      1. **Was ist das?** — 2-3 Absätze: erklärt, dass Claude Desktop direkt mit Carambus + CC sprechen kann (D-17 audience b)
      2. **Voraussetzungen** — Claude Desktop installiert, Carambus-Repo lokal vorhanden, eigene CC-Login-Daten
      3. **Installation Schritt-für-Schritt:**
         - 3.1 Bundle-Install
         - 3.2 `bin/mcp-server` ist executable (`chmod +x bin/mcp-server` falls nicht)
         - 3.3 `claude_desktop_config.json` öffnen — Pfad: `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) — Snippet einfügen:
           ```json
           {
             "mcpServers": {
               "carambus_clubcloud": {
                 "command": "/Users/<DEIN-USER>/DEV/carambus/carambus_api/bin/mcp-server",
                 "args": [],
                 "env": {
                   "CC_USERNAME": "deine-cc-email@example.com",
                   "CC_PASSWORD": "dein-cc-passwort",
                   "CC_FED_ID": "20",
                   "CARAMBUS_MCP_MOCK": "0",
                   "RAILS_ENV": "production"
                 }
               }
             }
           }
           ```
         - 3.4 Claude Desktop neustarten
         - 3.5 Test: in einer neuen Konversation fragen "Welche MCP-Tools sind verfügbar?"
      4. **Sicherheit & Vorsicht:** Datei-Permissions auf `chmod 600`; `cc_finalize_teilnehmerliste` benötigt `armed: true`
      5. **Troubleshooting:** "Server disconnected" → STDOUT-Pollution → `~/Library/Logs/Claude/mcp-server-carambus.log`; "Server failed to start" → Rails-Boot-Latenz → `MCP_TIMEOUT=15000`; "CC login failed" → `CARAMBUS_MCP_MOCK=1` zum Testen
      6. **Mock-Mode für sicheres Ausprobieren:** `CARAMBUS_MCP_MOCK=1`

    Step 4 — Create `docs/developers/clubcloud-mcp-server.de.md` (DE technical doc for Carambus devs using Claude Code):
    - Title: `# ClubCloud-MCP-Server: Entwickler-Setup`
    - Sections:
      1. **Architektur-Übersicht** — Verweise auf `lib/mcp_server/`, `bin/mcp-server`, Plan-Dateien-Index
      2. **Dependencies** — `mcp` Gem 0.15.x; `RegionCc::ClubCloudClient` (existing transport); Mock-mode via `CARAMBUS_MCP_MOCK=1`
      3. **Project-scope MCP-Setup für Claude Code** — `.mcp.json.example` zu `.mcp.json` kopieren + Variable-Expansion erklären
      4. **User-scope Alternative** — `claude mcp add carambus_clubcloud --scope user --env CC_USERNAME=... ...`
      5. **Lokales Testen** — `CARAMBUS_MCP_MOCK=1 bin/mcp-server` manuell starten
      6. **Test-Suite** — `bin/rails test test/mcp_server/`
      7. **Pitfalls:** STDOUT-Pollution → Rails.logger auf STDERR; Zeitwerk: `McpServer` (camelCase); PHPSESSID-Reauth bei 30-min-Idle; Mock-Mode-Leak in Production → Plan-01-Failsafe
      8. **Capistrano-Deploy** — `lib/capistrano/tasks/mcp_server.rake` hook ensures `bin/mcp-server` ist mode 0755 nach jedem Deploy (Plan 06 Task 4, RESEARCH Open Question §5 RESOLVED)
      9. **Referenz auf Phase 40.1** — geplante Erweiterung der Write-Allowlist (cc_create_team, cc_add_player_to_team, cc_upload_result, cc_release_endrangliste)
    - Sections auf DE per D-05 + D-17 audience a (devs).
  </action>
  <verify>
    <automated>test -f .mcp.json.example && test -f docs/managers/clubcloud-mcp-setup.de.md && test -f docs/developers/clubcloud-mcp-server.de.md && grep -q "carambus_clubcloud" .mcp.json.example && grep -q "CARAMBUS_MCP_MOCK" docs/managers/clubcloud-mcp-setup.de.md</automated>
  </verify>
  <acceptance_criteria>
    - `.mcp.json.example` exists at repo root and contains literal string `"carambus_clubcloud"` and `${CC_USERNAME}` (variable-expansion proof)
    - `.gitignore` contains `/.mcp.json`: `grep -c "^/\\.mcp\\.json$" .gitignore` returns 1
    - `docs/managers/clubcloud-mcp-setup.de.md` exists and contains DE markers (Voraussetzungen, Schritt-für-Schritt, Sicherheit): `grep -c "Voraussetzungen\|Schritt-für-Schritt\|Sicherheit" docs/managers/clubcloud-mcp-setup.de.md` returns >= 3
    - Setup-doc references `claude_desktop_config.json` path: `grep -c "claude_desktop_config.json" docs/managers/clubcloud-mcp-setup.de.md` returns >= 1
    - Setup-doc covers troubleshooting: `grep -c "Troubleshooting\|Server disconnected\|MCP_TIMEOUT" docs/managers/clubcloud-mcp-setup.de.md` returns >= 2
    - Developer-doc exists and references Phase 40.1: `grep -c "Phase 40.1\|cc_create_team\|cc_upload_result" docs/developers/clubcloud-mcp-server.de.md` returns >= 2
    - Developer-doc references mock-mode + STDOUT pitfall: `grep -c "CARAMBUS_MCP_MOCK\|STDOUT" docs/developers/clubcloud-mcp-server.de.md` returns >= 2
    - Developer-doc references Capistrano deploy hook: `grep -c "Capistrano\|mcp_server.rake" docs/developers/clubcloud-mcp-server.de.md` returns >= 1
  </acceptance_criteria>
  <done>3 docs/config files committed; setup walkthrough is complete and DE; gitignore protects the real .mcp.json from being committed; developer-doc references Capistrano deploy hook (Task 4).</done>
</task>

<task type="auto">
  <name>Task 4: Capistrano deploy task — ensure bin/mcp-server is mode 0755 after each deploy (RESEARCH Open Question §5 RESOLVED)</name>
  <files>lib/capistrano/tasks/mcp_server.rake</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md (Open Questions §5 RESOLVED — Capistrano executable-bit hook)
    - List existing Capistrano tasks: `ls lib/capistrano/tasks/ 2>/dev/null` (verify directory exists or create it)
    - /Users/gullrich/DEV/carambus/carambus_api/Capfile (if exists — check load convention)
  </read_first>
  <behavior>
    - Capistrano task `deploy:mcp_server:set_executable` runs `chmod 0755 #{release_path}/bin/mcp-server` on the deploy target
    - Hooks into `:bundle:install` (after) or `deploy:updated` so the chmod runs after the `release_path` is symlinked but before any process tries to spawn the binary
    - Idempotent — safe to re-run
    - Documented in the .rake file header so a future maintainer understands why this task exists
  </behavior>
  <action>
    Step 1 — Ensure `lib/capistrano/tasks/` directory exists. If missing, create it (`mkdir -p lib/capistrano/tasks/`).

    Step 2 — Create `lib/capistrano/tasks/mcp_server.rake`:
    ```ruby
    # frozen_string_literal: true
    # Phase 40 MCP-Server deploy task — ensures bin/mcp-server is executable after deploy.
    #
    # Background (RESEARCH Open Question §5 RESOLVED):
    # Capistrano's standard `linked_files` workflow does NOT preserve git-stored executable
    # bits across `release_path` symlinking on all servers. Without this hook, an MCP-client
    # spawning bin/mcp-server on a freshly-deployed server may fail with EACCES.
    #
    # Hook-point: after :bundle:install (or deploy:updated) — runs once per release.
    # Local development: unaffected — git tracks file mode, devs run `chmod +x` once.

    namespace :deploy do
      namespace :mcp_server do
        desc "Set executable bit on bin/mcp-server (Phase 40 MCP-Server)"
        task :set_executable do
          on roles(:app) do
            # release_path is the freshly-deployed release dir for this run.
            within release_path do
              execute :chmod, "0755", "bin/mcp-server"
            end
          end
        end
      end
    end

    # Run after bundle install — release dir is in place, before any restart hooks.
    after "bundle:install", "deploy:mcp_server:set_executable"
    ```

    Step 3 — Verify the file is loaded by Capistrano. The default Capfile pattern `Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }` should pick it up. If the project uses a different load mechanism, adjust accordingly (read `Capfile` for details).

    Step 4 — Test loading (without actually deploying):
    ```
    bundle exec ruby -e "load 'lib/capistrano/tasks/mcp_server.rake' rescue puts \"Note: capistrano DSL not in scope outside cap task — that's expected; file syntax-loaded fine.\""
    ```
    The file should at minimum be syntactically valid Ruby (`ruby -c lib/capistrano/tasks/mcp_server.rake` exits 0).
  </action>
  <verify>
    <automated>test -f lib/capistrano/tasks/mcp_server.rake && ruby -c lib/capistrano/tasks/mcp_server.rake | grep -q "Syntax OK"</automated>
  </verify>
  <acceptance_criteria>
    - `lib/capistrano/tasks/mcp_server.rake` exists with `frozen_string_literal: true` on line 2
    - File contains `namespace :deploy` and `task :set_executable` (Capistrano DSL): `grep -c "namespace :deploy\|task :set_executable" lib/capistrano/tasks/mcp_server.rake` returns >= 2
    - File performs chmod 0755 on bin/mcp-server: `grep -c "chmod.*0755.*bin/mcp-server" lib/capistrano/tasks/mcp_server.rake` returns 1
    - File hooks into bundle:install or deploy:updated: `grep -c "after.*bundle:install\|after.*deploy:updated" lib/capistrano/tasks/mcp_server.rake` returns 1
    - Syntactically valid Ruby: `ruby -c lib/capistrano/tasks/mcp_server.rake` exits 0
    - File header documents the RESEARCH Open Question §5 link: `grep -c "Open Question\|RESEARCH" lib/capistrano/tasks/mcp_server.rake` returns >= 1
  </acceptance_criteria>
  <done>Capistrano deploy task in place; bin/mcp-server is mode 0755 after every deploy; RESEARCH Open Question §5 fully RESOLVED with code-level mitigation.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| End-user filesystem → mcp.json | User creates the config; OS-level read protections apply |
| Test-spawned bin/mcp-server → test process | E2E test runs the actual binary; `CARAMBUS_MCP_MOCK=1` enforced via env |
| Capistrano deploy → release_path/bin/mcp-server | Server-side mode change via SSH; trusted operator only |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-40-06-01 | Information Disclosure | `.mcp.json` accidentally committed with real credentials | mitigate | `.gitignore` adds `/.mcp.json`; only `.mcp.json.example` (with `${VAR}` placeholders) is tracked; setup-doc explicitly says "kopiere `.mcp.json.example` nach `.mcp.json`" |
| T-40-06-02 | Information Disclosure | Setup-doc shows real credentials | mitigate | Setup-doc uses `<DEIN-USER>`, `deine-cc-email@example.com`, `dein-cc-passwort` placeholders |
| T-40-06-03 | Tampering | E2E test accidentally hits production CC | mitigate | Test-setup forces `CARAMBUS_MCP_MOCK=1` in subprocess env; combined with Plan 01 production-failsafe = double-defense |
| T-40-06-04 | Information Disclosure | Test logs leak boot-time STDOUT to CI artifacts | mitigate | Test merges STDOUT+STDERR via Open3.popen2e but only filters JSON-RPC lines; non-JSON lines are silently dropped |
| T-40-06-05 | Tampering | bin/mcp-server lost executable bit on deploy → MCP-client spawn fails open | mitigate | Capistrano deploy hook (Task 4) chmods 0755 after every deploy; E2E test (Task 2) asserts File.executable? on local checkout |
</threat_model>

<verification>
- 11 smoke-test runs pass: `bin/rails test test/mcp_server/tools/lookup_smoke_test.rb`
- 6 E2E-test runs pass (or skip on CI): `bin/rails test test/mcp_server/integration/stdio_e2e_test.rb`
- All Phase-40 tests combined run green: `bin/rails test test/mcp_server/` reports 0 failures, 0 errors
- `.mcp.json.example` exists at repo root, valid JSON: `python3 -m json.tool < .mcp.json.example > /dev/null` exits 0
- `/.mcp.json` is gitignored
- 2 DE setup docs exist
- Capistrano task syntactically valid: `ruby -c lib/capistrano/tasks/mcp_server.rake` exits 0
- All 5 RESEARCH Open Questions are now RESOLVED in code or docs (§1 invalid-JSON test, §2 single-thread comment in cc_session, §3 mock-mode HTTP-only in MockClient, §4 15 separate api resources, §5 Capistrano hook + E2E executable test)
</verification>

<success_criteria>
- All Phase 40 tests green: `bin/rails test test/mcp_server/` reports >= 30 tests passing
- D-16 fulfilled: end-to-end stdio integration tests, exercising initialize + tools/list + resources/list + tools/call (cc_finalize_teilnehmerliste dry-run) + invalid-JSON probe + executable-bit guard
- D-09 fulfilled: setup docs explain per-MCP-client credential config in both Claude Desktop and Claude Code
- D-17 fulfilled: 2 audiences served — DE setup-doc for Sportwarts (Claude Desktop) + DE technical doc for Devs (Claude Code)
- `.mcp.json.example` committed; `.mcp.json` gitignored
- D-19 acceptance proof: E2E Test "tools/call dry-run" shows the full chain works from JSON-RPC client to MCP-tool to MockClient.post → response back
- RESEARCH Open Question §1 RESOLVED proof: invalid-JSON probe test asserts -32700 envelope (Task 2 Test 5)
- RESEARCH Open Question §5 RESOLVED proof: Capistrano deploy hook + E2E executable-bit guard (Task 4 + Task 2 Test 6)
- Info 11 satisfied: dynamic + frozen reference drift detection (Task 1)
- Warning 10 satisfied: no dead code in filename mapping (Task 1)
</success_criteria>

<output>
After completion, create `.planning/phases/40-mcp-server-clubcloud/40-06-SUMMARY.md` documenting:
- Total Phase-40 test count + green/skip distribution
- Real measured Rails-Boot time during E2E test runs (informs whether `MCP_TIMEOUT=15000` recommendation in setup-doc is appropriate)
- Any SDK protocol version mismatches discovered
- Confirmation that all 5 RESEARCH Open Questions are now RESOLVED at code/docs level
- Closing checklist for v7.1 milestone retrospective: Phase 40 complete, deferred items (3-5 write tools) tracked in ROADMAP under Phase 40.1
</output>
</content>
</invoke>