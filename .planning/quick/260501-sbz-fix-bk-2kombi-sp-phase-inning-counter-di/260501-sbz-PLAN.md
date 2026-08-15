---
quick_id: 260501-sbz
description: Fix BK-2kombi SP-phase inning counter display
date: 2026-05-01
status: in-progress
mode: quick
files_changed:
  - app/views/table_monitors/_scoreboard.html.erb
must_haves:
  - The BK-2kombi SP-phase badge displays the current inning number (analog karambol-else-branch)
  - "Aufnahmen übrig" label is no longer rendered
  - DZ-phase badge stays empty (unchanged behavior)
  - The bk2_state["innings_left_in_set"] field stays in the data shape (service layer untouched)
---

# Quick Task 260501-sbz: Fix BK-2kombi SP-phase Inning Counter Display

## Context

User reported live from BCW club (2026-05-01) while running BK-2kombi matches:
- Detail-Page-started game: Aufnahmelimit 5 wird korrekt angewendet, ABER der Aufnahmen-Counter wird in der SP-Phase ("BK-2 Phase des BK-2kombi") nicht angezeigt
- Quickstart-started game: Limit wird gar nicht angewendet (Bug 1 — deferred)

Root cause for the missing counter: `bk2_state["innings_left_in_set"]` is **only** set during initial state init (`Bk2::AdvanceMatchState#init_state_if_missing!`), and **only** when SET 1 is serienspiel. For BK-2kombi default (DZ-first), this stays at 0 forever. The view condition `bk2_innings_left.to_i != 0` (added yesterday in `d3c1b1c8` to suppress the badge when no limit is set) then permanently hides the counter in SP phase.

User-Wunsch: Spieler sind den Counter aus dem BK-2-Standalone-Pfad gewohnt — sie wollen die aktuelle Aufnahme sehen, "Aufnahmen übrig" ist nicht nötig.

## Approach

Replace the broken `bk2_state["innings_left_in_set"]`-based counter with the karambol-style "current inning + of N" display. The karambol-else-branch (lines 122-128 in `_scoreboard.html.erb`) already has the correct kickoff-aware logic — copy it into the BK-2kombi SP-phase badge slot.

Source of truth for the limit: `options[:innings_goal]` (set to 5 by Detail Page controller path; set to 0 by Quickstart). The `if options[:innings_goal] > 0` guard means the "of N" suffix appears only when a limit is configured — so Quickstart still shows just the inning number without "of 0", no regression.

## Tasks

### Task 1: Apply view edit

**File:** `app/views/table_monitors/_scoreboard.html.erb`

**Action:** Two edits in the same file:

1. Line 67 — remove obsolete local:
   - DELETE: `<%- bk2_innings_left = bk2_state["innings_left_in_set"].to_i %>`

2. Lines 113-121 — replace the badge content (BK-2kombi SP-phase counter):
   - Replace the existing `Aufnahmen-übrig` block with kickoff-aware current-inning display, mirroring the karambol-else-branch logic at lines 122-128.

**Verify:**
- Run `bundle exec erblint app/views/table_monitors/_scoreboard.html.erb` — no new violations
- View renders without raising in Rails console: `ApplicationController.render(template: 'table_monitors/_scoreboard', locals: {table_monitor: tm, fullscreen: false})` (skip if no live tm available)

**Done when:**
- Both edits applied
- File still parses (no ERB syntax error)
- erblint passes on the file

### Task 2: Manual UAT in browser (user-driven, not blocking)

User will verify in the club:
1. Start BK-2kombi via Detail Page with innings_choice=5
2. Play through DZ phase (set 1) — DZ badge stays empty (unchanged)
3. Enter SP phase (set 2 = "BK-2 Phase") — badge should now show "1 of 5", "2 of 5", ... as innings progress
4. Verify counter resets at next SP-phase set boundary (set 3 stays DZ in DZ-first config; if SP-first config, set 3 is SP and counter resets to 1)

## Constraints

- View change only — no model/controller/service modifications
- Single file: `app/views/table_monitors/_scoreboard.html.erb`
- Don't touch the karambol-else-branch (lines 122-128) — pattern source, leave intact
- Don't remove `innings_left_in_set` from `Bk2::AdvanceMatchState` init — still in the data shape, just stop reading it in the view
- Single commit
