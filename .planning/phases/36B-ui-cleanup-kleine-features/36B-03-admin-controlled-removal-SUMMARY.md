---
phase: 36B-ui-cleanup-kleine-features
plan: 03
subsystem: tournament-lifecycle
tags: [ui, reflex, model, test, gate, cleanup, ui-03]

requires:
  - phase: 36B-ui-cleanup-kleine-features
    provides: "36B-CONTEXT.md decisions D-09, D-10, D-11, D-12"
  - phase: 36B-ui-cleanup-kleine-features
    plan: 02
    provides: "tournaments.monitor_form.labels.admin_controlled + tournaments.monitor_form.tooltips.admin_controlled i18n keys (kept intentionally unused for D-11 reversibility); admin_controlled row left un-tooltip-wrapped so plan 03 can delete it cleanly"
provides:
  - "Tournament#player_controlled? unconditional-true gate (auto-advance is the single source of truth)"
  - "Tournament parameter form without an admin_controlled checkbox row"
  - "TournamentReflex without an admin_controlled live-update handler"
  - "Minitest regression coverage asserting the new gate semantics against admin_controlled in {true, false, nil}"
affects:
  - "Phase 36c and beyond — any caller reading tournament.player_controlled? now sees `true` unconditionally; no call-site updates needed because every known caller already branches on the return value"
  - "Future schema cleanup phase — admin_controlled column drop is deferred (D-11); when it happens, the attribute-delegation block and the now-unused YAML keys can be pruned together"

tech-stack:
  added: []
  patterns:
    - "UI-retirement without schema drop: UI input path + Reflex handler + behavioral gate removed, column and delegation block left intact for read-compatibility with global (id < MIN_ID) records"
    - "TDD RED→GREEN inside a single plan: test asserts new semantics before the implementation flip; RED documented in the plan commit trail via the green-after-flip commit"

key-files:
  created: []
  modified:
    - "app/views/tournaments/tournament_monitor.html.erb"
    - "app/reflexes/tournament_reflex.rb"
    - "app/models/tournament.rb"
    - "test/models/tournament_test.rb"

key-decisions:
  - "D-09 honored: admin_controlled checkbox removed from tournament_monitor.html.erb + matching key removed from TournamentReflex::ATTRIBUTE_METHODS"
  - "D-10 honored: player_controlled? unconditionally returns true with an explicit German-language comment explaining the new contract"
  - "D-11 honored: admin_controlled column NOT dropped, attribute-delegation block at tournament.rb:239 intact, create_tournament_local(admin_controlled: ...) at :254 intact, before_save persistence block at :321 intact, and the tournaments.monitor_form.{labels,tooltips}.admin_controlled YAML keys (from plan 02) were left in place as intentional dead data"
  - "D-12 honored: no fixture that sets admin_controlled was touched; the new gate simply ignores the column value"

patterns-established:
  - "Feature-retirement pattern: remove UI input + Reflex handler + behavioral gate first, leave column and delegation for a later post-milestone cleanup phase — gives us one decision per phase and avoids data migration risk"
  - "Fixture-based model unit test for pure-method gate semantics: use tournaments(:local), mutate the in-memory attribute, assert the predicate — no persist, no LocalProtector interaction, no DB round-trip"

requirements-completed: [UI-03]

duration: ~8 min
completed: 2026-04-14
---

# Phase 36B Plan 03: Admin-Controlled Removal Summary

**Retired the manual round-change feature: checkbox gone from the Turnier-Monitor parameter form, Reflex handler removed, and `Tournament#player_controlled?` now unconditionally returns `true` while the schema column stays put for global-record read compatibility.**

## Performance

- **Duration:** ~8 min (execution)
- **Tasks:** 2 (both executed)
- **Files created:** 0
- **Files modified:** 4 (ERB view, Reflex, model, model test)
- **New lines:** 19 (test block + replacement comment in player_controlled?)
- **Deleted lines:** 3 (ERB row, hash key, old method body)

## Accomplishments

- **UI-03 delivered:** The manual round-change feature is fully retired from the UI layer. Tournament managers can no longer toggle `admin_controlled` via the monitor parameter form, the live-update Reflex handler that used to accept the checkbox change is gone, and the load-bearing gate method `Tournament#player_controlled?` now hard-returns `true`, so auto-advance is the single source of truth for round transitions.
- **D-11 reversibility preserved:** Zero schema changes, zero migrations. The `admin_controlled` column is still present (`t.boolean :admin_controlled, default: false, null: false` per the Schema Information block at tournament.rb:12). Attribute-delegation at tournament.rb:239 still includes `:admin_controlled`, `create_tournament_local(admin_controlled: read_attribute(:admin_controlled), ...)` at :254 still mirrors it to TournamentLocal, and the before_save persistence block at :321 still writes it to `data`. If a future phase needs to re-introduce a manual-control feature (hooking it to a different UX, e.g. a referee-console button), the underlying column, attribute list, and even the `tournaments.monitor_form.{labels,tooltips}.admin_controlled` i18n keys (from plan 02) are all still in place.
- **TDD coverage:** The new Minitest test `test "player_controlled? always returns true regardless of admin_controlled (UI-03 D-10)"` asserts the gate is unconditional against `admin_controlled` values `true`, `false`, and `nil`. Uses the `tournaments(:local)` fixture (id 50_000_001) and mutates the in-memory attribute only — no persist, so LocalProtector is irrelevant and the test is purely pure-method.
- **Tooltip count invariant held:** Before this plan, the monitor form had exactly 16 `data-controller="tooltip"` triggers (plan 02 deliberately skipped the admin_controlled row to avoid inter-plan coupling). After this plan, the count is still exactly 16 — the deleted row had no tooltip wrapper to begin with.

## Task Commits

Each task committed atomically on master with pre-commit hooks enabled (no `--no-verify`).

1. **Task 1: Remove admin_controlled checkbox row from ERB + Reflex hash key** — `f9e8c805` (feat)
   - Deleted the `<div class="flex flex-row space-x-4 items-center">...</div>` row in `tournament_monitor.html.erb` (formerly the 5th row in the "Turnier Parameter" block).
   - Deleted `admin_controlled: "B",` from `TournamentReflex::ATTRIBUTE_METHODS` at `tournament_reflex.rb:35`. The `define_method` loop at :50-72 iterates over the hash, so removing the key automatically drops the `admin_controlled` handler without touching the loop.
   - `grep -c admin_controlled app/views/tournaments/tournament_monitor.html.erb` → 0
   - `grep -c admin_controlled app/reflexes/tournament_reflex.rb` → 0
   - `grep -c data-controller=.tooltip. app/views/tournaments/tournament_monitor.html.erb` → 16 (exact, unchanged)
   - `grep -c ATTRIBUTE_METHODS app/reflexes/tournament_reflex.rb` → 3 (declaration + `ATTRIBUTE_METHODS.keys.each` + `ATTRIBUTE_METHODS[attribute]` lookup inside the loop)

2. **Task 2: Simplify player_controlled? gate + add Minitest coverage** — `9d71aafe` (feat, TDD RED→GREEN)
   - **RED:** added the test block to `test/models/tournament_test.rb`, ran `bin/rails test test/models/tournament_test.rb -n "/player_controlled/"` — observed the expected failure `player_controlled? must ignore admin_controlled=true` (the old gate was `!admin_controlled?`, which returned `false` when `admin_controlled: true`).
   - **GREEN:** replaced the method body in `app/models/tournament.rb:381-384` with an unconditional `true` and a 4-line German-language comment explaining the new contract (auto-advance is the einheitliche Default, Spalte bleibt für Kompatibilität mit globalen Records). Re-ran the full test file — 4 runs, 11 assertions, 0 failures, 0 errors, 0 skips.
   - Committed both the test and the implementation in a single commit (classical TDD would split them; here they're bundled because the plan calls for one Task 2 commit and the RED state is documented in the commit trail via this summary).

## Files Modified

- **Modified** `app/views/tournaments/tournament_monitor.html.erb` — deleted 3 lines (one full `<div class="flex flex-row space-x-4 items-center">...</div>` row wrapping the admin_controlled checkbox). The remaining 16 parameter rows are untouched.
- **Modified** `app/reflexes/tournament_reflex.rb` — deleted 1 line from the `ATTRIBUTE_METHODS` hash. The remaining 16 keys (innings_goal, timeouts, balls_goal, timeout, auto_upload_to_cc, continuous_placements, gd_has_prio, kickoff_switches_with, allow_follow_up, allow_overflow, color_remains_with_set, fixed_display_left, sets_to_play, sets_to_win, time_out_warm_up_first_min, time_out_warm_up_follow_up_min) are still present and still auto-registered via the `define_method` loop.
- **Modified** `app/models/tournament.rb` — replaced the 3-line body of `player_controlled?` (line 381-384) with 6 lines: an unconditional `true` plus a 4-line German comment. The attribute-delegation block at line 239, the `create_tournament_local(..., admin_controlled: read_attribute(:admin_controlled), ...)` call at line 254, and the before_save persistence block at line 321 are ALL intact (D-11).
- **Modified** `test/models/tournament_test.rb` — added a new `test "player_controlled? always returns true regardless of admin_controlled (UI-03 D-10)"` block at the end of `class TournamentTest`, 20 lines, uses `tournaments(:local)` fixture.

## Verification Results

- `grep -c admin_controlled app/views/tournaments/tournament_monitor.html.erb` → **0** (expected 0) ✓
- `grep -c admin_controlled app/reflexes/tournament_reflex.rb` → **0** (expected 0) ✓
- `grep -c ATTRIBUTE_METHODS app/reflexes/tournament_reflex.rb` → **3** (declaration + `.keys.each` + hash access inside loop) ✓
- `grep -c "data-controller=.tooltip." app/views/tournaments/tournament_monitor.html.erb` → **16** (unchanged from plan 02) ✓
- `grep -c "data-tooltip-content-value" app/views/tournaments/tournament_monitor.html.erb` → **16** (unchanged from plan 02) ✓
- `grep -c "def player_controlled" app/models/tournament.rb` → **1** ✓
- `grep -c "!admin_controlled" app/models/tournament.rb` → **0** (the negation expression is gone) ✓
- `grep -c "admin_controlled" app/models/tournament.rb` → **5** (schema comment line 12, attribute-delegation list line 239, `create_tournament_local` kwarg line 254, before_save whitelist line 321, and one more reference) — meets "≥ 4" ✓
- `grep -c 'player_controlled. always returns true' test/models/tournament_test.rb` → **1** ✓
- `bin/rails test test/models/tournament_test.rb` → **4 runs, 11 assertions, 0 failures, 0 errors, 0 skips** ✓
- `ruby -c app/reflexes/tournament_reflex.rb` → Syntax OK ✓
- `bundle exec standardrb app/reflexes/tournament_reflex.rb` → 32 pre-existing problems (all lines 167+, unrelated to ATTRIBUTE_METHODS block). Baseline-verified via `git stash && standardrb && git stash pop` — identical count, my change introduces zero new issues.
- `bundle exec standardrb app/models/tournament.rb` → 84 pre-existing problems (all lines 554+, unrelated to `player_controlled?` at line 381). Baseline-verified — identical count, my change introduces zero new issues.
- `bundle exec erblint app/views/tournaments/tournament_monitor.html.erb` → 7 pre-existing errors (1 `Extra blank line` on line 20 inside `<style>`, 6 `autocomplete attribute missing` on `number_field_tag` lines). Baseline unchanged from plan 02.

## Decisions Made

- **TDD RED→GREEN bundled into Task 2 commit, not split** — the plan only defines one commit per task, so the test addition and the method change land together in `9d71aafe`. The RED state was verified live before the implementation change (see "Task 2" above); documenting it in this summary preserves the TDD trail.
- **Kept the D-11 YAML keys from plan 02 untouched** — `tournaments.monitor_form.labels.admin_controlled` and `tournaments.monitor_form.tooltips.admin_controlled` in both `de.yml` and `en.yml` are now unused dead keys. Removing them would cause YAML churn and potentially conflict with plan 02's work; per D-11 they stay as intentional ballast for reversibility. A post-milestone docs-cleanup pass can prune them across all locales in a single sweep.
- **Did not touch `app/views/tournament_monitors/_current_games.html.erb:133,135`** — those lines read `tm.player_controlled?` and branch on the return value. After my change, `player_controlled?` is always true, so the "OK?" confirmation path is always taken and the `I18n.t('table_monitor.status.wait_check')` fallback path becomes dead code. This is the intended auto-advance UX per D-10; pruning the dead branch is out of scope for UI-03.

## Deviations from Plan

**None — plan executed exactly as written. No Rule 1/2/3 auto-fixes triggered. No Rule 4 checkpoint needed.**

## Issues Encountered

**None.** Both tasks landed cleanly on master with pre-commit hooks enabled. No parallel-wave contamination (plan 03 is wave-2, sequential, single-executor). No test regressions.

## Known Stubs

**None.** The plan retires a feature rather than introducing one; no placeholder rendering, no mock data, no unwired components.

## Threat Flags

**None.** No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. The plan's threat register (T-36b03-01 through T-36b03-04) was addressed in-scope:
- T-36b03-01 (Tournament auto-advances unexpectedly) — mitigated via D-10: the gate is unconditional, the UI input path is gone, and the Minitest unit test asserts the new semantics. Manual UAT in carambus_bcw remains a user-owned follow-up.
- T-36b03-02 (Stale admin_controlled=true blocks auto-advance) — impossible after this plan: the Reflex handler that used to accept the checkbox change is removed, and the gate ignores the column value.
- T-36b03-03 (Schema drift from keeping the column) — accepted per D-11: leaving the column is a deliberate reversibility choice, not a bug.
- T-36b03-04 (Unused i18n keys remain in YAML) — accepted per D-11: removing them would churn plan 02's work.

## Self-Check: PENDING (verified below)

Verifying claims before finalizing:

1. **Files modified exist in master:**
   - `app/views/tournaments/tournament_monitor.html.erb` — modified in commit `f9e8c805` ✓
   - `app/reflexes/tournament_reflex.rb` — modified in commit `f9e8c805` ✓
   - `app/models/tournament.rb` — modified in commit `9d71aafe` ✓
   - `test/models/tournament_test.rb` — modified in commit `9d71aafe` ✓

2. **Commits exist on master:**
   - `f9e8c805` (Task 1) — FOUND via `git log --oneline -3` ✓
   - `9d71aafe` (Task 2) — FOUND via `git log --oneline -3` ✓

3. **Test suite green:**
   - `bin/rails test test/models/tournament_test.rb` → 4 runs, 11 assertions, 0 failures, 0 errors ✓

## Self-Check: PASSED

## Next Plan Readiness

- **Plan 36B-06 (parameter-verification-modal) / any follow-up in this phase** can proceed cleanly. The Turnier-Monitor parameter form now has 16 parameter rows (all with i18n labels, 16 with tooltips) and no admin_controlled checkbox. The `start_tournament_path` form-submit path is unchanged.
- **No blockers.** All existing tournament_test.rb tests still pass. Standard and erblint baselines unchanged.

---
*Phase: 36B-ui-cleanup-kleine-features*
*Plan: 03-admin-controlled-removal*
*Completed: 2026-04-14*
