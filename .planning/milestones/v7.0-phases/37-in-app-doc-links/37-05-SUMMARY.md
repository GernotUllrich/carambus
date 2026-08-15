---
phase: 37-in-app-doc-links
plan: 05
subsystem: tests
tags: [test, minitest, helper, controller, integration, docs, mkdocs, link, locale, anchor, link-01, link-02, link-04]

# Dependency graph
requires:
  - 37-01 (mkdocs_link + mkdocs_url helpers + tournaments.docs.* i18n keys)
  - 37-02 (stable {#seeding-list} / {#participants} / {#mode-selection} / {#start-parameters} anchors)
  - 37-03 (wizard partial + inline steps rendering mkdocs_link calls)
  - 37-04 (form-help mkdocs_link in 4 tournament views)
provides:
  - Minitest lock-in coverage for mkdocs_url / mkdocs_link helper contract (LINK-01)
  - Controller integration test asserting wizard doc links render in DE + EN locales (LINK-02, LINK-04)
  - Phase-level verification matrix for LINK-01..LINK-04
affects:
  - Phase 37 close-out — all 4 LINK requirements validated and marked complete in REQUIREMENTS.md

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ActionView::TestCase for helper unit coverage
    - ActionDispatch::IntegrationTest with FK-repair setup for render-time regression coverage
    - club_admin fixture as the minimum-viable tournament_director? without triggering sidebar Region[1] crash
key-files:
  created:
    - test/helpers/application_helper_test.rb
    - test/controllers/tournament_doc_links_test.rb
    - .planning/phases/37-in-app-doc-links/37-05-SUMMARY.md
  modified:
    - .planning/REQUIREMENTS.md
decisions:
  - Controller integration test chosen over Capybara system test (plan-permitted fallback). No chromedriver installed locally; the assertions are fully observable in rendered ERB response body; test determinism is higher and runtime is ~0.4s vs multi-second Selenium boot.
  - club_admin fixture chosen over system_admin for the integration test setup — system_admin triggers _left_nav.html.erb:141 ClubCloud sidebar render which crashes on `migration_cc_region_path(Region[1])` when Region[1] is nil in the test DB.
  - LINK-01 grep check from plan ('text ||= path.split' anywhere in application_helper.rb) is a known false positive — it matches docs_page_link (explicitly out of scope per Plan 37-01 summary). The substantive check (`awk '/def mkdocs_link/,/^  end/' | grep -c humanize` returns 0) passes.
requirements-completed:
  - LINK-01
  - LINK-02  (already marked by 37-03; re-validated end-to-end here)
  - LINK-03  (already marked by 37-04; re-validated via grep sweep here)
  - LINK-04  (already marked by 37-03; re-validated end-to-end here)

# Metrics
metrics:
  duration_seconds: 440
  completed: 2026-04-14
  tasks: 3
  commits: 4
---

# Phase 37 Plan 05: Test Lock-In + Phase Verification Sweep Summary

**Locked in Plans 37-01..37-04 with automated tests: 13 Minitest assertions for `mkdocs_link` / `mkdocs_url` + 2-test controller integration test asserting DE and EN wizard doc-link rendering. Ran phase-level verification sweep confirming all 4 LINK-0X requirements are met; LINK-01 marked complete in REQUIREMENTS.md.**

## Performance

- **Duration:** ~7 minutes
- **Started:** 2026-04-14T21:03:14Z
- **Completed:** 2026-04-14T21:10:33Z
- **Tasks:** 3 (Task 1 helper test, Task 2 integration test, Task 3 phase sweep)
- **Commits:** 4 (3 task commits + 1 REQUIREMENTS update)

## Accomplishments

- **Task 1:** `test/helpers/application_helper_test.rb` created with 13 test cases / 27 assertions covering every branch of `mkdocs_url` / `mkdocs_link`:
  - DE locale (no prefix) vs EN locale (/docs/en/ prefix)
  - `I18n.locale` fallback when locale argument is nil (tested inside `I18n.with_locale` wrappers)
  - Anchor kwarg appending (present, nil, empty string)
  - Index-file trailing-slash suppression (`"index"` and `"managers/index"` × both locales)
  - ArgumentError guards for nil text and blank/whitespace-only text
  - Rendered `<a>` tag carries `target="_blank"` + `rel="noopener"` (D-05)
  - Rendered href includes anchor fragment end-to-end

- **Task 2:** `test/controllers/tournament_doc_links_test.rb` created with 2 test cases / 14 assertions covering end-to-end rendering of wizard doc links on the `TournamentsController#show` page:
  - DE locale — asserts `/docs/managers/tournament-management/` appears in response body with optional deep-link anchor, and carries `target="_blank"` + `rel="noopener"`
  - EN locale — asserts `/docs/en/managers/tournament-management/` analogue
  - Both tests assert at least one of the 4 stable anchors from Plan 37-02 appears as a deep-link fragment (LINK-04 end-to-end gate)

- **Task 3:** Phase-level verification sweep executed across all LINK-0X requirements. Summary matrix below. All 4 requirements now marked `[x]` in `.planning/REQUIREMENTS.md`.

## Task Commits

| # | Task | Hash | Files |
|---|------|------|-------|
| 1 | Helper test — 13 mkdocs_link / mkdocs_url assertions | 3181eeb3 | test/helpers/application_helper_test.rb |
| 2 | Controller integration test — 2 locale-scoped wizard renders | 0e5b9dc8 | test/controllers/tournament_doc_links_test.rb |
| 3 | Mark LINK-01 complete in REQUIREMENTS.md | aed8f948 | .planning/REQUIREMENTS.md |
| 4 | Plan metadata + SUMMARY (this commit) | pending | .planning/phases/37-in-app-doc-links/37-05-SUMMARY.md, .planning/STATE.md, .planning/ROADMAP.md |

## Files Created/Modified

- **Created:** `test/helpers/application_helper_test.rb` — 95 lines (13 tests)
- **Created:** `test/controllers/tournament_doc_links_test.rb` — 119 lines (2 tests, extensive header comment explaining fallback rationale)
- **Created:** `.planning/phases/37-in-app-doc-links/37-05-SUMMARY.md` — this file
- **Modified:** `.planning/REQUIREMENTS.md` — LINK-01 checkbox flipped to `[x]` and traceability table row status → `Complete`

## Decisions Made

### D-05-01: Controller integration test over Capybara system test

The plan explicitly permits degrading Task 2 from a Capybara system test to a controller integration test if the system test setup is "too fragile in the time budget." Three factors drove the degrade:

1. **No chromedriver installed locally.** `which chromedriver` returned nothing. Selenium-manager's auto-download behavior is non-deterministic in sandboxed test contexts.

2. **Known fixture association rot.** `TournamentResetConfirmationTest` (Phase 36b) already documents via `visit_tournament_or_skip` that `tournaments(:local)` can 500 on the show page due to `_show.html.erb:5 tournament.organizer.shortname` and other fixture FK issues. Reusing the established FK-repair pattern from `TournamentsControllerTest#test "GET show renders reset modal …"` (update_columns of organizer_id/organizer_type/season_id + `Carambus.config.carambus_api_url = "http://local.test"`) is the only reliable path, and it works in both integration and system contexts.

3. **Full observability of the assertions in the response body.** The LINK-02 / LINK-04 contract is entirely about the rendered `<a>` tag — href, target, rel, and anchor fragment. No JavaScript interaction or visual layout is involved. A controller integration test captures the exact same signal at ~50x faster test runtime.

The test file header documents this decision in detail for future readers.

### D-05-02: club_admin user fixture (not system_admin)

During Task 2 debugging, `users(:system_admin)` triggered an unrelated 500 in `_left_nav.html.erb:141`, which gates a ClubCloud sidebar section on `current_user&.system_admin?` and calls `migration_cc_region_path(Region[1])` — but `Region[1]` is nil in the test DB. `users(:club_admin)` satisfies `tournament_director?(user)` (which checks `club_admin? || system_admin?`) without triggering that sidebar block. This is a cleaner test setup and does not require patching the unrelated sidebar bug.

### D-05-03: LINK-01 grep check is a known false positive

The plan's Task 3 sweep includes:
```bash
grep 'text ||= path.split' app/helpers/application_helper.rb && echo "FAIL: fallback still present"
```

This is a broad string match against the entire helper file. It returns a hit on line 137 inside `docs_page_link` — a **different** helper that Plan 37-01 explicitly left untouched and documented as "the plan-level wording was written with mkdocs_link in mind." The substantive check — that `mkdocs_link`'s body has no humanize fallback — is:

```bash
awk '/def mkdocs_link/,/^  end/' app/helpers/application_helper.rb | grep -c humanize
# => 0
```

LINK-01 passes. The stale `docs_page_link` humanize fallback is out of scope (logged in Plan 37-01 summary's Out-of-scope section).

## LINK-0X Phase Verification Matrix

| Req | Actual | Target | Status | Evidence |
|-----|--------|--------|--------|----------|
| **LINK-01** | 1 `def mkdocs_link` + 1 `def mkdocs_url` + 0 humanize fallback inside `mkdocs_link` body | all | Complete | `application_helper.rb` lines 142-168; 13 Minitest assertions lock the contract |
| **LINK-02** | 3 inline `mkdocs_link('managers/tournament-management'…)` + 3 `docs_path: 'managers/tournament-management'` kwargs = 6 wizard doc links + 4 form-help doc links (one per form view) | 6 wizard, 4 form | Complete | `_wizard_steps_v2.html.erb` (3 + 3); `parse_invitation.html.erb`, `define_participants.html.erb`, `finalize_modus.html.erb`, `tournament_monitor.html.erb` (1 each) |
| **LINK-03** | 4 tournament form views each render exactly 1 `mkdocs_link` | 4 | Complete | Per-view grep count all = 1 |
| **LINK-04** | 4 unique deep-link anchors across wizard + form: `seeding-list`, `participants`, `mode-selection`, `start-parameters` | ≥3 | Complete (exceeds floor by +1) | `grep -roE "(anchor\|docs_anchor): '[a-z-]+'"` across wizard + 4 form views returns 4 unique IDs |

**Plan 02 anchor presence in both locale doc files:**

| Anchor | DE count | EN count |
|--------|----------|----------|
| `{#seeding-list}` | 1 | 1 |
| `{#participants}` | 1 | 1 |
| `{#mode-selection}` | 1 | 1 |
| `{#start-parameters}` | 1 | 1 |

All 4 stable anchors present once in each locale file.

## Phase 36b Invariant Check

`tournament_monitor.html.erb` `data-controller="tooltip"` count:

| Source | Count |
|--------|-------|
| HEAD~6 (before Plan 37-04) | 16 |
| Current HEAD | 16 |

**16 → 16 — Phase 36b tooltip invariant preserved.** No tooltip lines added, removed, or modified across all of Phase 37.

## i18n Key Resolution Check

```
I18n.t('tournaments.docs.walkthrough_link', locale: :de) → "📖 Detailanleitung im Handbuch →"
I18n.t('tournaments.docs.walkthrough_link', locale: :en) → "📖 Full walkthrough in handbook →"
I18n.t('tournaments.docs.form_help_link',   locale: :de) → "📖 Detailanleitung im Handbuch →"
I18n.t('tournaments.docs.form_help_link',   locale: :en) → "📖 Full walkthrough in handbook →"
I18n.t('tournaments.docs.form_help_prefix', locale: :de) → "Hilfe zu diesem Schritt:"
I18n.t('tournaments.docs.form_help_prefix', locale: :en) → "Help for this step:"
```

All 6 i18n resolutions succeed. D-19 invariant (`walkthrough_link == form_help_link` within each locale) holds.

## Test Suite Results

```
bin/rails test test/helpers/application_helper_test.rb test/controllers/tournament_doc_links_test.rb
Run options: --seed 29956
...............
Finished in 0.398952s, 37.5985 runs/s, 102.7693 assertions/s.
15 runs, 41 assertions, 0 failures, 0 errors, 0 skips
```

**15 runs, 41 assertions, 0 failures, 0 errors, 0 skips.**

## Lint Results

### standardrb on new test files

```
bundle exec standardrb test/helpers/application_helper_test.rb test/controllers/tournament_doc_links_test.rb
# exit 0 — clean
```

### standardrb on app/helpers/application_helper.rb

Exit 0. 239 pre-existing violations remain in unrelated helper methods (e.g., `generate_filter_fields` line 644+); these are out of scope per the scope-boundary rule and were documented as pre-existing in Plan 37-01.

### erblint on 6 modified ERB files

Exit code non-zero due to **pre-existing** violations (autocomplete attribute warnings on Phase 36b parameter fields in `tournament_monitor.html.erb`, trailing whitespace in `finalize_modus.html.erb`, pre-existing trailing newline in `_wizard_steps_v2.html.erb`). All were documented as pre-existing in Plans 37-03 and 37-04 summaries. No new violations introduced by any Phase 37 plan. Per CLAUDE.md scope boundary, these are logged here but not fixed.

## Deviations from Plan

### Rule 1 — Lint auto-fix on new test file (Task 1)

**Found during:** Task 1 verification step.

**Issue:** Initial write of `application_helper_test.rb` used a 2-space continuation indent for multi-line assert_equal arguments. standardrb's `Layout/ArgumentAlignment` cop prefers a single level of indentation for arguments following a multi-line method call (matching the first argument column of the previous line).

**Fix:** Ran `bundle exec standardrb --fix test/helpers/application_helper_test.rb` — auto-fix rewrapped 7 lines. Semantically equivalent, zero assertion changes, re-ran test suite after the fix (still 13 runs / 27 assertions / 0 failures).

**Commit:** 3181eeb3 (fix included in the Task 1 commit, not a separate commit)

### Rule 1 — Fixture choice correction during Task 2 TDD loop

**Found during:** Task 2 first test run.

**Issue:** Initial draft used `users(:admin)` for the integration test, which failed both DE and EN assertions — the `admin: true` flag on that fixture does NOT grant `tournament_director?` (which checks `club_admin?` / `system_admin?`), so the wizard partial was never rendered on the show page.

**Intermediate fix:** Switched to `users(:system_admin)`. This made `tournament_director?` true but introduced a different 500 — the `_left_nav.html.erb:141` ClubCloud sidebar section is gated on `current_user&.system_admin?` and calls `migration_cc_region_path(Region[1])`, and `Region[1]` is nil in the test DB, triggering an unrelated `ActionController::UrlGenerationError`.

**Final fix:** Switched to `users(:club_admin)`. This satisfies `tournament_director?` via `club_admin?` without triggering the system-admin-only sidebar block. Test suite now green in both locales.

Both fix attempts are counted as one Rule 1 deviation (fixture selection), tracked against the 3-attempt limit — attempt 2 of 3.

### D-05-01: Test type downgrade (documented as a decision, not a deviation)

Per the plan's explicit fallback permission, Task 2 was implemented as a controller integration test (`test/controllers/tournament_doc_links_test.rb`) rather than a Capybara system test (`test/system/tournament_doc_links_test.rb`). See D-05-01 above for rationale. The plan's acceptance criteria include an explicit fallback path with equivalent grep thresholds against the controller file.

## Out-of-scope / Deferred

- **erblint pre-existing violations** in 6 Phase 37 ERB files — documented in Plans 37-03 and 37-04 summaries, out of scope per the scope-boundary rule.
- **standardrb 239 pre-existing violations** in `application_helper.rb` — documented in Plan 37-01 summary, all in unrelated helper methods (`generate_filter_fields`, etc.), out of scope.
- **docs_page_link humanize fallback** at `application_helper.rb:137` — pre-existing, explicitly out of scope per Plan 37-01. A future cleanup pass could mirror `mkdocs_link`'s text guard to remove this fallback too.
- **Duplicate `docs_page_link` definition** at lines 96-101 and 134-140 — pre-existing shadowing, out of scope (documented in Plan 37-01 summary).
- **Capybara system-test coverage** — deferred. The controller integration test gives full assertion coverage for LINK-02 / LINK-04. A per-step system test for all 6 wizard steps was already deferred in the phase context file.

## Threat Flags

None — no new security-relevant surface introduced. Tests exercise read-only public helper and render paths only. Per the plan's threat register (T-37-12, T-37-13), both dispositions are `accept`; no mitigation required.

## User Setup Required

None — tests run against the existing test fixtures. No external services, credentials, or environment variables.

## Next Phase Readiness

- **Phase 37 close-out:** All 4 LINK-0X requirements validated and checked off. The phase is ready for finalization.
- **No blockers** for any downstream phase.
- **Regression net in place:** 15 tests / 41 assertions now guard the Phase 37 contract against future refactors of `application_helper.rb`, `_wizard_step.html.erb`, `_wizard_steps_v2.html.erb`, and the 4 tournament form views.

## Self-Check: PASSED

- [x] `test/helpers/application_helper_test.rb` — FOUND, committed (3181eeb3)
- [x] `test/controllers/tournament_doc_links_test.rb` — FOUND, committed (0e5b9dc8)
- [x] `.planning/REQUIREMENTS.md` — LINK-01 checkbox `[x]`, table row `Complete` (committed aed8f948)
- [x] All 3 commits present in `git log --oneline -5`
- [x] 13 helper tests (`grep -c '^  test "mkdocs_'` = 13) ≥ 10
- [x] 3 `assert_raises(ArgumentError)` calls ≥ 2 (guard coverage)
- [x] 1 `target="_blank"` assertion ≥ 1
- [x] 5 `/docs/en/managers` occurrences ≥ 2
- [x] Controller test has 1 DE test + 1 EN test (2 total)
- [x] Controller test `/docs/managers/tournament-management` count = 5 ≥ 2
- [x] Controller test `/docs/en/managers/tournament-management` count = 5 ≥ 1
- [x] Controller test `noopener` count = 8 ≥ 1
- [x] Controller test `target.*_blank` count = 8 ≥ 1
- [x] `bin/rails test test/helpers/application_helper_test.rb test/controllers/tournament_doc_links_test.rb` — 15 runs, 41 assertions, 0 failures, 0 errors, 0 skips
- [x] `bundle exec standardrb test/helpers/application_helper_test.rb test/controllers/tournament_doc_links_test.rb` — exit 0
- [x] LINK-0X phase matrix all green
- [x] 4 stable anchors present in both DE and EN tournament-management doc files
- [x] Phase 36b tooltip count in `tournament_monitor.html.erb` byte-identical: 16 → 16
- [x] All 6 `tournaments.docs.*` i18n key resolutions succeed in both locales
- [x] D-19 invariant (walkthrough_link == form_help_link within each locale) holds

---
*Phase: 37-in-app-doc-links*
*Completed: 2026-04-14*
