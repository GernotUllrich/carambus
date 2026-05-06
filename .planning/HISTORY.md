# Project History

Chronological record of completed work — quick tasks and phases. New entries appended at the bottom of each section.

For active focus and pending decisions, see `STATE.md`. For the milestone-level overview, see `MILESTONES.md`. For per-task detail, see `git log <commit-hash>` or `git show <commit-hash>` — the per-task PLAN.md/SUMMARY.md artifacts live locally under `.planning/quick/` and `.planning/phases/` (gitignored as of 2026-05-05) but the commit messages carry the load-bearing description.

---

## Quick Tasks (chronological)

| ID | Date | Description | Commit |
|---|---|---|---|
| 260414-qb8 | 2026-04-14 | Fix `PG::UndefinedColumn result_a` crash in tournaments show / finalize_modus views | `b787da5e` |
| 260415-26d | 2026-04-15 | `public/docs/` build hardening via overcommit pre-commit hook — **ROLLED BACK** (hook approach failed, see prior POSTMORTEM at 912bf72a → rollback) | `912bf72a` → rollback |
| 260501-pud | 2026-05-01 | Add `Carambus.config.training_mode_show_fullname` flag (default false) — when true, training mode shows full player names in scoreboard / warmup / shootout for non-guest registered players | `a5c90fa7` |
| 260501-sbz | 2026-05-01 | Fix BK-2kombi SP-phase inning counter display (replaces "Aufnahmen-übrig" with karambol-style "N of M") | `de1f0c0a` |
| 260501-uxo | 2026-05-01 | BK-2kombi: enforce SP-phase inning limit (default 5) and make it configurable from `carambus.yml` | `b3fcfeca` |
| 260501-vly | 2026-05-01 | BK-2kombi tiebreak fixes: credit set point on tiebreak win + Detail Page tiebreak default + unified inning display | `7cf939a9` |
| 260501-wfv | 2026-05-01 | BK-2kombi shootout `first_set_mode` pick was ignored: stale `bk2_state` survived the second `initialize_bk2_state!` call | `5b5dc22d` |
| 260501-x07 | 2026-05-01 | BK-2kombi: clear stale `tiebreak_winner` at set boundary so set 3 re-evaluates tiebreak independently of set 1 | `41081785` |
| 260502-0ok | 2026-05-02 | Score-line: mark set winner with asterisk in per-player innings list (S1: 70* vs S1: 50) | `d978e302` |
| 260503-hay | 2026-05-03 | BK-2plus phase / BK-2kombi DZ-Phase 5-Aufnahmen Abbruch — exclude DZ-phase from legacy `innings_goal` close branch | `12276841` |
| 260503-mor | 2026-05-03 | `GameProtocolReflex#panel_state` race — guard `open_protocol` / `switch_to_edit_mode` / `switch_to_view_mode` against downgrading "protocol_final" on stale-DOM clicks | `734a2b95` |
| 260503-x3k | 2026-05-03 | BK rematch preserves `bk2_options.balls_goal` — pass-through in `revert_players` options hash so BK-2 / BK-2plus standalone show correct Ballziel after auto-rematch | `45f9174c` |
| 260505-0b5 | 2026-05-04 | CR-02 sentinel restore — narrow-scoped per-TM (`Thread.current[:_advancing_round_for_tm] == self.id`) re-entry guard in `TableMonitor#advance_tournament_round_if_present`. Closes tournament-finals `SystemStackError` on tied 10:10 finals "Nächstes Spiel" (Tournament[17416] live incident). Unblocks Phase 38.7 UAT Test 5. | `1709938e` |
| 260505-auq | 2026-05-05 | `TournamentMonitor#playing_finals?` forces `tiebreak_required=true` at decision time — single private helper on TableMonitor + 2 call sites replaces Phase 38.7-09..13 executor_params plumbing strategy with a state-driven invariant | `94c488df` |
| 260505-fbb | 2026-05-05 | Remove dead `tiebreak_on_draw` config plumbing (resolver + `GameSetup` bake block + controller helpers + form checkbox + scoreboard toggle + i18n + dead tests) — −638 LOC across 15 files; `playing_finals?` override is canonical path | `de0e7340` |
| 260506-hka | 2026-05-06 | Refactor `TournamentsController#start` verification gate from in-place render to PRG redirect — `flash[:verification_failure]` carries payload across the 302; revert prior `data: { turbo: false }` workaround on start_tournament form (commit 8a948c93). Form params don't need replay (every field reads from `@tournament.<attr>` with live StimulusReflex change-handlers). Closes 2026-04-14 todo. **Status: Needs Review** — verifier 7/7 must-haves at code level, but 36B-06 system tests skip on fixture-data limits, so E2E browser handshake (POST → 302 → modal auto-open → confirm → re-POST) needs manual run. | `0ac7305a` |
| 260506-i6h | 2026-05-06 | Fix `tournaments(:local)` fixture FK rot (explicit `organizer_id`/`organizer_type`/`season_id`/`discipline_id`/`tournament_plan_id` columns replacing broken fixture-relation syntax) + tighten 36B-05 reset confirmation system test (broken `[data-controller='confirmation-modal'].hidden` selector → `[data-confirmation-modal-target='root'].hidden` across all 3 tests, remove `has_css?` skip, replace 500-skip with `flunk`, add failing-first Stimulus scope assertion). 36B-05 now 3/3 green / 0 skips. Closes 2026-04-14 `tighten-36b-05` todo. **Status: human_needed** — un-skipping 36B-06 surfaced 2 real bugs (DEFERRED-BLOCKER-1: PRG flash payload uses symbol keys but JSON serializer stringifies — affects production cookie store; DEFERRED-BLOCKER-2: fixture `state: "registration"` not in Tournament AASM state list). | `1c291731` + `12652ae2` |
| 260506-k3t | 2026-05-06 | Close both DEFERRED-BLOCKERs from 260506-i6h: (Bug 1) `build_verification_failure_payload` returns string keys + view reads string keys; new integration regression test JSON-round-trips the payload (2/2 green). (Bug 2) `tournaments(:local).state` → `"tournament_mode_defined"` (the AASM-correct pre-`start_tournament!` state per `tournament.rb:290-292`). **Rule 1 latent-bug fix:** AASM event `:start_tournament!` has a literal bang in the symbol name — auto-generated method does in-memory transition only, no persist. Added explicit `@tournament.save` after the AASM call (verified via Rails runner probes + SQL log). PRG refactor commit `0ac7305a` is now correct end-to-end in production. **Status: human_needed** — 36B-06 system tests 3+4 still fail at the assertion layer due to test-thread / Puma-server-thread Postgres connection isolation (controller's UPDATE visible in SQL log but not through test thread's connection). Production code is correct; the gap is test infrastructure (`application_system_test_case.rb` lacks shared-connection setup) and applies to all system tests asserting controller-side state changes. | `2fcce9d1` + `d6335bff` + `6f8a6f52` + `e362f8a9` |
| 260506-lii | 2026-05-06 | **HALTED — zero net change.** Attempted to fix 36B-06 connection-isolation by rewriting DB-state assertions to URL/DOM assertions. Plan iteration 1 passed plan-check; executor halted Task 1 because URL assertion failed (browser ended at `/`, not `/tournament_monitors/8`). Layer 1 root cause: `users(:admin)` fixture (no `role:`) is bounced by `TournamentMonitorsController#ensure_tournament_director` to `root_path`. Plan iteration 2 added a fixture-user swap (`users(:admin)` → `users(:system_admin)`) and passed plan-check; executor halted again because the swap regressed tests from 2 pass / 2 fail → 0 pass / 4 skip. **Layer 3 root cause** (newly discovered): `app/views/application/_left_nav.html.erb:156` calls `migration_cc_region_path(Region[1])` — `Region[1]` is nil in test fixtures (`:nbv` is at id 50_000_001, not 1). Under `:system_admin` the admin nav renders and crashes with `UrlGenerationError` → 500 → start_tournament form never reaches the test → skip. Layers 1+3 are coupled: any fixture user satisfying `ensure_tournament_director` also activates the broken admin nav. Working tree reverted clean to `8914f567`. Three-layer diagnosis recorded in SUMMARY for the next attempt. | _(none — halted)_ |
| 260506-me5 | 2026-05-06 | **Partial success: 3/4.** Local/global-aware fix path (informed by user's architectural framing): added `role: club_admin` to test/fixtures/users.yml `:admin` block (the realistic bcw operator role; satisfies `ensure_tournament_director` WITHOUT activating the system_admin-only admin nav, so Layer 3 stays dormant) + URL/DOM assertion rewrite in 36B-06 tests 3+4. Result: 36B-06 went 4 runs / 2 fails → 4 runs / 1 fail. Tests 1, 2, 3 now GREEN. Test 4 still fails for **Layer 4** (NEW): the in-range test only sets `balls_goal` to a safe value, but the form ALSO submits `sets_to_play=0` and `sets_to_win=0` — both out of `UI_07_SHARED_RANGES` (1..7 / 1..4). The verifier triggers the modal even when balls_goal is in range. This is a real production-edge bug for single-set tournaments (the verifier should accept 0 for these fields; pre-existing latent bug masked by earlier connection-isolation theory). 36B-05 stays 3/3 green; uploads_controller stays 6/6; integration suite 12/12; no system-test smoke regression. **Status: human_needed** (Test 4 + Layer 3 admin-nav both pending separate quick tasks). | `8f0b02a0` + `d55120c2` |

---

## Phases — milestone v7.1 (UX Polish & i18n Debt)

| Phase | Name | Status |
|---|---|---|
| 38 | UX Polish & i18n Debt | complete |
| 38.1 | BK2-Kombi Minimum Viable Support | complete (closed retroactively 2026-05-05; UAT covered by real Grand Prix 2026-05-02 + club-day test) |
| 38.2 | BK2-Kombi Scoreboard UX Realignment | complete |
| 38.3 | BK2-Kombi Dry-Run Corrections | complete |
| 38.4 | BK2-Kombi Post-Dry-Run Gaps | complete |
| 38.5 | BK-Param Hierarchy / Multiset Config | complete |
| 38.6 | Discipline Master-Data Cleanup | complete |
| 38.7 | Tiebreak bei Unentschieden — per-game flag + modal | complete |
| 38.8 | "Endergebnis erfasst" state restore + operator gate | complete |
| 38.9 | BK-2 end-of-set Anstoß-at-goal — close set immediately | complete (verified 2026-05-01: 6/6 must-haves + 3/3 human UAT pass; Test-3 observation captured as Backlog 999.1) |

**Backlog (not yet planned):**

| Phase | Name |
|---|---|
| 999.1 | "Endergebnis erfasst" winner label per set / result on score panel |

**Retired backlog items:**

- **999.2 — Panel summary vs panel editor intermittent display** — retired 2026-05-05. Presumed resolved by Quick `260503-mor` (commit `734a2b95`) `GameProtocolReflex panel_state race — guard open_protocol / switch_to_edit_mode / switch_to_view_mode against downgrading "protocol_final" on stale-DOM clicks`. The reported symptom (old Panel Summary instead of Panel Editor) matches the race-fix surface exactly; not observed in the ~2 days of operation since the fix landed. Reopen as a new backlog item if it ever resurfaces.

---

## Past Milestones

See `MILESTONES.md` for the milestone-level overview (v1.0 … v7.0). Per-milestone detail (REQUIREMENTS / ROADMAP / phase artifacts) is no longer tracked in the repo as of the 2026-05-05 cleanup — those files remain locally under `.planning/milestones/` for ad-hoc reference and live in git history up to the cleanup commit if you ever need to retrieve them.

---

## Conventions for new entries

- **Quick tasks:** add a row to the table with the GSD-generated quick-id, ISO date, one-sentence description, and the GREEN-fix commit hash (or `_pending_` if a follow-up is required).
- **Phases:** update the phase-status table once a phase reaches `complete` or `verifying`. The phase commit range lives in git log (search `phase-{N}` in commit messages).
- **Backlog → active:** when a 999.x backlog item is promoted to a real phase number, move the row from Backlog to Phases and renumber per `/gsd-add-phase`.
