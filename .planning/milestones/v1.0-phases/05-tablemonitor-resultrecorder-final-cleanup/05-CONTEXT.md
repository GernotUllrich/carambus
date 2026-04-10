# Phase 5: TableMonitor ResultRecorder & Final Cleanup - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract result persistence and AASM event dispatch from TableMonitor into ResultRecorder. Complete the final cleanup to achieve <800 lines. Full test coverage for all extracted services. Reek final measurement to quantify improvement from Phase 1 baseline. This is the final phase — no further extractions planned.

</domain>

<decisions>
## Implementation Decisions

### ResultRecorder Class Design
- **D-01:** ResultRecorder is an ApplicationService subclass using `.call(table_monitor:, **opts)` pattern. Rationale: it creates/updates database records (save_result writes Game data, evaluate_result triggers AASM events + save!) — this is a one-shot operation with side effects, matching the GameSetup pattern, not the stateless ScoreEngine PORO pattern.
- **D-02:** ResultRecorder handles: `save_result`, `save_current_set`, `evaluate_result`, `switch_to_next_set`, `get_max_number_of_wins`. All result-related persistence logic moves into the service.

### AASM Event Delegation
- **D-03:** ResultRecorder calls AASM events directly on the model via `@tm.finish_match!` and `@tm.end_of_set!`. Unlike ScoreEngine (which returns signals because it's a pure data PORO), ResultRecorder is already an AR-aware service that calls `@tm.save!`. Direct AASM event calls are simpler and match the existing code path exactly — no behavioral change risk.
- **D-04:** After AASM events fire, after_enter callbacks (set_game_over, set_start_time, set_end_time) execute on the model as before. ResultRecorder does NOT call CableReady directly — broadcasts happen through the existing after_update_commit callback chain.

### Final Cleanup Scope
- **D-05:** To hit <800 lines, the final cleanup must go beyond just ResultRecorder extraction (~200 lines). Additional cleanup includes:
  - Wire remaining undelegated ScoreEngine methods (8 methods identified in Phase 3 VERIFICATION.md warnings: update_innings_history, increment_inning_points, decrement_inning_points, delete_inning, insert_inning, recalculate_player_stats, update_player_innings_data, calculate_running_totals)
  - Remove dead code and inline helpers that are only called from already-extracted methods
  - Consolidate remaining orchestrator methods that call multiple services
- **D-06:** The 800-line target is a hard gate. If mechanical extraction doesn't reach it, additional method delegation to existing services (ScoreEngine, GameSetup) is in scope.

### Test Coverage
- **D-07:** All 4 extracted services (ScoreEngine, GameSetup, OptionsPresenter, ResultRecorder) must have passing unit tests. Characterization tests remain the regression safety net. No new characterization tests needed — Phase 1 tests cover the critical paths.

### Reek Final Measurement
- **D-08:** Run Reek on table_monitor.rb after all cleanup. Compare against Phase 1 baseline (781 warnings). Save post-extraction report to `.planning/reek_post_extraction_table_monitor.txt`. This is the final quality metric for the entire project.

### Claude's Discretion
- Exact method split for remaining undelegated methods
- Whether to create additional small helper services or fold remaining methods into existing services
- Dead code identification and removal
- Internal organization of ResultRecorder (private method structure)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Model Under Extraction
- `app/models/table_monitor.rb` — 2544 lines, target <800 (save_result at line 1482, evaluate_result at line 1681, AASM block at line 307)

### Extracted Services (Phase 3-4)
- `app/models/table_monitor/score_engine.rb` — PORO pattern reference (1197 lines, 27 methods)
- `app/services/table_monitor/game_setup.rb` — ApplicationService pattern reference
- `app/models/table_monitor/options_presenter.rb` — PORO pattern reference

### Characterization Tests
- `test/characterization/table_monitor_char_test.rb` — 41 tests, safety net for all extractions

### Quality Baselines
- `.planning/reek_baseline_table_monitor.txt` — 781 Reek warnings (Phase 1 baseline)
- `.planning/reek_post_extraction_region_cc.txt` — RegionCc comparison (54 warnings post-extraction)

### Phase 3 Verification Warnings
- `.planning/phases/03-tablemonitor-scoreengine/03-VERIFICATION.md` — Lists 8 undelegated ScoreEngine methods that should be wired in this phase

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ApplicationService` base class — for ResultRecorder
- ScoreEngine lazy accessor pattern — for remaining delegation wiring
- Phase 1 characterization tests — regression safety net
- Reek (globally installed) — for final measurement

### Established Patterns
- Phase 3: PORO for pure data operations (ScoreEngine)
- Phase 4: ApplicationService for AR-writing operations (GameSetup)
- Lazy accessor delegation: `def score_engine; @score_engine ||= ...; end`
- suppress_broadcast flag for batch operation callback suppression

### Integration Points
- AASM state machine (line 307) — finish_match!, end_of_set! events fired by ResultRecorder
- after_enter callbacks — set_game_over, set_start_time, set_end_time
- after_update_commit — broadcast chain that must fire after result persistence
- `app/reflexes/table_monitor_reflex.rb` — calls save_result, evaluate_result from reflexes

</code_context>

<specifics>
## Specific Ideas

No specific requirements — follow established extraction patterns. This is the final phase — prioritize correctness over aggression in line count reduction.

</specifics>

<deferred>
## Deferred Ideas

None — this is the final phase of the v1.0 milestone.

</deferred>

---

*Phase: 05-tablemonitor-resultrecorder-final-cleanup*
*Context gathered: 2026-04-10*
