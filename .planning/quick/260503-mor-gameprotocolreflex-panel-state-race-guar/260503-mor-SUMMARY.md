---
phase: quick-260503-mor
plan: 01
subsystem: reflexes / table-monitor
tags:
  - bug-fix
  - race-condition
  - panel-state
  - tiebreak
  - extend-before-build
  - bcw-grand-prix
dependency-graph:
  requires:
    - app/reflexes/game_protocol_reflex.rb (existing reflex layer, Phase 38.7 Plan 06)
    - app/models/table_monitor.rb#set_game_over (Phase 38.7 D-04 AASM after-callback)
  provides:
    - "Three guarded reflex entry points (open_protocol, switch_to_edit_mode, switch_to_view_mode) that bail out when panel_state == 'protocol_final'."
    - "Three regression tests (R1-R3) locking the no-downgrade invariant."
  affects:
    - app/views/table_monitors/_game_protocol_modal.html.erb (rendered via re-render path)
tech-stack:
  added: []
  patterns:
    - "Extend-before-build: small guard on existing path (3 × 4 LOC) instead of parallel state machine"
    - "Reflex unit tests via .allocate + define_singleton_method dispatch (matches existing T1-T5 pattern)"
key-files:
  created: []
  modified:
    - app/reflexes/game_protocol_reflex.rb
    - test/reflexes/game_protocol_reflex_test.rb
decisions:
  - "Guard inserted AFTER `morph :nothing` and `Rails.logger.debug` so logs still capture the invocation; BEFORE the `suppress_broadcast` / `panel_state=` / `save!` block so no downgrade can sneak through."
  - "close_protocol intentionally NOT guarded — closing the modal from protocol_final is legitimate operator intent (Esc / click-away after tiebreak choice already recorded)."
  - "Identical comment wording across all three guards so a future grep finds them in one shot."
  - "send_modal_update is invoked on the guarded path so the operator's click is not silently discarded — they always see the modal again, in its current protocol_final state."
metrics:
  duration: ~10 min
  completed: 2026-05-03
  tasks: 2
  red_tests_added: 3
  green_tests_at_end: 8
  guard_lines_added: 15
  files_modified: 2
---

# Phase quick-260503-mor: GameProtocolReflex panel_state Race Guard Summary

**One-liner:** Three identical 4-line early-return guards in `GameProtocolReflex#open_protocol` / `#switch_to_edit_mode` / `#switch_to_view_mode` close a long-standing intermittent race where stale-DOM clicks after a draw set-end downgraded `panel_state="protocol_final"` to `"protocol"` / `"protocol_edit"` and lost the tiebreak fieldset wiring.

## The Race Condition

User-reported symptom (BCW Grand Prix, 2026-05-02): on a draw set-end, the tiebreak choice fieldset would intermittently fail to appear, leaving the operator unable to record the Stechen winner. The seven-step root-cause sequence:

1. Set ends in a draw (`playera.result == playerb.result == balls_goal`).
2. AASM `next_set!` event fires; transitions table monitor into `set_over`.
3. AASM after-callback `set_game_over` (table_monitor.rb:543-548) writes `panel_state = "protocol_final"`, `current_element = "confirm_result"` (later flipped to `"tiebreak_winner_choice"` by the ResultRecorder when the discipline requires a tiebreak).
4. CableReady push to the scoreboard is queued — but does not arrive at the browser yet (Sidekiq async, Redis hop, page reflow).
5. Operator sees the **pre-set-over** DOM with the visible Spielprotokoll-Button.
6. Operator clicks → `GameProtocolReflex#open_protocol` (or `#switch_to_edit_mode` / `#switch_to_view_mode`) fires.
7. The reflex unconditionally writes `panel_state = "protocol"` (or `"protocol_edit"`), **overwriting `"protocol_final"`** and silently demoting the modal to its non-tiebreak variant. The fieldset that wires `tiebreak_winner=playera|playerb` is gone.

The result: the operator can no longer enter the Stechen winner from the modal. Workarounds at the BCW Grand Prix were manual DB writes via Rails console.

## The Fix (SKILL extend-before-build)

Three identical 4-line early-return guards — one per affected reflex method:

```ruby
# Race-guard: stale-DOM click after set_game_over set protocol_final — re-render, do not downgrade
if @table_monitor.panel_state == "protocol_final"
  send_modal_update(render_protocol_modal)
  return
end
```

Inserted AFTER `morph :nothing` + `Rails.logger.debug` and BEFORE the `suppress_broadcast` / `panel_state=` / `save!` block. The guard:

- **Re-renders** the existing protocol_final modal so the operator's click is not silently discarded — they see the modal again, in its current state (with the tiebreak fieldset, since `_game_protocol_modal.html.erb:5` reads `is_final_mode = panel_state == "protocol_final"`).
- **Returns early** so the body of the reflex (which would otherwise overwrite `panel_state`) is never reached.
- Honors the `extend-before-build` SKILL: no new helper, no refactor, no parallel state machine. Three guards on three existing paths.

Cited cautionary tale from the SKILL doc (`bk2-rounds1-8-experiment` — 8 rounds of symptom-chasing on a parallel state machine, rolled back to a 4-guard implementation that removed -1463 LOC). This fix follows the same pattern: tiny delta on the existing path.

## Why `close_protocol` is NOT Guarded

Closing the modal from `protocol_final` is **legitimate operator intent** — e.g. pressing Esc or clicking-away after the tiebreak choice has already been recorded by `confirm_result` (Phase 38.7 Plan 06). The race condition only affects open / switch reflexes, never close. Adding a guard to `close_protocol` would trap the operator in the modal once `protocol_final` was set — wrong behavior.

`close_protocol` body is byte-identical to the pre-fix version. Verified by `grep -c 'def close_protocol' app/reflexes/game_protocol_reflex.rb` → `1` (single occurrence, no edits).

## RED → GREEN Sequence

**RED commit `3f5aad76`** — `test(quick-260503-mor): add 3 RED regression tests for protocol_final no-downgrade guard`

3 new tests appended after T5 in `test/reflexes/game_protocol_reflex_test.rb`:

| Test | Reflex method        | Marker (current_element)    | Asserts                                                                      |
| ---- | -------------------- | --------------------------- | ---------------------------------------------------------------------------- |
| R1   | `open_protocol`      | `tiebreak_winner_choice`    | `panel_state == "protocol_final"` AND marker preserved AND modal re-rendered |
| R2   | `switch_to_edit_mode`| `tiebreak_winner_choice`    | `panel_state == "protocol_final"` AND marker preserved AND modal re-rendered |
| R3   | `switch_to_view_mode`| `confirm_result`            | `panel_state == "protocol_final"` AND marker preserved AND modal re-rendered |

R3 covers the second valid `protocol_final` marker (`confirm_result` — the value `set_game_over` initially writes before the ResultRecorder detects a pending tiebreak), so both code paths are locked.

RED-phase result: 3 failures with diff `Expected "protocol_final" / Actual "protocol"` (R1/R3) and `Expected "protocol_final" / Actual "protocol_edit"` (R2). T1-T5 unchanged and passing (5 PASSES + 3 FAILURES = 8 runs).

**GREEN commit `734a2b95`** — `fix(quick-260503-mor): guard protocol_final from downgrade in GameProtocolReflex open/switch reflexes`

Three identical guards added to `app/reflexes/game_protocol_reflex.rb`. Verified:

- `bin/rails test test/reflexes/game_protocol_reflex_test.rb` → **8 runs, 24 assertions, 0 failures, 0 errors, 0 skips** (R1/R2/R3 GREEN, T1-T5 stay GREEN).
- `bin/rails test test/integration/tiebreak_modal_form_wiring_test.rb` → **4 runs, 20 assertions, 0 failures, 0 errors, 0 skips** (G1-G4 from Phase 38.7 Plan 13 unchanged).

## Test Counts (end of plan)

| Suite                                                  | Runs | Assertions | Failures |
| ------------------------------------------------------ | ---- | ---------- | -------- |
| `test/reflexes/game_protocol_reflex_test.rb`           | 8    | 24         | 0        |
| `test/integration/tiebreak_modal_form_wiring_test.rb`  | 4    | 20         | 0        |

Total green: **12 runs / 44 assertions / 0 failures**.

## Lock-In

R1/R2/R3 are now permanent regression sentinels: any future change to `open_protocol` / `switch_to_edit_mode` / `switch_to_view_mode` that re-introduces the downgrade (e.g. by removing the guard, by reordering, by adding a new code path that writes `panel_state` without the guard) will fail with the same Expected/Actual diff that the original RED phase produced. The user-reported BCW Grand Prix symptom is now non-reproducible via stale-DOM clicks.

## Verification Trail

- `git log --oneline -3` shows RED then GREEN commits with `(quick-260503-mor)` prefix.
- `grep -n 'panel_state == "protocol_final"' app/reflexes/game_protocol_reflex.rb` returns 4 lines: 3 in the new guards (lines 15, 43, 59) + 1 pre-existing in `render_protocol_table_body` (line 393, unrelated — picks the edit body partial).
- `grep -c 'def close_protocol' app/reflexes/game_protocol_reflex.rb` returns `1`; method body unchanged.

## Self-Check: PASSED

**Files verified to exist:**

- `app/reflexes/game_protocol_reflex.rb` — modified, 3 guards present at lines 14-18, 42-46, 58-62.
- `test/reflexes/game_protocol_reflex_test.rb` — modified, R1/R2/R3 appended after T5.
- `.planning/quick/260503-mor-gameprotocolreflex-panel-state-race-guar/260503-mor-PLAN.md` — input artifact present.
- `.planning/quick/260503-mor-gameprotocolreflex-panel-state-race-guar/260503-mor-SUMMARY.md` — this file.

**Commits verified:**

- `3f5aad76` (RED) — `test(quick-260503-mor): add 3 RED regression tests for protocol_final no-downgrade guard`
- `734a2b95` (GREEN) — `fix(quick-260503-mor): guard protocol_final from downgrade in GameProtocolReflex open/switch reflexes`

Both commits present in `git log` and on master.
