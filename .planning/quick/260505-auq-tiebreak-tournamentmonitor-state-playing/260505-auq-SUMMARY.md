---
phase: 260505-auq
plan: "01"
type: quick
subsystem: table_monitor / tournament_monitor / tiebreak
tags: [tiebreak, playing_finals, table_monitor, result_recorder, aasm, extend-before-build]
dependency_graph:
  requires:
    - "Phase 38.7 Plan 05 — tiebreak_pending_block? AASM guard (table_monitor.rb:1716)"
    - "Phase 38.7 Plan 11 — bk2_kombi_tiebreak_auto_detect! pattern (result_recorder.rb:379)"
  provides:
    - "playing_finals_force_tiebreak_required! — forces tiebreak_required=true when TournamentMonitor#playing_finals?"
  affects:
    - "TableMonitor#tiebreak_pending_block? (first-line call)"
    - "ResultRecorder#tiebreak_pick_pending? (second pre-mutation call)"
tech_stack:
  added: []
  patterns:
    - "Pre-mutation helper called as first line of gate predicate (same as bk2_kombi_tiebreak_auto_detect!)"
    - "AASM state predicate guard (playing_finals?) instead of executor_params configuration"
    - "Game#deep_merge_data! + save! canonical write path"
    - "private :method_name declaration for method in public section"
    - "@tm.send(:private_method) cross-class private invocation"
key_files:
  created: []
  modified:
    - app/models/table_monitor.rb
    - app/services/table_monitor/result_recorder.rb
    - test/models/table_monitor_test.rb
    - test/services/table_monitor/result_recorder_test.rb
decisions:
  - "Override takes absolute precedence over executor_params — playing_finals? => ALWAYS tiebreak_on_draw, no config knob"
  - "Helper placed in public section of table_monitor.rb (private directive is at line 1913) with explicit private :playing_finals_force_tiebreak_required! declaration"
  - "Positive tests M1 + R1 fail RED as expected; negative tests M2/M3/M4 pass immediately (no-op behavior correct without the helper)"
metrics:
  duration_minutes: 15
  completed_date: "2026-05-05"
  tasks_completed: 2
  tasks_total: 3
  files_changed: 4
  tests_added: 5
  tests_red: 2
  tests_green_after_impl: 5
---

# Quick 260505-auq: TournamentMonitor#playing_finals? Tiebreak Override — Summary

**One-liner:** Added `playing_finals_force_tiebreak_required!` private helper on TableMonitor + two call sites so tied scores in Finale phase always show the tiebreak modal regardless of executor_params baking.

## What Was Built

A single private helper `playing_finals_force_tiebreak_required!` (~12 LOC) on `TableMonitor` + two one-line call-site additions:

**`app/models/table_monitor.rb`** — Helper added after `tiebreak_pending_block?` (lines 1732–1770), called as first line of `tiebreak_pending_block?`. Declared `private :playing_finals_force_tiebreak_required!` because the method lives in the public section (the `private` directive is at line 1913).

**`app/services/table_monitor/result_recorder.rb`** — `@tm.send(:playing_finals_force_tiebreak_required!)` added as second line of `tiebreak_pick_pending?`, after `bk2_kombi_tiebreak_auto_detect!` and before the `tiebreak_required == true` gate check.

### Helper logic

```ruby
def playing_finals_force_tiebreak_required!
  return unless game.present?
  return if game.data&.[]("tiebreak_required") == true   # idempotent
  return unless tournament_monitor.present?
  return unless tournament_monitor.is_a?(TournamentMonitor)
  return unless tournament_monitor.playing_finals?

  Rails.logger.info "[TableMonitor##{id}] playing_finals? override: ..."
  game.deep_merge_data!("tiebreak_required" => true)
  game.save!
end
private :playing_finals_force_tiebreak_required!
```

## Bug Fixed

**5. Grand Prix Einband Finale 10:10** — `tiebreak_required` was never baked into `game.data` for tournament finals games because no executor_params path was seeding it. Both `tiebreak_pending_block?` and `tiebreak_pick_pending?` read `game.data["tiebreak_required"] == true` as their first gate, so both returned `false` → AASM allowed `acknowledge_result!` to fire → "Endergebnis erfasst" / "Nächstes Spiel" appeared instead of the tiebreak modal.

## Why This Replaces the Phase 38.7-09..13 Strategy

Phase 38.7 Plans 09–13 attempted to seed `tiebreak_on_draw: true` through a 4-level executor_params hierarchy (carambus.yml → detail-form → GameSetup baking → Game.data). This produced a brittle plumbing chain: every tournament needed a correctly configured Quickstart button or operator to check a checkbox, and the baking needed to survive the full startup → game creation cycle.

The insight is that "tied in finals → tiebreak" is not a configurable knob — it is a hard rule of the tournament lifecycle. The TournamentMonitor AASM state `playing_finals?` already encodes exactly this information. Reading it at decision time (inside the two gate predicates) is O(1) and requires zero configuration. This is the extend-before-build pattern: one new private helper, two one-line call additions, zero new state machine.

## Test Results

| Test | Type | Before impl | After impl |
|------|------|-------------|------------|
| M1 — playing_finals? forces tiebreak_pending_block? true | Positive | RED (expected) | GREEN |
| M2 — training mode (no TM) is no-op | Negative | GREEN (correct) | GREEN |
| M3 — playing_groups state is no-op | Negative | GREEN (correct) | GREEN |
| M4 — PartyMonitor is no-op | Negative | GREEN (correct) | GREEN |
| R1 — tiebreak_pick_pending? Finale 10:10 returns true | Positive | RED (expected) | GREEN |

Pre-existing suites:
- `test/models/table_monitor_test.rb` — 46 runs, 0 failures
- `test/services/table_monitor/result_recorder_test.rb` — 23 runs, 0 failures
- `test/system/tiebreak_test.rb` — 4 runs, 0 failures
- `test/integration/tiebreak_modal_form_wiring_test.rb` — 4 runs, 0 failures
- `test/concerns/local_protector_test.rb` — 5 runs, 0 failures

**Total: 69 runs, 151 assertions, 0 failures, 0 errors, 0 skips** across the two main test files.

## Commits

| Hash | Message |
|------|---------|
| `2d666a38` | `test(quick-260505-auq): RED regression tests for TournamentMonitor#playing_finals? tiebreak override` |
| `94c488df` | `fix(quick-260505-auq): TournamentMonitor#playing_finals? forces tiebreak_required=true at decision time` |

## Surprises / Notes

**RED prediction:** Only M1 and R1 fail RED. M2/M3/M4 (the no-op tests) pass immediately because without the helper, `game.data["tiebreak_required"]` is never mutated → `tiebreak_pending_block?` returns false → `refute` assertions pass. This is correct: the no-op tests verify absence of side effects, not presence of the override.

**Private section placement:** `playing_finals_force_tiebreak_required!` was placed adjacent to its caller `tiebreak_pending_block?` in the public section (per the plan), with `private :playing_finals_force_tiebreak_required!` immediately following the `end`. This is idiomatic Ruby for keeping related methods together while enforcing private visibility.

**Standardrb:** All violations reported are pre-existing (lines 1914+ in table_monitor.rb and lines 101, 430 in result_recorder.rb). Zero new violations from the added code.

## Scenario-Management Note

This run edited `carambus_bcw` (on feature branch `go_back_to_stable`, independent of master — OK per pre-edit precondition check). The fix touches only Ruby model + Ruby service, both of which ship via standard `git pull` across all 4 scenarios (carambus_master, carambus_bcw, carambus_phat, carambus_api). Post-verify sync decision is deferred to the human-verify checkpoint per the plan's Task 3.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes.

## Self-Check

### Created/modified files exist

- `app/models/table_monitor.rb` — FOUND (contains `playing_finals_force_tiebreak_required!`)
- `app/services/table_monitor/result_recorder.rb` — FOUND (contains `@tm.send(:playing_finals_force_tiebreak_required!)`)
- `test/models/table_monitor_test.rb` — FOUND (contains `playing_finals`)
- `test/services/table_monitor/result_recorder_test.rb` — FOUND (contains `playing_finals`)

### Commits exist

- `2d666a38` — Task 1 RED tests commit
- `94c488df` — Task 2 GREEN implementation commit

## Self-Check: PASSED
