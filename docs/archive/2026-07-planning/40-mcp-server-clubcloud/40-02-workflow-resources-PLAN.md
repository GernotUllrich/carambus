---
phase: 40-mcp-server-clubcloud
plan: 02
type: execute
wave: 2
depends_on: ["40-01"]
files_modified:
  - docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md
  - docs/managers/clubcloud-scenarios/player-anlegen.de.md
  - docs/managers/clubcloud-scenarios/endrangliste-eintragen.de.md
  - docs/managers/clubcloud-scenarios/cc-roles.de.md
  - docs/managers/clubcloud-scenarios/cc-glossary.de.md
  - lib/mcp_server/resources/workflow_scenarios.rb
  - lib/mcp_server/resources/workflow_meta.rb
  - test/mcp_server/resources/workflow_scenarios_test.rb
  - test/mcp_server/resources/workflow_meta_test.rb
autonomous: true
requirements: [D-01, D-05, D-06, D-07, D-17, D-18]
requirements_addressed: [D-01, D-05, D-06, D-07, D-17, D-18]
user_setup: []

must_haves:
  truths:
    - "5 workflow markdown files exist under `docs/managers/clubcloud-scenarios/` in DE (D-05)"
    - "All 5 files contain content extracted from `.planning/clubcloud-admin-appendix-DRAFT.md` with `[SME-CONFIRM]` markers preserved verbatim (per CONTEXT.md `<specifics>`)"
    - "Exactly 4 or 5 files contain `[SME-CONFIRM]` markers — verified by `grep -l '\\[SME-CONFIRM\\]' docs/managers/clubcloud-scenarios/*.de.md | wc -l` returns 4 or 5 (per revision Info 12)"
    - "MCP server, when booted, exposes 5 resources at exactly the URIs `cc://workflow/scenarios/teilnehmerliste-finalisieren`, `cc://workflow/scenarios/player-anlegen`, `cc://workflow/scenarios/endrangliste-eintragen`, `cc://workflow/roles`, `cc://workflow/glossary` (D-06, D-07)"
    - "Reading the URI `cc://workflow/scenarios/teilnehmerliste-finalisieren` (via Plan 01's central dispatcher) returns the markdown content of `docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md` (D-18 acceptance story foundation)"
    - "Tool descriptions / file names use English slugs but resource content (markdown) is German per the D-05/D-20 split"
    - "Plan 02 does NOT register its own resources_read_handler — Plan 01's central dispatcher handles routing (per revision Blockers 2+3, Wave-2 conflict-free with Plan 03)"
  artifacts:
    - path: "docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md"
      provides: "Scenario 1 walkthrough — Teilnehmerliste finalisieren"
      min_lines: 30
    - path: "docs/managers/clubcloud-scenarios/player-anlegen.de.md"
      provides: "Scenario 2 walkthrough — Player nicht in CC-DB"
      min_lines: 25
    - path: "docs/managers/clubcloud-scenarios/endrangliste-eintragen.de.md"
      provides: "Scenario 3 walkthrough — Endrangliste in CC"
      min_lines: 20
    - path: "docs/managers/clubcloud-scenarios/cc-roles.de.md"
      provides: "Meta-Resource: Rollen-Modell-Tabelle"
      min_lines: 15
    - path: "docs/managers/clubcloud-scenarios/cc-glossary.de.md"
      provides: "Meta-Resource: Glossar (Sportwart-Ebenen, Branch, Meldeliste, etc.)"
      min_lines: 15
    - path: "lib/mcp_server/resources/workflow_scenarios.rb"
      provides: "MCP::Resource registrations for cc://workflow/scenarios/* + .read(slug:) class method (NO read-handler registration — Plan 01 central dispatcher handles that)"
      min_lines: 50
    - path: "lib/mcp_server/resources/workflow_meta.rb"
      provides: "MCP::Resource registrations for cc://workflow/roles + cc://workflow/glossary + .read(key:) class method"
      min_lines: 35
  key_links:
    - from: "lib/mcp_server/resources/workflow_scenarios.rb"
      to: "docs/managers/clubcloud-scenarios/*.de.md"
      via: "Pathname.read on URI->slug map"
      pattern: "Rails\\.root\\.join.*clubcloud-scenarios"
    - from: "lib/mcp_server/server.rb (Plan 01 central dispatcher)"
      to: "WorkflowScenarios.read / WorkflowMeta.read"
      via: "case-statement URI dispatch in install_central_read_handler"
      pattern: "WorkflowScenarios\\.read\\(slug:"
---

<objective>
Build the German workflow-documentation surface — 5 MCP resources backed by 5
markdown files extracted from `.planning/clubcloud-admin-appendix-DRAFT.md`.

This is the FIRST half of the D-18 acceptance story: "Als Turnierleiter frage ich
'wie finalisiere ich die Teilnehmerliste', bekomme die Anleitung aus
`cc://workflow/scenarios/teilnehmerliste-finalisieren`". The Read-Lookup half
lives in Plan 04.

**Revision 2026-05-07 changes (Blockers 2+3):**
Plan 02 no longer calls `server.resources_read_handler`. Plan 01's `Server.install_central_read_handler`
dispatches `cc://workflow/scenarios/{slug}` and `cc://workflow/(roles|glossary)` URIs to
`WorkflowScenarios.read(slug:)` / `WorkflowMeta.read(key:)`. Plan 02 only owns the data
(markdown files), the resource list (`.all`), and the read class methods.

Purpose: DE-speaking Turnierleiter (Audience b per D-17) can ask Claude Desktop
"wie finalisiere ich die Teilnehmerliste" and get the SME-source documentation
back without leaving the chat.

Output: 5 markdown files under `docs/managers/clubcloud-scenarios/` (sourced from
the existing DRAFT, with `[SME-CONFIRM]` markers preserved per spec) + 2 Ruby
registry classes that auto-register with `McpServer::Server` via Plan 01's
constant-lookup pattern.
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
@.planning/clubcloud-admin-appendix-DRAFT.md

@lib/mcp_server/server.rb

<interfaces>
<!-- Plan 01 contracts that this plan plugs into -->

From lib/mcp_server/server.rb (Plan 01):
```ruby
# Server.collect_resources iterates known constants and concatenates their .all arrays:
def self.collect_resources
  collected = []
  [..., "McpServer::Resources::WorkflowScenarios", "McpServer::Resources::WorkflowMeta", ...].each do |name|
    klass = name.constantize
    collected.concat(klass.all) if klass.respond_to?(:all)
  end
  collected
end

# Plan 01 owns the SINGLE central dispatcher — Plan 02 does NOT call resources_read_handler:
def self.install_central_read_handler(server)
  server.resources_read_handler do |params|
    uri = params[:uri].to_s
    case uri
    when %r{\Acc://workflow/scenarios/(?<slug>[\w-]+)\z}
      content = McpServer::Resources::WorkflowScenarios.read(slug: $~[:slug])
      [{ uri: uri, mimeType: "text/markdown", text: content }]
    when %r{\Acc://workflow/(?<key>roles|glossary)\z}
      content = McpServer::Resources::WorkflowMeta.read(key: $~[:key])
      [{ uri: uri, mimeType: "text/markdown", text: content }]
    # ...
    end
  end
end
```

Plan 02 must therefore expose:
  - `WorkflowScenarios.all` → Array<MCP::Resource>
  - `WorkflowScenarios.read(slug:)` → String (markdown content)
  - `WorkflowMeta.all` → Array<MCP::Resource>
  - `WorkflowMeta.read(key:)` → String (markdown content)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Extract and author the 5 DE markdown scenario/meta files</name>
  <files>docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md, docs/managers/clubcloud-scenarios/player-anlegen.de.md, docs/managers/clubcloud-scenarios/endrangliste-eintragen.de.md, docs/managers/clubcloud-scenarios/cc-roles.de.md, docs/managers/clubcloud-scenarios/cc-glossary.de.md</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/clubcloud-admin-appendix-DRAFT.md (full file — source of truth for all 5 outputs)
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md (section "Workflow Appendix Split (D-07 Empfehlung)" — table maps scenario → slug)
  </read_first>
  <action>
    Step 1 — Create directory: `mkdir -p docs/managers/clubcloud-scenarios/` (parent `docs/managers/` already exists).

    Step 2 — Author 5 files. Use the slug-to-section mapping from RESEARCH §"Workflow Appendix Split":

    File `teilnehmerliste-finalisieren.de.md`:
    - Source: `.planning/clubcloud-admin-appendix-DRAFT.md` section "Scenario 1: Teilnehmerliste needs finalization in CC"
    - Title: `# Teilnehmerliste in ClubCloud finalisieren`
    - Body: extract verbatim including BOTH `[SME-CONFIRM]` markers (mild ones — Fehlertext, UI-Wording per RESEARCH table) — DO NOT translate, DO NOT remove markers
    - Append section "## Carambus-Sicht" with: "Wenn der Carambus-Server das MCP-Tool `cc_lookup_teilnehmerliste` (Plan 04) erreicht, prüft es Status der Liste. Das Write-Tool `cc_finalize_teilnehmerliste` (Plan 05) führt die Finalisierung über `releaseMeldeliste`-Action aus."
    - Last line: `*Quelle: .planning/clubcloud-admin-appendix-DRAFT.md (Phase 36c, 2026-04-14). [SME-CONFIRM]-Marker bleiben unaufgelöst — Resolution in einem zukünftigen Doc-Promotion-Workflow.*`

    File `player-anlegen.de.md`:
    - Source: `.planning/clubcloud-admin-appendix-DRAFT.md` section "Scenario 2: Player nicht in CC-DB" (oder ähnlich benannt)
    - Title: `# Spieler in ClubCloud anlegen`
    - Body: extract verbatim, preserve all 4 `[SME-CONFIRM]` markers (Guest-Mechanik, Preflight)
    - Append "## Carambus-Sicht" mentioning that `cc_search_player` (Plan 04 read tool) and a future `cc_add_player` write-tool (deferred to Phase 40.1) form the workflow.

    File `endrangliste-eintragen.de.md`:
    - Source: `.planning/clubcloud-admin-appendix-DRAFT.md` section "Scenario 3: Endrangliste in CC" (oder ähnlich)
    - Title: `# Endrangliste in ClubCloud eintragen`
    - Body: extract verbatim, preserve 1 `[SME-CONFIRM]` marker (mild — automatische Berechnung ja/nein)
    - Append "## Carambus-Sicht" mentioning that automatic calculation lives in v7.2 ClubCloud Integration milestone (deferred per CONTEXT.md `<deferred>`).

    File `cc-roles.de.md`:
    - Source: `.planning/clubcloud-admin-appendix-DRAFT.md` section "The ClubCloud role model"
    - Title: `# ClubCloud-Rollenmodell`
    - Body: copy the Markdown role table verbatim (Club-Sportwart / Region-Sportwart / Turnierleiter / Verbands-Sportwart / Member), preserve `[SME-CONFIRM]` marker on the Turnierleiter row
    - Closing paragraph: "Diese Rollen sind ClubCloud-side, nicht Carambus-side. Carambus-Benutzerrollen (z.B. `club_admin`) sind separat. Das MCP-Write-Tool `cc_finalize_teilnehmerliste` setzt mindestens Club-Sportwart-Rechte voraus; bei fehlender Berechtigung antwortet CC mit einem Fehler, den der Server per D-11 trust-CC-and-parse-error-Pattern als strukturierten MCP-Fehler weiterreicht."

    File `cc-glossary.de.md`:
    - Title: `# ClubCloud-Glossar`
    - Body: extract glossary terms from across `.planning/clubcloud-admin-appendix-DRAFT.md` (search for "Branch", "Meldeliste", "Teilnehmerliste", "Spielbericht", "Sportwart-Ebenen", "Endrangliste", "Spielerdatenbank") into a `## Begriffe` section with one definition per term. If terms are not explicitly defined in the DRAFT, write a 1-2-line definition each based on the context they appear in, and add `[SME-CONFIRM]` to flag the inferred definition.

    Each file MUST start with the exact 4-line header (variable parts in `{}`):
    ```
    # {Title}

    > **Status:** Aus `.planning/clubcloud-admin-appendix-DRAFT.md` (Phase 36c) extrahiert. `[SME-CONFIRM]`-Marker bleiben verbatim — Auflösung in einem zukünftigen Doc-Promotion-Workflow.

    ```
  </action>
  <verify>
    <automated>test -f docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md && test -f docs/managers/clubcloud-scenarios/player-anlegen.de.md && test -f docs/managers/clubcloud-scenarios/endrangliste-eintragen.de.md && test -f docs/managers/clubcloud-scenarios/cc-roles.de.md && test -f docs/managers/clubcloud-scenarios/cc-glossary.de.md && [ "$(grep -l "\[SME-CONFIRM\]" docs/managers/clubcloud-scenarios/*.de.md | wc -l | tr -d ' ')" -ge 4 ]</automated>
  </verify>
  <acceptance_criteria>
    - All 5 `.de.md` files exist under `docs/managers/clubcloud-scenarios/`
    - Each file starts with `# ` (Markdown H1) on line 1
    - **Per revision Info 12 — exactly 4 or 5 files contain `[SME-CONFIRM]`**: `grep -l "\\[SME-CONFIRM\\]" docs/managers/clubcloud-scenarios/*.de.md | wc -l` returns 4 OR 5 (4 = scenarios + roles; 5 if glossary inferred-definitions also flagged). Concrete grep assertion locked: scenarios 1-3 + cc-roles MUST be in the 4; cc-glossary MAY be in the 5.
    - All 5 files contain DE content: `grep -lE "(der|die|das) " docs/managers/clubcloud-scenarios/*.de.md | wc -l` returns 5
    - `teilnehmerliste-finalisieren.de.md` mentions `cc_finalize_teilnehmerliste` in the "Carambus-Sicht" section: `grep -c "cc_finalize_teilnehmerliste" docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md` returns >= 1
    - `cc-roles.de.md` mentions D-11 / "trust-CC-and-parse-error" pattern: `grep -c "trust-CC-and-parse-error\|D-11" docs/managers/clubcloud-scenarios/cc-roles.de.md` returns >= 1
  </acceptance_criteria>
  <done>5 DE markdown files exist with verbatim DRAFT content + Carambus-side cross-references; SME-markers preserved (4 or 5 files); all in DE per D-05.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Implement WorkflowScenarios + WorkflowMeta resource classes (.all + .read, NO handler registration)</name>
  <files>lib/mcp_server/resources/workflow_scenarios.rb, lib/mcp_server/resources/workflow_meta.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/server.rb (Plan 01 — verify central dispatcher calls `WorkflowScenarios.read(slug:)` and `WorkflowMeta.read(key:)`)
    - /Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md (Pattern 3 + Example 1 + section "Workflow Appendix Split")
  </read_first>
  <behavior>
    - `WorkflowScenarios.all` returns Array<MCP::Resource> with exactly 3 resources (URIs ending `/teilnehmerliste-finalisieren`, `/player-anlegen`, `/endrangliste-eintragen`)
    - `WorkflowMeta.all` returns Array<MCP::Resource> with exactly 2 resources (URIs `cc://workflow/roles`, `cc://workflow/glossary`)
    - Each resource has `mime_type: "text/markdown"` and `name` matching slug (D-06)
    - `WorkflowScenarios.read(slug:)` reads the corresponding `.de.md` from disk and returns its String content; unknown slug → not-found body string (no exception)
    - `WorkflowMeta.read(key:)` reads roles/glossary `.de.md` from disk and returns String content; unknown key → not-found body string
    - **NEITHER class registers a `resources_read_handler`** (Plan 01 owns the central dispatcher per Blockers 2+3)
  </behavior>
  <action>
    Step 1 — Create `lib/mcp_server/resources/workflow_scenarios.rb`:
    ```ruby
    # frozen_string_literal: true
    # WorkflowScenarios — Exposes ClubCloud-Workflow-Scenarios als MCP-Resources unter
    # cc://workflow/scenarios/{slug} (D-06, D-07). Content ist DE (D-05).
    #
    # IMPORTANT (revision 2026-05-07 Blockers 2+3): Plan 01's `Server.install_central_read_handler`
    # owns the resources_read_handler. This class only exposes `.all` (resource list) + `.read(slug:)`
    # (content lookup). NO `install_read_handler` method here — that would conflict with Plan 03 in Wave 2.

    module McpServer
      module Resources
        class WorkflowScenarios
          # Per D-07 + RESEARCH §"Workflow Appendix Split (D-07 Empfehlung)":
          # 3 von 4 Scenarios shippen in Phase 40 (Upload-Failure-Recovery deferred).
          SCENARIOS = {
            "teilnehmerliste-finalisieren" => "Teilnehmerliste in ClubCloud finalisieren",
            "player-anlegen"               => "Spieler in ClubCloud anlegen",
            "endrangliste-eintragen"       => "Endrangliste in ClubCloud eintragen"
          }.freeze

          DOCS_BASE = "docs/managers/clubcloud-scenarios"

          def self.all
            SCENARIOS.map do |slug, title|
              MCP::Resource.new(
                uri: "cc://workflow/scenarios/#{slug}",
                name: "workflow-#{slug}",
                title: title,
                description: "ClubCloud-Workflow-Anleitung (DE) — Scenario: #{title}",
                mime_type: "text/markdown"
              )
            end
          end

          # Called by Plan 01's central read-handler dispatcher.
          # Returns String (markdown content) or not-found body for unknown slug.
          def self.read(slug:)
            return "# Scenario nicht gefunden\n\nUnknown slug: #{slug}" unless SCENARIOS.key?(slug)
            path = Rails.root.join(DOCS_BASE, "#{slug}.de.md")
            return "# Datei fehlt\n\nExpected at: #{path}" unless path.exist?
            path.read
          end
        end
      end
    end
    ```

    Step 2 — Create `lib/mcp_server/resources/workflow_meta.rb`:
    ```ruby
    # frozen_string_literal: true
    # WorkflowMeta — Meta-Resources cc://workflow/roles + cc://workflow/glossary (D-07).
    # Plan 01 central dispatcher owns the read_handler — this class only provides .all + .read(key:).

    module McpServer
      module Resources
        class WorkflowMeta
          META = {
            "roles"    => { title: "ClubCloud-Rollenmodell", file: "cc-roles.de.md" },
            "glossary" => { title: "ClubCloud-Glossar", file: "cc-glossary.de.md" }
          }.freeze

          DOCS_BASE = "docs/managers/clubcloud-scenarios"

          def self.all
            META.map do |key, meta|
              MCP::Resource.new(
                uri: "cc://workflow/#{key}",
                name: "workflow-#{key}",
                title: meta[:title],
                description: "ClubCloud-Meta (DE): #{meta[:title]}",
                mime_type: "text/markdown"
              )
            end
          end

          # Called by Plan 01's central read-handler dispatcher.
          def self.read(key:)
            meta = META[key]
            return "# Unknown meta key\n\nKey: #{key}" unless meta
            path = Rails.root.join(DOCS_BASE, meta[:file])
            return "# Datei fehlt\n\nExpected at: #{path}" unless path.exist?
            path.read
          end
        end
      end
    end
    ```
  </action>
  <verify>
    <automated>bundle exec rails runner "puts McpServer::Resources::WorkflowScenarios.all.map(&:uri).inspect; puts McpServer::Resources::WorkflowMeta.all.map(&:uri).inspect"</automated>
  </verify>
  <acceptance_criteria>
    - `lib/mcp_server/resources/workflow_scenarios.rb` exists with `frozen_string_literal: true` on line 2
    - `lib/mcp_server/resources/workflow_meta.rb` exists with `frozen_string_literal: true` on line 2
    - `bundle exec rails runner "puts McpServer::Resources::WorkflowScenarios.all.size"` outputs `3`
    - `bundle exec rails runner "puts McpServer::Resources::WorkflowMeta.all.size"` outputs `2`
    - URIs are exactly `cc://workflow/scenarios/{slug}` and `cc://workflow/{key}` (D-06)
    - All 5 resources have `mime_type` set to `"text/markdown"`
    - `.read(slug:)` reads from disk: `bundle exec rails runner "puts McpServer::Resources::WorkflowScenarios.read(slug: 'teilnehmerliste-finalisieren').lines.first"` outputs the first line of the DE markdown file (a `# ` heading)
    - **No install_read_handler method** (per Blockers 2+3): `grep -c "install_read_handler\|resources_read_handler" lib/mcp_server/resources/workflow_scenarios.rb lib/mcp_server/resources/workflow_meta.rb` returns 0
    - **No conditional refactor instruction in code/comments** (per Blocker 2): `grep -c "if SDK only allows one handler\|refactor.*server\\.rb" lib/mcp_server/resources/workflow_scenarios.rb lib/mcp_server/resources/workflow_meta.rb` returns 0
  </acceptance_criteria>
  <done>2 resource classes compiled; .all returns 3+2 MCP::Resource instances; URIs match D-06; .read(slug:|key:) delegates to disk per D-07; NO read-handler registration (Blockers 2+3 satisfied — Wave 2 conflict-free).</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Resource registration + read tests</name>
  <files>test/mcp_server/resources/workflow_scenarios_test.rb, test/mcp_server/resources/workflow_meta_test.rb</files>
  <read_first>
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/resources/workflow_scenarios.rb (just-written)
    - /Users/gullrich/DEV/carambus/carambus_api/lib/mcp_server/resources/workflow_meta.rb (just-written)
    - /Users/gullrich/DEV/carambus/carambus_api/test/mcp_server/server_smoke_test.rb (Plan 01 reference for test style)
  </read_first>
  <behavior>
    - WorkflowScenarios test 1: `.all` returns 3 MCP::Resource instances
    - WorkflowScenarios test 2: each URI matches `%r{\Acc://workflow/scenarios/[\w-]+\z}`
    - WorkflowScenarios test 3: `.read(slug: "teilnehmerliste-finalisieren")` returns content starting with `# Teilnehmerliste`
    - WorkflowScenarios test 4: `.read(slug: "nonexistent-slug")` returns the not-found body (NO exception)
    - WorkflowMeta test 1: `.all` returns 2 MCP::Resource instances with URIs `cc://workflow/roles` and `cc://workflow/glossary`
    - WorkflowMeta test 2: `.read(key: "roles")` returns content starting with `# ClubCloud-Rollenmodell` (or matches H1)
    - Server-integration test: `McpServer::Server.build.resources` includes all 5 resources after Plan 02 lands
  </behavior>
  <action>
    Step 1 — Create `test/mcp_server/resources/workflow_scenarios_test.rb`:
    ```ruby
    # frozen_string_literal: true
    require "test_helper"

    class McpServer::Resources::WorkflowScenariosTest < ActiveSupport::TestCase
      test "all returns 3 MCP::Resource instances" do
        resources = McpServer::Resources::WorkflowScenarios.all
        assert_equal 3, resources.size
        assert resources.all? { |r| r.is_a?(MCP::Resource) }
      end

      test "all URIs match cc://workflow/scenarios/{slug}" do
        McpServer::Resources::WorkflowScenarios.all.each do |r|
          assert_match %r{\Acc://workflow/scenarios/[\w-]+\z}, r.uri
        end
      end

      test "all resources have mime_type text/markdown" do
        assert McpServer::Resources::WorkflowScenarios.all.all? { |r| r.mime_type == "text/markdown" }
      end

      test "read(slug:) returns content from disk for valid slug" do
        content = McpServer::Resources::WorkflowScenarios.read(slug: "teilnehmerliste-finalisieren")
        assert_match(/\A# /, content)  # starts with H1
        refute_match(/Datei fehlt/, content)
      end

      test "read(slug:) returns not-found body for unknown slug (no raise)" do
        content = McpServer::Resources::WorkflowScenarios.read(slug: "nonexistent")
        assert_match(/Scenario nicht gefunden/, content)
      end

      test "server.build includes WorkflowScenarios in resource list" do
        server = McpServer::Server.build
        scenario_uris = server.resources.select { |r| r.uri.start_with?("cc://workflow/scenarios/") }.map(&:uri)
        assert_equal 3, scenario_uris.size
        assert_includes scenario_uris, "cc://workflow/scenarios/teilnehmerliste-finalisieren"
      end
    end
    ```

    Step 2 — Create `test/mcp_server/resources/workflow_meta_test.rb`:
    ```ruby
    # frozen_string_literal: true
    require "test_helper"

    class McpServer::Resources::WorkflowMetaTest < ActiveSupport::TestCase
      test "all returns 2 MCP::Resource instances with cc://workflow/{roles|glossary} URIs" do
        resources = McpServer::Resources::WorkflowMeta.all
        assert_equal 2, resources.size
        uris = resources.map(&:uri).sort
        assert_equal ["cc://workflow/glossary", "cc://workflow/roles"], uris
      end

      test "all resources are mime_type text/markdown" do
        assert McpServer::Resources::WorkflowMeta.all.all? { |r| r.mime_type == "text/markdown" }
      end

      test "read(key: 'roles') returns markdown starting with H1" do
        content = McpServer::Resources::WorkflowMeta.read(key: "roles")
        assert_match(/\A# /, content)
        refute_match(/Datei fehlt/, content)
      end

      test "read(key: unknown) returns not-found body without raise" do
        content = McpServer::Resources::WorkflowMeta.read(key: "nope")
        assert_match(/Unknown meta key/, content)
      end

      test "server.build includes meta resources" do
        server = McpServer::Server.build
        meta_uris = server.resources.map(&:uri).select { |u| u =~ %r{\Acc://workflow/(roles|glossary)\z} }
        assert_equal 2, meta_uris.size
      end
    end
    ```

    Step 3 — Run tests:
    ```
    bin/rails test test/mcp_server/resources/workflow_scenarios_test.rb test/mcp_server/resources/workflow_meta_test.rb
    ```
    All tests must pass.
  </action>
  <verify>
    <automated>bin/rails test test/mcp_server/resources/workflow_scenarios_test.rb test/mcp_server/resources/workflow_meta_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - Both test files exist; `frozen_string_literal: true` present on line 2 of each
    - Test run: `bin/rails test test/mcp_server/resources/workflow_scenarios_test.rb test/mcp_server/resources/workflow_meta_test.rb` reports `11 runs` (6+5) `0 failures, 0 errors`
    - server.build integration test passes: server.resources includes all 5 cc://workflow/* URIs
  </acceptance_criteria>
  <done>11 tests pass; server.build picks up workflow-resource registrations via Plan 01 dynamic registry; D-18 read pathway foundation complete (Plan 04 will add the lookup tools).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| MCP-client → server.resources/read | URI controlled by client; Plan 01 central dispatcher validates regex, delegates to Plan 02 .read |
| server → filesystem (docs/managers/clubcloud-scenarios/*.md) | read-only |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-40-02-01 | Tampering | Path-traversal via slug | mitigate | Plan 01 dispatcher regex `[\w-]+` rejects `/`, `..`; SCENARIOS hash whitelist gates valid slugs in Plan 02 .read; Pathname.join sanitizes |
| T-40-02-02 | Information Disclosure | Resources leak data outside CC scope | accept | Workflow markdown is non-sensitive operational documentation; was already publicly intended for `docs/managers/` per Phase 36c plan |
| T-40-02-03 | Spoofing | Resource URI cc:// prefix collision with another MCP-server in same client | accept | Custom scheme + project-specific server name (`carambus_clubcloud`) — D-06 spec decision |
</threat_model>

<verification>
- 5 markdown files under `docs/managers/clubcloud-scenarios/` exist, each with a `# ` heading on line 1
- All `[SME-CONFIRM]` markers from `.planning/clubcloud-admin-appendix-DRAFT.md` are preserved verbatim in the 5 outputs (per CONTEXT.md `<specifics>`)
- `bundle exec rails runner "puts McpServer::Server.build.resources.size >= 5"` outputs true
- 11 tests pass: `bin/rails test test/mcp_server/resources/`
- No new STDOUT pollution (resources do not write to STDOUT during build)
- **Plan 02 does NOT touch server.rb** — `git diff --stat lib/mcp_server/server.rb` for this plan should show 0 changes; only Plan 01 owns server.rb
</verification>

<success_criteria>
- 5 MCP resources exposed (3 scenarios + 2 meta) with URIs matching D-06
- Resource content is DE per D-05
- 5 markdown files contain `# `-style H1 headings on line 1
- `.read(slug:|key:)` returns markdown content for valid inputs, not-found body for unknowns (no exceptions)
- `McpServer::Server.build` (Plan 01 central dispatcher) routes `cc://workflow/scenarios/*` and `cc://workflow/(roles|glossary)` URIs to Plan 02's `.read` methods — no Plan-02-side handler registration
- Plan 02 + Plan 03 can run in same Wave 2 because neither touches server.rb (Blockers 2+3 fix)
</success_criteria>

<output>
After completion, create `.planning/phases/40-mcp-server-clubcloud/40-02-SUMMARY.md` documenting:
- Source-paragraph attribution for each of the 5 .de.md files (which DRAFT section the content was extracted from)
- Confirmation that Plan 02 does NOT call `resources_read_handler` (Blockers 2+3 audit)
- Final `[SME-CONFIRM]` marker count (4 or 5 — Info 12)
</output>
</content>
</invoke>