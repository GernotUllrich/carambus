# Seed: Match-Abbruch / Freilos Handling

**Planted:** 2026-04-14 (Phase 36c, v7.0)
**Source finding:** `.planning/v7.0-scope-evolution.md` F-36-49
**Target milestone:** Backlog — revisit after v7.1 ships, or earlier if SHO-09 pulls it forward.

## Problem

Carambus has no structured way to handle a player withdrawing mid-game
or a game that starts with a Freilos (walkover). Today the manager
resolves these situations off-system — paper notes, verbal agreements,
manual edits in ClubCloud after the fact — which defeats the point of
Carambus as the live tournament workflow UI.

Concrete scenarios that today have no Carambus-supported path:

1. **Mid-game withdrawal** — a player injures themselves or leaves
   during a game. The opponent advances. What does the scoreboard
   show? What does the Endrangliste record? What does the tournament
   plan distribution logic do with the abandoned game's data?
2. **Freilos at game start** — a scheduled opponent never arrives.
   The present player advances without a game being played. Same
   questions, with the added wrinkle that no game data exists.
3. **Disqualification** — the referee or Turnierleiter disqualifies
   a player mid-game. Identical shape to #1 but with a different
   upstream trigger.
4. **Bye in an odd-bracket KO** — a structural Freilos built into the
   tournament plan because the bracket has an odd number of
   participants. Current handling **[TBD: verify]** — the tournament
   plan PORO may already handle this cleanly, but it is not documented.

## Why it's a seed, not a todo

The work is medium-sized (the roadmap estimates it as "medium" in the
v7.0 scope-evolution table) but it touches several cross-cutting parts
of Carambus: AASM, tournament plan, scoreboard UI, Endrangliste, CC
upload. It's not a single-PR fix. It needs its own requirements and
phasing.

It is also **entangled with v7.2 Shootout work**. SHO-09 (Shootout
abort semantics) and this seed overlap at the intersection "what if a
Shootout can't complete?" Whoever picks up v7.2 first should re-read
this seed and decide whether to resolve both together.

## Conditions that should surface this seed

- When v7.1 (CC Integration) is mid-execution and the team starts
  asking "how do I upload an Endrangliste where one player withdrew?"
- When v7.2 Phase E (SHO-09 abort semantics) is being planned.
- When a real tournament hits a mid-game withdrawal and the user
  files a bug report against the current behavior.
- When 2026-Q3 planning starts (rough calendar trigger, since the
  feature is listed as "medium priority" in v7.0 scope evolution).

## Rough scope (when promoted to a milestone phase)

| Area | Work |
|------|------|
| Model | Game model gains `abandoned`, `walkover`, `disqualified` AASM transitions + PaperTrail versioning |
| Service | `Tournament::RankingCalculator` handles non-played games without special-casing every call site |
| UI | TableMonitor gains a "mark as abandoned" action with shared-modal confirmation (reuses 36B-05 infrastructure) |
| Scoreboard | Clear visual state for walkover / abandonment (distinct from warmup or pause) |
| CC integration | Endrangliste upload (v7.1 CCI-03) knows how to represent non-played game results |
| Docs | Walkthrough appendix for "player withdrew / didn't show up" scenarios |

## Related documents

- `.planning/v7.0-scope-evolution.md` F3 (this seed's source in the
  v7.0 review)
- `.planning/milestones/v7.2-REQUIREMENTS.md` SHO-09 (entangled
  Shootout abort question)
- `docs/managers/tournament-management.de.md` — Phase 36a added an
  appendix for special cases; Match-Abbruch is currently omitted
  from that appendix (DOC-ACC-04 coverage gap to re-audit here).
- Phase 36a doc-review finding F-36-49.

## Size estimate

**Medium.** ~1 phase, ~4–6 plans. Bigger if entangled with v7.2 SHO-09
(then it probably becomes a cross-cutting refactor instead of an
additive phase).
