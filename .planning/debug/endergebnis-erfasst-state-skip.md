---
status: diagnosed
trigger: "Phase 38.7 UAT post-completion: Endergebnis-erfasst state is skipped across ALL disciplines after match-end. User confirms it was working before Phase 38.x. Critical: in training mode, end-state must be operator-acknowledged before next game starts; in tournament mode, must hand off to TournamentMonitor."
created: 2026-05-01T00:00:00Z
updated: 2026-05-01T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED — `ResultRecorder#evaluate_result` short-circuits the training-mode flow by writing `update(state: "playing")` directly (bypassing AASM) and starting `do_play` immediately after `acknowledge_result!`/`report_result`, so the AASM state `final_match_score` (German label "Endergebnis erfasst") is never entered before the next game.
test: confirmed via code-trace and git-blame
expecting: fix lands in next phase — extract rematch logic out of evaluate_result and gate it behind an explicit operator action that runs only after `final_match_score` is reached
next_action: stop investigation; report findings

## Symptoms

expected: After final result accepted (`acknowledge_result!`), TM transitions to `final_set_score`, then `finish_match!` → `final_match_score`. Operator sees the "Endergebnis erfasst" display. Only on a SEPARATE operator action does training mode swap players + start rematch (or tournament mode hand off to TournamentMonitor).
actual: After final result accepted in TRAINING mode, `evaluate_result` immediately runs `revert_players + update(state: "playing") + do_play` in the same call, so `final_match_score` is never displayed and the new game starts immediately. Tournament mode: `finish_match!` IS called inside `report_result`, but the tournament round-progression callbacks (populate_tables / incr_current_round!) clobber the display before the operator sees it.
errors: none (silent skip)
reproduction: Run training match to completion → submit final result → next game starts immediately with no "Endergebnis erfasst" pause.
started: Commit `c3dedb69` (2026-03-24, "Fix: Race conditions, duplicate protocol modals, and training game rematch") — predates phase 38 numbering but landed in the phase-38 timeframe before 38.0 plans began. The commit explicitly says: *"After game end, automatically swaps players and starts new game — Skips warmup, goes directly to playing state."*

## Eliminated

- hypothesis: AASM state `endergebnis_erfasst` was renamed/removed
  evidence: There is no state literally named `endergebnis_erfasst` — that's the GERMAN LABEL (config/locales/de.yml:589) for AASM state `:final_match_score` (app/models/table_monitor.rb:343). State still exists; it's just SKIPPED at runtime.
  timestamp: 2026-05-01

- hypothesis: AASM transition chain auto-advances past `final_match_score`
  evidence: AASM block (table_monitor.rb:333-401) is clean — `acknowledge_result` → `final_set_score`, `finish_match` → `final_match_score`. No `to:` chain skips it. The skip happens via direct `update(state: "playing")` OUTSIDE AASM, in ResultRecorder.
  timestamp: 2026-05-01

## Evidence

- timestamp: 2026-05-01
  checked: AASM block in app/models/table_monitor.rb:333-401
  found: States declared: new, ready, warmup, warmup_a, warmup_b, match_shootout, playing, set_over, final_set_score, final_match_score, ready_for_new_match. Events: start_new_match, close_match, warmup_a/b, finish_warmup, finish_shootout, end_of_set, undo, acknowledge_result (set_over→final_set_score with tiebreak guard), finish_match (final_set_score→final_match_score), next_set, ready, force_ready.
  implication: `final_match_score` IS the "Endergebnis erfasst" state. Reachable only via `finish_match!` from `final_set_score`. Must be entered AND DISPLAYED before any further transition.

- timestamp: 2026-05-01
  checked: config/locales/de.yml:589
  found: `final_match_score: Endergebnis erfasst`
  implication: User-facing label "Endergebnis erfasst" maps to AASM state `:final_match_score`. Confirms which state the user expects to see.

- timestamp: 2026-05-01
  checked: app/services/table_monitor/result_recorder.rb:454-476 (set_over Branch C, single-set games) and 481-497 (final_set_score branch)
  found: After `acknowledge_result!` and `tournament_monitor&.report_result(@tm)`, the code does:
  ```ruby
  if @tm.tournament_monitor.blank? && @tm.game.present?
    if tiebreak_pick_pending?
      return  # 38.7 Plan 05 D-13 added this guard
    end
    Rails.logger.info "[evaluate_result] Training game finished - creating rematch with swapped players"
    @tm.revert_players
    @tm.update(state: "playing")   # <-- BYPASSES AASM, skips final_match_score
    @tm.do_play
    return
  end
  ```
  implication: SMOKING GUN. `update(state: "playing")` writes directly to the `state` column, NOT through AASM. So `finish_match!` is never invoked in training mode — the TM jumps from `final_set_score` straight to `playing` for the next game. The operator never sees `final_match_score` ("Endergebnis erfasst").

- timestamp: 2026-05-01
  checked: app/models/table_monitor.rb:1640-1652 (admin_ack_result)
  found: Tournament-mode path: `acknowledge_result! → tournament_monitor&.report_result(self) → finish_match! if may_finish_match?`. Tournament mode DOES enter `final_match_score`, but `report_result` (app/services/tournament_monitor/result_processor.rb:84-101) immediately continues to `accumulate_results`, `populate_tables`, `incr_current_round!`, etc., reseeding the next round and clobbering the display before operator can see "Endergebnis erfasst".
  implication: Both modes skip the operator-visible pause at `final_match_score`. Training mode bypasses the state entirely (state-machine bug). Tournament mode reaches the state but the round-progression cascade overrides the display (UX/control-flow bug). User report says "ALL disciplines" — consistent with this single root cause manifesting in both modes.

- timestamp: 2026-05-01
  checked: git blame / git log for the change
  found: Commit `c3dedb698c452d00478268d4f51912e0e953adf1` (2026-03-24, "Fix: Race conditions, duplicate protocol modals, and training game rematch") introduced the auto-rematch in `evaluate_result`. Diff shows the original code path was:
  ```
  -      elsif tournament_monitor.blank? && game.present?
  -        revert_players
  -        update(state: "playing")
  -        do_play
  -        return
  ```
  i.e. the rematch was a SEPARATE elsif branch — likely reachable only from a different operator-driven path. The commit MOVED the rematch into the post-`acknowledge_result`/`report_result` block, fusing it with the result-confirmation step. That is the regression.
  implication: Pre-c3dedb69, rematch required operator action (separate elsif branch hit only by force_next_state etc.); post-c3dedb69, rematch fires automatically inside evaluate_result. Phase landing: this commit predates the Phase 38.x plan numbering but landed during the phase-38 development window — user's "during Phase 38" recollection is consistent.

- timestamp: 2026-05-01
  checked: app/services/table_monitor/result_recorder.rb history
  found: Subsequent commits (`ea49e65b feat(05-01): extract ResultRecorder ApplicationService`) extracted the broken behavior verbatim from TableMonitor into ResultRecorder. Phase 38.7 Plan 05 D-13 (`7df72943`) added the `tiebreak_pick_pending?` guard but PRESERVED the rematch logic underneath — proving the bug is still live in HEAD.
  implication: The bug has survived three+ refactors because each one preserved the legacy `revert_players + update(state: "playing") + do_play` block. Tests validated the tiebreak escape but never asserted the contract "operator must explicitly advance from final_match_score before next game starts."

## Resolution

root_cause: |
  ResultRecorder#evaluate_result auto-starts the training-mode rematch (revert_players + update(state: "playing") + do_play) in the SAME call as result acknowledgment, bypassing the AASM `final_match_score` state ("Endergebnis erfasst"). For tournament mode, finish_match! does enter final_match_score but the round-progression cascade in TournamentMonitor::ResultProcessor#report_result overwrites the display immediately. Both modes therefore skip the operator-visible end-state pause.

  Introduced by commit c3dedb69 (2026-03-24) — "Fix: Race conditions, duplicate protocol modals, and training game rematch". The commit fused the rematch path INTO evaluate_result instead of leaving it as a separate operator-triggered branch.

  Smoking-gun lines:
  - app/services/table_monitor/result_recorder.rb:471-475 (set_over Branch C training rematch)
  - app/services/table_monitor/result_recorder.rb:491-496 (final_set_score branch training rematch)
  - app/models/table_monitor.rb:1648-1649 (admin_ack_result tournament chain — finish_match! is OK, but no operator gate after it)

fix: |
  NOT APPLIED — diagnosis only. Recommended fix sketch (lands in next phase):

  1. **Training mode (primary fix):**
     - Remove auto-rematch from `evaluate_result` (delete lines 462-476 and 485-497 of result_recorder.rb).
     - After `acknowledge_result!`, allow `finish_match!` to run (mirroring tournament path) so TM enters `final_match_score`.
     - Add explicit AASM event `start_rematch` (transitions: from `final_match_score` to `playing`, after: `:revert_players, :do_play, :clear_match_data`).
     - Wire a "Nächstes Spiel"/"Start rematch" button in the `final_match_score` view that triggers `start_rematch!` via reflex.

  2. **Tournament mode (secondary fix):**
     - Move the round-progression block (`populate_tables`, `incr_current_round!`, etc.) from inside `report_result` to a deferred callback triggered by `close_match!` (operator action from `final_match_score` → `ready_for_new_match`).
     - Or: keep round progression where it is, but suppress display reset until the TableMonitor receives an operator `close_match!`. (Less invasive but couples concerns.)

  3. **Test contract:**
     - Add system test: training match completion → assert TM.state == "final_match_score" → assert "Endergebnis erfasst" rendered → trigger start_rematch → assert TM.state == "playing".
     - Add unit test: `evaluate_result` for training, single-set game, no tiebreak → asserts TM ends in `final_match_score`, NOT `playing`. (This test would have failed since c3dedb69 — explains the regression survival.)

verification:
files_changed: []
