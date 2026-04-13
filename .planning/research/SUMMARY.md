# Project Research Summary

**Project:** Carambus API — v7.0 Manager Experience
**Domain:** Brownfield Rails app — volunteer-facing docs rewrite + wizard UX polish
**Researched:** 2026-04-13
**Confidence:** HIGH

## Executive Summary

v7.0 is a content and wiring milestone, not a build milestone. All infrastructure required to deliver the milestone already exists in the codebase: the `_wizard_steps_v2.html.erb` partial with progress bars, help blocks, and terminology box; the in-app doc renderer `docs_page.html.erb`; the `mkdocs_link` and `docs_page_link` helpers; the bilingual mkdocs site with `--strict` passing. The work is task-first content writing, one `mkdocs_link` locale bug fix, a few ERB wiring changes, and a targeted UX review. No new gems, no new routes, no new architecture.

The single biggest risk to the milestone is starting in the wrong order. Architecture research proposed docs-first then UX review. Pitfalls research proves this is wrong: two wizard partials coexist (`_wizard_steps.html.erb` and `_wizard_steps_v2.html.erb`), and writing docs against the wrong partial wastes all content work. The UX review must run first, its first deliverable being confirmation of the canonical partial and retirement (or explicit documentation) of v1. Nothing else opens until that question is closed. Pitfalls research wins this conflict — the correct build order is UX review first, then docs, then wiring.

The secondary risk is scope creep enabled by the newly loosened constraint ("feature additions now allowed"). The wizard's AASM has 9 states, 30 controller actions, and 85 characterization tests. Any fix that touches the AASM state machine is a Tier 3 change and requires a full test coverage plan before being accepted. The UX review output must classify each finding by impact tier — Tier 1 (view/copy only), Tier 2 (controller change), Tier 3 (AASM change) — and Tier 3 items must be explicitly gated. Cosmetic fixes have a known tendency to crowd out task-friction findings; the review scenarios must be written before any view file is opened.

## Key Findings

### Recommended Stack

No new dependencies are required. The existing stack delivers everything v7.0 needs. The two additions are cost-free: a `print.css` file (~30 lines of `@media print` CSS added to `docs/stylesheets/`) and a one-line bug fix in `app/helpers/application_helper.rb:149` where `mkdocs_link` always generates `/docs/#{path}` regardless of locale. The fix adds locale-aware URL construction matching the pattern already used correctly in `docs_page.html.erb`. The `pymdownx.tasklist` extension is already enabled in `mkdocs.yml`, making `- [ ]` checkbox syntax available for the printable reference card without any pip additions.

**Core technologies:**
- `mkdocs-material` 9.6.15: docs site theme — already installed; print CSS via custom `@media print` is the correct approach for a single reference card page; no plugin needed
- `mkdocs-static-i18n` 1.3.0: bilingual suffix structure (`file.de.md` / `file.en.md`) — already working; adding a new page requires nav entry + nav_translations entry + both locale files as a single atomic commit
- `mkdocs_link` helper (fixed): in-app to mkdocs deep links — exists at `app/helpers/application_helper.rb:143`; fix line 149 before wiring wizard links
- `_wizard_step.html.erb` `help:` parameter: already renders `help.html_safe` inside `<details>` — no new partial needed to add doc links; pass links in the `help:` string

**Do not add:** `mkdocs-print-site-plugin` (merges entire site, adds `/print_page/` nav entry, wrong tool for a single page); intro.js / Shepherd.js (2-3x/year users forget tours between visits); ViewComponent gem; Turbo Frames on wizard steps; JS tooltip libraries.

### Expected Features

The volunteer persona filter (club officer, 2-3 tournaments/year, German-speaking, often under time pressure on tournament day) drives every prioritization decision. The primary failure mode is the user arriving at a doc and seeing an architecture overview rather than a task walkthrough.

**Must have (table stakes):**
- Task-first doc rewrite of `tournament-management.{de,en}.md` — current file opens with architecture/system overview, failing the volunteer persona at first contact
- Printable quick-reference card (Before/During/After, one A4 side, DE + EN) — on tournament day no one reads docs on a laptop; this is the actual runtime UX for a low-frequency user
- In-app doc links from each wizard step — `docs_page.html.erb` renderer exists but zero links point from wizard views to it; wiring is LOW complexity and HIGH volunteer value
- Open-by-default `<details>` for the active step — all help blocks are currently collapsed; adding `open` conditionally on `status == :active` eliminates one click at the moment of highest confusion

**Should have (after validation):**
- Anchor-targeted doc links — link from step 2 directly to the "Step 2" heading, not the top of the page; requires `docs_page.html.erb` anchor-fragment support
- State badge as primary orientation cue — demote progress bar percentage, elevate `wizard_status_text`; one CSS/layout change

**Defer to v8+:**
- "What changed since last time" section in manager docs — maintenance burden only worthwhile if the wizard is actively evolving
- Simplified referee UI — explicitly called out in current docs as a future project; out of v7.0 scope

**Anti-features to reject:** guided JS tours (go stale between 2-3x/year uses), modal help dialogs (block UI under tournament-day time pressure), over-explanation on the reference card (must fit one A4 side), searchable in-app docs (low-frequency users recognize context not keywords), progress percentage as the primary metric (actionless for a user waiting at step 4).

### Architecture Approach

The wizard lives entirely on `show.html.erb`. Each step renders as a card via `_wizard_step.html.erb`. The active step's button triggers a separate controller action which redirects back to `show`. AASM state is the authoritative source of wizard progress — `TournamentWizardHelper` maps AASM states to step numbers and computes `:active`/`:completed`/`:pending` per step. Doc infrastructure (both the in-app Markdown renderer and the pre-built MkDocs site) are already fully operational.

**Major components:**
1. `_wizard_steps_v2.html.erb` + `_wizard_step.html.erb` — the canonical wizard UI; v1 partial must be retired or gated before any content work begins
2. `TournamentWizardHelper` — AASM state to step status mapping; correct as-is for v7.0
3. `mkdocs_link` helper (post-fix) — the right tool for wizard-to-docs links; opens pre-built MkDocs site in a new tab with full navigation, search, and language switcher intact
4. `docs_page_link` helper — appropriate for inline doc rendering within the Rails layout only; do NOT use for wizard contextual help links
5. MkDocs bilingual site (`docs/managers/`) — three-part atomic change required for any new page: nav entry + nav_translations entry + both locale files; `mkdocs build --strict` must pass before committing

**Key pattern for in-app links:** add an optional `docs_path` local variable to `_wizard_step.html.erb`; when present, render a `mkdocs_link` below the help text. Pass `docs_path:` from each step call in `_wizard_steps_v2.html.erb`. Zero new helpers, zero new routes, zero new partials.

**Build order conflict resolution — Pitfalls wins over Architecture:** Architecture research proposed docs-first (Step 1), then UX review (Step 3). Pitfalls research proves UX review is a pre-condition for docs: writing docs against the wrong wizard partial wastes all content work. Correct order: UX review first (confirm canonical partial, retire v1) then docs rewrite, then quick-reference card, then fix mismatches, then in-app links last (only after doc anchors are stable).

### Critical Pitfalls

1. **Two wizard partials, wrong one documented** — Before writing a single doc line, confirm which partial `show.html.erb` renders and under what condition. The v2 partial has a different step 2 ("Setzliste aus Einladung") than v1. Writing docs against the wrong partial invalidates all content work. Resolution: UX review is the first phase; its first output is a decision on v1 retirement.

2. **AASM phantom states fabricated as wizard steps** — `accreditation_finished` has no inbound event from any controller action; `closed` has no AASM event at all. A doc author reading the 9-state list as a sequential workflow will invent steps for these states or describe them as part of the happy path when they are not. Rule: every documented step must map to a named controller action; phantom states must be explicitly annotated as non-wizard.

3. **`auto_upload_to_cc` checkbox documented in wrong location** — Current EN doc says the checkbox is in "Step 6 of the wizard panel." Wizard step 6 in `_wizard_steps_v2.html.erb` contains no form — only a link button to `tournament_monitor_tournament_path`. The checkbox is consumed by `TournamentsController#start` via params and lives in the tournament-start form, not the wizard overview. Verify every documented UI element's location with `grep` before writing.

4. **In-app links added before doc anchors are stable** — Adding wizard-to-docs links in the same phase as the doc rewrite means links point to sections that move during the rewrite. `mkdocs build --strict` does not validate ERB URL references. In-app links must be sequenced as the final phase, after the doc rewrite is committed and anchor names are tagged as stable.

5. **Bilingual drift during large rewrite** — DE and EN docs are separate files. Writing EN-first then translating DE produces structural divergence: mismatched H2/H3 anchors break cross-locale links. The skeleton (all H2/H3 headers with matching anchor names in both languages) must be committed before any prose is written. v6.0 closed 17 bilingual gaps; this rewrite will open new ones unless the skeleton-first gate is enforced.

6. **Step numbers conditional on organizer type** — Both wizard partials render different step counts depending on `tournament.organizer.is_a?(Region)`. A club officer sees 5 steps; a regional officer sees 6. Any doc referring to "Step 6" without an organizer-type qualifier will be wrong for half the user base. Rule: describe steps by name, not number.

7. **Improvement cascade from loosened constraints** — Classify each UX finding by impact tier before accepting it. Tier 1 (view/copy change) is free. Tier 2 (controller change) requires targeted testing. Tier 3 (AASM change or new state) requires a full test coverage plan. Cap Tier 3 items at 1-2 per milestone. "Add a confirmation screen between steps 4 and 5" is a new AASM state and is Tier 3.

## Implications for Roadmap

Based on research, the dependency graph forces a specific phase order. The key constraint: in-app doc links must be last because they depend on stable doc anchors, and doc anchors can only be stable after the doc rewrite closes. The UX review must be first because it determines what docs describe.

### Phase 1: UX Review and Wizard Audit

**Rationale:** The wizard partial ambiguity (v1 vs v2) is the milestone's first risk. This phase closes it before any content work opens. Writing docs against an uncertain target is the highest-probability way to waste the entire milestone. The review also surfaces the `auto_upload_to_cc` location error, phantom AASM state issues, and transient state behavior that will corrupt the doc rewrite if not resolved first.
**Delivers:** Confirmed canonical wizard partial (v1 retired or explicitly gated); impact-tier classification of every UX finding; documented behavior of the transient `tournament_started_waiting_for_monitors` state; "documented but missing" features classified as never-implemented / was-removed / intent-unknown; cosmetic findings on a separate list not competing with task-friction findings.
**Addresses:** All features — UX review is a prerequisite for every other deliverable
**Avoids:** Pitfall 1 (two partials), Pitfall 3 (transient state), Pitfall 9 (documented but missing), Pitfall 10 (cosmetic over task), Pitfall 11 (improvement cascade)
**Research flag:** Standard patterns — no `/gsd-research-phase` needed; work is code inspection and scenario walkthroughs.

### Phase 2: Doc Rewrite (Task-First Walkthrough)

**Rationale:** With the canonical wizard confirmed, the doc rewrite has an authoritative spec. The rewrite establishes the anchor names that Phase 5 (in-app links) will target — anchors cannot be stable until this phase closes. Quick-reference card content derives from this rewrite; writing them in parallel risks inconsistency.
**Delivers:** Rewritten `docs/managers/tournament-management.{de,en}.md` — task-first opening, architecture moved to appendix or developer docs, bilingual skeleton committed before prose, all step references by name not number, all documented UI elements verified by grep, phantom AASM states annotated as non-wizard.
**Uses:** Bilingual skeleton-first commit gate (prevents drift); `mkdocs build --strict` validation before closing phase
**Implements:** Architecture decision Q1 — replace in place, no nav changes needed
**Avoids:** Pitfall 2 (phantom AASM states), Pitfall 4 (`auto_upload_to_cc`), Pitfall 5 (step numbers), Pitfall 6 (terminology leak), Pitfall 7 (bilingual drift)
**Research flag:** Standard patterns — work is content writing with grep-verified fact-checking.

### Phase 3: Printable Quick-Reference Card

**Rationale:** Can run immediately after Phase 2. Card content is derived from the rewritten doc's happy-path section. A separate page is required because a printable one-pager needs either a dedicated page scoped to a print stylesheet, or an admonition block — the decision turns on whether "printable" means literal paper or on-screen reference. This phase also delivers `print.css` and registers it in `mkdocs.yml`.
**Delivers:** `docs/managers/quick-reference.{de,en}.md` (Before/During/After, max 5 items per column, fits one A4 side); `docs/stylesheets/print.css` (~30 lines); nav entry + nav_translations entry in `mkdocs.yml`; both locale files created atomically with nav changes.
**Uses:** `pymdownx.tasklist` (already enabled) for `- [ ]` checkbox syntax; `attr_list` (already enabled) for `{ .print-break }` page-break CSS hooks; `print.css` registered under `extra_css` in `mkdocs.yml`
**Implements:** Architecture decision Q2 — separate page with dedicated print CSS
**Avoids:** Anti-feature: over-explanation (strict item count cap enforced); Pitfall 7 (bilingual drift — skeleton-first gate applies)
**Research flag:** Standard patterns — no `/gsd-research-phase` needed.

### Phase 4: Small UX Fixes (Tier 1 and Tier 2 Only)

**Rationale:** UX review findings classified as Tier 1 (view/copy) and Tier 2 (controller change) are implemented here. Any Tier 3 finding (AASM change) requires an explicit test coverage plan and is capped at 1-2 per milestone; findings above that cap are deferred to v7.x. The most valuable, lowest-risk fix is open-by-default `<details>` for the active step: one ERB condition in `_wizard_step.html.erb`.
**Delivers:** Open-by-default help for active step (one ERB condition); label/copy fixes from UX review (Tier 1); controller-only fixes for documented-but-working features (Tier 2); Tier 3 items either scoped with test plans or explicitly deferred.
**Uses:** Existing `_wizard_step.html.erb` `status` parameter; no new helpers, no new routes
**Implements:** Feature — open-by-default help (P1 from FEATURES.md)
**Avoids:** Pitfall 11 (improvement cascade) — tier classification gates entry
**Research flag:** Standard patterns for Tier 1-2 work. Any accepted Tier 3 item needs a targeted pass on test coverage implications before scoping.

### Phase 5: Fix `mkdocs_link` Locale Bug + In-App Doc Links

**Rationale:** This phase is last because it depends on stable doc anchors from Phase 2. The `mkdocs_link` locale bug must be fixed before any in-app links are wired — links to English docs will generate wrong URLs without the fix. In-app links are added to `_wizard_steps_v2.html.erb` by passing `docs_path:` to each step render call.
**Delivers:** Fixed `mkdocs_link` at `app/helpers/application_helper.rb:149` (one-line change: `url = locale == 'en' ? "/docs/en/#{path}/" : "/docs/#{path}/"`); `docs_path:` optional local variable in `_wizard_step.html.erb`; `docs_path:` passed from each of the 6 steps in `_wizard_steps_v2.html.erb` pointing to stable anchors; manual click-test confirming every link resolves to the correct doc section.
**Uses:** Fixed `mkdocs_link` helper; anchor names established and frozen in Phase 2
**Implements:** Feature — in-app doc links (P1 from FEATURES.md); Architecture decisions Q3 and Q6
**Avoids:** Pitfall 8 (in-app links to moving targets); Anti-pattern 1 (hardcoded absolute URLs); Anti-pattern 4 (`docs_page_link` instead of `mkdocs_link` for wizard help)
**Research flag:** Standard patterns — no `/gsd-research-phase` needed.

### Phase Ordering Rationale

- Phase 1 before everything: two wizard partials is the only ambiguity that can invalidate all other work. Must be closed first.
- Phase 2 before Phase 5: doc anchor stability is a hard dependency of in-app link correctness.
- Phase 3 after Phase 2: quick-reference card content is derived from the rewritten doc; writing them in parallel risks inconsistency. Running sequentially is safer for bilingual structural alignment.
- Phase 4 after Phase 2: UX fixes may require coordinated doc corrections; sequencing after the doc rewrite ensures both outputs can be aligned in one pass.
- Phase 5 last: non-negotiable. In-app links to moving anchor targets is a silent failure mode that `mkdocs build --strict` will not catch.

### Research Flags

Phases with standard patterns (skip `/gsd-research-phase`):
- **Phase 1 (UX Review):** Code inspection and scenario walkthroughs against known codebase. No novel technology.
- **Phase 2 (Doc Rewrite):** Content writing with grep-verified facts. Bilingual doc pattern established in v6.0.
- **Phase 3 (Quick Reference Card):** Pure content and CSS. Print CSS pattern fully documented in STACK.md with selectors.
- **Phase 4 (Small UX Fixes):** Tier 1-2 changes against fully understood codebase. No external API or novel pattern. Any accepted Tier 3 item should be treated as needing brief targeted research before scoping.
- **Phase 5 (In-App Links):** One-line helper fix and ERB wiring against existing helper API. Pattern fully documented in ARCHITECTURE.md and STACK.md.

No phases require a full `/gsd-research-phase` invocation. All patterns are verified against the actual codebase.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All findings from direct file inspection: `requirements.txt`, `mkdocs.yml`, `app/helpers/application_helper.rb`, both wizard partials. One MEDIUM item: mkdocs-material 9.x print CSS selector names verified from training knowledge (Aug 2025), not against live 9.6.15 docs. Use DevTools if any selector fails. |
| Features | HIGH | All Carambus-status assessments from direct code inspection. Analogous-product patterns (Challonge, club software) are MEDIUM — training knowledge, no external search available. Used only to validate anti-feature decisions. |
| Architecture | HIGH | All findings from direct source file reading. Route structure, helper APIs, wizard data flow, AASM state machine all verified against actual files. |
| Pitfalls | HIGH | All pitfalls derived from direct inspection of `tournament.rb` AASM block, both wizard partials, `tournaments_controller.rb`, existing EN docs. Specificity (line numbers, exact grep commands) confirms direct code reading throughout. |

**Overall confidence:** HIGH

### Gaps to Address

- **`mkdocs_link` print CSS selector accuracy:** The CSS selectors targeting `.md-header`, `.md-sidebar`, `.md-footer`, `.md-tabs` are based on training knowledge of mkdocs-material 9.x DOM structure. Browser DevTools verification is required when `print.css` is first applied. Risk is LOW — class names are stable across 9.x — but it is the one item that cannot be verified without running the site.

- **Transient state UI behavior:** Whether `tournament_started_waiting_for_monitors` surfaces any visible UI (loading flash, waiting screen, or passes invisibly) can only be confirmed by observing the actual start flow in a browser. Must be investigated in Phase 1 UX review, not assumed.

- **Wizard v1 render condition:** `show.html.erb` may render `_wizard_steps.html.erb` under specific conditions not surfaced during research. The exact condition must be confirmed by reading `show.html.erb` in Phase 1 before any doc work begins.

- **`docs_page.html.erb` anchor-fragment behavior:** Anchor-fragment targeting exists in the URL pattern but anchor scroll behavior in the in-app Markdown renderer was not verified. Deferred to v7.x (anchor-targeted doc links are P2, not P1).

## Sources

### Primary (HIGH confidence)

- `app/helpers/application_helper.rb:135-151` — both doc link helpers confirmed; locale bug on line 149 confirmed
- `app/views/tournaments/_wizard_steps_v2.html.erb` — canonical wizard partial; 6 steps, hardcoded German strings, glossary box, self-hiding after tournament_started
- `app/views/tournaments/_wizard_step.html.erb` — step card partial API; `help:` renders `.html_safe` inside `<details>`
- `app/helpers/tournament_wizard_helper.rb` — AASM state to step status mapping
- `app/controllers/tournaments_controller.rb` lines 288-350 — wizard actions; `start` reads `auto_upload_to_cc`; transitions to `tournament_started_waiting_for_monitors`
- `app/models/tournament.rb` AASM block lines 271-311 — 9 states; `accreditation_finished` has no inbound event; `closed` has no event
- `app/views/static/docs_page.html.erb` — in-app Markdown renderer fully functional; correct locale URL pattern lines 18-22
- `app/controllers/docs_controller.rb` + `app/controllers/static_controller.rb` — both doc serving paths confirmed
- `config/routes.rb` lines 328, 342 — `docs_page/:locale/*path` and `docs/*path` routes confirmed
- `mkdocs.yml` — nav structure, i18n plugin config, suffix convention, ~60 nav_translations entries, `toc.permalink: true`, `pymdownx.tasklist` and `attr_list` enabled
- `docs/managers/tournament-management.en.md` — current content: architecture-heavy first 60%; `auto_upload_to_cc` incorrectly located
- `.planning/PROJECT.md` — v7.0 milestone scope, volunteer persona constraint, constraint evolution, out-of-scope decisions

### Secondary (MEDIUM confidence)

- Analogous product patterns (Challonge, club management software onboarding UX) — training knowledge; no live web access during research; used only to validate anti-feature decisions
- mkdocs-material 9.x DOM CSS class names for print CSS — training knowledge (Aug 2025 cutoff); selectors `.md-header`, `.md-sidebar`, `.md-footer`, `.md-tabs` are stable across 9.x series but not re-verified against 9.6.15 live docs

---
*Research completed: 2026-04-13*
*Ready for roadmap: yes*
