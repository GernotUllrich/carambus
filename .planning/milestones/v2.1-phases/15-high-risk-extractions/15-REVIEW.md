---
phase: 15-high-risk-extractions
reviewed: 2026-04-10T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - app/services/tournament_monitor/result_processor.rb
  - app/services/tournament_monitor/table_populator.rb
  - app/models/tournament_monitor.rb
  - lib/tournament_monitor_state.rb
  - test/services/tournament_monitor/result_processor_test.rb
  - test/services/tournament_monitor/table_populator_test.rb
findings:
  critical: 3
  warning: 7
  info: 5
  total: 15
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-04-10
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

This phase extracts the result-processing and table-population logic from the `TournamentMonitor` god-object into two POROs (`ResultProcessor` and `TablePopulator`) plus a lean model shell. The structural extraction is sound — delegation wrappers are correctly placed, the PORO pattern is documented, and AASM events are fired on `@tournament_monitor`. However, there are three critical issues: a swallowed `StandardError` in `add_result_to` that silently discards ranking data, a hardcoded developer e-mail address in production-path code, and a potential nil-dereference crash in `update_ranking`. Seven warnings cover unsafe data access patterns, a silent error swallow inside the transaction, and test coverage gaps that would not catch the nil-crash. Five informational items address code quality.

---

## Critical Issues

### CR-01: Swallowed exception in `add_result_to` silently corrupts ranking data

**File:** `app/services/tournament_monitor/result_processor.rb:445`

**Issue:** The `rescue StandardError => e` at the end of `add_result_to` rescues the exception into a local variable `e` and does nothing — not even logs it. When `add_result_to` raises (e.g., because `gp.points`, `gp.result`, or `gp.innings` are nil), the entry for that player is partially built in the accumulator hash and the loop continues. The caller (`accumulate_results`) never knows an entry was skipped, so the final `data["rankings"]` is silently wrong.

```ruby
# Current (line 445-447)
rescue StandardError => e
  e   # ← assigned but never used; exception is swallowed
end
```

**Fix:** At minimum log the error. Better: let it propagate so `accumulate_results`'s own rescue can handle it uniformly.

```ruby
rescue StandardError => e
  Rails.logger.error "[add_result_to] gp=#{gp.id} #{e.class}: #{e.message}" if TournamentMonitor::DEBUG
  raise  # let accumulate_results rescue catch it
end
```

---

### CR-02: Hardcoded developer e-mail in production code path

**File:** `app/services/tournament_monitor/result_processor.rb:485`

**Issue:** `write_finale_csv_for_upload` unconditionally seeds the recipients list with a hardcoded personal Gmail address. This fires in production every time a tournament ends.

```ruby
emails = ["gernot.ullrich@gmx.de"]   # line 485
```

**Fix:** Move the address to Rails credentials/config and gate it behind an environment check, or remove it entirely and rely solely on `current_admin` / `current_user`.

```ruby
emails = []
emails << Rails.application.credentials.dig(:csv_result_recipient) if Rails.env.production?
```

---

### CR-03: Unguarded nil dereference in `update_ranking` crashes when a player_id cannot be resolved

**File:** `app/services/tournament_monitor/result_processor.rb:190`

**Issue:** `player_id_from_ranking` can return `nil` (the underlying `RankingResolver` returns `nil` for unresolvable rules). The next two lines use the return value as a hash key and pass it to an ActiveRecord `where`, both of which succeed, but `rankings["total"][player_id.to_s]` (where `player_id` is nil) becomes `rankings["total"][""]`, and then `.["rank"] = ix` is called on whatever is stored there. If that slot is `nil`, the method raises `NoMethodError: undefined method '[]=' for nil`. There is no rescue in `update_ranking` itself.

```ruby
# line 190-191
player_id = tm.player_id_from_ranking(rule_part, executor_params: executor_params)
rankings["total"][player_id.to_s]["rank"] = ix   # crashes if rankings["total"][""] is nil
```

**Fix:** Guard the resolution result before using it.

```ruby
player_id = tm.player_id_from_ranking(rule_part, executor_params: executor_params)
if player_id.present? && rankings["total"][player_id.to_s].present?
  rankings["total"][player_id.to_s]["rank"] = ix
  @tournament_monitor.tournament.seedings
    .where(seedings: { player_id: player_id }).first&.update(rank: ix + 1)
else
  Rails.logger.warn "[update_ranking] Could not resolve player for rule #{rule_part.inspect}, skipping"
end
```

---

## Warnings

### WR-01: CSV file uses wrong tournament ID in filename (result email sends wrong attachment)

**File:** `app/services/tournament_monitor/result_processor.rb:482,509,511`

**Issue:** The CSV is written to `tmp/result-#{tournament.cc_id}.csv` (line 482) but the mailer attachment is built with `result-#{tournament.id}.csv` (lines 509/511). These two IDs differ whenever `cc_id != id`, so `NotifierMailer.result` will attempt to attach a file that does not exist, raising `Errno::ENOENT` for every recipient.

```ruby
# line 482 — written with cc_id
f = File.new("#{Rails.root}/tmp/result-#{@tournament_monitor.tournament.cc_id}.csv", "w")

# lines 509/511 — read with id (different!)
"result-#{@tournament_monitor.tournament.id}.csv",
"#{Rails.root}/tmp/result-#{@tournament_monitor.tournament.id}.csv"
```

**Fix:** Use a single consistent identifier for both the write and the read paths.

```ruby
csv_path = "#{Rails.root}/tmp/result-#{@tournament_monitor.tournament.cc_id}.csv"
# ...write to csv_path...
NotifierMailer.result(
  @tournament_monitor.tournament,
  recipient,
  "Turnierergebnisse - #{@tournament_monitor.tournament.title}",
  File.basename(csv_path),
  csv_path
).deliver
```

---

### WR-02: `report_result` uses `try do` inside `TournamentMonitor.transaction` — rescue swallows error and raises `Rollback` silently

**File:** `app/services/tournament_monitor/result_processor.rb:35,117-120`

**Issue:** The outer `rescue StandardError => e` block logs at `Rails.logger.info` (not `error`) and then raises `ActiveRecord::Rollback`. When an unexpected error occurs — including the nil crash in CR-03 — the developer sees only a single `info`-level line. The rollback is not surfaced to any caller. This makes diagnosing production failures very hard.

**Fix:** Log at error level and, at minimum in non-production environments, re-raise or add the error to the tournament_monitor's data for visibility.

```ruby
rescue StandardError => e
  Rails.logger.error "[report_result] #{e.class}: #{e.message}\n#{e.backtrace&.first(10).join("\n")}"
  raise ActiveRecord::Rollback
end
```

---

### WR-03: `finalize_game_result` state guard fires after `finish_match!` may have already changed state — double-check is fragile

**File:** `app/services/tournament_monitor/result_processor.rb:269-272`

**Issue:** `finalize_game_result` checks `table_monitor.state` against `%w[final_match_score final_set_score]`, but this check happens *after* `finish_match!` was already called inside the lock. The `finish_match!` AASM transition moves `table_monitor` to a different state (`match_finished` or similar). Unless `table_monitor` is reloaded before this check, the in-memory state reflects the pre-`finish_match!` state (because `table_monitor.reload` was called inside the lock, after `write_game_result_data`, before `finish_match!`). After `finish_match!` runs, `table_monitor` is in the new state. Whether `finalize_game_result` correctly reads that depends on whether Rails AASM updates the in-memory object — which it does, but the guard would then always fail, causing the ClubCloud upload and `update_game_participations_for_game` to be skipped silently.

**Fix:** Verify the intended post-lock state and update the guard accordingly, or reload `table_monitor` at the top of `finalize_game_result`.

```ruby
def finalize_game_result(table_monitor)
  table_monitor.reload  # ensure post-lock state is current
  # ...
end
```

---

### WR-04: `update_game_participations_for_game` divides by zero when `innings` is 0

**File:** `app/services/tournament_monitor/result_processor.rb:362,378`

**Issue:** `gd = format("%.2f", result.to_f / innings).to_f` (line 362 for sets mode) and the equivalent at line 378 for single-set mode both divide by `innings`. When a game is recorded with 0 innings (e.g., a forfeit, a timeout, or malformed data), this produces `Infinity` (Ruby float division by zero does not raise, it returns `Float::INFINITY`). That value is then stored in `gp.data["results"]["GD"]` and the `gp.gd` column, poisoning the ranking calculations downstream.

**Fix:** Guard against zero innings before the division.

```ruby
gd = innings.positive? ? format("%.2f", result.to_f / innings).to_f : 0.0
```

---

### WR-05: `add_result_to` divides by zero when `hash[player_id]["innings"]` accumulates to 0

**File:** `app/services/tournament_monitor/result_processor.rb:424`

**Issue:** Same class of problem as WR-04: `format("%.2f", hash[player_id]["result"].to_f / hash[player_id]["innings"]).to_f` will produce `Infinity` when innings total is 0. The rescued `StandardError` (CR-01) would swallow this, but only after the poisoned value is already written into the hash.

**Fix:**

```ruby
total_innings = hash[player_id]["innings"]
hash[player_id]["gd"] = total_innings.positive? ?
  format("%.2f", hash[player_id]["result"].to_f / total_innings).to_f : 0.0
```

---

### WR-06: `populate_tables` calls `Table.find` (not `find_by`) inside a loop — raises on missing table_id

**File:** `app/services/tournament_monitor/table_populator.rb:86`

**Issue:** `@table = Table.find(table_id)` raises `ActiveRecord::RecordNotFound` if `table_id` is stale or deleted. The outer `rescue StandardError` at line 512 catches this and raises `ActiveRecord::Rollback`, silently abandoning all placement work with no user-facing error. This differs from `initialize_table_monitors` (line 44) which uses `find_by` with a graceful `next`.

**Fix:** Use `find_by` and skip missing tables consistently.

```ruby
@table = Table.find_by(id: table_id)
unless @table.present?
  Tournament.logger.error "[populate_tables] Table[#{table_id}] not found, skipping"
  next
end
```

---

### WR-07: `TournamentMonitor` has `before_save :set_paper_trail_whodunnit` declared twice

**File:** `app/models/tournament_monitor.rb:41,51`

**Issue:** The callback is registered on lines 41 and 51. Rails will fire it twice before every save, which is a logic error (duplicated audit record population) and may cause PaperTrail warnings in newer versions.

**Fix:** Remove one of the two declarations.

```ruby
# Keep only one:
before_save :set_paper_trail_whodunnit
```

---

## Info

### IN-01: Inline debug log strings with emoji and `+++NNN` prefixes should be removed before stable release

**File:** `app/services/tournament_monitor/table_populator.rb:102,109,112,136,157,166,187,228,241,271,284,304,324,346,414,848`

**Issue:** The file contains dozens of `Tournament.logger.info "+++001 ..."` through `"+++016 ..."` markers and emoji (`🔒`, `✅`, `⊘`) in `Rails.logger` calls throughout `result_processor.rb`. These are development-era diagnostics left in production paths and will inflate logs significantly for each tournament game.

**Fix:** Gate verbose debug logging behind `TournamentMonitor::DEBUG` or replace with structured log calls at appropriate levels.

---

### IN-02: `TournamentMonitorState#table_monitors_ready?` has incorrect boolean logic

**File:** `lib/tournament_monitor_state.rb:82-83`

**Issue:** The inject block computes `memo = memo && tm.ready? || tm.ready_for_new_match? || tm.playing?` which, due to Ruby operator precedence (`&&` binds tighter than `||`), evaluates as `memo = (memo && tm.ready?) || tm.ready_for_new_match? || tm.playing?`. If any table_monitor is `playing?`, the whole expression returns truthy regardless of `memo`. The intent appears to be "all monitors are in one of these three states", which would require `(tm.ready? || tm.ready_for_new_match? || tm.playing?)` grouped before `&&`.

**Fix:**

```ruby
res = table_monitors.inject(true) do |memo, tm|
  memo && (tm.ready? || tm.ready_for_new_match? || tm.playing?)
end
```

Note: `memo.presence` at the end of each block iteration also converts `false` to `nil`, which could cause the inject to return `nil` rather than `false`. This is an existing bug but it is not in the files modified by this phase.

---

### IN-03: `update_game_participations_for_game` is exposed via `send` in the model delegation wrapper

**File:** `app/models/tournament_monitor.rb:158`

**Issue:** `TournamentMonitor#update_game_participations_for_game` delegates via `TournamentMonitor::ResultProcessor.new(self).send(:update_game_participations_for_game, game, data)`. Bypassing visibility with `send` from a public model method defeats the private encapsulation of the service and is fragile if the method is ever renamed or moved.

**Fix:** Either make `update_game_participations_for_game` public in the service (since it is also delegated via the public `update_game_participations`), or remove the model-level wrapper entirely and let callers use `update_game_participations(tabmon)` instead.

---

### IN-04: `write_game_result_data` is exposed via `send` in the model delegation wrapper

**File:** `app/models/tournament_monitor.rb:169`

**Issue:** Same pattern as IN-03. `write_game_result_data` is private in the service but is called with `send` from the public model method. The test at `result_processor_test.rb:194` explicitly verifies it is private. Having a public model wrapper that bypasses the private contract undermines the test's intent.

**Fix:** Remove the model-level `write_game_result_data` delegation or make the service method public and document why.

---

### IN-05: Test for `update_game_participations` uses wrong key `"player a"` (with space)

**File:** `test/services/tournament_monitor/result_processor_test.rb:176`

**Issue:** The mock `table_monitor_data` hash uses `"player a"` (space) as a key, but the production code accesses `data_source["playera"]` (no space). The test calls `update_game_participations` which delegates to `update_game_participations_for_game`. Because the key is wrong, the method's data access silently returns `nil`, all calculations use `nil.to_i == 0`, and the test only verifies that no exception is raised — not that the values written to GameParticipation are correct. This is a test that passes even when the code is wrong.

**Fix:** Correct the key to `"playera"` and add assertions that verify the resulting `gp.result`, `gp.innings`, and `gp.points` values are as expected.

```ruby
table_monitor_data = {
  "playera" => { "result" => 25, "innings" => 10, "balls_goal" => 30, "hs" => 8 },
  "playerb" => { "result" => 20, "innings" => 10, "balls_goal" => 30, "hs" => 6 }
}
```

---

_Reviewed: 2026-04-10_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
