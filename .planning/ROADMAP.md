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

- [x] **Phase 38: UX Polish & i18n Debt** — Close 5 v7.1 requirements (dark-mode contrast, tooltip affordance, EN warmup translation, DE-only string audit on tournament views, Phase 36B Test 1 retest) in 2 plans (completed 2026-04-15)
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
- [ ] `38-01-quick-wins-bundle-PLAN.md` — G-01 dark-mode Tailwind class replacement on `_wizard_steps_v2.html.erb` (lines 167, 215, 268) + `tournament_wizard.css:287-295` specificity audit, G-03 single CSS attribute-selector rule for `[data-controller~="tooltip"]`, G-05 3-line `en.yml:844-846` warmup translation, plus the UX-POL-03 Phase 36B Test 1 retest (manual UAT) executed once G-01 ships. Closes UX-POL-01, UX-POL-02, UX-POL-03, I18N-01.
- [ ] `38-02-tournament-views-i18n-audit-PLAN.md` — grep-based sweep of `app/views/tournaments/` for hardcoded German strings (22 ERB files, excluding `_wizard_steps_v2.html.erb`), new keys under `tournaments.monitor.*` / `tournaments.show.*` / `tournaments.<action>.*`, DE + EN added in parallel per CONTEXT.md D-14. Closes I18N-02.

### Phase 38.1: BK2-Kombi minimum viable support (INSERTED)

**Goal**: Ship live-scoring scoreboard support for a BK2-Kombi tournament at the BCW club on Saturday 2026-05-02. Full shot-by-shot live scoring for the BK2-Kombi discipline: negative-score engine gate, discipline derivation, two playing phases (Direkter Zweikampf / Serienspiel), bonus-shot rule, foul handling with D-16 literal values, best-of-3 sets to configurable target (50/60/70), match winner = first to 2 sets. Karambol-with-negative-scores remains a rehearsed fallback.
**Depends on:** Phase 38
**Decisions addressed:** D-01..D-17 (see 38.1-CONTEXT.md)
**Plans:** 5/6 plans executed

Plans:
- [ ] `38.1-01-engine-negative-score-gate-PLAN.md` — Bypass the three `score_engine.rb` negative-score gates (:84 guard, :135 clamp, :690-692 protocol rejection) for `data["free_game_form"] == "bk2_kombi"` via a new `allow_negative_scores?` helper. Includes characterization tests that prove karambol still clamps/rejects. Wave 1.
- [ ] `38.1-02-dispatch-and-discipline-data-PLAN.md` — `GameSetup` derivation from `discipline.data["free_game_form"]` with name-match fallback and warning log; `OptionsPresenter` passthrough verification; `ResultRecorder` BK2 dispatch branch to `Bk2Kombi::AdvanceMatchState`; D-10 `discipline.data` write on id 107 (primary carambus_api path + BCW unprotected fallback with reconciliation runbook). Wave 1.
- [ ] `38.1-03-bk2-kombi-scoring-services-PLAN.md` — `Bk2Kombi::ScoreShot` (pure evaluator, DEFAULT_RULES frozen constant, exact D-15/D-16 literals) + `Bk2Kombi::AdvanceMatchState` (set/match close, idempotency via `shot_sequence_number`). TDD with 22 unit + 11 state-mutation + integration tests. Wave 2.
- [ ] `38.1-04-scoreboard-partial-and-input-PLAN.md` — Dedicated `_scoreboard_bk2_kombi.html.erb` partial + `_show_bk2_kombi` wrapper, shot-input form, `bk2_kombi_submit_shot` reflex action with scoped CableReady broadcast, Stimulus controller with 500ms submit debounce, DE+EN i18n keys under `table_monitor.bk2_kombi.*`. Wave 3.
- [ ] `38.1-05-dry-run-uat-and-fallback-drill-PLAN.md` — Pre-dry-run gate (critical suite + lint + brakeman + production data sanity), physical BCW club-table dry run with explicit GO/NO-GO verdict (D-02 UAT gate), karambol-fallback drill runbook + rehearsal (D-03/D-07), phase closure updates in STATE.md + ROADMAP.md. Wave 4, autonomous:false.

### Phase 38.2: BK2-Kombi scoreboard UX re-alignment (INSERTED)

**Goal**: Replace the dedicated BK2-Kombi scoreboard UI from Phase 38.1 Plan 04 with a karambol-layout-preserving variant so that players familiar with the existing Carambol scoreboards are not disoriented on tournament day. Structural 1:1 copy of the karambol scoreboard (`_show.html.erb` + `_scoreboard.html.erb`) is used as the baseline; BK2-specific deltas (phase chip, set counter, phase-sensitive remaining badge, full-width shot-entry bottom bar replacing the +1/-5 button row) are additive only. Also closes UAT-GAP-02..GAP-05 from the Phase 38.1 dry-run feedback: detail-view Alpine scope bug, missing Home/Cancel nav, i18n phase key guard, and `bk2_state` initialization fallback.
**Depends on:** Phase 38.1
**Decisions addressed:** D-01..D-20 (see 38.2-CONTEXT.md)
**Plans:** 5 plans

Plans:
- [ ] `38.2-01-PLAN.md` — Service-layer + config + i18n scaffolding: `Bk2Kombi::AdvanceMatchState` augmented with `innings_left_in_set` + `first_set_mode` fields (D-19); `bk2_options` gains `direkter_zweikampf_max_shots_per_turn` (default 2), `serienspiel_max_innings_per_set` (default 5), `first_set_mode` (D-20); `TableMonitor#bk2_state_uninitialized?` predicate for GAP-05 fallback banner; `TableMonitorsController#start_game` BK2 branch whitelists + persists `bk2_options[:first_set_mode]`; DE + EN i18n keys for Plans 02/03/04 consumption. `Bk2Kombi::ScoreShot` untouched (scope guard per D-02). Wave 1.
- [ ] `38.2-02-PLAN.md` — Detail-view mode selector (D-14) + Alpine scope fix (GAP-02): lift the single `x-data` scope in `scoreboard_free_game_karambol_new.html.erb` onto an outer wrapper covering both the hidden inputs and the radio/button block; replace single "Spieler A stösst an" with four buttons (A-DZ, A-SP, B-DZ, B-SP) each encoding `first_break_choice` + `bk2_options[first_set_mode]` in one click. Wave 2, depends on 01.
- [ ] `38.2-03-PLAN.md` — Karambol-parallel scoreboard rewrite (D-01, D-03..D-13, D-17) + GAP-03/04/05 closure: `_show_bk2_kombi.html.erb` becomes a structural 1:1 copy of `_show.html.erb` with Home/Cancel/Continue warning modal (closes GAP-04) + `bk2_state_uninitialized?` fallback banner (closes GAP-05); `_scoreboard_bk2_kombi.html.erb` re-maps Karambol slots per D-03..D-13 (Satz header + phase chip center, sets_won next to names, Ziel = current set target, current-set score as large number, GD/HS/inning-counter/set-history removed, phase-sensitive "remaining" badge reads shots_left_in_turn for DZ / innings_left_in_set for SP); `current_phase.present?` guard closes GAP-03; placeholder marks Plan 04 insertion point. Wave 2, depends on 01.
- [ ] `38.2-04-PLAN.md` — Shot-entry bottom bar (D-15, D-16) + Stimulus controller rewrite: replace Plan 03 placeholder with full-width 3-row form (Row 1 amber full_pin_image + hint; Row 2 Gefallene Kegel + Mittelpin + Echter/Unechter Karambol; Row 3 Durchläufe + Fehler → Fehlercode + Bande + STOSS ERFASSEN); `bk2_kombi_shot_controller.js` targets new DOM but preserves all 10 target names + dataset keys + 500ms debounce + UUID seq number → reflex endpoint `TableMonitorReflex#bk2_kombi_submit_shot` UNCHANGED. Wave 3, depends on 03.
- [ ] `38.2-05-PLAN.md` — System + integration tests rewrite (D-17): full inplace rewrite of `test/system/bk2_kombi_scoreboard_test.rb` covering Plan-02/03/04 DOM + Plan-01 service augmentations + explicit GAP-02/03/04/05 regression probes; 38.1 B2 full_pin_image + wrong_ball foul regression tests preserved (scope-guard proof that ScoreShot stayed untouched). Wave 4, depends on 01+02+03+04.

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
| 38. UX Polish & i18n Debt | v7.1 | 2/2 | Complete    | 2026-04-16 |
| 38.1. BK2-Kombi minimum viable support | v7.1 | 5/6 | In Progress | - |
| 38.2. BK2-Kombi scoreboard UX re-alignment | v7.1 | 0/5 | Not started | - |
| 39. DTP-Backed Parameter Ranges | v7.1 | 0/TBD | Not started | - |

**v7.0 total:** 7 phases, 31 plans, 37/37 requirements, ~2 weeks wall time.
**v7.1 total (planned):** 4 phases, 12+TBD plans, 6+ requirements (5 in Phase 38, 1 in Phase 39, gap closure in 38.1/38.2).
