# Phase 34: Task-First Doc Rewrite - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `34-CONTEXT.md` — this log preserves the discussion.

**Date:** 2026-04-13
**Phase:** 34-task-first-doc-rewrite
**Mode:** discuss
**Depends on:** Phase 33 complete (wizard partial confirmed, 24 UX findings classified)

## Prior decisions carried forward

From **Phase 33 (UX Review & Wizard Audit)** completion:
- Canonical wizard partial is `_wizard_steps_v2.html.erb` (UX-01, via grep evidence)
- Happy path for the volunteer workflow is a synced carom tournament (`id < 50_000_000`, carom discipline, upcoming), not a locally-invented tournament — the scenario in Phase 33 used NDM Freie Partie Klasse 1-3
- Transient state `tournament_started_waiting_for_monitors` passes invisibly for several seconds (F-19, Tier 3, `blocked-needs-test-plan`) — this is THE load-bearing fact for UX-02
- 24 findings classified: 14 Tier 1 (view/copy/i18n), 8 Tier 2 (controller/service), 1 Tier 3 (F-19 AASM)
- Severe i18n regression on start form (F-14, Tier 1) — most parameter labels are English or mangled
- Non-canonical partials `_wizard_steps.html.erb` + `_wizard_step.html.erb` are retirement candidates (F-24, deferred to Phase 36)

From **PROJECT.md**:
- v7.0 volunteer persona filter: "would a volunteer club officer who uses this 2-3x/year understand this?"
- Core Value: "Code and docs stay in sync — every documented feature works, every working feature is documented, and a volunteer user should never need to read the architecture to run a tournament"
- Behavior preservation is SCOPED for v7.0 — feature phases allowed to add behavior, cleanup phases enforce preservation. Phase 34 is `cleanup` (docs only, no code).

From **REQUIREMENTS.md**:
- DOC-01 (task-first rewrite), DOC-02 (bilingual skeleton gate), DOC-03 (glossary minimum), DOC-04 (troubleshooting 4 cases), DOC-05 (index Quick Start correction)
- Out of Scope: Full TournamentsController redesign, edge-case branches, interactive onboarding tour (explicitly flagged as anti-feature), undo-on-finalize

## Gray areas presented

1. Umgang mit aktueller Architektur-Sektion (delete / move / appendix / brief overview)
2. Umgang mit Phase-33 UX-Bugs im Doku-Text (as-is / callouts / write around / aspirational)
3. Glossar-Umfang (minimum / +Karambol / +start-form only)
4. Walkthrough-Struktur (6 H2 coarse / 10–14 fine; scenario vs abstract)

User selected: all four.

## Decisions made

### D-01: Architektur-Inhalt
- **Options presented:** Move to docs/developers/ (recommended), delete entirely, brief 2-paragraph overview at end, in-file appendix
- **User chose:** Brief 2-paragraph overview at the END of the file with link to docs/developers/
- **Rationale:** Safety net for curious volunteers without disrupting the task-first opening. First 20 lines stay task-focused per DOC-01.

### D-02: UX-bug handling in prose
- **Options presented:** As-is + inline callouts (recommended), as-is silent, write around problems, aspirational post-fix
- **User chose:** As-is + inline callouts
- **Rationale:** Honest documentation of current state with volunteer-facing help where the wizard trips people up. Callouts reference finding IDs (`<!-- ref: F-19 -->`) so Phase 36 can remove them atomically when fixing the underlying bugs.

### D-03: Glossar-Umfang
- **Options presented:** Extended + Karambol terms (recommended), minimum only, minimum + start-form terms only
- **User chose:** Extended + Karambol terms
- **Rationale:** Volunteers who run tournaments 2–3x per year need both the system terminology (ClubCloud, AASM status) AND the carom-specific terms (Freie Partie, Cadre, Dreiband, Aufnahme, HS, GD) that appear in the start form and in the tournament plans. Glossary is a reference, not a tutorial — broader is better.

### D-04: Walkthrough structure
- **Options presented:** 10–14 fine wizard steps + scenario (recommended), 7 coarse + abstract, 7 coarse + scenario, 10–14 fine + abstract
- **User chose:** 10–14 fine wizard steps with scenario framing
- **Rationale:** The volunteer sits in front of the wizard and wants "click this, then this, then this" not "generally speaking, you configure a tournament." Fine granularity matches the actual UI. Scenario framing makes the prose concrete without being tied to a specific tournament ID.

### D-04a follow-up: Scenario specificity
- **Options presented:** Generic NBV/NDM Freie Partie (recommended), concrete tournament 17403, generic + example box
- **User chose:** Generic NBV/NDM Freie Partie
- **Rationale:** Ages well across seasons. The concrete ID (17403) stays in Phase 33's audit artifacts, not in user-facing docs.

## Not discussed (Claude's Discretion)

- Troubleshooting section format (Problem/Cause/Fix subsections chosen as default)
- Bilingual translation workflow (DeepL first-pass polish chosen as default)
- Exact prose tone — formal "Sie" (DE convention for volunteer/admin audience)
- Glossary ordering — grouped by category (Karambol vs Wizard vs System) for easy scanning
- Whether screenshots are included — reuse 2–3 from Phase 33 as default

## Scope creep redirected

None — the discussion stayed within DOC-01..DOC-05 scope. The deferred ideas captured in CONTEXT.md came from anticipating downstream dependencies (Phase 35 QREF, Phase 36 fixes, Phase 37 links), not from in-session scope drift.
