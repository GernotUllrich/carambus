---
quick_id: 260506-lii
phase: quick
plan: 260506-lii
status: HALTED — third failure mode discovered (system_test_caveat triggered)
type: execute
wave: 1
depends_on: []
files_modified: []
files_created:
  - .planning/quick/260506-lii-fix-system-test-connection-isolation-so-/260506-lii-SUMMARY.md
autonomous: true
requirements:
  - SYS-TEST-CONN-ISOLATION (NOT closed — escalated to architectural-decision territory)
tags: [test-fix, system-test, capybara, halted, layered-failure, view-bug]
duration_seconds: 161
completed_date: 2026-05-06
parent_commit: 8914f567
final_commit: 8914f567 (REVERTED — no changes shipped)
---

# Phase quick Plan 260506-lii: Fix System Test Connection Isolation — HALTED

**Outcome:** Plan halted at Task 1 verification. The fixture-user swap from `users(:admin)` to `users(:system_admin)` (Task 1) uncovered a **third, previously-undiagnosed failure mode** that regressed all 4 tests in the file from "2 pass / 2 fail" (pre-fix baseline) to "0 pass / 4 skip" (post-Task-1 state). Per the executor prompt's `<system_test_caveat>` directive — "STOP and report — don't fudge further changes" — execution halted, the Task 1 commit was reverted, and the working tree was reset to parent `8914f567`. No commits ship in this quick.

## Why this halted (one-line)

`users(:system_admin)` causes `app/views/application/_left_nav.html.erb:156` to render `migration_cc_region_path(Region[1])`, which raises `ActionController::UrlGenerationError` because `Region[1]` is `nil` in the test fixture DB. The page returns 500, the form `#start_tournament` is never rendered, and `visit_monitor_or_skip` hits its third skip path on every test.

## Execution Trace

### Task 1 — Setup-block fixture-user swap — APPLIED then REVERTED

**Edit applied** (committed as `213c0472`, later reverted):

```ruby
# Old:
@user = begin
  users(:admin)
rescue
  User.first
end

# New:
@user = begin
  users(:system_admin)
rescue
  User.first
end
```

(Plus an explanatory comment block per the plan's prescribed code.)

**Verification result:** 4 runs / 0 assertions / 0 failures / 0 errors / **4 skips** — full regression vs. parent commit (which had 2 pass + 2 fail).

**Failure mode discovered:** Visit to `/tournaments/:id/tournament_monitor` returns 500 with stack trace pointing at `app/views/application/_left_nav.html.erb:156`:

```
ActionView::Template::Error (No route matches {:action=>"migration_cc",
  :controller=>"regions", :id=>nil}, missing required keys: [:id]):

156: <li><%= link_to "Migration", migration_cc_region_path(Region[1]),
              class: 'block p-2 text-gray-700 ...' %></li>

app/views/application/_left_nav.html.erb:156
app/views/application/_navbar.html.erb:36
app/views/layouts/application.html.erb:107
```

The nav block at line 156 is rendered conditionally (the surrounding `<ul>` and parent menu are gated to admin/system-admin views). With `:admin` (the old fixture, no `role:` set), this menu was hidden because the gate uses `system_admin?` — so the page rendered cleanly and the form was visible. With `:system_admin` (new fixture, `role: system_admin`), the gate opens, the link is rendered, `Region[1]` returns nil in the test DB (the `:nbv` region fixture has id `50_000_001`, not `1`), and `migration_cc_region_path(nil)` raises.

### Tasks 2, 3, 4 — NOT EXECUTED

Per the system_test_caveat, halted before applying the URL/DOM assertion rewrites. Task 2's edit was applied to the working tree but never committed; reverted via `git reset --hard 8914f567`.

## Three-Layer Diagnosis (updated from plan's two-layer)

The plan's iter-2 diagnosis identified two layers (Layer 1: auth bounce; Layer 2: cross-thread visibility). Execution uncovered a **third layer** that was not visible in iter-1's test.log evidence:

**Layer 1 — Auth bounce on success-path redirect** (plan's diagnosis, still valid):
- With `users(:admin)`, the success-path redirect from `/tournaments/:id/start` → `/tournament_monitors/:id` is bounced to `/` by `TournamentMonitorsController#ensure_tournament_director` (because `users(:admin).system_admin?` returns false).

**Layer 2 — Cross-thread visibility under `use_transactional_tests`** (plan's diagnosis, untestable post-halt):
- Even if Layer 1 were fixed, `@tournament.reload.state` cannot see the Puma server thread's UPDATE because the test thread holds a separate Postgres connection with its own MVCC snapshot.
- Plan's mitigation (URL/DOM assertion rewrite) is the right shape, but it requires the test to ever reach the Confirm-click step — which it cannot, due to Layer 3.

**Layer 3 — Layout 500 on system_admin nav render** (NEW, discovered during Task 1 verification):
- `app/views/application/_left_nav.html.erb:156` calls `migration_cc_region_path(Region[1])`. In the test DB, `Region[1]` is nil (the `:nbv` fixture lives at id `50_000_001`).
- This is hidden when `current_user.system_admin?` is false (the case with `:admin` fixture), so it never fires for tests that use the legacy fixture.
- It IS triggered when `current_user.system_admin?` is true (the case with `:system_admin` fixture), so it fires on EVERY page render under `:system_admin`.

**Why fixing only Layer 1 is insufficient:** The fix for Layer 1 (swap to `:system_admin`) inadvertently activates Layer 3 (nav-bar render path that crashes on nil `Region[1]`). The two layers are coupled: any fixture user that satisfies `ensure_tournament_director` on the success-path redirect (i.e., system_admin OR club_admin) also activates the layout-render path that crashes.

**Why fixing only Layer 2 is insufficient:** Even if URL/DOM assertions are written, the test never reaches the assertion line — `visit_monitor_or_skip` skips early because the form is missing due to Layer 3.

**Why all three must be fixed (or one routed around):** A correct fix needs to either (a) repair the layout's `migration_cc_region_path(Region[1])` reference so it doesn't crash when Region[1] is nil; or (b) use a fixture user with `club_admin?` true and `system_admin?` false (because `ensure_tournament_director` accepts club_admin OR system_admin, but the `:left_nav` admin block likely gates on system_admin specifically); or (c) widen the test to assume the Layer 3 view bug is pre-existing test-env breakage and skip past it via a different path.

## Recommended Next Steps (out of scope for this quick)

1. **Investigate Layer 3 root cause** in `app/views/application/_left_nav.html.erb:156` — is `Region[1]` a hardcoded fixture-DB-only assumption, or is the production assumption that region-1 always exists?
2. **Audit which other system tests pass under `:system_admin`** — if zero, this is a project-wide test-infrastructure bug that needs a coordinated fix (likely in the fixtures, not the layout). If some, check what they do differently.
3. **Re-evaluate the plan's diagnosis methodology** — iter-1's evidence collection didn't reach a page-render assertion under `:system_admin`, so Layer 3 was invisible. A future plan should run a single `visit` + `assert_no_text "Internal Server Error"` smoke test under each candidate fixture user before committing to a fixture swap.

## Constraints Honored

- ✅ `test/test_helper.rb` UNCHANGED (zero diff vs `8914f567`)
- ✅ `test/application_system_test_case.rb` UNCHANGED
- ✅ `Gemfile` UNCHANGED
- ✅ `test/fixtures/users.yml` UNCHANGED
- ✅ `test/system/tournament_parameter_verification_test.rb` UNCHANGED (Task 1 commit reverted)
- ✅ `carambus_master`, `carambus_phat`, `carambus_api` checkouts NOT touched
- ✅ Working tree clean at parent commit `8914f567` (zero net change shipped)

## Pending Todos / STATE.md Update Recommendation

The "System-test connection isolation" entry under `## Pending Todos` in `.planning/STATE.md` should be REPHRASED rather than closed. New text should reflect the three-layer diagnosis:

> **System-test connection isolation + system_admin layout 500 (test-infra; not blocking push):** Three coupled layers prevent 36B-06 tests 3+4 from going green: (Layer 1) `ensure_tournament_director` bounces non-admin users from the success-path redirect; (Layer 2) `use_transactional_tests=true` makes Puma's UPDATE invisible to the test-thread reload; (Layer 3) NEW — `app/views/application/_left_nav.html.erb:156` calls `migration_cc_region_path(Region[1])` which crashes when Region[1] is nil (test fixtures place :nbv at id 50_000_001, not 1), only triggers when current_user.system_admin? is true. Fixing Layer 1 alone (the obvious fixture swap) activates Layer 3. A correct fix needs either: a layout repair (Region.first || Region[1] fallback), a different fixture user with club_admin? true / system_admin? false, or a test-env-only nav-bypass. See quick-260506-lii SUMMARY for full evidence chain. Quick task halted at parent commit 8914f567; no shipped change.

## Self-Check: PASSED

Working tree: clean (verified by `git status` returning "nothing to commit").
Parent commit: `8914f567` (verified by `git log --oneline -1`).
File state: `test/system/tournament_parameter_verification_test.rb` byte-identical to parent commit (verified by `git diff HEAD -- test/system/tournament_parameter_verification_test.rb` returning empty).

No untracked files (other than this SUMMARY.md, which is gitignored under `.planning/quick/`).
