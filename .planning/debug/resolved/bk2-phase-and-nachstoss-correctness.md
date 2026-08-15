---
status: resolved
trigger: "B2/B3a/B3b: BK-2kombi phase sticky, BK-2plus nachstoss must never fire, asymmetric nachstoss set-close — live BCW test 2026-04-27"
created: 2026-04-27T00:00:00Z
updated: 2026-04-29T00:15:00Z
resolved: 2026-04-29T00:15:00Z
human_verified: true
final_commits:
  - 79328663 feat(bk): legacy multiset + 3 BK-specific guards (clean approach)
  - d8c7160f fix(bk): end_of_set? immediate close for no-Nachstoß BK phases
  - 5dbedc77 fix(bk): remove BK2-routing intercepts — pure legacy karambol path
  - 57357109 chore(bk): remove dead BK2 routing infrastructure (post-cleanup)
preserved_experiment_tag: bk2-rounds1-8-experiment
---

## Symptoms (initial)

- **B2:** BK-2kombi phase sticky across set boundaries — phase chip stayed on first-set discipline
- **B3a:** BK-2plus / BK-2kombi DZ phase incorrectly offered Nachstoß (rule: never in DZ)
- **B3b:** Asymmetric Nachstoß set-close — player B's Nachstoß closed set, player A's did not
- Later surfaced: C1 (no Nachstoß in 2nd set BK-2 SP), C2a (same via Quick Start)

## Root Cause

The pre-existing `Bk2::AdvanceMatchState` + `Bk2::CommitInning` services (Phase 38.x) implemented a parallel state-machine alongside the legacy karambol multiset mechanic. The two paths drifted out of sync:

- Routing decision in `bk_family_with_nachstoss?` did `Discipline.find_by(name:)` which returned a stub record (id 59 with `data: nil`) for "BK2-Kombi" instead of the correct id 107 record on dev DB → routing returned false → BK2-Kombi fell into legacy path → `bk2_state` stayed unused.
- When routing happened to work, `Bk2::CommitInning` advanced bk2_state but bypassed the AASM lifecycle (`end_of_set!` → `set_over` → protocol modal), so set-close UX broke.
- Phase-aware Nachstoß rules were duplicated across the legacy `follow_up?` mechanism AND the bk2_state `nachstoss_pending` machinery, producing conflicting display behavior.

## Resolution Approach (after 8 rounds of layered fixes — all reverted)

Per user directive: **"Das multiset management wie beim karambol legacy. BK spezifisch ist nur die verschiedene Behandlung der Negativ-Werte (im BK-2plus positiv beim Gegner angerechnet), das phase-switching bei BK-2kombi und die spezielle Nachstossbehandlung."**

Rolled back to commit `d986ffee` (last clean legacy state). Implemented BK-Familie support as **pure legacy karambol multiset + 4 minimal guards**.

## Final Architecture

| Concern | Implementation |
|---|---|
| Multiset, Anstoß-Wechsel, Set-Close, Modal, Match-End | Pure legacy karambol (unchanged) |
| BK-2kombi phase sequencing | `TableMonitor#bk2_kombi_current_phase` derives DZ/SP from `data["sets"].length + 1` and `bk2_options.first_set_mode` |
| Negative-Wert-Routing (BK-2plus) | `ScoreEngine#bk_credit_negative_to_opponent?` — negative n_balls credit opponent's redo_list positively |
| Nachstoß-Gate | `TableMonitor#follow_up?` BK-Override: BK-2plus/BK50/BK100 always false; BK-2kombi DZ false; BK-2/BK-2kombi SP gated by first-inning rule (`data[kickoff].innings == 1`) |
| Set-Close timing | `TableMonitor#end_of_set?` BK-Override: no-Nachstoß-phases close immediately on balls_goal (no innings-equal-or-allow_follow_up wait) |
| Controller `allow_follow_up` | BK-2/BK-2kombi force true (UI-display gate); BK-2plus/BK50/BK100 force false (defense-in-depth) |
| `Bk2::AdvanceMatchState` | Trimmed to ~99 LOC — only `initialize_bk2_state!` (config-seeding for view-side phase-chip) |
| `Bk2::CommitInning` | **Deleted** |
| Routing intercepts in reflexes | **Deleted** (key_a, key_b, next_step no longer special-case BK) |
| `bk_family_with_nachstoss?`, `route_goal_reached_through_bk2_commit_inning`, `karambol_commit_inning!`, `bk2_kombi_commit_if_active` | **Deleted** |

## Files Changed

```
app/controllers/table_monitors_controller.rb       (Guard 0)
app/models/table_monitor.rb                        (Guards 1, 3, 4 + cleanup)
app/models/table_monitor/score_engine.rb           (Guard 2)
app/reflexes/table_monitor_reflex.rb               (intercept removal + cleanup)
app/services/bk2/advance_match_state.rb            (trimmed 313→99 LOC)
app/services/bk2/commit_inning.rb                  (deleted)
test/integration/bk2_dispatch_integration_test.rb  (deleted)
test/services/bk2/advance_match_state_test.rb      (rewritten 1115→63 LOC)
test/services/bk2/commit_inning_test.rb            (deleted)
test/models/table_monitor_test.rb                  (removed dead-method tests)
test/services/table_monitor/result_recorder_test.rb (removed dead-method tests)
```

Net: ~1500 lines removed vs. the 8-round-experiment, ~150 lines added vs. d986ffee baseline.

## Human Verification

User-verified end-to-end on BCW dev (2026-04-29):
1. Set 1 DZ → A reaches goal → modal opens immediately
2. Confirm → set 2 SP starts, set wins display 1:0
3. Set 2 SP → B reaches goal in inning 1 → "Nachstoß" label on A
4. A plays Nachstoß inning + switch → set closes → modal
5. Confirm → set 3 DZ
6. Match-end on 2nd win

All steps confirmed working. Routing-symmetric: Quick Start ≡ Detail-Form.

## Preserved for Reference

Tag `bk2-rounds1-8-experiment` (commit `fd890cd2`) preserves the 11-commit experiment that built the parallel BK2 state machine before the user pushed back ("nicht an symptomen basteln") and we rolled back to legacy + guards. Useful if future questions arise about why the simpler approach is correct.
