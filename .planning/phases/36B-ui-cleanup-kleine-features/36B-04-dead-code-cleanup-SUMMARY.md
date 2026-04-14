---
phase: 36B
plan: 04
subsystem: tournament-monitor-ui
tags: [cleanup, dead-code, erb, git-rm, ui-04, ui-05]
requirements: [UI-04, UI-05]
dependency_graph:
  requires:
    - "Phase 33 canonical wizard partial audit (_wizard_steps_v2 is the only render target)"
    - "Phase 36a F-36-28 finding (manual input UI is dead code)"
    - "Phase 36b CONTEXT.md D-13/D-14"
  provides:
    - "Read-only Aktuelle Spiele table (no manual input path)"
    - "Cleaner tournaments/ views directory (one unused partial removed)"
  affects:
    - "app/views/tournament_monitors/_current_games.html.erb"
    - "app/views/tournaments/_wizard_steps.html.erb (deleted)"
tech_stack:
  added: []
  patterns: ["ERB partial cleanup", "git rm dead code"]
key_files:
  created: []
  modified:
    - "app/views/tournament_monitors/_current_games.html.erb"
  deleted:
    - "app/views/tournaments/_wizard_steps.html.erb"
decisions:
  - "Pre-existing erblint errors on adjacent lines (br/ void, unquoted rowspan) fixed under Rule 3 (blocker) since plan acceptance criterion requires erblint exit 0"
  - "Scope-correction: CONTEXT.md D-14 originally listed both _wizard_steps and _wizard_step for deletion; Task 1 gate empirically proved _wizard_step (singular) has 3 active callers in _wizard_steps_v2, so only the plural file was deleted"
metrics:
  tasks_completed: 3
  tasks_total: 3
  duration: "~8 minutes"
  completed_date: "2026-04-14"
---

# Phase 36B Plan 04: Dead Code Cleanup Summary

**One-liner:** Removed the dead-code manual-input UI from the Aktuelle Spiele tournament monitor table and deleted the orphaned `_wizard_steps.html.erb` partial, leaving the read-only columns, state-display link, and table-exchange arrows intact.

## What Was Built

### Task 1: Re-verification gate (D-14) — evidence-only, no files modified

Ran three independent greps to prove the deletion target had zero callers:

| Grep | Pattern | Expected | Actual |
|------|---------|----------|--------|
| G1 | `render.*wizard_steps` in `app/` | 1 line (only `_wizard_steps_v2`) | 1 line: `show.html.erb:35` |
| G2 | `wizard_steps\.html\.erb` in `app/` | 0 lines | 0 lines |
| G3 | `render.*wizard_step[^s_]` in `app/` | ≥3 lines in `_wizard_steps_v2.html.erb` | 3 lines at 247, 268, 286 |

The plan's automated ruby gate returned `GATE PASSED`. Task 3 was cleared to proceed.

**Key finding:** Grep 3 also returned 5 internal references from inside `_wizard_steps.html.erb` (the file being deleted) — these are internal references in a dead file, not external callers. The `_wizard_step.html.erb` singular partial IS still used by `_wizard_steps_v2.html.erb` (lines 247, 268, 286 for steps 3/4/5), confirming that the plan's decision to preserve the singular file (in contradiction of CONTEXT.md D-14) is correct.

### Task 2: Manual-input cell removal from `_current_games.html.erb`

**Removed (4 `<td>` cells per per-game row):**

1. **`set_balls` number input** — `number_field_tag(:set_balls, ...)` with `change->TableMonitorReflex#set_balls` Reflex hook.
2. **`-1` / `-10` / `+10` / `+1` buttons** — four `click->TableMonitorReflex#minus_one`, `#minus_ten`, `#add_ten`, `#add_one` handlers.
3. **`undo` button** — `click->TableMonitorReflex#undo` handler with SVG icon.
4. **`next` button** — `click->TableMonitorReflex#next_step` handler.

**Also removed:**

- The now-empty spacer `<td></td>` that used to precede the input cells.
- The two-row `<thead>` with `rowspan="2"` on all label columns and `colspan=5` over "Current Inning" / `colspan=4` over "inputs". Replaced with a single-row header that keeps the same data columns (Table, Player, Balls, of, Inning, of, HS, GD, optional Sets) plus one final "Current inning" column for the read-only current-inning balls display.

**Preserved (read-only display):**

- Per-player name cell (`gp.player.andand.fullname`), with active-player indicator (`*`).
- `result`, `balls_goal`, `innings`, `innings_goal`, `hs`, `gd`, and the per-set `Sets1`/`Sets2` cells.
- The `<% if tm.playing? %>` branch now renders only a read-only `<td>` showing the current-inning balls (from `tm.data[gp.role].andand["innings_redo_list"][-1]`).
- The `<% else %>` branch (`set_over` / `wait_check` state link via `evaluate_result_table_monitor_path`) was retained, reduced from `colspan=6` to a plain `<td>` to match the new single-column layout.
- Table-exchange `up` / `down` arrow Reflex handlers (`TableMonitorReflex#up` / `#down`) — these are not inning-input UI.

**Acceptance criteria (all pass):**

| Criterion | Result |
|-----------|--------|
| `grep -c set_balls` | 0 ✓ |
| `grep -c TableMonitorReflex#minus_one` | 0 ✓ |
| `grep -c TableMonitorReflex#minus_ten` | 0 ✓ |
| `grep -c TableMonitorReflex#add_ten` | 0 ✓ |
| `grep -c TableMonitorReflex#add_one` | 0 ✓ |
| `grep -c TableMonitorReflex#undo` | 0 ✓ |
| `grep -c TableMonitorReflex#next_step` | 0 ✓ |
| `grep -c evaluate_result_table_monitor_path` | 2 ✓ (≥1) |
| `grep -c TableMonitorReflex#up` | 1 ✓ |
| `grep -c TableMonitorReflex#down` | 1 ✓ |
| `grep -c gp.player.andand.fullname` | 1 ✓ (≥1) |
| `bundle exec erblint` | exit 0 ✓ |

**Commit:** `85f710f6` — `refactor(36B-04): remove dead manual input UI from current_games table`

### Task 3: `git rm _wizard_steps.html.erb`

Executed `git rm app/views/tournaments/_wizard_steps.html.erb` after the Task 1 gate confirmed zero external callers.

**Acceptance criteria (all pass):**

| Criterion | Result |
|-----------|--------|
| `test ! -f _wizard_steps.html.erb` | PASS ✓ |
| `test -f _wizard_steps_v2.html.erb` | PASS ✓ (canonical partial preserved) |
| `test -f _wizard_step.html.erb` (singular) | PASS ✓ (still used by v2 for steps 3-5) |
| `git ls-files _wizard_steps.html.erb` empty | PASS ✓ |
| `git status --porcelain` shows `D  ` | PASS ✓ |

**Explicit confirmation:** `_wizard_step.html.erb` (singular, 2383 bytes) is still present in the working tree and still tracked by git. It was NOT deleted. The plan and the Task 1 gate explicitly override CONTEXT.md D-14's blanket "delete both" instruction because the gate showed 3 live render calls to the singular partial from `_wizard_steps_v2.html.erb`.

**Commit:** `d9faaa41` — `chore(36B-04): git rm unused _wizard_steps.html.erb partial` (1 file changed, 258 deletions)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Fixed pre-existing erblint errors on lines adjacent to removed code**

- **Found during:** Task 2 verification (running the plan's `bundle exec erblint` acceptance check)
- **Issue:** The original file had 5 pre-existing erblint errors (verified by stashing my changes and re-running lint on the master state). Three of the five landed on lines 52-53 after my edits (the `<td rowspan=...>` with `<br/>` void-element). The plan's Task 2 acceptance criterion explicitly requires `bundle exec erblint ... exits 0`, which made the pre-existing errors a blocker for plan verification.
- **Fix:** Quoted the `rowspan` attribute value (`rowspan=<%= ... %>` → `rowspan="<%= ... %>"`) and closed the `<br/>` void element properly (`<br/>` → `<br>`).
- **Files modified:** `app/views/tournament_monitors/_current_games.html.erb` (line 52-53)
- **Commit:** Folded into the Task 2 commit `85f710f6`
- **Rationale:** Same-file pre-existing lint errors that block the plan's verification gate fall under Rule 3 (blocking issue). The scope-boundary rule restricts auto-fixes to "issues DIRECTLY caused by the current task's changes", but the plan's acceptance criterion explicitly asserts the whole file lints clean, so the pre-existing errors became in-scope for this plan.

**2. [Documentation] CONTEXT.md D-14 mismatch with plan's Task 1 gate**

- **Not a deviation from the plan** — the plan correctly overrides CONTEXT.md. Recording here for clarity.
- CONTEXT.md D-14 lists BOTH `_wizard_steps.html.erb` AND `_wizard_step.html.erb` for deletion, with a "re-verify via grep" escape hatch.
- The plan's Task 1 gate ran the re-verification and found 3 live callers of `_wizard_step.html.erb` (singular) in `_wizard_steps_v2.html.erb` at lines 247, 268, 286.
- Following CONTEXT.md blindly would have broken the wizard. The plan correctly scoped the deletion to the plural file only.
- The singular partial `_wizard_step.html.erb` remains in the tree and is still tracked.

### Authentication Gates

None encountered.

## Files Touched

| File | Change | Commit |
|------|--------|--------|
| `app/views/tournament_monitors/_current_games.html.erb` | modified (55 deletions, 17 insertions) | 85f710f6 |
| `app/views/tournaments/_wizard_steps.html.erb` | deleted (258 lines) | d9faaa41 |

**NOT touched (explicitly preserved per plan scope):**

- `app/views/tournaments/_wizard_step.html.erb` (singular) — still used for steps 3-5
- `app/views/tournaments/_wizard_steps_v2.html.erb` — canonical wizard partial
- `app/views/tournaments/show.html.erb` — render call at line 35 is stable
- `app/views/tournaments/tournament_monitor.html.erb` — that's plan 02/03's territory
- `config/locales/de.yml` / `en.yml` — no i18n keys added in this plan (wave conflict with plan 02)

## Key Decisions

1. **Plan-over-CONTEXT:** When the plan's Task 1 gate contradicted CONTEXT.md D-14 (delete both wizard_step partials), the plan won because it was backed by empirical grep evidence and an automated gate.

2. **Preserve `evaluate_result_table_monitor_path` state-display link:** The `<% if tm.playing? %> ... <% else %>` branch in `_current_games.html.erb` had two purposes — the `if` branch was manual input (deleted) and the `else` branch was a state-display link (`OK?` / `wait_check`). Per the plan's D-13 and the scope constraints, the else branch is NOT manual input and was preserved.

3. **Preserve table-exchange `up`/`down` arrows:** Lines 57-64 have `TableMonitorReflex#up` / `#down` Reflex handlers that are table-exchange UI, not inning input. Per the plan's explicit "do not touch" list, these stayed.

4. **Single-row header instead of removing "Current Inning" heading entirely:** The plan specified a single `<th>Current inning</th>` at the end of the new header row. This keeps the read-only current-inning balls column labelled rather than orphaning it under an unlabeled `<th>`.

5. **Scope-local erblint cleanup:** Only the 2 lines of pre-existing lint errors that were needed to satisfy the plan's acceptance criterion were touched. Other pre-existing ERB issues in the repo were left alone.

## Self-Check: PASSED

**Created files:**
- `.planning/phases/36B-ui-cleanup-kleine-features/36B-04-dead-code-cleanup-SUMMARY.md` — FOUND (this file)

**Commits:**
- `85f710f6` refactor(36B-04): remove dead manual input UI from current_games table — FOUND in git log
- `d9faaa41` chore(36B-04): git rm unused _wizard_steps.html.erb partial — FOUND in git log

**File state:**
- `app/views/tournament_monitors/_current_games.html.erb` — MODIFIED (manual input cells removed, erblint clean)
- `app/views/tournaments/_wizard_steps.html.erb` — DELETED
- `app/views/tournaments/_wizard_steps_v2.html.erb` — PRESERVED
- `app/views/tournaments/_wizard_step.html.erb` — PRESERVED (still used for steps 3-5)

**Verification:**
- `bundle exec erblint app/views/tournament_monitors/_current_games.html.erb` → exit 0
- All 12 acceptance-criteria greps from Task 2 return the expected counts
- All 5 file-existence / git-tracking checks from Task 3 pass
