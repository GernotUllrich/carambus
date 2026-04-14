# Requirements: Carambus API — v7.0 Manager Experience

**Defined:** 2026-04-13
**Core Value:** Code and docs stay in sync — every documented feature works, every working feature is documented, and a volunteer user should never need to read the architecture to run a tournament.

## v7.0 Requirements

Requirements for the Manager Experience milestone. Each maps to exactly one phase in ROADMAP.md.

### UX Review (Wizard Audit)

- [ ] **UX-01**: Canonical wizard partial is identified and non-canonical partial is retired or gated. `show.html.erb` renders exactly one wizard partial for all tournament scenarios. No documentation or code change downstream references the retired partial.
- [ ] **UX-02**: Transient AASM state `tournament_started_waiting_for_monitors` behavior is observed and documented (auto-advance vs user-visible) in a `.planning/phases/NN-ux-review/UX-FINDINGS.md` artifact that downstream phases can reference.
- [ ] **UX-03**: Every UX finding is classified by impact tier (Tier 1 = view/help text only, Tier 2 = controller changes, Tier 3 = AASM state machine changes). Tier 3 findings are explicitly gated from the small-fix phase unless approved with test coverage plan.
- [ ] **UX-04**: All TournamentsController happy-path actions (from `new` through `start`) are reviewed and documented with their intent and observed behavior in UX-FINDINGS.md. Non-happy-path actions are listed but not reviewed.

### Task-First Documentation

- [ ] **DOC-01**: `docs/managers/tournament-management.de.md` and `docs/managers/tournament-management.en.md` are rewritten as task-first walkthroughs. First 20 lines describe what the volunteer is doing, not how Carambus is architected. Architecture content (if retained) moves to an appendix or developer docs.
- [ ] **DOC-02**: Both language files have matching skeleton (identical heading structure and section order) before prose is written in either. Bilingual skeleton commit is a gate before content commits.
- [ ] **DOC-03**: A glossary section is added to both language files defining volunteer-relevant terms: ClubCloud, seeding list, tournament mode, AASM status, scoreboard, etc. Technical jargon is explained in plain language.
- [ ] **DOC-04**: A troubleshooting section is added to both language files covering "What to do if X goes wrong" with common recoveries (invitation upload failed, player not in ClubCloud, wrong mode selected, tournament already started).
- [ ] **DOC-05**: `docs/managers/index.de.md` and `docs/managers/index.en.md` "Quick Start: 10 Steps" is corrected to reflect the actual ClubCloud-sourced workflow (managers sync tournaments from ClubCloud, they do NOT create tournaments from scratch).

### Quick Reference Card

- [x] **QREF-01**: `docs/managers/tournament-quick-reference.de.md` and `docs/managers/tournament-quick-reference.en.md` exist as printable A4 single-page cards with Before / During / After checklist structure. `mkdocs.yml` nav entry and `nav_translations` DE label added in the same commit as the files.
- [x] **QREF-02**: Print CSS is added at `docs/stylesheets/print.css` and registered in `mkdocs.yml` `extra_css`. Laminate-ready layout: margins safe for printing, font size readable at arm's length, no dependency on color to convey information.
- [x] **QREF-03**: The quick-reference card includes the scoreboard keyboard shortcut cheat sheet (+1, -1, nnn, DEL, ^v, timer controls) for tournament-day reference.

### Phase 36a — Turnierverwaltung Doc Accuracy

> **Scope evolution:** Phase 36 was originally "Small UX Fixes" (FIX-01..04 only). The Phase 36 sentence-by-sentence doc review produced 58 findings and revealed that the walkthrough is systematically inaccurate. Phase 36a addresses the doc corrections; see `.planning/v7.0-scope-evolution.md`.

- [x] **DOC-ACC-01**: Begriffshierarchie (Setzliste / Meldeliste / Teilnehmerliste) is used consistently across `tournament-management.{de,en}.md` walkthrough and glossary. Setzliste = ordered snapshot (from invitation or Carambus rankings). Meldeliste = CC registration snapshot after deadline. Teilnehmerliste = who actually shows up, finalized on tournament day.
- [x] **DOC-ACC-02**: All factual corrections from review blocks 1–7 (F-36-01..F-36-58) are applied to both language files. Includes Ballziel/Aufnahmebegrenzung disambiguation, Default{n} template fix, logische vs. physikalische Tische, scoreboard-TableMonitor binding, AASM state accuracy, ClubCloud upload paths, honest reset-with-data-loss warning, and removal of fictional UI elements ("Modus ändern"-button, "Ergebnisse nach ClubCloud übertragen"-Schaltfläche, DB-Admin recovery).
- [x] **DOC-ACC-03**: New glossary entries exist for Meldeliste, Teilnehmerliste, Logischer Tisch, Physikalischer Tisch, TableMonitor, Turnier-Monitor, Trainingsmodus, Freilos, T-Plan vs. Default-Plan — in both languages.
- [x] **DOC-ACC-04**: New appendix sections are written covering: no-invitation special flow, missing-player special flow, player nachmeldung flow, ClubCloud CSV upload handling, and manual Rangliste maintenance in ClubCloud (as sourced from SME or further investigation).
- [x] **DOC-ACC-05**: Walkthrough is restructured to honestly distinguish manager-action phases from passive/observation phases. Current linear "Schritt 1..14" framing (which overstates manager activity during game play per F-36-30) is replaced with an accurate model.
- [x] **DOC-ACC-06**: The "Mehr zur Technik" section is removed. "Phase 36 will make the status badge more prominent"-style forward promises are removed or made realistic.

### Phase 36b — UI Cleanup & Kleine Features

> **Note:** FIX-02 is **closed as verified-aligned** per Phase 36 review finding F-36-02 — code and docs already agree on the `auto_upload_to_cc` checkbox location (both say Step 7 / start form). The larger ClubCloud upload model gap is tracked in Phase 36c, not here.

- [ ] **FIX-01**: The active wizard step's help block is expanded by default in `_wizard_steps_v2.html.erb` (or canonical partial). Non-active steps' help blocks remain collapsed. One ERB condition change. *Originally scoped for Phase 36, retained for Phase 36b.*
- [x] **FIX-02**: ~~The `auto_upload_to_cc` checkbox discrepancy is resolved~~. **Closed as verified-aligned (2026-04-14)** — code and docs already agree. See F-36-02 and F-36-23 in `.planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md`.
- [ ] **FIX-03**: Step name display replaces bare step numbers everywhere they mislead (conditional on organizer type). Both the wizard UI and any doc references use step names, not numbers like "Step 6". *Originally scoped for Phase 36, retained for Phase 36b.*
- [ ] **FIX-04**: The AASM state badge is promoted as the primary orientation indicator in the wizard UI, displayed more prominently than the progress bar. Progress bar may remain but is secondary. *Originally scoped for Phase 36, retained for Phase 36b. Note: per F-36-15 meta-finding, may be coupled with broader UI consolidation.*
- [ ] **UI-01**: Parameter form fields in `tournament_monitor.html.erb` have tooltips explaining each parameter's purpose. Reduces need for the "English labels" tip-block in the walkthrough and makes default-value tradeoffs visible inline.
- [ ] **UI-02**: i18n correction for English labels in the start form (e.g., "Tournament manager checks results before acceptance") — missing or broken entries in `config/locales/de.yml` are filled in. Cross-ref F-14 from Phase 33 UX findings.
- [ ] **UI-03**: The manual round-change control feature (parameter "Tournament manager checks results before acceptance") and its UI are removed. Round advance becomes automatic when the last game of a round is confirmed at the scoreboard.
- [ ] **UI-04**: The dead-code manual input UI in the "Aktuelle Spiele" table on the Turnier-Monitor is removed. Only the read-only display of current games remains.
- [ ] **UI-05**: The unused `app/views/tournaments/_wizard_steps.html.erb` partial is deleted (per F-24 from Phase 33 findings; `_wizard_step.html.erb` stays because it's still used by `_wizard_steps_v2.html.erb` for steps 3–5).
- [ ] **UI-06**: The "Zurücksetzen des Turnier-Monitors" action shows a data-loss confirmation dialog when invoked at `tournament_started` state or later. Below that state, no dialog is needed (no data to lose).
- [ ] **UI-07**: Before `start_tournament!` is triggered, a parameter verification dialog surfaces any parameter values that deviate unusually from discipline defaults (e.g., Ballziel < 50 or > 200 for Freie Partie) and asks the user to confirm. Reduces the likelihood of irreversible misconfigurations.

### Phase 36c — v7.1 Preparation / ClubCloud Integration Groundwork

> **Scope:** Phase 36c is a planning phase — it produces v7.1+ milestone skeletons and backlog seeds, not implementation. The large code feature gaps uncovered during the Phase 36 doc review are too big for v7.0 closure but must be scoped before the team moves on.

- [ ] **PREP-01**: A v7.1-ClubCloud-Integration milestone skeleton exists at `.planning/milestones/v7.1-clubcloud-integration-*.md` covering: (a) Endrangliste automatic calculation (currently manual in CC), (b) Teilnehmerliste finalization via CC API (currently to-be-implemented), (c) credentials delegation for Club-Sportwart rights to close the "player add in CC requires absent person" problem. Each subsection has rough scope and dependency notes.
- [ ] **PREP-02**: A Shootout / Stechen support skeleton exists (either as part of v7.1 or a dedicated milestone like v7.2). Covers AASM changes, TournamentPlan model changes, and scoreboard UI. Shootout is currently completely unsupported but required for KO tournaments.
- [ ] **PREP-03**: Backlog/seed entries exist at `.planning/seeds/` for Match-Abbruch / Freilos handling (medium) and for UI consolidation of historically grown screens (large) — items that are real but don't need immediate scheduling.
- [ ] **PREP-04**: A ClubCloud admin-side handling appendix is written and provided to Phase 36a as content for DOC-ACC-04. Covers: where the CC admin interface is, which CC role is needed, typical validation errors, and the two-path upload model (per-game vs. CSV batch). Source: SME interview or further investigation.

### In-App Doc Links

- [x] **LINK-01**: The `mkdocs_link` locale bug in `app/helpers/application_helper.rb:149` is fixed. The helper generates `/docs/en/#{path}` for EN locale and `/docs/de/#{path}` (or root `/docs/`) for DE locale, matching the `docs_page_link` pattern at `app/views/static/docs_page.html.erb:18-22`.
- [x] **LINK-02**: Each wizard step in `_wizard_steps_v2.html.erb` (or canonical partial) accepts a `docs_path:` local and, when present, renders a `mkdocs_link` to the corresponding section of `tournament-management.{locale}.md`. All 6 happy-path wizard steps have working links.
- [x] **LINK-03**: TournamentsController form help text (invitation upload, participant editing, mode selection, table assignment, start settings) includes doc links via `mkdocs_link`. Help text points volunteers at doc sections for context, not just inline hints.
- [x] **LINK-04**: At least 3 wizard-step links from LINK-02 use anchor fragments to deep-link into specific sections of the rewritten doc (e.g., `#seeding-list`, `#mode-selection`), not just page top. Requires stable anchors from DOC-01/DOC-02 to be frozen first.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full TournamentsController redesign | Targeted fixes only; redesign is v7.1+ if UX review surfaces need |
| Edge-case wizard branches (reset, manual overrides, partial retries) | Happy path first; defer to v7.1 unless blocking |
| Interactive onboarding tour / modal help | Research flagged as anti-feature for 2-3x/year users |
| Undo-on-finalize | Research flagged as anti-feature; managers need finality, not reversibility |
| New test coverage for untested models/controllers/services | Separate milestone |
| Real-user UAT recording/observation sessions | Milestone starts from informed analysis; UAT deferred to post-release validation |
| Architecture or stack changes | Project-level constraint |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| UX-01 | Phase 33 | Pending |
| UX-02 | Phase 33 | Pending |
| UX-03 | Phase 33 | Pending |
| UX-04 | Phase 33 | Pending |
| DOC-01 | Phase 34 | Pending |
| DOC-02 | Phase 34 | Pending |
| DOC-03 | Phase 34 | Pending |
| DOC-04 | Phase 34 | Pending |
| DOC-05 | Phase 34 | Pending |
| QREF-01 | Phase 35 | Complete |
| QREF-02 | Phase 35 | Complete |
| QREF-03 | Phase 35 | Complete |
| DOC-ACC-01 | Phase 36a | Complete |
| DOC-ACC-02 | Phase 36a | Complete |
| DOC-ACC-03 | Phase 36a | Complete |
| DOC-ACC-04 | Phase 36a | Complete |
| DOC-ACC-05 | Phase 36a | Complete |
| DOC-ACC-06 | Phase 36a | Complete |
| FIX-01 | Phase 36b | Pending |
| FIX-02 | Phase 36b | Closed (verified-aligned 2026-04-14) |
| FIX-03 | Phase 36b | Pending |
| FIX-04 | Phase 36b | Pending |
| UI-01 | Phase 36b | Pending |
| UI-02 | Phase 36b | Pending |
| UI-03 | Phase 36b | Pending |
| UI-04 | Phase 36b | Pending |
| UI-05 | Phase 36b | Pending |
| UI-06 | Phase 36b | Pending |
| UI-07 | Phase 36b | Pending |
| PREP-01 | Phase 36c | Pending |
| PREP-02 | Phase 36c | Pending |
| PREP-03 | Phase 36c | Pending |
| PREP-04 | Phase 36c | Pending |
| LINK-01 | Phase 37 | Complete |
| LINK-02 | Phase 37 | Complete |
| LINK-03 | Phase 37 | Complete |
| LINK-04 | Phase 37 | Complete |

**Coverage (after Phase 36 split, 2026-04-14):**
- v7.0 requirements: **37 total** (was 20; +17 from scope evolution: +6 DOC-ACC, +7 UI, +4 PREP)
- Mapped to phases: 37 (complete)
- Closed as no-op: 1 (FIX-02, verified code/doc already aligned)
- Unmapped: 0 ✓

**Scope evolution:** See `.planning/v7.0-scope-evolution.md` for the full rationale behind the 17 new requirements and the FIX-02 closure. Phase 36 was split into 36a/36b/36c after a sentence-by-sentence review of `tournament-management.de.md` produced 58 findings (F-36-01..F-36-58).

---

*Requirements defined: 2026-04-13*
*Last updated: 2026-04-13 after roadmap creation — all 20 requirements mapped to phases 33-37*
