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
- [ ] **Phase 34: Task-First Doc Rewrite** - Rewrite `docs/managers/tournament-management.{de,en}.md` as a volunteer task walkthrough with glossary, troubleshooting, and corrected index Quick Start
- [ ] **Phase 35: Printable Quick-Reference Card** - Create bilingual Before/During/After printable A4 card with print CSS registered in mkdocs
- [x] **Phase 36: Small UX Fixes** - Implement Tier 1 and Tier 2 UX fixes surfaced by Phase 33: open-by-default help, auto_upload_to_cc alignment, step name display, AASM badge prominence (completed 2026-04-13)
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
- [ ] 34-01-bilingual-skeleton-PLAN.md — Lay down the bilingual H2/H3/anchor skeleton (D-05 gate) in all four target files in carambus_master; commit before any prose
- [ ] 34-02-de-prose-PLAN.md — DE walkthrough (14 steps + 4 mandatory admonition callouts), glossary (15+ terms grouped), troubleshooting (4 cases Problem/Ursache/Lösung), index.de.md Quick Start teaser
- [ ] 34-03-en-prose-PLAN.md — EN walkthrough (14 steps + 4 callouts), glossary (5 mandated + Karambol), troubleshooting (Problem/Cause/Fix), index.en.md Quick Start teaser (parallel with 34-02)
- [ ] 34-04-screenshots-and-validate-PLAN.md — Copy 3 reused Phase 33 screenshots, embed at steps 2/6/10, run mkdocs build --strict, grep-verify all 5 success criteria
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
**Plans**: TBD

### Phase 36: Small UX Fixes
**Goal**: The four highest-value Tier 1 and Tier 2 UX friction points surfaced in Phase 33 are resolved: the active step's help is visible without a click, the auto_upload_to_cc doc/code alignment is corrected, step names replace bare numbers, and the AASM state badge is the primary orientation indicator
**Phase type**: mixed
**Depends on**: Phase 33 (UX findings drive fix scope; Phase 34 recommended first so doc corrections can be aligned with code fixes)
**Requirements**: FIX-01, FIX-02, FIX-03, FIX-04
**Success Criteria** (what must be TRUE):
  1. The active wizard step's help block renders open by default; non-active steps remain collapsed
  2. The `auto_upload_to_cc` checkbox location in the UI matches what the documentation describes — either the code and doc now agree, or a clear decision is recorded about which was changed
  3. Wizard steps are identified by name (not bare numbers like "Step 6") everywhere they appear in the UI, conditional on organizer type
  4. The AASM state badge is visually more prominent than the progress bar in the wizard UI; a volunteer returning to an in-progress tournament can immediately see the current state name
**Plans**: TBD
**UI hint**: yes

### Phase 37: In-App Doc Links
**Goal**: Every wizard step has a working link to the corresponding section of the rewritten documentation, and the mkdocs_link helper generates correct locale-aware URLs for both DE and EN users
**Phase type**: mixed
**Depends on**: Phase 34 (LINK-02..04 require stable doc anchors), Phase 35 (LINK-01 fix enables all links to work correctly)
**Requirements**: LINK-01, LINK-02, LINK-03, LINK-04
**Success Criteria** (what must be TRUE):
  1. `app/helpers/application_helper.rb` mkdocs_link helper generates `/docs/en/#{path}/` for EN locale and `/docs/#{path}/` for DE locale, matching the pattern in `docs_page.html.erb`
  2. All 6 happy-path wizard steps in the canonical partial render a working doc link when the user clicks it; the link opens the pre-built mkdocs site in a new tab
  3. Form help text in TournamentsController (invitation upload, participant editing, mode selection, table assignment, start settings) includes doc links pointing volunteers to the relevant doc sections
  4. At least 3 wizard-step links use anchor fragments to deep-link into specific sections of the rewritten doc (e.g., `#seeding-list`, `#mode-selection`), not just the page top
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:** 33 → 34 → 35 → 36 → 37

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 33. UX Review & Wizard Audit | v7.0 | 3/3 | Complete    | 2026-04-13 |
| 34. Task-First Doc Rewrite | v7.0 | 0/4 | Not started | - |
| 35. Printable Quick-Reference Card | v7.0 | 0/TBD | Not started | - |
| 36. Small UX Fixes | v7.0 | 0/TBD | Not started | - |
| 37. In-App Doc Links | v7.0 | 0/TBD | Not started | - |
