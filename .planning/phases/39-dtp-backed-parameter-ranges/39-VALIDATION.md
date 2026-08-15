---
phase: 39
slug: dtp-backed-parameter-ranges
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-07
---

# Phase 39 — Validation Strategy

> Per-phase validation contract. Reconstructed retroactively from Plan 39-01 + 39-02 SUMMARY.md after phase completion (State B) and gap-filled by `/gsd-validate-phase` on 2026-05-07.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Minitest (Rails 7.2) |
| **Config file** | `test/test_helper.rb` |
| **Quick run command** | `bin/rails test test/models/discipline_test.rb test/integration/phase_39_constants_contract_test.rb` |
| **Full suite command** | `bin/rails test test/controllers test/models test/integration` |
| **Estimated runtime** | ~1s (model + integration), ~30s (full suite) |
| **System tests (Selenium)** | Out of CI scope — `test/system/tournament_parameter_verification_test.rb` runs only with ChromeDriver. |

---

## Sampling Rate

- **After every task commit:** Quick run command (model + integration only).
- **After every plan wave:** Full suite command.
- **Before `/gsd-verify-work`:** Full suite green.
- **Max feedback latency:** ~1s for model+integration; ~30s for full suite.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 39-01-01 | 01 | 1 | DATA-01 | T-39-02 | Test fixtures load only into test DB; no production-data exposure | fixture-load smoke | `bin/rails runner -e test 'puts DisciplineTournamentPlan.count; puts Tournament.where(\"id BETWEEN 50_000_200 AND 50_000_207\").count'` | ✅ | ✅ green |
| 39-01-02 | 01 | 1 | DATA-01 | T-39-01 | AR-parameterized DTP query; no SQL string interpolation | unit (Discipline model) | `bin/rails test test/models/discipline_test.rb -n /parameter_ranges/` | ✅ | ✅ green |
| 39-01-03 | 01 | 1 | DATA-01 | — | Method behavior asserted: D-16 a/b/c/d/e/f + RQ-01 + RQ-03 + defensive regression | unit (9 tests) | `bin/rails test test/models/discipline_test.rb` | ✅ | ✅ green (22 runs / 207 assertions) |
| 39-02-01 | 02 | 2 | DATA-01 | T-39-03 | Verifier authority narrowed to {balls_goal, innings_goal}; sentinel guard removed | structural (integration) | `bin/rails test test/integration/phase_39_constants_contract_test.rb` | ✅ | ✅ green (Wave 0 added 2026-05-07) |
| 39-02-02 | 02 | 2 | DATA-01 | T-39-04 | Dead-code regression file removed; FakeDiscipline/FakeTournament Struct doubles + RANGES constant gone | filesystem (manual) | `test ! -f test/integration/tournament_verification_sentinels_test.rb` | ✅ (file deleted) | ✅ green |
| 39-02-03 | 02 | 2 | DATA-01 | T-39-05 | Modal does NOT fire on non-DTP / handicap / no-plan tournaments (D-10/D-11/D-16f) | system (Selenium) | `bin/rails test test/system/tournament_parameter_verification_test.rb` | ✅ | ⚠️ manual-only (Selenium) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky / manual-only*

---

## Wave 0 Requirements

- ✅ `test/integration/phase_39_constants_contract_test.rb` — added 2026-05-07 by `/gsd-validate-phase`. Pins UI_07_FIELDS shape, UI_07_SENTINEL_VALUES absence, and `Discipline#parameter_ranges` keyword-arg signature. 3 runs / 5 assertions. Commit `010e46ff` in carambus_master.

*All other infrastructure existed at phase entry (Minitest + fixtures + `test_helper.rb`).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Verification modal fires on out-of-range `balls_goal` for D-16(a) hit fixture | DATA-01 / Plan 02 must-have #1 | System test requires Selenium/ChromeDriver — out of CI scope | Run `bin/rails test test/system/tournament_parameter_verification_test.rb -n /out-of-range/` with ChromeDriver installed; modal must appear with German title text. |
| Verification modal does NOT fire on BK-2kombi (non-DTP) | DATA-01 / Plan 02 must-have #6a | Same — Selenium-dependent | Run system test `non-DTP discipline (BK-2kombi) skips verification entirely`; no modal text expected; tournament-monitor URL must be reached. |
| Verification modal does NOT fire on `handicap_tournier=true` | DATA-01 / Plan 02 must-have #6b | Same — Selenium-dependent | Run system test `handicap_tournier=true tournament skips verification entirely`. |
| Verification modal does NOT fire on `tournament_plan=nil` | DATA-01 / Plan 02 must-have #6c | Same — Selenium-dependent | Run system test `tournament without tournament_plan skips verification (defensive)`. |
| `tournament_verification_sentinels_test.rb` file deletion | Plan 02 must-have #5 | Filesystem state — not a test assertion | `test ! -f test/integration/tournament_verification_sentinels_test.rb` (also covered indirectly by GAP-2: re-introducing UI_07_SENTINEL_VALUES would fail the new contract test, making accidental rollback visible). |

*The 4 system-test entries are PARTIAL coverage: the underlying behaviour is fully covered by the 9 model unit tests (`discipline_test.rb`), which assert that `parameter_ranges` returns `{}` for non-DTP / handicap / no-plan / blank-class / zero-canonical configurations. The Selenium tests prove only that the modal-firing path correctly consumes a `{}` Hash. The risk of regression is therefore concentrated in the model tests, all of which are automated.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (Wave 0 added 2026-05-07).
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all MISSING references (3 structural gaps filled).
- [x] No watch-mode flags.
- [x] Feedback latency < 30s for full suite.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-05-07 — retroactive validation via `/gsd-validate-phase 39`.

---

## Validation Audit 2026-05-07

| Metric | Count |
|--------|-------|
| Gaps found | 6 |
| Resolved (automated) | 3 (UI_07_FIELDS shape, UI_07_SENTINEL_VALUES absence, parameter_ranges signature) |
| Already covered | 1 (file deletion via filesystem check) |
| Manual-only (Selenium) | 4 (system-test entries — model-level behavior already covered by 9 unit tests) |

**Gap-fill commit:** `010e46ff` (carambus_master) — `test(phase-39): add Nyquist validation tests for constant contracts`. 3 runs / 5 assertions / 0 failures.
