---
phase: 260501-pud
plan: 01
subsystem: scoreboard
tags: [config, training-mode, scoreboard, fullname, BCW, extend-before-build]
requires:
  - Carambus.config (existing OpenStruct memoized config)
  - TableMonitor::OptionsPresenter (existing presenter, untouched outside the 8 LOC delta)
provides:
  - Carambus.config.training_mode_show_fullname (boolean, default false)
  - elsif guard in player_a + player_b fullname blocks (8 LOC each branch ladder)
affects:
  - scoreboard rendering for non-team non-guest registered players in training mode
tech-stack:
  added: []
  patterns:
    - extend-before-build SKILL — single elsif on existing predicate ladder
    - sparse-key default via OpenStruct (nil → falsy → unverändertes Verhalten)
    - test helper with_config saves/restores Carambus.config in ensure block
key-files:
  created:
    - .planning/quick/260501-pud-add-training-mode-show-fullname-config-f/260501-pud-SUMMARY.md
  modified:
    - app/models/table_monitor/options_presenter.rb
    - test/models/table_monitor/options_presenter_test.rb
    - config/carambus.yml.erb
    - config/carambus.yml (gitignored — synced manually per Phase 38.4 D-decision)
decisions:
  - "Single new elsif arm on existing if/elsif/else ladder — extend-before-build SKILL applied; no new helper class, no new module, no parallel rendering path."
  - "Default value false documented in config/carambus.yml.erb default: block — explicit even though OpenStruct returns nil for absent keys (helps operators discover the flag)."
  - "config/carambus.yml (gitignored compiled mirror) edited in lockstep with .erb per Phase 38.4 D-decision (Carambus.config reads local .yml, not .erb)."
  - "BCW-specific override training_mode_show_fullname: true is OUT OF SCOPE — explicitly an operator deploy step before BCW Grand Prix 2026-05-02, NOT a code change."
metrics:
  duration_seconds: 172
  duration_human: "~3 min"
  tasks_completed: 3
  tests_added: 5
  loc_added: 14 # 8 in options_presenter.rb (4+4) + 6 in carambus.yml.erb (matching 6 in carambus.yml)
  loc_removed: 0
  files_changed: 4
  completed: 2026-05-01
---

# Quick Task 260501-pud: Add training_mode_show_fullname Config Flag — Summary

## One-liner

Added `Carambus.config.training_mode_show_fullname` boolean (default `false`) — single guard `elsif` in `OptionsPresenter` between the existing `guest?` arm and the `else` truncation, in BOTH `player_a` and `player_b` `fullname:` blocks; gives BCW operator a no-code-change toggle to show full registered-player names on the training-mode scoreboard for the 2026-05-02 Grand Prix.

## What changed

### Code (8 LOC, 2 files)

- `app/models/table_monitor/options_presenter.rb` (+8 LOC)
  - Line 110: new `elsif Carambus.config.training_mode_show_fullname` arm in `player_a` fullname block (with German comment block).
  - Line 146: identical guard in `player_b` fullname block (with single-line "siehe oben" comment).
  - All other arms (Tournament-mode + Team / `guest?` / `else` truncation) UNCHANGED.

### Tests (+125 LOC)

- `test/models/table_monitor/options_presenter_test.rb` (+125 LOC)
  - New `with_config(**overrides)` helper (sichert/restauriert `Carambus.config` im ensure-Block).
  - 5 new tests:
    - **Test A (default flag=false)** — pinned current behavior: returns `simple_firstname.presence || lastname` (= "Max" / "Erika" with default fixture).
    - **Test B (flag=true)** — non-team non-guest in training mode → returns `player.fullname` (= "Muster, Max" / "Beispiel, Erika").
    - **Test C (flag=true + guest)** — guest path UNCHANGED; both players come out with `player.fullname`.
    - **Test D (flag=true + tournament_monitor present)** — Tournament-Zweig wins, `player.fullname` regardless of flag.
    - **Test E (flag=false + tournament_monitor present)** — regression-guard partner of D.
  - Pre-existing 12 tests still GREEN.

### Config (4 LOC × 2 files)

- `config/carambus.yml.erb` (+6 LOC) — `training_mode_show_fullname: false` in `default:` block with German comment block.
- `config/carambus.yml` (+6 LOC, gitignored, synced manually per Phase 38.4 D-decision) — same key/value/comments.

## Test results

```
Final run: bin/rails test test/models/table_monitor/options_presenter_test.rb
17 runs, 61 assertions, 0 failures, 0 errors, 0 skips
```

RED phase (Task 1, before guard added):
```
17 runs, 60 assertions, 2 failures, 0 errors, 0 skips
  Test B fails: "Erwartet 'Muster, Max' bei flag=true, erhalten: 'Max'"
  Test C registered-player branch fails: "Erwartet 'Beispiel, Erika', erhalten: 'Erika'"
```

GREEN phase (Task 2, after guard added): all 17 tests pass.

Post-Task 3: re-ran tests after YAML edits — 17 runs, 0 failures (no regression from the YAML default-block addition).

## standardrb output

`bundle exec standardrb app/models/table_monitor/options_presenter.rb` — only PRE-EXISTING offenses on lines 29, 31, 175-178, 188, 190-192 (Layout/AccessModifierIndentation, IndentationWidth, ElseAlignment, EndAlignment, MultilineOperationIndentation). NONE at the new lines 110-115 / 146-150 — the new `elsif` arms match surrounding-style indentation perfectly. Out-of-scope per CLAUDE.md (existing standardrb baseline carries forward).

`bundle exec standardrb test/models/table_monitor/options_presenter_test.rb` — only pre-existing offenses (Style/RandomWithOffset on line 77, 84; Layout/SpaceInsideHashLiteralBraces on lines 193-194, 297-298 from existing tests). New test code at line 373/374 mirrors the existing test-file convention (same `{ space ... space }` pattern as the disambiguation tests at lines 193-194 and 297-298). Zero NEW offenses introduced.

## Verification command outputs

```
$ ruby -ryaml -e "puts YAML.load_file('config/carambus.yml').dig('default', 'training_mode_show_fullname').inspect"
false

$ bin/rails runner "puts Carambus.config.training_mode_show_fullname.inspect"
false

$ grep -n "training_mode_show_fullname" app/models/table_monitor/options_presenter.rb
110:                    elsif Carambus.config.training_mode_show_fullname
146:                    elsif Carambus.config.training_mode_show_fullname

$ grep -c "is_a?(Team)" app/models/table_monitor/options_presenter.rb
2   # UNCHANGED — Team arm preserved

$ grep -c "guest?" app/models/table_monitor/options_presenter.rb
4   # UNCHANGED (2 in logo: blocks lines 94/125 + 2 in fullname blocks lines 108/139)
```

## Operator deployment note (BCW Grand Prix 2026-05-02)

**This task ships the code path. The BCW-specific activation is a separate operator step.**

To enable full names on BCW for the 2026-05-02 Grand Prix, the operator must:

1. Edit BOTH files in the BCW deployment checkout:
   - `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/config/carambus.yml.erb`
   - `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/config/carambus.yml` (gitignored — must be synced manually)

2. Override the default by adding `training_mode_show_fullname: true` to the **`production:` block** (NOT `default:` — leave default at false to keep all other scenarios unchanged):

```yaml
production:
  ...existing keys...
  training_mode_show_fullname: true
```

3. Deploy via Capistrano: `cap production deploy` from `carambus_bcw/`.

4. **Restart Rails on the production server** (`Carambus.config` is memoized at process boot via `@config ||=` — config reload requires process restart).

5. Verify on the production server: open a training-mode scoreboard for a non-team non-guest registered player → name shows as "Muster, Max" instead of "Max".

To revert: remove the `production:` override and restart Rails. Default `false` resumes truncated behavior.

## Scenario-management precondition check

Pre-edit check ran across all 4 checkouts:
- `carambus_master`: branch `master`, working tree clean.
- `carambus_bcw`: branch `master`, working tree had only untracked `.claude/worktrees/` and the new `.planning/quick/260501-pud-...` directory (not load-bearing for code edits).
- `carambus_phat`: branch `master`, working tree dirty on `app/controllers/docs_controller.rb`, `config/cable.yml`, `public/docs/**` (none of the files I modified — no conflict potential).
- `carambus_api`: branch `master`, working tree clean.

Edits applied to **`carambus_bcw/`** (current CWD) per the workflow_note in the executor prompt: this session has been operating in implicit Debugging Mode for BCW (Phases 38.7, 38.8, 38.9 all landed here, were pushed to origin, and synced back to master + api via `git pull --ff-only`). The orchestrator handles the cross-checkout sync after the executor returns.

## Threat model attestation

| Threat ID | Disposition | Verification |
|-----------|-------------|--------------|
| T-260501-01 (I — fullname disclosure) | accept | Operator-controlled flag; no remote write surface; default false preserves existing disclosure model. |
| T-260501-02 (T — test config tampering) | mitigate | `with_config` helper uses `ensure` block to restore `Carambus.config = original` after every test. Cross-test independence verified: 17/17 tests pass with `--seed 14153`, `--seed 28742`, `--seed 62117` (seed-stable). |
| T-260501-03 (E — cross-checkout edits) | mitigate | Pre-edit precondition check ran; BCW debugging mode honored per session workflow_note. |

No new threat surface introduced — the new arm extends the same disclosure model already exercised by the Tournament-mode + Team and Guest arms (which already returned `player.fullname` unconditionally).

## Deviations from plan

None. Plan executed exactly as written, all 3 tasks landed atomically.

## Self-Check

Files exist on disk:
- `app/models/table_monitor/options_presenter.rb` — FOUND (lines 110, 146 carry the new elsif).
- `test/models/table_monitor/options_presenter_test.rb` — FOUND (with_config helper + 5 new tests).
- `config/carambus.yml.erb` — FOUND (line 25: `training_mode_show_fullname: false`).
- `config/carambus.yml` — FOUND (line 25: `training_mode_show_fullname: false`).

Commits exist:
- `ba513970` test(260501-pud): add RED tests — FOUND.
- `d34bc1de` feat(260501-pud): add guard — FOUND.
- `a5c90fa7` chore(260501-pud): document default in carambus.yml.erb — FOUND.

## Self-Check: PASSED

## Commits

| Task | Commit  | Type    | Message                                                              |
|------|---------|---------|----------------------------------------------------------------------|
| 1    | ba513970 | test    | add RED tests for training_mode_show_fullname flag                  |
| 2    | d34bc1de | feat    | add training_mode_show_fullname guard to OptionsPresenter           |
| 3    | a5c90fa7 | chore   | document training_mode_show_fullname default in carambus.yml.erb    |
