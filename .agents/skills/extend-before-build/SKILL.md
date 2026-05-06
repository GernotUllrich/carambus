---
name: extend-before-build
description: When adding a feature/addon to an existing codebase, prefer extending existing structures (legacy paths, existing predicates, established lifecycles) with small guards over building parallel state machines or routing layers. Refactoring for quality improvement can come later as a separate effort. Use whenever introducing BK-* / discipline-specific behavior, scoring rules, multiset variants, or any feature that overlaps with what the legacy karambol path already does.
---

# Extend Before Build

> **Addons sollten wo immer möglich existierende Strukturen nutzen, wenn diese noch sinnvoll sind. Refactoring zur Qualitätsverbesserung kann dann immer noch erfolgen.**

## The Principle

When implementing a new feature that overlaps with existing functionality:

1. **First** — identify the existing structure that's closest to the new requirement (legacy path, existing predicate, established lifecycle).
2. **Second** — figure out the smallest delta needed: a guard, an override, a discipline-specific branch.
3. **Only if no existing structure fits** — build a new one.

Refactoring the legacy structure for clarity/quality is a separate, deferrable concern. Don't conflate "I'm adding a feature" with "I'm cleaning up the legacy path."

## Why

Parallel structures drift out of sync. Two systems doing similar work always grow inconsistencies — different state-models, different gate conditions, different timing assumptions. The integration surface between them becomes a source of bugs.

A small guard on the existing path is:
- Easier to reason about (one execution flow, not two)
- Easier to test (existing tests stay valid; only delta needs new tests)
- Cheaper to revert (small diff)
- More honest about coupling (you can SEE the BK-specific override, instead of it being scattered across services)

## Checklist before building a new structure

- [ ] Does the legacy path already do 80%+ of what I need?
- [ ] Can the new behavior be expressed as `if discipline_X then else legacy`?
- [ ] Does the existing predicate (e.g. `follow_up?`, `end_of_set?`) have a natural place to inject a guard?
- [ ] Will the new structure SHARE state with the legacy path, or REPLICATE it?
  - SHARE → maybe it's a guard. Continue.
  - REPLICATE → likely over-engineering. Reconsider.
- [ ] Am I adding a new state-machine alongside an existing one? **Stop and reconsider.**

## When this principle does NOT apply

- The legacy path is fundamentally wrong for the new feature (semantics differ entirely, not just edge cases).
- The legacy code is being deprecated and the new feature is the replacement.
- A clean-room implementation is required for compliance / security / formal-verification reasons.
- User explicitly requests a rewrite.

## Cautionary Tale: bk2-phase-and-nachstoss debug session (2026-04-27 to 2026-04-29)

**What happened:** BK-2kombi tournament discipline needed three new behaviors layered onto karambol: phase-switching DZ↔SP per set, BK-2plus negative-value-to-opponent rule, special Nachstoß handling. Earlier work (Phase 38.x) had built a parallel state machine `Bk2::AdvanceMatchState` + `Bk2::CommitInning` + `bk2_state` JSON blob alongside the legacy karambol multiset.

**The 8-round symptom-chase:**
1. Routing fix to make BK2 path actually fire (Round 6b)
2. UI templates BK-aware (Round 7)
3. AASM modal hooked into BK2 (Round 8)
4. ... each round broke another integration point because the two state machines diverged

**The user's intervention** ("Wird immer schlimmer; gehen wir doch einige Schritte zurück und behandeln alles wie legacy Karambol. Es gibt einige guards wo in den Abläufen eingegriffen werden muss") forced a full rollback to the pre-Round-1 state and a 4-guard implementation:
- `bk2_kombi_current_phase` (helper, ~10 LOC)
- `follow_up?` BK-override (15 LOC)
- `end_of_set?` BK-override (15 LOC)
- `score_engine#bk_credit_negative_to_opponent?` (5 LOC)

**Result:** -1463 LOC vs. the experiment, all tests passing, end-to-end verified. The previous BK2 services were deleted (`Bk2::CommitInning`) or trimmed by 70%.

**The lesson:** The legacy karambol multiset DID handle multiset semantics correctly. It had `data["sets"]`, `data[player][result]`, `perform_save_current_set`, `perform_switch_to_next_set`, AASM `end_of_set!` / `set_over` / `next_set!` lifecycle, protocol modal — everything needed. BK-Familie didn't need a parallel state machine; it needed three ~15-LOC guards.

The 8-round experiment was preserved at git tag `bk2-rounds1-8-experiment` for reference.

## Application heuristic for Carambus specifically

- New scoring rule for a discipline → consider `score_engine` predicate or branch first.
- New set-close timing → consider `end_of_set?` override first.
- New display-time UI label → consider `follow_up?` (or similar predicate) override + view's existing template branches first.
- New per-set state needed → check if `data["sets"]` array + per-set legacy fields can hold it before adding a new JSON blob.
