# Retrospective

Living document tracking what worked, what didn't, and patterns across milestones.

---

## Milestone: v4.0 — League & PartyMonitor Refactoring

**Shipped:** 2026-04-12
**Phases:** 4 | **Plans:** 9

### What Was Built
- 65 characterization tests pinning League (standings, game plan, scraping) and PartyMonitor (8 AASM states, placement, result pipeline)
- League 2221→663 lines via 4 extracted services (StandingsCalculator, GamePlanReconstructor, ClubCloudScraper, BbvScraper)
- PartyMonitor 605→217 lines via 2 extracted services (TablePopulator, ResultProcessor)
- 30 controller integration tests + 10 reflex unit tests covering League/Party/PartyMonitor ecosystem
- 6 code review warnings fixed (SQL parameterization, timezone, error handling, lock semantics)
- Final suite: 901 runs, 0 failures, 0 errors

### What Worked
- Characterization-first extraction pattern proven again (v1.0/v2.1 precedent). Zero behavior regressions caught by Phase 20 tests.
- Thin delegation wrappers — zero caller changes across all extractions. Controllers, reflexes, jobs unmodified.
- Wave-based execution with worktree isolation — both plans in each phase ran cleanly.
- Code review → fix cycle caught real bugs (SQL injection, timezone, silent exception swallowing).
- Discuss → Research → Plan → Execute pipeline was smooth — research caught undeclared method calls (next_seqno, write_game_result_data, add_result_to) that would have caused runtime failures.

### What Was Inefficient
- Phase 20 characterization plans could have been 2 plans instead of 3 — LeagueTeam and Party were small enough to combine.
- Some SUMMARY.md one-liners were empty ("One-liner:") — executor agents didn't always fill the template field.
- Open Questions in RESEARCH.md needed manual `(RESOLVED)` marker fixes after planning — could be automated.

### Patterns Established
- `{Model}::` namespace under `app/services/{model}/` — consistent across League, PartyMonitor, Tournament, TournamentMonitor, TableMonitor
- PORO for pure algorithms, ApplicationService for side-effect-heavy operations
- Pessimistic locks stay in model (or move to service depending on TournamentMonitor precedent), AASM events never fired from services
- Fixture-first testing with `LocalProtectorTestOverride` and `ApiProtectorTestOverride`
- Code review fix cycle as standard post-execution step

### Key Lessons
- Pre-existing bugs should be documented but preserved during extraction — the accumulate_results data mutation was correctly preserved verbatim
- Fixture chains matter — broken party_monitors.yml caused 4 test skips that persisted across multiple milestones until Phase 23 fixed them
- Research phase catches coupling issues that discuss-phase can't — always research before planning extraction phases

### Cost Observations
- Model mix: Opus for planning, Sonnet for research/execution/review/verification
- 4 phases completed in approximately 2 sessions
- Notable: Worktree isolation enabled parallel execution within waves — no merge conflicts

---

## Milestone: v7.0 — Manager Experience

**Shipped:** 2026-04-15
**Phases:** 7 (33, 34, 35, 36a, 36b, 36c, 37) | **Plans:** 31 | **Requirements:** 37/37

### What Was Built

- Task-first rewrite of `docs/managers/tournament-management.{de,en}.md` (volunteer-friendly walkthrough, glossary, troubleshooting, corrected Quick Start)
- Printable A4 Quick-Reference Card with Before/During/After checklist, laminate-ready print CSS, scoreboard shortcut cheat sheet (DE + EN)
- 57 of 58 doc accuracy findings from Phase 36 sentence-by-sentence review applied (Ballziel/Aufnahmebegrenzung, logical vs. physical tables, fictional UI elements removed)
- Wizard header redesign: dominant colored AASM state badge + 6 bucket chips + active-step help auto-open
- 16 parameter field tooltips via new Stimulus `tooltip_controller.js`, full i18n of start-form labels
- Dead-code manual input removed from "Aktuelle Spiele" table; unused `_wizard_steps.html.erb` partial deleted
- `admin_controlled` feature removed with auto-advance gate flipped to always-true (column preserved for read-compat)
- Shared Stimulus confirmation modal infrastructure: reset confirmation (always shown) + parameter verification (triggered by `Discipline#parameter_ranges`)
- v7.1 ClubCloud Integration + v7.2 Shootout milestone skeletons planted; 2 backlog seeds (Match-Abbruch/Freilos, UI consolidation); CC admin-side appendix draft
- In-app wizard-to-doc links: locale-aware `mkdocs_link` helper (DE root, EN prefix) + 4 stable `{#anchor}` attrs in both `.de.md` and `.en.md` + all 6 wizard steps wired + 4 form-help info boxes
- 41 new Minitest assertions for Phase 37 helper contract (all green)

### What Worked

- **Scope splitting on discovery**: Phase 36 was "Small UX Fixes" until a sentence-by-sentence doc review produced 58 findings and 17 new requirements. Splitting 36 → 36a (doc accuracy) + 36b (UI cleanup) + 36c (v7.1 groundwork) preserved momentum without compromising any sub-goal. Captured in `v7.0-scope-evolution.md`.
- **Discuss-phase CONTEXT.md as contract**: Phase 37's 20 locked decisions (D-01..D-20) made the planner's job trivial — plans verified first-pass by gsd-plan-checker with zero revisions. The 5 plans shipped in ~8 minutes per plan with zero deviations.
- **Plan 37-04 tooltip invariant via git-diff assertion**: The acceptance criterion `git diff data-controller="tooltip" line count must return 0` caught nothing because the executor respected it. But it's the right kind of guardrail: structural invariant on prior work, not a subjective "don't break it".
- **Human UAT catches what automation can't**: Phase 36b's automated verification was 10/10 PASS, but the 2026-04-15 walkthrough surfaced G-01 (dark-mode contrast) and G-02 (stale public/docs) — both real bugs that no unit test could have caught because they're about deployment state and visual contrast.
- **Inline fix during UAT**: G-02 (public/docs/ stale since Mar 18) was discovered AND resolved within the UAT session — 257 files regenerated via `bin/rails mkdocs:build`, committed as `7cf16114`. UAT sessions aren't just "report bugs" — they can close them.
- **Gap capture as seed, not todos**: The 5 non-regression follow-ups from UAT went into a single seed file with fix sketches instead of 5 scattered todos. The seed will surface at next milestone kickoff. Low-friction transition from "found a bug" to "will get fixed later at the right moment".

### What Was Inefficient

- **`gsd-tools roadmap analyze` + `milestone complete` phase-parser bug**: The tool consistently failed to detect Phase 36c and 37 in milestone v7.0 (said "5 phases" instead of 7, "25 plans" instead of 31). The archival completed anyway because the ROADMAP.md content was copied verbatim, but the MILESTONES.md entry was garbage and had to be hand-rewritten. Root cause: the parser splits phases on exact `phase_number` match and 36c/37 confused it.
- **`gsd-tools` accomplishment extraction**: Some SUMMARY.md one_liner fields were empty or contained template artifacts ("One-liner:", "None — plan executed exactly as written", "`app/models/discipline.rb`") which the tool surfaced verbatim into the milestone entry. Need stricter one_liner format validation in executor agents OR retroactive cleanup at archive time.
- **`public/docs/` deployment gap invisible to verification**: Plan 37-02 ran `mkdocs build --strict` and marked it PASS. gsd-verifier ran a goal-backward check and marked Phase 37 PHASE COMPLETE. BOTH verifications checked source `.md` files contained anchors, neither simulated a real request to `/docs/managers/tournament-management/`. The bug (G-02) was only caught by human UAT. **Lesson for future verification**: any phase that touches `docs/**/*.md` should also grep the SERVED HTML file, not just the source Markdown.
- **REQUIREMENTS.md traceability table rotted across phases**: Phases 33, 34, 36b, 36c all shipped without updating their rows in the traceability table (only 35 and 37 kept it current). By the time of milestone completion, 24 requirements said "Pending" despite being shipped. Had to be hand-fixed before archival. **Recommended automation**: executor agents should update traceability as part of phase completion, or gsd-verifier should refuse to mark PHASE COMPLETE if traceability disagrees with SUMMARY existence.
- **Stale milestone audit**: `.planning/v7.0-MILESTONE-AUDIT.md` dated 2026-04-14 (before 36c + 37 shipped) was never refreshed. It still said "28/36 requirements complete" and "Phase 36c/37 not started" when those phases had in fact shipped. User opted not to re-run `/gsd-audit-milestone` before archival. Low-consequence because the traceability fix caught it, but a sign that audit docs should have auto-expire semantics (e.g., "stale if latest phase commit postdates audit").

### Patterns Established

- **Wizard step partial API via `local_assigns.fetch`**: Adding optional locals without breaking backward compatibility — the `docs_path:` / `docs_anchor:` pattern in `_wizard_step.html.erb` is the template for future additive locals.
- **Shared confirmation modal as reusable infrastructure**: One Stimulus controller + one partial reused by both reset (UI-06) and parameter verification (UI-07). Same pattern should apply to any future "dangerous action" confirmations.
- **i18n namespace discipline**: `tournaments.monitor_form.{labels,tooltips}.*` (Phase 36b) and `tournaments.docs.*` (Phase 37) show that sub-namespacing by feature prevents translation key drift as the project grows.
- **Stable `{#anchor}` attrs as the LINK-XX foundation**: Cross-locale anchor stability via `attr_list` markdown extension + identical English-only kebab-case IDs in both `.de.md` and `.en.md`. Zero Ruby-side complexity.
- **"Ship the tactical fix, defer the structural one" pattern**: G-02 was fixed inline via `bin/rails mkdocs:build` (tactical), with the structural fix (pre-commit hook / CI guard) deferred to a future phase. Explicit acknowledgement in the commit message, not silent debt.
- **Gaps → seed, not todos**: When a set of related follow-up items emerges from UAT or post-phase review, a single seed file with fix sketches beats scattered todos.

### Key Lessons

- **Bookkeeping rot is real**: A traceability table that's manually maintained across multi-phase milestones will drift. Either automate updates or accept that cleanup is part of milestone completion.
- **Deployment gaps aren't functional gaps**: Phase 37's anchors were in the source `.md` files AND the `mkdocs build` output AND passed `--strict`. What broke was the `site/` → `public/docs/` copy step. Verification that only checks source files misses deployment failures entirely. Any phase that ships docs should spot-check the served artifact, not the build input.
- **Human UAT isn't optional**: Even with 10/10 automated tests, visual and deployment issues only surface when a human walks through the product. The 36B UAT session produced 6 gaps in ~30 minutes — items that would have been 10x harder to find and fix in production.
- **Scope evolution during a phase isn't failure**: Phase 36 discovering it was actually 3 phases worth of work wasn't a planning miss — it was the doc review working as designed. The rescoping was fast (same day), transparent (`v7.0-scope-evolution.md`), and the split phases shipped cleanly.
- **The user is the judge of "done"**: Test 1 was marked `issue` because the user found a dark-mode bug while inspecting the header. They didn't negate the Test 1 criteria — they found a different bug in the same view. Workflow's "anything else is an issue" rule captured the signal correctly.

### Cost Observations

- Model mix: Opus for planning (37 + 36b), Sonnet for research/execution/verification; Plan 37-01..05 executed in ~2-8 minutes each
- Phase 37 start-to-finish (discuss → plan → execute → verify): ~50 minutes of wall time across 5 plans, 41 test assertions
- Human UAT + inline G-02 fix + archival: ~90 minutes of wall time, 1 major inline fix (257 files, +70k/-15k lines)
- Notable: the `gsd-tools milestone complete` parser bug required hand-rewriting the MILESTONES.md entry. For future milestones with phase number suffixes (36a/36b/36c), expect similar cleanup.

---

## Cross-Milestone Trends

| Metric | v1.0 | v2.0 | v2.1 | v3.0 | v4.0 | v5.0 | v6.0 | v7.0 |
|--------|------|------|------|------|------|------|------|------|
| Phases | 5 | 5 | 6 | 3 | 4 | 4 | 5 | 7 |
| Plans | — | — | — | — | 9 | — | 12 | 31 |
| Test suite | 475 | 475 | 751 | 751 | 901 | — | — | 1145+ |
| Services extracted | 14 | 0 | 7 | 0 | 6 | 10 | 0 | 0 |
| Models refactored | 2 | 0 | 2 | 0 | 2 | 0 | 0 | 0 |
| Docs files rewritten | 0 | 0 | 0 | 0 | 0 | 0 | many | 2 |
| Milestone theme | Refactor | Test audit | Refactor | Tests | Refactor | Scraper | Docs | UX/Feature |

**v7.0 is the first milestone where the primary deliverable isn't refactoring or tests — it's product UX and user-facing docs.** The patterns that worked for god-object breakdown (characterization → extraction → coverage) didn't apply directly; what worked instead was discuss-phase CONTEXT.md as a 20-decision contract, plus human UAT to catch what automation can't.

**Recurring pattern (refactor milestones v1.0/v2.1/v4.0/v5.0):** Characterization → Extraction → Coverage. Proven template for god-object breakdown.

**New pattern (v6.0/v7.0 docs+UX milestones):** Scout → Rewrite → Bilingual mirror → Human UAT. mkdocs build --strict as a gate. UAT closes the loop on deployment gaps.

**All original god-object models now addressed:**
- TableMonitor: 3903→1611 (v1.0)
- RegionCc: 2728→491 (v1.0)
- Tournament: 1775→575 (v2.1)
- TournamentMonitor: 499→181 (v2.1)
- League: 2221→663 (v4.0)
- PartyMonitor: 605→217 (v4.0)
- UmbScraper: 2133→175 (v5.0)

**v7.0 follow-ups seeded for next milestone:** `v71-ux-polish-i18n-debt.md` (G-01, G-03, G-04, G-05, G-06).
