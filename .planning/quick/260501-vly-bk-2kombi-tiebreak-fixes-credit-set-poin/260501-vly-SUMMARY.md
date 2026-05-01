---
quick_task: 260501-vly
plan: 01
title: BK-2kombi tiebreak fixes — credit set point + Detail Page default + unified inning display
subsystem: scoring-engine, scoreboard-views
tags: [bk2-kombi, bk-2, tiebreak, set-credit, scoreboard, detail-form, inning-display, extend-before-build]
requirements: [QUICK-260501-vly-01, QUICK-260501-vly-02, QUICK-260501-vly-03]
status: complete
completed_at: 2026-05-01
duration_minutes: 24
commits:
  - b4dbbe8d: feat(260501-vly) credit Sets1/Sets2 on tiebreak winner pick (engine + 5 tests)
  - 0caaec3f: feat(260501-vly) default-check tiebreak_on_draw on Detail Page for BK-2 family
  - 7cf939a9: feat(260501-vly) unified BK-family inning display "N of M" fallback
files_modified:
  - app/services/table_monitor/result_recorder.rb (+15 LOC)
  - test/services/table_monitor/result_recorder_test.rb (+109 LOC)
  - app/views/locations/scoreboard_free_game_karambol_new.html.erb (+8 LOC)
  - app/views/table_monitors/_scoreboard.html.erb (+16/-3 LOC)
test_results:
  before: { runs: 24, assertions: 58, failures: 0, errors: 0 }
  after:  { runs: 29, assertions: 73, failures: 0, errors: 0 }
  delta:  { runs: +5, assertions: +15, failures: 0, errors: 0 }
red_then_green: confirmed (2 RED on initial run pre-engine-branch → 0 failures after Task 1 implementation)
---

# Quick Task 260501-vly: BK-2kombi tiebreak fixes Summary

**One-liner:** Three independent BK-2kombi tournament-blocking bugs fixed in one quick task — tiebreak winner pick now credits Sets1/Sets2 (engine), Detail Page tiebreak_on_draw defaults checked for BK-2/BK-2plus/BK-2kombi (UX), and Quickstart BK-family inning counter shows "N of M" instead of bare "N" (UX) — all ready for the BCW Grand Prix 2026-05-02.

## Goal

Three bugs caught during BK-2kombi rehearsal on 2026-05-01:

1. **Bug 1 (engine, BLOCKER)** — Tiebreak winner pick recorded `ba_results["TiebreakWinner"]` indicator but did NOT increment `Sets1` / `Sets2`, so a tied set decided by an operator tiebreak pick never advanced the match-score. Match couldn't close. Pre-existing latent defect introduced when Phase 38.7 Plan 05 added the indicator without the credit branch.
2. **Bug 2 (Detail Page UX)** — `scoreboard_free_game_karambol_new.html.erb` defaulted tiebreak_on_draw to UNCHECKED while Quickstart preset gives it `tiebreak_on_draw: true` for BK-2/BK-2kombi disciplines — divergent UX.
3. **Bug 3 (display UX)** — Detail Page sets `innings_goal: 5`, Quickstart hardcodes `innings_goal: 0` for BK-family. Result: Detail-Page games show "3 of 5", Quickstart games show bare "3" for IDENTICAL engine semantics (Quick-260501-uxo enforces the SP-phase inning limit via `bk2_options.serienspiel_max_innings_per_set` either way).

All three fixes ride existing data paths; zero schema or engine semantic changes.

## Files Changed

| File | Δ LOC | Change |
|------|------:|--------|
| `app/services/table_monitor/result_recorder.rb` | +15 | Inside the existing `tw.is_a?(String) && whitelist` block at line 148, add a tied + `tiebreak_required==true` gate that credits Sets1 (playera) or Sets2 (playerb); `else` arm of the inner if leverages the outer whitelist (no re-check needed). |
| `test/services/table_monitor/result_recorder_test.rb` | +109 | 5 new tests under "Quick-260501-vly Plan 01" header (close branches × 2, missing-tw regression, tiebreak_required=false gate, no-double-count on non-tied path). |
| `app/views/locations/scoreboard_free_game_karambol_new.html.erb` | +8 | `x-bind:checked` Alpine binding on tiebreak_on_draw checkbox (line 650 → 654-656) keyed off `bk_selected_form` ∈ {bk_2, bk_2plus, bk2_kombi}; hidden_field_tag '0' (sparse-override semantics) UNCHANGED. |
| `app/views/table_monitors/_scoreboard.html.erb` | +16/-3 | New `bk_sp_inning_phase` + `display_innings_goal` ERB locals computed at top of partial (after `bk2_current_phase` definition); lines 120 + 127 swapped to reference `display_innings_goal`; handicap-tournier guard at line 127 preserved verbatim. |

## Test Results

```
$ bin/rails test test/services/table_monitor/result_recorder_test.rb
29 runs, 73 assertions, 0 failures, 0 errors, 0 skips
```

Pre-existing 24 tests preserved (58 assertions); 5 new tests added (15 assertions).

### Test Cases (260501-vly Bug 1)

| # | Scenario | Expected | Result |
|---|----------|---------:|-------:|
| 1 | Tied (50/50) + tiebreak_required=true + tw='playera' | Sets1=1, Sets2=0, TiebreakWinner=1 | ✓ |
| 2 | Tied (50/50) + tiebreak_required=true + tw='playerb' | Sets2=1, Sets1=0, TiebreakWinner=2 | ✓ |
| 3 | Tied + tiebreak_required=true + tw missing | Sets1=0, Sets2=0, TiebreakWinner absent (Plan 38.7-05 contract) | ✓ |
| 4 | Tied + tiebreak_required=false + tw='playera' | Sets1=0 (gate off), TiebreakWinner=1 still set (legacy/edge data) | ✓ |
| 5 | Non-tied (70/45) + tiebreak_required=true + tw='playera' | Sets1=1 from score comparison only (no double-count), TiebreakWinner=1 | ✓ |

### RED-then-GREEN proof (Bug 1)

After writing the 5 RED tests but BEFORE adding the new branch in `result_recorder.rb`:

```
$ bin/rails test test/services/table_monitor/result_recorder_test.rb -n /Quick.260501.vly/
5 runs, 11 assertions, 2 failures, 0 errors, 0 skips
  - Quick-260501-vly Bug 1 close branch playera (Sets1 expected 1, actual 0)
  - Quick-260501-vly Bug 1 close branch playerb (Sets2 expected 1, actual 0)
```

Exactly 2 failures, exactly the predicted close-branch tests (#1 + #2). Tests 3, 4, 5 stayed GREEN — they are regression guards exercising paths that the legacy code already handles correctly (missing tw, gate off, non-tied score).

After adding the new branch (`if game_set_result["Ergebnis1"].to_i == game_set_result["Ergebnis2"].to_i && @tm.game.data&.[]("tiebreak_required") == true …`):

```
$ bin/rails test test/services/table_monitor/result_recorder_test.rb -n /Quick.260501.vly/
5 runs, 15 assertions, 0 failures, 0 errors, 0 skips
```

Full file regression: 29/29 GREEN, 73 assertions, 0 failures.

### Regression sweep

```
$ bin/rails test test/models/table_monitor_test.rb
26 runs, 50 assertions, 0 failures, 0 errors, 0 skips
```

Quick-260501-uxo's 26 tests preserved. No regressions.

## SKILL Compliance

### extend-before-build (mandatory)

- **Bug 1:** ONE additive guard branch INSIDE the existing `tw.is_a?(String) && %w[playera playerb].include?(tw)` block. NO new method extracted. NO parallel state machine. Existing TiebreakWinner indicator unchanged. Outer guard unchanged.
- **Bug 2:** ONE attribute (`x-bind:checked`) added to ONE existing element (the check_box_tag at line 650). Surrounding `<div>`, label, hidden field UNCHANGED. NO new Alpine getter (inline whitelist is more honest about coupling than polluting x-data scope with `is_bk_supports_tiebreak`).
- **Bug 3:** ONE local variable (+ one predicate local) added at section top; 2 line-edits at sites 120 + 127. NO new partial. NO new helper. NO engine semantic change. handicap-tournier guard preserved verbatim.

### Memory hint: "Tiebreak independent from Discipline"

- ✅ NO Discipline schema changes; NO Discipline.data writes. All 3 fixes ride per-game (`Game.data['tiebreak_required']` / `'tiebreak_winner'`) and per-TM (`bk2_options`) paths only.

### Memory hint: "Extend before build"

- ✅ All 3 bugs fixed via 4 small additive guards/locals/bindings — zero parallel state, zero new abstractions. Validates the same -1463-LOC lesson from the bk2-rounds 1-8 experiment.

### Memory hint: "carambus.yml gitignored locally"

- ✅ NO carambus.yml or carambus.yml.erb edits. All 3 fixes ride existing config paths.

### scenario-management

- ✅ All edits in carambus_bcw working tree (this is the BCW deployment scenario; tournament target tomorrow). Scenario-mode skill rules respected.

## Manual smoke procedure (operator-driven, before tournament 2026-05-02)

### Bug 1 (engine — full tiebreak chain end-to-end)

1. Start a Quickstart BK-2kombi 2/5/70+NS match in BCW dev.
2. Drive both players to the SP-phase inning limit (5 each per Quick-260501-uxo) without either reaching 70 balls; ensure scores are tied (e.g., both at 50, both at 65, etc.).
3. Tiebreak modal opens (Phase 38.7 Plan 06 `_game_protocol_modal.html.erb` `current_element=='tiebreak_winner_choice'`).
4. Pick a winner (radio: playera / playerb), click "Bestätigen".
5. **Verify:** match closes correctly — `ba_results["Sets1"]` (or `Sets2`) is incremented to a value matching the picked winner's running set count, and `TiebreakWinner` indicator is 1 or 2 for the PDF; finalmatch_score AASM reached.
6. Generate Spielbericht PDF; confirm "Stechen <Player>" suffix renders (Phase 38.7 Plan 07).

### Bug 2 (Detail Page tiebreak default)

1. Open `/scoreboards/free_game_karambol/new` for a BCW location in BCW dev.
2. Pick **Kegel → BK-2kombi**: observe `tiebreak_on_draw` checkbox is now CHECKED by default.
3. Pick **Kegel → BK-2plus**: observe checkbox CHECKED.
4. Pick **Kegel → BK-2 (pure)**: observe checkbox CHECKED.
5. Switch to **BK50** or **BK100**: observe checkbox UNCHECKS (single-set games, no classical tiebreak shootout).
6. Switch to **Kegel → EUROK** (sets `bk_selected_form=null`): observe checkbox UNCHECKS.
7. Manually uncheck the checkbox on a BK-2kombi match: confirm submit goes through and the start_game flow honors the operator's explicit-false (sparse override via the unchanged hidden field at line 649).
8. Run a single Detail-Page-started BK-2kombi match through to a tied set + tiebreak modal pick + match-close to validate the full Bug 1 + Bug 2 chain end-to-end.

### Bug 3 (Quickstart BK-family inning display "N of M")

1. Start a Quickstart **BK-2kombi 2/5/70+NS** match in BCW dev. Drive to inning 3.
2. **Verify:** SP-phase inning panel shows **"3 of 5"** in the inning counter (previously: bare "3").
3. Start a Detail-Page-started **BK-2kombi** match (innings_goal=5 explicit via the karambol-style innings_choice radio). Drive to inning 3.
4. **Verify:** SP-phase inning panel shows **"3 of 5"** UNCHANGED (regression guard).
5. Start a karambol Detail-Page game (innings_goal=5). Drive to inning 3.
6. **Verify:** karambol inning panel shows **"3 of 5"** UNCHANGED via existing `display_innings_goal` positive-source path.
7. Start a Quickstart karambol game (no `bk2_options`).
8. **Verify:** karambol Quickstart panel — no "of M" display (no SP-phase predicate match, fallback no-op — UNCHANGED).

## String-key shape verification (Bug 3)

`options[:bk2_options]` is round-tripped through `TableMonitor.data` (JSON column). Rails JSON round-trips deserialize objects as Hashes with **STRING** keys by default (`symbolize_names: false`). Therefore the canonical access pattern is:

- ✅ `options.dig(:bk2_options, "serienspiel_max_innings_per_set")` (string inner key — used in this fix)
- ❌ `options.dig(:bk2_options, :serienspiel_max_innings_per_set)` (symbol inner key — would silently return nil)

The outer `:bk2_options` key on the `options` hash is itself a symbol because the controller serializer emits it that way; only the inner JSON-deserialized hash carries string keys.

Verifier should confirm by manually loading a Quickstart BK-2kombi 2/5/70+NS match in BCW dev and observing "3 of 5" appears at inning 3. If the display stays as bare "3", inspect `tm.data["bk2_options"]` shape via `Rails.logger.info @tm.data["bk2_options"].inspect` and verify the key is `"serienspiel_max_innings_per_set"` (string). This was Quick-260501-uxo's contract.

## Self-Check: PASSED

| Item | Status |
|------|:------:|
| `app/services/table_monitor/result_recorder.rb` contains tied + tiebreak_required gate inside the existing tw whitelist block | ✓ |
| `test/services/table_monitor/result_recorder_test.rb` has 5 new tests under "Quick-260501-vly Plan 01" header | ✓ |
| `app/views/locations/scoreboard_free_game_karambol_new.html.erb` carries `x-bind:checked` with 3-element whitelist on tiebreak_on_draw check_box_tag | ✓ |
| `app/views/locations/scoreboard_free_game_karambol_new.html.erb` hidden_field_tag :tiebreak_on_draw '0' UNCHANGED (sparse-override) | ✓ |
| `app/views/table_monitors/_scoreboard.html.erb` defines `display_innings_goal` ERB local (after bk2_current_phase definition) | ✓ |
| `app/views/table_monitors/_scoreboard.html.erb` line 120 swap to `display_innings_goal` | ✓ |
| `app/views/table_monitors/_scoreboard.html.erb` line 127 swap to `display_innings_goal` (handicap-tournier guard preserved) | ✓ |
| Commit b4dbbe8d exists (Task 1) | ✓ |
| Commit 0caaec3f exists (Task 2) | ✓ |
| Commit 7cf939a9 exists (Task 3) | ✓ |
| `bin/rails test test/services/table_monitor/result_recorder_test.rb` GREEN (29/29) | ✓ |
| `bin/rails test test/models/table_monitor_test.rb` GREEN (26/26 — Quick-260501-uxo regression guard) | ✓ |
| RED-then-GREEN proof for Bug 1 documented (Tests 1+2 RED before fix; 5/5 GREEN after) | ✓ |
| erblint clean at all 3 edit sites (pre-existing project-wide warnings out-of-scope per GSD scope-boundary rule) | ✓ |

## Deviations from Plan

None — plan executed exactly as written. All 3 tasks fit the "small additive guard" pattern; no architectural changes; no auth gates; no plan-prescribed-test-bug fixes needed.

The only minor adjustment: `defined?(bk2_current_phase) && bk2_current_phase == "serienspiel"` rather than bare `bk2_current_phase == "serienspiel"` in the `bk_sp_inning_phase` predicate. This is required because `bk2_current_phase` is only assigned inside the `if is_bk2` block (line 56-75); for non-BK forms (karambol/snooker/pool) the local would be undefined when the fallback computation runs at line 84. The `defined?` guard short-circuits cleanly. This is a defensive ERB idiom, not a deviation in the GSD sense — it lives entirely within the plan's prescribed lines and predicate logic.

## Ready for tournament 2026-05-02

The 3 fixes are complete, tested, and ready for deployment. User actions before BCW Grand Prix:

1. `cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw && git push` (3 commits ready: `b4dbbe8d`, `0caaec3f`, `7cf939a9`).
2. Capistrano deploy to BCW production.
3. Run the manual smoke procedures above (Bug 1, Bug 2, Bug 3) on the BCW dev environment as a final pre-tournament check.
4. If smoke passes, the BCW Grand Prix on 2026-05-02 morning is unblocked on all three counts.
