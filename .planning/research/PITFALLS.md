# Domain Pitfalls: Rails God-Model Refactoring

**Domain:** God-model extraction — Rails 7.2, AASM state machines, CableReady/StimulusReflex, external API sync
**Researched:** 2026-04-09
**Applies to:** TableMonitor (3900 lines) and RegionCc (2700 lines)

---

## Critical Pitfalls

These cause silent behavioral breakage, regressions in production, or force rewrites.

---

### Pitfall 1: Extracting callbacks without understanding their firing order and data dependencies

**What goes wrong:**
The `after_update_commit` lambda in TableMonitor (lines 75–186) reads `@collected_changes`,
`@collected_data_changes`, `previous_changes`, and instance state in a specific order, with
early-returns branching to ultra-fast, fast, and slow paths. Extracting this to a service
without preserving that exact execution sequence breaks scoreboard update routing. The instance
variables (`@collected_changes`, `@collected_data_changes`) are set by upstream callbacks and
must be populated before the commit callback fires. Moving the commit callback body into a
service that is called from a different lifecycle position will read nil or stale values.

**Why it happens:**
Rails callbacks form an implicit pipeline. The commit callback depends on pre-save hooks
setting `@collected_changes`. When you extract to a service and inject the model as a
dependency, you lose the guarantee that the pre-save data is still attached to `self`.

**Consequences:**
- Wrong broadcast path chosen (ultra-fast vs. fast vs. slow) → stale or missing scoreboard updates
- `previous_changes` is only valid inside `after_commit` — calling it from a service invoked
  after the response returns returns empty hash
- `@collected_data_changes` instance variable is nil if accessed outside the callback chain

**Prevention:**
1. Map the full callback chain BEFORE touching any code (before_create, before_save,
   after_update_commit, their order, and what instance state each one reads/writes).
2. Pass required data explicitly into the service — never have the service read
   `previous_changes` or `@instance_vars` from a model reference.
3. Freeze snapshot of `previous_changes` into a plain Hash at the start of the callback, then
   pass that hash to the service. This decouples service logic from AR callback timing.

**Warning signs:**
- Service constructor takes a model instance and calls `model.previous_changes` inside service code
- Test passes in isolation but fails when called from a real `after_commit`
- Scoreboards receive no update on score changes after extraction

**Phase:** Characterization-test phase — map and document the chain before any extraction.

---

### Pitfall 2: `skip_update_callbacks` flag becoming invisible in tests and extracted services

**What goes wrong:**
`TableMonitor` has `attr_accessor :skip_update_callbacks` used as a runtime guard to suppress
the entire `after_update_commit` block during batch operations like `start_game`. This flag
only exists on the instance; service objects hold no reference to it. When broadcasts are
moved into a service, the guard is no longer checked, meaning batch operations that previously
suppressed redundant job enqueues will fire them again — triggering multiple Sidekiq jobs per
table update during a tournament start.

**Why it happens:**
The flag is a known workaround (see CONCERNS.md: "skip_update_callbacks flag is dangerous
workaround"). When services are extracted without explicitly threading this flag through, the
suppression contract silently breaks.

**Consequences:**
- `start_game` enqueues 3–5 redundant broadcast jobs per table
- Race conditions in Sidekiq where an early job reads uncommitted state
- Log noise makes it hard to detect (job IDs differ, but behavior looks same)

**Prevention:**
1. Before extraction, document every call site that sets `skip_update_callbacks = true`.
2. Replace the flag with a named context: pass a `broadcast: false` keyword argument to the
   extracted service explicitly.
3. Delete the `attr_accessor` once all callers are migrated to the explicit pattern.
4. Write a test that asserts job enqueue count is exactly N during a `start_game` batch.

**Warning signs:**
- Grep for `skip_update_callbacks` returns callers not covered by tests
- Jobs count assertions are not part of the test suite for batch operations

**Phase:** First extraction phase for TableMonitor — address before broadcasting is moved out.

---

### Pitfall 3: `after_commit` reliability — side effects lost on process crash

**What goes wrong:**
If the process dies between transaction commit and the code that enqueues Sidekiq jobs inside
`after_commit`, those jobs are never enqueued. The database has the new state, but no broadcast
job was ever scheduled. This is not a new risk — it exists today — but extraction makes it
worse: a service wrapping commit side effects outside a real transaction boundary creates the
same gap with no protection.

**Why it happens:**
`after_commit` runs after the database transaction closes. Any exception or process kill
between "transaction committed" and "Sidekiq.enqueue called" loses the side effect
permanently. The ActiveRecord transaction does not wrap the Sidekiq enqueue.

**Consequences:**
- Scoreboards silently stuck on stale data after a network blip or deploy
- CableReady broadcasts never fired → UI appears frozen
- Difficult to reproduce because it requires a specific failure window

**Prevention:**
1. For critical broadcast jobs, enqueue inside the transaction using
   `after_create_commit` + Sidekiq's `perform_async` (which enqueues atomically with the
   `after_commit` hook if properly integrated).
2. Do not move broadcast job enqueuing outside of the `after_commit` boundary into a service
   that returns before committing — this widens the failure window.
3. If this risk is material, investigate Rails 7.x `after_commit_everywhere` gem or a
   transactional outbox pattern — but this is out of scope for the current milestone.
4. At minimum, add a heartbeat or "last broadcast" timestamp to detect stuck scoreboards.

**Warning signs:**
- Service encapsulates both save and broadcast — no guarantee save commits first
- Tests mock `after_commit` in a way that hides the async timing issue

**Phase:** TableMonitor extraction — note the risk, ensure jobs are enqueued inside commit hook.

---

### Pitfall 4: VCR cassettes masking RegionCc sync behavior after extraction

**What goes wrong:**
RegionCc sync tests rely on VCR cassettes recorded against a ClubCloud API snapshot. After
extracting HTTP logic into a `ClubCloudClient` service, the cassettes may match the old
calling pattern (URL, headers, parameter order) but the new service makes requests in a
different order, with different query parameters, or with additional requests not in the
cassette. Tests continue to pass locally (cassette matches), but production sync fails against
the live API.

**Why it happens:**
VCR records `match_requests_on: [:method, :uri]` only. If the extracted service makes the
same URIs but in a different sequence, or adds a new URI, the cassette silently replays
partial responses. The new codepath exercises the live API logic in ways not captured.

**Consequences:**
- RegionCc sync appears to pass in CI but creates orphaned records in production
- Data inconsistency in leagues, teams, players that is hard to trace back to the refactoring

**Prevention:**
1. Before extracting HTTP logic, enumerate all unique HTTP requests made by `region_cc.rb`
   (method + URI + parameter shape). Use `VCR.eject_cassette` + a debug logger to capture
   the exact request sequence.
2. After extraction, re-record cassettes — do not reuse cassettes recorded against the old
   calling pattern.
3. Add request-count assertions to critical sync tests:
   `assert_requested :get, /clubcloud/, times: 4`.
4. Mark all RegionCc sync tests with a comment showing which cassette version they expect,
   so stale cassettes are caught during code review.

**Warning signs:**
- Cassette files are not re-recorded after extracting HTTP into a new class
- Test passes but `stub_request(:any, ...)` count assertions are absent
- No test asserts the number of records created/updated after sync

**Phase:** RegionCc extraction — re-record cassettes as a required step, not an optional one.

---

### Pitfall 5: Extracted service breaks AASM transition guards without failing loudly

**What goes wrong:**
AASM transitions in TableMonitor use `guard:` lambdas and `after:` callbacks that reference
methods defined elsewhere in the 3900-line class. When those methods are moved into service
objects, the AASM DSL still references the model method by name — but the method now delegates
to the service. If that delegation is wrong or the service requires initialization parameters
the model no longer provides, AASM swallows the error by treating a raised exception as a
failed guard, silently refusing the transition rather than raising.

**Why it happens:**
AASM's default `whiny_transitions: false` setting causes failed transitions to return false
instead of raising `AASM::InvalidTransition`. The caller often ignores the return value.
A service that raises `ArgumentError` during a guard check becomes a silent no-op.

**Consequences:**
- State machine silently refuses transitions during a live match
- TableMonitor stays in a wrong state (e.g., stuck in `playing` after `finish_game` called)
- No exception in logs — just a return value of false that nobody checked

**Prevention:**
1. Verify AASM is configured with `whiny_transitions: true` (or set it explicitly before
   refactoring). This converts silent failures to exceptions.
2. For every `guard:` lambda that references a method, write a unit test asserting the
   transition raises `AASM::InvalidTransition` when the guard returns false.
3. Do not move guard logic into services until those unit tests exist and pass.
4. After extraction, re-run all state transition tests. If any test changes from "raises" to
   "returns false", a guard method was accidentally broken.

**Warning signs:**
- `aasm whiny_transitions: false` in the model
- Guard lambdas reference methods by symbol (e.g., `guard: :can_start?`) without tests for that method
- Reflex calls `table_monitor.start_game!` and checks return value instead of rescuing exception

**Phase:** Characterization phase — add `whiny_transitions: true` and tests before extraction.

---

### Pitfall 6: CableReady broadcast timing: service broadcasts before transaction commits

**What goes wrong:**
The current code enqueues broadcast jobs via `TableMonitorJob.perform_later` inside
`after_update_commit`, which is correct — the transaction is committed before the job fires.
If an extracted service calls `cable_ready.broadcast` (direct, not via job) inside a business
method that runs inside a transaction (e.g., inside `start_game` before `save!`), the
broadcast fires before the database row is committed. Connected scoreboards query fresh state
and read the old row.

**Why it happens:**
StimulusReflex docs explicitly warn: "Broadcasting a CableReady operation during the
Controller Action phase transmits to the browser before HTML has been rendered" — the same
problem applies to broadcasting inside an open database transaction. The DOM updates but the
data behind it has not committed.

**Consequences:**
- Scoreboard shows a score update, then snaps back to old state when it re-renders
- Race between broadcast consumer and database query is timing-dependent, so it only appears
  under load or when the database is slightly slow

**Prevention:**
1. All CableReady broadcasts triggered by model data changes MUST be inside `after_commit`
   hooks or Sidekiq jobs enqueued from `after_commit`.
2. Extracted broadcast service must never be called from inside a database transaction unless
   it defers via `perform_later`.
3. Add a linting rule in code review: any `cable_ready` call outside a `*_commit` callback
   or a job is a red flag.

**Warning signs:**
- Service method mixes `save!` and `cable_ready.broadcast` in the same execution context
- Tests mock `cable_ready` so timing is never validated

**Phase:** TableMonitor broadcasting extraction.

---

## Moderate Pitfalls

---

### Pitfall 7: Characterization tests that only test happy paths

**What goes wrong:**
Happy-path characterization tests confirm the refactoring does not break normal flow, but
TableMonitor has documented gaps in edge cases: game cancellation during active timer, timer
interruption, `PartyMonitor` vs `TournamentMonitor` polymorphic branches, and the
`local_server?` guard (API server skips all broadcasts). Without edge-case characterization
tests, extraction may silently break these paths.

**Prevention:**
1. Before any extraction, enumerate at least these paths for TableMonitor:
   - `start_game` → `finish_game` complete flow (happy path)
   - `start_game` → `cancel_game` with active timer
   - State transitions when `local_server?` returns false (API server mode)
   - `PartyMonitor` polymorphic branch in `after_update_commit`
   - `skip_update_callbacks = true` suppresses job enqueues
2. For RegionCc, enumerate sync scenarios:
   - Normal full sync (league + teams + players)
   - Sync after API failure mid-run (recovery behavior)
   - Duplicate `cc_id` handling
3. A characterization test need only assert "system does not raise and produces X records" —
   it does not need to be a perfect unit test.

**Warning signs:**
- Test file for TableMonitor only tests `state` transitions, not job enqueue count
- No test covers `skip_update_callbacks` behavior

**Phase:** Characterization phase — all paths before any extraction commit.

---

### Pitfall 8: Extraction creates a service that is just a renamed model method

**What goes wrong:**
Under time pressure, "extraction" becomes `TableMonitorBroadcastService.call(self)` where
the body is copied verbatim from the model. The service now has all the same dependencies as
the model (directly reads `previous_changes`, references `self.tournament_monitor`,
calls `self.get_options!`). It is not independently testable and provides no isolation benefit.
This is the "junk drawer" anti-pattern.

**Prevention:**
1. Extracted service must be instantiable and callable without an ActiveRecord model in tests
   (pass a plain struct or double with the required interface).
2. Define the service's public interface as data-in / side-effect-out:
   inputs are plain Ruby values (hashes, symbols, IDs), not model instances.
3. If the service cannot be tested without hitting the database, the extraction is incomplete.

**Warning signs:**
- Service `initialize` takes `model` and immediately calls `model.previous_changes`
- Service file is longer than 200 lines on first extraction

**Phase:** All extraction phases.

---

### Pitfall 9: Transactional test isolation hides `after_commit` behavior

**What goes wrong:**
Rails wraps tests in database transactions that are rolled back after each test
(`use_transactional_tests = true`, which is the default). `after_commit` callbacks never fire
inside a wrapped transaction — the transaction never actually commits. This means characterization
tests that verify "broadcast jobs are enqueued after save" will always pass (no jobs enqueued,
no assertion failure) because the callback never runs.

**Why it happens:**
This is a well-known Rails testing trap. The test transaction wraps the test body and the
`after_commit` hook waits for a real commit that never comes.

**Consequences:**
- Test suite claims 100% coverage of `after_update_commit` paths but has tested zero of them
- Extraction ships "green" but breaks production broadcasts immediately

**Prevention:**
1. For any test that must verify `after_commit` behavior, use
   `self.use_transactional_tests = false` and manually clean up.
2. Alternatively, use the `test_after_commit` gem (or Rails 5.1+ `after_commit_on_rails_test`
   support) to fire `after_commit` callbacks in wrapped transactions.
3. In the characterization phase, verify that at least one test class disables transactional
   tests for broadcast verification.

**Warning signs:**
- All test classes use `use_transactional_tests = true` (the default)
- Test asserts `assert_enqueued_jobs 1` for a save but callback never fires in tests
- No explicit `after_commit` test configuration in `test_helper.rb`

**Phase:** Characterization phase — identify before writing any new tests.

---

### Pitfall 10: `cattr_accessor` class-level state leaks between tests

**What goes wrong:**
`TableMonitor` uses `cattr_accessor :options`, `:gps`, `:location`, `:tournament`, `:my_table`
and `cattr_accessor :allow_change_tables`. These are class-level variables shared across all
instances and all test runs. If one test sets `TableMonitor.tournament = some_object` and
does not reset it, subsequent tests inherit polluted state. This is a latent issue that
extraction may trigger — extracted services reading `TableMonitor.tournament` directly will
expose the pollution more visibly.

**Prevention:**
1. In the characterization test setup, add `teardown` blocks that reset all `cattr_accessor`
   values to nil.
2. Extracted services should never read `cattr_accessor` values directly — they should receive
   context as constructor arguments.
3. Document which `cattr_accessor` values are "set once at boot" vs "set per request" so the
   appropriate reset strategy is clear.

**Warning signs:**
- Tests pass when run individually but fail when run as a suite
- Extracted service reads `TableMonitor.tournament` without receiving it as a parameter

**Phase:** Characterization phase and all extraction phases.

---

## Minor Pitfalls

---

### Pitfall 11: Serialized YAML fields parsed in service layer

**What goes wrong:**
`TableMonitor` serializes `data` and `prev_data` as YAML-encoded hashes. Service extraction
that parses these fields in Ruby code (e.g., `YAML.safe_load(table_monitor.data_before_type_cast)`)
must handle nil, malformed YAML, and the existing coder behavior consistently. If the service
uses a different deserialization path than the model, it will produce different hash shapes.

**Prevention:**
Always access serialized fields through the model accessors (`table_monitor.data`, not raw
column values). Never re-parse in the service — let ActiveRecord's coder handle it.

**Warning signs:**
- Service uses `YAML.load` or `JSON.parse` on a column that the model already deserializes

**Phase:** TableMonitor data-access extraction.

---

### Pitfall 12: `DEBUG = Rails.env != "production"` constant in extracted files

**What goes wrong:**
`TableMonitor` defines `DEBUG = Rails.env != "production"` at the class level. If extracted
service files copy this pattern, the constant is defined per file and Rails' autoloader may
warn about constant redefinition. More critically, `TableMonitorReflex` has `DEBUG = true`
(always on), which is a separate constant. Cross-file DEBUG constant naming conflicts are a
runtime warning in development and a latent test pollution source.

**Prevention:**
Replace all `DEBUG` constants with `Rails.logger.debug { "..." }` calls during extraction.
Do not carry the pattern forward into service files.

**Warning signs:**
- New service file defines `DEBUG = ...` at the top level

**Phase:** Any extraction phase that touches logging code.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Characterization tests (TableMonitor) | Transactional test wrapping silences `after_commit` (Pitfall 9) | Use non-transactional tests for commit-hook coverage |
| Characterization tests (TableMonitor) | Happy-path only — missing `skip_update_callbacks` and `local_server?` branches (Pitfall 7) | Enumerate all branching conditions before writing tests |
| TableMonitor broadcast extraction | `skip_update_callbacks` guard not threaded through (Pitfall 2) | Replace flag with explicit `broadcast:` param before extracting |
| TableMonitor broadcast extraction | Broadcast fires inside open transaction (Pitfall 6) | Enforce `after_commit`-only broadcast rule |
| TableMonitor state machine extraction | AASM silently swallows guard failures (Pitfall 5) | Set `whiny_transitions: true`, test each guard |
| TableMonitor callback chain extraction | Service reads stale `previous_changes` (Pitfall 1) | Snapshot `previous_changes` to Hash at callback entry |
| RegionCc HTTP extraction | VCR cassettes not re-recorded, masking new request pattern (Pitfall 4) | Mandatory cassette re-record step in extraction checklist |
| Any extraction | Service is renamed model method, not isolated (Pitfall 8) | Service must be testable without database access |
| Any extraction | `cattr_accessor` class state leaks between tests (Pitfall 10) | Reset all class-level accessors in teardown |

---

## Sources

- CONCERNS.md (fragile areas: TableMonitor state machine, RegionCc ClubCloud integration) — HIGH confidence
- Karol Galanciak: [The inherent unreliability of after_commit callbacks](https://karolgalanciak.com/blog/2022/11/12/the-inherent-unreliability-of-after_commit-callback-and-most-service-objects-implementation/) — HIGH confidence
- Kelly Sutton: [Rails Callbacks Flatten Layered Architecture](https://kellysutton.com/2018/01/15/rails-callbacks-flatten-layered-architecture.html) — HIGH confidence
- StimulusReflex docs: [Troubleshooting](https://v3-4-docs.docs.stimulusreflex.com/appendices/troubleshooting) and [Lifecycle](https://docs.stimulusreflex.com/guide/lifecycle) — HIGH confidence
- AASM GitHub: [aasm/aasm](https://github.com/aasm/aasm) — HIGH confidence (direct inspection of `whiny_transitions` option)
- Arkency: [OOP Refactoring from a god class to smaller objects](https://blog.arkency.com/oop-refactoring-from-a-god-class-to-smaller-objects/) — MEDIUM confidence
- Rails Guides: [Active Record Callbacks](https://guides.rubyonrails.org/active_record_callbacks.html) — HIGH confidence (transactional test behavior)
- VCR gem: [vcr/vcr](https://github.com/vcr/vcr) and [reinteractive VCR guide](https://reinteractive.com/articles/testing-external-services-using-vcr) — HIGH confidence
- Oozou: [Never Skip a Callback in Your Tests](https://oozou.com/blog/never-skip-a-callback-in-your-tests-21) — MEDIUM confidence
- Direct code reading: `app/models/table_monitor.rb` lines 39–186 — HIGH confidence
