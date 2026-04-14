---
status: partial
phase: 36B-ui-cleanup-kleine-features
source: [36B-VERIFICATION.md]
started: 2026-04-14T18:30:00Z
updated: 2026-04-14T18:30:00Z
---

## Current Test

[awaiting human testing in carambus_bcw]

## Tests

### 1. Wizard header visual check (FIX-04 + FIX-03)
where: carambus_bcw (LOCAL context) — open any tournament show page
expected: |
  - Large colored AASM state badge is the visually dominant element in the header
    (orange for new_tournament, blue for accreditation_finished, green for tournament_started)
  - Six wizard bucket chips render below the badge with the active bucket highlighted
  - Progress bar and "Schritt N von 6" text are gone
  - No numeric prefixes (1., 2., etc.) appear in any step card header
result: [pending]

### 2. Active step help block auto-opens (FIX-01)
where: carambus_bcw — open a tournament in any non-closed state
expected: |
  - The active step's <details> help block is already open
  - Non-active steps' help blocks are collapsed
  - The troubleshooting "Turnier nicht gefunden?" block stays closed by default
result: [pending]

### 3. Parameter form tooltips (UI-01)
where: carambus_bcw — Turnier-Monitor parameter form (before start)
expected: |
  - Hovering any of the 16 parameter labels shows a dark Tailwind tooltip card with German explanatory text
  - Keyboard-focus (Tab to a label) also opens the tooltip
  - No tooltip flashes before or below viewport edges unexpectedly
  - admin_controlled row is gone entirely (no label, no checkbox)
result: [pending]

### 4. German parameter labels (UI-02)
where: carambus_bcw — Turnier-Monitor parameter form (DE locale)
expected: |
  - Every label reads in German (no English literals)
  - Switching to EN locale shows the English equivalents
result: [pending]

### 5. Dead-code _current_games table (UI-04)
where: carambus_bcw — open Turnier-Monitor page for a running tournament
expected: |
  - The "Aktuelle Spiele" table shows only read-only columns
  - No set_balls input field, no +1/-1/+10/-10 buttons, no undo/next buttons
  - The "OK?" / "wait_check" state-display link still works
  - Table-exchange up/down arrows still render
result: [pending]

### 6. Reset confirmation modal (UI-06)
where: carambus_bcw — open a tournament and click any Reset button
expected: |
  - A Tailwind modal appears (not a native browser confirm) with title, body, Cancel, and Confirm buttons
  - Body text shows current AASM state + number of games played inline
  - Cancel closes the modal without resetting; Confirm triggers the reset action
  - Modal is always shown regardless of AASM state
  - Works on both primary reset (show.html.erb) and force-reset (finalize_modus.html.erb)
result: [pending]

### 7. Parameter verification modal (UI-07)
where: carambus_bcw — parameter form, set balls_goal out of range (e.g., 99999), submit
expected: |
  - The start form submit re-renders with the shared confirmation modal auto-opening
  - Modal shows out-of-range values and asks for explicit confirmation
  - Cancel closes; Confirm passes the hidden override and starts the tournament
  - In-range values submit straight through to start_tournament! with no modal
  - No inline <script> runs — everything is Stimulus-driven
result: [pending]

### 8. admin_controlled removal end-to-end (UI-03)
where: carambus_bcw — Turnier-Monitor for tournament in play, confirm last game of round at scoreboard
expected: |
  - No "Rundenwechsel manuell bestätigen" checkbox in the parameter form
  - Round auto-advances without manual intervention when the last game of a round is confirmed
  - Behavior holds regardless of whether admin_controlled was previously true on an imported global record
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps
