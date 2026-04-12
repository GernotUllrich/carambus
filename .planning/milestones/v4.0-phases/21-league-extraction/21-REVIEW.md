---
phase: 21-league-extraction
reviewed: 2026-04-11T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - app/models/league.rb
  - app/services/league/bbv_scraper.rb
  - app/services/league/club_cloud_scraper.rb
  - app/services/league/game_plan_reconstructor.rb
  - app/services/league/standings_calculator.rb
  - test/services/league/bbv_scraper_test.rb
  - test/services/league/club_cloud_scraper_test.rb
  - test/services/league/game_plan_reconstructor_test.rb
  - test/services/league/standings_calculator_test.rb
findings:
  critical: 2
  warning: 8
  info: 5
  total: 15
status: issues_found
---

# Phase 21: Code Review Report

**Reviewed:** 2026-04-11
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

The phase-21 extraction splits scraping logic out of `League` into three focused services (`BbvScraper`, `ClubCloudScraper`, `GamePlanReconstructor`) and a PORO (`StandingsCalculator`). The structural delegation is sound and the tests cover the happy path and delegation contracts well.

However, several bugs and potential crashes were found in `ClubCloudScraper` and `GamePlanReconstructor` — most carry over from the original god-object code and are now more visible in isolation. Two are critical: a nil-method crash on every non-DBU player lookup failure, and an undefined local variable in `GamePlanReconstructor`. The `StandingsCalculator` has three identical copy-paste methods that should be DRYed. Tests for `ClubCloudScraper` are very thin given the complexity of the service.

---

## Critical Issues

### CR-01: Nil-dereference crash when non-DBU player lookup fails

**File:** `app/services/league/club_cloud_scraper.rb:266`
**Issue:** In the non-DBU branch, when a player is not found `player` is `nil`. The code then calls `player.assign_attributes(cc_id: player_dbu_nr)` on the `nil` object (line 266) before the `else` that reaches `@league_team_players[team_name][fl_name] = player` (line 270). This raises `NoMethodError: undefined method 'assign_attributes' for nil:NilClass` and aborts scraping for the entire league.

```ruby
# Current (buggy):
else
  player.assign_attributes(cc_id: player_dbu_nr)   # player is nil here!
end

# Fix: guard against nil
else
  player&.assign_attributes(cc_id: player_dbu_nr)
end
```

The `unless / else` block (lines 258–268) has an `else` branch that is only reached when `player` is still `nil` after all three lookup attempts, yet it calls `player.assign_attributes` without a nil check. Additionally `@league_team_players[team_name][fl_name] = player` stores `nil`, silently propagating the bad state downstream.

### CR-02: Undefined local `round_name` inside `GamePlanReconstructor#reconstruct`

**File:** `app/services/league/game_plan_reconstructor.rb:137`
**Issue:** The variable `round_name` is never defined in the `reconstruct` method. It is referenced on line 137 when building the score hash:

```ruby
disciplines[discipline_name][:score] = {round_name.to_s => ball_values.max}
```

This raises `NameError: undefined local variable or method 'round_name'` the first time a game with ball data is processed. This path was present in `ClubCloudScraper` where `round_name` is a local variable in `parse_parties`, but was not ported during extraction.

```ruby
# Fix: initialize round_name before the parties loop, then update it as parties are iterated
round_name = nil
parties_with_games.each do |party|
  round_name = party.round_name  # add this line when iterating parties
  # ... rest of loop
end
```

---

## Warnings

### WR-01: `parse_teams` crashes when `team_a` is nil

**File:** `app/services/league/club_cloud_scraper.rb:114`
**Issue:** `team_a` is assigned via `andand[0]` (nil-safe), but then `team_a["href"]` is called unconditionally on the next line. If neither `td[1]` nor `td[2]` contains an `<a>` tag, `team_a` is `nil` and the call raises `NoMethodError`.

```ruby
team_a = tr.css("td")[1].css("a").andand[0] || tr.css("td")[2].css("a").andand[0]
team_link = team_a["href"].gsub(...)  # crashes if team_a is nil
```

**Fix:** Add a nil guard or `next` after the assignment:
```ruby
next if team_a.nil?
team_link = team_a["href"].gsub("mannschaftsplan", "mannschaft")
```

### WR-02: `details_table` nil-dereference in `scrape_from_club_cloud`

**File:** `app/services/league/club_cloud_scraper.rb:76`
**Issue:** `details_table = staffel_doc.css("aside > section > table")[0]` may return `nil` if the page structure changes or the request fails silently. The following `details_table.css("tr")` then crashes.

```ruby
details_table = staffel_doc.css("aside > section > table")[0]
skip = false
details_table.css("tr").each do |tr|   # NoMethodError if nil
```

**Fix:**
```ruby
return if details_table.nil?
```

### WR-03: `game_report_table` nil-dereference

**File:** `app/services/league/club_cloud_scraper.rb:407`
**Issue:** `game_report_table = game_report_doc.css("aside > section > table")[2]` may be nil (e.g., unexpected HTML layout, truncated response). The next line `game_report_table.css("tr > td")` raises `NoMethodError`.

**Fix:**
```ruby
next if game_report_table.nil?
```

### WR-04: `game_detail_table` nil-dereference

**File:** `app/services/league/club_cloud_scraper.rb:505`
**Issue:** `game_detail_table` (line 491–494) may be nil if CSS selectors do not match. `game_detail_table.css("tr").each` crashes without a guard.

**Fix:**
```ruby
next if game_detail_table.nil?
```

### WR-05: Bare `rescue` on the `call` method swallows all exceptions silently

**File:** `app/services/league/club_cloud_scraper.rb:21-23`
**Issue:** The top-level `rescue` in `call` catches every exception including `NoMethodError`, `NameError`, and `StandardError`, logs them as `Rails.logger.info` (not `error`), and returns `nil`. This means critical scraping failures (CR-01, CR-02, WR-01–WR-04) are silently swallowed in production rather than alerting operators.

```ruby
def call
  scrape_league
rescue => e
  Rails.logger.info "==== scrape ==== Fatal Error ..."  # should be .error
end
```

**Fix:** Use `Rails.logger.error` and consider re-raising or using a monitoring hook so failures are visible.

### WR-06: `StandingsCalculator` — identical logic triplicated across `karambol`, `snooker`, `pool`

**File:** `app/services/league/standings_calculator.rb:19-205`
**Issue:** The three public methods (`karambol`, `snooker`, `pool`) are almost byte-for-byte identical. The only differences are the stat field names (`partien` vs `frames`) and the outer method name. A bug fix in one method will silently fail to be applied to the others — as already demonstrated by `pool` having an asymmetric `rescue => e` (line 205-207) that `karambol` and `snooker` do not have.

**Fix:** Extract a shared private method:
```ruby
def calculate_standings(stat_key)
  teams = @league.league_teams.to_a
  # ... shared logic ...
  stats.sort_by.with_index { |row, idx| [-row[:punkte], -row[:diff], idx] }
       .each_with_index.map { |row, ix| row.merge(platz: ix + 1) }
end

def karambol = calculate_standings(:partien)
def snooker  = calculate_standings(:frames)
def pool     = calculate_standings(:partien)
```

### WR-07: `scrape_leagues_optimized` and `scrape_leagues_from_cc` reference `leagues_url` in rescue block even if never assigned

**File:** `app/models/league.rb:399-403`, `app/models/league.rb:469-473`
**Issue:** In both methods the rescue block references the local variable `leagues_url` in the error message. If the exception is raised *before* `leagues_url` is assigned (e.g., during `URI(leagues_url)` which is the first use of the variable), Ruby will raise a second `NameError: undefined local variable 'leagues_url'`, masking the original exception.

The `scrape_leagues_optimized` method body also calls `raise StandardError` after `Rails.logger.info` — so the error is logged twice with no additional context.

**Fix:** Assign `leagues_url = nil` at the top of each method so the rescue block always has a valid reference.

### WR-08: `pool` method has an asymmetric `rescue` that silently returns `nil`

**File:** `app/services/league/standings_calculator.rb:205-207`
**Issue:** The `pool` method has a `rescue => e` at the end that catches all exceptions and returns `nil`. `karambol` and `snooker` do not have this rescue. If `pool` raises for any reason the caller receives `nil` instead of an array — this likely causes a downstream `NoMethodError` when the caller iterates the result.

**Fix:** Either remove the rescue (let errors propagate) or apply consistent error handling across all three methods, and ensure the caller handles `nil` returns.

---

## Info

### IN-01: `DEBUG = true` constant left enabled in `League` model

**File:** `app/models/league.rb:250`
**Issue:** `DEBUG = true` is a magic boolean constant that appears unused (no references to it in the reviewed files). It is a dead code artifact from development.

**Fix:** Remove the constant or wire it to an environment check if it is needed.

### IN-02: BBV URL construction has a raw `%` in the format string

**File:** `app/services/league/bbv_scraper.rb:33`
**Issue:** The URL is built with string interpolation and contains a literal `%` that is not followed by a valid percent-encoding sequence:

```ruby
"#{BBV_BASE_URL}/cgi-bin/WebObjects/nuLigaBILLARDDE.woa/wa/leaguePage?championship=BBV%20#{branch_str}%#{season.name.gsub("/20", "/")}"
```

The `%` before `#{season.name...}` is a bare percent sign. Depending on what `season.name.gsub(...)` returns, this will produce a malformed URL (e.g., `BBV%20Pool%2024/25`). If the intent is `%20`, the interpolation is redundant; if the intent is a literal `%`, it should be `%25` in the URL. Either way this is ambiguous.

**Fix:** Build the URL clearly:
```ruby
"#{BBV_BASE_URL}/cgi-bin/...?championship=#{URI.encode_www_form_component("BBV #{branch_str} #{season.name.gsub("/20", "/")}")}"
```

### IN-03: Redundant nil guard `if league_team_b.present?` inside `if league_team_b.present?`

**File:** `app/services/league/club_cloud_scraper.rb:734-736`
**Issue:** The outer `if league_team_b.present?` check is immediately followed by an inner identical check `if league_team_b.present?` — the inner check is dead code.

```ruby
if league_team_b.present?
  if league_team_b.present?  # always true here
    player_b = @league_team_players[league_team_b.name].andand[player_b_fl_name]
  end
```

**Fix:** Remove the inner guard.

### IN-04: `find_leagues_with_same_gameplan` and `find_or_create_shared_gameplan` are private but unused dead code

**File:** `app/services/league/game_plan_reconstructor.rb:443-460`
**Issue:** Both methods are defined but never called from within the service or from external code in the reviewed files. They are dead private methods.

**Fix:** Remove them or move them to a comment if they are planned for future use.

### IN-05: `BbvScraper` test uses `regions(:nbv)` as the organizer but `scrape_all` hardcodes "BBV" branch strings

**File:** `test/services/league/bbv_scraper_test.rb:83`
**Issue:** The `scrape_all` test stubs all requests to `bbv-billard.liga.nu` but the fixture region is `nbv`, not the BBV region. The test therefore exercises a code path that constructs a URL using `BBV Pool/Snooker/Karambol` but the league lookup uses `organizer: region` which is NBV. This creates a mismatch between what is tested and what production does — the stub passes only because the leagues HTML has no `<a>` tags to follow.

**Fix:** Either use the BBV region fixture or document clearly in the test that this is a smoke test for the array return type only.

---

_Reviewed: 2026-04-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
