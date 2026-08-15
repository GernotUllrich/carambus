---
quick_id: 260506-me5
phase: quick
plan: 260506-me5
status: partial-success-with-layer-4-discovery
parent_commit: f6ff2918
commits:
  - 8f0b02a0  # Task 1: fixture role: club_admin
  - d55120c2  # Tasks 2+3: URL/DOM assertion rewrites
files_modified:
  - test/fixtures/users.yml
  - test/system/tournament_parameter_verification_test.rb
test_results:
  36b-06: 4 runs / 10 assertions / 1 failure / 0 errors / 0 skips (was 4 / 11 / 2 / 0 / 0 pre-fix)
  36b-05_control: 3 runs / 10 assertions / 0 failures / 0 errors / 0 skips
  uploads_controller: 6 runs / 9 assertions / 0 failures / 0 errors / 0 skips
  integration_suite: 12 runs / 38 assertions / 0 failures / 0 errors / 0 skips
  system_test_smoke: pre-existing Bk2::CommitInning errors only — no new failures from our changes
deferred_for_followup:
  - layer-4-form-defaults-vs-shared-ranges-mismatch
  - layer-3-system-admin-nav-region1-nil-crash
  - public-docs-untracked-files (pre-existing)
duration: 25 minutes
tags: [test-fix, partial-success, fixture-role, url-dom-assertion, layer-4-discovery, surgical, local-global-aware]
---

# Quick Task 260506-me5 — Get 36B-06 system tests 3+4 to pass via local/global-aware fixture role + URL/DOM assertion rewrite

## Executive summary

**Status: 3/4 partial success.** Tests 1, 2, 3 of `test/system/tournament_parameter_verification_test.rb` are GREEN. Test 4 reveals a **Layer 4** issue (4th in the cascade) not anticipated by the predecessor halt diagnosis: the test's `safe_value` only accounts for `balls_goal` parameter ranges, but the form ALSO submits `sets_to_play=0` and `sets_to_win=0` which fall OUTSIDE `UI_07_SHARED_RANGES` (1..7 and 1..4 respectively). These trigger the verification redirect even when `balls_goal` is in range.

Per the system_test_caveat in the executor prompt — **STOP and report on a 4th, undiagnosed issue** — Test 4 was NOT auto-fixed. Tasks 1, 2, 3 are committed exactly as the plan prescribed. Layer 4 is filed as a follow-up with concrete reproduction evidence below.

## Final test counts (5 verify runs)

| Suite                                                | Result                                                         | Notes                                                                                |
|------------------------------------------------------|----------------------------------------------------------------|--------------------------------------------------------------------------------------|
| `tournament_parameter_verification_test.rb` (36B-06) | 4 runs / 10 assertions / **1 failure** / 0 errors / 0 skips    | Tests 1, 2, 3 GREEN. Test 4 fails on Layer 4 (see below).                            |
| `tournament_reset_confirmation_test.rb` (36B-05)     | 3 runs / 10 assertions / 0 failures / 0 errors / 0 skips       | Control passes — `role: club_admin` had no effect.                                   |
| `uploads_controller_test.rb`                         | 6 runs / 9 assertions / 0 failures / 0 errors / 0 skips        | Control passes — `role: club_admin` had no effect.                                   |
| `test/integration/`                                  | 12 runs / 38 assertions / 0 failures / 0 errors / 0 skips      | Same counts as parent — no spillover.                                                |
| `test/system/` (broader smoke)                       | 120 runs / 12 failures / 41 errors                             | All failures pre-existing (`Bk2::CommitInning` from Phase 38.5/38.6 stale references; scaffolding stub tests). 36B-06 Test 4 is the only failure attributable to OUR changes. |

**Pre-fix baseline (parent commit `f6ff2918`):** 36B-06 had 4 runs / 11 assertions / **2 failures** / 0 errors / 0 skips (Tests 3 + 4 both failed via `assert_includes STARTED_STATES, @tournament.reload.state` cross-thread DB-state read).

**Net result:** Reduced 36B-06 failures from 2 → 1. Test 3 fully fixed. Test 4 still failing but for a NEW reason — Layer 4, not Layer 1+2.

## The 3 specific edits (across 2 files)

### Edit 1 — `test/fixtures/users.yml` :admin block (commit `8f0b02a0`)

```diff
@@ -144,6 +144,7 @@ admin:
   time_zone: "Central Time (US & Canada)"
   confirmed_at: <%= Time.current %>
   admin: true
+  role: club_admin

 invited:
```

Single-line addition AFTER the existing `admin: true` line. The legacy boolean is preserved.

### Edit 2 — `test/system/tournament_parameter_verification_test.rb` Test 3 (commit `d55120c2`)

Old (line 109):
```ruby
    # AASM transitions: tournament_started or a waiting-for-monitors variant.
    assert_includes STARTED_STATES, @tournament.reload.state
```

New (lines 108-128):
```ruby
    # The controller's start action runs start_tournament! + explicit save (commit
    # e362f8a9) and redirects to tournament_monitor_path(@tournament.tournament_monitor).
    # We assert the post-redirect URL pattern instead of @tournament.reload.state because
    # Capybara's Puma server runs on a separate Postgres connection from the test thread;
    # with use_transactional_tests = true (project convention; test/TEST_DATABASE_SETUP.md
    # line 94), the test thread cannot see the server thread's committed state UPDATE via
    # AR reload. The URL is observable cross-thread via the browser session.
    #
    # Layer 1 prerequisite: test/fixtures/users.yml :admin block carries `role: club_admin`
    # (added by quick-260506-me5 Task 1) so this redirect is NOT bounced to / by
    # TournamentMonitorsController#ensure_tournament_director (controllers/
    # tournament_monitors_controller.rb:201-206).
    #
    # See quick-260506-me5 diagnosis Layers 1 + 2 for the full reasoning. Layer 3
    # (Region[1] nil-crash in _left_nav.html.erb:156 under system_admin) stays dormant
    # because :admin uses club_admin, not system_admin.
    assert_current_path %r{\A/tournament_monitors/\d+\z}, wait: 10
    assert_no_text verification_title
```

### Edit 3 — `test/system/tournament_parameter_verification_test.rb` Test 4 (commit `d55120c2`)

Old (line 122):
```ruby
    assert_no_text verification_title
    assert_includes STARTED_STATES, @tournament.reload.state
```

New (lines 138-145):
```ruby
    assert_no_text verification_title
    # Same controller path + cross-thread-visibility rationale as the Confirm-click test
    # above (Test 3): in-range values skip the verification modal, the start action runs
    # start_tournament! + save, and redirects to tournament_monitor_path. The URL is
    # cross-thread-visible via the browser session; @tournament.reload.state is not
    # (test thread / Puma thread connection isolation under use_transactional_tests).
    # Task 1's `role: club_admin` on the :admin fixture ensures ensure_tournament_director
    # does not bounce.
    assert_current_path %r{\A/tournament_monitors/\d+\z}, wait: 10
```

## Three-layer diagnosis recap (Layers 1+2 fixed, Layer 3 dormant)

| Layer | What it is                                                                        | Fixed by this task?                          |
|-------|-----------------------------------------------------------------------------------|----------------------------------------------|
| 1     | Auth bounce — `ensure_tournament_director` rejects `:admin` user (no role)        | YES — `role: club_admin` added to fixture    |
| 2     | Cross-thread DB visibility under `use_transactional_tests`                        | YES — URL/DOM assertion rewrite              |
| 3     | `_left_nav.html.erb:156` crashes on nil `Region[1]` for `system_admin` users      | NO — kept dormant via `club_admin` choice    |

**Why `club_admin` was the right Layer 1 VALUE choice (not `system_admin`):**

The `carambus_bcw` checkout simulates a local-server operator. Per project topology (`CLAUDE.md` `MIN_ID = 50_000_000` distinguishing global from local records; `.agents/skills/scenario-management/SKILL.md` describing bcw as a deployment checkout), the realistic operator role for tests in this checkout is `club_admin`. `system_admin` is `carambus_api` central-server territory.

`TournamentMonitorsController#ensure_tournament_director` accepts EITHER role (`club_admin? || system_admin?`), so both satisfy the Layer 1 gate. But the system_admin-only admin-nav block (`_left_nav.html.erb:156`) calls `migration_cc_region_path(Region[1])` which crashes on nil `Region[1]` under fixtures (`:nbv` lives at id 50_000_001). Choosing `club_admin` keeps that block hidden — Layer 3 stays dormant.

The predecessor plan 260506-lii halted because it tried `users(:system_admin)` — correct shape, wrong VALUE. This task uses the same shape (assign a privileged role to the user the test signs in as) but picks the locally-realistic value.

## Layer 4 discovery — the 4th issue not in the original cascade diagnosis

**The bug:** Test 4 ("in-range values skip the modal and start the tournament directly") computes:

```ruby
safe_value = @tournament.discipline.parameter_ranges[:balls_goal].first + 5
```

This produces an in-range `balls_goal` value. But the form ALSO submits OTHER UI_07 fields — specifically `sets_to_play=0` and `sets_to_win=0` (the `"-"` option in the select tag, app/views/tournaments/tournament_monitor.html.erb lines 139, 142). These zeros fall outside `UI_07_SHARED_RANGES`:

```ruby
# app/models/discipline.rb:60-65
UI_07_SHARED_RANGES = {
  time_out_warm_up_first_min: 1..10,
  time_out_warm_up_follow_up_min: 0..5,
  sets_to_play: 1..7,    # 0 is OUT
  sets_to_win: 1..4      # 0 is OUT
}.freeze
```

The verifier (`tournaments_controller.rb:1011-1032`) iterates `UI_07_FIELDS` (which includes `sets_to_play` and `sets_to_win`), finds them out-of-range, builds the verification failure, and redirects to the start-of-flow GET URL with the modal flash. So the URL stays at `/tournaments/:id/tournament_monitor` instead of advancing to `/tournament_monitors/:id`.

**Test log evidence (test.log line 274107):**

```
Started POST "/tournaments/50000001/start" for 127.0.0.1 at 2026-05-06 16:16:38 +0200
Processing by TournamentsController#start as TURBO_STREAM
  Parameters: {"parameter_verification_confirmed"=>"0", "balls_goal"=>"15", "innings_goal"=>"",
               "timeout"=>"45", "timeouts"=>"0", ...,
               "sets_to_play"=>"0", "sets_to_win"=>"0", "commit"=>"Starte den Turnier-Monitor", ...}
...
Redirected to http://127.0.0.1:60935/tournaments/50000001/tournament_monitor
Completed 302 Found in 4ms
```

`balls_goal=15` is in range (Dreiband: 10..150) — but `sets_to_play=0, sets_to_win=0` triggered the verification redirect.

**Why this was hidden:** Tests 1, 2, 3 all set `balls_goal=99999` which itself triggers the modal — the test author never noticed the OTHER fields would also trigger it on their own. The original `assert_includes STARTED_STATES, @tournament.reload.state` failed for an unrelated reason (cross-thread visibility) that masked the real issue.

**This is NOT a regression caused by quick-260506-me5.** It's a pre-existing latent test bug that was discovered when our Layer 1+2 fixes correctly unblocked the URL observation. The test would have failed regardless of which Layer 1 fix was chosen (`club_admin` or `system_admin`); the new failure mode just becomes visible now.

**Why this was NOT auto-fixed in this task:** The system_test_caveat directive in the executor prompt instructs STOP and report on undiagnosed issues. Auto-fixing here would also require interpretation work — the discrepancy between the form's allowed `0` value and the verifier's `1..7` / `1..4` ranges is itself a bug worth a separate diagnosis (is the form wrong? is the verifier wrong? is `0` semantically "no limit" and should be exempt from the range check?).

**Recommended fix options for Layer 4 follow-up:**

1. **Test-only fix (minimal):** Make the test fill `sets_to_play=2, sets_to_win=2` along with `safe_value` for `balls_goal`. Quick, surgical, but leaves the production bug.
2. **Verifier exempt 0:** Add `next if value == 0` (or `next if value.zero? && [:sets_to_play, :sets_to_win].include?(field)`) in `verify_tournament_start_parameters`. Treats 0 as "no limit" / "single-set mode". Matches the form's `"-"` semantics.
3. **Form change:** Remove the `0` option from the `sets_to_play`/`sets_to_win` selects. Forces single-set choices into the 1..7 / 1..4 ranges. Likely too invasive — single-set tournaments are common.

Recommended: option (2) — exempt 0 in the verifier, matching the form's intent. Production bug — ship the fix.

## Files unchanged from parent commit `f6ff2918`

Verified via `git diff --stat HEAD~2 -- <path>` (zero output for each):

- `test/test_helper.rb` (LOCKED 6 — project transactional-tests convention)
- `test/application_system_test_case.rb` (LOCKED 6 — no shared-connection patch added)
- `Gemfile` (LOCKED 6 — no `database_cleaner` introduced)
- `test/fixtures/users.yml` `:system_admin` block (lines 106-115, byte-identical)
- `test/fixtures/users.yml` `:club_admin` block (lines 95-104, byte-identical)
- `test/fixtures/users.yml` ALL other blocks (`:valid`, `:player`, `:one`, `:two`, `:invited`, `:regular`) byte-identical
- `app/views/application/_left_nav.html.erb` (LOCKED 3 — Layer 3 dormant)

## Self-check: STARTED_STATES retention

The `STARTED_STATES` constant at line 69 of `tournament_parameter_verification_test.rb` remains in the file as documentary dead code (no longer referenced from any assertion). Same retention pattern as predecessor plan 260506-lii. A separate cleanup pass can remove it.

## Backlog seeds (for STATE.md Pending Todos)

### Layer 3 — Harden `_left_nav.html.erb:156` migration_cc link (carry-forward from predecessor)

- **Title:** Harden `_left_nav.html.erb:156` migration_cc link against nil `Region[1]`
- **Why:** On a fresh local server that hasn't synced regions, a `system_admin` login would hit `ActionController::UrlGenerationError` because `migration_cc_region_path(Region[1])` raises when `Region[1]` is nil. Same crash occurs in test fixtures (`:nbv` lives at id 50_000_001). Reproducible: log in as `users(:system_admin)` and visit any page that renders the layout.
- **Recommended fix:** `link_to "Migration", migration_cc_region_path(Region[1] || Region.first), class: ...` — minimal-blast hardening, preserves link visibility for system_admin users, falls back to `Region.first` when `Region[1]` doesn't exist.
- **Discovered by:** quick-260506-lii halt diagnosis (Layer 3); kept dormant by quick-260506-me5 via `club_admin` role choice.

### Layer 4 — Verifier rejects sets_to_play=0 / sets_to_win=0 even though form offers them (NEW, this task)

- **Title:** UI_07 verifier rejects `sets_to_play=0` / `sets_to_win=0` despite form's `"-"` (= 0) option
- **Why:** `app/views/tournaments/tournament_monitor.html.erb:139, 142` offers `0` as a valid select option for `sets_to_play` and `sets_to_win` (rendered as `"-"`, semantically "single-set / no limit"). But `UI_07_SHARED_RANGES` requires `sets_to_play: 1..7` and `sets_to_win: 1..4`. The verifier (`tournaments_controller.rb:1011-1032`) flags `0` as out-of-range, triggering the verification modal even for tournaments that intentionally use single-set mode.
- **Reproducer:** `test/system/tournament_parameter_verification_test.rb` Test 4 ("in-range values skip the modal and start the tournament directly") — submits `balls_goal=15` (in range) but inherits form defaults `sets_to_play=0, sets_to_win=0`, which trigger the modal redirect.
- **Recommended fix:** In `verify_tournament_start_parameters`, exempt `0` for `sets_to_play` / `sets_to_win` (e.g., `next if value.zero? && [:sets_to_play, :sets_to_win].include?(field)`). Treats `0` as "single-set / no limit" matching the form's intent.
- **Production impact:** Same false-positive verification modal will fire for any operator running a single-set tournament with otherwise-valid parameters. User-visible papercut.
- **Test fix coupling:** Same fix unblocks 36B-06 Test 4. Recommend a follow-up quick task that ships the verifier fix and removes Test 4 from the failure list in one commit.
- **Discovered by:** quick-260506-me5 Test 4 reproduction (this SUMMARY).

## Pending Todos cleanup

The STATE.md "Get 36B-06 system tests 3+4 to pass — three-layer cascade discovered by halted quick-260506-lii" entry can be moved from "Pending Todos" to a state reflecting **partial closure**:

- Tests 3 of 4 closed by quick-260506-me5 commits `8f0b02a0` + `d55120c2`
- Test 4 still failing — replace with new entry "Fix UI_07 verifier rejects sets_to_play=0 / sets_to_win=0 (Layer 4 from quick-260506-me5)" pointing at the SUMMARY for Reproducer + Recommended fix.
- Layer 3 backlog seed (above) added as separate pending todo.

## Push-readiness note (scenario-management SKILL)

bcw is in **Debugging Mode** (settled per executor prompt). This task lands 2 commits on bcw at HEAD `f6ff2918` + 2 = `d55120c2`. Cross-checkout sync (master, phat, api) **deferred per user** (LOCKED 7 in plan). When user is ready to push:

```bash
cd /Users/gullrich/DEV/carambus/carambus_bcw && git push
# Then sync:
cd /Users/gullrich/DEV/carambus/carambus_master && git pull
cd /Users/gullrich/DEV/carambus/carambus_phat && git pull   # (or skip if intentionally behind)
cd /Users/gullrich/DEV/carambus/carambus_api && git pull    # (or skip if intentionally behind)
```

## Notes for future planners / reviewers

The `club_admin` choice (vs. predecessor's `system_admin`) was the load-bearing decision distinguishing this task from the failed 260506-lii. The Layer 2 URL/DOM assertion rewrite design carried over verbatim from the predecessor's plan — the predecessor's Layer 2 design was sound; only its Layer 1 VALUE was wrong.

Layer 4 discovery is genuinely new; the predecessor's cascade diagnosis was three layers deep, and Test 4's `safe_value` field-coverage gap was not visible until Layers 1+2 were correctly resolved.

The `assert_no_text verification_title` defense-in-depth assertion in Test 3 proved its value: had the URL assertion passed but the modal still appeared (e.g., due to a Turbo cache), the second assertion would catch it. In the current run both assertions pass for Test 3.

## Self-Check: PASSED

Verified:
- `test/fixtures/users.yml` `:admin` block contains both `admin: true` AND `role: club_admin` (grep returns 2)
- `test/system/tournament_parameter_verification_test.rb` contains 2 occurrences of `assert_current_path %r{\A/tournament_monitors/\d+\z}` (one per Test 3 + Test 4)
- 0 remaining `assert_includes STARTED_STATES, @tournament.reload.state` in the test file
- Commit `8f0b02a0` exists (`git log --oneline | grep 8f0b02a0` → match)
- Commit `d55120c2` exists (`git log --oneline | grep d55120c2` → match)
- Both commits include `Co-Authored-By` not added (per CLAUDE.md style — the project's own commits don't use the trailer)
- Files: this SUMMARY at `.planning/quick/260506-me5-get-36b-06-system-tests-3-4-to-pass-via-/260506-me5-SUMMARY.md` (will be FOUND after this Write)
