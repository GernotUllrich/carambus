---
phase: 13-low-risk-extractions
reviewed: 2026-04-10T00:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - app/models/tournament.rb
  - app/models/tournament_monitor.rb
  - app/services/tournament/ranking_calculator.rb
  - app/services/tournament/table_reservation_service.rb
  - app/services/tournament_monitor/player_group_distributor.rb
  - test/models/tournament_auto_reserve_test.rb
  - test/models/tournament_calendar_test.rb
  - test/services/tournament/ranking_calculator_test.rb
  - test/services/tournament/table_reservation_service_test.rb
  - test/services/tournament_monitor/player_group_distributor_test.rb
  - test/tasks/auto_reserve_tables_test.rb
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-04-10
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

This phase extracted three service objects from the `Tournament` and `TournamentMonitor` god-objects:
`Tournament::RankingCalculator`, `Tournament::TableReservationService`, and
`TournamentMonitor::PlayerGroupDistributor`. The extraction is structurally clean: delegation
wrappers are in place on the models, the PORO/service patterns are appropriate, and the test
coverage is broad.

Five warnings were found — none are blockers, but two carry a real risk of silent data corruption
or unexpected `nil` errors at runtime. Four info items cover dead code, a duplicate `before_save`
hook, and minor comment cruft.

---

## Warnings

### WR-01: `RankingCalculator#calculate_and_cache_rankings` reverses the season order, producing wrong effective GD

**File:** `app/services/tournament/ranking_calculator.rb:29-49`

**Issue:** Seasons are fetched newest-first, then reversed so they are oldest-first (`seasons.reverse`).
The comment says "aktuellste Saison zuerst" but the index mapping applied next (`gd_values[2]` = most
recent) is consistent with an oldest-first array. However, `gd_values[2]` is the third element of a
maximum-three-element array, so it refers to the season that was fetched **first** (the most recent one)
after the `.reverse`.

The actual bug is more subtle: `Season.where("id <= ?", current_season.id).order(id: :desc).limit(3)`
returns up to 3 seasons newest-first; `.reverse` makes index 0 oldest, index 2 newest. Then:

```ruby
effective_gd = gd_values[2] || gd_values[1] || gd_values[0]
```

This correctly prefers the most recent season, then falls back — **but only when exactly 3 seasons
exist**. When fewer than 3 seasons exist (e.g., a fresh database with 1 or 2 seasons), `gd_values`
has 1 or 2 elements, making `gd_values[2]` always `nil`. The fallback chain then produces the wrong
priority: it will pick `gd_values[1]` (middle season) before `gd_values[0]` (oldest), but the
intent is always "newest available". With 2 seasons: `gd_values[0]` is oldest, `gd_values[1]` is
newest — the logic picks newest first, which happens to be correct by accident. With 1 season:
`gd_values[0]` is the only season — but `gd_values[2]` and `gd_values[1]` are both `nil`, so it
falls through to `gd_values[0]` which is correct.

The real danger is the inverted priority intent: the comment says "aktuellste Saison zuerst" but the
code picks the **last** element of a reversed array. This is fragile and any future refactor that
removes the `.reverse` will silently invert the priority.

**Fix:**
```ruby
# Fetch newest-first, don't reverse; use first element for "most recent"
seasons = Season.where("id <= ?", current_season.id).order(id: :desc).limit(3).to_a

# ...
gd_values = seasons.map do |season|
  ranking = rankings.find { |r| r.season_id == season.id }
  ranking&.gd
end
# gd_values[0] = most recent, gd_values[1] = previous, gd_values[2] = oldest
effective_gd = gd_values[0] || gd_values[1] || gd_values[2]
```

---

### WR-02: `RankingCalculator#reorder_seedings` silently skips missing seedings

**File:** `app/services/tournament/ranking_calculator.rb:71-72`

**Issue:** `Seeding.find_by_id(seeding_id)` returns `nil` when a seeding has been deleted between
the `seeding_ids` fetch and the loop iteration (a possible race condition, or just stale data). The
result of `nil` is then called with `.update_columns(position: ix + 1)`, raising `NoMethodError`.
The caller (`Tournament#reorder_seedings`) has no rescue, so the error propagates and aborts
mid-loop — leaving seedings in a partially renumbered state.

**Fix:**
```ruby
def reorder_seedings
  l_seeding_ids = @tournament.seeding_ids
  l_seeding_ids.each_with_index do |seeding_id, ix|
    Seeding.find_by(id: seeding_id)&.update_columns(position: ix + 1)
  end
  @tournament.reload
end
```

---

### WR-03: `TableReservationService#format_table_list` raises `NoMethodError` when a table name contains no digits

**File:** `app/services/tournament/table_reservation_service.rb:56`

**Issue:** `name.match(/\d+/)[0]` is called unconditionally inside `format_table_list`. If a table
name has no numeric suffix (e.g., `"Haupttisch"` or a name imported from an external source), the
`match` returns `nil` and `[0]` raises `NoMethodError`. The same unchecked pattern exists on line 30
of the same file when building `table_names`.

**Fix:**
```ruby
numbers = table_names.filter_map { |name| name.match(/\d+/)&.send(:[], 0).to_i }.sort
```
Or validate at the call site that `match` succeeds before indexing:
```ruby
numbers = table_names.map { |name| (name.match(/\d+/) || next)[0].to_i }.compact.sort
```

---

### WR-04: `TournamentMonitor` has a duplicate `before_save :set_paper_trail_whodunnit` callback

**File:** `app/models/tournament_monitor.rb:42-51`

**Issue:** `before_save :set_paper_trail_whodunnit` is registered twice (lines 42 and 51). Rails
accumulates callbacks — the method will be called twice on every save. This is harmless for an
idempotent whodunnit setter but is still a correctness defect that indicates the second declaration
was added without noticing the first, and could cause issues if the method ever acquires side
effects.

**Fix:** Remove the duplicate at line 51:
```ruby
before_save :log_state_change
# Remove the duplicate: before_save :set_paper_trail_whodunnit  ← delete this
```

---

### WR-05: `distribute_with_sizes` can silently under-assign players when `groups_with_space` is exhausted

**File:** `app/services/tournament_monitor/player_group_distributor.rb:159-168`

**Issue:** In the Phase 2 loop (lines 156–169), when a group reaches its `max_size`, the code calls
`groups_with_space << target_group` (line 166) **before** the conditional that re-adds it only if
still under capacity — but the logic is inverted: it appends unconditionally and then the condition
never removes it. On careful reading: `target_group` is shifted off at line 160, then appended back
at line 166 **only if** `group_fill_count[target_group] < max_size`. This is correct. However, when
`groups_with_space` is empty (all groups are full) but `remaining_players` still has entries, the
`else` branch logs a warning but does **not raise**, causing a silent data loss: some players are
not assigned to any group, and the distributor returns an incomplete result that will silently produce
games with the wrong number of players. There is no contract (return value validation, error, or
exception) to signal the caller.

**Fix:** At minimum, raise after the `else` warning so the caller can detect the inconsistency:
```ruby
else
  raise ArgumentError,
    "distribute_with_sizes: cannot assign player #{players_for_phase1 + index + 1} — " \
    "group_sizes #{group_sizes.inspect} do not accommodate #{players.count} players"
end
```
Or return a sentinel that callers can check. The current silent drop is the most dangerous outcome
since tournaments would proceed with fewer players than expected.

---

## Info

### IN-01: Dead code — `DIST_RULES` constant is defined but never used

**File:** `app/services/tournament_monitor/player_group_distributor.rb:15-27`

**Issue:** `DIST_RULES` is defined as a frozen hash constant but is referenced nowhere in
`PlayerGroupDistributor` or in any other file in scope. The algorithm uses `GROUP_RULES` and
`GROUP_SIZES` instead. `DIST_RULES` appears to be a leftover from an earlier design iteration.

**Fix:** Remove the constant, or add a comment explaining its intended future use:
```ruby
# DIST_RULES intentionally omitted — replaced by GROUP_RULES path.
```

---

### IN-02: Commented-out code blocks in `tournament_monitor.rb`

**File:** `app/models/tournament_monitor.rb:91-93`, `128-133`

**Issue:** Two blocks of commented-out code (`initialize` override and
`table_monitors_ready_and_populated`) remain in the file. These add noise without value.

**Fix:** Delete both commented-out blocks.

---

### IN-03: `Tournament::RankingCalculator` test does not assert the order of cached rankings

**File:** `test/services/tournament/ranking_calculator_test.rb:112-126`

**Issue:** Test 4 ("calculate_and_cache_rankings caches player_rankings in data hash") only verifies
that `player_rankings` is a `Hash` and is non-nil. It does not verify that rankings are ordered
correctly or that `player_rank` values are sequential integers starting from 1. This leaves the
core ranking logic untested at the unit level.

**Fix:** Add a fixture or factory that creates `PlayerRanking` records for the tournament's
discipline and region, then assert the resulting hash keys and values:
```ruby
# Assert rank values are consecutive integers >= 1
ranks = tournament.data["player_rankings"].values
assert ranks.all? { |r| r.is_a?(Integer) && r >= 1 }
```

---

### IN-04: `tournament.rb` line 410 references an undefined variable `tournament_html_`

**File:** `app/models/tournament.rb:410`

**Issue:** Inside the `scrape_single_tournament_public` method:
```ruby
tournament_doc_ = Nokogiri::HTML(tournament_html_)
```
`tournament_html_` (with trailing underscore) is used but the fetched HTML is assigned to
`tournament_html` (no underscore) on line 409. This is a `NameError` at runtime if the
`tournament_cc_id.blank?` branch is taken. This is pre-existing code, not introduced in this
phase, but it was encountered during the standard file read.

**Fix:**
```ruby
tournament_html = Rails.env == "development" ? Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)
tournament_doc_ = Nokogiri::HTML(tournament_html)
```

---

_Reviewed: 2026-04-10_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
