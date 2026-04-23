---
phase: 260423-k9v
plan: 01
subsystem: models/season
tags: [bugfix, season, cache-removal, typo-fix]
requires:
  - Quick task 260422-pz0 (merge origin/master) completed at 8b7a8a3c
provides:
  - Typo fix in Season.current_season (undefined `year` local replaced with correctly-scoped var)
  - Removal of class-level eager-load state (`@year`, `@current_season`) that created cross-test pollution risk
affects:
  - app/models/season.rb (1 file, 5 insertions / 12 deletions)
key-files:
  modified:
    - app/models/season.rb
decisions:
  - "No-cache approach chosen: Season.current_season now queries DB on every call. Performance cost is negligible (indexed find_by_name on a small table) and the alternative (proper cache with invalidation) is out of scope for a flake-fix."
  - "update_seasons fallback preserved: missing Season still triggers auto-creation, so caller semantics unchanged."
metrics:
  duration: "~6 min"
  completed: 2026-04-23
---

# Phase 260423-k9v Plan 01: Fix Season.current_season typo + remove class-level caching — Summary

Removed the class-level `@year` / `@current_season` eager-load antipattern in `Season` and fixed a latent `NameError` on line 37 (`year` was undefined; `@year` was meant). The bug surfaced as a one-off flake in `RankingCalculatorTest` during the 260422-pz0 merge verification.

## Outcome (one-liner)

`Season.current_season` is now a plain stateless class method; no class-level state, no typo, no cross-test pollution vector.

## Commit

```
372c6344 fix(Season): remove class-level caching and year-typo in current_season
```

## Diff summary

- Deleted lines 25-26 (class-level eager-load of `@year` / `@current_season`)
- Rewrote `self.current_season` (lines 31-41 → 28-34): local `year` var + `find_by_name || update_seasons+retry` idiom
- Net: `1 file changed, 5 insertions(+), 12 deletions(-)`

## Verification Results

| # | Check | Result |
|---|---|---|
| 1 | `grep -n "@current_season\\|@year" app/models/season.rb` | no matches (exit 1) — PASS |
| 2 | `bin/rails test test/services/tournament/ranking_calculator_test.rb --seed=1` | 5 runs / 8 assertions / 0 failures / 0 errors / 0 skips — PASS |
| 3 | `bin/rails test test/services/tournament/ranking_calculator_test.rb --seed=54435` | 5 / 8 / 0 / 0 / 0 — PASS (the seed that flaked during 260422-pz0 verification) |
| 4 | `bin/rails test test/services/tournament/ranking_calculator_test.rb --seed=99999` | 5 / 8 / 0 / 0 / 0 — PASS |
| 5 | `RAILS_ENV=test bin/rails test` (full suite) | 1282 runs / 2883 assertions / 0 failures / 0 errors / 13 skips — PASS (matches 260422-pz0 baseline) |

## Deviations

1. **Worktree config-file copy** — the executor's worktree was missing gitignored config files (`config/database.yml`, `config/carambus.yml`, `config/cable.yml`, `config/deploy.rb`, `config/deploy/production.rb`, `config/environments/development.rb`). Copied from the canonical working tree at `/Users/gullrich/DEV/carambus/carambus_gu/config/`. No tracked files changed — the copy-in only affected the isolated worktree.

2. **Branch-base reset** — worktree started at `7ac9990f` (master-tip) instead of the expected `8b7a8a3c` (training-system-tip). The `worktree_branch_check` guard corrected this via `git reset --soft 8b7a8a3c`. The 1282-run baseline only holds on training-system-tip because master-tip lacks the ~131 new Ontologie-v0.9 tests.

## Memory Status

No memories to retire. The fix addresses a latent bug, not a documented workaround.
