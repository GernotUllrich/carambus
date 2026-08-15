---
phase: 11-tournamentmonitor-characterization
reviewed: 2026-04-10T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - test/fixtures/tournament_plans.yml
  - test/models/tournament_monitor_t04_test.rb
  - test/models/tournament_monitor_t06_test.rb
  - test/support/t04_tournament_test_helper.rb
  - test/support/t06_tournament_test_helper.rb
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-04-10
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Five files were reviewed: a fixture YAML, two characterization test files, and two test helper modules. The code overall is well-structured with clear intent, good comments explaining the `MIN_ID` limitation, and proper teardown hygiene. No security vulnerabilities or data-loss risks were found.

Three warnings were identified: a shared mutable class-level counter that can cause ID collisions across test runs, a `TEST_ID_BASE` constant defined identically in two separate modules (silent duplication that becomes a bug if one is changed), and a `teardown` block in the T04 test that calls cleanup before ensuring the inline-created `TournamentMonitor` from `ensure` is destroyed (ordering hazard).

Four info items cover minor style/reliability improvements: an unguarded `high_id_game` local variable assigned but never used, duplicate state-check assertions in AASM transition tests, a hardcoded player count assumption documented only via a comment, and a minor inconsistency in how T06 tests re-use `game.game_participations.find_by` without reloading after `game.update!`.

---

## Warnings

### WR-01: Shared `@@t04_test_counter` / `@@t06_test_counter` class-level variables cause ID collisions across parallel or repeated test runs

**File:** `test/support/t04_tournament_test_helper.rb:11` and `test/support/t06_tournament_test_helper.rb:11`

**Issue:** Both helpers use `@@` class variables (`@@t04_test_counter`, `@@t06_test_counter`) as counters for generating unique IDs. These are module-level class variables, meaning their state persists across the entire test suite process — they are never reset between tests. If the test suite is run multiple times in the same process (e.g., `spring` or `guard`-based continuous testing), or if the counter reaches a high enough value, the computed `tournament_id` (`TEST_ID_BASE + 20_000 + counter * 200`) can grow without bound. More critically, both counters start at `0` and increment globally; if a test crashes before teardown runs, the counter is already incremented, which is fine, but the generated ID is permanently "consumed" even though the record may not have been cleaned up. In test environments with transactional fixtures, this can cause `ActiveRecord::RecordNotUnique` on reuse. The practical risk is low with small test suites, but it is a latent instability.

**Fix:** Use a `SecureRandom`-based or time-seeded offset instead of a shared mutable counter, or scope the counter to the instance:

```ruby
# In T04TournamentTestHelper
def create_t04_tournament_with_seedings(player_count, tournament_attrs = {})
  # Use a random offset to avoid collision without shared mutable state
  unique_offset = rand(1_000..9_999)
  tournament_id = TEST_ID_BASE + 20_000 + unique_offset
  # ...
end
```

Alternatively, freeze the counter to a per-test-class instance variable using `setup`:

```ruby
# In test class setup
@t04_counter = (self.class.instance_variable_get(:@t04_counter) || 0) + 1
self.class.instance_variable_set(:@t04_counter, @t04_counter)
```

---

### WR-02: `TEST_ID_BASE` constant defined identically in both helper modules — silent divergence risk

**File:** `test/support/t04_tournament_test_helper.rb:9` and `test/support/t06_tournament_test_helper.rb:12`

**Issue:** Both `T04TournamentTestHelper` and `T06TournamentTestHelper` define `TEST_ID_BASE = 50_000_000` independently. This creates a silent duplication: if one module's constant is updated and the other is not, the helpers will use different base IDs but both claim to use `50_000_000`. This could lead to ID range collisions between T04 and T06 test data. The T06 helper even references this constant in the T06 test file (`TEST_ID_BASE + 30_800 + @tournament.id`) — if the test class includes only `T06TournamentTestHelper`, the constant is resolved from `T06TournamentTestHelper::TEST_ID_BASE`, but if both helpers are included in the same class, Ruby resolves constants via the include chain in reverse order, and whichever module was included last wins.

**Fix:** Extract the shared constant into a single shared module or into `test_helper.rb`:

```ruby
# test/support/tournament_test_constants.rb
module TournamentTestConstants
  MIN_ID     = 50_000_000  # matches ApplicationRecord::MIN_ID
  TEST_ID_BASE = MIN_ID
end

# Then in each helper:
include TournamentTestConstants
# Remove the local TEST_ID_BASE definition
```

---

### WR-03: `teardown` in T04 test destroys tournament before `ensure` cleanup of the inline-created `TournamentMonitor`

**File:** `test/models/tournament_monitor_t04_test.rb:37-42`

**Issue:** The `teardown` block calls `cleanup_t04_tournament(@test_data)`, which destroys the tournament and its associations. The test `"ApiProtectorTestOverride allows saving local TournamentMonitor"` (line 278) creates an additional `TournamentMonitor` with `id: local_id` and cleans it up in an `ensure` block. However, `teardown` runs after the test body's `ensure` for that test, but before the next test's `setup`. If `cleanup_t04_tournament` is called while the extra `TournamentMonitor` is still associated with the tournament (e.g., if the `ensure` inside the test raised its own error), the FK cascade may fail or leave an orphan. The `ensure` inside the test does `TournamentMonitor.find_by(id: local_id)&.destroy` — this is safe in normal flow, but if that `find_by` itself raises (e.g., database connection issue), the tournament cleanup in `teardown` will attempt to destroy a tournament that still has a `tournament_monitor` FK reference.

**Fix:** Add a guard in `cleanup_t04_tournament` to destroy any `TournamentMonitor` records before destroying the tournament, or move the extra TM cleanup to `teardown` rather than relying on the test-level `ensure`:

```ruby
# In cleanup_t04_tournament (t04_tournament_test_helper.rb line 82)
# Before tournament.destroy:
TournamentMonitor.where(tournament_id: tournament.id).destroy_all
tournament.reload.tournament_monitor&.destroy  # already present, but redundant after above
tournament.destroy
```

---

## Info

### IN-01: Assigned but unused local variable `high_id_game` in two tests

**File:** `test/models/tournament_monitor_t06_test.rb:365` and `test/models/tournament_monitor_t06_test.rb:381`

**Issue:** In the tests `"group_phase_finished? returns false when high-ID group games exist without ended_at"` and `"group_phase_finished? returns true when all high-ID group games have ended_at"`, the return value of `@tournament.games.create!(...)` is assigned to `high_id_game` (line 365) and `high_id_game` (line 381) but the variable is never referenced again. This is dead code — the variable name implies intent to assert something about it, but no assertions use it.

**Fix:** Either remove the variable assignment (`@tournament.games.create!(...)` alone is sufficient) or add an assertion to confirm the game was created correctly:

```ruby
# Option A: drop the assignment
@tournament.games.create!(id: TEST_ID_BASE + 30_800 + @tournament.id, gname: "group1:high-test", group_no: 1)

# Option B: assert on it
high_id_game = @tournament.games.create!(...)
assert high_id_game.persisted?, "High-ID game should be persisted"
```

---

### IN-02: Duplicate state assertion pattern in T04 and T06 AASM transition tests

**File:** `test/models/tournament_monitor_t04_test.rb:56-70` and `test/models/tournament_monitor_t06_test.rb:59-73`

**Issue:** Several tests assert the state immediately after `start_playing_groups!` with `assert_equal "playing_groups", @tm.state`, and then transition to `playing_finals`. This initial re-assertion of an already-asserted state (from the previous test or setup) adds noise without adding coverage. For example in `"T04 can transition from playing_groups to playing_finals"` (line 62-70), the first `assert_equal "playing_groups"` is redundant because `start_playing_groups!` on line 58 already transitions to that state; the test's purpose is the transition to `playing_finals`.

**Fix:** Remove the redundant intermediate assertions to keep tests focused:

```ruby
test "T04 can transition from playing_groups to playing_finals" do
  @tm.start_playing_groups!
  # Assert the transition we care about, not the intermediate state
  @tm.start_playing_finals!
  assert_equal "playing_finals", @tm.state
end
```

This is minor — the existing pattern is not incorrect, just noisy.

---

### IN-03: `create_t04_tournament_with_seedings` accepts `player_count` but the fixture plan hardcodes 5 players

**File:** `test/support/t04_tournament_test_helper.rb:21`

**Issue:** The method signature accepts a `player_count` parameter with the comment "caller should pass player_count: 5 to match the fixture plan." But the method creates exactly `player_count` players regardless of what the fixture plan expects. If a caller passes a count other than 5, the `do_reset_tournament_monitor` call in the test `setup` will fail or silently mismatch. The method API implies flexibility (a parameter), but the fixture constraint makes any other value incorrect. This is a documentation/design ambiguity that could mislead future test authors.

**Fix:** Either remove the `player_count` parameter and hardcode 5 (since the fixture mandates it), or add a guard:

```ruby
def create_t04_tournament_with_seedings(player_count = 5, tournament_attrs = {})
  raise ArgumentError, "T04 fixture plan requires exactly 5 players, got #{player_count}" unless player_count == 5
  # ...
end
```

---

### IN-04: T06 result pipeline tests do not reload `gp_a`/`gp_b` before the `find_by` call following `game.update!`

**File:** `test/models/tournament_monitor_t06_test.rb:247-275`

**Issue:** In the tied-result test (line 247), `gp_a` and `gp_b` are fetched from `game.game_participations.find_by(role: ...)` before `game.update!(data: {})` is called. The `game.update!` call changes the game's `data` attribute, which does not affect `gp_a`/`gp_b` (they are separate records). However, the pattern is subtly fragile: if `update_game_participations_for_game` internally re-queries `game.game_participations` via the game object, and `game` was not reloaded after `update!`, there could be a stale association cache. The existing tests in the "winner" case reload with `gp_a.reload` and `gp_b.reload` after the call, which is correct. The tied-results test also calls `.reload` (lines 271-272), so this is already handled. The issue is only that `gp_a`/`gp_b` are fetched before `game.update!`, which may leave the game's associations dirty in some edge cases.

**Fix:** Minor — fetch game participations after `game.update!` to ensure a clean state:

```ruby
game.update!(data: {})
gp_a = game.game_participations.reload.find_by(role: "playera")
gp_b = game.game_participations.find_by(role: "playerb")
```

---

_Reviewed: 2026-04-10_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
