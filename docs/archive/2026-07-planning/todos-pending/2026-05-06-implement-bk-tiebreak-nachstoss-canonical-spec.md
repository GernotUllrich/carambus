---
created: 2026-05-06T19:50:00Z
title: Implement BK-Family Tiebreak & Nachstoß Canonical Spec (supersedes Bug-B)
area: BK-* family scoring + tiebreak detection + Nachstoß lifecycle
spec: .planning/specs/2026-05-06-bk-tiebreak-nachstoss.md
estimated_effort: "4-8h Code + Tests + decision-log amendment"
risk: medium (test rewrites + Phase 38.4 decision roll-back)
files:
  - app/models/table_monitor.rb (end_of_set?, follow_up?, new must_be_decided?, new multi_set?, new tiebreak_auto_detect!, narrow bk_with_nachstoss)
  - app/services/table_monitor/result_recorder.rb (replace bk2_kombi_tiebreak_auto_detect! with generalized version, remove trailing-player-wins for BK-* single-set tied)
  - db/seeds/seed_bk2_disciplines.rb (remove nachstoss_allowed for BK-2kombi + multi-set BK-*)
  - db/migrate/<new>_remove_nachstoss_allowed_for_bk2_kombi.rb (data migration to clear flag from existing Discipline rows)
  - test/system/bk2_scoreboard_test.rb (rewrite Nachstoß-related tests)
  - test/system/tiebreak_test.rb (extend cross-discipline coverage)
  - test/services/table_monitor/result_recorder_test.rb (update Plan 11 + Plan 38.4-11 tests)
  - test/integration/bk_param_latent_bugs_test.rb (review D-12 BK-2 fixtures)
  - test/models/table_monitor_test.rb (extend Phase 38.9 tests for multi-set BK-*)
  - .planning/PROJECT.md (decision-log amendment for Phase 38.4 D-13 + Plan 38.4-11/12/13 superseding)
  - .planning/ROADMAP.md (new phase entry)
---

## Problem

Current code at HEAD `4b1bb5b3` diverges from the canonical spec for BK-family tiebreak and Nachstoß behavior. The spec was stated by the BCW user (Gernot Ullrich) on 2026-05-06 during the Phase 38.7/38.8/38.9 UAT closure session and is the authoritative model going forward.

**The full spec lives at `.planning/specs/2026-05-06-bk-tiebreak-nachstoss.md`** — read that first before starting implementation. This todo is the implementation backlog item that points to the spec.

### TL;DR — What the spec says

1. **Tiebreak fires** ⟺ `tied(set-end) ∧ must_be_decided?` where `must_be_decided? ≡ playing_finals? ∨ multi_set?` (BK-2kombi is by-definition multi-set per Spec point 2). Discipline-agnostic on the tiebreak side.
2. **Nachstoß** is family-aware:
   - Karambol family: allowed by default, overridable via existing per-param plumbing
   - Kegel (BK-*) family: NOT allowed by default; **single exception** is single-game (`sets_to_play == 1`) AND Player A reaches `balls_goal` in first inning
   - **BK-2kombi** has NO Nachstoß (contradicts current code, which has D-02 BK-2-Nachstoss-close branch + Plan 38.4-11 `nachstoss_allowed: true` flag).
3. **Single-Set training tied** → **Remis** (no winner). The Phase 38.4 "provisional Nachstoß equal rule: trailing player wins" is **dropped**.

### Concretely diverging from current code

| Where | Current behavior | Spec says |
|-------|------------------|-----------|
| `table_monitor.rb:1514-1532` Phase 38.7-02 D-02 BK-2-Nachstoss-close | BK-2kombi-SP gets Nachstoß-Aufnahme | Remove (BK-2kombi has NO Nachstoß) |
| `result_recorder.rb:382-408` `bk2_kombi_tiebreak_auto_detect!` | Fires only for BK-2kombi-SP tied 1+1 | Generalize to any tied multi-set set-end (rename) |
| `table_monitor.rb:1552-1558` Phase 38.9 4th-branch | A-goal in inning >= 2 → close (assumes Nachstoß-context) | For multi-set BK-*: A-goal in any inning → close. For single-set BK-*: keep `>= 2` to preserve first-inning exception. |
| `db/seeds_bk2_disciplines.rb` `nachstoss_allowed: true` for BK-2kombi/BK-2/BK-2plus/BK50/BK100 | All five flagged true | Remove for BK-2kombi entirely; for plain BK-* only single-game first-inning case (or remove flag and hardcode predicate) |
| `result_recorder.rb` set-result evaluation | BK-* single-set tied → trailing-player-wins | BK-* (and any non-must-decide) single-set tied → Remis (no winner) |

### Reproduction / proof-of-divergence

- **BK2-Kombi UAT 6 scenario (2026-05-06)**: tied 70:70 in BK2-Kombi-SP 1+1 innings opened tiebreak modal. Under new spec, this scenario is unreachable (A's goal in inning 1 closes the set immediately, no Nachstoß for B). New BK-2kombi-tied scenario: both players hit Aufnahmegrenze without reaching goal, equal scores → tiebreak.
- **Plain BK-2 70 single-set tied 70:70 (2026-05-06)**: trailing-player-wins → match ended in `:final_match_score`. Under new spec: Remis, no winner.
- **Plain BK-2 multi-set tied set (current)**: silent trailing-player-wins, no tiebreak modal. Under new spec: tiebreak modal opens (must-decide via multi-set).

## Solution

Run `/gsd-discuss-phase` for a new phase (likely v7.2 milestone or insert as v7.1-closure phase 38.10) to scope the implementation. The discuss-phase should:

1. Read the canonical spec at `.planning/specs/2026-05-06-bk-tiebreak-nachstoss.md`
2. Resolve open questions (none currently — F1+F2 answered in spec doc)
3. Decide: v7.2 new milestone vs. 38.10 closure of v7.1
4. Lay out plans per the spec's Section 9 sketch
5. Identify Phase 38.4 decisions to roll back in PROJECT.md decision log
6. Plan test rewrite scope (Phase 38.4-07 system tests are most affected)

## Closing Note: Bug-B Resolution

This todo OBSOLETES the earlier "Bug-B" question raised during the same UAT session: should plain BK-2 training-mode tiebreak be `strict` / `per-discipline hard rule` / `operator-wahl`? The canonical spec resolves it directly with a fourth (cleaner) answer: **structural** — tiebreak depends on `must_be_decided?` (a property of the match context, not of the discipline or operator preference).

Plain BK-2 training-mode tiebreak fires automatically when:
- The match is multi-set (then any tied set-end triggers tiebreak), OR
- It's a tournament finals game

Single-set BK-* training-mode tied → Remis, no operator decision needed (and previously buried "trailing-player-wins" provisional rule is dropped).

## Touches & Phase History

- **Phase 38.1**: BK-2kombi minimum viable support — built initial Nachstoß logic that this spec partly reverses
- **Phase 38.4**: D-13 + Plans 11/12/13 — `nachstoss_allowed` flag + Nachstoß-deferred-close branch — **superseded by this spec**
- **Phase 38.5**: BkParamResolver — orthogonal (allow_negative_score_input, negative_credits_opponent), not affected
- **Phase 38.7**: Plan 11 (Gap-03) — auto-detect generalizes; Plan 13 (form wiring) preserved
- **Phase 38.8**: Operator-gate — orthogonal, preserved
- **Phase 38.9**: 4th-branch — generalizes for multi-set BK-*, preserves single-set first-inning exception

After implementation, this todo moves to `.planning/todos/done/` with closing commit hash; spec doc gets `status: implemented` annotation.
