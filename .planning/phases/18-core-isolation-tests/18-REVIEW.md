---
phase: 18-core-isolation-tests
reviewed: 2026-04-11T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - test/system/table_monitor_isolation_test.rb
  - test/fixtures/table_monitors.yml
  - test/fixtures/tables.yml
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-04-11
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Three files reviewed: the new two-session system test (`table_monitor_isolation_test.rb`) and two fixture files that support it. The test architecture is sound — multi-session isolation, DOM-marker-based filter proof, and the ActionCable subscription guard (`wait_for_actioncable_connection`) are well-designed. However, there are several correctness and reliability issues: one critical (SQL injection in a raw `execute` call), one missing fixture column that will cause `has_one :table` to return `nil` in ISOL-03, one vacuous assertion branch in ISOL-02, and minor style/reliability concerns.

## Critical Issues

### CR-01: SQL injection via string interpolation in `connection.execute`

**File:** `test/system/table_monitor_isolation_test.rb:127-133`
**Issue:** The raw SQL string is built with plain Ruby string interpolation. `@tm_b.id` is an integer so the WHERE clause is safe, but the JSON data blob is inserted with `'#{...to_json}'` — single-quoted in SQL, not parameterised. If `.to_json` ever produces a string containing a single quote (e.g., a player name with an apostrophe in future data), the query would break or — in a different data context — be exploitable. Even in tests this pattern is unsafe because it bypasses the database adapter's quoting layer and establishes a bad precedent.
**Fix:** Use `ActiveRecord::Base.sanitize_sql` or the connection's quoting method:
```ruby
json_data = {
  "playera" => { "innings_redo_list" => [5], "result" => 10 },
  "playerb" => { "innings_redo_list" => [3], "result" => 7 }
}.to_json

TableMonitor.connection.execute(
  TableMonitor.sanitize_sql(
    ["UPDATE table_monitors SET data = ? WHERE id = ?", json_data, @tm_b.id]
  )
)
```
Alternatively, since the hash is constant (no user input), use `update_columns` with Rails serializer bypassed via `ActiveRecord::Base.connection.quote`:
```ruby
quoted = TableMonitor.connection.quote(json_data)
TableMonitor.connection.execute(
  "UPDATE table_monitors SET data = #{quoted} WHERE id = #{@tm_b.id}"
)
```

## Warnings

### WR-01: `@tm_a.table` returns `nil` in ISOL-03 — `NoMethodError` on `.location`

**File:** `test/system/table_monitor_isolation_test.rb:236`
**Issue:** ISOL-03 calls `@tm_a.table.location` at line 236. `TableMonitor` declares `has_one :table, dependent: :nullify`. The foreign key lives on `tables.table_monitor_id`. The `setup` block calls `@tm_a.update_columns(game_id: ..., state: "new", data: {})` but never touches the table association. The association is populated only if the `tables` fixture row with `table_monitor_id: 50_000_001` is loaded. However the `tables` fixture (`test/fixtures/tables.yml`) has **no `location_id` column** — only a bare `location: one` YAML reference — and `tables.yml` has no schema annotation to confirm the column name. If the tables fixture fails to load or the `location` foreign key column is named differently than Rails expects, `@tm_a.table` will be `nil` and this line raises `NoMethodError: undefined method 'location' for nil`.

More concretely: the tables fixture uses the shorthand `location: one`, which Rails fixture loading resolves as a foreign key reference. If the `Table` model's `belongs_to :location` association is not named `:location` or the column name differs, the fixture row may not link correctly and `@tm_a.table` may return `nil` at runtime. The test has no guard against this.

**Fix:** Add a defensive assertion before using the association, or reload explicitly:
```ruby
@location = @tm_a.table&.location
raise "Fixture misconfiguration: @tm_a has no associated table/location" if @location.nil?
```
Also add a schema annotation header to `test/fixtures/tables.yml` to document the column that backs the `location:` reference.

### WR-02: ISOL-02 Step 5 has a vacuously-passing branch — filter correctness unverified when event does not arrive

**File:** `test/system/table_monitor_isolation_test.rb:210-221`
**Issue:** The Step 5 block reads:
```ruby
if received
  assert filtered_correctly, "..."
end
refute_selector "#full_screen_table_monitor_#{@tm_b.id}"
```
If `received` is `false` (the score:update event never reached Session A — e.g., because ActionCable routing changed or the JS listener was not installed in time), the `assert filtered_correctly` block is entirely skipped. The test passes silently while providing zero proof that the filter ran. Only the structural `refute_selector` check executes, which is always true on the TM-A scoreboard regardless of filtering. The comment at line 113 says "silently ignored on Session A" but the test does not assert that the event *arrived* — only that it arrived *and* the filter ran. A flaky subscription race will produce a green test with no isolation guarantee.

**Fix:** Assert that the event arrived unconditionally, or time-box the poll and assert:
```ruby
# Poll for event arrival with a known timeout
20.times do
  break if page.evaluate_script("window._wrongScoreUpdateReceived")
  sleep 0.3
end
received = page.evaluate_script("window._wrongScoreUpdateReceived")

assert received,
  "score:update for TM-B never arrived on Session A — " \
  "cannot verify filter behaviour. Check ActionCable subscription timing."
assert page.evaluate_script("window._scoreUpdateFilteredCorrectly"),
  "score:update for TM-B arrived on Session A but filter did NOT block it."
refute_selector "#full_screen_table_monitor_#{@tm_b.id}"
```

### WR-03: `ready!` called with state already `"new"` — valid, but `@tm_b.reload` before `ready!` races with `update_columns`

**File:** `test/system/table_monitor_isolation_test.rb:76-78`
**Issue:** The ISOL-01/04 test calls:
```ruby
@tm_b.reload
@tm_b.ready!
TableMonitorJob.perform_now(@tm_b.id)
```
However, the ISOL-02 test calls `@tm_b.update_columns(state: "ready")` at line 124 before setting up sessions, but then calls `@tm_b.reload` at line 185 and directly calls `TableMonitorJob.perform_now` without calling `ready!`. This is inconsistent: ISOL-01 requires `ready!` to trigger the AASM callbacks (which may fire CableReady broadcasts), whereas ISOL-02 bypasses AASM entirely via `update_columns`. If `ready!` triggers an `after_transition` callback that itself broadcasts, the ISOL-01/04 test fires two broadcasts (one from `ready!` and one from `TableMonitorJob.perform_now`) — the first broadcast could arrive on Session A before the JS warn interceptor is confirmed installed. The comment at line 23 says `update_columns(state: "new")` is used to avoid triggering AASM callbacks, so it is inconsistent to then call `ready!` in ISOL-01.

**Fix:** Either (a) use `update_columns(state: "ready")` in ISOL-01 as well (matching ISOL-02's pattern) to avoid callback-triggered double-broadcasts, or (b) document explicitly why `ready!` is needed and add an assertion that the `_mixupPreventedCount` is exactly 1 (not ≥ 1) to catch double-broadcast cases.

## Info

### IN-01: `sleep 2` used twice without explanation of why 2 seconds is sufficient

**File:** `test/system/table_monitor_isolation_test.rb:91`, `204`
**Issue:** Two `sleep 2` calls are used to "allow time for the broadcast to arrive". The comments acknowledge this (citing "asserting absence of DOM change"), but 2 seconds is an arbitrary constant with no relationship to CI server latency, ActionCable handshake timing, or Capybara's `default_max_wait_time` (set to 10s at line 64 of `application_system_test_case.rb`). On a loaded CI server, 2 seconds may be insufficient, making ISOL-04 and ISOL-02 Step 5 susceptible to false negatives.
**Fix:** Consider using the DOM-marker polling pattern already used in ISOL-02 Step 4 (polling `_scoreUpdateReceived` in a loop with `sleep 0.5`) rather than a fixed sleep. For ISOL-01/04, the `_mixupPreventedCount` marker can be polled similarly.

### IN-02: `table_monitors.yml` missing schema annotation `table_id` column

**File:** `test/fixtures/table_monitors.yml`
**Issue:** The schema annotation block at the top lists all columns present in the `table_monitors` table. There is no `table_id` column listed, which is correct — the foreign key is on `tables.table_monitor_id` (the `has_one` side). However, `tournament_monitor_id` is listed as `:integer` in the schema but no fixture row sets it. This is intentional (optional association), but it means that any test relying on `@tm_a.tournament_monitor.present?` evaluating to `false` is silently correct only because the fixture omits this column. A brief comment to that effect would help future maintainers.
**Fix:** Add a comment above the fixture entries:
```yaml
# tournament_monitor_id intentionally omitted (optional; tests assume nil/absent)
```

### IN-03: Duplicated comment in ISOL-03 (line 218 vs 219)

**File:** `test/system/table_monitor_isolation_test.rb:218-219`
**Issue:** Lines 218 and 219 both describe the same assertion with near-identical text. Line 218 ends mid-thought ("# Session A must not have a TM-B scoreboard container — structural proof") and line 219 repeats it ("# that the session is correctly bound to TM-A only."). The first line appears to be a leftover from an edit.
**Fix:** Remove line 218; keep line 219 as the complete comment.

---

_Reviewed: 2026-04-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
