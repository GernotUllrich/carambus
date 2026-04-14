# Phase 36b: UI Cleanup & Kleine Features - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 36B-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-14
**Phase:** 36b-ui-cleanup-kleine-features
**Areas discussed:** Wizard header (FIX-03 + FIX-04), Parameter form (UI-01 + UI-02), UI-03 admin_controlled removal, Safety features (UI-06 + UI-07), Test strategy

---

## Prior Context Loaded

**From `.planning/phases/33-ux-review-wizard-audit/33-CONTEXT.md`:**
- D-09: Phase 33 decided to defer non-canonical wizard partial deletion to Phase 36 (now 36b UI-05)
- D-11/D-12: Tier classification rules — Tier 3 AASM changes are gated behind explicit test plans (36b does NOT touch AASM state machine)
- UX-FINDINGS: F-14 (English labels), F-24 (unused `_wizard_steps.html.erb`), F-19 (transient state feedback)

**From `.planning/phases/36A-turnierverwaltung-doc-accuracy/`:**
- Phase 36a completed 2026-04-14 with 7/7 plans, 6/6 DOC-ACC requirements verified
- F-36-55 (parameter verification dialog) explicitly mapped to 36b UI-07 per 36A-COVERAGE.md
- F-36-28 (dead-code manual input UI removal) → 36b UI-04
- F-36-29 (manual round-change feature removal) → 36b UI-03
- F-36-32 (Reset safety warning) → 36b UI-06
- F-36-15 meta-finding (Doc-Schritte ≠ UI-Screens) informs FIX-03 step naming decision

**From `.planning/ROADMAP.md` and `.planning/REQUIREMENTS.md`:**
- FIX-02 is closed as verified-aligned (code and docs already agree on auto_upload_to_cc)
- Dependency: Phase 36b depends on Phase 33 and Phase 36a (both complete)

---

## Codebase Scout Findings

- `app/views/tournaments/_wizard_steps_v2.html.erb` (386 lines) — canonical wizard partial; current header shows "Schritt N von 6" + "Status: X" + progress bar; per-step rows show `<span class="step-number">1.</span>` prefix + `<h4>` title
- `app/views/tournaments/tournament_monitor.html.erb` (131 lines) — start form with 13+ parameter fields; labels mostly hardcoded English ("Timeout (Sek.)", "Tournament Manager checks results before acceptance", "GD has prio on inter-group-comparisons", "WarmUp New Table (Min.)", "Assign Games as Tables become available"); only `balls_goal`/`innings_goal`/`auto_upload_to_cc` use i18n via `t()`
- `app/helpers/tournament_wizard_helper.rb` (162 lines) — `wizard_current_step` returns 1..8 based on AASM state; `wizard_status_text` maps to 6 buckets; `wizard_progress_percent` divides by 6.0 (implicit 6-bucket model)
- `db/schema.rb:1301-1360` — tournaments table has `admin_controlled boolean default false not null` at line 1334, plus `innings_goal`, `balls_goal`, `handicap_tournier`, `timeout`, `time_out_warm_up_*`, `auto_upload_to_cc`, etc.
- `app/models/tournament.rb` — `admin_controlled` referenced at lines 12 (annotation), 239 (broadcast attr list), 254 (safe_attributes delegation), 321 (second attr list), 382-384 (load-bearing gate: `!admin_controlled?` blocks auto-advance)
- `app/reflexes/tournament_reflex.rb` — handles `admin_controlled` checkbox change via Reflex (1 handler method)
- `test/models/tournament_attributes_test.rb` — existing tests for attribute handling, may reference `admin_controlled`

---

## Gray Areas Presented

Initial 7-option list was reduced to 4 grouped areas due to AskUserQuestion's max-4 options constraint.

| # | Area | User picked? |
|---|------|--------------|
| 1 | Wizard header: step names + AASM badge (FIX-03 + FIX-04) | ✓ |
| 2 | Parameter form: tooltips + label localization (UI-01 + UI-02) | ✓ |
| 3 | UI-03 admin_controlled feature removal depth | ✓ |
| 4 | Safety features: UI-06 reset + UI-07 param verification | ✓ |

All 4 areas selected.

---

## Area 1: Wizard header (FIX-03 + FIX-04)

### Question 1a: Step name source for FIX-03

| Option | Description | Selected |
|--------|-------------|----------|
| Bucket names (6) replace numbers entirely | Drop "Schritt N von 6". Show 6 bucket-name chips with active highlighted. Per-step numbers removed. Aligns with F-36-15 meta-finding. | ✓ |
| Keep numbers + add inline step names | "Schritt N von 6" stays; per-row title prefix gains a name. Mild change. | |
| Organizer-conditional: Region=6, Club=fewer | Two wizard layouts by organizer type. Most explicit "conditional" interpretation. | |

**User's choice:** Bucket names replace numbers entirely.
**Notes:** No user-provided notes. Decision captured as D-01/D-03.

### Question 1b: AASM badge prominence for FIX-04

| Option | Description | Selected |
|--------|-------------|----------|
| Large colored badge row above progress bar | Big colored badge; progress bar shrinks to thin secondary. Most visual weight on badge. | |
| Compact pill inline with title + progress bar removed | Small colored pill next to title; progress bar gone (redundant with step chips from 1a). | |
| You decide — just make it visually dominant | Claude's discretion with explicit goal: volunteer's eye lands on state first. | ✓ |

**User's choice:** You decide.
**Notes:** Decision captured as D-02. Treatment is Claude's discretion during execution.

---

## Area 2: Parameter form (UI-01 + UI-02)

### Question 2a: Tooltip mechanism for UI-01

| Option | Description | Selected |
|--------|-------------|----------|
| Native HTML `title` attr, content from i18n keys | Zero JS, OS-styled tooltips, works everywhere. Simplest. | |
| New Stimulus controller + Tailwind hover card | Branded hover card, more JS work, richer content possible. | ✓ |
| Native `title` attr with inline German strings | Fastest, DE-only, no i18n proliferation. | |

**User's choice:** New Stimulus controller + Tailwind hover card.
**Notes:** Decision captured as D-05. Creates foundation for future richer help content.

### Question 2b: Label localization scope for UI-02

| Option | Description | Selected |
|--------|-------------|----------|
| Full i18n conversion (DE + EN keys) for every label | Most thorough, enables English UI. Largest diff. | ✓ |
| Replace English literals with hardcoded German strings | Quick wins, no i18n plumbing. Less DRY. | |
| Minimal — only English ones become German literals | Smallest diff; "no English visible" goal only. | |

**User's choice:** Full i18n conversion.
**Notes:** Decision captured as D-07/D-08. Defines `tournaments.monitor_form.labels.*` and `tournaments.monitor_form.tooltips.*` as paired namespaces.

---

## Area 3: UI-03 admin_controlled removal

### Question 3: Removal depth

| Option | Description | Selected |
|--------|-------------|----------|
| Full removal: drop column via migration + delete all references | Cleanest; requires SAFETY_ASSURED migration; touches global records. | |
| UI-only + code path simplification, keep column | Remove checkbox, Reflex handler, replace line 382-384 method. Column stays. | |
| UI + gate removal, leave column AND attribute lists | Most conservative; only UI and Reflex removed; gate returns true. | |
| Other (user-provided) | "default to automatic - not admin controlled, remove editable field from parameters form" | ✓ |

**User's choice:** Free-text: "default to automatic - not admin controlled, remove editable field from parameters form".
**Notes:** Interpreted as a middle ground between Options 2 and 3 — remove the editable UI field AND simplify the gate to always-auto. Column stays (no migration). Captured as D-09/D-10/D-11/D-12.

---

## Area 4: Safety features (UI-06 + UI-07)

### Question 4a: UI-06 Reset confirmation states

| Option | Description | Selected |
|--------|-------------|----------|
| Only `tournament_started` and later (recommended) | Warn only when there's data to lose. Native data-confirm. Zero new JS. | |
| From `tournament_mode_defined` onwards (stricter) | Broader safety net; still native data-confirm. | |
| Stimulus-controlled Tailwind modal, always shown | Always required regardless of state; reusable pattern for UI-07. | ✓ |

**User's choice:** Stimulus modal, always shown.
**Notes:** Decision captured as D-15/D-16. Drives the shared modal pattern used by UI-07 as well.

### Question 4b: UI-07 threshold source + dialog mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Threshold map on Discipline model + Stimulus/Tailwind modal | `Discipline#parameter_ranges`. Shared Stimulus modal. Clean separation. | ✓ |
| Hardcoded constant in Tournament model + native data-confirm | `Tournament::PARAMETER_RANGES`. No new JS. Discipline-agnostic. | |
| YAML config under config/tournament_defaults.yml + Stimulus modal | Non-devs can tune. More infrastructure. | |

**User's choice:** Threshold map on Discipline model + Stimulus/Tailwind modal.
**Notes:** Decision captured as D-17/D-18. Reuses the shared modal from UI-06 (D-15).

---

## Area 5: Test strategy

### Question 5a: Test depth

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal: unit tests for model changes only | Test Discipline#parameter_ranges + new gate behavior. No system tests. | |
| Model tests + system tests for the two safety dialogs | UI-06 and UI-07 Capybara system tests; model unit tests. | ✓ |
| Full: unit + system tests for every non-trivial 36b item | Most thorough; largest diff. | |

**User's choice:** Model tests + system tests for the two safety dialogs.
**Notes:** Decision captured as D-19/D-20/D-21. System tests focus on load-bearing safety features; visual items (FIX-03/FIX-04/UI-01/UI-02) go through manual UAT.

### Question 5b: More gray areas or proceed?

| Option | Description | Selected |
|--------|-------------|----------|
| Proceed to context | Write CONTEXT.md from captured decisions. | ✓ |
| More gray areas | Raise additional areas. | |

**User's choice:** Proceed to context.

---

## Claude's Discretion

Items the user explicitly deferred to Claude during planning/execution:
- AASM badge exact visual treatment (Area 1b) — Tailwind colors, badge size, progress bar handling
- Step-chip visual treatment (Area 1a) — underline vs fill vs border (implied from "you decide" spirit)
- Tooltip card styling details (D-05) — drop shadow, rounded corners, pointer arrow
- Modal animation style (D-15) — fade, slide, or none
- Shared Stimulus modal API shape (D-15) — data attributes vs Turbo Stream vs Reflex-triggered
- Discipline parameter range numeric values (D-17) — first-pass defaults, user validates in UAT
- i18n English translations for UI-02 labels (D-07) — mirror German meaning

---

## Deferred Ideas

- Reset-safety for other AASM transitions (uses same shared modal pattern; backlog)
- Richer tooltip content (markdown, doc links) — foundation ready, first pass is plain text
- Database-backed `Discipline#parameter_ranges` — first pass uses hardcoded constants
- `admin_controlled` column drop via migration — kept for global-record backward compat
- System tests for wizard visual regression — manual UAT preferred for first pass
- Full DE/EN doc walkthrough sync — already handled by Phase 36a
- F-36-55 coverage confirmation — same feature as UI-07, no standalone work needed

---

*Discussion completed 2026-04-14*
