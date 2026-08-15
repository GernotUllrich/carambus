---
phase: 04-tablemonitor-gamesetup-optionspresenter
verified: 2026-04-09T01:00:00Z
status: human_needed
score: 3/3
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/3
  gaps_closed:
    - "skip_update_callbacks completely removed from all app/ and test/ code; alias shims gone from TableMonitor; all call sites use suppress_broadcast directly"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "In a dev environment, load a live scoreboard page for a table with an active game. Compare scoreboard rendering before and after the phase — player names, scores, disambiguation, layout should be identical."
    expected: "Zero visual difference in scoreboard output between pre- and post-extraction of OptionsPresenter."
    why_human: "The OptionsPresenter produces a hash with ~50 keys consumed by scoreboard views and TableMonitorJob. Correctness requires a running server with real data; grep cannot confirm rendering parity."
---

# Phase 4: TableMonitor GameSetup & OptionsPresenter — Verification Report

**Phase Goal:** The most entangled method cluster (start_game) and view-preparation logic are extracted; the skip_update_callbacks flag is replaced with an explicit broadcast: false keyword argument
**Verified:** 2026-04-09T01:00:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure (plan 04-04)

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | TableMonitor::GameSetup exists and handles start_game, initialize_game, assign_game, and player sequence/switching; Game and GameParticipation record creation occurs inside GameSetup, not the model | VERIFIED | `app/services/table_monitor/game_setup.rb` (226 lines) exists as `ApplicationService` subclass with `.call(table_monitor:, options:)` and `.assign(table_monitor:, game_participation:)` entry points; model's `start_game` and `assign_game` are 1-line delegation wrappers |
| 2 | The skip_update_callbacks flag is gone; batch operations use an explicit broadcast: false keyword argument; job enqueue count assertions verify no extra jobs fire during batch saves | VERIFIED | `grep -r "skip_update_callbacks" app/ test/` returns zero matches; alias shims removed from `table_monitor.rb`; `suppress_broadcast` is the sole canonical flag (D-05 alternative path); `test/services/table_monitor/game_setup_test.rb` line 208 asserts exactly 1 TableMonitorJob enqueued — commits b800cb38 and 73189f05 |
| 3 | TableMonitor::OptionsPresenter exists and handles all view-preparation logic; reflex interactions that render options produce identical UI output to before extraction | VERIFIED (partial — see human check) | `app/models/table_monitor/options_presenter.rb` (211 lines) exists as PORO; full `get_options!` body extracted; model's `get_options!` reduced to 23-line wrapper; 11 unit tests pass; identical reflex output requires human spot-check |

**Score:** 3/3 truths verified

**Note on SC #2 "broadcast: false keyword argument":** CONTEXT.md decision D-05 explicitly provides the alternative: "(or uses a thread-local/instance variable `@suppress_broadcast`)." The implementation follows this alternative path — `suppress_broadcast` instance variable on TableMonitor, set to `true` before batch saves and reset in an `ensure` block. The `skip_update_callbacks` name is completely gone (zero occurrences). The semantic goal of SC #2 is achieved; the literal phrase "broadcast: false keyword argument" reflects the planning intent captured in D-04, with D-05 providing the accepted alternative implementation. No gap remains.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/services/table_monitor/game_setup.rb` | GameSetup ApplicationService for start_game extraction | VERIFIED | 226 lines, `class TableMonitor::GameSetup < ApplicationService`, dual entry points, ensure block, real Game/GameParticipation creation |
| `test/services/table_monitor/game_setup_test.rb` | Unit tests for GameSetup | VERIFIED | 280 lines, 10 tests covering both game-creation branches, job enqueue count (test 7), ensure cleanup, assign branch; all references use `suppress_broadcast` |
| `app/models/table_monitor/options_presenter.rb` | OptionsPresenter PORO | VERIFIED | 211 lines, `class TableMonitor::OptionsPresenter`, PORO with `initialize(tm, locale:)`, `call` returns hash |
| `test/models/table_monitor/options_presenter_test.rb` | Unit tests for OptionsPresenter | VERIFIED | 295 lines, 11 tests covering hash structure, player data, disambiguation, readers, cattr isolation |
| `app/models/table_monitor.rb` | Thin delegation wrappers + suppress_broadcast (no alias shims) | VERIFIED | `attr_writer :suppress_broadcast` at line 72; no `alias_method` for skip_update_callbacks; `start_game` (line 1807) and `assign_game` (line 746) are 1-line wrappers |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `app/models/table_monitor.rb` | `app/services/table_monitor/game_setup.rb` | `TableMonitor::GameSetup.call` in start_game wrapper | WIRED | Line 1808: `TableMonitor::GameSetup.call(table_monitor: self, options: options_)` |
| `app/models/table_monitor.rb` | `app/services/table_monitor/game_setup.rb` | `TableMonitor::GameSetup.assign` in assign_game wrapper | WIRED | Line 747: `TableMonitor::GameSetup.assign(table_monitor: self, game_participation: game_p)` |
| `app/models/table_monitor.rb` | `app/models/table_monitor/options_presenter.rb` | `TableMonitor::OptionsPresenter.new` in get_options! wrapper | WIRED | Line 1057: `presenter = TableMonitor::OptionsPresenter.new(self, locale: locale)` |
| `app/reflexes/table_monitor_reflex.rb` | `app/models/table_monitor.rb` | `suppress_broadcast=` accessor (46 occurrences) | WIRED | All 46 call sites use `.suppress_broadcast =`; zero `skip_update_callbacks` references |
| `app/reflexes/game_protocol_reflex.rb` | `app/models/table_monitor.rb` | `suppress_broadcast=` accessor (24 occurrences) | WIRED | All 24 call sites use `.suppress_broadcast =`; zero `skip_update_callbacks` references |
| `app/services/table_monitor/game_setup.rb` | `app/models/table_monitor.rb` | `@tm.suppress_broadcast=` (3 occurrences) | WIRED | Lines 24, 28, 90 use `suppress_broadcast` directly; no alias |
| `app/controllers/tournament_monitors_controller.rb` | `app/models/table_monitor.rb` | `suppress_broadcast=` (4 occurrences) | WIRED | All 4 call sites use `.suppress_broadcast =` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `game_setup.rb` | Game/GameParticipation creation | `Player.where(id: ...).order(:dbu_nr)`, `Game.new`, `GameParticipation.create!` | Yes — real AR writes | FLOWING |
| `options_presenter.rb` | options hash | `@tm.game`, `@tm.data`, `@tm.game_participations`, `@tm.tournament_monitor` | Yes — reads real AR associations | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED for GameSetup and OptionsPresenter (tests require live DB; no runnable entry point without full Rails stack). Commit-level and grep verification substitutes:

| Behavior | Evidence | Status |
|----------|----------|--------|
| Zero `skip_update_callbacks` in app/ and test/ | `grep -r "skip_update_callbacks" app/ test/` — no matches | PASS |
| suppress_broadcast count: table_monitor_reflex.rb = 46 | grep count confirmed | PASS |
| suppress_broadcast count: game_protocol_reflex.rb = 24 | grep count confirmed | PASS |
| suppress_broadcast count: game_setup.rb >= 3 | grep count = 5 (includes attr definition + reader) | PASS |
| suppress_broadcast count: tournament_monitors_controller.rb = 4 | grep count confirmed | PASS |
| No alias shims in table_monitor.rb | grep for `alias_method.*suppress_broadcast` — no matches | PASS |
| Gap closure commits exist in git | b800cb38 and 73189f05 confirmed in git log | PASS |
| GameSetup unit tests pass (per summary) | "10 runs, 29 assertions, 0 failures" (04-04-SUMMARY) | PASS (per summary) |
| OptionsPresenter unit tests pass (per summary) | "11 new unit tests... all 41 characterization tests pass" (04-03-SUMMARY) | PASS (per summary) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| TMON-02 | 04-01-PLAN, 04-02-PLAN, 04-04-PLAN | Extract GameSetup service (game/participation creation, replace skip_update_callbacks) | SATISFIED | GameSetup extraction complete; `skip_update_callbacks` fully removed; `suppress_broadcast` is canonical; alias shims gone |
| TMON-04 | 04-03-PLAN | Extract OptionsPresenter service (view-preparation logic) | SATISFIED | OptionsPresenter PORO created with full `get_options!` extraction; thin wrapper in model; 11 unit tests |

### Anti-Patterns Found

No TODO/FIXME/placeholder comments, no empty implementations, no hardcoded empty data found in phase-modified files. Rename was purely mechanical with no logic changes.

### Human Verification Required

#### 1. Reflex UI Output Identical After OptionsPresenter Extraction

**Test:** In a dev environment, load a live scoreboard page for a table with an active game. Compare the scoreboard rendering before and after the phase (using git stash to toggle between pre- and post-extraction commits) — player names, scores, disambiguation, layout should be identical.
**Expected:** Zero visual difference in scoreboard output between pre- and post-extraction.
**Why human:** The OptionsPresenter produces a hash with ~50 keys consumed by scoreboard views and TableMonitorJob. Correctness requires a running server with real data; grep cannot confirm rendering parity.

### Gaps Summary

No gaps remain. The single gap from the initial verification — `skip_update_callbacks` persisting via alias shims — is closed by plan 04-04. Re-verification confirms:

- Zero occurrences of `skip_update_callbacks` in app/ or test/ directories
- Alias shims removed from `table_monitor.rb`
- All 79 call sites renamed to `suppress_broadcast` across 4 production files
- All tests updated in 2 test files
- `suppress_broadcast` is the sole canonical name for the broadcast suppression flag

The `broadcast: false` keyword argument phrasing in SC #2 was the planning intent (D-04), but CONTEXT.md D-05 explicitly accepted the instance-variable alternative (`@suppress_broadcast`). The implementation follows D-05. The semantic goal — preventing redundant broadcasts during batch saves, with explicit naming — is fully achieved.

Phase 4 goal is met. Status is `human_needed` only because the OptionsPresenter scoreboard rendering parity check (SC #3) still requires a running server with live data.

---

_Verified: 2026-04-09T01:00:00Z_
_Verifier: Claude (gsd-verifier)_
