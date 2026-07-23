---
phase: 260502-0ok-score-line-mark-set-winner-with-asterisk
plan: 01
subsystem: table_monitor
tags: [score-engine, result-recorder, multiset, tiebreak, render, ui-display]
requires:
  - app/services/table_monitor/result_recorder.rb#perform_save_result (existing)
  - app/models/table_monitor/score_engine.rb#render_last_innings (existing)
  - data["sets"] per-set hash (legacy karambol multiset structure)
  - Game.data["tiebreak_winner"] (set by tiebreak resolution flow, 260501-x07/-vly)
provides:
  - data["sets"][n]["TiebreakWinner"] (per-set snapshot, 1=playera | 2=playerb | nil)
  - Visual "*" marker after per-set Ergebnis in score panel innings line
affects:
  - Per-player score-line display in TableMonitor live view
  - PDF/protocol code (UNAFFECTED — keys are additive, ba_results unchanged)
tech-stack:
  added: []
  patterns:
    - Extend-before-build: extension lives inside existing hash literal + existing each_with_index block (no new methods, no new state slots).
    - Per-set snapshot pattern: capture mutable Game.data state into immutable data["sets"][n] BEFORE downstream clear (260501-x07).
    - nil-safe rendering: nil.to_i == 0; player_ix is 1 or 2, so tw==0 never matches → no marker.
key-files:
  created: []
  modified:
    - app/services/table_monitor/result_recorder.rb (1 hash key added in perform_save_result)
    - app/models/table_monitor/score_engine.rb (render_last_innings inner block rewritten)
    - test/models/table_monitor/score_engine_test.rb (5 new test cases + 1 helper)
decisions:
  - Per-set TiebreakWinner stored independently of aggregate ba_results["TiebreakWinner"] (260501-vly) to keep render path data-local — render_last_innings only sees data["sets"][n], not ba_results.
  - Forged/unknown values for Game.data["tiebreak_winner"] (anything outside "playera"/"playerb") map to nil via Hash#[] semantics — safer than is_a?(String) whitelist here because the consumer (render path) only checks `tw == player_ix` against literal 1 or 2.
  - Clear-score winner determined by Ergebnis comparison alone; TiebreakWinner only consulted on tie (e1 == e2) — keeps marker correct even if a stale tiebreak_winner value somehow leaked into a non-tied set.
metrics:
  duration: ~5 min
  completed: 2026-05-01T22:34Z
  tests-added: 5
  tests-passing: 84/84 (score_engine) + 32/32 (result_recorder)
requirements:
  - QUICK-260502-0ok
---

# Quick 260502-0ok: Mark Set-Winner in Score Panel with Asterisk Summary

User feedback (2026-05-01 evening) requested visual indication of the per-set winner in the score panel — particularly important for tied sets resolved by tiebreak where both players otherwise show "S1: 1" with no winner indication. Implementation follows extend-before-build SKILL: pure additive edits to existing structures (one hash key + one block rewrite); no new methods, no new state slots, no new files in `app/`.

## What Changed

**app/services/table_monitor/result_recorder.rb#perform_save_result (~lines 76–95):**
Added one new key `"TiebreakWinner"` at the end of the `game_set_result` hash literal. Maps `Game.data["tiebreak_winner"]` (a string `"playera"` | `"playerb"` | nil) into a numeric `1 | 2 | nil` via Hash literal lookup. Mirrors the established mapping in `update_ba_results_with_set_result!` (260501-vly, lines 142–149) but lives on `data["sets"][n]` instead of `ba_results`.

Critical timing: this snapshot must occur in `perform_save_result` (BEFORE `perform_switch_to_next_set` clears `Game.data["tiebreak_winner"]` per quick-260501-x07). The execution order is preserved — no new sequencing logic needed.

**app/models/table_monitor/score_engine.rb#render_last_innings (~lines 499–513):**
Rewrote the body of the existing `Array(data["sets"]).each_with_index` block. The block now:
1. Reads `Ergebnis1`, `Ergebnis2`, `TiebreakWinner` from the set hash (with `to_i` for nil-safety — `nil.to_i == 0` and `player_ix ∈ {1, 2}` so `tw == player_ix` never spuriously matches).
2. Determines winner from this player's perspective: clear-score sets use Ergebnis comparison alone; tied sets defer to TiebreakWinner.
3. Appends `"*"` to the per-set prefix iff this player won the set.

The "; " separator (Phase 38.4 R5-4) is preserved; all caller sites (live view, etc.) UNCHANGED.

**test/models/table_monitor/score_engine_test.rb (end of class):**
Added 5 new minitest cases under existing `TableMonitor::ScoreEngineTest` using a new `sets_data` helper built on the existing `playing_data` helper:

1. `render_last_innings marks playera set-winner with asterisk on clear win` (E1=70, E2=50 → playera sees `S1: 70*`, playerb sees `S1: 50` without star).
2. `render_last_innings marks playerb set-winner with asterisk on clear win` (E1=40, E2=70 → playerb sees `S1: 70*`, playera sees `S1: 40` without star).
3. `render_last_innings marks tiebreak winner with asterisk on tied set` (3-set sequence, set 3 tied with TiebreakWinner=1 → playera sees `S3: 1*`, playerb does not).
4. `render_last_innings tied set with nil TiebreakWinner has no asterisk and no crash` (E1=E2=1, TW=nil → `assert_nothing_raised`, neither side gets a star).
5. `render_last_innings multi-set prefix preserves order and per-player markers` (3-set ordering check; ensures S1<S2<S3 indices in output, no false `S2: 40*`, `; ` separator preserved).

## Verification

```
bin/rails test test/models/table_monitor/score_engine_test.rb
→ 84 runs, 147 assertions, 0 failures, 0 errors, 0 skips

bin/rails test test/services/table_monitor/result_recorder_test.rb
→ 32 runs, 77 assertions, 0 failures, 0 errors, 0 skips
```

TDD flow honored: RED phase (4 of 5 tests failing on the existing `S1: 70; ` output, test 4 already passing because no asterisk could leak yet) → GREEN phase (both production edits applied → all tests pass).

## Deviations from Plan

None — plan executed exactly as written. The plan included a complete spec (action block with full code text for all three edits) and the implementation matches verbatim. The hash literal in `result_recorder.rb` uses `@tm.game&.data&.[]("tiebreak_winner")` for nil-safety; `Hash#[]` returns nil for unknown keys (no exception), so forged values naturally map to nil.

Per the orchestrator's KEY GOTCHAS:
- Confirmed `Game#data` is read-only here; no need for the read-mutate-assign-back idiom.
- `player_ix` reused at line 503 (no new local variable needed in result_recorder).
- Test data uses `innings_list: [], innings_redo_list: []` to keep output a pure prefix (per playing_data caveat).

## Commits

- `d978e302` — feat(260502-0ok): mark set-winner in score panel with asterisk

## Self-Check: PASSED

- File present: app/services/table_monitor/result_recorder.rb (modified) — FOUND
- File present: app/models/table_monitor/score_engine.rb (modified) — FOUND
- File present: test/models/table_monitor/score_engine_test.rb (modified) — FOUND
- Commit present: d978e302 — FOUND
- Both verification test suites green (84/84 + 32/32) — VERIFIED
- Plan must_haves.artifacts.contains markers all present:
  - "TiebreakWinner" present in result_recorder.rb perform_save_result hash — VERIFIED
  - TiebreakWinner present in score_engine.rb render_last_innings — VERIFIED
  - render_last_innings present in score_engine_test.rb (new tests) — VERIFIED
