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
- 🚧 **v7.1 UX Polish & i18n Debt** — Phase 38 (in progress, started 2026-04-15)
- 📋 **v7.2 ClubCloud Integration** — skeleton at `.planning/milestones/v7.2-*` (planned, not started)
- 📋 **v7.3 Shootout Support** — skeleton at `.planning/milestones/v7.2-*` (planned, version label TBD)

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

### 🚧 v7.1 UX Polish & i18n Debt (In Progress)

**Milestone Goal:** Close the 5 Phase 36B UAT follow-up gaps (G-01, G-03, G-04, G-05, G-06) plus a Test 1 retest before they rot into larger debt. Two-phase warm-up milestone: Phase 38 handles the UX/i18n polish surface, Phase 39 reworks `Discipline#parameter_ranges` on top of the existing `discipline_tournament_plans` table (scope expanded out of Phase 38 during its discuss-phase).

- [ ] **Phase 38: UX Polish & i18n Debt** — Close 5 v7.1 requirements (dark-mode contrast, tooltip affordance, EN warmup translation, DE-only string audit on tournament views, Phase 36B Test 1 retest) in 2 plans
- [ ] **Phase 39: DTP-Backed Parameter Ranges** — Close DATA-01 by replacing the hardcoded `DISCIPLINE_PARAMETER_RANGES` constant with a `Discipline#parameter_ranges(tournament:)` method that queries the existing `discipline_tournament_plans` table; handles normal/reduced modes and `handicap_tournier=true` special case

## Phase Details

### Phase 38: UX Polish & i18n Debt
**Goal**: Volunteer-facing wizard and tournament_monitor screens are polished — readable in dark mode, tooltips have visible affordance, EN locale is correct, and hardcoded German strings on tournament views are localized. Phase 36B Test 1 header criteria are explicitly reconfirmed.
**Depends on**: Phase 37 (v7.0 shipped)
**Requirements**: UX-POL-01, UX-POL-02, UX-POL-03, I18N-01, I18N-02
**Success Criteria** (what must be TRUE):
  1. A volunteer running the wizard in dark mode can read every `<details>` help block and every inline-styled info banner without squinting or switching to light mode (UX-POL-01).
  2. A volunteer seeing a tooltipped label on `tournament_monitor.html.erb` knows it is hoverable without trial-and-error — visible dashed underline + `cursor: help` on all 16 existing tooltipped labels (UX-POL-02).
  3. An English-locale admin sees "Warmup / Warm-up Player A / Warm-up Player B" on the scoreboard warm-up screen instead of "Training" (I18N-01); `en.yml:387 training: Training` remains untouched.
  4. No hardcoded German strings remain on `app/views/tournaments/` files outside the Phase 36B parameter form — every user-visible label routes through `t(...)` with new keys under `tournaments.monitor.*` / `tournaments.show.*` (I18N-02).
  5. Phase 36B Wizard Header Test 1 criteria (dominant AASM state badge, 6 bucket chips, no "Schritt N von 6" text, no numeric step prefixes) are explicitly reconfirmed via a fresh manual UAT pass after the G-01 fix lands (UX-POL-03).
**Plans**: 2 plans
**UI hint**: yes

Plans:
- [ ] 38-01: Quick wins bundle — G-01 dark-mode Tailwind class replacement on `_wizard_steps_v2.html.erb` (lines 167, 215, 268) + `tournament_wizard.css:287-295` specificity audit, G-03 single CSS attribute-selector rule for `[data-controller~="tooltip"]`, G-05 3-line `en.yml:844-846` warmup translation, plus the UX-POL-03 Phase 36B Test 1 retest checklist executed once G-01 ships
- [ ] 38-02: Tournament views i18n audit — grep-based sweep of `app/views/tournaments/` for hardcoded German strings (excluding Phase 36B parameter form), new keys under `tournaments.monitor.*` / `tournaments.show.*`, DE + EN translations

### Phase 39: DTP-Backed Parameter Ranges
**Goal**: `Discipline#parameter_ranges` becomes context-aware — it queries the existing `discipline_tournament_plans` table for canonical points/innings values based on the tournament's plan, player count, and player_class, returns Ranges derived from the normal (exact) or reduced (80%) mode, and correctly handles `handicap_tournier=true` tournaments (skip innings check, widen balls_goal which is per-participant from the participant list). The parameter verification modal no longer false-fires on youth/handicap/pool/snooker/biathlon/kegel tournaments.
**Depends on**: Phase 38 (v7.1 polish shipped first so the warm-up milestone lands incrementally)
**Requirements**: DATA-01
**Success Criteria** (what must be TRUE):
  1. `Discipline#parameter_ranges(tournament:)` takes a Tournament argument and returns a hash of `points` → `Range` and `innings` → `Range` computed from `DisciplineTournamentPlan.where(discipline: self, tournament_plan: tournament.tournament_plan, players: …, player_class: tournament.player_class)`.
  2. Normal mode returns an exact-match range; reduced mode returns `(points*0.8).floor..points`.
  3. When `tournament.handicap_tournier == true`, the innings check is disabled (Range is `nil` or `(0..Float::INFINITY)`), and `balls_goal` is either skipped or returns a very wide range because it's per-participant.
  4. Disciplines without a DTP entry (Pool, Snooker, Kegel, Biathlon, 5-Kegel) use a hardcoded fallback hash OR return an empty hash (= "no check"); behavior is explicit and tested.
  5. `DISCIPLINE_PARAMETER_RANGES` / `UI_07_SHARED_RANGES` / `UI_07_DISCIPLINE_SPECIFIC_RANGES` constants in `app/models/discipline.rb:59-87` are removed; the `tournaments_controller.rb` parameter verification callsite passes the tournament into the new signature.
  6. `test/models/discipline_test.rb` is updated to cover the new API surface (normal mode, reduced mode, handicap_tournier branch, DTP-backed disciplines, fallback disciplines); `test/system/tournament_parameter_verification_test.rb` still passes with the new behavior.
**Plans**: TBD (to be created by `/gsd-plan-phase 39`)
**UI hint**: no

## Progress

**Execution Order:**
Phases execute in numeric order: 33 → 34 → 35 → 36a → 36b → 36c → 37 → 38 → 39

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 33. UX Review & Wizard Audit | v7.0 | 3/3 | Complete | 2026-04-13 |
| 34. Task-First Doc Rewrite | v7.0 | 4/4 | Complete | 2026-04-13 |
| 35. Printable Quick-Reference Card | v7.0 | 5/5 | Complete | 2026-04-13 |
| 36a. Turnierverwaltung Doc Accuracy | v7.0 | 7/7 | Complete | 2026-04-14 |
| 36b. UI Cleanup & Kleine Features | v7.0 | 6/6 | Complete | 2026-04-14 |
| 36c. v7.1 Preparation / CC Groundwork | v7.0 | — (planning phase) | Complete | 2026-04-14 |
| 37. In-App Doc Links | v7.0 | 5/5 | Complete | 2026-04-15 |
| 38. UX Polish & i18n Debt | v7.1 | 0/2 | Not started | - |
| 39. DTP-Backed Parameter Ranges | v7.1 | 0/TBD | Not started | - |

**v7.0 total:** 7 phases, 31 plans, 37/37 requirements, ~2 weeks wall time.
**v7.1 total (planned):** 2 phases, 2+TBD plans, 6 requirements (5 in Phase 38, 1 in Phase 39).
