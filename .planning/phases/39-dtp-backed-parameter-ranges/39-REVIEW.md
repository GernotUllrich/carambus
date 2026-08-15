---
phase: 39-dtp-backed-parameter-ranges
reviewed: 2026-05-06T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - app/controllers/tournaments_controller.rb
  - app/models/discipline.rb
  - test/fixtures/discipline_tournament_plans.yml
  - test/fixtures/seedings.yml
  - test/fixtures/tournaments.yml
  - test/models/discipline_test.rb
  - test/system/tournament_parameter_verification_test.rb
findings:
  critical: 0
  warning: 3
  info: 6
  total: 9
status: issues_found
---

# Phase 39: Code Review Report

**Reviewed:** 2026-05-06
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 39 replaces three hardcoded constants (`UI_07_SHARED_RANGES`, `UI_07_DISCIPLINE_SPECIFIC_RANGES`, `DISCIPLINE_PARAMETER_RANGES`) with a DTP-query-backed `Discipline#parameter_ranges(tournament:)` method. The new code is clean, well-commented, and the test coverage is thorough — all six early-return branches plus RQ-01/RQ-03 are covered, and the system test plus an `assert_nothing_raised` cross-product test guard the public contract.

The refactor is correct in its primary control flow. However, three correctness-adjacent warnings stand out:

1. The class-walk algorithm permits a numeric (Karambol klein) starting class to walk into the Roman-numeral (Karambol groß) suffix `["I","II","III"]` of `PLAYER_CLASS_ORDER` because they are concatenated into one array. The model comment explicitly notes that "no discipline mixes both sets in the live DB," so this is currently latent — but a single seeded DTP row in the wrong family would silently produce an out-of-domain range without raising. (See WR-01.)
2. `tournament.seedings.count` always issues a `COUNT(*)` SQL query even when the `seedings` association is preloaded, and is invoked once per `parameter_ranges` call (and a second time when the walk fires). Not in v1 perf scope, but worth flagging because the controller-side `verify_tournament_start_parameters` is on the critical-path of `start`. (See WR-02.)
3. The DTP fixture file uses IDs `9_000_001..9_000_005`, which fall **below** `MIN_ID = 50_000_000`. `DisciplineTournamentPlan` includes `LocalProtector`. This works in the test DB only because `test_helper.rb` prepends `LocalProtectorTestOverride`. The test would fail loudly outside the test process — which is the desired behavior — but the `# Test DB is rebuilt from these fixtures, so global ID range (id < 50_000_000) is safe.` comment in the fixture file is misleading (it's the LocalProtector override, not the DB rebuild, that makes this safe). (See IN-04.)

The remaining items are stylistic / maintainability suggestions.

## Warnings

### WR-01: class-walk crosses PLAYER_CLASS_ORDER class-system boundary

**File:** `app/models/discipline.rb:55,99-106`
**Issue:** `PLAYER_CLASS_ORDER = %w[7 6 5 4 3 2 1 I II III]` concatenates the numeric Karambol-klein classes (7..1) and the Roman Karambol-groß classes (I..III) in one array. The walk in `lookup_dtp_with_class_walk` does not stop at the boundary between "1" and "I":

```ruby
PLAYER_CLASS_ORDER[(starting_index + 1)..].each do |candidate|
  hit = base_scope.find_by(player_class: candidate)
  return hit if hit
end
```

A Karambol-klein tournament starting at class "5" therefore walks "4"→"3"→"2"→"1"→"I"→"II"→"III". The model comment says "in der Live-DB mischt keine Disziplin beide Sätze" — so today the walk silently ends at `nil` because no Karambol-klein DTP row is keyed by `"I"`. But the coupling is implicit: a single seeded row with the "wrong" class system would silently feed an out-of-domain range to the verification UI without raising or logging.

**Fix:** Either (a) split into two separate ordered arrays and pick the right one based on the starting class, or (b) restrict the walk slice to the same class-family as the starting class. Minimal change:

```ruby
PLAYER_CLASS_NUMERIC = %w[7 6 5 4 3 2 1].freeze
PLAYER_CLASS_ROMAN   = %w[I II III].freeze

def lookup_dtp_with_class_walk(tournament)
  # ... base_scope ...
  exact = base_scope.find_by(player_class: tournament.player_class)
  return exact if exact

  family = if PLAYER_CLASS_NUMERIC.include?(tournament.player_class.to_s)
    PLAYER_CLASS_NUMERIC
  elsif PLAYER_CLASS_ROMAN.include?(tournament.player_class.to_s)
    PLAYER_CLASS_ROMAN
  end
  return nil unless family

  starting_index = family.index(tournament.player_class.to_s)
  family[(starting_index + 1)..].each do |candidate|
    hit = base_scope.find_by(player_class: candidate)
    return hit if hit
  end
  nil
end
```

If the cross-family walk is intentional (defensible — both arrays are "worst→best" within their family, and the boundary "1"→"I" never gives a real hit anyway), please add an explicit unit test asserting the boundary behavior so a future contributor cannot quietly remove the comment without the regression surfacing in CI.

---

### WR-02: `tournament.seedings.count` may issue redundant SQL on the start-tournament critical path

**File:** `app/models/discipline.rb:91-94`
**Issue:** The DTP base_scope filters by `players: tournament.seedings.count`. Calling `.count` on an `ActiveRecord::Relation` always issues `SELECT COUNT(*)`, even when `seedings` has already been loaded (e.g., via `includes(:seedings)`). This method is invoked by `TournamentsController#start` on every form submit (line 312), and it's also used inside `tournament_monitor.html.erb` (likely — to compute `@verification_failure` previewing). Each call now issues at least 2 SQL statements (the COUNT + the DTP find_by), and 2..1+`PLAYER_CLASS_ORDER.length-index` if the walk fires on a missing DTP row.

**Fix:** Use `.size` instead of `.count` so Rails uses the cached collection when loaded and falls back to COUNT(*) when not:

```ruby
.where(players: tournament.seedings.size)
```

This is a single-line change. (Also — performance issues are explicitly out of v1 review scope per the agent rules, so I'm flagging this as a correctness-adjacent warning rather than a perf finding: the same `parameter_ranges` call happens inside the system test's `setup` block via `tournament.discipline.parameter_ranges(tournament: @tournament).empty?`, and the system test's `safe_value = ...parameter_ranges(...)[:balls_goal].first + 5` line — repeated calls during a single test multiply unnecessarily.)

---

### WR-03: `verify_tournament_start_parameters` silently no-ops when the field's range is missing

**File:** `app/controllers/tournaments_controller.rb:1011-1027`
**Issue:** The loop iterates `UI_07_FIELDS` and skips any field whose range key is missing from the returned hash:

```ruby
UI_07_FIELDS.each_with_object([]) do |field, failures|
  range = ranges[field]
  next unless range
  ...
end
```

Phase 39's `parameter_ranges` always returns either `{}` or a hash containing **both** `:balls_goal` AND `:innings_goal` (because `range_from_canonical(0)` returns `nil` AND the method short-circuits to `{}` only when **both** are nil — line 79 in discipline.rb: `return {} if balls_range.nil? && innings_range.nil?`). But there is a defensive gap: if a future DTP row has e.g. `points=250, innings=0`, then `balls_range = 187..250` AND `innings_range = nil`, so `parameter_ranges` returns `{balls_goal: 187..250}` only, and the verification will check balls_goal but silently skip innings_goal. That is probably the intended semantic (a "lenient OR" in the comment), but it's not explicit in the controller-side guard or covered by a test.

**Fix:** Add an explicit unit test for the asymmetric case `points > 0, innings == 0` (and the mirror `points == 0, innings > 0`) — both currently uncovered by the 8 D-16 tests. The simplest assertion:

```ruby
test "parameter_ranges returns balls_goal-only when innings is zero (asymmetric DTP)" do
  # New fixture: points=250, innings=0 -> {balls_goal: 187..250}
  # Verifies range_from_canonical(0) -> nil pruning preserves balls_goal alone
end
```

This closes the documented behavior of `range_from_canonical` (line 110-117) against unintended drift.

## Info

### IN-01: Magic number `0.75` in two places

**File:** `app/models/discipline.rb:58,116`
**Issue:** `REDUCED_FACTOR = 0.75` is well-named, but the comment "Standard-Praxis: 80/20 → 60/15" cites the canonical `(80*0.75=60, 20*0.75=15)` math without explaining why the floor — not round — is used. A future contributor may flip `floor` to `round` (raising the lower bound by 1 in some cases like `15*0.75=11.25` → 11 vs 11) without realizing that test fixture rows like `points=250, innings=15` were chosen specifically to exercise the floor behavior.
**Fix:** Add one more sentence to the `range_from_canonical` comment, e.g. "`floor` is intentional — `round` would raise the lower bound by 0.5 in some cases and break the D-16(a) test fixture (15*0.75=11.25 → floor 11)."

### IN-02: `frozen_string_literal: true` missing from controllers/tournaments_controller.rb (already present — false alarm; leaving for completeness)

**File:** `app/controllers/tournaments_controller.rb:1`
**Issue:** Already has `# frozen_string_literal: true`. No change needed.

### IN-03: Inconsistent string format for ID comments in fixture files

**File:** `test/fixtures/seedings.yml:14-16, 47-52`
**Issue:** The ID-range documentation block uses `50_001_xxx` (3 underscores) and `50_002_xxx`, but Phase 39 additions inline use `50_000_300 + tidx * 10 + i` and `50_000_400 + i` (raw expressions). The header comment block does not document the new `50_000_300+` and `50_000_400+` ranges added in Phase 39.
**Fix:** Extend the header comment block to enumerate the Phase 39 ID ranges:

```
# ID ranges (Phase 39 additions):
#   Phase 39 tournaments:        50_000_200..50_000_207
#   Phase 39 seedings (5-each):  50_000_300..50_000_369  (7 tournaments x 5 seedings, sparse)
#   Phase 39 seedings (zero):    50_000_400..50_000_405  (6 seedings for t06_6 plan)
```

### IN-04: DTP fixture comment misattributes safety mechanism

**File:** `test/fixtures/discipline_tournament_plans.yml:3`
**Issue:** Comment says "Test DB is rebuilt from these fixtures, so global ID range (id < 50_000_000) is safe." The actual safety mechanism is `LocalProtectorTestOverride` in `test_helper.rb:38-45`, which prepends a no-op `disallow_saving_global_records` to `LocalProtector` for the entire test process. DB rebuild is orthogonal — `LocalProtector` would still raise on save even on a fresh DB if the override were not active.
**Fix:** Reword the comment to:

```yaml
# Test DB uses LocalProtectorTestOverride (test_helper.rb:38-45) which no-ops
# the LocalProtector before_save guard, so global ID range (id < MIN_ID) is safe
# in fixtures even though DisciplineTournamentPlan includes LocalProtector.
```

### IN-05: Tournament fixture `local_no_plan` may not satisfy upstream assumptions

**File:** `test/fixtures/tournaments.yml:171-184`
**Issue:** The `local_no_plan` fixture deliberately leaves `tournament_plan_id:` blank. Cross-checking with `app/models/tournament.rb:76` (`belongs_to :tournament_plan, optional: true`), this is permitted. However, the comment block on the `local` fixture (lines 59-62) notes that `tournament_monitor.html.erb:40 raises NoMethodError on @tournament.tournament_plan.rulesystem` without a plan. The Phase 39 system test `tournament without tournament_plan skips verification (defensive)` (lines 184-195 of `test/system/tournament_parameter_verification_test.rb`) calls `visit_monitor_or_skip`, which requires the page not to 500 — but with `tournament_plan_id: nil`, line 40 of the ERB template will likely raise.

The test has a `skip "tournament_monitor page renders 500 in test env"` guard, so it would fail-skip rather than fail-fail. That makes the test silent on its actual assertion. Either the ERB template was updated to handle nil `tournament_plan` (worth verifying), or this test currently always skips.

**Fix:** Either confirm the ERB template handles `@tournament.tournament_plan.nil?` (and document the line in the test), OR convert `visit_monitor_or_skip` into `visit_monitor_or_fail` so the test cannot quietly pass without exercising its assertion. A minimal targeted check:

```bash
grep -n 'tournament_plan' app/views/tournaments/tournament_monitor.html.erb | head -20
```

### IN-06: Controller still has `Rails.logger.info "🔍 [START] ..."` debug output (pre-existing, not introduced by Phase 39)

**File:** `app/controllers/tournaments_controller.rb:366,368,373,379,381`
**Issue:** Five `Rails.logger.info "🔍 [START] ..."` lines remain in the `start` action. Phase 39 did not introduce these (commit `e362f8a9` did, per the comment trail), and removing them is out of scope. Flagging only because the agent guideline requires noting debug artifacts. Recommend leaving them alone — they're load-bearing for the `quick-260506-k3t` debugging trail.
**Fix:** No action required for Phase 39. Capture in a future cleanup phase once the unprotected/AASM `start_tournament!` save-pattern is fully stabilized.

---

_Reviewed: 2026-05-06_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
