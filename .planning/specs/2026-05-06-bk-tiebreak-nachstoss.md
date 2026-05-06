---
title: Carambus BK-Family Tiebreak & Nachstoß — Canonical Spec
status: authoritative
authored_by: Gernot Ullrich (BCW)
authored_at: 2026-05-06
session_context: Phase 38.7/38.8/38.9 human-UAT closure (commit 4b1bb5b3)
supersedes:
  - "Phase 38.4 D-13: nachstoss_allowed=true für BK-2kombi"
  - "Phase 38.4-11: BK-2kombi Nachstoß-deferred-close branch"
  - "Phase 38.4 'provisional Nachstoß equal rule: trailing player wins'"
  - "Phase 38.7 Plan 11 (Gap-03): BK-2kombi-only auto-detect (gets generalized)"
  - "Phase 38.7-02 D-02 BK-2-Nachstoss-close branch (table_monitor.rb:1514-1532)"
related_open_questions: []
---

# Carambus BK-Family Tiebreak & Nachstoß — Canonical Spec

This document is the **authoritative spec** for tiebreak detection and Nachstoß-Aufnahme rules across all Carambus disciplines. Stated by the BCW user (Gernot Ullrich) on 2026-05-06 during the Phase 38.7/38.8/38.9 UAT closure session as the canonical model that should drive all future code in this area. Resolves the open "Bug-B" spec question raised in the same session.

The spec is intentionally **discipline-agnostic on the tiebreak side** and **discipline-family-aware on the Nachstoß side**.

## 1. Spec — User Statement (verbatim, German)

1. Ein Tiebreak wird genau dann gespielt, wenn Gleichstand bei Spielende erreicht wird und das Spiel entschieden werden muss.
2. Ein Spiel muss entschieden werden, wenn es im Turnier ein Spiel in der Finalrunde ist, oder wenn es Teil eines Mehrsatzspieles ist (BK-2kombi ist per definition ein solches).
3. Nachstoß kann gewährt werden, wenn der Spieler A das Ballziel erreicht hat.
4. Die Möglichkeit eines Nachstoßes ist von verschiedenen Bedingungen abhängig:
   - Bei Karambol Disziplinen ist in der Regel ein Nachstoß erlaubt. Wenn nicht, dann kann das über die Parameter auf verschiedenen Ebenen explizit überschrieben werden.
   - Bei Kegel Disziplinen gibt es in der Regel keinen Nachstoß. Ausnahme: In einem Einzelspiel erreicht der Spieler A in der ersten Aufnahme das Ballziel.
   - Entgegen der gegenwärtigen Implementierung gibt es auch beim BK-2kombi KEINEN Nachstoß.

## 2. Clarifications (Q&A 2026-05-06)

**F1 — Single-Set training tied (no must-decide), what happens?**
→ **(a) Remis** — neither player wins. Both score 0 match-points (or whatever the no-winner outcome is in the existing data model). The "trailing-player-wins provisional rule" from Phase 38.4 is **dropped**.

**F2 — BK-2kombi end-of-set per phase:**

| BK-2kombi Phase | End condition | Nachstoß | Aufnahmen-Limit |
|------------------|---------------|----------|------------------|
| **DZ-Phase (BK-2plus)** | balls_goal reached by either player | **NO** | NO |
| **SP-Phase (BK-2)** | balls_goal reached by either player, **OR** Aufnahmegrenze (typically 5 or 7) reached by Player B | **NO** | YES (per `bk2_options.serienspiel_max_innings_per_set`) |

If SP-phase ends tied (both reach goal in same inning, or both at limit with equal score) → tiebreak fires (BK-2kombi is multi-set → must_be_decided?).

## 3. Logical Formulation

```
must_be_decided?(table_monitor)
  ≡  playing_finals?(tournament)            -- Tournament finals path
     ∨  multi_set?(match)                    -- Multi-set match path

multi_set?(match)
  ≡  data["sets_to_play"].to_i > 1
     ∨  data["free_game_form"] == "bk2_kombi"   -- explicit "by definition multi-set"

tiebreak_fires?(set_end)
  ≡  tied(set_end)  ∧  must_be_decided?(set_end.table_monitor)

tied(set_end)
  ≡  set_end.playera.result == set_end.playerb.result   -- inning-based
     ∨  (simple_set_game? ∧ last_set.Ergebnis1 == last_set.Ergebnis2)   -- simple-set
```

## 4. Nachstoß Rules

| Family | Default | Override | Single-Game First-Inning Exception |
|--------|---------|----------|-------------------------------------|
| **Karambol-Disziplinen** | **Allowed** | Per-param at multiple levels (Discipline / Tournament / TournamentPlan / TournamentMonitor / Preset / detail-form / TableMonitor) | (N/A — already default-allowed) |
| **Kegel (BK-*)** | **NOT allowed** | (none) | **YES** — `sets_to_play == 1 ∧ player_a_reached_goal_in_inning_1` → Nachstoß for Player B |
| **BK-2kombi** | **NOT allowed** | (none) | **NO** (per-definition multi-set, exception predicate `sets_to_play == 1` is false by construction) |

## 5. End-of-Set / End-of-Match Per Discipline

| Discipline | Set-Modus | Set ends when... | Nachstoß |
|------------|-----------|------------------|----------|
| **Karambol** (any) | Any | discipline-specific end-condition (balls_goal, innings_goal) | Per Karambol family default-allowed; overridable |
| **BK-2 / BK-2plus / BK50 / BK100** | **Single-Set** | balls_goal reached by either player | Only via single-game first-inning exception |
| **BK-2 / BK-2plus / BK50 / BK100** | **Multi-Set** | balls_goal reached by either player | **NEVER** — set closes immediately on first goal-reach by either player |
| **BK-2kombi DZ-Phase** | (always multi-set) | balls_goal reached by either player | NEVER (no inning limit) |
| **BK-2kombi SP-Phase** | (always multi-set) | balls_goal reached by either player, OR Aufnahmegrenze (`bk2_options.serienspiel_max_innings_per_set`) reached by Player B | NEVER |

Tied-at-end behavior:
- If `must_be_decided?` → tiebreak modal opens; operator picks winner; set closes via Phase 38.7 Plan 05 path (`tiebreak_pending_block?` AASM guard + `confirm_result` reflex).
- If `¬must_be_decided?` → match ends as **Remis** (no winner declared, both 0 match-points).

## 6. Behavioral Implications vs. Current Code (HEAD 4b1bb5b3)

### 6.1 Code that REMAINS aligned

- `playing_finals_force_tiebreak_required!` (`table_monitor.rb:1758`) — fires on `tournament_monitor.playing_finals?`, aligns with Spec point 2 (finals branch).
- `tiebreak_pending_block?` AASM guard for `:acknowledge_result` (`table_monitor.rb:1716`) — preserves the modal-pending semantic.
- Karambol Nachstoß default-allowed via `allow_follow_up` config — aligns with Spec point 4 (Karambol family).
- Phase 38.8 operator-gate (`final_match_score` state + "Nächstes Spiel" button) — orthogonal to tiebreak/Nachstoß; preserved.

### 6.2 Code that DIVERGES (must change)

| What | Where | Spec says | Action |
|------|-------|-----------|--------|
| BK-2kombi-SP Nachstoß-Aufnahme close branch | `table_monitor.rb:1514-1532` (Phase 38.7-02 D-02) | BK-2kombi has NO Nachstoß | **Remove** |
| `nachstoss_allowed: true` on BK-2kombi Discipline.data | `db/seeds/seed_bk2_disciplines.rb` (Plan 38.4-11) + DB Discipline rows | BK-2kombi NEVER Nachstoß | **Remove flag, write migration** |
| `nachstoss_allowed: true` on BK-2 / BK-2plus / BK50 / BK100 Discipline.data | same | Multi-set: NEVER. Single-set: only via first-inning exception | **Remove flag for non-single-game cases**, OR delete entirely and hardcode the exception predicate |
| Plan 11 BK-2kombi-only Tiebreak-Auto-Detect | `result_recorder.rb:382-408` | Tiebreak generalizes to any tied multi-set set-end (or finals) | **Generalize**: rename to `tiebreak_auto_detect!`, replace 5-condition gate with `tied(set_end) ∧ must_be_decided?` |
| Plain BK-2 / BK-2plus Single-Set tied trailing-player-wins ("provisional" rule per Phase 38.4) | `result_recorder.rb` set-result evaluation | Single-set training tied → Remis | **Remove rule**, fall through to no-winner-declared |
| Plain BK-2 / BK-2plus / BK-2kombi Multi-Set Nachstoß-related branches | `table_monitor.rb`, `result_recorder.rb`, etc. | Multi-set BK-* → no Nachstoß ever, set closes immediately on first goal-reach | **Remove Nachstoß logic for multi-set BK-***; the close happens via the existing legacy karambol-balls_goal branch (`table_monitor.rb:1600-1604`) which already returns true at first goal-reach |
| Phase 38.9 4th-Branch (`anstoss_at_goal && anstoss_innings >= 2`) | `table_monitor.rb:1552-1558` | BK-* multi-set: A-goal in any inning → close. Single-set first-inning exception preserved. | **Generalize** — for multi-set BK-*: close on `anstoss_at_goal` regardless of inning. For single-set BK-*: keep `anstoss_innings >= 2` (so first-inning exception still triggers Nachstoß). |
| `bk_with_nachstoss` predicate covering bk_2 + bk2_kombi-SP unconditionally | `table_monitor.rb:1514-1515` | Only single-set BK-* first-inning case has Nachstoß | **Narrow** to: `(free_game_form ∈ BK_FAMILY) ∧ sets_to_play == 1 ∧ anstoss_innings == 1` |

### 6.3 New code needed

- **`TableMonitor#must_be_decided?`** predicate encapsulating `playing_finals? ∨ multi_set?`. Used by both the new `tiebreak_auto_detect!` and any future code reasoning about must-decide semantics.
- **`TableMonitor#multi_set?`** predicate (or extend an existing helper) — `data["sets_to_play"].to_i > 1 ∨ data["free_game_form"] == "bk2_kombi"`. Note the BK-2kombi clause is the explicit "by-definition multi-set" carve-out from Spec point 2.
- **Generalized `tiebreak_auto_detect!`** (replaces `bk2_kombi_tiebreak_auto_detect!`) — fires on `tied(set_end) ∧ must_be_decided?`, idempotent, persists `Game.data["tiebreak_required"] = true`.
- **BK-* single-game-first-inning Nachstoß predicate** — `bk_family_single_game_first_inning_nachstoss?(tm)` returning true iff `bk_family? ∧ sets_to_play == 1 ∧ playera.innings == 1 ∧ playera_at_goal`. Used in `follow_up?` and the close-side mirror.

## 7. Test Coverage Implications

### 7.1 Tests that become obsolete or invert

- `test/system/bk2_scoreboard_test.rb` (35 methods, Phase 38.4-07): many tests asserting BK-2kombi-Nachstoß behavior must invert ("set closes on Player A goal-reach without Player B Nachstoß").
- `test/integration/bk_param_latent_bugs_test.rb` (Phase 38.5): re-evaluate; some D-12 BK-2 latent-bug fixtures may need refresh.
- `test/services/table_monitor/result_recorder_test.rb` Phase 38.7 Plan 11 / Phase 38.4-11 tests: Nachstoß-deferred-close tests become obsolete; replace with "first-goal-reach immediate close" tests.

### 7.2 Tests that must extend coverage

- `test/system/tiebreak_test.rb` (Phase 38.7): add cross-discipline tied-multi-set scenarios — Karambol-Multi-Set, BK-2-Multi-Set, BK-2kombi-DZ-tied, BK-2kombi-SP-tied-via-inning-limit. Each opens the tiebreak modal.
- `test/models/table_monitor_test.rb` Phase-38.9 tests: extend with multi-set BK-* "first-goal-reach in inning 1 also closes" (the single-set exception goes away in multi-set).

### 7.3 Tests that remain valid

- `test/system/final_match_score_operator_gate_test.rb` (Phase 38.8): orthogonal to tiebreak/Nachstoß, all 4 tests preserved.
- `test/integration/tiebreak_modal_form_wiring_test.rb` (Phase 38.7 Plan 13 G1-G4): orthogonal to spec; locks the form-wiring contract.
- `test/system/tiebreak_test.rb` existing 4 tests: still valid for the BK-2kombi-SP-tied-via-Plan-11 path **after the auto-detect generalizes** to all multi-set tied set-ends (the existing tests will now run via the generalized predicate).

## 8. Risks & Migration Considerations

### 8.1 Production data

The 2026-05-02 BCW BK-2 Grand Prix ran on the OLD model (BK-2kombi WITH Nachstoß). Game records from that tournament:
- ID range: production-side, id < 50_000_000
- Risk of replay/regression: **none** — completed games don't re-evaluate end-of-set logic. The new code only affects new matches.
- Risk of historical-record interpretation: **low** — `ba_results` and final scores are persisted; no live re-derivation.

No data migration required. New deployment = new spec; old games stay frozen with their original results.

### 8.2 Phase 38.4 Decision Roll-back

PROJECT.md Decision Log entries for Phase 38.4 D-13 / Plans 38.4-11/12/13 must be amended with a "Superseded by 2026-05-06 canonical spec" note pointing to this file. The implementation phase for this spec must add this amendment to its SUMMARY.

### 8.3 Tournament-Plan executor_params plumbing

Quick-260505-fbb's commit message noted the `g{N}` executor_param plumbing was already broken before being removed. Under the new spec, **no per-game tiebreak_on_draw configuration is needed** (the rule is structural: must-decide? → tiebreak on tie). The dead plumbing stays out. If a future requirement emerges to override the must-decide rule for specific plans, that's a separate spec extension.

### 8.4 BK-2kombi UAT 6 scenario

UAT 6 (Phase 38.9) was passed 2026-05-06 with BK2-Kombi best-of-3 SP-first, tied 70:70 in 1+1 innings → tiebreak modal opened. Under the new spec, **this scenario is no longer reachable** because A's goal in inning 1 of SP-phase will close the set immediately (no Nachstoß). The tied case in BK-2kombi-SP becomes reachable only via the inning-limit (`bk2_sp_max_innings`): both players complete N innings, neither reaches goal, equal scores → tied → tiebreak. The implementation phase must update the UAT script accordingly.

## 9. Implementation Plan Sketch

To be refined during `/gsd-discuss-phase` for the new phase. Likely structure:

1. **Plan: New canonical predicates** — `must_be_decided?` + `multi_set?` on TableMonitor with unit tests
2. **Plan: Generalized `tiebreak_auto_detect!`** — replaces Plan 11; tests for cross-discipline tied-multi-set scenarios
3. **Plan: BK-2kombi Nachstoß removal** — delete D-02 branch, update `nachstoss_allowed` flag handling, update `bk_with_nachstoss` predicate scope
4. **Plan: BK-* Multi-Set Nachstoß removal** — generalize Phase 38.9 4th-branch to inning >= 1 in multi-set, preserve inning >= 2 in single-set with first-inning Nachstoß exception
5. **Plan: Trailing-player-wins removal for BK-* Single-Set tied** — replace with Remis path
6. **Plan: Discipline.data flag cleanup** — migration to remove `nachstoss_allowed` from disciplines where the new spec says no Nachstoß (or remove flag entirely if predicate-based)
7. **Plan: Test rewrites** — Phase 38.4-07 + Phase 38.5 + Phase 38.7 Plan 11 tests update; new cross-discipline tiebreak coverage
8. **Plan: PROJECT.md decision-log amendment** + ROADMAP.md update + this spec file marked `status: implemented`
9. **Plan: UAT** — re-run TR-B / 38.9-Tests / Cross-discipline tiebreak with new behavior

Phase scope: estimated 4-8h Code + Tests; risk-medium due to test rewrites and decision roll-back.

## 10. Status

- **2026-05-06**: Spec authored from user directive during UAT closure session. Status: **authoritative**. Implementation pending.
- **Implementation**: see backlog todo `.planning/todos/pending/2026-05-06-implement-bk-tiebreak-nachstoss-canonical-spec.md`.

This spec supersedes ad-hoc decisions in Phase 38.4 / 38.7 Plan 11 / 38.9 4th-branch where they diverge. It does NOT supersede the Phase 38.8 operator-gate work (orthogonal) or Phase 38.7 Plan 13 form-wiring work (orthogonal).

---

*Authored: 2026-05-06T19:50:00Z*
*Session context: Phase 38.7/38.8/38.9 human-UAT closure (master @ commit 4b1bb5b3, 11/11 UAT PASS).*
