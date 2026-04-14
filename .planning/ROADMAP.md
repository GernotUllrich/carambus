# Roadmap: Carambus API — Quality & Manager Experience

## Milestones

- ✅ **v1.0 Model Refactoring** - Phases 1-5 (shipped 2026-04-10)
- ✅ **v2.0 Test Suite Audit** - Phases 6-10 (shipped 2026-04-10)
- ✅ **v2.1 Tournament Refactoring** - Phases 11-16 (shipped 2026-04-11)
- ✅ **v3.0 Broadcast Isolation** - Phases 17-19 (shipped 2026-04-11)
- ✅ **v4.0 League & PartyMonitor Refactoring** - Phases 20-23 (shipped 2026-04-12)
- ✅ **v5.0 UMB Scraper Überarbeitung** - Phases 24-27 (shipped 2026-04-12)
- ✅ **v6.0 Documentation Quality** - Phases 28-32 (shipped 2026-04-13)
- 🚧 **v7.0 Manager Experience** - Phases 33-37 (in progress)

## Phases

<details>
<summary>✅ v1.0–v6.0 (Phases 1-32) - SHIPPED</summary>

Phases 1-32 completed across six milestones. See MILESTONES.md for details.

</details>

### 🚧 v7.0 Manager Experience (In Progress)

**Milestone Goal:** A volunteer club officer who runs 2-3 tournaments per year can manage one end-to-end using Carambus, with task-first documentation and a happy-path UX that doesn't trip them up each time they come back.

- [x] **Phase 33: UX Review & Wizard Audit** - Identify the canonical wizard partial, observe transient state behavior, and classify all happy-path UX findings by impact tier before any doc or code work begins (completed 2026-04-13)
- [x] **Phase 34: Task-First Doc Rewrite** - Rewrite `docs/managers/tournament-management.{de,en}.md` as a volunteer task walkthrough with glossary, troubleshooting, and corrected index Quick Start (completed 2026-04-13)
- [x] **Phase 35: Printable Quick-Reference Card** - Create bilingual Before/During/After printable A4 card with print CSS registered in mkdocs (completed 2026-04-13)
- [x] **Phase 36a: Turnierverwaltung Doc Accuracy** - Apply 58 findings from Phase 36 sentence-by-sentence review: factual corrections, new glossary entries, new appendices, walkthrough restructure (completed 2026-04-14)
- [ ] **Phase 36b: UI Cleanup & Kleine Features** - FIX-01/03/04 + UI cleanup (tooltips, i18n, dead-code removal, reset safety, parameter verification dialog)
- [ ] **Phase 36c: v7.1 Preparation / ClubCloud Integration Groundwork** - Scope v7.1+ milestones for Endrangliste, Shootout, CC API integration, Match-Abbruch
- [ ] **Phase 37: In-App Doc Links** - Fix the mkdocs_link locale bug and wire doc links from each wizard step to the corresponding stable doc anchors from Phase 34

## Phase Details

### Phase 33: UX Review & Wizard Audit
**Goal**: The canonical wizard partial is known, the transient AASM state is observed and documented, and every happy-path action is classified by impact tier — giving downstream phases an authoritative spec to write against
**Phase type**: cleanup
**Depends on**: Nothing (first phase of milestone)
**Requirements**: UX-01, UX-02, UX-03, UX-04
**Success Criteria** (what must be TRUE):
  1. `show.html.erb` renders exactly one wizard partial for all tournament scenarios; the non-canonical partial is retired or gated, and a decision is recorded in UX-FINDINGS.md
  2. `tournament_started_waiting_for_monitors` transient state behavior is observed in a browser and documented: does it surface any visible UI, or does it pass invisibly?
  3. Every happy-path action from `new` through `start` is listed in UX-FINDINGS.md with its intent and observed behavior
  4. Every UX finding is classified Tier 1 (view/copy), Tier 2 (controller change), or Tier 3 (AASM change); Tier 3 items are explicitly gated from Phase 36 unless a test coverage plan is attached
**Plans**: 3 plans
- [x] 33-01-setup-and-grep-evidence-PLAN.md — Create reproduction recipe, grep evidence for canonical partial (UX-01), and scaffold UX-FINDINGS.md skeleton
- [x] 33-02-browser-walkthrough-and-screenshots-PLAN.md — Drive happy-path walkthrough in real browser, capture 6–10 screenshots, observe transient state (UX-02, UX-04)
- [x] 33-03-tier-classification-and-finalize-PLAN.md — Assign stable IDs, tier-classify findings, apply gates, record retirement decision, finalize file (UX-03, UX-04, UX-01)

### Phase 34: Task-First Doc Rewrite
**Goal**: Both language files of `docs/managers/tournament-management.{de,en}.md` open with a task walkthrough the volunteer can follow end-to-end, with glossary and troubleshooting sections, and the index Quick Start reflects the actual ClubCloud-sourced workflow
**Phase type**: cleanup
**Depends on**: Phase 33 (canonical wizard partial must be confirmed before writing)
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04, DOC-05
**Success Criteria** (what must be TRUE):
  1. A volunteer opening either language file sees a task-first walkthrough within the first 20 lines, not a system architecture description
  2. Both DE and EN files share an identical heading skeleton (matching H2/H3 structure and anchor names) committed before any prose is written
  3. A glossary section exists in both language files defining at least: ClubCloud, Setzliste/seeding list, tournament mode, AASM status, scoreboard
  4. A troubleshooting section exists in both language files covering the four common failure cases (invitation upload failed, player not in ClubCloud, wrong mode selected, tournament already started)
  5. The `docs/managers/index.{de,en}.md` Quick Start corrects the workflow to "sync from ClubCloud" and does not describe creating a tournament from scratch
**Plans**: 4 plans
- [x] 34-01-bilingual-skeleton-PLAN.md — Lay down the bilingual H2/H3/anchor skeleton (D-05 gate) in all four target files in carambus_master; commit before any prose
- [x] 34-02-de-prose-PLAN.md — DE walkthrough (14 steps + 4 mandatory admonition callouts), glossary (15+ terms grouped), troubleshooting (4 cases Problem/Ursache/Lösung), index.de.md Quick Start teaser
- [x] 34-03-en-prose-PLAN.md — EN walkthrough (14 steps + 4 callouts), glossary (5 mandated + Karambol), troubleshooting (Problem/Cause/Fix), index.en.md Quick Start teaser (parallel with 34-02)
- [x] 34-04-screenshots-and-validate-PLAN.md — Copy 3 reused Phase 33 screenshots, embed at steps 2/6/10, run mkdocs build --strict, grep-verify all 5 success criteria
**UI hint**: yes

### Phase 35: Printable Quick-Reference Card
**Goal**: A volunteer can open and print a one-page Before/During/After checklist card for tournament day, and the card is reachable from the mkdocs nav in both languages
**Phase type**: cleanup
**Depends on**: Phase 34 (card content derives from rewritten happy-path walkthrough; anchors must be stable)
**Requirements**: QREF-01, QREF-02, QREF-03
**Success Criteria** (what must be TRUE):
  1. `docs/managers/tournament-quick-reference.de.md` and `docs/managers/tournament-quick-reference.en.md` exist, are reachable from the mkdocs nav, and display Before / During / After sections with checkbox items
  2. Printing either page from a browser hides all mkdocs navigation chrome and produces a clean A4-sized layout with legible font size
  3. The reference card includes the scoreboard keyboard shortcut cheat sheet (+1, -1, nnn, DEL, ^v, timer controls) in a format readable at arm's length
  4. `mkdocs build --strict` passes with zero warnings after adding both files and their nav entries
**Plans**: 5 plans
- [x] 35-01-PLAN.md — Record mkdocs strict baseline, create docs/stylesheets/print.css with @media print chrome-stripping + A4 layout, wire into mkdocs.yml extra_css (QREF-02)
- [x] 35-02-PLAN.md — Create bilingual tournament-quick-reference.{de,en}.md skeleton with #before/#during/#after/#scoreboard-shortcuts anchors AND mkdocs.yml nav entry + DE nav_translation label in a single atomic commit (QREF-01; D-07a + D-08a gates)
- [x] 35-03-PLAN.md — Fill DE + EN Before/During/After checklists with F-09/F-12/F-14/F-19 warning callouts and Phase 34 walkthrough deep-links (QREF-01)
- [x] 35-04-PLAN.md — Fill DE + EN scoreboard-shortcuts section with shortcut table and verbatim ASCII keycap strip copied from scoreboard-guide.{de,en}.md (QREF-03)
- [x] 35-05-PLAN.md — Final mkdocs --strict gate, automated success-criteria verification, cross-reference integrity checks, human smoke test of print preview (QREF-01/02/03)

### Phase 36a: Turnierverwaltung Doc Accuracy
**Goal**: All 58 findings from the Phase 36 sentence-by-sentence review of `docs/managers/tournament-management.de.md` are addressed — factual errors corrected, missing glossary entries added, new troubleshooting recipes created, special-case appendices written, and the walkthrough restructured to honestly reflect manager activity vs. passive phases
**Phase type**: docs-only
**Depends on**: Phase 34 (this phase corrects and extends Phase 34's output)
**Requirements**: DOC-ACC-01, DOC-ACC-02, DOC-ACC-03, DOC-ACC-04, DOC-ACC-05, DOC-ACC-06
**Input artifact**: `.planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md` (58 findings, F-36-01..58)
**Scope evolution reference**: `.planning/v7.0-scope-evolution.md`
**Success Criteria** (what must be TRUE):
  1. Begriffshierarchie (Setzliste / Meldeliste / Teilnehmerliste) is used consistently across walkthrough + glossary
  2. All factual corrections from review blocks 1–7 are applied to both `tournament-management.de.md` and `tournament-management.en.md`
  3. New glossary entries exist for: Meldeliste, Teilnehmerliste, Logischer Tisch, Physikalischer Tisch, TableMonitor, Turnier-Monitor, Trainingsmodus, Freilos, T-Plan vs. Default-Plan
  4. New appendix sections cover: no-invitation flow, missing-player flow, player registration flow, ClubCloud CSV upload handling, manual Rangliste maintenance
  5. Walkthrough is restructured to honestly distinguish manager-action phases from passive/observation phases
  6. "Mehr zur Technik" section is removed
  7. `mkdocs build --strict` passes with zero new warnings over the Phase 35 baseline
**Plans**: 7 plans
- [x] 36A-01-PLAN.md — Block 1+2 corrections (F-36-01..F-36-11): Szenario, Schritte 1-5 — Begriffshierarchie + Schritt-4-as-action-link
- [x] 36A-02-PLAN.md — Block 3 corrections (F-36-12..F-36-23): Schritte 6-8 merged — Ballziel/Aufnahmebegrenzung, logisch/physikalisch, auto_upload_to_cc
- [x] 36A-03-PLAN.md — Block 4+5 corrections (F-36-24..F-36-38): Schritte 9-14 — passive-phase restructure, Endrangliste/Shootout disclosure
- [x] 36A-04-PLAN.md — Glossar rewrite (F-36-39..F-36-50): 7 entries fixed + 6 new entries (Meldeliste, Teilnehmerliste, Logischer/Physikalischer Tisch, TableMonitor, Turnier-Monitor, Trainingsmodus, Freilos)
- [x] 36A-05-PLAN.md — Troubleshooting rewrite (F-36-51..F-36-58): 4 recipes rewritten + 6 new recipes; "Mehr zur Technik" removed
- [x] 36A-06-PLAN.md — New Anhang/Appendix section: 6 sub-sections (no-invitation, missing-player, nachmeldung, cc-upload, cc-csv-upload, rangliste-manual)
- [x] 36A-07-PLAN.md — Final verification: mkdocs --strict + coverage matrix + anchor integrity check

### Phase 36b: UI Cleanup & Kleine Features
**Goal**: UI cleanup items from the Phase 36 doc review are implemented, plus the remaining original FIX-01/03/04 items, plus two small safety/verification features that reduce the risk of irreversible mistakes during tournament setup
**Phase type**: mixed
**Depends on**: Phase 33 (UX findings drive scope), Phase 36a (doc accuracy should land first so UI changes can be documented correctly)
**Requirements**: FIX-01, FIX-03, FIX-04, UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07
**Scope evolution reference**: `.planning/v7.0-scope-evolution.md`
**Success Criteria** (what must be TRUE):
  1. FIX-01: The active wizard step's help block renders open by default; non-active steps remain collapsed
  2. FIX-03: Wizard steps are identified by name (not bare numbers like "Step 6") everywhere they appear in the UI, conditional on organizer type
  3. FIX-04: The AASM state badge is visually more prominent than the progress bar in the wizard UI (possibly coupled with UI-01 tooltip work)
  4. UI-01: Parameter form fields have tooltips explaining their purpose
  5. UI-02: Start-form labels are in German (no English/broken-German labels)
  6. UI-03: Manual round-change control feature and its parameter are removed
  7. UI-04: Dead-code manual input UI in the Turnier-Monitor "Aktuelle Spiele" table is removed
  8. UI-05: The unused `app/views/tournaments/_wizard_steps.html.erb` partial is deleted (per F-24 from Phase 33)
  9. UI-06: Reset confirms with a data-loss warning when invoked at `tournament_started` state or later
  10. UI-07: Parameter verification dialog shows unusual values before `start_tournament!` is triggered
**Note**: FIX-02 (auto_upload_to_cc checkbox location) is **closed as verified-aligned** — code and docs already agree per Phase 36 review finding F-36-02/F-36-23. The broader ClubCloud upload model gap is tracked separately in Phase 36c.
**Plans**: 6 plans
- [ ] 36B-01-wizard-header-rewrite-PLAN.md — Wizard header rewrite: six bucket chips + dominant AASM state badge + FIX-01 active help expansion (FIX-01, FIX-03, FIX-04)
- [ ] 36B-02-parameter-form-i18n-and-tooltips-PLAN.md — Full i18n conversion of tournament_monitor parameter labels + new Stimulus tooltip controller (UI-01, UI-02)
- [ ] 36B-03-admin-controlled-removal-PLAN.md — Remove admin_controlled checkbox, reflex handler, and simplify player_controlled? gate to always-true (UI-03)
- [ ] 36B-04-dead-code-cleanup-PLAN.md — Remove dead-code manual input UI from _current_games.html.erb + git rm _wizard_steps.html.erb after re-verification (UI-04, UI-05)
- [ ] 36B-05-confirmation-modal-and-reset-safety-PLAN.md — Shared Stimulus confirmation modal infrastructure + UI-06 reset-confirmation rewire on 3 reset buttons + Capybara system test (UI-06)
- [ ] 36B-06-parameter-verification-PLAN.md — Discipline#parameter_ranges + server-side pre-start range check + modal trigger + Minitest unit tests + Capybara system test (UI-07)
**UI hint**: yes

### Phase 36c: v7.1 Preparation / ClubCloud Integration Groundwork
**Goal**: The large code features uncovered by the Phase 36 doc review are scoped into v7.1+ milestone skeletons and backlog seeds, so v7.0 can close cleanly without carrying unresolved feature debt
**Phase type**: planning
**Depends on**: Phase 36a, Phase 36b (so the planning is informed by what's already been fixed)
**Requirements**: PREP-01, PREP-02, PREP-03, PREP-04
**Scope evolution reference**: `.planning/v7.0-scope-evolution.md`
**Success Criteria** (what must be TRUE):
  1. PREP-01: A v7.1-ClubCloud-Integration milestone skeleton exists covering Endrangliste automatic calculation, Teilnehmerliste finalization via CC API, and credentials delegation for Club-Sportwart rights
  2. PREP-02: A Shootout/Stechen support skeleton exists (either as part of v7.1 or its own milestone v7.2) covering AASM changes, tournament plan modifications, and scoreboard UI
  3. PREP-03: Backlog/seed entries exist for Match-Abbruch / Freilos handling and for UI consolidation of historically grown screens
  4. PREP-04: A ClubCloud admin-side handling appendix is written (as referenced by Phase 36a DOC-ACC-04) based on SME interview or further investigation
**Plans**: 7 plans
**UI hint**: no (planning phase)

### Phase 37: In-App Doc Links
**Goal**: Every wizard step has a working link to the corresponding section of the rewritten documentation, and the mkdocs_link helper generates correct locale-aware URLs for both DE and EN users
**Phase type**: mixed
**Depends on**: Phase 34 (LINK-02..04 require stable doc anchors), Phase 36a (walkthrough restructure may shift anchor positions — 37 must happen after 36a), Phase 35 (LINK-01 fix enables all links to work correctly)
**Requirements**: LINK-01, LINK-02, LINK-03, LINK-04
**Success Criteria** (what must be TRUE):
  1. `app/helpers/application_helper.rb` mkdocs_link helper generates `/docs/en/#{path}/` for EN locale and `/docs/#{path}/` for DE locale, matching the pattern in `docs_page.html.erb`
  2. All 6 happy-path wizard steps in the canonical partial render a working doc link when the user clicks it; the link opens the pre-built mkdocs site in a new tab
  3. Form help text in TournamentsController (invitation upload, participant editing, mode selection, table assignment, start settings) includes doc links pointing volunteers to the relevant doc sections
  4. At least 3 wizard-step links use anchor fragments to deep-link into specific sections of the rewritten doc (e.g., `#seeding-list`, `#mode-selection`), not just the page top
**Plans**: 6 plans
- [ ] 36B-01-wizard-header-rewrite-PLAN.md — Wizard header rewrite: six bucket chips + dominant AASM state badge + FIX-01 active help expansion (FIX-01, FIX-03, FIX-04)
- [ ] 36B-02-parameter-form-i18n-and-tooltips-PLAN.md — Full i18n conversion of tournament_monitor parameter labels + new Stimulus tooltip controller (UI-01, UI-02)
- [ ] 36B-03-admin-controlled-removal-PLAN.md — Remove admin_controlled checkbox, reflex handler, and simplify player_controlled? gate to always-true (UI-03)
- [ ] 36B-04-dead-code-cleanup-PLAN.md — Remove dead-code manual input UI from _current_games.html.erb + git rm _wizard_steps.html.erb after re-verification (UI-04, UI-05)
- [ ] 36B-05-confirmation-modal-and-reset-safety-PLAN.md — Shared Stimulus confirmation modal infrastructure + UI-06 reset-confirmation rewire on 3 reset buttons + Capybara system test (UI-06)
- [ ] 36B-06-parameter-verification-PLAN.md — Discipline#parameter_ranges + server-side pre-start range check + modal trigger + Minitest unit tests + Capybara system test (UI-07)
**UI hint**: yes

## Progress

**Execution Order:** 33 → 34 → 35 → 36a → 36b → 36c → 37

**Scope Evolution Note:** Phase 36 was originally "Small UX Fixes" with FIX-01..04. A sentence-by-sentence review of the Turnierverwaltung walkthrough during discuss-phase produced 58 findings and exposed the original scope as significantly underestimated. Phase 36 was split into 36a (doc accuracy), 36b (UI cleanup + remaining small fixes), and 36c (v7.1 preparation for large code features). See `.planning/v7.0-scope-evolution.md` for the full rationale.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 33. UX Review & Wizard Audit | v7.0 | 3/3 | Complete    | 2026-04-13 |
| 34. Task-First Doc Rewrite | v7.0 | 4/4 | Complete    | 2026-04-13 |
| 35. Printable Quick-Reference Card | v7.0 | 5/5 | Complete    | 2026-04-13 |
| 36a. Turnierverwaltung Doc Accuracy | v7.0 | 7/7 | Complete    | 2026-04-14 |
| 36b. UI Cleanup & Kleine Features | v7.0 | 0/6 | Not started | - |
| 36c. v7.1 Preparation / CC Groundwork | v7.0 | 0/TBD | Not started | - |
| 37. In-App Doc Links | v7.0 | 0/TBD | Not started | - |
