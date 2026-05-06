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
