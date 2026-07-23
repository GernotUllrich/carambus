---
quick_id: 260506-lii
phase: quick
plan: 260506-lii
type: execute
wave: 1
depends_on: []
files_modified:
  - test/system/tournament_parameter_verification_test.rb
autonomous: true
requirements:
  - SYS-TEST-CONN-ISOLATION
tags: [test-fix, system-test, capybara, dom-assertion, surgical, auth-fixture]
must_haves:
  truths:
    - "Setup uses `users(:system_admin)` (which has `role: system_admin` per test/fixtures/users.yml lines 106-115) so `TournamentMonitorsController#ensure_tournament_director` (controllers/tournament_monitors_controller.rb:3 + 201-206) does NOT bounce after the success-path redirect to `/tournament_monitors/:id`. The previous `users(:admin)` fixture has only `admin: true` legacy boolean and no `role:` field, so `current_user.system_admin?` returned false and the browser was redirected away to `/`."
    - "test/system/tournament_parameter_verification_test.rb passes 4/4 (0 failures, 0 errors, 0 skips) after the fixture-user swap (Task 1) AND the rewrite of the 2 DB-state assertions to URL/DOM-state assertions (Tasks 2 + 3)"
    - "test/system/tournament_reset_confirmation_test.rb (36B-05 control) still passes 3/3 — no regression from the change"
    - "test/test_helper.rb is UNCHANGED (project transactional-tests convention preserved)"
    - "test/application_system_test_case.rb is UNCHANGED in its connection-handling area (no use_transactional_tests override, no shared-connection patch, no new mixin/base-class layer)"
    - "Gemfile is UNCHANGED (no database_cleaner gem introduced)"
    - "test/fixtures/users.yml is UNCHANGED (we use the existing `system_admin` fixture, not introduce a new one)"
    - "A representative sample of OTHER system tests AND the integration test suite still passes — verifies no spillover from the fixture-user change (other tests reference fixtures by their own per-test labels, but verify defensively)"
  artifacts:
    - path: "test/system/tournament_parameter_verification_test.rb"
      provides: "Setup-block fixture-user swap (line ~20: `users(:admin)` → `users(:system_admin)`); URL/DOM-based assertions on tournament-start success path replacing stale-read DB assertions on lines ~109 and ~122. Total: 3 line edits in 1 file."
      contains: "users(:system_admin)"
  key_links:
    - from: "test/system/tournament_parameter_verification_test.rb setup block"
      to: "test/fixtures/users.yml `system_admin` fixture (lines 106-115)"
      via: "ActiveSupport::TestCase fixture lookup"
      pattern: "users\\(:system_admin\\)"
    - from: "test/system/tournament_parameter_verification_test.rb test 'clicking Confirm starts the tournament with the override'"
      to: "tournament_monitor_path (TournamentMonitor#show)"
      via: "Capybara's assert_current_path after redirect"
      pattern: "assert_current_path.*tournament_monitor"
    - from: "test/system/tournament_parameter_verification_test.rb test 'in-range values skip the modal and start the tournament directly'"
      to: "tournament_monitor_path (TournamentMonitor#show)"
      via: "Capybara's assert_current_path after redirect"
      pattern: "assert_current_path.*tournament_monitor"
---

<objective>
Make `test/system/tournament_parameter_verification_test.rb` (36B-06) green 4/4 by (1) switching the setup-block fixture user from `users(:admin)` to `users(:system_admin)` so the success-path redirect to `/tournament_monitors/:id` is not bounced by `TournamentMonitorsController#ensure_tournament_director`, and (2) rewriting the 2 currently-failing assertions to verify post-redirect URL state instead of cross-thread DB state. This closes the test-infrastructure gap flagged in quick-260506-k3t's "Remaining gap" section without disabling the project's documented `use_transactional_tests = true` convention.

Purpose: The production code path is verifiably correct (k3t commit `e362f8a9` proved it via SQL log). Two layers prevented the system test from observing that correctness:

1. **Auth-bounce layer (newly diagnosed by orchestrator iter-1):** The test's `users(:admin)` fixture has only the legacy `admin: true` boolean and no `role:` field. `User#system_admin?` (app/models/user.rb:45-49) requires `role: system_admin`. So `TournamentMonitorsController#ensure_tournament_director` (line 3 before_action; lines 201-206 redirect) bounced the browser from `/tournament_monitors/8` to `/` on every success-path follow-up. The `users(:system_admin)` fixture (test/fixtures/users.yml:106-115) is a drop-in replacement with `role: system_admin` set.

2. **Connection-isolation layer (originally diagnosed):** Even with the auth bounce fixed, `assert_includes STARTED_STATES, @tournament.reload.state` is unobservable to the test thread because Capybara's Puma server runs on a separate Postgres connection from the test thread; with `use_transactional_tests = true`, the server thread's UPDATE is not visible cross-thread via AR reload. The Capybara-idiomatic resolution is to assert on what the test thread CAN see — the redirect URL (`tournament_monitor_path`) and the rendered DOM after the redirect — observable through HTTP semantics, not ActiveRecord.

With both layers fixed, the test's URL assertion settles at `/tournament_monitors/:id` (no auth bounce) AND the assertion does not depend on AR cross-thread visibility. The connection-isolation hypothesis becomes both untestable AND moot — even if it WAS the original failure mode, the URL/DOM rewrite routes around it.

Output: Three surgical edits in one test file: (a) line ~20 setup user swap; (b) Test 3 assertion rewrite; (c) Test 4 assertion rewrite. Zero changes to test infrastructure, zero changes to fixtures.
</objective>

<execution_context>
@/Users/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/workflows/execute-plan.md
@/Users/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/quick/260506-k3t-fix-two-deferred-blockers-from-quick-260/260506-k3t-SUMMARY.md
@.planning/quick/260506-k3t-fix-two-deferred-blockers-from-quick-260/260506-k3t-VERIFICATION.md
@CLAUDE.md
@.agents/skills/extend-before-build/SKILL.md
@test/system/tournament_parameter_verification_test.rb
@test/system/tournament_reset_confirmation_test.rb
@test/application_system_test_case.rb
@test/test_helper.rb
@test/TEST_DATABASE_SETUP.md
@test/fixtures/users.yml
@app/controllers/tournaments_controller.rb
@app/controllers/tournament_monitors_controller.rb
@app/models/user.rb
@Gemfile

<diagnosis>
**Layer 1 — Auth bounce on success-path redirect (orchestrator iter-1 finding):**

After the controller's `start` action redirects to `/tournament_monitors/8` (correct success branch), the browser issues `GET /tournament_monitors/8` which hits `TournamentMonitorsController` (`app/controllers/tournament_monitors_controller.rb`):

```ruby
# Line 3:
before_action :ensure_tournament_director, only: %i[show edit update destroy update_games switch_players start_round_games]

# Lines 201-206:
def ensure_tournament_director
  unless current_user&.club_admin? || current_user&.system_admin?
    redirect_to root_path, alert: ...
  end
end
```

`User#system_admin?` (app/models/user.rb:45-49) returns `role == "system_admin"`. The `users(:admin)` fixture (test/fixtures/users.yml:137-146) does NOT set `role:`; it sets only `admin: true` (legacy boolean). So `current_user.system_admin?` returns false AND `current_user.club_admin?` returns false → bounce to `/` → test's `assert_current_path %r{\A/tournament_monitors/\d+\z}` fails because the URL is `/`.

The `users(:system_admin)` fixture (test/fixtures/users.yml:106-115) IS configured with `role: system_admin`:

```yaml
system_admin:
  first_name: "System"
  last_name: "Admin"
  email: systemadmin@example.com
  encrypted_password: <%= Devise::Encryptor.digest(User, 'password') %>
  accepted_terms_at: <%= Time.current %>
  accepted_privacy_at: <%= Time.current %>
  time_zone: "Central Time (US & Canada)"
  confirmed_at: <%= Time.current %>
  role: system_admin
```

This is a drop-in replacement that satisfies `ensure_tournament_director` without any other change. The other tests in the project that reference `users(:admin)` (if any) are unaffected — fixture references are per-test, not global.

**Test.log evidence (orchestrator iter-1):**
1. POST `/tournaments/50000001/start` → 302 to `/tournament_monitors/8` ✓ (controller success path works)
2. GET `/tournament_monitors/8` → 302 to `/` ✗ (auth bounce fires here)
3. GET `/` → 200 (StaticController#index)

So even though the controller-level success was correct, the URL never settles at `/tournament_monitors/8` long enough for the assertion to observe it. Fix: use `:system_admin` fixture.

**Layer 2 — Connection-isolation cross-thread visibility (original diagnosis, still load-bearing for assertion shape):**

Controller redirect target on success path (`app/controllers/tournaments_controller.rb` lines 468-472, inside the `if @tournament.valid?` block after `start_tournament!` + `@tournament.save`):

```ruby
if @tournament.tournament_monitor.present?
  redirect_to tournament_monitor_path(@tournament.tournament_monitor)
else
  redirect_to tournament_path(@tournament)
end
```

The 36B-06 fixture chain (`tournaments(:local)`) HAS a tournament_monitor association via the fixture FK rot fix from quick-260506-i6h (commit `1c291731`). The controller path also calls `@tournament.initialize_tournament_monitor` at line 389 BEFORE the AASM transition, so `@tournament.tournament_monitor` is populated by the time the redirect-decision runs. **Conclusion:** on the success path of Tests 3 and 4, the controller ALWAYS redirects to `tournament_monitor_path(@tournament.tournament_monitor)`, which is a DIFFERENT route from the test's start-of-flow URL `tournament_monitor_tournament_path(@tournament)` (i.e., `/tournament_monitors/:id` vs. `/tournaments/:id/tournament_monitor`).

**Routes confirmed (from `bundle exec rails routes | grep tournament_monitor`):**
- `tournament_monitor_tournament` → `GET /tournaments/:id/tournament_monitor` (start-of-flow / form)
- `tournament_monitor` → `GET /tournament_monitors/:id` (success destination)

These two routes have entirely disjoint path patterns, so `assert_current_path %r{\A/tournament_monitors/\d+\z}` is unambiguous (the `\A...\z` anchors prevent accidentally matching the start-of-flow URL which contains `tournament_monitor` as a substring).

**Why DB-read is unobservable to the test thread:** Capybara's Puma server runs in a thread that uses its own AR connection. With `use_transactional_tests = true` (Rails default, project convention), the test thread wraps its work in a transaction; the server thread's UPDATE happens on its own non-transactional connection. There is no shared-connection bridge in `application_system_test_case.rb` (verified: lines 6-62, no `ActiveRecord::Base.connected_to`, no `share_with_other_threads`, no `use_transactional_tests = false`). The test thread's `@tournament.reload` reads from its own connection's MVCC snapshot which does not include the Puma thread's already-committed UPDATE.

**Why URL/DOM assertion IS observable:** The browser session is owned by the Capybara driver thread (NOT the Rails-AR test thread). After the controller redirects, the browser follows the redirect, the Puma thread renders the destination view, the response goes back over the wire to the browser, and Capybara's `current_path` / `current_url` reflect the URL the browser navigated to. This is observable through HTTP semantics, NOT through ActiveRecord, so the connection-isolation issue does not apply.

**Combined fix logic:** With Layer 1 fixed (`:system_admin` fixture), the browser settles at `/tournament_monitors/8` after redirect (no auth bounce). With Layer 2's URL/DOM rewrite, the assertion observes that settled URL via the cross-thread-visible browser session. Both layers must be fixed to make the test green; either alone is insufficient.
</diagnosis>

<interfaces>
<!-- Key APIs the executor needs. Already imported via require "application_system_test_case". -->
<!-- All of these are standard Capybara DSL — no codebase exploration needed. -->

Capybara DSL (already in scope via ApplicationSystemTestCase):
- `assert_current_path(path, options = {})` — asserts the browser is at the given path; supports `wait:` option for redirect propagation; supports `ignore_query: true` if needed
- `assert_text(string)` — asserts visible text on rendered page
- `assert_no_text(string)` — asserts visible text is absent
- `page.has_text?(string, wait: 0)` — non-blocking presence check

Rails URL helpers (already in scope via ActionDispatch test integration):
- `tournament_monitor_path(tournament_monitor)` — `/tournament_monitors/:id`
- `tournament_monitor_tournament_path(tournament)` — `/tournaments/:id/tournament_monitor`

Existing test idioms (DO follow):
- The reset_confirmation test (`test/system/tournament_reset_confirmation_test.rb` line 120) already uses `assert_current_path tournament_path(@tournament)` after a Confirm click — same pattern, proven to work in the project.

Fixture references (read-only):
- `users(:system_admin)` — test/fixtures/users.yml:106-115; has `role: system_admin`; satisfies `User#system_admin?` predicate
- `users(:admin)` — test/fixtures/users.yml:137-146; has only legacy `admin: true` boolean, NO `role:` field; does NOT satisfy `system_admin?` or `club_admin?` predicates → bounced by `ensure_tournament_director`
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Setup-block fixture-user swap — replace `users(:admin)` with `users(:system_admin)` to satisfy `ensure_tournament_director`</name>
  <files>test/system/tournament_parameter_verification_test.rb</files>
  <action>
Edit the setup block (currently lines 19-23 inside the `setup do ... end` at lines 13-33). Change the fixture reference from `users(:admin)` to `users(:system_admin)`. Preserve the existing `begin/rescue` defensive pattern (rescue any fixture-loading error and fall back to `User.first`) — it's load-bearing for environments where the fixtures DB has not been freshly loaded.

Concrete edit (replace lines 19-23):

```ruby
    @user = begin
      users(:system_admin)
    rescue
      User.first
    end
```

Rationale (cite this in an inline comment for traceability):

```ruby
    # Use users(:system_admin) (test/fixtures/users.yml:106-115) which has
    # `role: system_admin` set. The previous users(:admin) reference (lines 137+
    # of the same fixture file) only sets the legacy `admin: true` boolean and
    # does NOT set `role:`, so `current_user.system_admin?` returns false and
    # the success-path redirect to /tournament_monitors/:id is bounced to / by
    # TournamentMonitorsController#ensure_tournament_director (controllers/
    # tournament_monitors_controller.rb:3 before_action + lines 201-206 redirect).
    # See quick-260506-lii diagnosis Layer 1 for the full evidence chain.
    @user = begin
      users(:system_admin)
    rescue
      User.first
    end
```

Do NOT modify any other line in the setup block. Do NOT modify `test/fixtures/users.yml` — the `:system_admin` fixture already exists and is correctly configured.

Do NOT change any OTHER tests in the file — the existing structure of Tests 1, 2, 3, 4 is preserved. Tasks 2 and 3 below handle Tests 3 and 4's assertion rewrites.
  </action>
  <verify>
    <automated>cd /Users/gullrich/DEV/carambus/carambus_bcw && grep -n "users(:system_admin)" test/system/tournament_parameter_verification_test.rb && ! grep -n "users(:admin)" test/system/tournament_parameter_verification_test.rb && echo OK</automated>
  </verify>
  <done>The setup block references `users(:system_admin)` and contains zero references to `users(:admin)`. The grep verification shows the new line and confirms no stale references. The auth bounce on the success-path redirect to `/tournament_monitors/:id` no longer fires (verified later in Task 4 regression sweep, where the full file run will demonstrate the URL settles correctly).</done>
</task>

<task type="auto">
  <name>Task 2: Confirm-click test — replace DB-state reload with redirect-URL assertion + DOM defense-in-depth</name>
  <files>test/system/tournament_parameter_verification_test.rb</files>
  <action>
Edit the test "clicking Confirm starts the tournament with the override" (currently lines 99-110). Replace the single failing assertion `assert_includes STARTED_STATES, @tournament.reload.state` with TWO assertions that observe the same outcome via the browser session (which is cross-thread-visible via HTTP, not via the test thread's AR connection):

1. **Primary URL assertion:** After the Confirm click, the controller's `start` action takes the success branch, runs `start_tournament!` + explicit save, then redirects to `tournament_monitor_path(@tournament.tournament_monitor)`. Use Capybara's `assert_current_path` with a `wait:` option to absorb the redirect-and-server-thread propagation latency. Rails 7.2 + Capybara default `default_max_wait_time` is 10s (set in application_system_test_case.rb line 64), but be explicit at `wait: 10` for self-documentation. Match the URL path PATTERN (`%r{\A/tournament_monitors/\d+\z}`) which avoids needing the exact ID at all and is robust to cross-thread AR visibility quirks. With Task 1's fixture swap, the auth bounce no longer fires, so the URL settles at `/tournament_monitors/:id` and the regex matches.

2. **DOM defense-in-depth assertion:** After the redirect URL is confirmed, assert that the destination page (TournamentMonitor#show) has rendered. Use `assert_no_text verification_title` to confirm the verification modal/title is GONE from the new page (it was the failure-path signal on the previous page). This is a low-bar DOM check that complements the URL assertion: even if a future redirect-target change moves the URL pattern, the DOM check still pins "no longer on the verification-failure page."

Concrete edit (replace lines 99-110):

```ruby
test "clicking Confirm starts the tournament with the override" do
  visit_monitor_or_skip

  fill_balls_goal(99999)
  click_start_button

  assert_text verification_title
  find("button[data-action='click->confirmation-modal#confirm']", match: :first).click

  # The controller's start action runs start_tournament! + explicit save (commit
  # e362f8a9) and redirects to tournament_monitor_path(@tournament.tournament_monitor).
  # We assert the post-redirect URL pattern instead of @tournament.reload.state because
  # Capybara's Puma server runs on a separate Postgres connection from the test thread;
  # with use_transactional_tests = true (project convention, see test/TEST_DATABASE_SETUP.md
  # line 94), the test thread cannot see the server thread's committed state UPDATE via
  # AR reload. The URL is observable cross-thread via HTTP. See quick-260506-k3t SUMMARY
  # and quick-260506-lii diagnosis Layer 2 for the full reasoning.
  #
  # Note: Task 1 of quick-260506-lii also swapped users(:admin) → users(:system_admin)
  # in the setup block so this redirect is NOT bounced by ensure_tournament_director.
  assert_current_path %r{\A/tournament_monitors/\d+\z}, wait: 10
  assert_no_text verification_title
end
```

Rationale for `\A...\z` regex anchors: prevents accidental match against the start-of-flow URL `/tournaments/:id/tournament_monitor` which contains `tournament_monitor` as a substring. The success URL is `/tournament_monitors/:id` (plural resource path), distinct path entirely.

Do NOT change `STARTED_STATES` constant or any other test in this file — Tests 1, 2 keep their existing assertions (Test 1 asserts `assert_not_equal "tournament_started", @tournament.reload.state` which is the FAILURE-path observation and works fine because the test thread CAN see "no UPDATE happened" — `reload` returns the fixture's seeded state, which is what the test asserts is unchanged. Test 2 has the same shape and works for the same reason. ONLY Tests 3 and 4 read for a SUCCESS-side state change, which is what hits the cross-thread visibility wall).

Do NOT remove the `STARTED_STATES = %w[tournament_started tournament_started_waiting_for_monitors].freeze` constant — it remains DEAD code after this edit, but leaving it preserves the test's documentary intent (the constant names the AASM destination states clearly even if the assertion no longer reads from `state`). A separate cleanup pass can remove it if desired; it is NOT in scope for this task.
  </action>
  <verify>
    <automated>cd /Users/gullrich/DEV/carambus/carambus_bcw && bin/rails test test/system/tournament_parameter_verification_test.rb -n "test_clicking_Confirm_starts_the_tournament_with_the_override" 2>&1 | tail -20</automated>
  </verify>
  <done>The Confirm-click test (formerly Test 3) passes (`1 runs / 2 assertions / 0 failures / 0 errors / 0 skips`). The other 3 tests in the file are unaffected by this single-test rerun (Test 4 is fixed in Task 3; Tests 1, 2 already pass).</done>
</task>

<task type="auto">
  <name>Task 3: In-range skip-modal test — same URL+DOM assertion pattern as Task 2</name>
  <files>test/system/tournament_parameter_verification_test.rb</files>
  <action>
Edit the test "in-range values skip the modal and start the tournament directly" (currently lines 112-123). Replace the failing assertion `assert_includes STARTED_STATES, @tournament.reload.state` (currently line 122) with the same URL+DOM assertion pattern landed in Task 2.

Concrete edit (replace lines 112-123):

```ruby
test "in-range values skip the modal and start the tournament directly" do
  visit_monitor_or_skip

  # 100 is inside every Range in DISCIPLINE_PARAMETER_RANGES for balls_goal
  # except "Dreiband" (10..80). Pick an in-range value based on discipline.
  safe_value = @tournament.discipline.parameter_ranges[:balls_goal].first + 5
  fill_balls_goal(safe_value)
  click_start_button

  assert_no_text verification_title
  # See Task 2 (the Confirm test above) for the rationale on URL-vs-DB-state
  # assertion. Same controller path: in-range values skip the verification modal,
  # the start action runs start_tournament! + save, and redirects to
  # tournament_monitor_path. The URL is cross-thread-visible; @tournament.reload.state
  # is not (test thread / Puma thread connection isolation under use_transactional_tests).
  # Task 1's users(:system_admin) swap ensures ensure_tournament_director does not bounce.
  assert_current_path %r{\A/tournament_monitors/\d+\z}, wait: 10
end
```

Note the slight difference from Task 2: this test already has `assert_no_text verification_title` BEFORE the success assertion (it asserts the modal NEVER appeared because the in-range value short-circuits the verification check). The post-redirect `assert_no_text` defense-in-depth from Task 2 would be redundant here, so the URL assertion alone is sufficient. The test still has 2 assertions total (one no-text, one URL) — same shape as before.
  </action>
  <verify>
    <automated>cd /Users/gullrich/DEV/carambus/carambus_bcw && bin/rails test test/system/tournament_parameter_verification_test.rb 2>&1 | tail -10</automated>
  </verify>
  <done>The full file passes 4/4 (`4 runs / NN assertions / 0 failures / 0 errors / 0 skips` — assertion count will be ~10-11 depending on the exact wait/match invocations). Tests 1, 2, 3, 4 are all green.</done>
</task>

<task type="auto">
  <name>Task 4: Regression sweep — verify 36B-05 control + 2 unrelated system tests + integration test suite + full system test smoke</name>
  <files>(read-only verification — no file changes)</files>
  <action>
Run four independent regression checks to prove the change in Tasks 1+2+3 has zero spillover. Step 4 is NEW vs. the prior plan's iter-0 — added because the fixture-user swap (Task 1) is a structural change that COULD theoretically affect any other test that loads the `:admin` fixture (it shouldn't — fixtures are per-test references, not globally swapped — but verify defensively).

1. **36B-05 control (the canonical "Capybara test that doesn't trigger cross-thread DB visibility issue"):**
   ```
   bin/rails test test/system/tournament_reset_confirmation_test.rb
   ```
   Expected: `3 runs / N assertions / 0 failures / 0 errors / 0 skips`. This file is the proof that the project's transactional-tests convention works fine for system tests that use URL/DOM assertions (which 36B-05 already does — see line 120 `assert_current_path tournament_path(@tournament)`).

2. **Two unrelated system tests for breadth — pick the 2 smallest system test files unrelated to tournament-start to minimize runtime while still hitting Devise sign-in + Capybara navigation:**
   ```
   ls -lS test/system/*.rb | tail -2 | awk '{print $NF}'
   ```
   Take the 2 smallest files from that listing and run them:
   ```
   bin/rails test test/system/<smallest>.rb test/system/<second_smallest>.rb
   ```
   Expected: 0 failures / 0 errors. If a file shows pre-existing skips for env-dependent reasons (no Selenium driver, missing fixtures), document them — they are NOT caused by this change.

3. **Integration test suite — NEW step to validate fixture-user swap has no spillover:**
   ```
   bin/rails test test/integration 2>&1 | tail -10
   ```
   Expected: same pass/fail counts as parent commit `8914f567`. Rationale: the fixture-user swap in Task 1 is a per-test reference change (only `tournament_parameter_verification_test.rb` references `:system_admin` instead of `:admin`), so other tests that load `:admin` for their own setup are NOT affected. But verify defensively. If integration tests show NEW failures vs. parent, diagnose before committing — the change may have hit a fixture-loading edge case (e.g., shared helper module that resolved `users(:admin)` differently).

   Confirm pre-existence of any failures by:
   ```
   git stash && bin/rails test test/integration 2>&1 | tail -10 && git stash pop
   ```
   If the failure count is the same with the stash active, the failures are pre-existing and out of scope.

4. **Full system test directory smoke (faster than full suite, broader than 36B-06):**
   ```
   bin/rails test test/system/ 2>&1 | tail -10
   ```
   Expected: `19 runs / NN assertions / 0 failures / 0 errors / NN skips`. Skip count may be > 0 because 36B-05/36B-06 have conditional skips for environments without Selenium-friendly fixtures, but failure count MUST be 0. If failures appear in any system test file other than 36B-06 and they were absent at parent commit `8914f567`, the change has caused regression and must be diagnosed before commit.

If Step 4 reveals pre-existing failures in OTHER system test files (i.e., failures that were already there at HEAD `8914f567` before this change), document them in the SUMMARY but do NOT fix them — they are out of scope.

If Steps 1+2+3+4 all pass, the regression-safety contract is fully satisfied: 36B-06 fixed (Tasks 1+2+3), 36B-05 unchanged, integration tests unchanged, and the broader system test suite shows no spillover.
  </action>
  <verify>
    <automated>cd /Users/gullrich/DEV/carambus/carambus_bcw && bin/rails test test/system/tournament_reset_confirmation_test.rb test/system/tournament_parameter_verification_test.rb 2>&1 | tail -5</automated>
  </verify>
  <done>36B-05 file: 3/3 green. 36B-06 file: 4/4 green. Integration test suite: same pass/fail counts as parent commit `8914f567` (any pre-existing failures documented but not in scope). Broader system test smoke: no NEW failures introduced. test/test_helper.rb, test/application_system_test_case.rb, test/fixtures/users.yml, Gemfile all UNCHANGED (verified by `git diff --stat HEAD -- test/test_helper.rb test/application_system_test_case.rb test/fixtures/users.yml Gemfile` showing zero output).</done>
</task>

</tasks>

<verification>
Run `git diff --stat HEAD` and confirm:
- ONLY `test/system/tournament_parameter_verification_test.rb` has changed
- No other files in `test/`, `config/`, `app/`, or `Gemfile` have changed (specifically: `test/fixtures/users.yml` is UNCHANGED — we use the existing `:system_admin` fixture, not introduce a new one)

Run `git diff HEAD -- test/system/tournament_parameter_verification_test.rb` and confirm the diff:
- Has exactly 1 line CHANGED in the setup block: `users(:admin)` → `users(:system_admin)` (with optional inline comment block adjacent)
- Has exactly 2 lines REMOVED that read `assert_includes STARTED_STATES, @tournament.reload.state`
- Has 2 lines ADDED that contain `assert_current_path %r{\A/tournament_monitors/\d+\z}` (one per test)
- Has 1 ADDED `assert_no_text verification_title` line in the Confirm-click test (defense-in-depth)
- Has explanatory comment blocks above the new setup line and each new assertion citing the auth-bounce diagnosis (Layer 1) and cross-thread visibility issue (Layer 2)

Run the full file: `bin/rails test test/system/tournament_parameter_verification_test.rb` — expect 4 runs / 0 failures / 0 errors / 0 skips.

Run the control file: `bin/rails test test/system/tournament_reset_confirmation_test.rb` — expect 3 runs / 0 failures / 0 errors / 0 skips.

Run the integration suite: `bin/rails test test/integration` — expect same pass/fail counts as parent commit `8914f567`.

Run the broader smoke: `bin/rails test test/system/` — expect no NEW failures vs. parent commit `8914f567`.
</verification>

<success_criteria>
- [ ] `test/system/tournament_parameter_verification_test.rb` setup uses `users(:system_admin)` (NOT `users(:admin)`) — verified by grep
- [ ] `test/system/tournament_parameter_verification_test.rb` passes 4/4 with 0 failures, 0 errors, 0 skips (was 4 runs / 11 assertions / 2 failures pre-fix)
- [ ] `test/system/tournament_reset_confirmation_test.rb` (36B-05 control) still passes 3/3 — no regression
- [ ] `test/integration` test suite shows same pass/fail counts as parent commit `8914f567` (no spillover from fixture-user swap)
- [ ] `test/test_helper.rb` is byte-identical to HEAD `8914f567` (project transactional-tests convention preserved)
- [ ] `test/application_system_test_case.rb` is byte-identical to HEAD `8914f567` (no shared-connection patch, no new mixin)
- [ ] `test/fixtures/users.yml` is byte-identical to HEAD `8914f567` (we use the existing `:system_admin` fixture)
- [ ] `Gemfile` is byte-identical to HEAD `8914f567` (no `database_cleaner` gem)
- [ ] The other 17 system test files in `test/system/` show no NEW failures (pre-existing failures, if any, documented but out of scope per quick-task scope hygiene)
- [ ] extend-before-build SKILL honored: surgical 3-line edit to one test file (1 setup + 2 assertions), NO new test base class / mixin module / helper layer / shared-connection plumbing / new fixture
- [ ] STATE.md "Pending Todos / System-test connection isolation" entry can be moved to "Recently closed" with this quick's commit hash referenced
</success_criteria>

<output>
After completion, create `.planning/quick/260506-lii-fix-system-test-connection-isolation-so-/260506-lii-SUMMARY.md` documenting:

1. Final test counts for the 4 verify runs (36B-06 file, 36B-05 control file, integration suite, broader system test smoke)
2. The 3 specific lines edited in `tournament_parameter_verification_test.rb` (line numbers + before/after diff hunks): setup user swap, Test 3 assertion, Test 4 assertion
3. The two-layer diagnosis paragraph (Layer 1: auth bounce via `ensure_tournament_director` because `users(:admin)` lacks `role:` field; Layer 2: cross-thread visibility under `use_transactional_tests`); explain why both layers had to be fixed and why fixing only one would have left the test red
4. Confirmation that `test_helper.rb`, `application_system_test_case.rb`, `test/fixtures/users.yml`, `Gemfile` are UNCHANGED
5. Self-check that `STARTED_STATES` constant remains in the file (intentional dead-code retention for documentary intent — separate cleanup-pass concern)
6. Push-readiness note: the bcw stack is now at 11 commits ahead (10 pushed earlier this session by the user + 1 from this quick) — this commit can be cherry-picked or re-pushed as appropriate
7. Pending Todos cleanup: STATE.md "System-test connection isolation" entry can be moved from "Pending Todos" to "Recently closed" referencing this quick's commit hash
8. Note for future planners/reviewers: the connection-isolation hypothesis (Layer 2) became untestable AND moot once the auth-bounce fix (Layer 1) was in place — the URL/DOM rewrite routes around it. We retained the URL/DOM rewrite anyway because (a) it's good defensive style for system tests (browser-observable assertions are more reliable cross-thread), (b) reverting to `@tournament.reload.state` would couple the test to AR cross-thread visibility which is fragile, and (c) the rewrite itself is zero-risk to the rest of the codebase.
</output>
