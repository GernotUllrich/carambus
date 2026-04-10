# Pitfalls Research: Tournament & TournamentMonitor Refactoring (v2.1)

**Domain:** God-model extraction — Tournament (API Server, 1775 lines) and TournamentMonitor (Local Server orchestrator, 499 lines + 600+ lines in lib/)
**Researched:** 2026-04-10
**Confidence:** HIGH — based on direct code reading of both models, existing test files, concern implementations, and v1.0 lessons learned

---

## Critical Pitfalls

These cause silent behavioral breakage, regressions in production, or require rewrites.

---

### Pitfall 1: LocalProtector and ApiProtector fire in opposite server contexts — silence is the failure mode

**What goes wrong:**
`Tournament` includes `LocalProtector`, which blocks saves of global records (id < 50_000_000) on the local server via `after_save :disallow_saving_global_records`. `TournamentMonitor` includes `ApiProtector`, which blocks saves of local records on the API server via `after_save :disallow_saving_local_records`. Both raise `ActiveRecord::Rollback` silently — the save appears to succeed, the caller continues, but no row was written to the database. Extracted services or characterization tests that create or save records without understanding which server context is active will produce phantom "successes" that leave the database unchanged.

**Why it happens:**
`ApplicationRecord.local_server?` returns `true` when `Carambus.config.carambus_api_url.present?`. In the test environment, `LocalProtector#disallow_saving_global_records` explicitly returns `true` early (`return true if Rails.env.test?`), making it harmless. But `ApiProtector#disallow_saving_local_records` is installed via `included do ... after_save` directly on each including class — prepending `ApiProtectorTestOverride` to the module itself does NOT override already-installed methods (this is documented in test_helper.rb). The workaround is `ObjectSpace.each_object` patching, but any model class required AFTER that patch runs will not be covered.

Critically: `TournamentMonitor` includes `ApiProtector`. If a test loads `TournamentMonitor` for the first time after the `ObjectSpace` sweep, `disallow_saving_local_records` is the original method, and every `tournament_monitor.save` silently rolls back.

**How to avoid:**
1. Run `bin/rails test` once before writing any tests to confirm `TournamentMonitor` is already in the patched set. If it is not, add it explicitly to the patch loop or ensure it is required before the `ObjectSpace.each_object` sweep.
2. In every new test that saves a `TournamentMonitor`, add an assertion immediately after `save` / `save!` that the record `persisted?` and `id` is set. Silent rollback will cause `persisted?` to return false.
3. For any extracted service that calls `tournament_monitor.save`, wrap the assertion in the service's test: `assert tournament_monitor.reload.updated_at > 1.second.ago`.
4. Never trust a green test that does not assert database state — especially for models including `ApiProtector`.

**Warning signs:**
- Test passes but `TournamentMonitor.count` does not change
- `tournament_monitor.save` returns false with no errors on `tournament_monitor.errors`
- Extracted service creates a `TournamentMonitor` but subsequent `TournamentMonitor.find(id)` raises `RecordNotFound`

**Phase to address:** Characterization phase — before writing any characterization test for TournamentMonitor, verify the ApiProtector override is active for that class in the test environment.

---

### Pitfall 2: PaperTrail versioning fires conditionally based on server context — extracting Tournament without this breaks sync

**What goes wrong:**
`LocalProtector` calls `has_paper_trail(skip: lambda {...})` only when `carambus_api_url` is NOT present (i.e., on the API server). `ApiProtector` calls `has_paper_trail` only when `carambus_api_url` IS present (i.e., on the local server). This means:
- On the API server, `Tournament` (LocalProtector) generates PaperTrail versions for sync to local servers.
- On the local server, `TournamentMonitor` (ApiProtector) generates PaperTrail versions.
- Neither model versions itself in the wrong context.

When extracting logic from `Tournament` into service objects that call `tournament.save!` directly, every such save on the API server creates a new PaperTrail `Version`. Local servers consume these versions via `Version.update_from_carambus_api`. If extracted services produce additional save calls (e.g., splitting one `save!` into two to separate concerns), they create double versions, which can cause the local server to apply the same logical change twice — producing duplicate records or stale field overwrites.

**Why it happens:**
PaperTrail creates a version on every `save!` call where the `skip:` lambda returns false. The `skip:` lambda skips only when ALL changes are `updated_at` or `sync_date`. Any extraction that splits a multi-field update into sequential saves changes how many versions are created and what each version contains.

**How to avoid:**
1. Before extraction, count the number of `save!`/`update!` calls in each method being extracted. This is the baseline version count per operation.
2. After extraction, add assertions to tests: `assert_difference "tournament.versions.count", 1 do ... end`. If the count changes, the extraction changed the version footprint.
3. When a service must make multiple saves, wrap them in `PaperTrail.request(enabled: false) do ... end` for all but the final authoritative save — or batch all field changes into a single `update!`.
4. Never call `save!` at the end of a service method if the caller will also call `save!` — this double-saves and double-versions.
5. The `skip:` lambda is on `LocalProtector`, not on the model. Extracted services do not bypass it, but they can inadvertently trigger more versions by calling save multiple times.

**Warning signs:**
- Service method ends with `record.save!` AND the caller also calls `record.save!` after the service returns
- `tournament.versions.count` grows faster than expected during a sync operation
- Local server `update_from_carambus_api` job processes the same `tournament_id` twice in quick succession

**Phase to address:** Characterization phase for Tournament — establish version-count baselines for every method before extracting. Enforce via `assert_difference` in extraction tests.

---

### Pitfall 3: AASM's `skip_validation_on_save: true` hides data integrity bugs during extraction

**What goes wrong:**
`Tournament` uses `aasm column: "state", skip_validation_on_save: true`. This means AASM-triggered state transitions call `save!` but skip ActiveRecord validations. The `validates_each :data` validator — which checks `table_ids` for completeness, heterogeneity, and consistency — is bypassed on every state transition. Extracted services that trigger state transitions (e.g., `tournament.finish_seeding!`) will also bypass validations, silently persisting invalid `data` structures.

If a service extracts logic that combines a state transition with a data field update (e.g., seeding calculation + `finish_seeding!`), and the service sets `data[:table_ids]` to an inconsistent value before calling the transition, the validator will not fire and the inconsistency will persist to production.

**Why it happens:**
`skip_validation_on_save: true` is AASM's mechanism for avoiding double validation — it assumes the model was valid before the transition. But it becomes dangerous when extracted services modify `data` as part of the same operation that triggers a transition, because the modification is never validated.

**How to avoid:**
1. Never combine data mutation with state transition in a single service method. Separate them: one service validates and mutates data, a second (or the controller) calls the transition.
2. When characterizing Tournament state transitions, always add an explicit `assert tournament.valid?` after calling `finish_seeding!` or similar — AASM will not raise even if invalid.
3. In extracted services that modify `data`, call `tournament.valid?` before `save!` even when the caller plans to run a transition afterward.

**Warning signs:**
- Service method calls `tournament.finish_seeding!` immediately after `tournament.data[:table_ids] = [...]`
- No test calls `assert tournament.valid?` after a state transition in Tournament
- `validates_each :data` block is not covered by any test

**Phase to address:** Characterization phase for Tournament — add tests that verify validator fires on non-transition saves, and document that transition saves bypass it.

---

### Pitfall 4: `TournamentMonitor#data` JSON blob is the single source of truth for live tournament state — mutations must be atomic

**What goes wrong:**
`TournamentMonitor#data` (serialized JSON hash) stores: groups, placements, rankings, current_round, executor_params results, error messages, and KO bracket state. Multiple methods mutate this hash with `deep_merge_data!` followed by `save!`. The `deep_merge_data!` method does NOT call `save!` itself — it only modifies the in-memory hash and marks it dirty. The `save!` must be called separately.

During extraction, if a service extracts a subset of the data-mutation logic, it may call `deep_merge_data!` but then return without calling `save!`, or conversely, a second service may call `save!` before the first service's changes are merged — overwriting them.

Specifically: `do_reset_tournament_monitor` makes over a dozen sequential `deep_merge_data!` + `save!` pairs. If this is split across services, interleaved saves will cause earlier in-memory merges to be lost when a later `save!` reads the stale record from the database before merging.

**Why it happens:**
`deep_merge_data!` operates on `self.data` in memory. If another `save!` has committed a different version of `data` to the database since the last `reload`, the in-memory merge accumulates on top of stale data. Concurrent processes are not the only risk — sequential service calls in the same request are sufficient to trigger this if one service reads from the database mid-sequence.

**How to avoid:**
1. Treat `data` mutations as a unit: accumulate all changes in memory, then flush once with a single `save!`. Never let two service calls each do `deep_merge_data! + save!` sequentially if either might read from the database in between.
2. If splitting `do_reset_tournament_monitor` into sub-services, pass the in-memory `data` hash through as a parameter rather than letting each service read `tournament_monitor.reload.data`.
3. Add a test that verifies two sequential `deep_merge_data!` calls followed by one `save!` persist both changes correctly — this is the intended usage pattern.
4. If services must each save independently, use pessimistic locking: `TournamentMonitor.lock.find(id)` before each mutation sequence.

**Warning signs:**
- Two extracted services each call `deep_merge_data!` and then `save!` independently
- Service calls `tournament_monitor.reload` before `deep_merge_data!` (correct but signals the caller is not batching)
- Test only verifies final state, not intermediate states, so data loss between saves is invisible

**Phase to address:** TournamentMonitor extraction — establish the data-mutation contract (accumulate in memory, flush once) before splitting any methods.

---

### Pitfall 5: `after_update_commit :broadcast_status_update` in TournamentMonitor fires a Sidekiq job in tests — silently enqueuing jobs that nobody asserts on

**What goes wrong:**
`TournamentMonitor` has `after_update_commit :broadcast_status_update, if: :saved_change_to_state?`. This fires `TournamentStatusUpdateJob.perform_later(tournament)` whenever the AASM `state` column changes. In tests using transactional fixtures (`use_transactional_tests = true`), `after_commit` callbacks do NOT fire, so this job is never enqueued — tests pass without asserting on broadcast behavior. When `use_transactional_tests = false` (as in `TournamentMonitorKoTest`), the job IS enqueued.

If Sidekiq is in `:fake` mode (as configured in test_helper.rb: `Sidekiq::Testing.fake!`), the job accumulates in `Sidekiq::Worker.jobs` without executing. Tests that change `TournamentMonitor` state without draining Sidekiq queues will have orphaned job queue state that pollutes subsequent tests.

Additionally, `TournamentStatusUpdateJob` requires a working `tournament` association. If a test creates a `TournamentMonitor` with a fixture tournament that lacks required associations (discipline, region, season), the job will raise when eventually drained — but since it runs asynchronously in tests, the error appears in a different test's output, making it appear to be that test's fault.

**How to avoid:**
1. For any test that transitions TournamentMonitor state, add: `assert_enqueued_with(job: TournamentStatusUpdateJob) do ... end` when `use_transactional_tests = false`.
2. In teardown for non-transactional tests, drain or clear the Sidekiq queue: `Sidekiq::Worker.clear_all`.
3. When writing characterization tests that exercise AASM transitions on TournamentMonitor, explicitly decide whether to use transactional or non-transactional mode and document the choice.
4. Never assume a green test means "the broadcast fired correctly" — it may mean the transaction wrapper prevented the callback from firing at all.

**Warning signs:**
- `TournamentMonitor` state transitions in tests use `use_transactional_tests = true` (default) — broadcasts are never tested
- No `assert_enqueued_with` or `assert_enqueued_jobs` assertion in any TournamentMonitor test
- Sidekiq job failures appear in a test different from the one that caused them

**Phase to address:** Characterization phase for TournamentMonitor — decide transactional mode before writing tests, document broadcast behavior as explicitly untested if using transactional mode.

---

### Pitfall 6: `TournamentMonitorSupport` and `TournamentMonitorState` live in `lib/` — not autoloaded in all contexts

**What goes wrong:**
The bulk of TournamentMonitor's business logic lives in `lib/tournament_monitor_support.rb` and `lib/tournament_monitor_state.rb`. These are Ruby modules included via `include TournamentMonitorSupport` and `include TournamentMonitorState` in the model. They are loaded because `lib/` is explicitly added to the autoload path (or via `require` at boot), but they are NOT autoloaded by Zeitwerk — they must be `require`d explicitly.

When extracting these into service classes (e.g., moving `populate_tables` into a `TournamentMonitor::PopulateTablesService`), the new service file must be placed either in `app/services/` (Zeitwerk-autoloaded) or `lib/` (require-explicit). If placed in `app/` but still references constants from `lib/` modules, circular load ordering can cause `NameError` in development but not in tests (where the full app is booted before any test runs).

Additionally, the modules reference `Game::MIN_ID`, `Seeding::MIN_ID`, and call `Tournament.logger` — all global constants assumed present. If a service is unit-tested in isolation (stub-first), these constants must be stubbed or the full app must load.

**How to avoid:**
1. Place all extracted services in `app/services/tournament_monitor/` so Zeitwerk handles them. Do not extend the `lib/` pattern to new code.
2. Gradually migrate `TournamentMonitorSupport` and `TournamentMonitorState` methods into services rather than creating new lib modules.
3. Before each service extraction, identify all external constants it references. If more than 3 constants require stubbing for unit tests, the extraction boundary is too fine — coarsen it.
4. Write a smoke test that requires each extracted service file in isolation to detect load-order issues early.

**Warning signs:**
- New service file placed in `lib/` instead of `app/services/`
- Service references `Tournament.logger`, `Game::MIN_ID`, or `Seeding::MIN_ID` without those being passed as arguments
- `NameError` in development but not in tests

**Phase to address:** First TournamentMonitor extraction — establish the file placement convention before extracting any methods.

---

### Pitfall 7: Tournament's dynamic attribute overrides via `define_method` break setter extraction

**What goes wrong:**
`Tournament` dynamically defines getter and setter methods for 12 attributes (`timeouts`, `timeout`, `gd_has_prio`, `admin_controlled`, `auto_upload_to_cc`, `sets_to_play`, `sets_to_win`, `team_size`, `kickoff_switches_with`, `allow_follow_up`, `allow_overflow`, `fixed_display_left`, `color_remains_with_set`) using a `%i[...].each do |meth| define_method(meth)` loop. The getter reads from `tournament_local` if the record is global (id < MIN_ID), otherwise from `read_attribute`. The setter creates or updates `tournament_local` for global records.

These overrides mean `tournament.sets_to_play` does NOT always return `read_attribute(:sets_to_play)`. Any extracted service that calls `tournament.sets_to_play` assumes the dynamic dispatch is transparent. But if a service is tested with a fixture or stub that mocks `sets_to_play` directly on the attribute, while production code routes through `tournament_local`, the service test passes but production behavior differs.

Critically: `initialize_tournament_monitor` in Tournament calls `timeout`, `timeouts`, `innings_goal`, etc. as method calls, not `read_attribute`. If this method is extracted to a service, those calls must still go through the dynamic dispatch chain — the service cannot use `read_attribute` directly.

**How to avoid:**
1. Never use `read_attribute` in extracted service code for any of the 12 dynamically overridden attributes. Always call the method (e.g., `tournament.sets_to_play`, not `tournament.read_attribute(:sets_to_play)`).
2. When writing characterization tests for `initialize_tournament_monitor`, test with both a global tournament (id < MIN_ID, uses `tournament_local`) and a local tournament (id >= MIN_ID, uses direct attribute). Both paths must be covered.
3. In fixtures, ensure the `local` tournament fixture does NOT have a `tournament_local` record, and the `imported` fixture DOES (or the test explicitly creates one) to exercise both paths.

**Warning signs:**
- Extracted service constructor calls `read_attribute(:sets_to_play)` or `[:timeout]` hash access on tournament
- Characterization tests only use local tournament fixtures (id >= MIN_ID), never testing the `tournament_local` delegation path
- `tournament.sets_to_play` returns a different value than `tournament.read_attribute(:sets_to_play)` in a test — the dynamic override is active

**Phase to address:** Characterization phase for Tournament — document all 12 dynamically overridden attributes and ensure both code paths are tested before extraction.

---

### Pitfall 8: `scrape_single_tournament_public` is a 400-line method with multiple HTTP calls — VCR cassette strategy must be planned before extraction

**What goes wrong:**
`scrape_single_tournament_public` makes 4 sequential HTTP requests (tournament page, registration list, results page, ranking page) and interleaves parsing with database writes. VCR cassettes recorded against this method as a whole will not apply cleanly if the method is split into focused services (e.g., `TournamentScraper::RegistrationParser`, `TournamentScraper::ResultsParser`), because VCR matches requests in order against a cassette recorded in a different order.

If cassettes are not re-recorded against the new request sequence, tests silently replay wrong responses — registration data is parsed using the results page cassette, causing silent data corruption in test fixtures.

**How to avoid:**
1. Before any extraction of scraping logic, enumerate the exact URL sequence and HTTP methods made by `scrape_single_tournament_public` using the existing VCR cassettes as documentation.
2. After extraction, re-record ALL cassettes that touch scraping logic. Treat cassette re-recording as mandatory, not optional.
3. Give each extracted scraper service its own cassette, named after the service. Do not share cassettes between services.
4. Add `assert_requested :get, /cc_url/, times: 4` (or whatever the count is) to integration tests so cassette drift is caught immediately.

**Warning signs:**
- VCR cassettes from before extraction are reused without re-recording after extraction
- Scraper service test passes locally but scrapes different data than the pre-extraction test
- No `assert_requested` count assertions in scraping tests

**Phase to address:** Tournament scraping extraction — mandatory cassette re-record step, not optional.

---

### Pitfall 9: AASM `after_enter` callbacks on state entry trigger side effects that must be preserved exactly

**What goes wrong:**
`Tournament` AASM state machine has `after_enter` callbacks on two states:
- `new_tournament, after_enter: [:reset_tournament]` — destroys TournamentMonitor, games, reorders seedings
- `tournament_seeding_finished, after_enter: [:calculate_and_cache_rankings]` — computes and caches player rankings in `data`

`TournamentMonitor` AASM has:
- `new_tournament_monitor, after_enter: [:do_reset_tournament_monitor]` — the 500+ line initialization chain

These are NOT `after_commit` callbacks — they run synchronously inside the state transition, within the same database transaction as the `save!` that triggers the transition. If extracted services are called from these `after_enter` callbacks, and those services call `save!` internally, they create nested saves inside the transition's transaction. This is correct Rails behavior, but it means errors in the service's `save!` will cause the entire state transition to rollback — which may not be the intended behavior if the service's saves are meant to be independent.

Additionally, `reset_tournament` calls `tournament_monitor.destroy` which triggers `TableMonitor#reset_table_monitor` for each associated table monitor. If `reset_tournament` is extracted into a service that calls `tournament_monitor.destroy` outside the transaction context, the cascading resets will fire after the state machine transaction commits — meaning the Tournament state is now `new_tournament` but the TableMonitors are still in their previous state for a brief window.

**How to avoid:**
1. Characterize the exact transaction boundary for each `after_enter` callback before extracting. Use `Tournament.connection.open_transactions` inside the callback to verify the transaction nesting level.
2. If a service's internal `save!` must be independent (not rolled back if the state transition fails), execute it in a separate transaction: `ActiveRecord::Base.transaction(requires_new: true) { service.call }`.
3. The `reset_tournament` → `TournamentMonitor#destroy` → `TableMonitor#reset_table_monitor` cascade must be tested end-to-end before any part is extracted.

**Warning signs:**
- Extracted service contains `save!` and is called from an AASM `after_enter` callback
- Test only verifies the final state of Tournament, not whether TableMonitors were reset
- No test verifies the rollback behavior when `calculate_and_cache_rankings` raises

**Phase to address:** Characterization phase — map all `after_enter` callbacks and their cascades before any extraction.

---

### Pitfall 10: `cattr_accessor :current_admin` and `cattr_accessor :allow_change_tables` on TournamentMonitor leak between tests

**What goes wrong:**
`TournamentMonitor` declares `cattr_accessor :current_admin` and `cattr_accessor :allow_change_tables`. These are class-level variables shared across all instances and all tests in a test run. The `before_all_events` callback reads `current_admin` for authorization decisions. If one test sets `TournamentMonitor.current_admin = admin_user` and does not reset it, subsequent tests that call AASM events will use the polluted `current_admin`, potentially bypassing or triggering authorization guards they should not.

This is the same pattern as v1.0's `TableMonitor.tournament` / `TableMonitor.options` leakage, which was flagged as a critical issue in the original PITFALLS.md.

**How to avoid:**
1. Add to every TournamentMonitor test's teardown: `TournamentMonitor.current_admin = nil; TournamentMonitor.allow_change_tables = nil`.
2. If a `TournamentMonitorSupportHelper` or test helper is created for v2.1, include this teardown automatically.
3. Extracted services must never read `TournamentMonitor.current_admin` directly. Pass the admin user as an argument.
4. Search for all `TournamentMonitor.current_admin = ` call sites before extraction to ensure teardown coverage is complete.

**Warning signs:**
- Tests pass individually but fail in full suite run
- AASM event guard authorization produces unexpected results in later tests
- No `teardown` block in TournamentMonitor test classes that resets class-level accessors

**Phase to address:** Characterization phase — add teardown resets before writing any tests.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keeping `do_reset_tournament_monitor` monolithic | Avoids complex service boundaries | 500+ lines in a single method, untestable in parts | Never — extract incrementally |
| Testing only with local tournament fixtures (id >= MIN_ID) | No `tournament_local` complexity | Dynamic attribute overrides never exercised | Never — both contexts must be tested |
| Reusing VCR cassettes across pre/post extraction | No re-recording cost | Silent mismatched responses; data corruption in tests | Never for scraping logic |
| Calling `save!` at end of extracted service AND in caller | Simple return contract | Double PaperTrail versions; double sync to local servers | Never |
| Using `DEBUG = Rails.env != "production"` in new files | Matches existing pattern | Constant redefinition warnings; always-on DEBUG in test | Never — use Rails.logger.debug |
| Skipping `assert_difference "tournament.versions.count"` | Faster test writing | Version count drift undetected until sync failures | Only for non-LocalProtector models |

---

## Integration Gotchas

Common mistakes when connecting to external services or internal subsystems.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| PaperTrail + LocalProtector | Extracting a method that calls `save!` twice, creating 2 versions instead of 1 | Batch all field changes; single `save!` per logical operation |
| PaperTrail + ApiProtector | Assuming `tournament_monitor.save` succeeded because no exception raised | Always assert `persisted?` after save on ApiProtector models in tests |
| AASM + `skip_validation_on_save: true` | Assuming `finish_seeding!` validates `data` field | Validators are bypassed on AASM saves; validate explicitly in services |
| ActionCable + Sidekiq in tests | Missing job enqueue assertions when `use_transactional_tests = true` | `after_commit` never fires in wrapped transactions; choose the right mode |
| TournamentMonitor + `data` JSON | Calling `deep_merge_data!` in one service, `save!` in another | Always flush `data` in the same service call that merges it |
| `scrape_single_tournament_public` + VCR | Reusing pre-extraction cassettes after splitting HTTP logic | Re-record cassettes per extracted service; never reuse across extraction boundaries |
| `tournament_local` + dynamic `define_method` | Using `read_attribute` in services for overridden attributes | Always call the method accessor, never `read_attribute` for the 12 dynamic attributes |

---

## Performance Traps

Patterns that work at small scale but become problematic.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `tournament.games.where("games.id >= #{Game::MIN_ID}")` repeated in services | N+1 on game count queries per service call | Memoize game scope; pass game collection to services | At 50+ games per tournament (KO finals) |
| `tournament.seedings.where(...).map(&:player)` in `do_reset_tournament_monitor` | Full seedings + players loaded into memory | Use `pluck(:player_id)` if only IDs needed | At 16+ players per tournament |
| PaperTrail version accumulation during scrape | `tournament.versions.count` grows unboundedly | Scope version queries; prune old versions in maintenance jobs | At 100+ scrape cycles per tournament |
| Sequential `save!` in `do_reset_tournament_monitor` | 10+ saves per tournament initialization | Batch into fewer saves or use `update_columns` for non-version-critical fields | Visible at > 5 tournament initializations per minute |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **TournamentMonitor characterization tests:** Verify `ApiProtectorTestOverride` is active for `TournamentMonitor` in the test environment before asserting any saves
- [ ] **Tournament characterization tests:** Baseline `tournament.versions.count` before and after each tested method — verify PaperTrail version count matches expected
- [ ] **AASM extraction:** Verify `whiny_transitions` setting in both Tournament and TournamentMonitor AASM blocks — if absent, add before writing transition tests
- [ ] **Dynamic attribute setters:** Ensure at least one characterization test uses a global tournament (id < MIN_ID) to exercise the `tournament_local` delegation path
- [ ] **Broadcast assertions:** At least one TournamentMonitor test must use `use_transactional_tests = false` to verify `broadcast_status_update` fires correctly
- [ ] **`cattr_accessor` teardown:** Every TournamentMonitor test class must reset `current_admin` and `allow_change_tables` in teardown
- [ ] **Scraping extraction:** VCR cassettes re-recorded after extraction, not reused from pre-extraction captures
- [ ] **Service placement:** All new services in `app/services/tournament/` or `app/services/tournament_monitor/`, not `lib/`
- [ ] **Data flush discipline:** No extracted service calls `deep_merge_data!` without calling `save!` in the same method (or explicitly documented that the caller is responsible)

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Silent ApiProtector rollback discovered late | MEDIUM | Add `persisted?` assertions to all failing tests; patch ApiProtectorTestOverride to cover newly required classes |
| Extra PaperTrail versions causing double-sync on local servers | HIGH | Write a migration to prune duplicate versions; audit `Version.update_from_carambus_api` for idempotency; add version-count assertions to all Tournament tests |
| VCR cassettes not re-recorded after extraction | MEDIUM | Re-record cassettes; run with `VCR_RECORD=all` mode; verify request count assertions |
| AASM silent transition failures from extracted guard | HIGH | Enable `whiny_transitions: true` on all AASM blocks; rerun full suite to find silent no-ops; fix guards to not raise inside guard check |
| `cattr_accessor` test pollution discovered mid-milestone | LOW | Add teardown resets; rerun full suite in random order to confirm isolation |
| `data` JSON overwrites from multi-service saves | HIGH | Roll back to single-service pattern; establish data-mutation contract; add explicit lock on `TournamentMonitor` before any mutation sequence |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| ApiProtector silent rollback (Pitfall 1) | Phase 1: Characterization — TournamentMonitor | Assert `persisted?` after every TournamentMonitor `save` in tests; confirm `ApiProtectorTestOverride` covers class |
| PaperTrail version count drift (Pitfall 2) | Phase 1: Characterization — Tournament | `assert_difference "tournament.versions.count", N` for each method under test |
| AASM `skip_validation_on_save` bypasses validator (Pitfall 3) | Phase 1: Characterization — Tournament | Add explicit `assert tournament.valid?` after transition tests; cover `validates_each :data` |
| `data` JSON mutation atomicity (Pitfall 4) | Phase 2: TournamentMonitor extraction | Service tests verify final `data` state; no service calls `deep_merge_data!` without flushing |
| Broadcast job test pollution (Pitfall 5) | Phase 1: Characterization — TournamentMonitor | Decide transactional mode; add `assert_enqueued_with` or `Sidekiq::Worker.clear_all` |
| `lib/` modules not Zeitwerk-managed (Pitfall 6) | Phase 2: TournamentMonitor extraction | All new services in `app/services/`; smoke test for isolated require |
| Dynamic `define_method` setters (Pitfall 7) | Phase 1: Characterization — Tournament | Tests cover both global (tournament_local) and local (direct attribute) paths |
| Scraping VCR cassettes (Pitfall 8) | Phase 3: Tournament scraping extraction | Mandatory cassette re-record in extraction checklist; `assert_requested` count assertions |
| AASM `after_enter` cascade (Pitfall 9) | Phase 1: Characterization — both models | End-to-end test of `reset_tournament` cascade including TableMonitor state |
| `cattr_accessor` test pollution (Pitfall 10) | Phase 1: Characterization — TournamentMonitor | Teardown resets in all TournamentMonitor test classes; suite runs in random order |

---

## Sources

- Direct code reading: `app/models/tournament.rb` (1775 lines, all sections) — HIGH confidence
- Direct code reading: `app/models/tournament_monitor.rb` (499 lines) — HIGH confidence
- Direct code reading: `lib/tournament_monitor_support.rb`, `lib/tournament_monitor_state.rb` (600+ combined) — HIGH confidence
- Direct code reading: `app/models/local_protector.rb`, `app/models/api_protector.rb` — HIGH confidence
- Direct code reading: `test/test_helper.rb` (ApiProtectorTestOverride implementation and limitation) — HIGH confidence
- Direct code reading: `test/models/tournament_test.rb`, `test/models/tournament_monitor_ko_test.rb` — HIGH confidence
- v1.0 PITFALLS.md (lessons from TableMonitor/RegionCc extraction): `cattr_accessor` leakage, `after_commit` timing, VCR cassette drift, AASM silent failures — HIGH confidence (observed in production)
- `.planning/PROJECT.md` (v1.0 Key Decisions: suppress_broadcast pattern, PORO vs ApplicationService, fixtures-first, ApiProtectorTestOverride rationale) — HIGH confidence

---
*Pitfalls research for: Tournament & TournamentMonitor refactoring (v2.1)*
*Researched: 2026-04-10*
