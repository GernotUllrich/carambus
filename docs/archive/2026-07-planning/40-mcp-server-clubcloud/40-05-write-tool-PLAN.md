---
phase: 40-mcp-server-clubcloud
plan: 05
type: execute
wave: 2
depends_on: ["40-01"]
files_modified:
  - lib/mcp_server/tools/finalize_teilnehmerliste.rb
  - test/mcp_server/tools/finalize_teilnehmerliste_test.rb
autonomous: true
requirements: [D-03, D-04, D-08, D-10, D-11, D-19, D-20]
requirements_addressed: [D-03, D-04, D-08, D-10, D-11, D-19, D-20]
user_setup:
  - service: clubcloud
    why: "Write tool exercises real CC-Backend in armed mode (default mock); credentials gated per D-09"
    env_vars:
      - name: CC_USERNAME
        source: "ClubCloud user account login"
      - name: CC_PASSWORD
        source: "ClubCloud user account password"
      - name: CC_FED_ID
        source: "ClubCloud federation ID (e.g. 20 for BCW)"
      - name: CARAMBUS_MCP_MOCK
        source: "Set to 1 for development/test (see lib/mcp_server/tools/mock_client.rb)"

must_haves:
  truths:
    - "MCP server exposes exactly ONE write tool — `cc_finalize_teilnehmerliste` (D-19 proof tool only; remaining ~3-5 write tools deferred to Phase 40.1)"
    - "Tool's JSON-schema is structured with the 4 required parameters (`fed_id`, `branch_id`, `season`, `meldeliste_id`) plus the `armed: boolean, default: false` (D-03 dry-run convention)"
    - "When called with `armed: false`, the tool returns a 'would finalize' dry-run text WITHOUT calling CC (matching `RegionCc::ClubCloudClient#post`'s armed-flag semantics — D-19)"
    - "When called with `armed: true` AND `CARAMBUS_MCP_MOCK=1`, the tool calls `client.post(\"releaseMeldeliste\", ..., armed: true)` against MockClient and returns success text"
    - "When CC rejects (HTTP non-200, login redirect, or `<div class=\"error\">`), tool parses CC response and returns structured MCP error with text identifying the failure mode (D-11 trust-CC-and-parse-error)"
    - "Tool name is EN per D-20 (`cc_finalize_teilnehmerliste`); description and JSON-schema text are EN; user-visible response messages can be EN (consistent with tool surface)"
    - "Plan 05 does NOT modify lib/mcp_server/cc_session.rb — Plan 01 already implements full login + reauth_if_needed! (per revision Warning 7). This plan ONLY adds write-tool semantics: allowlist behavior, JSON schema, role-error parsing, retry-after-reauth flow."
  artifacts:
    - path: "lib/mcp_server/tools/finalize_teilnehmerliste.rb"
      provides: "MCP tool cc_finalize_teilnehmerliste — D-19 proof write tool"
      min_lines: 60
    - path: "test/mcp_server/tools/finalize_teilnehmerliste_test.rb"
      provides: "Tests covering dry-run, armed-mock-success, role-error parsing (D-11), session-reauth retry, defensive guard"
      min_lines: 80
  key_links:
    - from: "lib/mcp_server/tools/finalize_teilnehmerliste.rb"
      to: "RegionCc::ClubCloudClient#post('releaseMeldeliste', ...)"
      via: "McpServer::CcSession.client_for"
      pattern: "client\\.post\\(.releaseMeldeliste"
    - from: "lib/mcp_server/tools/finalize_teilnehmerliste.rb"
      to: "Nokogiri-parsed response error detection"
      via: "parse_cc_error helper"
      pattern: "parse_cc_error|css\\("
    - from: "lib/mcp_server/tools/finalize_teilnehmerliste.rb"
      to: "McpServer::CcSession.reauth_if_needed!"
      via: "retry-on-login-redirect (defined by Plan 01)"
      pattern: "cc_session\\.reauth_if_needed!"
---

<objective>
Build the write architecture (allowlist mechanism, JSON-schema discipline, role-error
parsing per D-03 + D-11) AND ship the single proof tool `cc_finalize_teilnehmerliste`
that exercises that architecture against the mock backend (D-19).

This is the validation that the allowlist + dry-run + error-parsing pattern actually
works end-to-end. Phase 40.1 will add 3-5 more tools on top of this foundation
without re-architecting.

Per D-19: only ONE write tool ships in Phase 40 — the others (`cc_create_team`,
`cc_add_player_to_team`, `cc_upload_result`, `cc_release_endrangliste`) are
deferred to Phase 40.1.

**Revision 2026-05-07 changes (Warning 7):**
- The CcSession login + reauth implementation has moved to Plan 01 Task 2 (full canonical Setting.login_to_cc reuse). Plan 05 NO LONGER edits cc_session.rb.
- Plan 05 now contains only TWO tasks: implement the write tool + write its tests. The previous "Task 1: augment CcSession" is gone — that's Plan 01 territory.
- Plan 04 and Plan 05 are now genuinely independent in Wave 2 (no ordering coupling on cc_session.rb edits).

Output: `cc_finalize_teilnehmerliste` tool wrapping `releaseMeldeliste` PATH_MAP
action; tests covering dry-run / armed-mock / CC-error / session-reauth / defensive
guard.
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
@app/services/region_cc/registration_syncer.rb

@lib/mcp_server/tools/base_tool.rb
@lib/mcp_server/cc_session.rb
@lib/mcp_server/tools/mock_client.rb

<interfaces>
<!-- Existing Carambus-side write convention (D-19 reuses it) -->

From app/services/region_cc/club_cloud_client.rb:469-506:
```ruby
def post(action, post_options = {}, opts = {})
  dry_run = opts[:armed].blank?  # <-- The convention: opts[:armed] gates the actual HTTP call
  read_only_action = PATH_MAP[action][1]  # false for releaseMeldeliste
  if !dry_run || read_only_action
    # ... actually performs the POST
  end
  [res, doc]  # Returns [nil, nil] when in dry-run for write actions
end
```

From PATH_MAP entry verified at line 332:
```ruby
"releaseMeldeliste" => ["/admin/einzel/meldelisten/releaseMeldeliste.php", false],
# Required POST params (per RESEARCH §"Verifikation `releaseMeldeliste`"): branchId, fedId, season, meldelisteId, release: ""
```

From lib/mcp_server/cc_session.rb (Plan 01 — fully implemented, no placeholder):
```ruby
McpServer::CcSession.client_for       # returns RegionCc::ClubCloudClient or McpServer::Tools::MockClient
McpServer::CcSession.cookie           # returns active PHPSESSID (login via Setting.login_to_cc)
McpServer::CcSession.reauth_if_needed!(doc)  # returns true if login-redirect detected; reset+re-login transparent
```

From McpServer::Tools::BaseTool (Plan 01) — error / text / validate_required! / cc_session helpers.
From McpServer::Tools::MockClient (Plan 01) — drop-in client; honors opts[:armed].blank? for write actions.

**SDK API contracts (locked by Plan 01 Task 3 SDK-API smoke probe):**
- `tool_name`, `description`, `input_schema(properties:, required:)`, `annotations` are class-level DSL
- `MCP::Tool::Response.new(content, error: bool)`; instance has `#error` and `#content`
- These are NOT hedged in Plan 05 — Plan 01 verifies them at install time.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Implement cc_finalize_teilnehmerliste write tool with armed-flag + role-error parsing + retry-on-reauth</name>
  <files>lib/mcp_server/tools/finalize_teilnehmerliste.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md (Example 2 — Write-Tool template, D-19 verification block, Pitfall 6 schema validation)
    - /Users/gullrich/DEV/carambus/carambus_api/app/services/region_cc/club_cloud_client.rb (lines 332-337 — `releaseMeldeliste` PATH_MAP entry comment block; lines 469-506 — post() armed-flag semantics)
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/base_tool.rb (Plan 01 helpers)
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/cc_session.rb (Plan 01 — full login + reauth_if_needed! already in place; this plan does NOT edit this file)
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-01-SUMMARY.md (SDK API findings)
  </read_first>
  <behavior>
    - Tool subclasses `McpServer::Tools::BaseTool`, has `tool_name "cc_finalize_teilnehmerliste"`, EN description, EN schema text
    - Schema declares 4 required params + `armed` (default false)
    - `annotations(read_only_hint: false, destructive_hint: true)` — explicit destructive declaration
    - `call(...)` flow:
      1. `validate_required!(args, [:fed_id, :branch_id, :season, :meldeliste_id])` — early return on missing
      2. Build CC `client` via `cc_session.client_for`
      3. Call `client.post("releaseMeldeliste", {branchId:, fedId:, season:, meldelisteId:, release: ""}, {armed: armed, session_id: cc_session.cookie})`
      4. If `armed: false` → tool returns "Would finalize Meldeliste {id} for branch {b}, season {s}." dry-run text
      5. If `armed: true` and `res&.code != "200"` → call `parse_cc_error(doc)` and return structured error envelope (D-11 trust-CC-and-parse-error)
      6. If `armed: true` and `cc_session.reauth_if_needed!(doc)` → ONE retry; if reauth-and-retry still fails, return error
      7. On success → return "Finalized Meldeliste {id} for branch {b}, season {s}." text
    - `parse_cc_error(doc)` returns string identifying error: "Session expired (login redirect)", "Permission denied: ...", or "(no error)"
    - Defensive `rescue StandardError => e` → returns "Tool exception: #{e.class.name}" envelope (NO `.message` / `.backtrace` — threat T-40-04-03)
  </behavior>
  <action>
    Create `lib/mcp_server/tools/finalize_teilnehmerliste.rb`:
    ```ruby
    # frozen_string_literal: true
    # cc_finalize_teilnehmerliste — D-19 proof write tool (the single write-tool shipped in Phase 40).
    # Wraps PATH_MAP['releaseMeldeliste']. Honors armed-flag dry-run convention (D-03).
    # Trust-CC-and-parse-error (D-11) for permission failures.
    # Retries once after transparent reauth (Plan 01 cc_session.reauth_if_needed!).

    module McpServer
      module Tools
        class FinalizeTeilnehmerliste < BaseTool
          tool_name "cc_finalize_teilnehmerliste"
          description <<~DESC
            Finalize (release) a Meldeliste in ClubCloud, locking the participant list.
            After finalization, CC accepts result uploads for this tournament.
            Requires Club-Sportwart or higher CC role; CC will reject with a permission error otherwise.
            Pass `armed: false` (default) for a dry-run that only describes what would happen.
          DESC
          input_schema(
            properties: {
              fed_id:        { type: "integer", description: "ClubCloud federation ID (e.g. 20 for BCW)" },
              branch_id:     { type: "integer", description: "CC branch (e.g. 10 for Karambol)" },
              season:        { type: "string",  description: "Season name like '2025/2026'" },
              meldeliste_id: { type: "integer", description: "CC meldelisteId of the participant list" },
              armed:         { type: "boolean", default: false, description: "If false (default), dry-run only — no CC mutation" }
            },
            required: ["fed_id", "branch_id", "season", "meldeliste_id"]
          )
          annotations(read_only_hint: false, destructive_hint: true)

          def self.call(fed_id: nil, branch_id: nil, season: nil, meldeliste_id: nil, armed: false, server_context: nil)
            err = validate_required!(
              { fed_id: fed_id, branch_id: branch_id, season: season, meldeliste_id: meldeliste_id },
              [:fed_id, :branch_id, :season, :meldeliste_id]
            )
            return err if err

            client = cc_session.client_for
            res, doc = client.post(
              "releaseMeldeliste",
              { branchId: branch_id, fedId: fed_id, season: season, meldelisteId: meldeliste_id, release: "" },
              { armed: armed, session_id: cc_session.cookie }
            )

            # Dry-run path: armed: false returns [nil, nil] from RegionCc::ClubCloudClient#post for write actions
            return text("Would finalize Meldeliste #{meldeliste_id} for branch #{branch_id}, season #{season}.") unless armed

            # Armed path: res must be present and 200; otherwise parse error
            if res.nil?
              return error("Unexpected nil response from CC (armed mode). MockClient may have rejected.")
            end

            # Reauth retry: Plan 01's cc_session.reauth_if_needed! detects login-redirect, re-logs in transparently
            if cc_session.reauth_if_needed!(doc)
              # Retry once after reauth
              res, doc = client.post(
                "releaseMeldeliste",
                { branchId: branch_id, fedId: fed_id, season: season, meldelisteId: meldeliste_id, release: "" },
                { armed: armed, session_id: cc_session.cookie }
              )
            end

            if res&.code != "200"
              return error("CC rejected: #{parse_cc_error(doc)} (HTTP #{res&.code})")
            end

            # Inspect doc body for embedded error response (CC sometimes returns 200 with an error div)
            parsed = parse_cc_error(doc)
            return error("CC rejected: #{parsed}") if parsed && parsed != "(no error)"

            text("Finalized Meldeliste #{meldeliste_id} for branch #{branch_id}, season #{season}.")
          rescue StandardError => e
            # Defensive — never leak stacktrace (Pitfall 6 + threat T-40-04-03)
            error("Tool exception: #{e.class.name} (details suppressed; check Rails.logger on stderr).")
          end

          # Returns a string identifying the CC-side error mode, or "(no error)" for clean responses.
          def self.parse_cc_error(doc)
            return "(no error)" if doc.nil?
            return "Session expired (login redirect)" if doc.css("form[action*='login']").any?
            err = doc.css("div.error, .errorMessage, .alert-danger").map(&:text).map(&:strip).reject(&:empty?).first
            return err if err
            "(no error)"
          end
        end
      end
    end
    ```

    Note: `MockClient#post` in Plan 01 honors `opts[:armed].blank?` for write actions and returns `[nil, nil]` in dry-run; in armed-mode it returns a stub-200 response. Both paths are covered by Task 2 tests below.
  </action>
  <verify>
    <automated>bundle exec rails runner "tools = McpServer::Server.build.tools; finalize = tools.find { |t| (t.respond_to?(:tool_name) ? t.tool_name : t.name).to_s.include?('finalize_teilnehmerliste') }; abort('finalize tool not registered') unless finalize; puts 'finalize tool registered'"</automated>
  </verify>
  <acceptance_criteria>
    - `lib/mcp_server/tools/finalize_teilnehmerliste.rb` exists with `frozen_string_literal: true` on line 2
    - tool_name is exactly `cc_finalize_teilnehmerliste`: `grep -c 'tool_name "cc_finalize_teilnehmerliste"' lib/mcp_server/tools/finalize_teilnehmerliste.rb` returns 1
    - annotations include `destructive_hint: true`: `grep -c "destructive_hint: true" lib/mcp_server/tools/finalize_teilnehmerliste.rb` returns 1
    - 4 required params declared in schema: `grep -c 'required: \\["fed_id", "branch_id", "season", "meldeliste_id"\\]' lib/mcp_server/tools/finalize_teilnehmerliste.rb` returns 1
    - `armed` flag defaults to false: `grep "default: false" lib/mcp_server/tools/finalize_teilnehmerliste.rb | grep -c "armed"` returns >= 1
    - parse_cc_error handles login-redirect AND error-div: `grep -c "form\\[action\\*='login'\\]" lib/mcp_server/tools/finalize_teilnehmerliste.rb` returns 1; `grep -c "div.error" lib/mcp_server/tools/finalize_teilnehmerliste.rb` returns 1
    - Uses Plan 01's `cc_session.reauth_if_needed!`: `grep -c "cc_session\\.reauth_if_needed!" lib/mcp_server/tools/finalize_teilnehmerliste.rb` returns 1
    - **Plan 05 does NOT touch cc_session.rb** (Warning 7 fix): `git diff --stat lib/mcp_server/cc_session.rb` for this plan should show 0 changes
    - Tool is auto-registered by Plan 01's collect_tools: `bundle exec rails runner "tools = McpServer::Server.build.tools.map { |t| (t.respond_to?(:tool_name) ? t.tool_name : t.name).to_s }; abort('not registered') unless tools.any? { |n| n.include?('finalize_teilnehmerliste') }"` exits 0
  </acceptance_criteria>
  <done>cc_finalize_teilnehmerliste tool compiled, auto-registered, JSON-schema declares 4 required params + armed flag, parse_cc_error covers login-redirect + error-div modes (D-11), uses Plan 01's reauth_if_needed! for retry. cc_session.rb untouched (Warning 7).</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Tests — dry-run, armed-mock-success, role-error parsing, session-reauth retry, defensive guard</name>
  <files>test/mcp_server/tools/finalize_teilnehmerliste_test.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/finalize_teilnehmerliste.rb (just-written)
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/tools/mock_client.rb (Plan 01 — verify .post stub structure)
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/cc_session.rb (Plan 01 — full login + reauth already in place)
    - /Users/gullrich/DEV/carambus/carambus_api/test/mcp_server/cc_session_test.rb (test pattern reference)
  </read_first>
  <behavior>
    - Test 1 (dry-run, armed: false default): Returns text "Would finalize Meldeliste 42..." — no error, MockClient.calls last entry has `opts[:armed]` blank
    - Test 2 (armed: true mock-success): MockClient returns stub-200; tool returns "Finalized Meldeliste 42..." text — no error
    - Test 3 (validation: missing meldeliste_id): Returns error "Missing required parameter" listing meldeliste_id
    - Test 4 (D-11 role-error parsing): Stub MockClient.post to return error-div doc. Tool returns error response with text matching /CC rejected.*Permission denied/
    - Test 5 (D-11 login-redirect → reauth + retry): First call returns login-form; second call returns success. Tool returns "Finalized..." text (single retry)
    - Test 6 (StandardError defensive guard): Stub `client.post` to raise. Tool returns error envelope with "Tool exception: RuntimeError" (no stacktrace)
  </behavior>
  <action>
    Create `test/mcp_server/tools/finalize_teilnehmerliste_test.rb`:
    ```ruby
    # frozen_string_literal: true
    require "test_helper"

    class McpServer::Tools::FinalizeTeilnehmerlisteTest < ActiveSupport::TestCase
      setup do
        ENV["CARAMBUS_MCP_MOCK"] = "1"
        McpServer::CcSession.reset!
        # Build a fresh MockClient and inject as override so we can spy on calls
        @mock = McpServer::Tools::MockClient.new
        McpServer::CcSession._client_override = @mock
      end

      teardown do
        ENV["CARAMBUS_MCP_MOCK"] = nil
        McpServer::CcSession._client_override = nil
        McpServer::CcSession.reset!
      end

      test "dry-run (armed: false default) returns 'would finalize' text without mutating" do
        response = McpServer::Tools::FinalizeTeilnehmerliste.call(
          fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42,
          server_context: nil
        )
        refute response.error
        assert_match(/Would finalize Meldeliste 42/, response.content.first[:text])
        # MockClient was called, opts[:armed] was blank
        assert @mock.calls.any? { |verb, action, _params, opts| verb == :post && action == "releaseMeldeliste" && opts[:armed].blank? }
      end

      test "armed: true with mock-success returns finalized text" do
        response = McpServer::Tools::FinalizeTeilnehmerliste.call(
          fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42, armed: true,
          server_context: nil
        )
        refute response.error
        assert_match(/Finalized Meldeliste 42/, response.content.first[:text])
      end

      test "validation: missing meldeliste_id returns error listing it" do
        response = McpServer::Tools::FinalizeTeilnehmerliste.call(
          fed_id: 20, branch_id: 10, season: "2025/2026",
          server_context: nil
        )
        assert response.error
        assert_match(/Missing required parameter/i, response.content.first[:text])
        assert_match(/meldeliste_id/, response.content.first[:text])
      end

      test "D-11 role-error parsing: error-div in CC response surfaces as MCP error" do
        error_doc = Nokogiri::HTML('<html><body><div class="error">Permission denied: requires Club-Sportwart</div></body></html>')
        @mock.define_singleton_method(:post) do |action, params, opts|
          [Struct.new(:code, :message, :body).new("200", "OK", ""), error_doc]
        end

        response = McpServer::Tools::FinalizeTeilnehmerliste.call(
          fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42, armed: true,
          server_context: nil
        )
        assert response.error
        assert_match(/CC rejected.*Permission denied/, response.content.first[:text])
      end

      test "D-11 login-redirect triggers reauth + retry" do
        login_doc   = Nokogiri::HTML('<html><body><form action="/login.php"><input/></form></body></html>')
        success_doc = Nokogiri::HTML('<html><body><table>OK</table></body></html>')
        ok_response = Struct.new(:code, :message, :body).new("200", "OK", "")
        call_count = 0
        @mock.define_singleton_method(:post) do |action, params, opts|
          call_count += 1
          if call_count == 1
            [ok_response, login_doc]
          else
            [ok_response, success_doc]
          end
        end

        response = McpServer::Tools::FinalizeTeilnehmerliste.call(
          fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42, armed: true,
          server_context: nil
        )
        refute response.error
        assert_match(/Finalized Meldeliste 42/, response.content.first[:text])
        assert_equal 2, call_count, "Expected exactly one reauth-retry"
      end

      test "defensive: StandardError in client.post returns error envelope without stacktrace" do
        @mock.define_singleton_method(:post) do |*_|
          raise RuntimeError, "simulated network failure"
        end

        response = McpServer::Tools::FinalizeTeilnehmerliste.call(
          fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42, armed: true,
          server_context: nil
        )
        assert response.error
        assert_match(/Tool exception: RuntimeError/, response.content.first[:text])
        refute_match(/backtrace|line \d+/i, response.content.first[:text]) # no stacktrace leak
      end
    end
    ```

    Run:
    ```
    bin/rails test test/mcp_server/tools/finalize_teilnehmerliste_test.rb
    ```
    6 tests, all must pass.

    SDK API contracts (`response.error`, `response.content.first[:text]`) are locked by Plan 01 Task 3 SDK-API smoke probe — no conditional hedging needed in this test (Warning 8 fix).
  </action>
  <verify>
    <automated>bin/rails test test/mcp_server/tools/finalize_teilnehmerliste_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - `test/mcp_server/tools/finalize_teilnehmerliste_test.rb` exists with `frozen_string_literal: true` on line 2
    - 6 tests: `bin/rails test test/mcp_server/tools/finalize_teilnehmerliste_test.rb` reports `6 runs, 0 failures, 0 errors`
    - D-19 proof: dry-run test (Test 1) verifies `Mock.calls` contains `[:post, "releaseMeldeliste", ..., {armed: blank}]` exactly once
    - D-11 proof: 2 separate tests (Test 4 role-error, Test 5 login-redirect) cover both branches of `parse_cc_error`
    - Defense-in-depth: Test 6 verifies no stacktrace leak (T-40-04-03 mitigation)
  </acceptance_criteria>
  <done>6 tests pass; D-19 + D-11 + threat-mitigation verified; ready for end-to-end Plan 06 stdio test.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| MCP-client → tool.call | LLM-supplied params; `armed: true` is the user-visible confirmation gate (D-19) |
| tool.call → CC-Backend (armed-true path) | HTTPS, real mutation; PHPSESSID-cookie-bound |
| LocalProtector boundary | Tool MUST NOT mutate any Carambus-side `id < 50_000_000` records — CC-side mutation only |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-40-05-01 | Tampering | Unintended CC-mutation when LLM omits `armed: true` | mitigate | `armed: false` is the default in JSON-schema; tool returns "would finalize" dry-run text without calling CC; verified by Test 1 |
| T-40-05-02 | Elevation of Privilege | LLM bypasses allowlist by passing arbitrary action via params | mitigate | Tool hardcodes `client.post("releaseMeldeliste", ...)` — no action-name parameter; D-04 + D-19 |
| T-40-05-03 | Information Disclosure | CC error message leaks user role / club info | accept | D-11 explicit decision: surface CC error verbatim to user; rationale: actionable feedback for Sportwart >> info-leak risk |
| T-40-05-04 | Information Disclosure | Tool exception leaks Ruby stacktrace via .message + .backtrace | mitigate | `rescue StandardError => e` + bounded `error("Tool exception: #{e.class.name} ...")` (no `.message`/`.backtrace`); verified by Test 6 |
| T-40-05-05 | Spoofing | Stale PHPSESSID after 30-min idle causes silent failure | mitigate | `cc_session.reauth_if_needed!` (Plan 01) with one retry on login-redirect (Test 5); D-10 |
| T-40-05-06 | Tampering | LocalProtector violation — tool writes to Carambus globals | mitigate | Tool only calls `client.post(...)` (CC-side mutation); no AR-write paths in tool body — verified by `grep` returning 0 ActiveRecord write calls in finalize_teilnehmerliste.rb |
| T-40-05-07 | Information Disclosure | CC_PASSWORD leaked through `client.post` log lines | mitigate | `client.post` only logs `post_options` (no credentials); credentials live in `RegionCc::ClubCloudClient#initialize` (instance-private), not POST body |
</threat_model>

<verification>
- `cc_finalize_teilnehmerliste` registered: `bundle exec rails runner "puts McpServer::Server.build.tools.map { |t| t.respond_to?(:tool_name) ? t.tool_name : t.name }.grep(/finalize/).first"` outputs `cc_finalize_teilnehmerliste`
- Allowlist: this is the ONLY write tool — `grep -rl "destructive_hint: true" lib/mcp_server/tools/` returns exactly 1 file (finalize_teilnehmerliste.rb)
- D-11 trust-CC-and-parse-error verified by Tests 4 + 5
- D-19 dry-run-default verified by Test 1
- LocalProtector: `grep -E "\\.(save|update|destroy|create)\\b" lib/mcp_server/tools/finalize_teilnehmerliste.rb` returns 0 lines (no AR writes)
- All 6 tests pass
- No `puts`/`print` in tool: `grep -E '\\bputs\\b|\\bprint\\b' lib/mcp_server/tools/finalize_teilnehmerliste.rb` returns 0 lines
- **Plan 05 does NOT modify cc_session.rb** (Warning 7): full login implementation already in Plan 01
</verification>

<success_criteria>
- ONE write tool exposed (`cc_finalize_teilnehmerliste` per D-19); no other tool has `destructive_hint: true`
- D-11 trust-CC-and-parse-error: parse_cc_error covers BOTH login-redirect (session expiry) and `<div class="error">` (permission/CC error) modes; 2 tests verify
- All 6 finalize-tool tests pass
- D-08 mock-mode failsafe (Plan 01) preserved — production + CARAMBUS_MCP_MOCK=1 still raises
- LocalProtector contract preserved — no Carambus-side `id < 50_000_000` mutations from tool body
- Plan 05 + Plan 04 are independent in Wave 2 — Plan 05 does NOT edit cc_session.rb (Warning 7 fix)
</success_criteria>

<output>
After completion, create `.planning/phases/40-mcp-server-clubcloud/40-05-SUMMARY.md` documenting:
- Confirmation that login + reauth implementation lives entirely in Plan 01 (Setting.login_to_cc reuse, Warning 7 + Blocker 4 audit)
- Whether SDK 0.15.0's `MCP::Tool::Response` exposed `.error`/`.content` as expected per Plan 01 SDK-API findings (Warning 8)
- Phase 40.1 followup list: which write tools (`cc_create_team`, `cc_add_player_to_team`, `cc_upload_result`, `cc_release_endrangliste`) are now unblocked by this architecture
- LocalProtector audit summary (grep result for AR writes inside tool body)
</output>
</content>
</invoke>