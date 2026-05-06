---
gsd_state_version: 1.0
milestone: v7.1
milestone_name: UX Polish & i18n Debt
status: verifying
stopped_at: Completed 38.9-01-end-of-set-fourth-branch-PLAN.md (4th BK-2 sub-branch in end_of_set?, 2 RED-then-GREEN tests; latent defect 79328663 closed; phase 38.9 ready for /gsd-verify-work)
last_updated: "2026-05-05T14:00:00.000Z"
last_activity: 2026-05-05
progress:
  total_phases: 11
  completed_phases: 10
  total_plans: 68
  completed_plans: 67
  percent: 91
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-15)

**Core value:** Code and docs stay in sync — every documented feature works, every working feature is documented, and a volunteer user should never need to read the architecture to run a tournament.
**Current focus:** v7.1 Hauptphasen alle abgeschlossen (38, 38.1–38.9); offen sind nur Backlog 999.1 / 999.2 + carry-forward TODOs (Postpone Review-by 2026-07-05).

## Current Position

Phase: alle Hauptphasen 38..38.9 complete; backlog 999.1 not yet planned
Plan: —
Status: v7.1 inhaltlich fertig — verbleibende Items sind operativ (Server-Hygiene) oder backlog-parking (999.x). Ballziel-loss pending todo am 2026-05-05 nach `done/` verschoben (gefixed durch quick-260503-x3k commit `45f9174c`). BK-Family-Carry-Forwards (TODOs A/B/C) postponed bis ~2026-07-05.
Last activity: 2026-05-06 - Completed quick task 260506-i6h (commits `1c291731` + `12652ae2`): fixed `tournaments(:local)` fixture FK rot + tightened 36B-05 reset confirmation system test (3/3 green, 0 skips). Closes second 2026-04-14 todo. **Verifier: human_needed** — un-skipping 36B-06 surfaced 2 real bugs blocking push of the PRG refactor (commit `0ac7305a`): (1) PRG flash payload uses symbol keys but cookie-session JSON serializer stringifies — production-affecting; (2) fixture `state: "registration"` not in Tournament AASM state list — test-only. Earlier today: 260506-hka (PRG refactor commit `0ac7305a` + docs `1de19400`). Pre-push: 4 commits ahead of origin/master in carambus_bcw, other checkouts clean.

Previous milestone archived at:

- `.planning/milestones/v7.0-ROADMAP.md`
- `.planning/milestones/v7.0-REQUIREMENTS.md`
- `.planning/milestones/v7.0-MILESTONE-AUDIT.md`
- `.planning/milestones/v7.0-phases/` (8 phase directories: 33, 34, 35, 36, 36A, 36B, 36C, 37)

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Full v7.0 cross-phase decisions recorded inline in the milestone archive and RETROSPECTIVE.md.

**v7.1 roadmap decisions:**

- **Single-phase shape (Phase 38, 3 plans)** chosen over 2-phase or 3-phase splits. Rationale: all 6 requirements are small polish/debt items sharing the same UX theme (volunteer-facing wizard + tournament_monitor), don't benefit from cross-phase sequencing, and shipping in one phase keeps the milestone focused with an atomic final commit. Granularity is `coarse` and the seed explicitly recommends 1-3 plans / single phase.
- **DATA-01 short-term widen only assumed** — the medium-term DB-backed `discipline_parameter_ranges` table is flagged as a discuss-phase open question, not in scope for the roadmap. If the discuss-phase decides medium-term is in scope, Plan 38-03 can split or a Phase 39 can be inserted.
- **UX-POL-03 (Test 1 retest) bundled into Plan 38-01** with the G-01 fix. Dependency satisfied by ordering: G-01 ships first inside the same plan, retest immediately follows. No risk of retesting before the fix lands.
- [Phase 38.4]: I2 closed via i18n-values-only rename: direkter_zweikampf→BK-2plus, serienspiel→BK-2. Internal keys and YAML paths unchanged per D-08/D-09.
- [Phase 38.4]: D-06: balls_goal replaces set_target_points as per-set Ballziel target on tournament_monitor.balls_goal
- [Phase 38.4]: D-07: ballziel_choices array in discipline.data drives server-side CLAMP; clamp_bk_family_params! helper DRYs both quick-game and detail-form paths
- [Phase 38.4]: D-04: BK2_DISCIPLINE_MAP extended to 5 BK-* disciplines sharing one scoring family (Bk2::CommitInning)
- [Phase 38.4]: D-10/D-13: Hard rename Bk2Kombi→Bk2 with no runtime aliases; Open Q 2 resolved — result_recorder.rb keeps Bk2::AdvanceMatchState (not CommitInning)
- [Phase 38.4]: D-16/D-07: Alpine-driven 5-radio BK-family selector + Ballziel dropdown + conditional DZ/SP inputs in detail view; bk_selected_form drives all hidden inputs for 5 BK-* forms
- [Phase 38.4]: is_bk2_kombi semantic split: phase-chip + CSS hook narrowed to single-value BK-2kombi check; Plan 05 5-family is_bk2 predicate preserved for GD/HS hide and score display
- [Phase 38.4]: D-03: Wave 5 closure — renamed bk2_kombi_scoreboard_test.rb to bk2_scoreboard_test.rb; all 8 deferred issues (I1-I9 except I6) covered by explicit regression tests in 35-method Bk2ScoreboardTest suite
- [Phase 38.4]: Plan 08: Two-layer fix for start_game UnfilteredParameters — controller .to_h (load-bearing for production path + 4 existing tests) + GameSetup .to_unsafe_h defensive guard (closes I9b unit test)
- [Phase 38.4]: Plan 09: BK-* detail view converted to 4 touch-button rows (BK-Variante / Punkt-Ziel / DZ-max / SP-max) — outer col-span-6/space-y-3 wrapper REMOVED, rows plug into parent grid-cols-6 as 8 sibling divs. Bespoke template-x-for chosen over reusing _radio_select partial for Alpine-reactive value lists.
- [Phase 38.4]: Two _radio_select partial calls (not one with dynamic values) for O7 Aufnahmebegrenzung — partial has no Alpine-template x-for escape hatch
- [Phase 38.4]: x-effect approach chosen for innings→bk2_sp_max_innings mirror; runs reactively on Alpine state change without @change wiring on partial calls
- [Phase 38.4]: Provisional Nachstoß equal rule: trailing player wins (not Verlängerungssatz). Landessportwart sign-off pending before 2026-05-02 tournament.
- [Phase 38.4]: define_singleton_method used for discipline wiring in advance_match_state_test.rb unit tests — acceptable shortcut; fixture-based approach preferred for future system tests.
- [Phase 38.4]: carambus.yml (compiled/ignored) must be kept in sync with carambus.yml.erb manually — Carambus.config reads the local .yml, not the .erb template
- [Phase 38.4]: button_id disambiguation via label_suffix in _quick_game_buttons partial is preventive — added proactively for same-discipline+balls_goal entries (BK2-Kombi 70)
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 13: BK_FAMILY_BALLZIEL_FALLBACK constant + balls_goal_a/b fallback chain in clamp_bk_family_params! — defense-in-depth against carambus_api → local-server Discipline sync gap; closes P1 (BK100) and P3 (BK-2kombi 2/5/70+NS) round-4 UAT gaps
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 15: BK-Variante grid-cols-5 (supersedes Plan 10's grid-cols-8) + Aufnahmebegrenzung BK-* cols=4 + MEHRSATZ col-span-6 h-4 spacer; T-O6 renamed to -v2 per I-15-02; T-P2 ERB-compilation render replaces Capybara DOM (visit table_monitor_path doesn't render BK-* detail view) per I-15-01 — closes round-4 UAT P2 layout regression
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 16: P5 narrowed via interpretation (b) flag-only — nachstoss_allowed scoped to BK-2kombi (id 107) only; BK50/BK100/BK-2/BK-2plus retain Discipline records but lose flag.
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 16 round-4 iteration-2 BLOCKER 2: explicit pre-check (Option (i)) replaces unreachable rescue ActiveRecord::RecordInvalid — LocalProtector raises Rollback (transaction control flow), silently swallowed by AR transactions; rescue NEVER fired on local servers.
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 16 I-16-02: residual sync-race accepted (not blocked-on); production deployment sequence (master seed FIRST, then local-server migrations) makes window small + idempotent re-run recovers; tracked T-38.4-16-07 in STATE deferred follow-ups.
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 17: CR-01 closed via 1-char fix at version.rb:434 (local_server → local_server?); 3 T-CR-01 tests lock the predicate-naming convention. INFO-01 closed via git mv todos/pending/sync-version-yaml-...md → todos/done/ + closure marker. INFO-02 closed via 3 ROADMAP checkbox flips on plans 38.4-10/11/12. WR-01..06 stay deferred.
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 17 I-17-01 attestation: inline English comment above the local_server? fix is per CLAUDE.md line 23 technical-terms exception (NameError + predicate naming + line numbers are technical, not business). Documented in 38.4-17-SUMMARY.md for auditability.
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 14: Option B implemented — TableMonitor#discipline String contract preserved; bk_family_with_nachstoss? + route_goal_reached_through_bk2_commit_inning private helpers route :goal_reached through Bk2::CommitInning when name-looked-up Discipline has nachstoss_allowed? Bk2::CommitInning + Bk2::AdvanceMatchState hardened to handle String discipline (Rule 1 fix); incidentally clears 4 deferred T8-T11 errors. Closes round-4 P4 gap.
- [Phase 38.5]: Plan 01: RED-tests seed post-resolver state directly in data hash to decouple Plan 01 from Plan 02 — Plan 01 ships independently in Wave 1; tests turn GREEN automatically once Plan 04 rewrites predicates
- [Phase 38.5]: Plan 01: GSD verification contract — test/integration/bk_param_latent_bugs_test.rb is locked against edits in Plan 06; turning all 4 tests GREEN without editing this file proves Plans 04+05 fix the latent bugs correctly
- [Phase 38.5]: Plan 02: BkParamResolver as top-level service (orthogonal to Bk2:: namespace) — also services non-BK default-false path so karambol/snooker/pool stay correct without resolver-aware code.
- [Phase 38.5]: Plan 02: TournamentPlan level (Level 3) silently skipped — schema has no data column on tournament_plans (db/schema.rb:1255–1268). Honors D-14 'keine Migrationen'. Test D1 is the regression guard (assert_nothing_raised on Tournament+TournamentPlan reference).
- [Phase 38.5]: Plan 02: Levels 5 (Quickstart-Preset) + 6 (Detail-Form) collapse into Level 7 (TableMonitor) — D-16 defers UI toggles, so preset/form values already land in tm.data via controller params.
- [Phase 38.5]: Plan 02: bake! does NOT save (caller is responsible) and is idempotent — verified by F3 reloading from DB and asserting effective_discipline absent on persisted row. AASM initial-state callback persists TableMonitor.new implicitly, so tm.persisted? cannot be used for the contract test.
- [Phase 38.5]: Plan 02: D-06 sparse-override regression guard — test C1 explicitly asserts data.key? gate (NOT data[].present?) so an explicit false at any level overrides true at lower levels. Failure message names the bug class for self-diagnostic regressions.
- [Phase 38.5]: Plan 03: BK2-Kombi (Discipline 107) explicitly does NOT carry allow_negative_score_input or negative_credits_opponent — resolver looks up effective_discipline (bk_2plus or bk_2) per set and reads THAT Discipline's params (D-08). Seed script's idempotency guard deletes those keys if accidentally written by a prior run.
- [Phase 38.5]: Plan 03: Test fixture mirrors seed output verbatim — decouples Plan 02/04 unit tests from Version-sync timing. test/fixtures/disciplines.yml carries the same data shape that local servers receive via Version#update_from_carambus_api after the seed runs on carambus_api.
- [Phase 38.5]: Plan 04: Two-line predicate body swap in score_engine.rb (data["free_game_form"]=="..." → !!data["..."]) closes both latent BK-* bugs (D-11 BK-2kombi DZ, D-12 BK-2/BK50/BK100); three consumer call-sites (lines 84, 148, 706) UNCHANGED, automatically pick up new contract via D-10 (call-by-name).
- [Phase 38.5]: Plan 04: All 4 of Plan 01's RED tests turn GREEN from Plan 04 alone (NOT only Tests 2/3/4 as plan author predicted). Plan 01 seeded post-bake state directly in test data per its D-13 decoupling, so Test 1 (BK-2kombi DZ) doesn't need Plan 05's set-boundary bake. Plan 05 still required for the live add_n_balls path (system tests verify that surface).
- [Phase 38.5]: Plan 05: rebake_at_set_open! lives on Bk2::AdvanceMatchState (D-03 mental model) — thin one-line delegate to BkParamResolver.bake!; called from ResultRecorder#perform_switch_to_next_set (research finding 3 actual file path); BK-2kombi guard at consumer site (not inside delegate)
- [Phase 38.5]: Plan 05: stub-and-restore test pattern — save original via .method(:name), restore via define_singleton_method(name, original) in ensure. Avoids remove_method clobbering real module methods between sibling tests; load-bearing for testing module-level delegate methods
- [Phase 38.5]: Plan 06: 2 E2E system tests in bk2_scoreboard_test.rb prove BkParamResolver.bake! -> ScoreEngine integration end-to-end at the live data path; service-level dispatch (tm.score_engine.add_n_balls) over real DOM clicks matches existing 35-test convention
- [Phase 38.5]: Plan 06: No-lazy-bake decision recorded in 38.5-DEPLOYMENT-RUNBOOK.md (closes Open Question 2 from RESEARCH.md). Rationale: D-15 forbids migration code; ScoreEngine refactor for lazy-bake is out of scope (only Hash + Discipline AR ref, no TM ref); in-flight pre-38.5 BK-* matches fall back to false/false per D-04 (identical to today's behaviour, no regression); next start_game bakes correctly
- [Phase 38.6]: All 6 D-13 phases implemented in merge_bk_disciplines.rb — per-loser transaction isolation, PaperTrail-aware AR-API only, interactive CC-conflict halt
- [Phase 38.6]: Seed-replay carve-out: discipline_test.rb lines 190-247 keep 'BK2-Kombi' strings synchronized with un-touched seed file; follow-up phase required to align seed + test data after production merge runs
- [Phase 38.6]: Rule 1 auto-fix: table_monitors_controller_test.rb updated (not in plan's 4-file list) — 3 tests failed as direct cascade of BK2_DISCIPLINE_MAP rename; CLAMP target updated from BK2-Kombi to BK-2kombi
- [Phase 38.6]: Dry-run transaction wrapper added (Rule 3): merge_bk_disciplines_dry_run.rb wraps script in ActiveRecord::Rollback so dev DB stays untouched after path-B full-merge dry-run
- [Phase 38.6]: No CC-Konflikt-Scan conflicts found in dry-run: D-08 interactive halt never triggered — production merge is safest possible path
- [Phase 38.6]: PlayerRanking recompute list empty: all 24 loser-95 rankings FK-updated without unique-constraint conflict — no post-merge recompute job needed (D-03 scope cleared)
- [Phase 38.6]: Synonyms block inserted inside existing Discipline.transaction so dry-run rollback also undoes synonym change; winner.save! (not update_columns) preserves PaperTrail compliance (D-04)
- [Phase 38.7]: Plan 01: Sparse-key default for tiebreak_on_draw — BK-2 + BK-2kombi affirmatively true; BK50/BK100/BK-2plus/Karambol/Snooker/Pool key-absent. Resolver in Plan 03 must use data.key? gate (NOT data[].present?) so explicit higher-level false still overrides discipline-level true.
- [Phase 38.7]: Plan 01: Plan AC `grep -c "tiebreak_on_draw: true" seed_bk2_disciplines.rb == 2` is inconsistent with prescribed code (BK-2kombi block uses string-key syntax via current["tiebreak_on_draw"] = true, not symbol). Followed prescribed code; must_haves frontmatter (data carries true after seed) is satisfied. AC discrepancy documented for verifier.
- [Phase 38.7]: Plan 02: BK-2 / BK-2kombi-SP Nachstoss-Aufnahme close — extend-before-build SKILL applied (+37 LOC guard in end_of_set?, no parallel state machine). New branch fires when Anstoss at balls_goal AND nachstoss_innings == anstoss_innings + 1. Resolves D-02 deadlock without regressing the 41-test char suite.
- [Phase 38.7]: Plan 02: RED phase had 3 failures (predicted 2). Test 4 (Nachstoss not at goal, innings 5 vs 6) was predicted to PASS via legacy karambol gate but actually FAILS today — gate requires innings parity OR !allow_follow_up, both halves false in fixture. Task 2's new branch covers Test 4 correctly. Documented as plan-internal RED-prediction error, not a code defect.
- [Phase 38.7]: Plan 03: D-10 tiebreak override branch in update_game_participations — 3-clause defensive guard (is_a?(String) AND in whitelist AND rank tied) before applying operator pick. Legacy logic preserved verbatim in else-arm. Stub-based test pattern: prime_tiebreak_game creates real Game+GP+TM rows; run_update_game_participations stubs PartyMonitor#get_*_by_gname to decouple from league.game_plan fixture.
- [Phase 38.7]: Plan 04: Game.derive_tiebreak_required class method (CD-01, not extending BkParamResolver) walks 4-level hierarchy with sparse-override (data.key? gate). Plan-prescribed direct mutation @tm.game.data['key']=X failed to dirty-track because Game has a custom def data getter that returns freshly-decoded Hash; switched to @tm.game.deep_merge_data!('tiebreak_required' => …) which calls data_will_change! and reassigns self.data. RULE 1 deviation, documented inline.
- [Phase 38.7]: Plan 05: tiebreak_pick_pending? as private helper on ResultRecorder (mirrors TableMonitor#tiebreak_pending_block? but kept separate per public/private split). T7-T9 do NOT use @tm.reload — update_ba_results_with_set_result! does NOT save (caller owns persistence). Plan-prescribed reload removed during GREEN phase as Rule 1 plan-prescribed-test-bug fix.
- [Phase 38.7]: Plan 05: AASM guard  on :acknowledge_result event provides D-08 defense-in-depth across ALL caller paths (admin_ack_result, ResultRecorder branches, console, forged direct invocations). Pairs with Plan 06's reflex-level form validation for layered defense.
- [Phase 38.7]: Plan 06: Modal radio fieldset rendered only when current_element=='tiebreak_winner_choice' (D-07 extend-before-build); reflex confirm_result augmented with allowlist guard + deep_merge_data! persistence (Rule 1 same dirty-tracking fix as Plan 04). 5 functional tests cover allowlist + persistence + non-tiebreak regression.
- [Phase 38.7]: Plan 07: PartiesHelper#tiebreak_indicator (D-12) renders localized 'Stechen <Player>' suffix in Spielbericht-PDF when ba_results['TiebreakWinner']∈{1,2}; integer-coerce defense via tw.to_i; auto-escaping preserved (no html_safe); 5 unit tests cover valid/invalid/nil/missing cross-product; Plan 06 table_monitor.tiebreak.* keys preserved.
- [Phase 38.7]: Plan 08: System tests use service-level dispatch + reflex via .allocate stubs, consistent with bk2_scoreboard_test.rb (38.4-07/38.5-06) and game_protocol_reflex_test.rb (Plan 06 Task 4). Avoids the Tournament+TournamentMonitor+TournamentPlan fixture chain while exercising the same evaluate_result→tiebreak_pick_pending?→marker-switch chain production runs. 4 tests, 32 assertions, 0 failures.
- [Phase 38.7]: Plan 09 (Gap-01): preset tiebreak_on_draw threaded carambus.yml → form → controller → GameSetup with key? gate after Game.derive_tiebreak_required; sparse-override semantic preserved (Phase 38.5 D-06); 4 BK-2kombi + 3 BK-2 small_billard buttons carry tiebreak_on_draw: true; both .erb template and gitignored .yml kept in sync per project convention
- [Phase 38.7]: Plan 11 (Gap-03): bk2_kombi_tiebreak_auto_detect! injected as first line of tiebreak_pick_pending? — extend-before-build SKILL applied (one guard, 4 call sites unchanged). 5-condition gate forces Game.data['tiebreak_required']=true on BK-2kombi BK-2-phase ties at goal in 1+1 innings via Game#deep_merge_data! (canonical write path), overriding any pre-baked false. Hard rule of the discipline, NOT operator-configurable.
- [Phase 38.7]: Plan 10 (Gap-02): hidden_field_tag '0' + check_box_tag '1' pattern in detail-form set_params panel — explicit unchecked-submits-false sparse semantics; rides Plan 09's slice + GameSetup override branch (zero controller/service changes)
- [Phase 38.7]: Plan 12 (Gap-04): TournamentMonitor startup-form tiebreak override — operator pick written to Tournament.data['tiebreak_on_draw'] via update_columns (bypasses unrelated organizer presence validation + before_save data-key extraction). Persist gated to :update only because :create is NOT director-gated; operator workflow is create-then-edit. i18n under tournament_monitors.form namespace, disjoint from Plan 10's locations.scoreboard_free_game namespace. Plan 04 resolver UNCHANGED — Plan 12 only writes Level 1.
- [Phase 38.7]: Plan 13 (Gap-05): data-reflex='submit->GameProtocolReflex#confirm_result' relocated from <button> onto <form> in _game_protocol_modal.html.erb + action='javascript:void(0)' defense-in-depth; submit-event observability fixed (browsers fire submit on forms, not buttons). RED→GREEN integration suite (test/integration/tiebreak_modal_form_wiring_test.rb, 4 tests / 20 assertions) locks the contract via Nokogiri parse of ApplicationController.render output. Zero Ruby-layer changes — Plans 09-12 deliverables UNCHANGED. Closes the test gap that allowed the original bug to ship despite GREEN reflex unit + system tests.
- [Phase 38.8]: Plan 01: RED characterization test added — test_evaluate_result_for_training_single-set_no-tiebreak_game_lands_in_final_match_score asserts tm.state == 'final_match_score' for training single-set games. Mirrors phase 38.7 update_columns(state: 'set_over') pattern to reach Branch C directly. Fails RED today (Expected 'final_match_score', Actual 'playing') — pins regression introduced by commit c3dedb69.
- [Phase 38.8]: Plan 02: AASM :start_rematch event added (15 LOC, transition final_match_score → playing, after-callbacks [revert_players, do_play]). Extend-before-build SKILL applied — single new event block, no parallel state machine. Phase 38.7 tiebreak guard preserved verbatim. Plan 01 RED test deliberately remains RED until Plan 03 deletes auto-rematch block. DE+EN i18n keys table_monitor.next_game shipped together to unblock Plan 05 wiring.
- [Phase 38.8]: Plan 03: Both training auto-rematch blocks DELETED from result_recorder.rb (Branch C + final_set_score branch); replaced with @tm.finish_match! if @tm.may_finish_match? mirroring tournament admin_ack_result path. AASM bypass update(state: 'playing') eliminated (0 real call sites). Plan 01 RED test flipped to GREEN. T6 Phase 38.7 test re-anchored under Rule 1 (assertions inverted from assert_includes :revert to assert_empty + assert_equal final_match_score). Phase 38.7 tiebreak guard preserved verbatim (tiebreak_not_pending? grep count UNCHANGED at 3). 24/24 result_recorder tests + 16/16 model tests + 4/4 tiebreak system tests all GREEN.
- [Phase 38.8]: Plan 04: Tournament round-progression cascade extracted from TournamentMonitor::ResultProcessor#report_result into new public method advance_round_after_match_close(table_monitor); wired to TableMonitor AASM :close_match event via after-callback advance_tournament_round_if_present (no-op in training mode). report_result now writes data + finish_match!s but DEFERS the cascade until operator-triggered close_match!. Symmetric to training-mode operator-gate landed by Plans 02/03. Phase 38.7 tiebreak guard preserved verbatim (grep count UNCHANGED at 3); Plan 02 :start_rematch event preserved (count UNCHANGED at 1). 24/24 result_processor_test.rb (was 19, +5 new lock-in tests) + 24/24 result_recorder_test.rb + 16/16 table_monitor_test.rb + 4/4 tiebreak_test.rb (system) all GREEN. Test 4 regex tightened to call-site-aware (Rule 1 plan-prescribed test bug fix — same DOCUMENTARY-comment-noise pattern as Plan 03). Extend-before-build SKILL upheld.
- [Phase 38.8]: Plan 05: TableMonitorReflex#start_rematch + #close_match added (mirroring admin_ack_result/force_next_state pattern verbatim — morph :nothing, find TM, locked_scoreboard guard, suppress_broadcast wrap, save!); _scoreboard.html.erb gains elsif final_match_score? branch with two-arm reflex routing on tournament_monitor.blank? (training -> #start_rematch, tournament -> #close_match), both arms render t('table_monitor.next_game'). Phase 38.7 tiebreak_not_pending? guard preserved verbatim (count UNCHANGED at 3); Plan 02 :start_rematch event + Plan 04 :close_match after-callback preserved (each count UNCHANGED at 1). 48/48 unit tests + 4/4 tiebreak system tests GREEN.
- [Phase 38.8]: Plan 06: 3 AASM unit tests (test/models/table_monitor_test.rb +55 LOC) + 4 system-level operator-gate tests (test/system/final_match_score_operator_gate_test.rb NEW +214 LOC). Service-level dispatch pattern, ActiveSupport::TestCase parent for speed. build_training_tm helper coerces TM to :set_over via update_columns + reload (mirrors result_recorder_test.rb:433/:468) so ResultRecorder.call reaches Branch C. Per-instance @seqno_counter handles Game uniqueness in cross-discipline loop (Rule 3 auto-fix). TableMonitor.find singleton override + ensure-block restore for reflex .allocate dispatch. SC-5 seal asserts test/system/tiebreak_test.rb stays present + ≥4 tests. Phase 38.7 tiebreak guard preserved verbatim (count UNCHANGED at 3); all 6 plans of phase 38.8 now landed; 71 runs / 193 assertions / 0 failures / 0 errors / 2 baseline skips across the combined regression sweep, plus 4/4 tiebreak system tests GREEN.
- [Phase 38.9]: Plan 01: 4th sub-branch added to TableMonitor#end_of_set? inside the existing Plan 38.7-02 D-02 bk_with_nachstoss block — closes BK-2 / BK-2kombi-SP set IMMEDIATELY when Anstoss reached balls_goal in inning >= 2 (Erste-Aufnahme-Gate close-side mirror of follow_up?:1205-1210). Reuses anstoss_role/anstoss_innings/anstoss_at_goal locals — zero recomputation. SKILL extend-before-build honored. Latent defect introduced commit 79328663 closed; no regressions in 21/21 table_monitor_test + 4/4 tiebreak_test + 4/4 final_match_score_operator_gate_test. 19 pre-existing bk2_scoreboard_test failures verified pre-existing at parent commit cfee5962 (stale Bk2::CommitInning + stale BK2-Kombi regexes from Phase 38.5/38.6); deferred to deferred-items.md per scope-boundary rule.

### Roadmap Evolution

- Phase 38.1 inserted after Phase 38: BK2-Kombi minimum viable support (URGENT — 2026-05-02 tournament deadline)
- Phase 38.4 inserted after Phase 38: BK2-Kombi post-dry-run gaps (URGENT) — covers G1 delete, G2 Ballziel, I8, I9 deferred from Phase 38.3
- Phase 38.7 inserted after Phase 38.6: Tiebreak bei Unentschieden — Per-Game-Flag mit Modal-Eingabe (URGENT)

### Pending Todos

_(none — both 2026-04-14 todos resolved by today's quick tasks 260506-hka + 260506-i6h)_

**Two DEFERRED-BLOCKERs from 260506-i6h need a follow-up quick task before 260506-hka can be pushed:**

- **DEFERRED-BLOCKER-1 (production-affecting):** PRG flash payload uses symbol keys but cookie-session JSON serializer stringifies → modal renders empty body in production. Recommended fix: switch `build_verification_failure_payload` (`app/controllers/tournaments_controller.rb:1028-1040`) to use string keys, AND change view access (`app/views/tournaments/tournament_monitor.html.erb:66`) to `@verification_failure["body_text"]`. Add a regression-guard test for the JSON round-trip. Smallest possible scope.
- **DEFERRED-BLOCKER-2 (test-only):** Fixture `tournaments(:local)` has `state: "registration"` which is not in `Tournament` AASM state list (`app/models/tournament.rb:271-281`). Tests 3+4 of 36B-06 (`Confirm` and `in-range` paths) need `start_tournament!` to fire. Fix options: change fixture state to `"new_tournament"` (initial AASM state), OR add `update_columns(state: "new_tournament")` in 36B-06 test setup.

**Recently closed:**

- **Refactor 36B-06 verification gate to PRG redirect** (created 2026-04-14, resolved 2026-05-06 quick-260506-hka commit `0ac7305a`). PRG via `flash[:verification_failure]` + revert of `data: { turbo: false }` workaround. Verifier 7/7 must-haves at code level; 36B-06 system tests skip on fixture-data limits, so E2E browser handshake needs manual run. Todo file moved to `.planning/todos/done/`.
- **Tighten 36B-05 reset confirmation system test skip paths** (created 2026-04-14, resolved 2026-05-06 quick-260506-i6h commits `1c291731` + `12652ae2`). Fixture FK rot fixed at `tournaments(:local)` + selector `.hidden` corrected to root target across all 3 tests + has_css? skip removed + 500-skip→flunk + Stimulus scope assertion. 3/3 green / 0 skips. Todo file moved to `.planning/todos/done/`.
- **Production API disk — `api-server-disk-cleanup`** (created 2026-04-23, resolved 2026-05-05 commit `c007dd20`). Root cause: missing logrotate for `/var/log/carambus*/` scenario-specific nginx log dirs (standard `/etc/logrotate.d/nginx` only covers `/var/log/nginx/`). Deployed `/etc/logrotate.d/carambus` + forced first rotation; reclaimed ~5 GB (disk 82% → 76%).
- **Rematch loses Ballziel — `fix-ballziel-loss-on-swapped-anstoss-rematch`** (created 2026-05-01, resolved 2026-05-05 commit `0b67be03`). Fixed by quick-260503-x3k commit `45f9174c` (`revert_players` now passes `bk2_options` through to `start_game`). Todo file moved to `.planning/todos/done/`.

#### Phase 38.1 carry-forward (post-tournament 2026-05-05)

**Postponed — Review-by 2026-07-05** (deferred at user request 2026-05-05; revisit zusammen wenn die Saison-Pause beginnt oder vor dem nächsten BK-Turnier).

- **TODO A — Foulzähler-Buttons (−1, −2, −6).** Buttons im Scoreboard für Foul-Erfassung (3 Werte: −1, −2, −6). Negative Werte zählen unabhängig vom positiven Score in der Aufnahme. Falls negative zum Gegner übertragen werden: positiver Aufnahme-Score bleibt beim Spieler; Foul-Betrag wird beim Gegner positiv in dessen Aufnahme-Score übernommen. **Offene Fragen beim Aufgreifen** (interaktiv klären): Discipline-Scope (BK-* Family only, oder alle Karambol-Disziplinen mit `allow_negative_scores?`)? Button-Layout (neben Aufnahme-Eingabe oder separates Foul-Panel)? Übertrags-Zeitpunkt (sofort beim Tap oder erst bei Aufnahme-Schluss)? i18n-Labels (kurz "F-1 / F-2 / F-6" oder lang)?

- **TODO B — BK50 / BK100 Neuauflage als Stoß-basiertes Spielmodell.** "BK50" und "BK100" beziehen sich auf **Stöße innerhalb einer Aufnahme** (NICHT balls_goal). Neuer Stoßzähler-UI nötig; Score-Inputs **pro Stoß** aus dem Bereich −7, −6, …, +6, +7. Aktuell aus Quick-Game-Presets in `carambus.yml(.erb)` entfernt (commit 33d3b799). Reaktivierung erfordert eigene Phase (UI + Scoring-Service + ggf. eigene `Bk50::*` / `Bk100::*` Service-Klassen) und ist mit TODO C verschränkt — die `BK2_DISCIPLINE_MAP` muss gleichzeitig umgeordnet werden.

- **TODO C — BK50 / BK100 Code-Cleanup (verzahnt mit TODO B).** Nach dem Quick-Game-Preset-Strip stehen BK50/BK100 noch in: `app/models/discipline.rb:160` (`BK2_DISCIPLINE_MAP`), `app/controllers/table_monitors_controller.rb:11-12, 285-288` (balls_goal-Whitelist + 1-Aufnahme-Regel), `app/views/locations/_quick_game_buttons.html.erb:51` (`bk_family_names`), `app/views/locations/scoreboard_free_game_karambol_new.html.erb` (7 Stellen — bk50/bk100 Family-Choice + `is_bk_fixed_goal`-Branch), `app/views/table_monitors/_player_score_panel.html.erb:74` (Kommentar), `app/models/table_monitor.rb:1173, 1483` (Kommentare), `app/models/table_monitor/score_engine.rb:1330` (Kommentar), `test/integration/bk_param_latent_bugs_test.rb:135-149` (2 D-12-Tests "BK50 single-set" + "BK100 single-set"). Cleanup erst zusammen mit TODO B angehen, weil dann eh die ganze BK-Family-Definition neu gedacht wird (3 statt 5 Disziplinen, evtl. `BK2_DISCIPLINE_MAP` → `BK_FAMILY_MAP`, Stoßzähler-Disziplinen separat).

### Deferred follow-ups

- **T-38.4-16-07 — Residual sync-race for nachstoss_allowed cleanup (Phase 38.4-16):**
  The migration `db/migrate/20260425090000_clear_nachstoss_allowed_for_non_bk2_kombi.rb`
  removes the `nachstoss_allowed` key from BK50/BK100/BK-2/BK-2plus on each server.
  If a stale Plan-11 payload arrives via Version sync AFTER the migration runs on a
  given server (sync race), the flag reappears until the seed re-runs on master AND
  the new flag-less payload propagates. Mitigation in production deployment sequence
  (master seed re-run FIRST, then local-server migrations); residual risk documented
  in migration's `up` method comments. If observed in the wild, re-run the migration
  after the next sync — idempotent. Future hardening: a self-healing periodic check
  that re-applies the cleanup if drift detected.

### Blockers/Concerns

None blocking Phase 38.1 execution. Reconciliation debt above is tracked but not blocking — name-match fallback keeps the tournament working on any server that's missing the `discipline.data` write.

**Open question for discuss-phase (Phase 38):**

- DATA-01 scope boundary — short-term widen only (current assumption, single plan), or short-term widen + medium-term DB-backed `discipline_parameter_ranges` table (would split DATA-01 into 2 plans or justify a Phase 39)?

**Known tech debt carried into next milestone:**

- **`public/docs/` manual-rebuild gap — RESOLVED 2026-05-05** via `config/initializers/docs_auto_rebuild.rb`. Development-only Listen-based watcher on `docs/**/*.md` triggers `bin/rails mkdocs:build` automatically (debounced 2s, background thread, opt-out via `DOCS_AUTO_REBUILD=0`). History: `public/docs/` is git-tracked; previously had to be manually rebuilt after any `docs/**/*.md` edit. G-02 first found and fixed this inline during v7.0 UAT (commit `7cf16114`). Quick `260415-26d` (2026-04-15) tried overcommit pre-commit hook → rolled back (see local `.planning/quick/260415-26d-public-docs-build-hardening-via-overcomm/260415-26d-POSTMORTEM.md`). The initializer-based approach replaces both. Production / CI still requires committing `public/docs/` from a dev machine that has run the rebuild — a future CI guard (GitHub Actions: `mkdocs build` + diff check) remains a defense-in-depth option but is no longer urgent.

### Quick Tasks Completed

See `HISTORY.md` for the chronological ledger of completed quick tasks (with commit hashes). Per-task PLAN.md / SUMMARY.md detail lives locally under `.planning/quick/<id>/` (gitignored as of 2026-05-05) — for the full backstory, `git show <commit-hash>` or `git log --grep=<quick-id>` in the repo.

## Session Continuity

Last session: 2026-05-04T22:26:00.000Z
Stopped at: 2026-05-04 - Completed quick task 260505-0b5: CR-02 sentinel restored narrow-scoped per-TM. Phase 38.7 UAT Test 5 now unblocked — operator can retry tied finals "Nächstes Spiel" without recursion crash.
Resume: Sanity-check Tournament[17416] / TournamentMonitor[50000028] state (savepoints all rolled back; verify current_round + rankings consistency in console), then retry Phase 38.7 UAT Test 5 (TR-A Karambol-Liga tied tiebreak). After Tests 5–10 pass: `/gsd-verify-phase 38.7`, then `/gsd-verify-phase 38.8` and `/gsd-verify-phase 38.9`.
