---
phase: 40-mcp-server-clubcloud
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Gemfile
  - Gemfile.lock
  - bin/mcp-server
  - lib/mcp_server/server.rb
  - lib/mcp_server/cc_session.rb
  - lib/mcp_server/transport/boot.rb
  - lib/mcp_server/tools/base_tool.rb
  - lib/mcp_server/tools/mock_client.rb
  - test/mcp_server/server_smoke_test.rb
  - test/mcp_server/cc_session_test.rb
autonomous: true
requirements: [D-12, D-13, D-14, D-15, D-08, D-10]
requirements_addressed: [D-12, D-13, D-14, D-15, D-08, D-10]
user_setup: []

must_haves:
  truths:
    - "Gemfile lists `gem \"mcp\", \"~> 0.15\"` in the main group (not :development), Gemfile.lock contains mcp 0.15.x"
    - "`bin/mcp-server` is an executable Ruby file (mode 0755) that boots Rails, redirects Rails.logger to STDERR, traps SIGINT/SIGTERM, and opens MCP::Server::Transports::StdioTransport"
    - "`bundle exec rails runner \"puts McpServer::Server\"` exits 0 and prints `McpServer::Server` (Zeitwerk autoload via Rails 7.2 default `autoload_lib` works without config change)"
    - "`McpServer::CcSession` caches PHPSESSID in-memory with ~30 min TTL, raises RuntimeError when `Rails.env.production?` AND `ENV[\"CARAMBUS_MCP_MOCK\"] == \"1\"` (failsafe)"
    - "`McpServer::CcSession#login!` is FULLY IMPLEMENTED in Plan 01 (no placeholder) — uses existing `Setting.login_to_cc` for real CC login when not in mock-mode (per revision Blocker 4 + Warning 7)"
    - "`McpServer::Server.build` installs a SINGLE central `resources_read_handler` block on the SDK server that dispatches by URI scheme + path prefix to per-resource read methods — Plans 02 + 03 do NOT register their own read_handler (per revision Blocker 2 + 3, Wave-2 conflict-free)"
    - "Plan 01 Task 3 includes an SDK-API smoke probe that verifies `tool_name`/`description`/`input_schema` DSL exists and `MCP::Tool::Response` exposes `#error`/`#content` (Warning 8 — eliminates conditional hedges in Plans 04 + 05)"
  artifacts:
    - path: "Gemfile"
      provides: "Adds `gem \"mcp\", \"~> 0.15\"` to main group"
      contains: 'gem "mcp"'
    - path: "bin/mcp-server"
      provides: "Executable entrypoint that MCP clients spawn"
      min_lines: 25
    - path: "lib/mcp_server/server.rb"
      provides: "McpServer::Server.build builds an MCP::Server with auto-registered tools+resources via constants AND a single central resources_read_handler dispatcher"
      min_lines: 60
    - path: "lib/mcp_server/cc_session.rb"
      provides: "PHPSESSID cache + lazy-login (real Setting.login_to_cc reuse, no placeholder) + reauth_if_needed! + mock-mode failsafe"
      min_lines: 90
    - path: "lib/mcp_server/transport/boot.rb"
      provides: "Rails.logger STDERR redirect + signal traps + transport.open"
      min_lines: 25
    - path: "lib/mcp_server/tools/base_tool.rb"
      provides: "Common MCP::Tool subclass helpers (cc_client, mock_mode?, error envelope, validate_input!)"
      min_lines: 40
    - path: "lib/mcp_server/tools/mock_client.rb"
      provides: "Drop-in replacement for RegionCc::ClubCloudClient when CARAMBUS_MCP_MOCK=1"
      min_lines: 35
    - path: "test/mcp_server/server_smoke_test.rb"
      provides: "Boot smoke test — server constant resolves, server name correct, registry empty pre-Wave-2 + SDK-API smoke probe"
      min_lines: 50
    - path: "test/mcp_server/cc_session_test.rb"
      provides: "CcSession tests — mock failsafe, mock-client, env-var-missing, TTL, reauth_if_needed!"
      min_lines: 80
  key_links:
    - from: "bin/mcp-server"
      to: "lib/mcp_server/transport/boot.rb"
      via: "require_relative or Rails autoload"
      pattern: "McpServer::Transport::Boot\\.run"
    - from: "lib/mcp_server/cc_session.rb"
      to: "Setting.login_to_cc"
      via: "method call (existing canonical login flow)"
      pattern: "Setting\\.login_to_cc"
    - from: "lib/mcp_server/server.rb"
      to: "McpServer::Tools and McpServer::Resources constants"
      via: ".constants enumeration to auto-register"
      pattern: "McpServer::Tools\\.constants"
    - from: "lib/mcp_server/server.rb (resources_read_handler dispatcher)"
      to: "WorkflowScenarios.read / WorkflowMeta.read / ApiSurface.read"
      via: "URI regex match in single central handler"
      pattern: "resources_read_handler"
---

<objective>
Foundation of the MCP server. Adds the `mcp` gem, scaffolds `lib/mcp_server/`
with a Zeitwerk-strict camelCase namespace (McpServer, NOT MCPServer), creates
the executable `bin/mcp-server`, and establishes the dynamic registry pattern
that Plans 02-05 will plug into without modifying server.rb.

**Revision 2026-05-07 changes:**
- Plan 01 now installs the SINGLE central `resources_read_handler` dispatcher in `server.rb` (Blockers 2 + 3). Plans 02 + 03 only expose `.read(slug:)` / `.read(action:)` class methods — no `install_read_handler` calls.
- `CcSession#login!` is fully implemented here (not a placeholder) using `Setting.login_to_cc` per Warning 7. Plan 05 only adds reauth + write-tool semantics on top.
- Task 3 adds an SDK-API smoke probe to lock down the `tool_name`/`description`/`input_schema` DSL and `MCP::Tool::Response` shape (Warning 8) — Plans 04 + 05 reference these findings instead of hedging.

Purpose: Without this, no MCP request can be answered. This plan unblocks all
parallel Wave-2 plans (workflow-resources, api-resources, read-tools, write-tool)
WITHOUT cross-plan refactor coupling.

Output: A bootable `bin/mcp-server` that starts cleanly with empty tool/resource
arrays, ready for Plans 02-05 to populate via the constants-based registry.
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
@app/models/setting.rb
@config/application.rb
@lib/scenario_generator.rb

<interfaces>
<!-- Existing contracts the plan must use as-is -->

From app/services/region_cc/club_cloud_client.rb:
```ruby
class RegionCc::ClubCloudClient
  PATH_MAP = { "home" => ["", true], "showLeagueList" => [...], ... }.freeze
  def initialize(base_url:, username:, userpw:); end
  def get(action, get_options = {}, opts = {}); end   # returns [Net::HTTPResponse, Nokogiri::HTML::Document]
  def post(action, post_options = {}, opts = {}); end # opts[:armed].blank? => dry-run; opts[:session_id] => PHPSESSID
end
```

From app/models/setting.rb (canonical CC login flow — VERIFIED via grep):
```ruby
def self.login_to_cc
  # Reads region/credentials from RegionCcAction.get_base_opts_from_environment + Rails Credentials
  # POSTs to {base_url}/login/checkUser.php with call_police, MD5 password, etc.
  # Stores session_id in Setting.key_set_value("session_id", session_id)
  # Returns the session_id string on success
end
```

From config/application.rb (line 86 — already configured, do NOT change):
```ruby
config.autoload_lib(ignore: %w[assets generators tasks templates])
# This means lib/mcp_server/ is automatically Zeitwerk-loaded.
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add mcp gem to Gemfile + scaffold lib/mcp_server skeleton + bin/mcp-server</name>
  <files>Gemfile, Gemfile.lock, bin/mcp-server, lib/mcp_server/server.rb, lib/mcp_server/transport/boot.rb, lib/mcp_server/tools/base_tool.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/Gemfile
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md (sections "Standard Stack", "Pattern 1", "Pattern 4", "Pitfall 1", "Pitfall 2", "Pitfall 8")
    - /Users/gullrich/DEV/carambus/carambus_api/lib/scenario_generator.rb (canonical lib/ pattern reference)
    - /Users/gullrich/DEV/carambus/carambus_api/config/application.rb (verify line 86 autoload_lib stays untouched)
  </read_first>
  <behavior>
    - Test 1: `bundle exec rails runner "puts McpServer::Server"` exits 0 — Zeitwerk loads the constant from lib/mcp_server/server.rb
    - Test 2: `bundle exec rails runner "puts McpServer::Tools::BaseTool.ancestors.first(3).inspect"` includes MCP::Tool — base class is correctly subclassed
    - Test 3: `bin/mcp-server` is mode 0755 (file -L returns "executable")
    - Test 4: `head -1 bin/mcp-server` is `#!/usr/bin/env ruby`
    - Test 5: `grep -c "frozen_string_literal: true" lib/mcp_server/server.rb` returns 1
  </behavior>
  <action>
    Step 1 — Add gem to `Gemfile` (NOT in :development group). Insert AFTER an existing main-group line like `gem "redis"` (find any line near top-level main group). Exact line:
    ```ruby
    gem "mcp", "~> 0.15"
    ```
    Run `bundle install` to update Gemfile.lock. Verify `bundle list mcp` shows version 0.15.x.

    Step 2 — Create `bin/mcp-server` (executable, mode 0755) with this exact content:
    ```ruby
    #!/usr/bin/env ruby
    # frozen_string_literal: true
    # Carambus MCP-Server entrypoint — gespawnt von MCP-Clients (Claude Desktop / Code) als Subprocess.
    # JSON-RPC läuft über STDIN/STDOUT — daher MUSS STDOUT sauber bleiben (Pitfall 1).

    ENV["RAILS_ENV"] ||= "production"
    require_relative "../config/environment"

    require "mcp_server/transport/boot"
    McpServer::Transport::Boot.run
    ```
    Set executable bit: `chmod 0755 bin/mcp-server`.

    Step 3 — Create `lib/mcp_server/transport/boot.rb`:
    ```ruby
    # frozen_string_literal: true
    # Boot-Helper: leitet Rails.logger auf STDERR um (sonst korrumpiert Logger-Output JSON-RPC),
    # registriert Signal-Handler (SDK undokumentiert — Pitfall 8), öffnet StdioTransport.
    #
    # SDK-Verhalten bei invalidem JSON von stdin (RESOLVED in 40-RESEARCH.md Open Questions §1):
    # SDK gibt JSON-RPC -32700 Parse error per Spec zurück; Server-Loop crashed nicht.

    require "mcp"

    module McpServer
      module Transport
        module Boot
          def self.run
            Rails.logger = Logger.new($stderr)
            Rails.logger.level = Logger::INFO
            $stdout.sync = true

            server = McpServer::Server.build

            %w[INT TERM].each do |sig|
              Signal.trap(sig) do
                Rails.logger.info "[mcp-server] caught SIG#{sig}, exiting"
                exit 0
              end
            end

            transport = MCP::Server::Transports::StdioTransport.new(server)
            transport.open
          end
        end
      end
    end
    ```

    Step 4 — Create `lib/mcp_server/server.rb` with the dynamic registry pattern AND the SINGLE central `resources_read_handler` dispatcher (per revision Blockers 2 + 3):
    ```ruby
    # frozen_string_literal: true
    # Server-Wiring: instanziiert MCP::Server, registriert alle McpServer::Tools::* Subclasses
    # automatisch via Zeitwerk-vorgeladene Konstanten + alle McpServer::Resources::* via Registry-Module.
    #
    # CRITICAL (per revision 2026-05-07 Blockers 2+3): The MCP SDK accepts ONE `resources_read_handler`
    # block per server. Plan 01 owns this single handler; Plans 02 (workflow) + 03 (api_surface) ONLY
    # expose `.read(slug:|action:, uri:)` class methods. They do NOT register their own handler.
    # This makes Wave 2 conflict-free — no plan touches server.rb after Plan 01.

    module McpServer
      class Server
        SERVER_NAME = "carambus_clubcloud"

        # Build the server with auto-registered tools and resources.
        # Plans 02..05 add files; this method picks them up via constant enumeration.
        def self.build
          # Force-load tool subclass files so .constants enumeration is complete after autoload.
          eager_load_namespace!

          tools = collect_tools
          resources = collect_resources

          server = MCP::Server.new(
            name: SERVER_NAME,
            tools: tools,
            resources: resources
          )

          install_central_read_handler(server)
          server
        end

        def self.collect_tools
          return [] unless defined?(McpServer::Tools)
          McpServer::Tools.constants.map { |c| McpServer::Tools.const_get(c) }
            .select { |k| k.is_a?(Class) && k < MCP::Tool }
        end

        def self.collect_resources
          # Resources::*.all returns Array<MCP::Resource> (Plans 02-03 implement .all)
          collected = []
          [
            ("McpServer::Resources::WorkflowScenarios" if defined?(McpServer::Resources::WorkflowScenarios)),
            ("McpServer::Resources::WorkflowMeta" if defined?(McpServer::Resources::WorkflowMeta)),
            ("McpServer::Resources::ApiSurface" if defined?(McpServer::Resources::ApiSurface))
          ].compact.each do |const_name|
            klass = const_name.constantize
            collected.concat(klass.all) if klass.respond_to?(:all)
          end
          collected
        end

        # Single central dispatcher — routes resources/read requests to the right registry class
        # by URI scheme + path prefix. Per revision Blocker 2+3: ONE handler per server.
        def self.install_central_read_handler(server)
          server.resources_read_handler do |params|
            uri = params[:uri].to_s
            case uri
            when %r{\Acc://workflow/scenarios/(?<slug>[\w-]+)\z}
              if defined?(McpServer::Resources::WorkflowScenarios)
                content = McpServer::Resources::WorkflowScenarios.read(slug: $~[:slug])
                [{ uri: uri, mimeType: "text/markdown", text: content }]
              end
            when %r{\Acc://workflow/(?<key>roles|glossary)\z}
              if defined?(McpServer::Resources::WorkflowMeta)
                content = McpServer::Resources::WorkflowMeta.read(key: $~[:key])
                [{ uri: uri, mimeType: "text/markdown", text: content }]
              end
            when %r{\Acc://api/(?<action>[\w-]+)\z}
              if defined?(McpServer::Resources::ApiSurface)
                content = McpServer::Resources::ApiSurface.read(action: $~[:action])
                [{ uri: uri, mimeType: "text/markdown", text: content }]
              end
            else
              # Per MCP spec: returning nil/empty causes the SDK to surface a ResourceNotFound error frame.
              nil
            end
          end
        end

        def self.eager_load_namespace!
          tools_dir = Rails.root.join("lib/mcp_server/tools")
          resources_dir = Rails.root.join("lib/mcp_server/resources")
          [tools_dir, resources_dir].each do |dir|
            Dir.glob(dir.join("*.rb")).sort.each { |f| require f }
          end
        end
      end
    end
    ```

    Step 5 — Create `lib/mcp_server/tools/base_tool.rb`:
    ```ruby
    # frozen_string_literal: true
    # BaseTool — Common Helpers für alle MCP-Tool-Subklassen.
    # MCP::Tool#input_schema ist deskriptiv, NICHT runtime-validation (Pitfall 6) —
    # daher manuell validieren und strukturierten Error zurückgeben.
    #
    # SDK-API findings (verified by Task 3 SDK-API smoke probe — see Plan 01 SUMMARY):
    # - `tool_name`, `description`, `input_schema`, `annotations` are class-level DSL macros
    # - `MCP::Tool::Response.new(content, error: bool)` exposes `#error` and `#content`

    module McpServer
      module Tools
        class BaseTool < MCP::Tool
          # Construct an error response in the SDK-canonical shape.
          def self.error(message)
            MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
          end

          # Construct a text response.
          def self.text(message)
            MCP::Tool::Response.new([{ type: "text", text: message }])
          end

          # Manually validate that all required keys in the schema are present.
          # Returns nil on success, error response on failure.
          def self.validate_required!(args, required_keys)
            missing = required_keys.reject { |k| args[k.to_sym] || args[k.to_s] }
            return nil if missing.empty?
            error("Missing required parameter(s): #{missing.join(', ')}")
          end

          # Returns true if CARAMBUS_MCP_MOCK is set; tools should branch their CC-call paths.
          def self.mock_mode?
            ENV["CARAMBUS_MCP_MOCK"] == "1"
          end

          # Lazy CC-client accessor — Tools delegate to McpServer::CcSession (Plan 01 Task 2).
          def self.cc_session
            McpServer::CcSession
          end
        end
      end
    end
    ```

    Step 6 — Verify Zeitwerk loads everything:
    ```
    bundle exec rails runner "puts McpServer::Server; puts McpServer::Tools::BaseTool.ancestors.take(3).inspect"
    ```
    Must print `McpServer::Server` and an array including `MCP::Tool`. If Zeitwerk::NameError fires, check that filename → constant follows snake-to-camel rule (Pitfall 2).
  </action>
  <verify>
    <automated>test -x bin/mcp-server && grep -q 'gem "mcp"' Gemfile && grep -q "mcp (0.15" Gemfile.lock && bundle exec rails runner "exit(McpServer::Server.is_a?(Class) ? 0 : 1)"</automated>
  </verify>
  <acceptance_criteria>
    - `Gemfile` contains line `gem "mcp", "~> 0.15"` (NOT under `group :development` block)
    - `Gemfile.lock` contains `mcp (0.15` (some 0.15.x version)
    - `bin/mcp-server` exists, mode 0755 (`stat -f "%Mp%Lp" bin/mcp-server` returns `0755`)
    - First line of `bin/mcp-server` is exactly `#!/usr/bin/env ruby`
    - All new .rb files contain `# frozen_string_literal: true` on line 2
    - `bundle exec rails runner "exit(defined?(McpServer::Server) && defined?(McpServer::Tools::BaseTool) ? 0 : 1)"` exits 0
    - Module name is exactly `McpServer` (camelCase per Zeitwerk default inflector — Pitfall 2): `grep -c "module McpServer" lib/mcp_server/server.rb` returns 1; `grep -c "module MCPServer" lib/mcp_server/server.rb` returns 0
    - server.rb defines `install_central_read_handler` with case-statement dispatch on `cc://workflow/scenarios/`, `cc://workflow/(roles|glossary)`, `cc://api/`: `grep -c "install_central_read_handler\|cc://workflow/scenarios\|cc://api/" lib/mcp_server/server.rb` returns >= 3
  </acceptance_criteria>
  <done>Server constant resolves via Zeitwerk; bin/mcp-server is executable; gem in Gemfile.lock; no MCPServer (uppercase) constants; central read-handler dispatcher in place.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Build CcSession with PHPSESSID cache, REAL login!, reauth_if_needed!, mock-mode failsafe</name>
  <files>lib/mcp_server/cc_session.rb, lib/mcp_server/tools/mock_client.rb, test/mcp_server/cc_session_test.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md (sections "Pitfall 4", "Pitfall 5", "Mock-Mode Strategy")
    - /Users/gullrich/DEV/carambus/carambus_api/app/services/region_cc/club_cloud_client.rb (lines 17-100 + lines 424-535 for class header + initializer + post)
    - /Users/gullrich/DEV/carambus/carambus_api/app/models/setting.rb (lines 104-340 — canonical `Setting.login_to_cc` flow)
    - /Users/gullrich/DEV/carambus/carambus_api/test/test_helper.rb (LocalProtectorTestOverride convention)
  </read_first>
  <behavior>
    - Test 1 (mock-mode-leak failsafe): When `Rails.env.production?` AND `ENV["CARAMBUS_MCP_MOCK"] == "1"`, `McpServer::CcSession.client_for(nil)` raises RuntimeError "Mock mode not allowed in production"
    - Test 2 (real-client construction): When CARAMBUS_MCP_MOCK unset, `client_for` returns a `RegionCc::ClubCloudClient` instance (verify class only, no network)
    - Test 3 (mock-client construction): When CARAMBUS_MCP_MOCK=1 in test/dev env, returns `McpServer::Tools::MockClient` instance, NOT real client
    - Test 4 (env-var-missing error): When CC_USERNAME unset (and not mock-mode), raises RuntimeError "CC_USERNAME env var not set"
    - Test 5 (TTL stub): `CcSession.cookie_expired?(Time.now - 35*60)` returns true; `(Time.now - 5*60)` returns false; `nil` returns true
    - Test 6 (mock-mode login!): With CARAMBUS_MCP_MOCK=1, `cookie` returns "MOCK_SESSION_ID" and sets session_started_at
    - Test 7 (reauth_if_needed! detects login redirect): `Nokogiri::HTML('<form action="/login.php">...')` triggers reauth (returns true)
    - Test 8 (reauth_if_needed! ignores normal pages): `Nokogiri::HTML('<table>...')` returns false
  </behavior>
  <action>
    Step 1 — Create `lib/mcp_server/cc_session.rb` with FULL login implementation (no placeholder):
    ```ruby
    # frozen_string_literal: true
    # CcSession — Wraps RegionCc::ClubCloudClient with in-memory PHPSESSID cache (D-10) +
    # lazy login + 30-min TTL + mock-mode failsafe (D-08) + transparent reauth on session expiry.
    #
    # Real CC login is delegated to the existing canonical flow in `Setting.login_to_cc`
    # (extend-before-build per CLAUDE.md skill). Phase 40 does NOT hand-roll Net::HTTP::Post
    # against /login.php — see revision 2026-05-07 Blocker 4.
    #
    # Single-threaded by design (MCP stdio is one-request-at-a-time per SDK README;
    # see RESEARCH Open Questions §2 RESOLVED — no Mutex needed in stdio mode).

    module McpServer
      class CcSession
        TTL_SECONDS = 30 * 60
        MOCK_FLAG = "CARAMBUS_MCP_MOCK"

        class << self
          attr_accessor :session_id, :session_started_at, :_client_override

          # Returns either a real RegionCc::ClubCloudClient or a McpServer::Tools::MockClient.
          # Failsafe: never returns mock in production env (D-08).
          def client_for(_server_context = nil)
            if mock_mode?
              raise RuntimeError, "Mock mode not allowed in production" if Rails.env.production?
              return McpServer::Tools::MockClient.new
            end

            return _client_override if _client_override

            base_url = Carambus.config.cc_base_url || "https://www.club-cloud.de"
            username = require_env!("CC_USERNAME")
            password = require_env!("CC_PASSWORD")
            RegionCc::ClubCloudClient.new(base_url: base_url, username: username, userpw: password)
          end

          # Lazy login: returns an active PHPSESSID, logging in if cache empty/expired.
          def cookie
            if session_id.nil? || cookie_expired?(session_started_at)
              login!
            end
            session_id
          end

          def cookie_expired?(started_at)
            return true if started_at.nil?
            Time.now - started_at > TTL_SECONDS
          end

          def reset!
            self.session_id = nil
            self.session_started_at = nil
          end

          def mock_mode?
            ENV[MOCK_FLAG] == "1"
          end

          # PUBLIC — Tools call this after each CC response to detect login-redirect (Pitfall 4 — D-10).
          # Returns true if a reauth happened; tool should retry its call.
          def reauth_if_needed!(doc)
            return false unless login_redirect?(doc)
            reset!
            cookie  # forces login!
            true
          end

          private

          # Real CC login: delegates to existing canonical Setting.login_to_cc flow (Blocker 4 fix).
          # Mock-mode short-circuits to a fixed token.
          def login!
            if mock_mode?
              self.session_id = "MOCK_SESSION_ID"
              self.session_started_at = Time.now
              return session_id
            end

            # Reuse the existing canonical CC login flow (Setting.login_to_cc).
            # That method:
            #   - Reads region context via RegionCcAction.get_base_opts_from_environment
            #   - Pulls credentials from Rails Credentials (per-environment encrypted) or RegionCc fallback
            #   - POSTs to /login/checkUser.php with MD5 password + call_police hidden field
            #   - Follows redirect, extracts PHPSESSID from Set-Cookie
            #   - Persists session_id via Setting.key_set_value("session_id", ...)
            #   - Returns the session_id string
            #
            # NOTE: ENV vars CC_USERNAME / CC_PASSWORD / CC_FED_ID are read indirectly — the canonical
            # flow uses Rails Credentials + region context. If a deployment requires ENV-only credentials,
            # set them in `RAILS_MASTER_KEY`-encrypted credentials.yml.enc rather than bypassing.
            self.session_id = Setting.login_to_cc
            self.session_started_at = Time.now
            session_id
          end

          def login_redirect?(doc)
            return false if doc.nil?
            return false unless doc.respond_to?(:css)
            doc.css("form[action*='login']").any?
          end

          def require_env!(key)
            ENV[key].presence || raise(RuntimeError, "#{key} env var not set")
          end
        end
      end
    end
    ```

    Step 2 — Create `lib/mcp_server/tools/mock_client.rb`:
    ```ruby
    # frozen_string_literal: true
    # MockClient — Drop-in replacement for RegionCc::ClubCloudClient when CARAMBUS_MCP_MOCK=1.
    # Hardcoded fixture responses; Plan 05 expands this with releaseMeldeliste fixture.

    module McpServer
      module Tools
        class MockClient
          attr_reader :calls

          def initialize
            @calls = []
          end

          def get(action, get_options = {}, opts = {})
            @calls << [:get, action, get_options, opts]
            [stub_response("OK"), Nokogiri::HTML("<html><body>MOCK GET #{action}</body></html>")]
          end

          def post(action, post_options = {}, opts = {})
            @calls << [:post, action, post_options, opts]
            # Honor armed-flag dry-run convention to mirror real client (Pitfall 5).
            return [nil, nil] if opts[:armed].blank? && writable?(action)
            [stub_response("OK"), Nokogiri::HTML("<html><body>MOCK POST #{action} OK</body></html>")]
          end

          def post_with_formdata(action, post_options = {}, opts = {})
            post(action, post_options, opts)
          end

          private

          def writable?(action)
            entry = RegionCc::ClubCloudClient::PATH_MAP[action]
            entry && entry[1] == false
          end

          def stub_response(message)
            Struct.new(:code, :message, :body).new("200", message, "")
          end
        end
      end
    end
    ```

    Step 3 — Create `test/mcp_server/cc_session_test.rb`:
    ```ruby
    # frozen_string_literal: true
    require "test_helper"

    class McpServer::CcSessionTest < ActiveSupport::TestCase
      setup do
        @prev_mock = ENV["CARAMBUS_MCP_MOCK"]
        @prev_user = ENV["CC_USERNAME"]
        @prev_pw   = ENV["CC_PASSWORD"]
        McpServer::CcSession.reset!
        McpServer::CcSession._client_override = nil
      end

      teardown do
        ENV["CARAMBUS_MCP_MOCK"] = @prev_mock
        ENV["CC_USERNAME"] = @prev_user
        ENV["CC_PASSWORD"] = @prev_pw
        McpServer::CcSession.reset!
      end

      test "production + mock-mode raises (failsafe per D-08)" do
        ENV["CARAMBUS_MCP_MOCK"] = "1"
        Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
          assert_raises(RuntimeError, /Mock mode not allowed in production/) do
            McpServer::CcSession.client_for
          end
        end
      end

      test "mock-mode in test env returns MockClient" do
        ENV["CARAMBUS_MCP_MOCK"] = "1"
        client = McpServer::CcSession.client_for
        assert_instance_of McpServer::Tools::MockClient, client
      end

      test "missing CC_USERNAME raises clear error" do
        ENV["CARAMBUS_MCP_MOCK"] = nil
        ENV["CC_USERNAME"] = nil
        assert_raises(RuntimeError, /CC_USERNAME env var not set/) do
          McpServer::CcSession.client_for
        end
      end

      test "TTL: cookie_expired? after 35 min" do
        assert McpServer::CcSession.cookie_expired?(Time.now - 35 * 60)
        refute McpServer::CcSession.cookie_expired?(Time.now - 5 * 60)
        assert McpServer::CcSession.cookie_expired?(nil)
      end

      test "mock-mode cookie returns MOCK_SESSION_ID and sets started_at" do
        ENV["CARAMBUS_MCP_MOCK"] = "1"
        token = McpServer::CcSession.cookie
        assert_equal "MOCK_SESSION_ID", token
        assert_in_delta Time.now.to_i, McpServer::CcSession.session_started_at.to_i, 5
      end

      test "reauth_if_needed! returns true when doc contains login-redirect form" do
        doc = Nokogiri::HTML('<html><body><form action="/login.php"><input name="username"></form></body></html>')
        ENV["CARAMBUS_MCP_MOCK"] = "1"
        assert McpServer::CcSession.reauth_if_needed!(doc)
      end

      test "reauth_if_needed! returns false on normal response" do
        doc = Nokogiri::HTML('<html><body><table>data</table></body></html>')
        ENV["CARAMBUS_MCP_MOCK"] = "1"
        refute McpServer::CcSession.reauth_if_needed!(doc)
      end

      test "TTL expiry triggers transparent re-login" do
        ENV["CARAMBUS_MCP_MOCK"] = "1"
        first = McpServer::CcSession.cookie
        McpServer::CcSession.session_started_at = Time.now - 31 * 60
        second = McpServer::CcSession.cookie
        assert_in_delta Time.now.to_i, McpServer::CcSession.session_started_at.to_i, 5
        assert_equal first, second  # mock token is stable
      end
    end
    ```

    Step 4 — Run the test suite:
    ```
    bin/rails test test/mcp_server/cc_session_test.rb
    ```
    All 8 tests must pass.
  </action>
  <verify>
    <automated>bin/rails test test/mcp_server/cc_session_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - `lib/mcp_server/cc_session.rb` exists; `grep -c "frozen_string_literal: true" lib/mcp_server/cc_session.rb` returns 1
    - `lib/mcp_server/tools/mock_client.rb` exists with `class MockClient` inside `module McpServer; module Tools`
    - `grep "raise RuntimeError, .Mock mode not allowed in production." lib/mcp_server/cc_session.rb` returns 1 line (D-08 failsafe present)
    - `grep "TTL_SECONDS = 30 \\* 60" lib/mcp_server/cc_session.rb` returns 1 line (D-10 TTL)
    - **No placeholder login**: `grep -c "CC_PRESET_SESSION_ID" lib/mcp_server/cc_session.rb` returns 0 (Warning 7 fix)
    - **No hand-rolled Net::HTTP::Post in cc_session.rb**: `grep -c "Net::HTTP::Post.new\|/login\\.php" lib/mcp_server/cc_session.rb` returns 0 (Blocker 4 fix — delegates to Setting.login_to_cc)
    - **Setting.login_to_cc is called**: `grep -c "Setting\\.login_to_cc" lib/mcp_server/cc_session.rb` returns 1
    - **reauth_if_needed! is public**: `grep -c "def reauth_if_needed!" lib/mcp_server/cc_session.rb` returns 1
    - `bin/rails test test/mcp_server/cc_session_test.rb` passes (8 runs, 0 failures, 0 errors)
    - `MockClient#post` honors `opts[:armed].blank?` for write actions: `grep "opts\\[:armed\\]" lib/mcp_server/tools/mock_client.rb` returns 1 line
  </acceptance_criteria>
  <done>CcSession + MockClient compiled with FULL real-login implementation (Setting.login_to_cc reuse — no placeholder, no hand-rolled Net::HTTP); reauth_if_needed! public; mock-mode failsafe verified by 8 passing tests; TTL constant in place. Plan 05 only adds write-tool semantics on top, no further CcSession changes needed.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Server smoke test + SDK-API smoke probe (locks tool_name DSL + Response shape)</name>
  <files>test/mcp_server/server_smoke_test.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/server.rb (just-written file)
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md (Example 1 minimal stdio server, "SDK API Findings" section just added in revision)
  </read_first>
  <behavior>
    - Test 1: McpServer::Server.build returns an MCP::Server instance (not nil)
    - Test 2: built server's name is "carambus_clubcloud" (matches D-18 acceptance story expectation)
    - Test 3: built server before Wave-2 plans land has empty tools and resources arrays
    - Test 4 (smoke): no STDOUT pollution during build (capture stdout, assert empty)
    - Test 5 (SDK-API smoke probe — Warning 8): MCP::Tool DSL methods (`tool_name`, `description`, `input_schema`, `annotations`) are defined as class-level macros and respond
    - Test 6 (SDK-API smoke probe): MCP::Tool::Response.new(content, error: bool) works; instance responds to `#error` and `#content`
  </behavior>
  <action>
    Create `test/mcp_server/server_smoke_test.rb`:
    ```ruby
    # frozen_string_literal: true
    require "test_helper"

    class McpServer::ServerSmokeTest < ActiveSupport::TestCase
      test "build returns an MCP::Server" do
        server = McpServer::Server.build
        assert_instance_of MCP::Server, server
      end

      test "server name is carambus_clubcloud" do
        server = McpServer::Server.build
        assert_equal "carambus_clubcloud", server.name
      end

      test "before Wave 2 plans land, build does not raise (empty registry safe)" do
        assert_nothing_raised { McpServer::Server.build }
      end

      test "no STDOUT pollution during server build (Pitfall 1)" do
        out, _err = capture_io { McpServer::Server.build }
        assert_equal "", out, "Server build wrote to STDOUT — would corrupt JSON-RPC channel"
      end

      # SDK-API smoke probe (Warning 8 — locks the API contracts that Plans 04 + 05 rely on).
      # Findings recorded in Plan 01 SUMMARY for Plans 04/05 reference.
      test "SDK API smoke — MCP::Tool DSL macros exist (tool_name, description, input_schema, annotations)" do
        # MCP::Tool subclasses use these DSL macros as class-level methods. We verify they exist
        # by introspecting on a throwaway subclass.
        klass = Class.new(MCP::Tool)
        %i[tool_name description input_schema annotations].each do |dsl_method|
          assert klass.respond_to?(dsl_method),
                 "MCP::Tool subclasses must respond to ##{dsl_method} (DSL macro). " \
                 "If this fails, SDK 0.15 has a different API and Plans 04+05 must adapt."
        end
      end

      test "SDK API smoke — MCP::Tool::Response exposes #error and #content" do
        response = MCP::Tool::Response.new([{ type: "text", text: "hello" }], error: false)
        assert_respond_to response, :error
        assert_respond_to response, :content
        refute response.error
        assert_equal "hello", response.content.first[:text]
      end
    end
    ```

    Run `bin/rails test test/mcp_server/server_smoke_test.rb` — all 6 must pass.

    If Tests 5 or 6 fail, the SDK 0.15 has a different API than RESEARCH inferred. In that case:
    1. Adjust `BaseTool.error` / `BaseTool.text` helpers (Task 1) to match actual SDK shape
    2. Update SDK-API findings in `40-RESEARCH.md` "SDK API Findings" section
    3. Re-run smoke test until both pass — Plans 04 + 05 depend on these contracts
  </action>
  <verify>
    <automated>bin/rails test test/mcp_server/server_smoke_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - `test/mcp_server/server_smoke_test.rb` exists
    - All 6 tests pass: `bin/rails test test/mcp_server/server_smoke_test.rb` reports `6 runs, 6 assertions+ , 0 failures, 0 errors`
    - Test 4 (STDOUT-pollution check) is present: `grep "capture_io" test/mcp_server/server_smoke_test.rb` returns 1 line
    - SDK-API smoke probes (Tests 5+6) are present: `grep -c "MCP::Tool DSL macros\|MCP::Tool::Response exposes" test/mcp_server/server_smoke_test.rb` returns 2 lines
    - SDK API contracts locked: any future SDK upgrade that breaks `tool_name`/`description`/`input_schema`/`annotations` DSL or `Response#error`/`#content` accessors will fail Tests 5 or 6 first, before Plan 04/05 unit tests
  </acceptance_criteria>
  <done>Smoke test passes; foundation is bootable; SDK-API contracts locked for Plans 04+05; Plans 02-05 unblocked.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| MCP-client → bin/mcp-server | JSON-RPC over stdio; client controls input fully |
| bin/mcp-server → CC-Backend | HTTPS (existing transport via RegionCc::ClubCloudClient) |
| ENV vars → process | OS-level; client config (`mcp.json`) supplies CC_USERNAME / CC_PASSWORD / CARAMBUS_MCP_MOCK |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-40-01-01 | Information Disclosure | bin/mcp-server STDOUT | mitigate | `Rails.logger = Logger.new($stderr)` set immediately after Rails boot in `lib/mcp_server/transport/boot.rb`; Pitfall 1 — STDOUT MUST stay JSON-RPC-clean |
| T-40-01-02 | Tampering | Mock-Mode-Leak in production | mitigate | `McpServer::CcSession#client_for` raises RuntimeError when `Rails.env.production?` AND `CARAMBUS_MCP_MOCK == "1"` (Test 1 of Task 2); D-08 failsafe |
| T-40-01-03 | Spoofing | PHPSESSID in-memory | accept | Process-lifetime = session-lifetime; no disk persist; D-10 explicit decision |
| T-40-01-04 | Denial of Service | Boot-timeout (Rails-Boot ~3-5s) | accept | Documented in setup-doc (Plan 06) — recommend `MCP_TIMEOUT=15000`; SDK-level concern, not actionable in this plan |
| T-40-01-05 | Information Disclosure | CC_PASSWORD in process env / logs | mitigate | Audit grep `grep -ni "password\|cc_password" lib/mcp_server/` must show only documented refs (e.g. `require_env!("CC_PASSWORD")`); never log the value |
| T-40-01-06 | Tampering | Zeitwerk constant-mismatch crashes server boot | mitigate | Strict `McpServer` (camelCase, NOT `MCPServer`) per Pitfall 2; smoke test asserts `defined?(McpServer::Server)` returns truthy |
| T-40-01-07 | Tampering | Hand-rolled login bypasses canonical Setting.login_to_cc protections | mitigate | Plan 01 Task 2 explicitly delegates to Setting.login_to_cc — no Net::HTTP::Post in cc_session.rb (Blocker 4 fix); grep audit returns 0 |
</threat_model>

<verification>
- `Gemfile` updated, `Gemfile.lock` regenerated, `bundle list mcp` shows 0.15.x
- `bin/mcp-server` exists and is executable
- `lib/mcp_server/{server,cc_session,transport/boot,tools/base_tool,tools/mock_client}.rb` all present with `frozen_string_literal: true`
- All Zeitwerk-loaded constants resolve: `bundle exec rails runner "puts [McpServer::Server, McpServer::CcSession, McpServer::Tools::BaseTool, McpServer::Tools::MockClient, McpServer::Transport::Boot].map(&:name).inspect"`
- Tests pass: `bin/rails test test/mcp_server/server_smoke_test.rb test/mcp_server/cc_session_test.rb` (6 + 8 = 14 runs)
- No STDOUT-pollution: covered by Test 4 in server_smoke_test
- SDK-API contracts locked: Tests 5+6 in server_smoke_test pass
- No Tools written yet (collect_tools returns empty array) — Plans 02-05 will populate
- Central read-handler dispatcher in server.rb (per Blockers 2+3): `grep -c "install_central_read_handler" lib/mcp_server/server.rb` returns 2 (def + invocation)
</verification>

<success_criteria>
- `bin/mcp-server` is mode 0755 and contains `require_relative "../config/environment"` + `McpServer::Transport::Boot.run`
- `lib/mcp_server/server.rb` defines `McpServer::Server.build` returning an `MCP::Server` instance with `name: "carambus_clubcloud"` AND a single central `resources_read_handler` dispatcher (Blockers 2+3)
- `lib/mcp_server/cc_session.rb` raises in production + mock-mode (D-08), caches PHPSESSID with 30-min TTL (D-10), AND fully implements login! via Setting.login_to_cc (Blocker 4 + Warning 7 — no placeholder)
- `lib/mcp_server/cc_session.rb` exposes public `reauth_if_needed!` for tools (used by Plan 05 write tool retry)
- All 14 tests pass (8 cc_session + 6 server_smoke)
- `grep -rn '\bputs\b\|\bprint\b' lib/mcp_server/ bin/mcp-server` returns ZERO results from production code (Rails.logger only)
- SDK-API smoke probe results recorded in 40-01-SUMMARY.md for Plans 04+05 reference
</success_criteria>

<output>
After completion, create `.planning/phases/40-mcp-server-clubcloud/40-01-SUMMARY.md` documenting:
- Gem version installed (verify against research-published 0.15.x)
- Bootsnap-warm vs cold boot time measured (informational — feeds Plan 06 setup-doc MCP_TIMEOUT recommendation)
- **SDK-API smoke probe findings** (Warning 8): exact method signatures of `tool_name`/`description`/`input_schema`/`annotations` DSL + `MCP::Tool::Response.new` arity + accessor names — Plans 04+05 use these as fixed contracts
- Any deviation from RESEARCH §"Recommended Project Structure"
- Confirmation that `Setting.login_to_cc` is the canonical CC login flow (Blocker 4 + Warning 7 audit)
</output>
</content>
</invoke>