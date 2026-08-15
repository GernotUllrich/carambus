---
quick_id: 260501-sbz
description: Fix BK-2kombi SP-phase inning counter display
date: 2026-05-01
status: complete
files_changed:
  - app/views/table_monitors/_scoreboard.html.erb
---

# Quick Task 260501-sbz: Summary

## What Changed

Replaced the broken `bk2_state["innings_left_in_set"]`-based "Aufnahmen übrig" counter in the BK-2kombi SP-phase badge with a karambol-style "current inning + of N" display. The new logic is a 1:1 copy of the kickoff-aware inning calculation already in use for BK-2 standalone (lines 122-128 of the same file).

## Files

**`app/views/table_monitors/_scoreboard.html.erb`** — 2 edits:

1. Removed obsolete local `bk2_innings_left = bk2_state["innings_left_in_set"].to_i` (line 67 in original)
2. Replaced the SP-phase badge content (lines 113-121 in original) — now derives the current inning from `right_player[:innings]` / `left_player[:innings]` + `delta`, and displays "N of M" when `innings_goal > 0`, else just "N"

Net diff: +1 line.

## Why

User reported live from BCW club (2026-05-01): in BK-2kombi matches started via Detail Page, the Aufnahmenlimit (5) was applied correctly (game terminated), but the inning counter was hidden in the SP phase ("BK-2 Phase des BK-2kombi"). Investigation:

- `bk2_state["innings_left_in_set"]` is only set during `Bk2::AdvanceMatchState#init_state_if_missing!` and ONLY when SET 1 is serienspiel (`advance_match_state.rb:72`).
- For BK-2kombi default (DZ-first): SET 1 is DZ → `innings_left_in_set = 0` → never re-baked at set transitions (verified via grep — only 2 references in entire codebase: init + view-read, no writes).
- Yesterday's fix `d3c1b1c8` masked the "no limit configured" case but the underlying loop-hole stayed open.

Player UX request: "Spieler sind den Counter aus dem BK-2-Standalone-Pfad gewohnt" — they want the same display as BK-2 standalone, not "Aufnahmen übrig".

## Verification

- `git diff` reviewed — change is exactly the planned 2-edit set
- `bundle exec erblint app/views/table_monitors/_scoreboard.html.erb` — no NEW violations (pre-existing extra-blank-line at line 207 was already there at line 206 before the edit; verified by stash/unstash diff)
- `grep "bk2_innings_left" app/views/table_monitors/_scoreboard.html.erb` — 0 hits (variable cleanly removed)
- `grep "bk2_current_inning" app/views/table_monitors/_scoreboard.html.erb` — 2 hits (assignment + render)
- ERB still parses (no syntax error reported)

## Manual UAT (user-driven, in club)

User to verify:
1. Start BK-2kombi via Detail Page with innings_choice=5 (DZ-first default)
2. SET 1 (DZ phase): badge stays empty — unchanged behavior
3. SET 2 (SP phase = "BK-2 Phase"): badge now shows "1 of 5", "2 of 5", ... as innings advance
4. SET 2 closes at "5 of 5" (or earlier on points goal) — game transitions to next set / final state
5. Counter display matches what players see in BK-2 standalone (familiar UX)

## Deferred (not in scope)

- **Bug 1 (Quickstart `innings_goal=0`):** `app/views/locations/_quick_game_buttons.html.erb:149` hardcodes `innings_goal=0` for BK-family. Detail Page sends 5. Tracked as backlog 999.x — user accepted "Detail Page reicht erstmal".
- **`bk2_shots_left` unused:** Line 66 of `_scoreboard.html.erb` reads `bk2_state["shots_left_in_turn"]` into a local that is never used (Stöße-übrig-Badge was removed in 38.4 R5-6). Out of scope; pure dead-code cleanup. Consider adding to a future sweep.
- **`bk2_state["innings_left_in_set"]` field still in data shape:** Service layer (`Bk2::AdvanceMatchState`) untouched per plan constraint. The field is initialized but never read after this commit. Safe to remove in a future cleanup phase.

## Commit

Will be created as: `fix(scoreboard): show current inning instead of Aufnahmen-übrig in BK-2kombi SP phase`
