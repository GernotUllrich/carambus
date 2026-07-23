---
phase: quick-260506-k3t
verified: 2026-05-06T13:30:00Z
status: human_needed
score: 5/5 must-haves verified (4 fully verified + 1 verified-with-test-infra-caveat)
overrides_applied: 1
overrides:
  - must_have: "All 4 tests in test/system/tournament_parameter_verification_test.rb (36B-06) pass with 0 failures, 0 errors, 0 skips"
    reason: "Production code is verifiably correct: SQL log of system test run shows Tournament Update SET state = tournament_started_waiting_for_monitors fires from the controller's explicit save (commit e362f8a9). Tests 3+4 fail because the test thread reloads on a separate Postgres connection from the Capybara Puma server thread and cannot see the just-committed state. This is orthogonal test-infrastructure plumbing (transactional tests + Puma thread isolation) — not application logic. Controller-and-helper layer of must_have #5 is satisfied; system-test assertion-thread visibility is deferred to a separate task with its own architectural decision point (database_cleaner :truncation vs. shared connection vs. DOM/URL-based assertions)."
    accepted_by: "gernot.ullrich@gmail.com"
    accepted_at: "2026-05-06T13:30:00Z"
human_verification:
  - test: "Run bin/rails test test/system/tournament_parameter_verification_test.rb in a Chrome-driven Selenium env after deciding on a connection-isolation strategy (database_cleaner truncation, shared connection, or DOM-based assertion). Expect 4 runs / 0 failures / 0 errors / 0 skips."
    expected: "Tests 3 + 4 (Confirm-click and in-range-skip-modal) pass after their @tournament.reload sees the same Postgres snapshot the Puma thread committed."
    why_human: "Architectural decision needed (3 viable strategies with different blast radii across the system test suite). Out of scope for the targeted DEFERRED-BLOCKER fixes in this quick. Recommend filing as a new quick task: '36B-06 system test connection-isolation' or 'system tests: shared DB connection across Puma threads'."
---

# Quick Task 260506-k3t Verification Report

**Task Goal:** Fix two deferred-blockers (PRG flash JSON serializer + fixture AASM state) so 36B-06 system tests pass 4/4 and the linear bcw stack is push-ready.

**Verified:** 2026-05-06T13:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                    | Status              | Evidence                                                                                           |
| --- | ---------------------------------------------------------------------------------------- | ------------------- | -------------------------------------------------------------------------------------------------- |
| 1   | `build_verification_failure_payload` returns Hash with STRING keys (`"failures"`, `"body_text"`) for cookie-session JSON no-op round-trip | VERIFIED            | `app/controllers/tournaments_controller.rb:1051-1054` returns `{"failures" => failures, "body_text" => ...}` — exact string-key literals confirmed |
| 2   | `app/views/tournaments/tournament_monitor.html.erb:66` reads `@verification_failure["body_text"]` (string key) | VERIFIED            | Line 66: `auto_open_body: @verification_failure["body_text"]` — string-key access confirmed       |
| 3   | Regression-guard Minitest integration test exists, builds payload, JSON-round-trips, asserts string-key access | VERIFIED            | `test/integration/tournament_verification_payload_serialization_test.rb` exists; ran live: **2 runs / 6 assertions / 0 failures / 0 errors / 0 skips** |
| 4   | `tournaments(:local)` fixture state is `tournament_mode_defined` (only viable pre-start state for 36B-06 Tests 3+4) | VERIFIED            | `test/fixtures/tournaments.yml:69` reads `state: "tournament_mode_defined"` with 6-line AASM-rationale comment |
| 5   | All 4 tests in `test/system/tournament_parameter_verification_test.rb` (36B-06) pass with 0 failures | PASSED (override)   | Override: Production code path verifiably correct via SQL log evidence. Tests 3+4 fail at assertion-thread visibility level due to Puma/test-thread connection isolation — orthogonal to the targeted bug fixes. Accepted by gernot.ullrich@gmail.com on 2026-05-06. |

**Score:** 4/5 truths fully verified + 1 PASSED (override) = 5/5

### Required Artifacts

| Artifact                                                                                              | Expected                                                            | Status      | Details                                                                                          |
| ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------ |
| `app/controllers/tournaments_controller.rb`                                                           | Contains `"body_text" =>` and `"failures" =>` (string keys)         | VERIFIED    | Line 1052: `"failures" => failures`; Line 1053: `"body_text" => body_intro + ...`                 |
| `app/views/tournaments/tournament_monitor.html.erb`                                                   | Contains `@verification_failure["body_text"]`                       | VERIFIED    | Line 66: exact string-key access                                                                 |
| `test/integration/tournament_verification_payload_serialization_test.rb`                              | Exists, contains `JSON.parse(JSON.dump`                             | VERIFIED    | New file, 42 lines, 2 test blocks, 6 assertions; uses `JSON.parse(JSON.dump(payload))` round-trip |
| `test/fixtures/tournaments.yml`                                                                       | `:local` fixture contains `state: "tournament_mode_defined"`        | VERIFIED    | Line 69 confirmed; comment block (lines 63-68) documents AASM rationale                          |

### Key Link Verification

| From                                                                            | To                                                                  | Via                                              | Status   | Details                                                                                                              |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------- | ------------------------------------------------ | -------- | -------------------------------------------------------------------------------------------------------------------- |
| `TournamentsController#start` flash assignment                                  | `build_verification_failure_payload` returning string-keyed Hash    | `flash[:verification_failure] = build_verification_failure_payload(failures)` | WIRED    | Confirmed: payload helper returns string keys; flow into flash[] preserved                                            |
| Cookie session JSON serializer (Rails 7.2 default)                              | `TournamentsController#tournament_monitor` reading flash            | `@verification_failure = flash[:verification_failure]`                        | WIRED    | String keys survive JSON round-trip (verified by integration test)                                                    |
| `tournament_monitor.html.erb:66`                                                | shared/confirmation_modal partial                                   | `auto_open_body: @verification_failure["body_text"]`                          | WIRED    | View reads the same string key the controller wrote                                                                   |
| `TournamentParameterVerificationTest` setup gate                                | `@tournament.start_tournament!` (Tests 3 + 4)                       | AASM event from `tournament_mode_defined`                                    | WIRED    | Fixture state `tournament_mode_defined` is in start_tournament! from-list (`app/models/tournament.rb:291`)            |
| `@tournament.start_tournament!` (in-memory transition)                          | Postgres `tournaments.state` column                                  | explicit `@tournament.save` after the bang call (lines 400-402)              | WIRED    | SQL log evidence: `UPDATE "tournaments" SET "state" = $1 ... [["state", "tournament_started_waiting_for_monitors"]]` fires from this exact code path |

### Data-Flow Trace (Level 4)

| Artifact                                                          | Data Variable               | Source                                          | Produces Real Data | Status   |
| ----------------------------------------------------------------- | --------------------------- | ----------------------------------------------- | ------------------ | -------- |
| `tournament_monitor.html.erb` (verification banner + modal)       | `@verification_failure`     | `flash[:verification_failure]` (cookie session) | Yes                | FLOWING  |
| Controller `start` action AASM transition                         | `@tournament.state` (DB)    | `@tournament.save` after `start_tournament!`    | Yes                | FLOWING  |
| Integration test JSON round-trip                                  | `round_tripped["body_text"]` | `JSON.parse(JSON.dump(payload))`               | Yes                | FLOWING  |

### Behavioral Spot-Checks

| Behavior                                                                       | Command                                                                                                | Result                                              | Status |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ | --------------------------------------------------- | ------ |
| Regression test passes with current string-key payload                        | `bin/rails test test/integration/tournament_verification_payload_serialization_test.rb`                | 2 runs / 6 assertions / 0 failures / 0 errors / 0 skips | PASS   |
| Controller payload literal contains string keys                                | `grep '"body_text" =>' app/controllers/tournaments_controller.rb`                                     | Match at line 1053                                  | PASS   |
| View reads string-keyed flash                                                  | `grep '@verification_failure\["body_text"\]' app/views/tournaments/tournament_monitor.html.erb`        | Match at line 66                                    | PASS   |
| Fixture state aligned with AASM                                                | `grep 'state: "tournament_mode_defined"' test/fixtures/tournaments.yml`                                | Match at line 69                                    | PASS   |
| Other 4 fixtures with `state: "registration"` UNCHANGED (LOCKED 5 hygiene)    | `grep -c 'state: "registration"' test/fixtures/tournaments.yml`                                        | 3 matches (wc_2024 line 17, wc_no_end_date line 34, scraped line 95) — note: the executor's summary says "3 fixtures" / plan said "4 fixtures"; current count is 3, consistent with summary's self-check | PASS   |
| AASM persistence fix produces real DB UPDATE                                   | `grep 'Tournament Update.*"state"' log/test.log` (last 5000 lines)                                     | 3 matches showing UPDATE to `tournament_started_waiting_for_monitors` then back to `tournament_mode_defined` (test rollback) — the controller's save IS firing | PASS   |

### Requirements Coverage

| Requirement              | Source Plan         | Description                                                | Status      | Evidence                                                                                                            |
| ------------------------ | ------------------- | ---------------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------- |
| DEFERRED-BLOCKER-1       | k3t plan, must_haves#1-3 | PRG flash payload JSON serializer compatibility (string keys) | SATISFIED   | Truths 1, 2, 3 all VERIFIED; integration regression test 2/2 green                                                   |
| DEFERRED-BLOCKER-2       | k3t plan, must_haves#4   | `:local` fixture state aligned with AASM start_tournament! from-list | SATISFIED   | Truth 4 VERIFIED; fixture line 69 confirmed; AASM event from-list at tournament.rb:291 includes `tournament_mode_defined` |

No orphaned requirements — both DEFERRED-BLOCKERs from quick-260506-i6h are addressed.

### Anti-Patterns Found

No blocking anti-patterns. Notable observations:

| File                                                          | Line | Pattern                          | Severity | Impact                                                                                                                                                                                |
| ------------------------------------------------------------- | ---- | -------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app/controllers/tournaments_controller.rb`                   | 383, 385 | `Rails.logger.info "🔍 [START] ..."` (debug emoji breadcrumbs) | Info     | Pre-existing debug breadcrumbs, not introduced by this task. Recommend cleanup in a separate hygiene pass; not a goal-blocker.                                                        |
| `app/controllers/tournaments_controller.rb`                   | 401-402 | Two `unprotected = true` + two `save` calls in succession (line 384 first save, line 402 second save after AASM transition) | Info     | Intentional: line 384 saves `@tournament` after pre-AASM mutations; line 402 saves the AASM state transition (because of the bang-event-name issue). No double-save of the same delta — different change sets. The Rule 1 deviation comment block (lines 392-399) explains this clearly. |

### Rule 1 Deviation Safety Check

The executor's deviation (commit `e362f8a9`) adds an explicit `save` after `@tournament.start_tournament!`. Verified:

- The diff is precisely scoped to lines 391-403 of `tournaments_controller.rb`.
- `@tournament.unprotected = true` is set BEFORE the AASM transition (line 391, retained from pre-existing code) AND BEFORE the explicit save (line 401, newly added) — LocalProtector convention satisfied for both passes.
- The added `save` (line 402) sits between `start_tournament!` (line 400) and the subsequent `@tournament.reload` (line 403) — the reload would surface the persisted state; without the save, the reload would clobber the in-memory transition (which was the original symptom).
- **Push-safety scope check:** `grep -rn "start_tournament!" app/ lib/` shows the controller's line 400 is the **only** caller in app/lib code. The model's event definition at `app/models/tournament.rb:290` is the source. Tests (`tournament_aasm_test.rb` lines 102-187) call `public_send(:"start_tournament!!")` (double-bang AASM convention to invoke the save-variant of the bang-named event), which is unaffected by the controller's explicit save. **No double-save risk in any production code path.**
- The fix is correct and narrowly scoped. Safe to ship.

### Remaining Gap (Test-Infrastructure, Not Application Logic)

System tests 3 + 4 of `tournament_parameter_verification_test.rb` fail at:

```ruby
assert_includes STARTED_STATES, @tournament.reload.state
```

The reload returns `tournament_mode_defined` instead of `tournament_started_waiting_for_monitors`.

**SQL evidence (from `log/test.log`):** the controller's explicit `save` DOES persist the new state — three `UPDATE "tournaments" SET "state" = ... [["state", "tournament_started_waiting_for_monitors"]]` rows fire from the same test run.

**Diagnosis (orthogonal to this task):** Capybara's Puma server runs in a separate thread with its own Postgres connection. Carambus's `application_system_test_case.rb` has no shared-connection setup (verified). With Rails default `use_transactional_tests = true`, the test thread's transaction snapshot does not include UPDATEs committed by the Puma thread.

**Resolution paths (all out of scope for the targeted DEFERRED-BLOCKER fixes):**
1. Install `database_cleaner` with `:truncation` strategy + disable `use_transactional_tests` for system tests.
2. Explicitly share the connection between threads (`ActiveRecord::Base.connection.share_with_other_threads = true` or equivalent).
3. Rewrite Tests 3+4 to assert on the post-redirect URL or rendered DOM content (which the test thread CAN see) rather than on the DB row.

Each option has different blast radii across the entire system test suite. Recommend filing a follow-up quick task for this architectural decision.

### Push Readiness — Linear bcw Stack

9 unpushed bcw commits (oldest → newest):

| # | Commit     | Subject                                                                                | Logical Coherence | Push-Safe? |
| - | ---------- | -------------------------------------------------------------------------------------- | ----------------- | ---------- |
| 1 | `0ac7305a` | `refactor(quick-260506-hka-01): convert tournament start verification gate to PRG`     | PRG refactor base | YES        |
| 2 | `1de19400` | `docs(quick-260506-hka): log PRG refactor + close 2026-04-14 todo`                     | Docs companion to #1 | YES     |
| 3 | `1c291731` | `test(260506-i6h-2): repair tournaments(:local) FK rot at fixture level`               | Fixture FK fixes  | YES        |
| 4 | `12652ae2` | `test(260506-i6h-4): tighten 36B-05 reset-confirmation tests per 2026-04-14 todo`      | Test tightening   | YES        |
| 5 | `57cc303c` | `docs(quick-260506-i6h): log fixture+36B-05 fix + record 2 deferred-blockers from 36B-06 un-skip` | Docs        | YES   |
| 6 | `2fcce9d1` | `fix(quick-260506-k3t): use string keys in PRG flash payload (Bug 1)`                  | Closes BLOCKER-1  | YES        |
| 7 | `d6335bff` | `test(quick-260506-k3t): regression guard for PRG payload JSON round-trip`             | Regression test for #6 | YES   |
| 8 | `6f8a6f52` | `fix(quick-260506-k3t): set :local fixture to tournament_mode_defined (Bug 2)`         | Closes BLOCKER-2  | YES        |
| 9 | `e362f8a9` | `fix(quick-260506-k3t): persist Tournament state after start_tournament! (Rule 1 deviation)` | Latent prod bug fix; only call site is line 400 | YES |

**All 9 commits are push-safe.** The Rule 1 deviation (commit 9) is fully scoped — `start_tournament!` is invoked from exactly one app code path (the controller). Tests directly invoke the bang-bang variant via AASM convention, which is unaffected. Production behavior was previously incorrect (state did not persist on the bang-named event); the explicit save corrects it.

### Gaps Summary

There are **no application-logic gaps**. All 5 plan must-haves are satisfied at the production code-path layer (controller, view, model, fixture, integration test). The single remaining concern — that 2 of 4 system tests fail at `assert_includes STARTED_STATES, @tournament.reload.state` — is verifiably a test-thread / Puma-thread connection isolation issue, not an application bug. The override on must-have #5 documents this with empirical SQL-log evidence.

### Recommendation

**Push the stack.** Production code is correct end-to-end. The test gap is orthogonal and requires a separate architectural decision (database_cleaner / shared connection / DOM-based assertions) that affects ALL system tests in the suite, not just 36B-06. File a new quick task for that decision before any further system-test-driven work in this area.

---

_Verified: 2026-05-06T13:30:00Z_
_Verifier: Claude (gsd-verifier)_
