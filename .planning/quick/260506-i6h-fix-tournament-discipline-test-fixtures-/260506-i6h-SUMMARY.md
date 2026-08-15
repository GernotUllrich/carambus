---
quick_id: 260506-i6h
type: summary
mode: quick-full
status: partial-with-blockers
files_modified:
  - test/fixtures/tournaments.yml
  - test/system/tournament_reset_confirmation_test.rb
  - .planning/todos/pending/2026-04-14-tighten-36b-05-reset-confirmation-system-test-skip-paths.md
    -> .planning/todos/done/2026-04-14-tighten-36b-05-reset-confirmation-system-test-skip-paths.md
commits:
  - 1c291731 - test(260506-i6h-2): repair tournaments(:local) FK rot at fixture level
  - 12652ae2 - test(260506-i6h-4): tighten 36B-05 reset-confirmation tests per 2026-04-14 todo
metrics:
  duration_min: ~18
  tasks_completed: 4
  tasks_partial: 1   # Task 3 of plan: 36B-06 partially un-skipped
---

# Quick 260506-i6h: Fix Tournament/Discipline Test Fixtures — Summary

## One-liner

Repaired tournaments(:local) FK rot at fixture level (organizer/season/discipline/tournament_plan all needed explicit ID columns, not just the planner-anticipated organizer/season pair); 36B-05 reset-confirmation tests fully green (3/3, 10 assertions, 0 skips); 36B-06 verification tests partially un-skipped (Test 2 green; Tests 1+3+4 surfaced TWO real bugs the plan didn't anticipate — one production-affecting PRG flash bug, one fixture-state issue).

## Tasks Completed

### Task 1 — NO-OP (collapsed by orchestrator)

Single `echo` per plan. No work.

### Task 2 — Fix prong A: repair tournaments(:local) FKs

Status: **DONE** with Rule 3 expansion of scope.

**Plan-anticipated fix**: explicit `organizer_id: 50_000_001`, `organizer_type: "Region"`, `season_id: 50_000_001`, `tournament_plan: t04_5`.

**Discovered during execution** (Rule 3 — auto-fix blocking issues): the same fixture-relation-syntax-hashes-the-ID problem ALSO applies to `discipline:` and `tournament_plan:`, NOT just to the polymorphic organizer / season as the plan assumed. Pre-Task-2 inspection in test env via runner script:

```
discipline_id=329867132   # expected 50_000_001 (carom_3band)
tournament_plan_id=849969480   # expected 50_000_100 (t04_5)
```

So `tournaments(:local).discipline` and `.tournament_plan` BOTH returned nil despite the fixture-relation syntax appearing well-formed. This is why the 36B-06 setup-gate (which queries `Tournament.joins(:discipline)... .find { |t| t.discipline&.parameter_ranges&.any? }`) found ZERO eligible tournaments after the planner-prescribed fix — the inner-join would still match (FK exists) but the `t.discipline` reference in the predicate would resolve to a non-existent Discipline record.

**Final fixture diff** (test/fixtures/tournaments.yml :: local):
```diff
-  season: current
-  organizer: nbv (Region)
+  season_id: 50_000_001
+  organizer_id: 50_000_001
   organizer_type: "Region"
-  discipline: carom_3band
+  discipline_id: 50_000_001
+  tournament_plan_id: 50_000_100
```

**Verification**: 144 runs / 309 assertions / 0 failures / 0 errors / 1 pre-existing skip across the 7 enumerated test files (tournament_test, table_monitor_test, tournament_status_update_job_test, tournament_doc_links_test, tournament_monitors_controller_test, tournaments_controller_test, result_recorder_test). No regressions.

**Commit**: `1c291731`

### Task 3 — 36B-06 verification: setup-gate PASSES, tests partially green

Status: **PARTIAL — 3 deviations from "all 3 of tests 1-3 must pass" expectation**.

After Task 2, the setup-gate skip ("no eligible tournament with discipline ranges in fixtures") is ABSENT — the `tournaments(:local)` fixture now correctly resolves discipline/tournament_plan and the gate finds the eligible tournament. This was the primary hidden blocker.

Test results from `bin/rails test test/system/tournament_parameter_verification_test.rb`:

| # | Test | Status | Reason |
|---|------|--------|--------|
| 1 | out-of-range opens verification modal | **FAIL** | Real PRG flash bug — see DEFERRED-BLOCKER-1 below |
| 2 | clicking Cancel keeps tournament un-started | **PASS** | Cancel path doesn't depend on body_text or AASM transition |
| 3 | clicking Confirm starts the tournament with the override | **FAIL** | Real PRG flash bug + AASM state mismatch — see DEFERRED-BLOCKER-1 + DEFERRED-BLOCKER-2 |
| 4 | in-range values skip the modal and start the tournament directly | **FAIL** | AASM state mismatch — see DEFERRED-BLOCKER-2 (planner anticipated this for test 4 only; same blocker hits test 3) |

I did NOT add a documented skip to test 4 (the plan's chosen approach) because doing so would mask DEFERRED-BLOCKER-1 (PRG bug) and DEFERRED-BLOCKER-2 (AASM state) for tests 1+3 too. Per `system_test_caveat`: "If real assertion failure (e.g., the PRG flow has an actual bug), STOP and report rather than papering over." Returning these as findings rather than papering over them is the correct application.

**No commit** — Task 3 left the test file unchanged so the failures remain visible (loud) for the orchestrator + user to triage.

### Task 4 — Tighten 36B-05 reset-confirmation tests

Status: **DONE — fully green**.

Four edits applied to `test/system/tournament_reset_confirmation_test.rb`:

1. **Selector fix** (3 occurrences): `[data-controller='confirmation-modal'].hidden` → `[data-confirmation-modal-target='root'].hidden`. The `.hidden` class lives on the inner root-target div; the controller-scope div uses `display: contents` and is never toggled. The original selector matched ZERO elements.
2. **Drop dead `has_css?` skip** in `visit_tournament_or_skip` (modal partial is per-page-rendered since commit 5ef81ab0).
3. **Convert 500-skip to flunk** so future regressions fail loudly.
4. **Add Stimulus scope assertion** to test 1 (per 2026-04-14 todo step 3): walks DOM ancestors of the reset trigger to assert it lives inside a `data-controller='confirmation-modal'` subtree.

Plus: file-level header rewrite documenting the tightening.

**Verification**: `bin/rails test test/system/tournament_reset_confirmation_test.rb` → **3 runs, 10 assertions, 0 failures, 0 errors, 0 skips**.

**Todo file moved**: `.planning/todos/pending/2026-04-14-tighten-36b-05-reset-confirmation-system-test-skip-paths.md` → `.planning/todos/done/...` with `## Closure` marker appended in-place before the `git mv` (file content modified BEFORE the rename, so history shows the closure on the same blob — per plan's checker-W6 sequencing).

**Commit**: `12652ae2`

## Deviations from Plan

### 1. [Rule 3 - Blocking] Discipline + tournament_plan FK rot scope wider than planned

**Found during**: Task 2.
**Issue**: Plan diagnosed FK rot for `organizer` + `season` (polymorphic / has_many-style fixture-relation labels). It did NOT anticipate that `discipline:` and `tournament_plan:` (plain belongs_to fixture-relation syntax) ALSO get hashed to wrong IDs in test env.
**Fix**: Added `discipline_id: 50_000_001` + `tournament_plan_id: 50_000_100` to the explicit-columns list in the same fixture edit.
**Files modified**: `test/fixtures/tournaments.yml`
**Commit**: `1c291731`

### 2. [DEFERRED-BLOCKER] PRG flash body_text symbol-key bug (test env + cookie session production)

**Found during**: Task 3 (running 36B-06 Test 1 after Task 2 unblocked the setup gate).

**Symptom**: After commit 0ac7305a's PRG redirect, the auto-open confirmation modal renders WITHOUT a body — title is set ("Ungewöhnliche Turnierparameter"), confirm/cancel buttons set, but the failure list (`Bälle-Ziel = 99999 (üblich: 10-150)`) is missing. Test 1 fails on `assert_text "99999"`. Visual proof: `tmp/capybara/failures_test_out-of-range_balls_goal_opens_verification_modal.png` shows an empty modal body.

**Root cause** (verified via direct JSON round-trip test):
1. `app/controllers/tournaments_controller.rb#build_verification_failure_payload` returns `{body_text: "...", failures: [...]}` (Hash with **symbol** keys).
2. The controller stores this via `flash[:verification_failure] = ...` then `redirect_to`.
3. Rails 7.2 default cookie session uses `:json` serializer (verified in test env: `Rails.application.config.action_dispatch.cookies_serializer == :json`).
4. JSON round-trip stringifies symbol keys: `{:body_text=>"..."}` → `"{\"body_text\":\"...\"}"` → `{"body_text"=>"..."}`.
5. View accesses `@verification_failure[:body_text]` (symbol) → returns `nil`.
6. `auto_open_body: nil` is rendered into the partial; modal opens with empty body.

**Production scope**: `config/environments/development.rb:6` explicitly sets `config.session_store :redis_session_store` (Marshal-based, preserves symbols). Production envs (`production-bc-wedel.rb`, `production-carambus-de.rb`, `staging.rb`) and `test.rb` do NOT — they use the default cookie session store with `:json` serializer. **This bug WILL manifest in production for any scenario that has not explicitly configured Redis sessions.**

**Why the verifier missed it**: The verifier's 7/7 must-haves were code-level (PRG redirect path exists, flash key written, view reads flash, etc.). Without the E2E browser run, the JSON round-trip stripping symbol keys was invisible.

**Recommended fix** (NOT applied — per `system_test_caveat` "STOP and report"):
- **Option A** (one-line, defensive): change `auto_open_body: @verification_failure[:body_text]` to `auto_open_body: @verification_failure[:body_text] || @verification_failure["body_text"]` in `app/views/tournaments/tournament_monitor.html.erb:66`. Cheap, but masks the underlying issue.
- **Option B** (idiomatic, narrow): wrap the access via `@verification_failure&.with_indifferent_access&.dig(:body_text)` in the same view line.
- **Option C** (root cause): change `build_verification_failure_payload` (controller line 1028) to return string-keyed hashes: `{ "failures" => failures, "body_text" => ... }`. Then the access stays `@verification_failure["body_text"]` (or use HashWithIndifferentAccess on the controller side). This matches the JSON serializer's contract.

I'd lean toward Option C for clarity (the data IS being serialized through JSON, so embracing string keys is honest about the wire format).

### 3. [DEFERRED-BLOCKER] tournaments(:local) state "registration" is not a valid AASM state for start_tournament!

**Found during**: Task 3 (debugging Test 3 + Test 4 failures).

**Symptom**: After Confirm (Test 3) or in-range (Test 4) submit, the form re-POSTs with `parameter_verification_confirmed=1`. Controller skips the verification gate, calls `@tournament.start_tournament!` (Tournament model line 392). Test asserts `assert_includes STARTED_STATES, @tournament.reload.state` → fails with state still "registration".

**Root cause** (verified via runner): `:registration` is NOT a defined AASM state for `Tournament`:
```
AASM events: [:finish_seeding, :finish_mode_selection, :start_tournament!, :signal_tournament_monitors_ready, :reset_tmt_monitor, :forced_reset_tournament_monitor, :finish_tournament, :have_results_published]
Defined states: [:new_tournament, :accreditation_finished, :tournament_seeding_finished, :tournament_mode_defined, :tournament_started_waiting_for_monitors, :tournament_started, :tournament_finished, :results_published, :closed]

t.start_tournament!  # raises AASM::UndefinedState: State :registration doesn't exist
```

The AASM event `start_tournament!` only transitions from `tournament_started`, `tournament_mode_defined`, `tournament_started_waiting_for_monitors`. The `:local` fixture's "registration" state is undefined for AASM, so the call raises and the transaction rolls back. State stays "registration".

The plan's Task 3 assumed test 4 would fail due to "missing seedings + table assignments + executor_params" — but the actual root cause is much earlier: the fixture starts in an INVALID AASM state, so `start_tournament!` can't even be called regardless of seedings.

**Production scope**: This is a TEST-ONLY blocker. Production tournaments transition through finish_seeding → finish_mode_selection (which sets state to `tournament_mode_defined`) before the operator clicks "Start". The `:local` fixture has no setup path for those upstream transitions.

**Recommended fix** (NOT applied — per `system_test_caveat`):
- **Option A** (fixture-only, narrow): change `:local` fixture's state from `"registration"` to `"tournament_mode_defined"`. Side-effects to evaluate: `tournaments_controller_test.rb`'s reset-modal test asserts un-started state (which is games-based, not state-string-based — likely OK); the 36B-05 tests we just landed (uses `tournaments(:local)` for the reset modal — also games-based, likely OK). Other consumers (table_monitor_test, etc.) primarily use `:local` as a parent FK — likely OK.
- **Option B** (test-side): in 36B-06's setup, after the eligible-fixture lookup, force the state via `update_columns(state: "tournament_mode_defined")` before `visit_monitor_or_skip`. Doesn't affect other test files.
- **Option C** (defer): per the plan's Task 3 prescription, mark tests 3 + 4 explicitly `skip` with a documented marker pointing to "tournaments(:local) needs both AASM state buildup AND seedings/tables for end-to-end happy path". This loses E2E coverage of the Confirm-leg of the PRG flow.

## Test 4 in-range deferral status

The plan's Task 3 chose **Option (b) Explicit skip with marker** for test 4 only. After this execution, that decision must be expanded: **tests 3 AND 4 BOTH need the deferred-skip treatment** (or DEFERRED-BLOCKER-2 fixed). Test 1 needs DEFERRED-BLOCKER-1 fixed.

I did not apply any skip markers because doing so would conceal the discovered bugs.

## Files Changed

```
.planning/todos/{pending=>done}/2026-04-14-tighten-36b-05-reset-confirmation-system-test-skip-paths.md  (renamed + closure marker)
test/fixtures/tournaments.yml                       | +14 -3
test/system/tournament_reset_confirmation_test.rb   | +47 -15
```

Total: **3 files changed, 76 insertions(+), 21 deletions(-)** across **2 commits**.

**No `app/` files modified** — extend-before-build SKILL honored. (The PRG bug fix for DEFERRED-BLOCKER-1 would be a small `app/views/tournaments/tournament_monitor.html.erb` edit, but is out of scope per `system_test_caveat`.)

## Final Test Run Snapshot

```
$ bin/rails test test/system/tournament_parameter_verification_test.rb test/system/tournament_reset_confirmation_test.rb
7 runs, 20 assertions, 3 failures, 0 errors, 0 skips
```

| File | Runs | Assertions | Failures | Errors | Skips |
|------|------|-----------|----------|--------|-------|
| tournament_reset_confirmation_test.rb (36B-05) | 3 | 10 | 0 | 0 | 0 |
| tournament_parameter_verification_test.rb (36B-06) | 4 | 10 | 3 | 0 | 0 |

Pre-existing comparison set:
```
$ bin/rails test test/models/tournament_test.rb test/models/table_monitor_test.rb test/jobs/tournament_status_update_job_test.rb test/controllers/tournaments_controller_test.rb test/services/table_monitor/result_recorder_test.rb
144 runs, 309 assertions, 0 failures, 0 errors, 1 skip (pre-existing)
```

## Follow-ups for Orchestrator + User

### Critical (production-affecting, decision needed)

1. **DEFERRED-BLOCKER-1 (PRG flash body_text symbol-key bug)** — production cookie-session scenarios will display empty modal bodies on parameter verification. Needs a small fix (1-3 lines in view OR controller). See "Recommended fix" options above. Should be a separate quick task once user/orchestrator picks the option.

2. **DEFERRED-BLOCKER-2 (tournaments(:local) state "registration")** — TEST-ONLY blocker for 36B-06 Tests 3 + 4. Needs decision between:
   - (A) change fixture state to `"tournament_mode_defined"` (universal fix, evaluate side effects on consumer tests),
   - (B) test-local `update_columns` in 36B-06 setup (narrow, no side effects),
   - (C) document skip on tests 3 + 4 (loses E2E coverage of Confirm-leg).

### Cleanup (separate task)

3. After this fixture FK repair landed, the per-test workaround `update_columns` blocks in `test/controllers/tournaments_controller_test.rb:69-79` and `test/controllers/tournament_doc_links_test.rb:~37` are now redundant (they re-write columns to the same values they already hold). Cleanup is harmless — recommend a separate quick task to remove them and update the explanatory comments.

4. The `wc_2024`, `wc_no_end_date`, `imported`, `scraped` fixtures in `test/fixtures/tournaments.yml` still use the broken fixture-relation syntax (`season: current`, `organizer: nbv (Region)`, `discipline: carom_3band` / `pool_8ball`). These haven't manifested as visible bugs because consumers don't rely on the resolved associations — but the fixture rot remains. Recommend a follow-up to harmonize all fixtures to explicit IDs (low priority — defense in depth).

## Self-Check: PASSED

Files exist on disk:
- `test/fixtures/tournaments.yml`: FOUND (FK columns present)
- `test/system/tournament_reset_confirmation_test.rb`: FOUND (4 edits applied; 3/3 tests green)
- `.planning/todos/done/2026-04-14-tighten-36b-05-reset-confirmation-system-test-skip-paths.md`: FOUND (closure marker appended)

Commits exist:
- `1c291731`: FOUND in `git log`
- `12652ae2`: FOUND in `git log`
