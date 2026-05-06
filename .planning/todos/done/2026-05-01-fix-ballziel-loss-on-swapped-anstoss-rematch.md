---
created: 2026-05-01T17:10:45.784Z
title: Fix Ballziel loss on swapped-Anstoß rematch (training-mode start_rematch)
area: general
files:
  - app/models/table_monitor.rb:1409-1441 (revert_players — suspect site)
  - app/models/table_monitor.rb:402-410 (:start_rematch AASM event from Phase 38.8)
  - app/models/table_monitor.rb:594-612 (do_play after-callback)
  - app/services/table_monitor/game_setup.rb (balls_goal default fallback — likely 50)
  - app/services/table_monitor/result_recorder.rb (post-match data mutation)
  - app/models/table_monitor/score_engine.rb (set_open / terminate_inning_data)
  - app/services/table_monitor/bk_param_resolver.rb (Phase 38.5 per-set baking)
---

## Problem

After a game completes (state `final_match_score` / "Endergebnis erfasst") and the operator clicks the "Nächstes Spiel" button (training-mode rematch path landed in Phase 38.8), the new game starts with swapped Anstoßer roles — but the Ballziel field shows "?" or falls back to a default 50 instead of the previous game's value (e.g., 70).

**Suspect site:** `app/models/table_monitor.rb:1409-1441` (`revert_players` after-callback on `:start_rematch`):

```ruby
"balls_goal_a" => data["playerb"]["balls_goal"].to_i,
"balls_goal_b" => data["playera"]["balls_goal"].to_i,
```

If the post-match data mutation chain (Phase 38.7 multiset balls_goal-per-set / Phase 38.8 final_match_score AASM transitions / Phase 38.9 close-side mirror) leaves `data["playerN"]["balls_goal"]` nil/blank at the moment `revert_players` reads it, the `.to_i` silently returns `0`, and `GameSetup` then falls back to its default Ballziel ("50 statt 70" matches that pattern). The "?" rendering happens when the value is genuinely missing in the new game's data.

**Reported by user during BCW production verification 2026-05-01** after Phase 38.9 deploy. Not blocking for the 2026-05-02 BCW Grand Prix because every match starts with different players (no rematches with role swap).

## Solution

TBD — needs systematic investigation. Recommended path: `/gsd-debug` session or `/gsd-insert-phase 38.10` after the Grand Prix.

**Reproduction steps:**

1. Start a BK-2 (or BK-2kombi-SP) match in training mode with `balls_goal=70`
2. Play through to `final_match_score` ("Endergebnis erfasst")
3. Click "Nächstes Spiel" (training-mode start_rematch path)
4. Observe new game's Ballziel — expect 70, will see "?" or 50

**Investigation hints:**

- Inspect `data` Hash state at end of `final_match_score` transition — is `balls_goal` cleared, moved, or just nil for one of the players?
- Compare with the working tournament-mode `:close_match` path (Phase 38.8 — that one DOES go through round-progression cascade, but Ballziel for next match comes from Tournament/TournamentPlan, not data carry-over)
- Check whether Phase 38.7 multiset baking writes `balls_goal` only into `current_inning` / `set_data` rather than the top-level `data["playerN"]` — if so, after final_match_score the top-level may legitimately be empty
- Probable fix: in `revert_players`, fall back through the same hierarchy `BkParamResolver` walks (Discipline → Tournament → ... → TableMonitor) instead of trusting `data["playerN"]["balls_goal"]` is still populated; OR snapshot Ballziel into `data["last_balls_goal_a/b"]` at end-of-match for the rematch path to consume

**Touches:**
- Phase 38.5 BkParamResolver per-set baking
- Phase 38.7 multiset balls_goal_a/b carry
- Phase 38.8 :start_rematch AASM event + revert_players + do_play after-callbacks
- Phase 38.9 close-side mirror (just landed — likely not the cause; bug pre-dates 38.9)

**Severity:** Cosmetic + behavioral. Workaround for any operator who hits it: re-enter Ballziel via the detail form before continuing the new game.

---

## Closure (2026-05-05)

Closed: both observed symptoms fixed by `45f9174c` (quick-260503-x3k) — `revert_players` now passes `data["bk2_options"]` through to `start_game`, restoring the BK-family score panel's `bk2_set_target` fallback (`data.dig("bk2_options", "balls_goal")`). Affected variants confirmed by user: BK-2 (single set), BK-2plus (multiset), BK-2kombi-SP / DZ.

- `?` rendering: gone (fallback now resolves to the configured Ballziel)
- `70 → 50` regression: gone (default 50 was the symptom of `bk2_options` being nil-forwarded; key is now preserved)

The wider speculative concern about `data["playerN"]["balls_goal"]` clearing for legacy karambol-side per-player goals (suspect site `revert_players:1409-1441` `data["playerb"]["balls_goal"].to_i`) never manifested in production. If it surfaces later, open a fresh todo / debug session — this one is closed.

See: `.planning/quick/260503-x3k-bk-rematch-loses-bk2-options-balls-goal-/260503-x3k-SUMMARY.md`.
