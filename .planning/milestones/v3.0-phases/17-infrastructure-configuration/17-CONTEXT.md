# Phase 17: Infrastructure & Configuration - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Set up a working system test environment where ActionCable broadcasts reach real browser WebSocket connections. Includes cable adapter config, local_server? override, ApplicationSystemTestCase multi-session helpers, and a smoke test proving end-to-end broadcast delivery.

</domain>

<decisions>
## Implementation Decisions

### Cable Adapter Strategy
- **D-01:** Switch `config/cable.yml` test adapter globally from `test` to `async`. The `test` adapter stores broadcasts in memory only and never delivers to real WebSocket connections opened by Selenium. The `async` adapter runs in-process and works with the same-process Puma topology used by system tests.
- **D-02:** After the adapter change, run `bin/rails test test/channels/` to verify the 2 existing channel unit tests (`TournamentChannelTest`, `TournamentMonitorChannelTest`) still pass. If they break, fall back to an env-var approach.

### local_server? Override
- **D-03:** Add a `test:` section to `config/carambus.yml` with `carambus_api_url: "http://test-api"` (or similar dummy value). This makes `ApplicationRecord.local_server?` return `true` in the test environment, so `TableMonitorChannel` accepts subscriptions and `TableMonitorJob` executes broadcasts.
- **D-04:** After the config change, run the full test suite to verify no existing tests depend on `local_server?` being `false`.

### Smoke Test Design
- **D-05:** Use Capybara's built-in wait/retry mechanism (`assert_selector` with default wait time) for asserting broadcast-driven DOM updates. No custom polling helper or cable-status indicator needed for Phase 17.
- **D-06:** Claude picks the simplest AASM state change that produces a visible DOM update on the scoreboard page for the smoke test trigger.

### Claude's Discretion
- Exact AASM transition for smoke test (pick the simplest one that produces a visible scoreboard DOM change)
- Multi-session Capybara helper API design (method names, parameter patterns)
- AR connection pool configuration for multi-session tests
- suppress_broadcast reset in test teardown (if needed)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### ActionCable Channel & Broadcast
- `app/channels/table_monitor_channel.rb` — Subscription guard (`local_server?`), stream name (`"table-monitor-stream"`)
- `app/javascript/channels/table_monitor_channel.js` — Client-side filtering (`shouldAcceptOperation`, `getPageContext`), `console.warn("SCOREBOARD MIX-UP PREVENTED")` on rejection

### Job & Broadcast Trigger
- `app/jobs/table_monitor_job.rb` — `local_server?` guard, CableReady broadcast to `"table-monitor-stream"`, operation types (teaser, table_scores, score_data, player_score_panel, default full scoreboard)

### Configuration
- `config/cable.yml` — Cable adapter per environment (currently `test` for test)
- `config/carambus.yml` — `carambus_api_url` setting that controls `local_server?` return value

### Test Infrastructure
- `test/application_system_test_case.rb` — Existing Selenium/Chrome setup, Devise/Warden helpers
- `test/test_helper.rb` — LocalProtectorTestOverride, ApiProtectorTestOverride, no local_server? override
- `test/channels/tournament_channel_test.rb` — Existing channel unit test (verify after adapter change)
- `test/channels/tournament_monitor_channel_test.rb` — Existing channel unit test (verify after adapter change)

### Scoreboard Routes & Views
- `config/routes.rb` — `table_monitors#scoreboard`, `table_monitors#scoreboard_overlay`, `table_monitors#scoreboard_text`

### Research
- `.planning/research/STACK.md` — Stack decisions for system test infrastructure
- `.planning/research/ARCHITECTURE.md` — Build order and integration architecture
- `.planning/research/PITFALLS.md` — 9 critical pitfalls with prevention strategies

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/application_system_test_case.rb` — Already configured with Selenium headless Chrome, Devise helpers, optional remote Selenium support. Extend this for multi-session and ActionCable helpers.
- 13 existing system test files in `test/system/` — Established patterns for system test structure and assertions.

### Established Patterns
- `TableMonitorChannel` uses a single shared stream (`"table-monitor-stream"`) — all clients receive all broadcasts, filtering is client-side only
- `local_server?` is the gate for both channel subscriptions and job execution — same config key controls both
- `suppress_broadcast` flag on TableMonitor controls whether `after_update_commit` triggers `TableMonitorJob`
- CableReady operations target CSS selectors like `#full_screen_table_monitor_{id}` — the ID in the selector is how the JS filter determines which table a broadcast belongs to

### Integration Points
- `ApplicationSystemTestCase` is where multi-session helpers and ActionCable config will be added
- `config/carambus.yml` needs a new `test:` section (currently only `default:` and `development:` exist)
- `config/cable.yml` test adapter needs changing from `test` to `async`
- Scoreboard page route: `scoreboard_table_monitor_path(table_monitor)` — the page the smoke test will visit

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 17-infrastructure-configuration*
*Context gathered: 2026-04-11*
