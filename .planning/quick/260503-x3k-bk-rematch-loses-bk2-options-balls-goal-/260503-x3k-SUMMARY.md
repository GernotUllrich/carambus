---
phase: quick-260503-x3k
plan: 01
subsystem: scoreboard / BK-Familie / rematch
tags: [bug-fix, bk2-options, revert-players, rematch, ballziel, extend-before-build]
type: execute
requires:
  - app/models/table_monitor.rb#revert_players
  - app/services/table_monitor/game_setup.rb#build_result_hash
provides:
  - bk2_options pass-through through revert_players → start_game → GameSetup → new game's data
affects:
  - app/views/table_monitors/_player_score_panel.html.erb (BK-2 / BK-2plus Ballziel display)
tech-stack:
  added: []
  patterns:
    - one-line-pass-through-key-in-options-hash
    - extend-before-build (no new methods, no conditionals, no parallel state machine)
key-files:
  created: []
  modified:
    - app/models/table_monitor.rb
    - test/models/table_monitor_test.rb
decisions:
  - One-line fix: add `"bk2_options" => data["bk2_options"]` in `revert_players` options hash adjacent to `"free_game_form"` (semantic grouping, both describe discipline/scoring shape).
  - No service-layer changes: `GameSetup#build_result_hash` already wires `"bk2_options" => @options["bk2_options"]` at line 484. Nil round-trips correctly for non-BK games.
  - Test pattern: stub `start_game` + `update` + `game.game_participations` chain on the @tm singleton to capture options without invoking GameSetup or requiring a real Game/GameParticipation fixture. Direct unit test of `revert_players`'s options assembly.
  - Two tests: BK-2plus rematch (asserts balls_goal=70 + DZ=2 + SP=5 round-trip) + non-BK karambol regression guard (asserts nil round-trips, no harm to non-BK games).
metrics:
  duration: ~9m
  completed: 2026-05-03
  tasks: 2
  files: 2
  commits: 2
---

# Quick 260503-x3k: BK-rematch loses bk2_options.balls_goal — Summary

## One-liner

BK-2 / BK-2plus rematch ("Nächstes Spiel" after final_match_score) lost the configured Ballziel because `TableMonitor#revert_players` built an 18-key options hash for `start_game` without `bk2_options`. Fixed by adding the single missing pass-through key — `data["bk2_options"]` now round-trips through revert_players → GameSetup → new game's data, restoring the BK-family scoreboard's `bk2_set_target` fallback path.

## The Fix (one quoted line in `app/models/table_monitor.rb`)

```ruby
"bk2_options" => data["bk2_options"],
```

Inserted at `revert_players`'s options hash, immediately after `"free_game_form" => data["free_game_form"]` and before `"first_break_choice" => data["first_break_choice"]`. Six lines total including a 5-line comment explaining intent and the BK-family fallback contract.

## RED → GREEN test transition

- **Task 1 (RED)** — commit `f6cda79b`: added 2 tests + 2 helpers (`stub_revert_players_dependencies!` + `seed_revert_players_data!`) to `test/models/table_monitor_test.rb`.
  - BK-2plus test: 1 failure with the targeted message `"revert_players MUST forward bk2_options to start_game (today omits the key — TEST EXPECTED TO FAIL BEFORE TASK 2)"`. `Expected nil to be a kind of Hash, not NilClass.` confirmed bug pinpointed.
  - Non-BK karambol regression test: passed already (nil → nil round-trip baseline).
- **Task 2 (GREEN)** — commit `45f9174c`: 6-line addition to `revert_players`. Targeted suite: `2 runs, 7 assertions, 0 failures`. Both BK-2plus + non-BK tests now GREEN.

## Verification

| Suite                                            | Result                              |
| ------------------------------------------------ | ----------------------------------- |
| `test/models/table_monitor_test.rb -n /quick-260503-x3k/` | 2 runs, 7 assertions, 0 failures   |
| `test/models/table_monitor_test.rb` (full)       | 32 runs, 63 assertions, 0 failures (was 30, +2 new) |
| `test/integration/tiebreak_modal_form_wiring_test.rb` | 4 runs, 20 assertions, 0 failures |
| `test/reflexes/game_protocol_reflex_test.rb`     | 8 runs, 24 assertions, 0 failures  |

## Confirmation: BK-rematch behavior

After this fix:

- **BK-2 / BK-2plus standalone rematches** retain their Ballziel (e.g. 70 stays 70). The score panel reads `data.dig("bk2_options", "balls_goal")` as fallback when `bk2_state` is empty — which is the case for all BK-* disciplines except BK-2kombi. Now that `bk2_options` is preserved, the fallback returns 70, `bk2_set_target` resolves to 70, and the score panel renders `70` instead of `"?"` or the default `50`.
- **Non-BK games** (karambol / snooker / pool) are unaffected. `data["bk2_options"]` is nil → forwarded as `"bk2_options" => nil` → `GameSetup#build_result_hash` writes `data["bk2_options"] = nil` (already its no-op behavior since line 484 was stable for nil input). Verified by the regression-guard test.
- **BK-2kombi** is also covered: it carries `bk2_options` with `balls_goal` set, and is the discipline that initializes `bk2_state`. The BK-2kombi score panel uses the populated `bk2_state["balls_goal"]` (not the fallback), but the bk2_options pass-through still ensures the new game has the right `direkter_zweikampf_max_shots_per_turn` / `serienspiel_max_innings_per_set` per-discipline knobs after a rematch.

## Extend-before-build SKILL applied

This fix exemplifies the SKILL: ONE new key in the existing options hash. NO new method, NO new predicate, NO conditional. The existing pipeline (revert_players → start_game → GameSetup → build_result_hash) was already structured correctly — it just had a missing key on the first hop. Total diff: 6 added lines in one file (1 of which is the actual fix line, 5 are explanatory comment).

## Cross-reference

Pending todo `.planning/todos/pending/2026-05-01-fix-ballziel-loss-on-swapped-anstoss-rematch.md` describes a related-but-orthogonal concern: **top-level `data["balls_goal"]` clearing** during the post-match data mutation. That todo's symptom (Ballziel shows "?" or 50 in the new game) overlaps with the BK-family symptom this quick task fixed via `bk2_options` pass-through, but the underlying surfaces are distinct:

- **THIS quick task** — fixes the BK-family score panel's `bk2_set_target` fallback (`data.dig("bk2_options", "balls_goal")` returning nil in the new game). Resolved.
- **Pending todo `2026-05-01-…`** — wider concern about `data["playerN"]["balls_goal"]` (legacy karambol per-player goal) and/or top-level `data["balls_goal"]` clearing during the rematch dance. Remains open and tracked. Karambol/snooker/pool rematches that lose Ballziel via that path are NOT addressed by this commit.

If user reports persist after this fix, the wider concern in the pending todo is the next surface to investigate.

## Commits

| Task | Commit    | Message                                                                       |
| ---- | --------- | ----------------------------------------------------------------------------- |
| 1    | `f6cda79b` | test(quick-260503-x3k): RED regression for revert_players dropping bk2_options |
| 2    | `45f9174c` | fix(quick-260503-x3k): preserve bk2_options through revert_players for BK-rematch |

## Self-Check: PASSED

- `app/models/table_monitor.rb` — modified, 6 LOC added at revert_players around line 1432-1438 (verified)
- `test/models/table_monitor_test.rb` — modified, 83 LOC added at end of test class (verified)
- Commit `f6cda79b` — exists in git log (verified)
- Commit `45f9174c` — exists in git log (verified)
- Targeted test suite GREEN (verified: 2 runs, 0 failures)
- Full table_monitor_test.rb GREEN (verified: 32 runs, 0 failures)
- Related suites GREEN (verified: tiebreak_modal_form_wiring_test, game_protocol_reflex_test)
