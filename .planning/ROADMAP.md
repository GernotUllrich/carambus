# Roadmap: Carambus API — Quality & Manager Experience

## Milestones

- ✅ **v1.0 Model Refactoring** — Phases 1-5 (shipped 2026-04-10)
- ✅ **v2.0 Test Suite Audit** — Phases 6-10 (shipped 2026-04-10)
- ✅ **v2.1 Tournament Refactoring** — Phases 11-16 (shipped 2026-04-11)
- ✅ **v3.0 Broadcast Isolation** — Phases 17-19 (shipped 2026-04-11)
- ✅ **v4.0 League & PartyMonitor Refactoring** — Phases 20-23 (shipped 2026-04-12)
- ✅ **v5.0 UMB Scraper Überarbeitung** — Phases 24-27 (shipped 2026-04-12)
- ✅ **v6.0 Documentation Quality** — Phases 28-32 (shipped 2026-04-13)
- ✅ **v7.0 Manager Experience** — Phases 33-37 (shipped 2026-04-15)
- 📋 **v7.1 ClubCloud Integration** — skeleton at `.planning/milestones/v7.1-*` (planned, not started)
- 📋 **v7.2 Shootout Support** — skeleton at `.planning/milestones/v7.2-*` (planned, not started)

## Phases

<details>
<summary>✅ v1.0–v6.0 (Phases 1-32) — SHIPPED</summary>

Phases 1-32 completed across six milestones. See `.planning/MILESTONES.md` for summaries and `.planning/milestones/v{X.Y}-ROADMAP.md` for full per-milestone phase details.

</details>

<details>
<summary>✅ v7.0 Manager Experience (Phases 33-37) — SHIPPED 2026-04-15</summary>

- [x] **Phase 33: UX Review & Wizard Audit** — Canonical wizard partial identified, 24 findings tier-classified (14 Tier 1, 7 Tier 2, 1 Tier 3), transient AASM state documented (completed 2026-04-13)
- [x] **Phase 34: Task-First Doc Rewrite** — `tournament-management.{de,en}.md` rewritten as volunteer walkthrough + glossary + troubleshooting + corrected index Quick Start (completed 2026-04-13)
- [x] **Phase 35: Printable Quick-Reference Card** — A4 Before/During/After checklist with print CSS, scoreboard shortcut cheat sheet, bilingual nav entry (completed 2026-04-13)
- [x] **Phase 36a: Turnierverwaltung Doc Accuracy** — 57/58 doc findings applied, Begriffshierarchie enforced, fictional UI elements removed, 10 troubleshooting recipes, new Anhang with 6 special flows (completed 2026-04-14)
- [x] **Phase 36b: UI Cleanup & Kleine Features** — Wizard header redesign (AASM badge + 6 bucket chips), 16 parameter tooltips, full i18n, admin_controlled removed, shared confirmation modal for reset + parameter verification (completed 2026-04-14, human UAT 2026-04-15)
- [x] **Phase 36c: v7.1 Preparation / ClubCloud Integration Groundwork** — v7.1/v7.2 milestone skeletons, 2 backlog seeds, CC admin appendix draft for Phase 36a (completed 2026-04-14)
- [x] **Phase 37: In-App Doc Links** — `mkdocs_link` locale-aware URL fix, 4 stable `{#anchor}` attrs in both DE/EN docs, all 6 wizard steps + 4 form-help info boxes wired (completed 2026-04-15)

**Full details:** `.planning/milestones/v7.0-ROADMAP.md`
**Requirements archive:** `.planning/milestones/v7.0-REQUIREMENTS.md`

</details>

### Next milestone

_Run `/gsd-new-milestone` to start the questioning → research → requirements → roadmap cycle. Two milestone skeletons are already available from Phase 36c groundwork and will surface when you pick your next direction:_

- `v7.1 ClubCloud Integration` (Endrangliste, Teilnehmerliste finalization, credentials delegation)
- `v7.2 Shootout / Stechen Support` (AASM + TournamentPlan + scoreboard UI)

_Additionally, seed `v71-ux-polish-i18n-debt.md` will auto-surface at next milestone kickoff — it captures 5 small follow-up gaps from Phase 36B human UAT (G-01, G-03, G-04, G-05, G-06)._

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 33. UX Review & Wizard Audit | v7.0 | 3/3 | Complete | 2026-04-13 |
| 34. Task-First Doc Rewrite | v7.0 | 4/4 | Complete | 2026-04-13 |
| 35. Printable Quick-Reference Card | v7.0 | 5/5 | Complete | 2026-04-13 |
| 36a. Turnierverwaltung Doc Accuracy | v7.0 | 7/7 | Complete | 2026-04-14 |
| 36b. UI Cleanup & Kleine Features | v7.0 | 6/6 | Complete | 2026-04-14 |
| 36c. v7.1 Preparation / CC Groundwork | v7.0 | — (planning phase) | Complete | 2026-04-14 |
| 37. In-App Doc Links | v7.0 | 5/5 | Complete | 2026-04-15 |

**v7.0 total:** 7 phases, 31 plans, 37/37 requirements, ~2 weeks wall time.
