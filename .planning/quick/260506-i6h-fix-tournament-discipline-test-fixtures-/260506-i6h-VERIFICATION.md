---
phase: 260506-i6h-fix-tournament-discipline-test-fixtures
verified: 2026-05-06T11:47:41Z
status: human_needed
score: 9/9 must-haves verified (planned-scope) + 2 DEFERRED-BLOCKERs surfaced beyond plan scope
overrides_applied: 0
human_verification:
  - test: "DEFERRED-BLOCKER-1 — PRG flash body_text symbol-key bug (PRODUCTION-AFFECTING)"
    expected: "After clicking Start with out-of-range value, the auto-opening confirmation modal renders WITH the failure body text (e.g., 'Bälle-Ziel = 99999 (üblich: 10-80)'), not just title + buttons. In production cookie-session deployments today the modal renders with an EMPTY body."
    why_human: |
      Decision required: pick a fix path AND scope. The bug is real, reproducible, and affects production
      (only carambus_bcw development.rb sets redis_session_store + Marshal-equivalent; production-bc-wedel.rb,
      production-carambus-de.rb, staging.rb, and test.rb all fall back to Rails default cookie store with
      :json serializer in Rails 7.2). Behaviour:

        app/controllers/tournaments_controller.rb:1028-1040 (build_verification_failure_payload):
          returns { failures: [...], body_text: "..." } — symbol keys
        flash[:verification_failure] = payload  →  redirect (PRG)
        cookie store JSON-serializes for round-trip  →  symbol keys become strings
        app/views/tournaments/tournament_monitor.html.erb:66:
          auto_open_body: @verification_failure[:body_text]  →  nil (key is now "body_text")

      The view already accesses other keys correctly elsewhere (consistent symbol access). The fix is
      one-sided — either coerce on read in the view, or write strings on the controller side.

      Fix options (executor's recommendations):
        Option A (defensive one-liner in view):
          auto_open_body: @verification_failure[:body_text] || @verification_failure["body_text"]
          Lowest risk, masks underlying contract mismatch.
        Option B (with_indifferent_access in view):
          @verification_failure&.with_indifferent_access&.dig(:body_text)
          Idiomatic, narrow, but adds a copy.
        Option C (root-cause: string keys at the source — RECOMMENDED by executor):
          Change build_verification_failure_payload (controller line 1028) to return
          { "failures" => failures, "body_text" => ... } AND update the view access to "body_text".
          Honest about the wire format (data IS being JSON-serialized through the cookie session).

      Routing recommendation:
        - SHORT-TERM: open a new quick task to apply Option C (one-line controller change + one-line
          view change). Block of work: <30 min including a regression test that round-trips a hash
          through the same flash mechanism.
        - LONG-TERM (NOT recommended): revert commit 0ac7305a (the entire PRG refactor). The PRG flow
          is sound architecturally; only the symbol-key contract is wrong. Reverting trades a
          1-line bug for losing all PRG benefits.

      Planning gap to acknowledge: the original PLAN locked a "Redis sessions, no 4KB issue"
      assumption from the brainstorm without re-reading the production environment files. A pre-flight
      grep `grep -ln session_store config/environments/` would have caught this in 30 seconds.

  - test: "DEFERRED-BLOCKER-2 — tournaments(:local) state \"registration\" not in AASM state list (TEST-ONLY)"
    expected: "After Confirm or in-range submit, start_tournament! transitions the tournament from a valid pre-start state to tournament_started or tournament_started_waiting_for_monitors. Currently raises AASM::UndefinedState: State :registration doesn't exist (verified during execution; reproduces today)."
    why_human: |
      Decision required: pick a fix scope.

      Tournament AASM states (app/models/tournament.rb:271-281):
        new_tournament (initial), accreditation_finished, tournament_seeding_finished,
        tournament_mode_defined, tournament_started_waiting_for_monitors, tournament_started,
        tournament_finished, results_published, closed.
      "registration" is NOT in this list. start_tournament! transitions from
        [tournament_started, tournament_mode_defined, tournament_started_waiting_for_monitors] only.

      Production has no analogue — real tournaments transition through finish_seeding → finish_mode_selection
      (state := tournament_mode_defined) before the operator clicks Start. The fixture diverges from
      production reality.

      Fix options (executor's recommendations):
        Option A (universal fixture fix):
          test/fixtures/tournaments.yml :: local  →  state: "tournament_mode_defined"
          Side-effects to evaluate: tournament_reset_confirmation_test.rb still passes (uses games-based
          tournament_started? predicate, not state-string), table_monitor_test / result_recorder_test
          use :local as parent FK only. Likely safe but worth a re-run.
        Option B (test-local fixture massage):
          In TournamentParameterVerificationTest#setup, after the eligible-fixture lookup,
          `@tournament.update_columns(state: "tournament_mode_defined")` before visit.
          Narrowest blast radius; doesn't help any other test that wants this fixture in a startable
          state. RECOMMENDED by executor for least-disruption.
        Option C (defer with skip):
          Mark tests 3 + 4 explicitly `skip` with a documented marker citing this AASM gap.
          Loses E2E coverage of Confirm-leg + in-range-leg of the PRG flow.

      Routing recommendation:
        Bundle Option B with the DEFERRED-BLOCKER-1 fix into a single follow-up quick task. After both
        land, re-run `bin/rails test test/system/tournament_parameter_verification_test.rb` and expect
        4/4 green, 0 skips — which validates the entire PRG refactor (commit 0ac7305a) end-to-end
        through real Selenium browser flow.

      Planning gap to acknowledge: plan-checker iteration 1 identified test 4's AASM dependency and
      the revision picked "explicit skip with marker" — but test 3 hits the same blocker and the
      plan didn't notice. Both Confirm and in-range paths invoke start_tournament! AASM. This was
      catchable with a 5-line runner check at plan-time:
        Tournament.find(50_000_001).aasm.may_start_tournament!?
---

# Quick 260506-i6h: Fix Tournament/Discipline Test Fixtures — Verification Report

**Phase Goal:** Fix Tournament/Discipline test fixtures so 36B-06 verification system tests un-skip and exercise the new PRG flow end-to-end; tighten 36B-05 reset confirmation test per the 2026-04-14 todo.

**Verified:** 2026-05-06T11:47:41Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Plan-Scope must_haves)

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | Tournament show page renders 200 in test env for `tournaments(:local)` | ✓ VERIFIED | 36B-05 file runs all 3 tests against `tournament_path(@tournament)` with no flunk on the 500-guard branch (3 runs / 10 assertions / 0 failures) |
| 2 | Tournament monitor page renders 200 in test env for `tournaments(:local)` | ✓ VERIFIED | 36B-06 setup-gate finds eligible tournament, `visit_monitor_or_skip` proceeds past 500-check (4 runs, no skip on the 500-text branch — failures are downstream of monitor rendering) |
| 3 | Setup gate at `tournament_parameter_verification_test.rb:32` finds at least one Tournament whose Discipline has non-empty `parameter_ranges` and which is in a non-started state | ✓ VERIFIED | All 4 tests of 36B-06 execute (the setup-gate skip "no eligible tournament with discipline ranges in fixtures" is ABSENT from the run output) |
| 4 | Tests 1-3 in `tournament_parameter_verification_test.rb` execute with 0 skips against the new redirect-based verification path | ✓ VERIFIED | 0 skips in 36B-06 run (4 runs / 10 assertions / 3 failures / 0 errors / **0 skips**). The plan asked for "execute, no skips" — that's what landed. The failures are real bugs (DEFERRED-BLOCKER-1, -2), not skips |
| 5 | Test 4 in `tournament_parameter_verification_test.rb` is EITHER green OR explicitly skipped with documented marker | ⚠ DEVIATION (justified) | Executor chose neither option — left it FAIL (loud) per `system_test_caveat` "STOP and report rather than paper over". This is the correct call: skipping would mask DEFERRED-BLOCKER-2 which also breaks test 3. See `human_verification` items |
| 6 | All 3 modal-flow tests in `tournament_reset_confirmation_test.rb` execute (no skips) | ✓ VERIFIED | `bin/rails test test/system/tournament_reset_confirmation_test.rb` → 3 runs / 10 assertions / 0 failures / 0 errors / **0 skips** (re-verified by verifier) |
| 7 | All `[data-controller='confirmation-modal'].hidden` assertions in `tournament_reset_confirmation_test.rb` rewritten to `[data-confirmation-modal-target='root'].hidden` | ✓ VERIFIED | File reads at lines 88, 94, 107 — all use the corrected root-target selector. `grep "data-controller='confirmation-modal'\\].hidden"` returns zero matches in the file |
| 8 | The `has_css?` modal-presence skip in `visit_tournament_or_skip` is removed | ✓ VERIFIED | File `test/system/tournament_reset_confirmation_test.rb:47-56` shows the rewritten `visit_tournament_or_skip` — no `has_css?` branch, only the 500-guard which `flunk`s |
| 9 | The 500-error skip path replaced by `flunk` so future regressions are loud | ✓ VERIFIED | Line 51: `flunk "tournament show page rendered 500 — fixture or view regression. ..."` |

**Score:** 9/9 plan-scope truths verified (1 with documented justified deviation on truth #5)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `test/fixtures/tournaments.yml` :: local | `tournament_plan: t04_5` AND explicit `organizer_id: 50_000_001 / organizer_type / season_id: 50_000_001` | ✓ VERIFIED + RULE-3 EXPANSION | Lines 43-66 of fixture: `season_id: 50_000_001`, `organizer_id: 50_000_001`, `organizer_type: "Region"`, `discipline_id: 50_000_001`, `tournament_plan_id: 50_000_100`, `state: "registration"`. Executor expanded scope per Rule 3 to also include explicit `discipline_id` and `tournament_plan_id` (the planner had `discipline: carom_3band` + `tournament_plan: t04_5` fixture-relation syntax; turns out that hashes wrong too). Net: stronger fix than planned, all FK rot eradicated for `:local`. |
| `test/system/tournament_reset_confirmation_test.rb` | Tightened per 2026-04-14 todo | ✓ VERIFIED | All 4 edits applied (3 selector fixes lines 88/94/107; `has_css?` skip removed lines 47-56; 500-skip → flunk line 51; Stimulus scope assertion lines 67-81; header rewrite lines 1-19). |
| Todo file moved to `done/` with closure marker | `.planning/todos/done/2026-04-14-tighten-36b-05-reset-confirmation-system-test-skip-paths.md` | ✓ VERIFIED | File present in `done/`, absent from `pending/`. Closure marker at the bottom: `## Closure` block with date, fix reference, and key-changes list — appended in-place before `git mv` so history shows closure on the same blob (per plan checker-W6 sequencing). |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `tournaments(:local)` | `tournament_plans(:t04_5)` (id 50_000_100) | `tournament_plan_id: 50_000_100` | ✓ WIRED | Explicit ID column in fixture (executor expanded vs. planner's fixture-relation syntax) |
| `tournaments(:local)` | `regions(:nbv)` (id 50_000_001) | `organizer_id: 50_000_001 + organizer_type: "Region"` | ✓ WIRED | Explicit ID columns in fixture |
| `tournaments(:local)` | `seasons(:current)` (id 50_000_001) | `season_id: 50_000_001` | ✓ WIRED | Explicit ID column in fixture |
| `tournaments(:local)` | `disciplines(:carom_3band)` | `discipline_id: 50_000_001` | ✓ WIRED (Rule 3 expansion) | Executor discovered planner's `discipline: carom_3band` hashes wrong; replaced with explicit ID |
| `tournaments(:local).discipline.parameter_ranges` | `Discipline::DISCIPLINE_PARAMETER_RANGES["Dreiband"]` | `Discipline#parameter_ranges` | ✓ WIRED | Setup gate now finds eligible tournament (no setup-gate skip in 36B-06 output) |
| Setup gate query in `tournament_parameter_verification_test.rb:28-32` | tournaments(:local) | inner join + `parameter_ranges&.any?` predicate | ✓ WIRED | All 4 tests of 36B-06 enter their bodies (skip is absent) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| 36B-05 modal flow tests pass end-to-end | `bin/rails test test/system/tournament_reset_confirmation_test.rb` | 3 runs / 10 assertions / 0 failures / 0 errors / 0 skips | ✓ PASS |
| 36B-06 system tests un-skip and run real assertions | `bin/rails test test/system/tournament_parameter_verification_test.rb` | 4 runs / 10 assertions / 3 failures / 0 errors / 0 skips | ✓ PASS (un-skip goal met; failures are surfaced bugs, not test infrastructure issues) |
| Regression spot-check: tournaments_controller_test still green after fixture change | `bin/rails test test/controllers/tournaments_controller_test.rb` | 56 runs / 118 assertions / 0 failures / 0 errors / 0 skips | ✓ PASS |
| Both task commits exist in history | `git log --oneline` for `1c291731`, `12652ae2` | Both present in `git log --oneline -5` output | ✓ PASS |
| Todo file landed in `done/` not `pending/` | `ls .planning/todos/done/ \| grep tighten-36b-05` AND `ls .planning/todos/pending/` | Found in done/, absent from pending/ | ✓ PASS |
| Closure marker present in moved todo | `grep "## Closure"` on the moved file | Block present with date + reference + key-changes | ✓ PASS |
| Production env files do NOT set redis_session_store (DEFERRED-BLOCKER-1 root cause) | `grep -ln session_store config/environments/` | Only `development.rb` matches; `production-bc-wedel.rb`, `production-carambus-de.rb`, `staging.rb`, `test.rb` use Rails default cookie store | ✓ CONFIRMED (this is what makes DEFERRED-BLOCKER-1 production-affecting) |
| AASM state list does NOT include `:registration` (DEFERRED-BLOCKER-2 root cause) | Read `app/models/tournament.rb:271-281` | States: new_tournament, accreditation_finished, tournament_seeding_finished, tournament_mode_defined, tournament_started_waiting_for_monitors, tournament_started, tournament_finished, results_published, closed. **No `:registration`.** | ✓ CONFIRMED |
| `build_verification_failure_payload` returns symbol-keyed hash (DEFERRED-BLOCKER-1 mechanism) | Read `app/controllers/tournaments_controller.rb:1028-1040` | Returns `{ failures: failures, body_text: ... }` — Ruby symbol keys, will stringify under JSON serializer | ✓ CONFIRMED |
| View accesses `:body_text` symbol key (DEFERRED-BLOCKER-1 manifestation point) | Read `app/views/tournaments/tournament_monitor.html.erb:66` | `auto_open_body: @verification_failure[:body_text]` — symbol access; will return `nil` after JSON round-trip | ✓ CONFIRMED |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (none in plan-scope deliverables) | — | — | — | Executor did not modify any `app/` code. extend-before-build SKILL honored. No new TODO/FIXME/placeholders introduced. |
| `app/controllers/tournaments_controller.rb` | 1036-1039 | Symbol-keyed hash flowing into Rails flash + JSON cookie session round-trip | 🛑 Blocker (production-affecting, surfaced by this task but originated in commit 0ac7305a) | DEFERRED-BLOCKER-1 — empty modal body in production |
| `test/fixtures/tournaments.yml` :: local | 63 | `state: "registration"` does not match any AASM state | 🛑 Blocker for 36B-06 tests 3+4 | DEFERRED-BLOCKER-2 — start_tournament! cannot transition |

(The two anti-patterns above are NOT in code modified by this task — they are pre-existing issues that the now-running tests have surfaced. They appear here as findings for the human verification section, not as gaps in this quick task's deliverable.)

### Human Verification Required

See frontmatter `human_verification` section above for the two DEFERRED-BLOCKERs with full root-cause analysis, fix options, and routing recommendations.

**Summary for the user:**

1. **DEFERRED-BLOCKER-1 (production-affecting, decision needed):** The PRG handshake from commit `0ac7305a` is broken in production — modal renders with empty body. One-line fix (Option C: change controller to return string keys + view to read string keys). Recommend a follow-up quick task. Do NOT revert commit 0ac7305a — the PRG architecture is sound.

2. **DEFERRED-BLOCKER-2 (test-only, decision needed):** Fixture `state: "registration"` is invalid for AASM. Recommend Option B (test-local `update_columns` in 36B-06 setup) — narrowest blast radius, no side effects on other tests. Bundle with DEFERRED-BLOCKER-1 fix.

3. **After both fixes land:** Re-run `bin/rails test test/system/tournament_parameter_verification_test.rb` and expect 4/4 green, 0 skips — validating the entire PRG refactor end-to-end before push.

### Gaps Summary

**No gaps in plan-scope deliverables** — all 9 plan must_haves are verified, with one justified deviation (truth #5: executor left test 4 FAIL instead of skip-with-marker, correctly applying `system_test_caveat`).

**Two DEFERRED-BLOCKERs surfaced beyond plan scope:**

- **DEFERRED-BLOCKER-1 (PRG flash JSON serializer mismatch — PRODUCTION-AFFECTING):** Originated in upstream commit `0ac7305a`. The plan inherited a "Redis sessions, no 4KB issue" assumption from the brainstorm without re-checking production env config. Catchable in 30 seconds with `grep session_store config/environments/`. Effect: modal renders with empty body in production cookie-session deployments. Fix is 1-2 lines (executor recommends Option C — controller-side string keys).

- **DEFERRED-BLOCKER-2 (fixture AASM state mismatch — TEST-ONLY):** Plan-checker iteration 1 caught test 4's AASM dependency but missed that test 3 hits the same blocker. Plan revision picked "skip-with-marker for test 4 only" without noticing test 3. Fix is 1 line (executor recommends Option B — test-local `update_columns`).

**The right next step is a NEW follow-up quick task** that bundles both fixes (~30 min of work, including a regression-guard test that round-trips a hash through the flash mechanism). After it lands, the entire 36B-06 file goes 4/4 green, validating commit `0ac7305a`'s PRG refactor before user push.

**Status decision rationale:** Per Step 9 decision tree, this is `human_needed`:
- Step 9.1 (gaps_found) does NOT apply — no plan-scope gaps; the surfaced blockers are real bugs in upstream code that the plan-scope tests now correctly expose.
- Step 9.2 (human_needed) applies — Step 8 produced 2 critical items requiring human triage: which fix option to pick for each, and whether to bundle into a single follow-up or split.
- The "passed" path is unavailable because human_verification is non-empty.

The executor did exactly the right thing per `system_test_caveat`: STOPPED at the surfaced bugs and reported them rather than papering over. This verification confirms that and routes the decision to the user.

---

_Verified: 2026-05-06T11:47:41Z_
_Verifier: Claude (gsd-verifier)_
