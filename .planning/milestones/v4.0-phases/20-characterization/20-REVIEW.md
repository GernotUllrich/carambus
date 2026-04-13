---
phase: 20-characterization
reviewed: 2026-04-11T14:30:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - app/models/league.rb
  - test/fixtures/league_teams.yml
  - test/fixtures/parties.yml
  - test/models/league_scraping_test.rb
  - test/models/league_standings_test.rb
  - test/models/league_team_test.rb
  - test/models/league_test.rb
  - test/models/party_monitor_aasm_test.rb
  - test/models/party_monitor_placement_test.rb
  - test/models/party_test.rb
  - test/support/party_monitor_test_helper.rb
findings:
  critical: 2
  warning: 5
  info: 4
  total: 11
status: issues_found
---

# Phase 20: Code Review Report

**Reviewed:** 2026-04-11T14:30:00Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Reviewed the League model (2221 lines) and 10 associated test/fixture files from the Phase 20 characterization effort. The League model is a large god-object containing scraping, standings calculation, game plan reconstruction, and BBV-specific scraping logic. Two critical SQL injection vulnerabilities were found in scraping methods where user-scraped HTML content is interpolated directly into SQL queries. Several test files use class variables (`@@counter`) that persist across test runs and can cause ID collisions. The characterization tests themselves are well-structured and document pre-existing bugs clearly.

## Critical Issues

### CR-01: SQL Injection via String Interpolation in Club Lookup

**File:** `app/models/league.rb:931`
**Issue:** `club_name` is extracted from scraped HTML content and interpolated directly into a SQL `ILIKE` clause without parameterization. A malicious or malformed club name in the scraped HTML (e.g., containing `'`) could break the query or enable SQL injection.
**Fix:**
```ruby
club ||= Club.where("synonyms ilike ?", "%#{club_name}%").first
```

### CR-02: SQL Injection via String Interpolation in BBV Team Lookup

**File:** `app/models/league.rb:1744`
**Issue:** `team_name` is extracted from scraped HTML and interpolated directly into a SQL `ILIKE` clause. The `gsub(/ [IV]+$/, '')` sanitization does not prevent SQL injection.
**Fix:**
```ruby
sanitized_name = team_name.gsub(/ [IV]+$/, '')
club = Club.where(region: organizer).where("clubs.name ilike ?", "%#{sanitized_name}%").first
```

## Warnings

### WR-01: Class Variable @@counter Persists Across Test Runs

**File:** `test/models/league_scraping_test.rb:18`, `test/models/league_standings_test.rb:13`, `test/models/league_test.rb:9`
**Issue:** `@@counter` is initialized at class load time (`@@counter = 0`) but never reset between test suite runs. When tests are run in a persistent process (e.g., Spring or guard), the counter keeps incrementing, producing different IDs each run. This can cause ID collisions with fixtures or other tests if the counter grows large enough. The same pattern exists in `test/support/party_monitor_test_helper.rb:13` with `@@pm_counter`.
**Fix:** Use `setup` blocks to reset the counter, or switch to instance-level counters with a `before_setup` hook. Since the counters use different `ID_OFFSET` values (50000, 60000, 70000), collisions are unlikely in practice but the pattern is fragile. Consider using `SecureRandom` or DB sequences for unique IDs instead.

### WR-02: Undefined Variable `records_to_tag` in scrape_bbv_leagues

**File:** `app/models/league.rb:1691`
**Issue:** `records_to_tag |= Array(league)` references `records_to_tag` which is never initialized in `scrape_bbv_leagues`. This will raise `NameError: undefined local variable or method 'records_to_tag'` when the BBV code path is executed. The variable is also returned on line 1698 without initialization.
**Fix:**
```ruby
def self.scrape_bbv_leagues(region, season, opts = {})
  records_to_tag = []
  url = "https://bbv-billard.liga.nu"
  # ... rest of method
```

### WR-03: Undefined Variable `location` in Party Creation Fallback

**File:** `app/models/league.rb:1336`
**Issue:** In the `else` branch (no result link), the code references `location` variable which is only assigned inside the `if result_a.present?` branch (line 944). If `result_a` is nil, `location` is undefined and will raise `NameError`.
**Fix:**
```ruby
location: league_team_a.andand.club.andand.location
```
Remove the `location ||` prefix since `location` is not in scope.

### WR-04: Undefined Variable `round_name_to_s` in reconstruct_game_plan

**File:** `app/models/league.rb:1097`
**Issue:** Line 1097 references `round_name_to_s` (a method call on an implicit receiver) but the intended expression is likely `round_name.to_s`. Additionally on line 1099, `max_balls` (a local hash) is compared with `<` against an integer, which will raise `ArgumentError` -- the correct expression is `max_balls[round_name.to_s]`.
**Fix:**
```ruby
max_balls[round_name.to_s] = (result_detail["Bälle:"] || result_detail["Punkte:"]).split(/\s*:\s*/).map(&:to_i).max
disciplines[dis_name][:score][round_name.to_s] = max_balls[round_name.to_s] if disciplines[dis_name][:score][round_name.to_s].to_i < max_balls[round_name.to_s]
```

### WR-05: Undefined Variable `max_balls` in reconstruct_game_plan_from_existing_data

**File:** `app/models/league.rb:1899-1901`
**Issue:** `max_balls` is referenced but never declared in `reconstruct_game_plan_from_existing_data`. It is only a local in `scrape_single_league_from_cc`. Additionally, `disciplines[discipline_name][:score]` may be nil on first access (line 1900), causing `NoMethodError` when `[]` is called on nil. Line 1098 in `scrape_single_league_from_cc` has the same issue: `disciplines[dis_name][:score] || {}` evaluates but discards the result.
**Fix:** Initialize `max_balls = {}` at the top of the method, and use `disciplines[discipline_name][:score] ||= {}` before accessing it.

## Info

### IN-01: Massive Code Duplication in Standings Methods

**File:** `app/models/league.rb:1434-1628`
**Issue:** `standings_table_karambol`, `standings_table_snooker`, and `standings_table_pool` are nearly identical (60+ lines each), differing only in the label key (`:partien` vs `:frames`). This is a prime candidate for extraction into a shared method during refactoring.
**Fix:** Extract a shared `compute_standings(label_key:)` method and delegate from each discipline-specific method.

### IN-02: TODO Comment Indicates Unclear Code Purpose

**File:** `app/models/league.rb:604`
**Issue:** `# TODO what's the following code about??` indicates the developer does not understand the purpose of the code block that follows. This is a maintenance risk.
**Fix:** Investigate and document the purpose of the `source_url` check block, or remove it if it is dead code.

### IN-03: `raise StandardError` Missing Comma (String Method Call)

**File:** `app/models/league.rb:1038`
**Issue:** `raise StandardError "Format Error 1 Party[#{party.id}]"` is missing a comma between `StandardError` and the string. This calls `StandardError("...")` as a method (Kernel#StandardError), which works but is an unusual pattern compared to `raise StandardError, "..."`.
**Fix:**
```ruby
raise StandardError, "Format Error 1 Party[#{party.id}]"
```

### IN-04: `schedule_by_rounds` Has Unreachable Sort Result

**File:** `app/models/league.rb:1633-1657`
**Issue:** The `sort_by` on line 1634 is called but its return value is not captured -- the sorted result is discarded. `ordered_keys` on line 1642 uses the original `all_parties` order. The sort operation has no effect.
**Fix:**
```ruby
all_parties = all_parties.sort_by do |p|
  # ...sort logic...
end
```

---

_Reviewed: 2026-04-11T14:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
