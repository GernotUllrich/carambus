# Seed: UI Consolidation of Historically Grown Tournament Screens

**Planted:** 2026-04-14 (Phase 36c, v7.0)
**Source finding:** `.planning/v7.0-scope-evolution.md` F-36-15
**Target milestone:** Backlog — **large**, possibly interleaved across multiple future milestones rather than a single dedicated phase.

## Problem

The tournament management UI has accreted organically over several
years. The v7.0 Phase 36 doc review surfaced the issue as Meta-finding
1: **"Wizard-Schritt ≠ AASM-State ≠ UI-Screen"**. The walkthrough's
numbered Schritte don't map linearly to either AASM states or UI
screens, because:

| Doc Schritte | Actual UI | Actual AASM |
|--------------|-----------|-------------|
| 1 (invitation) | no UI | — |
| 2–5 (Meldeliste / Setzliste / Teilnehmerliste) | `TournamentsController#index` wizard partial | one state with action-links |
| 6 (Turniermodus) | separate mode-selection screen | state transition |
| 7–8 (start params + tables) | **same** `tournament_monitor` param form | one screen |
| 9+ (start / warmup / games) | `TableMonitor#show` + downstream views | multiple states |

Quoting the SME from the Phase 36 review:
> *"Alle diese Seiten sind historisch gewachsen und haben leider kein
> einheitliches UI-Konzept."*

Symptoms for the end user:
1. The same screen serves multiple "logical" steps (steps 7–8 share
   one form), so the wizard numbering lies.
2. Different screens use inconsistent visual idioms for the same
   concept (button styles, confirmation flows, flash placement, dark
   mode behavior).
3. The AASM state badge (Phase 36b FIX-04) was flagged as "should
   happen alongside UI consolidation, not in isolation" — meaning the
   right answer to FIX-04 can't be found without resolving the larger
   structure question first.
4. Phase 36b-01 already did a "wizard header rewrite" (six bucket
   chips + dominant AASM state badge) which is a surface-level
   remedy. The underlying screen decomposition was left alone.

## Why it's a seed, not a phase

The work is **large** — easily a full milestone's worth of design +
implementation — and it touches almost every tournament-management
view in the codebase. It also requires design decisions that nobody
has made yet: what IS the unified UI concept? Before that question
has a committed answer, any code work is premature.

It is also **entangled with v7.1** (CC integration work touches the
Teilnehmerliste screen) and **v7.2** (Shootout work touches the
TableMonitor and Turnier-Monitor views). Doing UI consolidation
before those milestones would mean designing for features that don't
exist yet; doing it after might mean throwing away work. A
"interleaved across milestones" approach is probably more realistic:
each future milestone absorbs a small consolidation slice when it
touches a relevant screen.

## Conditions that should surface this seed

- When a future milestone's discuss-phase produces a decision that
  would be cleaner to implement if the UI was consolidated first
  (e.g., "we need to change the Turnier-Monitor to display X" — is
  X consistent with the rest of the tournament screens?)
- When 3+ future v7.x phases individually flag the same screen as
  "would benefit from rework" — that's the trigger to promote this
  seed to a milestone of its own.
- When an external event forces the hand (new tablet hardware, new
  accessibility requirement, new design language).

## Rough scope (when it eventually becomes a milestone)

| Area | Work |
|------|------|
| Design | UI/UX review across every tournament-management screen; produce a single visual idiom document |
| Models | Possibly consolidate "parameter form" + "tournament monitor" + "mode selection" into a unified controller action set |
| Views | Massive ERB refactor, probably one phase per screen group (wizard, TableMonitor, Turnier-Monitor, show) |
| Stimulus | Consolidate redundant controllers (e.g., multiple tooltip variants from Phase 36b) |
| i18n | Re-audit every string after consolidation; historical duplicates are common |
| Testing | Capybara system tests for every consolidated flow |
| Docs | Full walkthrough rewrite (Phase 36a's walkthrough is honest about current state but would need a second rewrite after consolidation) |

## What NOT to do

- **Do NOT** start nibbling at UI consolidation on an ad-hoc "while
  I'm here" basis. That's how the historically-grown state was
  created in the first place. Every change should be part of a
  deliberate slice with a committed design target.
- **Do NOT** promote this seed to a milestone until the design
  question (what IS the unified UI?) has a written answer.
- **Do NOT** block v7.1 or v7.2 on this seed. They ship first; this
  waits for a natural window.

## Related documents

- `.planning/v7.0-scope-evolution.md` F8 and Meta-finding 1.
- Phase 36a walkthrough (`docs/managers/tournament-management.de.md`)
  — the ground truth on current state that any consolidation must
  honor or explicitly replace.
- Phase 36b FIX-04 (AASM state badge) — deliberately deferred to this
  seed's resolution.
- Phase 36c v7.1-ROADMAP.md / v7.2-ROADMAP.md — milestones whose work
  will touch consolidation-adjacent screens.

## Size estimate

**Large.** Probably 1 full milestone's worth of work (~15–25 plans).
Almost certainly needs its own discuss-phase to even decide what the
unified UI looks like before any phase work can start.
