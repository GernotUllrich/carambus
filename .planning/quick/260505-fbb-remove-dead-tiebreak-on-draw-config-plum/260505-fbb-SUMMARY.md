---
phase: 260505-fbb
plan: "01"
subsystem: tiebreak / table_monitor / game_setup
tags:
  - tiebreak
  - cleanup
  - dead-code
  - extend-before-build
dependency_graph:
  requires:
    - 260505-auq  # playing_finals_force_tiebreak_required! override (canonical path)
  provides:
    - Dead tiebreak_on_draw config plumbing fully removed
  affects:
    - app/models/game.rb
    - app/controllers/table_monitors_controller.rb
    - app/controllers/tournament_monitors_controller.rb
    - app/views/tournament_monitors/_form.html.erb
    - app/views/locations/_quick_game_buttons.html.erb
    - app/views/locations/scoreboard_free_game_karambol_new.html.erb
    - app/services/table_monitor/game_setup.rb
    - app/services/table_monitor/result_recorder.rb
    - config/locales/de.yml
    - config/locales/en.yml
    - test/models/game_test.rb
    - test/services/table_monitor/game_setup_test.rb
    - test/controllers/tournament_monitors_controller_test.rb
    - test/controllers/table_monitors_controller_test.rb
    - test/system/tiebreak_test.rb (doc-comment-only)
tech_stack:
  added: []
  patterns:
    - Dead config chain collapsed back to state-driven override (extend-before-build inverse)
key_files:
  created: []
  modified:
    - app/models/game.rb
    - app/controllers/table_monitors_controller.rb
    - app/controllers/tournament_monitors_controller.rb
    - app/views/tournament_monitors/_form.html.erb
    - app/views/locations/_quick_game_buttons.html.erb
    - app/views/locations/scoreboard_free_game_karambol_new.html.erb
    - app/services/table_monitor/game_setup.rb
    - app/services/table_monitor/result_recorder.rb
    - config/locales/de.yml
    - config/locales/en.yml
    - test/models/game_test.rb
    - test/services/table_monitor/game_setup_test.rb
    - test/controllers/tournament_monitors_controller_test.rb
    - test/controllers/table_monitors_controller_test.rb
    - test/system/tiebreak_test.rb
decisions:
  - "Removed entire Game.derive_tiebreak_required + Game.parse_data_hash — resolver only ever read g{N} executor_param buckets; real tournament plans use hf*/fin/p<*> keys, confirming the plumbing was already broken before Quick-260505-auq landed"
  - "carambus.yml + carambus.yml.erb tiebreak_on_draw: true on BK-2 + BK-2kombi presets left AS-IS — no consumer remains; YAML-edit-pair convention (Phase 38.4 decision) defers removal to a separate quick task"
  - "erblint violations in scoreboard_free_game_karambol_new.html.erb are all pre-existing (Alpine x-bind syntax + void element patterns) — not introduced by our deletion; left unchanged per scope-boundary rule"
  - "standardrb violations in game.rb / controllers are all pre-existing; lines edited by this plan are clean"
metrics:
  duration: "~35 minutes"
  completed_date: "2026-05-05"
  tasks_completed: 3
  tasks_total: 4
  files_modified: 15
  loc_delta: "-627 net (11 additions, 638 deletions)"
---

# Quick Task 260505-fbb: Remove Dead tiebreak_on_draw Config Plumbing

**One-liner:** Removed 638 LOC of dead Phase 38.7-04/09/10/12 tiebreak_on_draw config plumbing (resolver, controllers, views, i18n, tests) now that Quick-260505-auq's `playing_finals_force_tiebreak_required!` state-driven override is the canonical path.

## Why This Cleanup Is Safe Now

Two canonical tiebreak-trigger paths survive and are tested:

1. **`TableMonitor#playing_finals_force_tiebreak_required!`** (Quick-260505-auq, commit `94c488df`) — fires when `TournamentMonitor#playing_finals?` at decision time. 5 regression tests (M1–M4 in table_monitor_test.rb, R1 in result_recorder_test.rb) lock this path.

2. **`ResultRecorder#bk2_kombi_tiebreak_auto_detect!`** (Phase 38.7-11) — fires when BK-2kombi BK-2-phase tied at goal in 1+1 innings. Tests in result_recorder_test.rb lock this path.

The deleted resolver (`Game.derive_tiebreak_required`) had an architectural mismatch: it only read `g{N}` executor_param buckets, but real tournament plans carry tiebreak keys under `hf*/fin/p<*>` gnames. The resolver was broken before the override landed — the override simply made the broken plumbing irrelevant. The user has also scrubbed matching `tiebreak_on_draw` data from carambus_api production (2026-05-05).

## Files Modified and What Was Removed

| File | Removed |
|------|---------|
| `app/models/game.rb` | `Game.derive_tiebreak_required` class method (53 LOC) + `Game.parse_data_hash` helper (8 LOC) |
| `app/services/table_monitor/game_setup.rb` | Resolver-bake block lines 366-405 (40 LOC): `if @tm.game.present?` block calling `derive_tiebreak_required` + preset override branch + `deep_merge_data!` write |
| `app/controllers/table_monitors_controller.rb` | `:tiebreak_on_draw` from `params.permit` list + 10-line bool-coercion block in quick_game_form branch |
| `app/controllers/tournament_monitors_controller.rb` | `@tiebreak_on_draw_default` assignments in `new`/`edit`/`create`/`update`; `derive_tiebreak_default` private method (16 LOC); `persist_tournament_tiebreak_override` private method (32 LOC) |
| `app/views/tournament_monitors/_form.html.erb` | Checkbox group for `tournament_tiebreak_on_draw` (15 LOC including comment block) |
| `app/views/locations/_quick_game_buttons.html.erb` | `hidden_field_tag :tiebreak_on_draw` + comment (6 LOC) in BK-family branch |
| `app/views/locations/scoreboard_free_game_karambol_new.html.erb` | `content_tag :div#tiebreak_on_draw` + label block (19 LOC) |
| `config/locales/de.yml` | `tournament_monitors.form.tiebreak_on_draw` + `locations.scoreboard_free_game.tiebreak_on_draw` keys (+ empty parent `locations:` block) |
| `config/locales/en.yml` | Same two keys (+ empty parent `locations:` block) |
| `test/models/game_test.rb` | Entire Phase 38.7-04 resolver test block (7 tests, 88 LOC) → empty class + tombstone comment |
| `test/services/table_monitor/game_setup_test.rb` | Lines 367-532: Phase 38.7-04 bake tests + `build_mock_tm_with_plan` helper + Phase 38.7-09 G1/G2/G3 tests (166 LOC) |
| `test/controllers/tournament_monitors_controller_test.rb` | Phase 38.7-12 Gap-04 G1/G2/G3/G4 tests (85 LOC) |
| `test/controllers/table_monitors_controller_test.rb` | Phase 38.7-10 Gap-02 G1/G2 tests (49 LOC) |
| `test/system/tiebreak_test.rb` | Doc-comment header updated (lines 8-9) to reference `playing_finals?` override + `bk2_kombi_tiebreak_auto_detect!` as canonical paths (no test bodies changed) |
| `app/services/table_monitor/result_recorder.rb` | Comment at line 453 updated: replaced "opts into tiebreak_on_draw" with reference to `bk2_kombi_tiebreak_auto_detect!` + `playing_finals_force_tiebreak_required!` as canonical triggers |

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| `4a6f7f5d` | test | Remove dead-code tests for tiebreak_on_draw config plumbing (Task 1) |
| `de0e7340` | refactor | Remove dead tiebreak_on_draw config plumbing — playing_finals? override is canonical (Task 2) |

## Test Results (Task 3 Regression Sweep)

| Suite | Runs | Assertions | Failures | Errors | Skips |
|-------|------|-----------|----------|--------|-------|
| game_test + table_monitor_test + result_recorder_test + game_setup_test + table_monitors_controller_test + tournament_monitors_controller_test + tiebreak_modal_form_wiring_test + local_protector_test | 136 | 293 | 0 | 0 | 4 |
| system/tiebreak_test | 4 | 32 | 0 | 0 | 0 |
| system/final_match_score_operator_gate_test | 4 | 19 | 0 | 0 | 0 |
| reflexes/game_protocol_reflex_test | 8 | 24 | 0 | 0 | 0 |
| test:critical (concerns + scraping) | 29 | 55 | 0 | 0 | 0 |

**Straggler grep result:** Zero hits for all deleted symbols across `app/ test/ lib/ config/ db/`.

**Boot smoke:** `TableMonitor.first&.id` returns `50000002`, `Game.method_defined?(:data)` returns `true`, exits with `OK`.

**i18n smoke:** Both `I18n.t("tournament_monitors.form.tiebreak_on_draw", default: "REMOVED")` and `I18n.t("locations.scoreboard_free_game.tiebreak_on_draw", default: "REMOVED", locale: :en)` print `REMOVED`.

## Known Dead Config (Deferred)

`config/carambus.yml` and `config/carambus.yml.erb` still carry `tiebreak_on_draw: true` on BK-2 + BK-2kombi quick_game_presets entries. The only consumer was the `hidden_field_tag :tiebreak_on_draw` in `_quick_game_buttons.html.erb`, which is now deleted. These YAML keys are dead config with no consumer.

Removal deferred to a follow-up quick task because the project requires `carambus.yml.erb` and `carambus.yml` to be edited in pairs (Phase 38.4 decision: "carambus.yml (compiled/ignored) must be kept in sync with carambus.yml.erb manually"). That synchronized edit is a separate, clean atomic operation.

## Scenario-Management Note

Ran on `carambus_bcw` / `go_back_to_stable` branch (debugging-mode-style edit on feature branch, independent of `master`). Both commits are on this branch only. User to handle cross-checkout sync per scenario-management SKILL workflow (lines 113-131) after master promotion.

## Deviations from Plan

None — plan executed exactly as written. The pre-existing erblint violations in `scoreboard_free_game_karambol_new.html.erb` (Alpine `x-bind` syntax, void element patterns) were present before our edit and are out of scope per the scope-boundary rule. The standardrb violations reported are also all pre-existing on unrelated lines.

## Self-Check: PASSED

- FOUND: `.planning/quick/260505-fbb-remove-dead-tiebreak-on-draw-config-plum/260505-fbb-SUMMARY.md`
- FOUND: commit `4a6f7f5d` (test deletions)
- FOUND: commit `de0e7340` (production code deletions)
