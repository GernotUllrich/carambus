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

- [ ] **QREF-01**: `docs/managers/tournament-quick-reference.de.md` and `docs/managers/tournament-quick-reference.en.md` exist as printable A4 single-page cards with Before / During / After checklist structure. `mkdocs.yml` nav entry and `nav_translations` DE label added in the same commit as the files.
- [ ] **QREF-02**: Print CSS is added at `docs/stylesheets/print.css` and registered in `mkdocs.yml` `extra_css`. Laminate-ready layout: margins safe for printing, font size readable at arm's length, no dependency on color to convey information.
- [ ] **QREF-03**: The quick-reference card includes the scoreboard keyboard shortcut cheat sheet (+1, -1, nnn, DEL, ^v, timer controls) for tournament-day reference.

### Small UX Fixes

- [ ] **FIX-01**: The active wizard step's help block is expanded by default in `_wizard_steps_v2.html.erb` (or canonical partial). Non-active steps' help blocks remain collapsed. One ERB condition change.
- [ ] **FIX-02**: The `auto_upload_to_cc` checkbox discrepancy is resolved. Either (a) code moves the checkbox to a visible wizard step that matches the doc, or (b) doc is corrected to reflect that the checkbox lives in the start form. Decision made and either the code or the doc matches reality.
- [ ] **FIX-03**: Step name display replaces bare step numbers everywhere they mislead (conditional on organizer type). Both the wizard UI and any doc references use step names, not numbers like "Step 6".
- [ ] **FIX-04**: The AASM state badge is promoted as the primary orientation indicator in the wizard UI, displayed more prominently than the progress bar. Progress bar may remain but is secondary.

### In-App Doc Links

- [ ] **LINK-01**: The `mkdocs_link` locale bug in `app/helpers/application_helper.rb:149` is fixed. The helper generates `/docs/en/#{path}` for EN locale and `/docs/de/#{path}` (or root `/docs/`) for DE locale, matching the `docs_page_link` pattern at `app/views/static/docs_page.html.erb:18-22`.
- [ ] **LINK-02**: Each wizard step in `_wizard_steps_v2.html.erb` (or canonical partial) accepts a `docs_path:` local and, when present, renders a `mkdocs_link` to the corresponding section of `tournament-management.{locale}.md`. All 6 happy-path wizard steps have working links.
- [ ] **LINK-03**: TournamentsController form help text (invitation upload, participant editing, mode selection, table assignment, start settings) includes doc links via `mkdocs_link`. Help text points volunteers at doc sections for context, not just inline hints.
- [ ] **LINK-04**: At least 3 wizard-step links from LINK-02 use anchor fragments to deep-link into specific sections of the rewritten doc (e.g., `#seeding-list`, `#mode-selection`), not just page top. Requires stable anchors from DOC-01/DOC-02 to be frozen first.

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
| UX-01 | TBD | Pending |
| UX-02 | TBD | Pending |
| UX-03 | TBD | Pending |
| UX-04 | TBD | Pending |
| DOC-01 | TBD | Pending |
| DOC-02 | TBD | Pending |
| DOC-03 | TBD | Pending |
| DOC-04 | TBD | Pending |
| DOC-05 | TBD | Pending |
| QREF-01 | TBD | Pending |
| QREF-02 | TBD | Pending |
| QREF-03 | TBD | Pending |
| FIX-01 | TBD | Pending |
| FIX-02 | TBD | Pending |
| FIX-03 | TBD | Pending |
| FIX-04 | TBD | Pending |
| LINK-01 | TBD | Pending |
| LINK-02 | TBD | Pending |
| LINK-03 | TBD | Pending |
| LINK-04 | TBD | Pending |

**Coverage:**
- v7.0 requirements: 20 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 20 ⚠️

---

*Requirements defined: 2026-04-13*
*Last updated: 2026-04-13 after initial definition*
