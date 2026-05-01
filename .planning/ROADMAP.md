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

### Phase 38.9: BK-2 end-of-set Anstoss-at-goal fix — close set immediately when Erste-Aufnahme-Gate fails (INSERTED)

**Goal:** [Urgent work - to be planned]
**Requirements**: TBD
**Depends on:** Phase 38
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 38.9 to break down)

### Phase 38.8: Endergebnis-erfasst state restore — operator-gate the post-match flow across all disciplines (INSERTED)

**Goal**: Restore the AASM `final_match_score` state ("Endergebnis erfasst") as the operator-gated end-state across ALL disciplines and BOTH modes. Today the state is silently skipped: training mode auto-starts the next game (regression introduced in commit c3dedb69 2026-03-24 — `ResultRecorder#evaluate_result` writes `update(state: "playing")` directly, bypassing AASM); tournament mode reaches the state but the round-progression cascade (`populate_tables`/`incr_current_round!`/etc.) clobbers the display before the operator sees it. After 38.8: training mode lands in `:final_match_score` and waits for "Nächstes Spiel"; tournament mode lands in `:final_match_score`, defers round-progression until operator triggers `close_match!`. Cross-discipline regression test locks the contract. Phase 38.7 tiebreak modal flow remains green.
**Depends on:** Phase 38.7
**Requirements**: SC-1 (training operator-gate), SC-2 (tournament operator-gate), SC-3 (final_match_score view + button), SC-4 (cross-discipline regression test), SC-5 (Phase 38.7 tiebreak preserved)
**Plans:** 6 plans

Plans:
- [ ] `38.8-01-red-characterization-test-PLAN.md` — RED characterization test in `test/services/table_monitor/result_recorder_test.rb`: training single-set no-tiebreak game lands in `:final_match_score` (NOT `:playing`). Locks the contract that would have failed since c3dedb69. Wave 1.
- [ ] `38.8-02-aasm-start-rematch-event-PLAN.md` — Add AASM event `:start_rematch` to `TableMonitor` (`:final_match_score → :playing`, `after: [:revert_players, :do_play]`); add DE + EN i18n keys `table_monitor.next_game` ("Nächstes Spiel" / "Next Game"). Wave 2.
- [ ] `38.8-03-delete-training-rematch-block-PLAN.md` — Delete the auto-rematch blocks at `app/services/table_monitor/result_recorder.rb` lines 462-476 (Branch C) and 485-497 (final_set_score branch). Replace with `@tm.finish_match! if @tm.may_finish_match?` mirroring `admin_ack_result` (table_monitor.rb:1649). Plan 01 RED test turns GREEN. Wave 2.
- [ ] `38.8-04-defer-tournament-round-progression-PLAN.md` — Extract round-progression cascade (`accumulate_results`/`populate_tables`/`incr_current_round!`/`finalize_round`/`start_playing_groups!`/etc.) from `TournamentMonitor::ResultProcessor#report_result` into new public method `advance_round_after_match_close`; wire AASM `:close_match` event with `after: :advance_tournament_round_if_present` so the cascade fires only on operator-confirmed match close. Wave 2.
- [ ] `38.8-05-view-and-reflex-wiring-PLAN.md` — Add `start_rematch` + `close_match` reflex methods to `TableMonitorReflex` (mirroring `admin_ack_result`/`force_next_state` locked_scoreboard pattern). Add `<%- elsif table_monitor.final_match_score? %>` branch to `_scoreboard.html.erb` rendering the "Nächstes Spiel" operator-gate button (training arm fires `start_rematch`, tournament arm fires `close_match`). Wave 3.
- [ ] `38.8-06-integration-system-test-PLAN.md` — End-to-end coverage in new `test/system/final_match_score_operator_gate_test.rb`: training match completion → `:final_match_score` → "Endergebnis erfasst" rendered → button click fires `start_rematch` → `:playing`. Tournament-mode round-progression deferred contract. Cross-discipline guard (karambol + BK-2). Phase 38.7 tiebreak file integrity check. + 3 AASM unit tests for `:start_rematch` in `test/models/table_monitor_test.rb`. Wave 4.

### Phase 38.1: BK2-Kombi minimum viable support (INSERTED)

**Goal**: Ship live-scoring scoreboard support for a BK2-Kombi tournament at the BCW club on Saturday 2026-05-02. Full shot-by-shot live scoring for the BK2-Kombi discipline: negative-score engine gate, discipline derivation, two playing phases (Direkter Zweikampf / Serienspiel), bonus-shot rule, foul handling with D-16 literal values, best-of-3 sets to configurable target (50/60/70), match winner = first to 2 sets. Karambol-with-negative-scores remains a rehearsed fallback.
**Depends on:** Phase 38
**Decisions addressed:** D-01..D-17 (see 38.1-CONTEXT.md)
**Plans:** 2/2 plans complete

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

### Phase 38.3: BK2-Kombi dry-run corrections — Karambol-branch merge + point-entry + detail/shootout rewire (INSERTED)

**Goal**: Close the Phase 38.2 dry-run findings DR-01..DR-06 recorded in `38.2-DRY-RUN-ISSUES.md` with a simplification pass: collapse the separate BK2 partials (`_show_bk2_kombi.html.erb`, `_scoreboard_bk2_kombi.html.erb`) from Plan 38.2-03 back into conditional branches inside the existing Karambol partials (`_show.html.erb`, `_scoreboard.html.erb`) — same pattern Eurokegel uses — because BK2 now deviates from Karambol only in three narrow ways: (1) inning-score and set-score may be negative and rendered with minus sign; (2) GD / HS / per-set-history slots hidden; (3) set-to-set phase alternation between Direkter Zweikampf and Serienspiel with matching remaining-badge (`Stöße übrig` vs `Aufnahmen übrig`). Replace the event-based shot-entry bar + Stimulus controller from Plan 38.2-04 with a Karambol-parallel point-entry bottom bar (`-10 -5 -1 | reset | +1 +5 +10` + number popup) that commits whole inning totals to the set score via a new thin service `Bk2Kombi::CommitInning`; `Bk2Kombi::ScoreShot` stops being called on the live path (kept as code for a possible later event-based mode). Move the four first_set_mode buttons out of the detail-view (Plan 38.2-02 removed them from there) and into the shootout screen where they replace the Karambol-generic "Spieler A/B stösst an" buttons; repurpose the detail-view BK2 branch to configure Ballziel (50/60/70) + DZ-max-shots + SP-max-innings instead. DR-02 rule-interpretation defaults (Landessportwart + BK2 Excel tool) confirm or adjust the `bk2_options` defaults already configurable from Plan 38.2-01.
**Depends on:** Phase 38.2 (Plan 38.2-01 service/config/i18n foundations stay; Plans 38.2-02, 38.2-04 partially unwound; Plan 38.2-03 partials removed; Plan 38.2-05 tests rewritten)
**Decisions addressed:** D-01..D-23 + DR-01..DR-06 (see 38.3-CONTEXT.md and 38.2-DRY-RUN-ISSUES.md)
**Plans:** 8/8 plans complete

Plans:
- [ ] `38.3-01-PLAN.md` — New service `Bk2Kombi::CommitInning` (point-entry paradigm per D-21) with TDD test suite. DZ negative -> opponent credit (D-11); SP additive signed (D-12). Reuses AdvanceMatchState set-close logic. Wave 1.
- [ ] `38.3-02-PLAN.md` — Delete `_show_bk2_kombi.html.erb`; route dispatcher through shared `_show.html.erb` with BK2 fallback-banner branch (GAP-05). D-01. Wave 1.
- [ ] `38.3-03-PLAN.md` — Delete `_scoreboard_bk2_kombi.html.erb`; branch `_scoreboard.html.erb` + `_player_score_panel.html.erb` on `options[:free_game_form] == "bk2_kombi"` (phase chip, remaining badge, GD/HS hidden, negative-tolerant scores). D-01/D-04..D-10. Wave 1.
- [ ] `38.3-04-PLAN.md` — Delete `bk2_kombi_submit_shot` reflex + `bk2_kombi_shot_controller.js`; add `bk2_kombi_commit_if_active` helper branching `next_step`/`key_a`/`key_b` to `CommitInning` on BK2 matches (D-14/D-23). Wave 2 (deps: 01+02+03).
- [ ] `38.3-05-PLAN.md` — Branch `_shootout.html.erb` to render 4 BK2 first_set_mode buttons; augment `start_game`/`switch_players_and_start_game` reflexes to persist `bk2_options[:first_set_mode]` from CLAMPed dataset (D-18/DR-01). Wave 3 (depends on 04 for reflex file overlap).
- [ ] `38.3-06-PLAN.md` — Repurpose detail-view BK2 branch: remove 4 first_set_mode buttons, add Ballziel/DZ-max/SP-max config inputs; controller whitelist+CLAMP for the two new fields (D-17/DR-06); preserve Alpine scope-lift (GAP-02 guard). Wave 1.
- [ ] `38.3-07-PLAN.md` — Rewrite `test/system/bk2_kombi_scoreboard_test.rb` end-to-end against Variante B paradigm + regression guards for deleted code. Wave 4 (depends on 01-06).
- [ ] `38.3-08-PLAN.md` — Gap closure (I6 blocker): expose `Bk2Kombi::AdvanceMatchState.initialize_bk2_state!` public method; wire into `start_game` + `switch_players_and_start_game` reflexes to populate `bk2_state` on shootout→playing transition. Unblocks HUMAN-UAT 1/2/3. Wave 1 (standalone gap closure).

### Phase 38.4: BK2-Kombi post-dry-run gaps (INSERTED)

**Goal**: Close the 8 issues deferred from Phase 38.3 (I1-I5, I7, I8, I9 — I6 already closed in 38.3-08) plus the open `sync-version-yaml-load-json-collision` todo. Coherent BK-* family restructure: (1) two bugs — webapp Delete missing on BK2 fallback banner (I8), Ballziel silently ignored in Serienspiel (I9); (2) discipline data-model restructure (I1) — BK50, BK100, BK-2, BK-2plus as peer disciplines to BK-2kombi, central Discipline records carrying `data[:free_game_form]` + `data[:ballziel_choices]`; (3) UI label rename (I2) — "Direkter Zweikampf" → "BK-2plus" / "Serienspiel" → "BK-2", i18n VALUES only, internal mode keys unchanged to avoid bk2_state migration risk; (4) scoring generalization (I7) — `Bk2Kombi::*` → `Bk2::*` hard rename, branch by `discipline.data[:free_game_form]`, opponent-credit only for BK-2plus + BK-2plus-phase of BK-2kombi, sign-preserving additive scoring for BK-2/BK50/BK100; (5) UI tweaks (I3 detail-view conditional inputs per discipline; I4 shootout 4-btn BK-2kombi-only; I5 shootout button labels use real player names); (6) sync-bug unblock — `Version.safe_parse` / `safe_parse_for_text_column` replaces `YAML.load` JSON-text-column collision so the 4 new central Discipline records can propagate cleanly to all local servers.
**Depends on:** Phase 38.3 (Bk2Kombi service namespace, balls_goal field, BK2-Kombi karambol-branch partials)
**Decisions addressed:** D-01..D-19 (see 38.4-CONTEXT.md and 38.4-DISCUSSION-LOG.md)
**Plans:** 17/17 plans complete

Plans:
- [x] `38.4-01-PLAN.md` — `Version.safe_parse` + `safe_parse_for_text_column` helpers; replace 4 `YAML.load(args["data|remarks"])` callsites in `Version#update_from_carambus_api`; 9 regression tests. Wave 1.
- [x] `38.4-02-PLAN.md` — I8: add Delete escape-hatch button to BK2 fallback banner in `_show.html.erb` (button_to + Turbo confirm); DE/EN i18n keys under `table_monitor.bk2_kombi.fallback.delete_button`. Wave 1.
- [x] `38.4-03-PLAN.md` — I2: rename UI labels in `de.yml` + `en.yml` (8 value substitutions); internal mode keys (`direkter_zweikampf`, `serienspiel`) and YAML key paths unchanged per D-08/D-09. Wave 2.
- [x] `38.4-04-PLAN.md` — I1+I9: extend `BK2_DISCIPLINE_MAP` to 5 entries; `bk_family?` predicate; `clamp_bk_family_params!` controller helper for `balls_goal` against `discipline.ballziel_choices`; backfill migration from legacy `set_target_points`; seed script for new central Discipline records. Wave 3.
- [x] `38.4-05-PLAN.md` — I7: hard rename `Bk2Kombi::*` → `Bk2::*` (zero residue in app/test/config); 5-way dispatcher in `Bk2::CommitInning` (BK-2plus opponent-credit, BK-2/BK50/BK100 additive, BK-2kombi phase-dependent); `result_recorder.rb` extended to 5-value `BK2_FREE_GAME_FORMS.include?` check. Wave 3.
- [x] `38.4-06-PLAN.md` — I3+I4+I5: detail-view 5-radio BK-family selector with Ballziel dropdown + conditional DZ/SP-max inputs (Alpine, single x-data scope); shootout 4-btn re-sorted (cols=player, rows=mode), real player names, BK-2kombi-only via `is_bk2_kombi` predicate; phase-chip narrowed from 5-family `is_bk2` to single-value `is_bk2_kombi`. Wave 4.
- [x] `38.4-07-PLAN.md` — Rewrite `test/system/bk2_kombi_scoreboard_test.rb` → `test/system/bk2_scoreboard_test.rb` (35 methods: 17 preserved from 38.3 + 18 new regression probes for I1-I5, I7, I8, I9); service-level coverage extended for `Bk2::AdvanceMatchState` and `Bk2::CommitInning` (D-06 balls_goal semantics). Wave 5.
- [x] `38.4-08-PLAN.md` — UAT-test-2 closure (I9 sub-issue): two-layer fix for `start_game` `ActionController::UnfilteredParameters` crash on nested `bk2_options` hash — controller `params.permit(...).to_h` (closes I9 + 4 bonus 38.3-06 free-game tests that were silently dropping `bk2_options`) + `GameSetup#initialize` defensive `.to_unsafe_h` guard (closes I9b unit test). Wave 6.
- [x] `38.4-09-PLAN.md` — UAT-test-3 minor closure: BK-* detail-view (lines 317-390 of `scoreboard_free_game_karambol_new.html.erb`) converted to 4 _radio_select-style touch-button rows (BK-Variante / Punkt-Ziel / DZ-max / SP-max). Punkt-Ziel row introduced with discipline-aware values [50/100/50-100/50-70]. Hidden-input integrity preserved (no duplicates). 4 new system test guards green.

- [x] `38.4-10-PLAN.md` — UAT round 3 layout/form integrity (closes O1, O3, O6, O7, O7a, O8): hide pre-existing generic Punktziel row when BK-* selected; BK-Variante row to 8-col grid for right-flush; standalone DZ-max + SP-max rows removed (DZ-max hardcoded server-side; SP-max merged into Aufnahmebegrenzung with discipline-aware buttons [5,7] vs [20,25,30] vs hidden-for-BK50/BK100); 5 new T-O* system tests. Wave 1.
- [x] `38.4-11-PLAN.md` — UAT round 3 Nachstoß rule + off-by-one fix (closes O2, O4): `nachstoss_allowed: true` flag on all 5 BK-* Discipline records via seed; Discipline#nachstoss_allowed? helper; Bk2::AdvanceMatchState#close_set_if_reached! gains Nachstoß deferred-close branch (state["nachstoss_pending"]); Nachstossende can score up to and including balls_goal (off-by-one removed); 5 new RED→GREEN service tests + 1 system test. Wave 1.
- [x] `38.4-12-PLAN.md` — UAT round 3 BK-2kombi quick-game shortcut (closes O5): canonical "BK-2kombi 2/5/70+NS" button at index 0 of BK2-Kombi quick-game category in config/carambus.yml.erb; `_quick_game_buttons.html.erb` button_id derivation amended with label_suffix to disambiguate same-balls_goal entries; 2 new T-O5 system tests. Wave 1.

### Phase 38.5: BK-Param-Hierarchy + Multiset-Config (INSERTED)

**Goal**: Two orthogonal BK scoring parameters (`allow_negative_score_input`, `negative_credits_opponent`) become first-class, resolvable via a hierarchy chain Discipline → Tournament → TournamentPlan → TournamentMonitor → Quickstart-Preset → Detail-Form → TableMonitor (lower levels override upper). Architectural correction: BK-2kombi stops being a peer Discipline and becomes a Multiset-Konfiguration that points to BK-2plus (DZ phase) and BK-2 (SP phase) per set — the resolver picks the per-set effective discipline as the top of the chain. Short-term scope: training path (Discipline → Quickstart → Detail-Form → TableMonitor); tournament path (Discipline → Tournament → TournamentPlan → TournamentMonitor → TableMonitor) is deferred to a follow-up half-phase. Defaults migrated from current `free_game_form` string-equality checks: BK-2plus (true/true), BK-2/BK50/BK100 (true/false), BK-2kombi DZ-set (true/true via BK-2plus), BK-2kombi SP-set (true/false via BK-2), all others unchanged.
**Depends on**: Phase 38.4 (BK family Discipline records seeded; `Bk2::CommitInning` 5-way dispatcher in place)
**Decisions addressed:** D-01..D-16 (see 38.5-CONTEXT.md)
**Plans:** 6/6 plans complete

Plans:
- [ ] `38.5-01-PLAN.md` — RED-tests in `test/integration/bk_param_latent_bugs_test.rb` documenting D-11 (BK-2kombi DZ credit-opponent) and D-12 (BK-2/BK50/BK100 negative-clamp) latent bugs. Tests fail today, turn GREEN automatically after Plans 04+05 land. autonomous: true. Wave 1.
- [ ] `38.5-02-PLAN.md` — `BkParamResolver` service (`app/services/bk_param_resolver.rb`) walking the 7-level hierarchy (Discipline → Tournament → TournamentPlan(reserved, no data column) → TournamentMonitor → Quickstart-Preset → Detail-Form → TableMonitor). `bake!`/`resolve` API + multiset effective_discipline computation per set. ~14 unit tests covering walk-order, sparse override (D-06), training mode (D-14). autonomous: true. Wave 1.
- [ ] `38.5-03-PLAN.md` — Extend `script/seed_bk2_disciplines.rb` with two new D-05 keys for BK-2plus/BK-2/BK50/BK100 + `multiset_components` default for BK-2kombi (id 107). Update `test/fixtures/disciplines.yml` to mirror. Karambol/Snooker/Pool/Biathlon untouched. Sync flows via `Version#update_from_carambus_api` (38.4-D-05 fix already shipped). autonomous: true. Wave 1.
- [ ] `38.5-04-PLAN.md` — ScoreEngine predicate rewrite (D-09): `allow_negative_scores?` and `bk_credit_negative_to_opponent?` bodies become `!!data["..."]` reads. Three consumer call-sites (lines 84, 148, 706) automatically pick up new behaviour (D-10). 8 new tests cover 4-truth-table + 3 consumer paths + opponent-credit. autonomous: true. Wave 2 (depends on Plans 02+03).
- [ ] `38.5-05-PLAN.md` — Bake-hook integration (D-03): Hook 1 in `GameSetup#perform_start_game` (after deep_merge_data!, before save!); Hook 2 via new `Bk2::AdvanceMatchState.rebake_at_set_open!` thin delegate, called from `ResultRecorder#perform_switch_to_next_set` guarded by `bk2_kombi` (research finding 3 — actual hook site is ResultRecorder, not AdvanceMatchState). 4 integration tests. autonomous: true. Wave 2 (depends on Plan 02).
- [ ] `38.5-06-PLAN.md` — End-to-end verification: 2 new system tests in `bk2_scoreboard_test.rb` close D-11 + D-12 through the full UI path; Plan 01 RED-tests verified GREEN; no-lazy-bake decision recorded against research Open Question 2 (D-15 forbids migration code); BCW deployment runbook with sync-path checklist. autonomous: true. Wave 3 (depends on 01+04+05).
**UI hint**: no (resolver is data-only; per D-16 no UI toggles in this phase — derived-only)

### Phase 38.6: Discipline Master-Data Cleanup — BK-* Duplikate auf carambus_api (INSERTED)

**Goal**: Auf der carambus_api (Source of Truth für globale Records, id < 50_000_000) duplikate `Discipline`-Rows der BK-Familie via Merge-Skript zusammenführen, die 17 Reflections (`versions`, `discipline_tournament_plans`, `table_kind`, `super_discipline`, `sub_disciplines`, `tournaments`, `player_classes`, `player_rankings`, `discipline_cc`, `leagues`, `game_plan_ccs`, `game_plan_row_ccs`, `seeding_plays`, `competition_cc`, `branch_cc`, `training_concept_disciplines`, `training_concepts`) erhalten/transferieren, dann via Standard-AR-API (`update!`/`destroy`, KEINE `update_column`/`delete_all`/`update_all`) die Loser-Rows entfernen — damit PaperTrail Versions schreibt und `Version#update_from_carambus_api` die Bereinigung an alle Local-Server (carambus_bcw, carambus_phat, etc.) propagiert. Kanonische Namen: BK-2, BK-2plus, BK50, BK100, BK-2kombi.

Merge-Map (Winner → Loser):
- BK-2 → 110 (kein Loser)
- BK-2plus → 111 (kein Loser)
- BK50 → 108 (Loser: 61 "BK 50")
- BK100 → 109 (Loser: 62 "BK 100", 60 "BK 2-100" — semantisch BK100)
- BK-2kombi → 107 (Rename "BK2-Kombi" → "BK-2kombi"; Loser: 57 "BK 2kombi", 59 "BK2-Kombi", 95 "BK-2 Kombi")

**Depends on**: Phase 38.5 (BK-Param-Hierarchy nutzt 107/108/109/110/111 als Anker — Winner-IDs absichtlich gewählt, damit 38.5-Seed nicht erneut ausgerollt werden muss)

**Decisions addressed:**
- D-01: Winner-IDs = 107/108/109/110/111 (matchen 38.5-Seed)
- D-02: id 60 "BK 2-100" merged in BK100 (semantisch identisch)
- D-03: PlayerRanking-Konflikt-Strategie: FK-Update versuchen; bei Unique-Constraint-Verletzung Loser-Ranking destroyen + (player_id, winner_discipline_id) für spätere Recompute markieren
- D-04: Sync-Pfad ausschließlich PaperTrail-aware AR-Calls (KEINE `update_column`, `delete_all`, `update_all`, raw SQL)
- D-05: Format = One-shot Skript (`script/merge_bk_disciplines.rb`), erst dev, dann prod
- D-06: Verification = Before/After-Association-Counts-Protokoll (Markdown nach `tmp/`) im dev-Run
- D-07: Stats-First-Design: Skript Step-0 emittiert Usage-Matrix (Loser × Reflection × Count) BEVOR irgendwas modifiziert wird; informiert (a) ob Konflikt-Handler nötig, (b) Before/After-Protokoll, (c) ob Q1-Konflikte überhaupt auftreten. Erwartung: die meisten Reflections haben 0 Refs auf Loser
- D-08: `*_cc` Konflikte (`discipline_cc`/`competition_cc`/`branch_cc`) → Skript HÄLT AN, druckt Konflikt, manuelle Entscheidung pro Fall (kein Auto-Merge bei singulären CC-Rows)
- D-09: `super_discipline` self-ref defensiv im Skript behandeln (kein Pre-Scan; Loser-zu-Loser-Refs via topologische Reihenfolge oder zwei-Pass-Strategie)
- D-10: PaperTrail `versions`-Rows der Loser bleiben unangetastet (Annahme: alle Local-Server sind sync-aktuell, Audit-History bleibt korrekt am ursprünglichen item_id)
- D-11: Idempotenz: Re-Run = sicherer No-Op, wenn keine Loser-IDs mehr existieren

**Plans**: 3 plans

Plans:
- [ ] `38.6-01-merge-script-PLAN.md` — Build `script/merge_bk_disciplines.rb` per D-13's six phases (pre-flight + idempotency check, stats matrix per D-07, CC-conflict scan per D-08, per-loser merge in transactions per D-13/D-03/D-09, rename winner 107 to BK-2kombi per D-12, post-flight protocol with deltas + recompute todo per D-06). Uses ONLY PaperTrail-aware AR API (D-04). Wave 1, autonomous: true.
- [ ] `38.6-02-fixtures-canonical-rename-PLAN.md` — Update `test/fixtures/disciplines.yml` to use canonical name "BK-2kombi" (was "BK2-Kombi") so post-rename production state is mirrored in tests. Verify fixture loser-free (no loser IDs/names). Wave 1, autonomous: true.
- [ ] `38.6-03-dev-dry-run-PLAN.md` — Probe dev DB state, run the merge script in development, capture Markdown protocol, human-verify checkpoint for GO/NO-GO on production deployment. Production run is OUT of scope for /gsd-execute-phase (manual operator step). Wave 2, autonomous: false (human-verify gate).
**UI hint**: no (data-only cleanup)

### Phase 38.7: Tiebreak bei Unentschieden — Per-Game-Flag mit Modal-Eingabe (INSERTED)

**Goal**: A single game/set ending in a draw across the four trigger classes (TR-A Karambol innings parity, TR-B BK-2 / BK-2kombi-SP nachstoss-ballziel parity, TR-C generic ball parity, TR-D snooker/pool frame parity) opens an extension of the existing `protocol_final` modal with a Sieger-A/Sieger-B radio fieldset; operator pick persists to `game.data['tiebreak_winner']`, derives `ba_results['TiebreakWinner']` (1|2) for the Spielbericht-PDF, and feeds `PartyMonitor::ResultProcessor#update_game_participations` so league points reflect the pick instead of a draw. Per-game `tiebreak_required` flag baked at game start from a sparse hierarchy: Tournament.data → TournamentPlan.executor_params['gN'] → false. Training-mode sources (carambus.yml `quick_game_presets` per-button flag, free_game detail-form toggle, BK-2kombi BK-2-phase auto-detect) bake `Game.data['tiebreak_required']` directly — owned by gap-closure plans 38.7-09…12. Includes the BK-2 game-end-fix (D-02): when Nachstoss-Spieler reaches balls_goal in his Nachstoss-Aufnahme the set now closes (today: deadlock).
**Depends on**: Phase 38.6
**Decisions addressed:** D-01..D-16 + CD-01..CD-06 (see 38.7-CONTEXT.md)
**Plans**: 6/8 plans complete + 1 reverted + 5 gap-closure plans planned

Plans:
- [~] `38.7-01-discipline-defaults-and-fixtures-PLAN.md` — **REVERTED 2026-04-30** (commits `9ffb8744`, `4eeb5550`). User feedback: tiebreak property is independent from Discipline; Discipline rows must not be patched on local servers. Training-mode tiebreak source moves to gap-closure plans (carambus.yml preset / detail-form toggle / BK-2kombi auto-detect). Plan 04 also surgically updated to drop Level-3 Discipline lookup (commit `42297932`).
- [x] `38.7-02-bk2-game-end-fix-PLAN.md` — D-02 BK-2 game-end-fix (RED-then-GREEN per D-16): extend `TableMonitor#end_of_set?` so that BK-2 / BK-2kombi-SP set closes when Nachstoss-Spieler completes his Nachstoss-Aufnahme (closes today's deadlock). 5 characterization tests; small guard (extend-before-build). Wave 1. (SUMMARY: `38.7-02-SUMMARY.md`)
- [x] `38.7-03-result-processor-tiebreak-branch-PLAN.md` — D-10 tiebreak-priority branch in `PartyMonitor::ResultProcessor#update_game_participations`: when `game.data['tiebreak_winner']` set + rank tied, award win/lost instead of draw; defense-in-depth on invalid values. 5 unit tests. Wave 1. (SUMMARY: `38.7-03-SUMMARY.md`)
- [x] `38.7-04-tiebreak-flag-bake-PLAN.md` — `Game.derive_tiebreak_required` class method (CD-01) + bake call in `GameSetup#perform_start_game` (D-04, D-05). Sparse-override semantics across Tournament + TournamentPlan levels (Discipline level removed 2026-04-30). 8 unit tests + 4 integration tests. Wave 2. (SUMMARY: `38.7-04-SUMMARY.md`)
- [x] `38.7-05-result-recorder-tiebreak-detection-PLAN.md` — Trigger detection (D-03) + training-rematch guard (D-13) + `ba_results['TiebreakWinner']` derivation (D-08) in `TableMonitor::ResultRecorder`. `current_element='tiebreak_winner_choice'` marker (CD-02). 8 unit tests. Wave 3. (SUMMARY: `38.7-05-SUMMARY.md`)
- [x] `38.7-06-modal-radio-fieldset-PLAN.md` — Extend `_game_protocol_modal.html.erb` with radio fieldset (D-07); augment `GameProtocolReflex#confirm_result` with server-side validation + game.data persistence (D-08). i18n keys under `table_monitor.tiebreak.*` (CD-05). Wave 4. (SUMMARY: `38.7-06-SUMMARY.md`)
- [x] `38.7-07-spielbericht-pdf-rendering-PLAN.md` — `parties_helper#tiebreak_indicator(game)` + `_spielbericht.html.erb` view edit (D-12). i18n key `parties.spielbericht.tiebreak_won_by`. 5 unit tests. Wave 5. (SUMMARY: `38.7-07-SUMMARY.md`)
- [~] `38.7-08-system-tests-and-uat-PLAN.md` — `test/system/tiebreak_test.rb` with 4 E2E tests (TR-A Karambol + TR-B BK-2 + control + forged-submit security probe). Task 1 complete, 32 assertions GREEN. Task 2 (human UAT) **paused** at TR-B failure (training-mode source missing) → triggered the plan-01 revert + Level-3 surgery. Will resume after gap-closure plans land. (Partial SUMMARY: `38.7-08-SUMMARY.md`)

**Gap closure plans** (training-mode tiebreak sources — closes 4 gaps from 38.7-UAT.md, planned 2026-04-30):
- [ ] `38.7-09-PLAN.md` — Gap-01: `config/carambus.yml` `quick_game_presets` per-button `tiebreak_on_draw: true` on BK-2 + BK-2kombi; threaded through form → controller → GameSetup preset-override block (deep_merge_data!). 3 RED→GREEN tests. Wave 1.
- [ ] `38.7-10-PLAN.md` — Gap-02: free_game detail-form checkbox (`scoreboard_free_game_karambol_new.html.erb`) + i18n (DE/EN). Reuses Plan 09 controller wiring. 2 controller tests. Wave 2 (depends on 38.7-09).
- [ ] `38.7-11-PLAN.md` — Gap-03: BK-2kombi BK-2-phase auto-detect (`bk2_kombi_tiebreak_auto_detect!` private helper inside `tiebreak_pick_pending?`) — fires when phase=serienspiel + 1+1 innings + tied at goal; overrides any pre-baked false. 3 RED→GREEN tests. Wave 1.
- [ ] `38.7-12-PLAN.md` — Gap-04: TournamentMonitor startup-form checkbox + controller persist to Tournament.data['tiebreak_on_draw']. Default reads TournamentPlan.executor_params['g1'] Level 2. 3 RED→GREEN tests. Wave 3 (depends on 38.7-10, i18n file ownership).
- [ ] `38.7-13-tiebreak-modal-form-reflex-wiring-PLAN.md` — Gap-05: tiebreak modal submit-loop blocker. Move `data-reflex="submit->GameProtocolReflex#confirm_result"` + `data-id` from `<button>` onto `<form>` in `_game_protocol_modal.html.erb` (browsers fire submit events on forms, not buttons); add `action="javascript:void(0)"` defensive no-op fallback. 4 RED→GREEN integration tests (render-based wiring + GET-fallback no-op). Wave 1 (standalone, depends on []).

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
Phases execute in numeric order: 33 → 34 → 35 → 36a → 36b → 36c → 37 → 38 → 38.5 → 38.6 → 39

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 33. UX Review & Wizard Audit | v7.0 | 3/3 | Complete | 2026-04-13 |
| 34. Task-First Doc Rewrite | v7.0 | 4/4 | Complete | 2026-04-13 |
| 35. Printable Quick-Reference Card | v7.0 | 5/5 | Complete | 2026-04-13 |
| 36a. Turnierverwaltung Doc Accuracy | v7.0 | 7/7 | Complete | 2026-04-14 |
| 36b. UI Cleanup & Kleine Features | v7.0 | 6/6 | Complete | 2026-04-14 |
| 36c. v7.1 Preparation / CC Groundwork | v7.0 | — (planning phase) | Complete | 2026-04-14 |
| 37. In-App Doc Links | v7.0 | 5/5 | Complete | 2026-04-15 |
| 38. UX Polish & i18n Debt | v7.1 | 2/2 | Complete   | 2026-04-25 |
| 38.1. BK2-Kombi minimum viable support | v7.1 | 5/6 | In Progress | - |
| 38.2. BK2-Kombi scoreboard UX re-alignment | v7.1 | 5/5 | Complete | 2026-04-19 |
| 38.3. BK2-Kombi dry-run corrections | v7.1 | 8/8 | Complete | 2026-04-23 |
| 38.4. BK2-Kombi post-dry-run gaps | v7.1 | 17/17 | Complete   | 2026-04-25 |
| 38.5. BK-Param-Hierarchie + Multiset-Config | v7.1 | 6/6 | Complete    | 2026-04-29 |
| 38.6. Discipline Master-Data Cleanup | v7.1 | 4/4 | Complete    | 2026-04-29 |
| 38.8. Endergebnis-erfasst state restore | v7.1 | 0/6 | Planned | - |
| 39. DTP-Backed Parameter Ranges | v7.1 | 0/TBD | Not started | - |

**v7.0 total:** 7 phases, 31 plans, 37/37 requirements, ~2 weeks wall time.
**v7.1 total (planned):** 4 phases, 12+TBD plans, 6+ requirements (5 in Phase 38, 1 in Phase 39, gap closure in 38.1/38.2).
