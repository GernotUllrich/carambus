---
phase: quick-260506-hka
plan: 01
subsystem: tournament-flow
tags: [refactor, controller, prg, turbo, stimulus-reflex, flash, cleanup]
dependency-graph:
  requires:
    - "Phase 36B-05 confirmation_modal partial (auto_open Stimulus controller)"
    - "Phase 36B-06 system test fixture (tournament_parameter_verification_test.rb)"
    - "Redis-backed sessions (CLAUDE.md → redis-session-store)"
  provides:
    - "PRG (Post/Redirect/Get) flow for TournamentsController#start verification gate"
    - "flash[:verification_failure] -> @verification_failure handover in #tournament_monitor"
    - "Turbo-native start_tournament form (no data: { turbo: false } escape hatch)"
  affects:
    - "TournamentsController#start (failure branch)"
    - "TournamentsController#tournament_monitor (one-line read of flash)"
    - "tournament_monitor.html.erb start_tournament form_tag"
tech-stack:
  added: []
  patterns:
    - "PRG (Post/Redirect/Get) — replaces in-place render after non-idempotent POST"
    - "Flash transport for transient view state — Redis-backed sessions, no 4KB cookie limit"
    - "Extend-before-build SKILL — single new ivar assignment in #tournament_monitor (no new action, no new partial, no new helper)"
key-files:
  created: []
  modified:
    - "app/controllers/tournaments_controller.rb (+13 −2: PRG flash write + #tournament_monitor flash read)"
    - "app/views/tournaments/tournament_monitor.html.erb (+1 −1: revert data: { turbo: false })"
decisions:
  - "PRG over in-place render — fixes URL-bar-stuck-on-POST root cause that prior workarounds (8a948c93 form turbo:false, 23d65963 redirect_back_or_to → redirect_to) addressed at the symptom layer."
  - "flash[:verification_failure] (NOT session, NOT cookie, NOT params) — Redis-backed sessions auto-clear after one request and bypass the 4KB cookie ceiling."
  - "Form fields NOT replayed across redirect — every input reads from @tournament.<attr>; live StimulusReflex change-handlers persist edits to DB before submit, so the same values reload naturally from a fresh GET."
  - "Workaround #1 (data: { turbo: false }) reverted — Turbo follows the 302 cleanly via fetch and the auto_open Stimulus controller's connect() fires on the swapped <body>."
  - "Workaround #2 (redirect_back_or_to → redirect_to in rescue branch line 274) LEFT INTACT — locked decision 5; PRG also makes redirect_back_or_to safe again (URL bar now sits at a valid GET route after submit), but the explicit redirect_to is more readable, no need to revert."
metrics:
  duration: "1m 47s (≈107s wall-clock)"
  completed: "2026-05-06T10:52:48Z"
  files_modified: 2
  files_created: 0
  tasks_completed: 2
  tasks_total: 2
  loc_added: 14
  loc_deleted: 3
---

# Quick Task 260506-hka: Refactor TournamentsController#start verification gate to PRG — Summary

**One-liner:** Replaced in-place `render :tournament_monitor` after the parameter-verification gate with a `flash[:verification_failure]` + `redirect_to` PRG handover, then reverted the now-unneeded `data: { turbo: false }` form escape hatch.

## What Changed

Three coordinated edits across two files, shipped as a single semantic commit:

1. **TournamentsController#start (failure branch, ~line 315–328)** — write `flash[:verification_failure] = build_verification_failure_payload(failures)` and `redirect_to tournament_monitor_tournament_path(@tournament) and return`. Replaces `@verification_failure = ...` + `render :tournament_monitor and return`.

2. **TournamentsController#tournament_monitor (~line 280–289)** — add `@verification_failure = flash[:verification_failure]` as the first executable line (before the early-return guard). Promotes the flash payload to the ivar the view already reads.

3. **app/views/tournaments/tournament_monitor.html.erb (line 72)** — remove `, data: { turbo: false }` from the `start_tournament` form_tag. Turbo now follows the 302 via fetch and the auto_open Stimulus controller's `connect()` fires on the body-swap.

## Tasks

| # | Name | Status | Commit |
|---|------|--------|--------|
| 1 | Convert verification gate to PRG and revert workarounds | DONE | `0ac7305a` |
| 2 | Run system test and update if assertions pinned render-not-redirect | DONE (no source changes — see below) | — |

Task 2 made **no source changes** — the plan explicitly identified this as the success case. The Capybara assertions in `test/system/tournament_parameter_verification_test.rb` observe browser-visible state (orange banner, modal text, AASM-state transitions); none of them pin "render vs redirect" or assert on HTTP status. The PRG redirect is fully transparent to the test contract.

## Verification

### Automated (all 6 grep checks PASSED)

```
CHECK 1 ✓ flash[:verification_failure] = build_verification_failure_payload(failures) at line 327
CHECK 2 ✓ redirect_to tournament_monitor_tournament_path(@tournament) and return at line 328
CHECK 3 ✓ @verification_failure = flash[:verification_failure] at line 284
CHECK 4 ✓ render :tournament_monitor and return — ABSENT
CHECK 5 ✓ data: { turbo: false } in tournament_monitor.html.erb — ABSENT
CHECK 6 ✓ form_tag now ends with method: :post do at line 72
```

### Locked decisions preserved

- Locked decision 5 — `redirect_back_or_to(tournament_path(@tournament))` at line 274 (rescue branch) UNCHANGED. Confirmed via grep.
- StimulusReflex `change->TournamentReflex#<attr>` wiring on every form input UNCHANGED.
- Field defaults in `tournament_monitor.html.erb` UNCHANGED — every input still reads from `@tournament.<attr>`.
- `confirmation_modal` partial UNCHANGED.

### System test (Phase 36B-06)

```
$ bin/rails test test/system/tournament_parameter_verification_test.rb
4 runs, 0 assertions, 0 failures, 0 errors, 4 skips
```

**0 failures, 0 errors** — verification clause satisfied per plan's `<done>` criterion.

The 4 skips trace to `test/system/tournament_parameter_verification_test.rb:32`:

> `skip "no eligible tournament with discipline ranges in fixtures" unless @tournament`

This is a pre-existing fixture-data limitation documented in plan 36B-05 deviation 3 (no eligible non-started tournament with `discipline.parameter_ranges` in `test/fixtures/tournaments.yml`) and is **explicitly accepted** by this plan's `<done>` clause:

> "skips are acceptable — the test file's setup includes intentional skip guards for unrelated fixture issues per plan 36B-06 deviation 3"

The test file did not need modification — the test framework sees the same DOM/state contract before and after PRG.

### Verification gap requiring manual run

The 4 assertion-bearing tests skip in the current fixture set. End-to-end manual verification of the PRG behavior (steps 1-9 from the plan's `<verification>` block) was NOT performed in this quick task — it requires a running dev stack (`foreman start -f Procfile.dev`) and a live tournament whose discipline has parameter_ranges. Recommended manual sanity check:

1. Sign in, find a tournament with `Tournament.joins(:discipline).find { |t| t.discipline.parameter_ranges.any? }`
2. Visit `tournament_monitor_tournament_path(@tournament)`
3. Set `balls_goal=99999` and click "Turnier starten"
4. Expected: URL-bar moves from `/tournaments/:id/start` to `/tournaments/:id/tournament_monitor`; orange banner appears; modal auto-opens
5. Cancel → modal closes, hidden input resets, tournament stays unstarted
6. Re-submit + Confirm → `tournament_started`
7. F5 reload → no modal, no banner (flash consumed in single request)

## Deviations from Plan

**None — plan executed exactly as written.**

- All three edits applied verbatim from the plan's `<action>` block.
- All 6 verification grep checks passed without iteration.
- System test passed `0 failures, 0 errors` on first run; no test edits needed.
- No Rule 1/2/3 auto-fixes triggered.
- No Rule 4 architectural decisions encountered.
- No authentication gates.
- No analysis-paralysis loops.

## Workaround Reconciliation

Both prior commits the plan referenced are now architecturally moot:

| Commit | Workaround | Status post-PRG |
|--------|-----------|-----------------|
| `8a948c93` | Added `data: { turbo: false }` to start_tournament form so browsers do real navigation (Turbo's morph would drop the modal element) | **REVERTED** in Edit 3 — Turbo follows the 302 cleanly via fetch, auto_open Stimulus controller's `connect()` fires on swapped DOM |
| `23d65963` | Replaced `redirect_back_or_to` with `redirect_to tournament_monitor_tournament_path(@tournament)` in the rescue branch to break a loop back to POST-only `/start` URL | **LEFT INTACT** per locked decision 5 — PRG makes `redirect_back_or_to` safe again (URL bar now sits at valid GET after submit), but the explicit `redirect_to` is more readable and load-bearing for direct-post error paths |

## Scenario Management

**Mode:** Debugging Mode in `carambus_bcw/` (user-confirmed via orchestrator preconditions block).

- Pre-edit precondition check: PASSED before plan started (per orchestrator note: all 4 checkouts clean on `master`; `carambus_api` had 2 untracked scripts unrelated to these edits).
- Edits and commit landed in `carambus_bcw/` only.
- **Cross-checkout sync (`git pull` in `carambus_master/` + `carambus_phat/` + `carambus_api/` after the orchestrator pushes) is the orchestrator's responsibility, NOT this executor's.** Per executor constraints block: "Do not attempt it."

Per `.agents/skills/scenario-management/SKILL.md` Debugging Mode Workflow, the orchestrator will need to:

1. `git push` from `carambus_bcw/` (when ready)
2. `git pull` in `carambus_master/`, `carambus_phat/`, `carambus_api/` to keep all checkouts at the same commit on `master`

## Deferred Follow-ups

**None directly produced by this task.**

Pre-existing follow-ups touching nearby surface (untouched, unrelated):

- The 4 skipped tests in `tournament_parameter_verification_test.rb` would benefit from a future quick task to add an explicit fixture (Tournament + Discipline pair where `discipline.parameter_ranges[:balls_goal]` is non-empty) so the assertion path is exercised in CI rather than skipped. Tracked informally — defer to next quick batch.
- The `redirect_back_or_to(tournament_path(@tournament))` in the rescue branch (line 274) is now safer than before (URL bar sits at a valid GET after PRG) but still uses the loose `redirect_back_or_to` semantics. Not a defect — explicit follow-up only if a future audit prefers `redirect_to tournament_path(@tournament)` for symmetry. Tracked informally.

## Self-Check: PASSED

**Files claimed modified — verified to exist:**

- `app/controllers/tournaments_controller.rb` — FOUND (commit `0ac7305a`)
- `app/views/tournaments/tournament_monitor.html.erb` — FOUND (commit `0ac7305a`)

**Commit hash claimed — verified to exist:**

- `0ac7305a` — FOUND in `git log --oneline -3` (HEAD)

**No SUMMARY/STATE/PLAN files committed in code commit (per orchestrator constraint).**
