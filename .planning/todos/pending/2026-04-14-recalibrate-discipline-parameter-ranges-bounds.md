---
created: 2026-04-14T19:26:11.314Z
title: Recalibrate Discipline#parameter_ranges bounds
area: general
files:
  - app/models/discipline.rb
  - app/controllers/tournaments_controller.rb:311-317
---

## Problem

The pre-start parameter verification modal added in Phase 36B-06 (UI-07)
uses `Discipline#parameter_ranges` to decide which values are "plausible"
and triggers a confirmation dialog when a user-entered value is outside
the range. During the 260414-tms debug session the user ran tournament
17411 ("Dreiband klein") with `balls_goal=100` and `innings_goal=20` —
both perfectly normal for that discipline in real-world play — and the
modal flagged BOTH as out-of-range. The range bounds are too tight to
reflect actual tournament practice.

Symptom: every time a realistic tournament is started for Dreiband klein
the user has to click through a "Ungewöhnliche Turnierparameter" warning
for normal values, training users to dismiss the warning and defeating
its purpose.

## Solution

1. Review `Discipline#parameter_ranges` for every discipline currently
   in use (Einband, Dreiband klein, Dreiband groß, Cadre, Freie Partie,
   5-pin, etc.)
2. For each, gather the spread of `balls_goal` and `innings_goal` values
   from historical tournaments in the database (or from tournament
   organizers' reference points) and set the plausibility bounds to
   cover the p5..p95 range, not the p50 ± small delta
3. Add a unit test per discipline that asserts a known-valid historical
   tournament's parameters fall inside the range
4. Verify the modal no longer fires on tournament 17411 with 100/20

Out of scope for this todo: the broader question of whether a modal is
even the right UX — a live "hint" on the form might be better.
