---
phase: 40-mcp-server-clubcloud
reviewed: 2026-05-07T00:00:00Z
depth: standard
files_reviewed: 35
files_reviewed_list:
  - .mcp.json.example
  - Gemfile
  - bin/mcp-server
  - docs/developers/clubcloud-mcp-server.de.md
  - docs/managers/clubcloud-mcp-setup.de.md
  - docs/managers/clubcloud-scenarios/cc-glossary.de.md
  - docs/managers/clubcloud-scenarios/cc-roles.de.md
  - docs/managers/clubcloud-scenarios/endrangliste-eintragen.de.md
  - docs/managers/clubcloud-scenarios/player-anlegen.de.md
  - docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md
  - lib/capistrano/tasks/mcp_server.rake
  - lib/mcp_server/cc_session.rb
  - lib/mcp_server/resources/api_surface.rb
  - lib/mcp_server/resources/workflow_meta.rb
  - lib/mcp_server/resources/workflow_scenarios.rb
  - lib/mcp_server/server.rb
  - lib/mcp_server/tools/base_tool.rb
  - lib/mcp_server/tools/finalize_teilnehmerliste.rb
  - lib/mcp_server/tools/lookup_category.rb
  - lib/mcp_server/tools/lookup_club.rb
  - lib/mcp_server/tools/lookup_league.rb
  - lib/mcp_server/tools/lookup_region.rb
  - lib/mcp_server/tools/lookup_serie.rb
  - lib/mcp_server/tools/lookup_spielbericht.rb
  - lib/mcp_server/tools/lookup_team.rb
  - lib/mcp_server/tools/lookup_teilnehmerliste.rb
  - lib/mcp_server/tools/lookup_tournament.rb
  - lib/mcp_server/tools/mock_client.rb
  - lib/mcp_server/tools/search_player.rb
  - lib/mcp_server/transport/boot.rb
  - test/mcp_server/cc_session_test.rb
  - test/mcp_server/integration/stdio_e2e_test.rb
  - test/mcp_server/resources/api_surface_test.rb
  - test/mcp_server/resources/workflow_meta_test.rb
  - test/mcp_server/resources/workflow_scenarios_test.rb
  - test/mcp_server/server_smoke_test.rb
  - test/mcp_server/tools/finalize_teilnehmerliste_test.rb
  - test/mcp_server/tools/lookup_region_test.rb
  - test/mcp_server/tools/lookup_smoke_test.rb
  - test/mcp_server/tools/lookup_teilnehmerliste_test.rb
  - test/mcp_server/tools/search_player_test.rb
findings:
  critical: 0
  warning: 5
  info: 7
  total: 12
status: issues_found
---

# Phase 40: Code Review Report

**Reviewed:** 2026-05-07
**Depth:** standard
**Files Reviewed:** 35 (Ruby source + docs + tests)
**Status:** issues_found

## Summary

The Phase 40 MCP server implementation is well-architected: a single central
read-handler dispatcher (per the revision blockers), explicit allowlists for
PATH_MAP/Workflow/Meta resources, defensive error handling that suppresses
stack-traces from MCP responses, mock-mode failsafe in production, and a
healthy test layer combining unit + smoke + drift-detection + e2e tests.

No security or critical-path defects were identified. Findings are split
between two categories:

1. **Logic bugs in DB-first lookup paths (Warnings).** Several read tools
   contain queries that either reference associations that don't exist on
   the target model, ignore parameters callers pass in, or return
   inconsistent shapes. The mock-mode + e2e test layer doesn't exercise the
   real-DB path, so these defects ship behind clean tests. They will manifest
   only when a real CC user invokes the tool.
2. **Hygiene / robustness (Info).** Unused-variable assignments, defensive
   patterns that read confusingly, and one cross-test helper that mutates
   global class state without restoration.

The single Write tool (`cc_finalize_teilnehmerliste`) and the resource
dispatcher are solid.

## Warnings

### WR-01: `lookup_teilnehmerliste` references nonexistent `tournament_cc` association on `RegistrationListCc`

**File:** `lib/mcp_server/tools/lookup_teilnehmerliste.rb:36-37`
**Issue:** When the tool is called with `meldeliste_id` (and not `tournament_id`),
it looks up the registration list and then attempts to navigate to its
tournament:

```ruby
registration_cc = RegistrationListCc.find_by(cc_id: meldeliste_id) if defined?(RegistrationListCc)
registration_cc&.tournament_cc
```

`RegistrationListCc` does NOT define a `tournament_cc` association — it only
has `belongs_to :branch_cc`, `:season`, `:discipline`, `:category_cc` and
`has_many :registration_ccs` (verified in
`app/models/registration_list_cc.rb:22-26`). The actual relationship is the
reverse: `TournamentCc belongs_to :registration_list_cc, optional: true`
(see `app/models/tournament_cc.rb:52`).

Because the call uses safe-navigation (`&.`), it won't raise when
`registration_cc` is nil — but when found, calling
`registration_cc.tournament_cc` will raise `NoMethodError`, which gets caught
nowhere in this tool and surfaces to the SDK as an unhandled exception.
(Unlike `finalize_teilnehmerliste`, this tool has no `rescue` block.)

**Fix:** Reverse the lookup — start from `TournamentCc`:

```ruby
tournament_cc = if tournament_id.present?
  TournamentCc.find_by(tournament_id: tournament_id)
else
  TournamentCc.find_by(registration_list_cc_id: RegistrationListCc.find_by(cc_id: meldeliste_id)&.id)
end
```

Or, more directly:

```ruby
registration_cc = RegistrationListCc.find_by(cc_id: meldeliste_id)
tournament_cc = registration_cc && TournamentCc.find_by(registration_list_cc_id: registration_cc.id)
```

Add a unit test that covers the `meldeliste_id`-only path with a fixture
that has both records linked.

---

### WR-02: `lookup_league` DB-first ignores `fed_id`/`branch_id`/`league_id`-derivation, returns wrong row

**File:** `lib/mcp_server/tools/lookup_league.rb:31-35`
**Issue:** When `league_id` is not given, the DB-first path narrows by
`season_id` only:

```ruby
LeagueCc.joins(:season_cc).where(
  season_ccs: { season_id: season_id_for(season) }
).first
```

A single season has many `LeagueCc` rows (one per competition × division).
The query simply returns `.first` — effectively random — and silently
ignores `fed_id` and `branch_id` that the caller passed. Worse, the input
schema documents `branch_id` as "CC branch ID (e.g. 10 for Karambol)" but
the parameter never reaches the WHERE clause.

Caller-visible result: a user asking
"show me the BCW Karambol-Bundesliga league for 2025/2026" receives the
first arbitrary league of that season, with no error.

**Fix:** Either narrow further by joining through the fed/branch chain
(`season_cc.competition_cc.branch_cc.region_cc.cc_id == fed_id` and
`branch_cc.cc_id == branch_id`), or document that `league_id` is required
for a deterministic DB-first lookup and reject the (fed_id, branch_id, season)
combo at the validation layer:

```ruby
# Either require league_id for DB-first…
if league_id.blank?
  return error("DB-first lookup requires league_id; use force_refresh: true with fed_id+branch_id+season for live CC lookup.")
end

# …or, if you want the combo path to work, add the joins:
LeagueCc.joins(season_cc: { competition_cc: { branch_cc: :region_cc } })
        .where(seasons: { name: season })
        .where(region_ccs: { cc_id: fed_id })
        .where(branch_ccs: { cc_id: branch_id })
        .first
```

---

### WR-03: `season_id_for` returns `nil` for unknown season name → query becomes "all leagues with NULL season_id"

**File:** `lib/mcp_server/tools/lookup_league.rb:54-56` (combined with WR-02)
**Issue:** If the caller passes a season name that doesn't match any
`Season` record (typo, future season, etc.):

```ruby
def self.season_id_for(season_name)
  Season.find_by(name: season_name)&.id
end
```

returns `nil`. The downstream query becomes `WHERE season_ccs.season_id IS
NULL` (because `where(... season_id: nil)` translates to `IS NULL` in
ActiveRecord). This will likely return rows with a NULL `season_id` if any
exist, or zero rows otherwise — neither is what the user asked for, and
no diagnostic is produced.

**Fix:** Detect the `nil` case explicitly:

```ruby
season_obj = Season.find_by(name: season)
return error("Unknown season: #{season.inspect}. Try force_refresh: true.") if season_obj.nil?
LeagueCc.joins(:season_cc).where(season_ccs: { season_id: season_obj.id }).first
```

---

### WR-04: `LookupLeague.live_lookup` raises `ArgumentError` for invalid actions; `LookupRegion.live_lookup` reuses `home` action

**File:** `lib/mcp_server/tools/lookup_region.rb:46-52` and
`lib/mcp_server/tools/lookup_league.rb:42-52`
**Issue:** Two related concerns about the live-lookup helper:

1. `LookupRegion.live_lookup` calls
   `client.get("home", { fedId: fed_id }, ...)`. The `home` action exists
   in PATH_MAP, but it's a generic CC dashboard root that returns an HTML
   page; nothing in this code parses it, so the response is just stubbed
   into "CC live response for fed_id=… (status 200)". A user expecting
   region metadata gets a meaningless confirmation. Either parse the HTML
   into JSON-shaped output (matching `format_region`), or re-route through
   a region-detail endpoint.

2. None of the live-lookup paths (in any read tool) call
   `cc_session.reauth_if_needed!(doc)` after the GET, so a session
   expired after the cookie fetched on line 49 will result in the user
   getting a "live response" that's actually a CC login page. Only
   `finalize_teilnehmerliste` does the reauth dance.

**Fix:**
1. Either parse the HTML response into a structured payload, or update the
   tool description so users know `force_refresh: true` returns
   confirmation-only — not data.
2. Add reauth handling to all live-lookup helpers; consider extracting a
   `BaseTool.cc_get_with_reauth(action, params)` helper to enforce this:

```ruby
def self.cc_get_with_reauth(action, params)
  client = cc_session.client_for
  res, doc = client.get(action, params, { session_id: cc_session.cookie })
  if cc_session.reauth_if_needed!(doc)
    res, doc = client.get(action, params, { session_id: cc_session.cookie })
  end
  [res, doc]
end
```

---

### WR-05: `LookupLeague`/`LookupTournament` swallow `force_refresh` unless required identifiers present

**File:** `lib/mcp_server/tools/lookup_league.rb:23-27`,
`lib/mcp_server/tools/lookup_tournament.rb:22-26`
**Issue:** Validation runs before `force_refresh` branching:

```ruby
unless league_id.present? || (fed_id.present? && branch_id.present? && season.present?)
  return error("Missing required parameter: ...")
end
return live_lookup(...) if force_refresh
```

But `live_lookup` itself has its own per-parameter checks (e.g.
`return error("Missing fed_id for live lookup") if fed_id.blank?`). The
front-validation rejects e.g. `force_refresh: true, fed_id: 20` because
`branch_id` and `season` are absent — even though `live_lookup` would
accept just `fed_id`. This is a UX paper-cut that surfaces a misleading
error message ("provide league_id or fed_id+branch_id+season") when the
user actually asked for a live lookup.

**Fix:** Branch on `force_refresh` first, then validate the live-lookup
required fields:

```ruby
return live_lookup(...) if force_refresh
unless league_id.present? || (fed_id.present? && branch_id.present? && season.present?)
  return error("Missing required parameter: provide `league_id` or fed_id+branch_id+season (or use force_refresh: true).")
end
```

The same restructuring applies to `LookupTournament`.

## Info

### IN-01: `LookupTeilnehmerlisteTest` doesn't `assert response.error?` on happy-path branch

**File:** `test/mcp_server/tools/lookup_teilnehmerliste_test.rb:14-20`
**Issue:** The "D-18 acceptance story" test only asserts that
`body.length.positive?` after looking up the first tournament, but it
doesn't check `refute response.error?`. Because the tool returns an error
response when no `TournamentCc` mirror exists for that tournament (which
is the most likely fixture state), the test is happy whether it took the
happy path or the error path. The error-text branch produces a
"length-positive" body too.

**Fix:** Add `refute response.error?` (or equivalent) and assert content
is JSON-shaped. If fixtures don't reliably link `Tournament` →
`TournamentCc`, set up a factory in the test:

```ruby
tournament_cc = TournamentCc.first
skip "No tournament_cc fixtures" unless tournament_cc
response = McpServer::Tools::LookupTeilnehmerliste.call(
  tournament_id: tournament_cc.tournament_id, server_context: nil
)
refute response.error?, "expected DB-hit, got: #{response.content.first[:text]}"
parsed = JSON.parse(response.content.first[:text])
assert_equal tournament_cc.cc_id, parsed["cc_tournament_id"]
```

---

### IN-02: `FinalizeTeilnehmerlisteTest` test "D-11 Login-Redirect" leaks `define_singleton_method` override

**File:** `test/mcp_server/tools/finalize_teilnehmerliste_test.rb:82-103`
**Issue:** The test stubs `McpServer::CcSession.reauth_if_needed!` via
`define_singleton_method` and then in `ensure` calls
`define_singleton_method(:reauth_if_needed!, original_reauth)` — but
`define_singleton_method` does not accept a `Method` object as a second
positional argument; it requires a block or a `UnboundMethod`. This
silently no-ops the restore on some Ruby versions, and on others raises
ArgumentError that masks the real test failure. The override leaks into
subsequent tests in the same process, causing flakes that depend on test
order.

**Fix:** Use `Mocha`/`Minitest::Mock` or rebind correctly:

```ruby
ensure
  McpServer::CcSession.singleton_class.send(:remove_method, :reauth_if_needed!)
  McpServer::CcSession.define_singleton_method(:reauth_if_needed!, original_reauth.unbind.bind_call(McpServer::CcSession.singleton_class))
end
```

A simpler, more robust pattern: use `stub` (which is already used in
`cc_session_test.rb`):

```ruby
McpServer::CcSession.stub(:reauth_if_needed!, ->(doc) { ... }) do
  response = McpServer::Tools::FinalizeTeilnehmerliste.call(...)
  ...
end
```

---

### IN-03: Unused `_doc` block-locals via tuple destructuring everywhere

**File:** `lib/mcp_server/tools/lookup_*.rb` (all 9 read tools that touch
CC live)
**Issue:** Every live-lookup tool destructures the client response as
`res, _doc = client.get(...)` and never uses `_doc`. This means the tool
cannot detect:

- Login-redirect responses (always a 200 from CC's POV)
- Embedded error divs in 200-responses

This is the same defensive concern as WR-04 (#2), but reframed: the
underscore-prefix convention is correct for "intentionally unused" — but
in this domain, the unused doc is exactly where errors hide. Either
remove the destructuring (use `res, = client.get(...)` and an explicit
single-value reception) or actually parse the doc.

**Fix:** Adopt the helper from WR-04 #2; renaming `_doc` to `doc` and
checking `cc_session.reauth_if_needed!(doc)` would also surface the
session-redirect case at the read-tool layer.

---

### IN-04: `cc_session.rb` private `login_redirect?` duplicates logic in `finalize_teilnehmerliste.rb#parse_cc_error`

**File:** `lib/mcp_server/cc_session.rb:95-99`,
`lib/mcp_server/tools/finalize_teilnehmerliste.rb:78`
**Issue:** Both files contain the identical CSS selector
`form[action*='login']` to detect a CC login redirect. If CC ever changes
the login form structure, two files must be updated in lockstep. This is
a small but real DRY violation in security-adjacent code.

**Fix:** Extract a public predicate on `CcSession`:

```ruby
# in cc_session.rb
def self.login_redirect?(doc)
  return false if doc.nil? || !doc.respond_to?(:css)
  doc.css("form[action*='login']").any?
end
```

Then `finalize_teilnehmerliste.rb#parse_cc_error` uses
`McpServer::CcSession.login_redirect?(doc)`.

---

### IN-05: `BaseTool.cc_session` is a class-level helper but never used by any tool

**File:** `lib/mcp_server/tools/base_tool.rb:38-40`
**Issue:** Every tool calls `McpServer::CcSession.client_for` directly
(or via the lower-level `client_for`) rather than going through the
`cc_session` helper on `BaseTool`. The helper was added "just in case"
and now reads as dead.

**Fix:** Either use it consistently (replace `cc_session` /
`McpServer::CcSession` calls in the tool files with
`self.class.cc_session`) — or delete the helper. Same for
`mock_mode?` on `BaseTool` (line 33-35), which duplicates
`McpServer::CcSession.mock_mode?` and is also unused.

---

### IN-06: `MockClient#post` does NOT honor `armed: true` for write actions — silently returns 200 for anything

**File:** `lib/mcp_server/tools/mock_client.rb:19-24`
**Issue:** The mock returns `[nil, nil]` only when `opts[:armed].blank?` AND
the action is writable. When `armed: true`, it returns
`[stub_response("OK"), Nokogiri::HTML(...)]` with HTTP 200, regardless
of payload validity. This is documented as "mirror the real client",
but the real client also makes a real HTTP request — the mock has no
test fixtures for permission-denied or validation errors. Tests that
want to verify CC-rejection paths must hand-craft a stub via
`define_singleton_method` (as `finalize_teilnehmerliste_test.rb` does).

This is fine for v1 but worth a comment so test authors know the mock's
limit.

**Fix:** Add an explicit comment to `MockClient`:

```ruby
# NOTE: armed: true always returns a successful mock response. For tests
# that exercise CC-rejection paths (permission errors, malformed payloads,
# session expiry), override .post / .get on a MockClient instance via
# define_singleton_method. See test/mcp_server/tools/finalize_teilnehmerliste_test.rb
```

---

### IN-07: `bin/mcp-server` reads `RAILS_ENV ||= "production"` — hidden default for a development tool

**File:** `bin/mcp-server:6`
**Issue:** When a developer spawns `bin/mcp-server` directly without
setting `RAILS_ENV`, it boots in production mode by default. This means
production credentials, production DB, production logging — typically
not what a dev wants when testing locally. The setup doc recommends
starting via Claude Desktop, which should pass `RAILS_ENV=development`
explicitly, but this is buried in `.mcp.json.example` (not present).

**Fix:** Either:

1. Default to `development` (safer for local invocation):
   `ENV["RAILS_ENV"] ||= "development"`
2. Or document the production default loudly in `bin/mcp-server`'s
   header comment AND in `.mcp.json.example` so users explicitly
   choose:

```jsonc
"env": {
  "RAILS_ENV": "production",
  ...
}
```

The current `.mcp.json.example` doesn't set `RAILS_ENV` at all, so the
production default silently wins.

---

_Reviewed: 2026-05-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
