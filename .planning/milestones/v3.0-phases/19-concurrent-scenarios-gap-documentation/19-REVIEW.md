---
phase: 19-concurrent-scenarios-gap-documentation
reviewed: 2026-04-11T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - test/system/table_monitor_isolation_test.rb
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 19: Code Review Report

**Reviewed:** 2026-04-11
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Phase 19 added two new test methods — `CONC-01` (rapid-fire alternating broadcasts) and `CONC-02` (three simultaneous sessions) — to the existing `TableMonitorIsolationTest` file, along with supporting setup/teardown logic for the third TableMonitor (`@tm_c`). The overall structure is well-documented and the test strategy is sound. Two issues were found:

1. A vacuousness gap in CONC-02 Rounds 2 and 3 where the `_mixupPreventedCount` guard (which proves broadcasts actually arrived) is present in Round 1 but absent in Rounds 2 and 3. Without it, the negative assertions in those rounds are vacuous — if the broadcast never arrived, `refute_selector` passes trivially.

2. The `@table_c` record created with `find_or_create_by!` may carry stale FK data on re-runs because the initialization block only executes during creation, not when the record already exists. Unlike `@tm_c`, there is no `update_columns` call after `find_or_create_by!` to enforce correct state.

---

## Warnings

### WR-01: CONC-02 Rounds 2 and 3 negative assertions are vacuous — mix-up counter not checked

**File:** `test/system/table_monitor_isolation_test.rb:431-437` and `449-455`
**Issue:** In CONC-02, Round 1's negative assertions verify that Sessions B and C actually received the TM-A broadcast by asserting `window._mixupPreventedCount > 0` before the `refute_selector`. This is the correct pattern — it proves the filter ran (non-vacuous). Rounds 2 and 3 omit this counter check entirely: they `sleep 2` then directly call `refute_selector`. If the broadcast never reaches Sessions A/C (Round 2) or Sessions A/B (Round 3), those `refute_selector` calls pass trivially — they assert the absence of elements that were never going to appear, even if the broadcast was silently lost. This makes the Round 2 and 3 negative assertions weaker than Round 1's.

The gap is especially noticeable for Round 3 (TM-C broadcast): Session A and Session B's counters are reset once in Step 2 and then incremented by Round 1 (TM-A) and Round 2 (TM-B) broadcasts. A bare `refute_selector` in Round 3 does not distinguish between "filter blocked the broadcast" and "broadcast never arrived".

**Fix:** Add the counter check to Rounds 2 and 3, mirroring Round 1. For Round 2 (Sessions A and C):

```ruby
# Round 2 negative: Sessions A and C must not have TM-B content.
[:scoreboard_a, :scoreboard_c].each do |session_name|
  in_session(session_name) do
    sleep 2
    count = page.evaluate_script("window._mixupPreventedCount")
    # Counter accumulates across rounds — Round 1 already added >=1; Round 2 TM-B
    # broadcast should add at least 1 more. Use a round-specific baseline if needed,
    # or simply assert count increased by checking > previous_count (store before Round 2).
    # Simplest fix: assert at least one filtered event has arrived in this session overall.
    assert count.to_i > 0,
      "CONC-02: #{session_name} should have filtered at least one cross-table broadcast, " \
      "but counter is #{count}"
    refute_selector "#full_screen_table_monitor_#{@tm_b.id}"
  end
end
```

Apply the same pattern for Round 3 (Sessions A and B) with `refute_selector "#full_screen_table_monitor_#{@tm_c.id}"`.

Note: Because the counter accumulates across all rounds, the `> 0` assertion for Rounds 2/3 is satisfied by any prior round's filter events. For a stricter proof that the Round-N broadcast specifically arrived, capture the counter value before each round and assert it increased after the round.

---

### WR-02: `@table_c` initialization block only runs on create — stale FK data on re-runs

**File:** `test/system/table_monitor_isolation_test.rb:40-45`
**Issue:** `find_or_create_by!(id: 50_000_003) do |t| ... end` executes the block only when the record is being created. On subsequent test runs where `@table_c` already exists (teardown destroys it, but if teardown is interrupted or a prior run left partial state), the `table_monitor_id`, `location_id`, and `table_kind_id` attributes in the block are ignored. Unlike `@tm_c`, which calls `update_columns` after `find_or_create_by!` to enforce correct state regardless of whether the record was found or created, `@table_c` has no such enforcement step.

If `@table_c` exists with a stale or missing `table_monitor_id`, `visit_scoreboard` will fail with an FK/association error (per the Research Pitfall 2 note in the comment at line 39), producing a confusing failure that is not obviously connected to the `find_or_create_by!` behavior.

**Fix:** Add an `update_columns` call after the `find_or_create_by!` to enforce the correct FK values unconditionally:

```ruby
@table_c = Table.find_or_create_by!(id: 50_000_003) do |t|
  t.name = "Table Three"
  t.table_monitor_id = 50_000_003
  t.location_id = @tm_a.table.location.id
  t.table_kind_id = 50_000_001
end
# Enforce correct FK values on both create and find paths (idempotency).
@table_c.update_columns(
  table_monitor_id: 50_000_003,
  location_id: @tm_a.table.location.id
)
```

---

## Info

### IN-01: `rapid_fire_count` "must be even" invariant is undocumented in code — no guard

**File:** `test/system/table_monitor_isolation_test.rb:267`
**Issue:** The comment on line 267 states "RAPID_FIRE_COUNT must be even so both TMs fire equally (3 broadcasts each)." The value is a local variable (`rapid_fire_count = 6`), not a constant, and there is no assertion or raise that enforces the even invariant. If a future developer changes the value to an odd number, the `expected_b_broadcasts = rapid_fire_count / 2` calculation (integer division) silently produces an asymmetric lower bound that does not match the actual broadcast count for TM-B.

**Fix:** Add a guard at the top of the test, or promote the variable to a local constant with an assertion:

```ruby
rapid_fire_count = 6
raise "rapid_fire_count must be even" unless rapid_fire_count.even?
```

---

### IN-02: CONC-02 Rounds 2/3 `sleep 2` blocks execute sequentially — wall-clock cost accumulates

**File:** `test/system/table_monitor_isolation_test.rb:431-437` and `449-455`
**Issue:** Each `in_session` block is entered sequentially. In Rounds 2 and 3, two sessions each sleep 2 seconds, adding 4 seconds of wall-clock time per round (8 additional seconds beyond Round 1). This is inherent to the sequential `in_session` API and cannot be parallelized without test framework changes. No action required, but documenting for awareness when test suite run time is evaluated.

**Fix:** No change needed — this is a known limitation of the sequential session API. The comment pattern (already present in ISOL-01 and CONC-01) explaining why `sleep` is acceptable should be replicated in Rounds 2 and 3 for consistency:

```ruby
# sleep 2: asserting absence of DOM change — no element to poll (see Research Pitfall 4).
sleep 2
```

---

_Reviewed: 2026-04-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
