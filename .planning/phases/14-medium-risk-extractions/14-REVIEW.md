---
phase: 14-medium-risk-extractions
reviewed: 2026-04-10T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - app/models/tournament.rb
  - app/models/tournament_monitor.rb
  - app/services/tournament/public_cc_scraper.rb
  - app/services/tournament_monitor/ranking_resolver.rb
  - test/models/tournament_scraping_test.rb
  - test/services/tournament/public_cc_scraper_test.rb
  - test/services/tournament_monitor/ranking_resolver_test.rb
findings:
  critical: 2
  warning: 7
  info: 5
  total: 14
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-04-10
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

This review covers the medium-risk extraction work from phase 14: the `Tournament::PublicCcScraper` service (extracted from Tournament), the `TournamentMonitor::RankingResolver` PORO (extracted from TournamentMonitor), plus the host models and their characterization test suites.

The extraction architecture is sound and the delegation wiring is correct. However, the `PublicCcScraper` has two critical issues — a `Kernel.exit(501)` call inside dead code that would kill the Puma process if ever reached, and an unguarded nil-dereference on `name_match` in the participant list parser that crashes the full scrape. Several warnings cover nil-safe access gaps and logic bugs in both the service and the ranking resolver. Test coverage for the ranking resolver is thin for the most complex paths.

---

## Critical Issues

### CR-01: `Kernel.exit(501)` in dead `parse_table_td` halts the server process

**File:** `app/services/tournament/public_cc_scraper.rb:919`
**Issue:** The `parse_table_td` method is explicitly marked as dead code (line 734 comment). Nevertheless it contains `Kernel.exit(501)` at line 919 inside its `elsif /X/.match?(...)` branch. If this method were ever called — even accidentally — it would terminate the entire Puma worker process rather than raising a recoverable error. Dead code containing process-killing calls is a latent operational hazard.
**Fix:**
```ruby
# Replace with a recoverable error raise:
raise StandardError, "Fatal 501 - seeding nil???"
# Or simply remove the entire parse_table_td method — it is acknowledged dead code.
```

---

### CR-02: Unguarded nil dereference on `name_match` in participant-list parser

**File:** `app/services/tournament/public_cc_scraper.rb:212`
**Issue:** The three-branch `name_match` cascade at lines 203–213 ends with:
```ruby
name_match = tr.css("td")[2].inner_html.match(%r{<strong>(.*)</strong><br>(.*)})
player_lname, club_name = name_match[1..2]
```
There is no `if name_match` guard on this final branch. When none of the three patterns matches (e.g., a header row, a colspan, or unexpected HTML), `name_match` is `nil` and `nil[1..2]` raises `NoMethodError`. This aborts the entire `call` method, skipping all remaining seedings and potentially triggering `reset_tournament` via the outer `rescue StandardError` at line 437.

**Fix:**
```ruby
name_match = tr.css("td")[2].inner_html.match(%r{<strong>(.*)</strong><br>(.*)})
if name_match
  player_lname, club_name = name_match[1..2]
else
  Rails.logger.info("===== scrape ===== Warning: no name match for participant row, skipping")
  next
end
```

---

## Warnings

### WR-01: `variant3` returns uninitialized local variables when early branch taken

**File:** `app/services/tournament/public_cc_scraper.rb:621-649`
**Issue:** `variant3` returns `[frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines, innings, points, gd, hs]` from all branches. In the first two branches (lines 622–628), `no`, `playera_fl_name`, `playerb_fl_name`, `gd`, and `hs` are never assigned. Ruby returns `nil` for uninitialized locals declared only in an `elsif` branch. The caller at line 522 then destructures this array and overwrites the caller's valid variables (`no`, `playera_fl_name`, etc.) with `nil`, silently wiping state for the current game being built.
**Fix:** Initialize the missing variables at the top of the method before the conditional:
```ruby
def variant3(...)
  no = playera_fl_name = playerb_fl_name = result = nil
  # ... rest of method
end
```

---

### WR-02: `result_with_party_variant` and `result_with_party_variant2` return uninitialized variables

**File:** `app/services/tournament/public_cc_scraper.rb:683-702`, `662-681`
**Issue:** Both `result_with_party_variant` and `result_with_party_variant2` return `[frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines]`. When the first branch (`td.count == 2`, "Ergebnis:" row) is taken, `no`, `playera_fl_name`, `playerb_fl_name` are never set, returning `nil` and overwriting the caller's state. Same pattern as WR-01.
**Fix:** Initialize all returned variables at the method top, or use explicit `return` with the current values passed in for variables not modified in that branch.

---

### WR-03: `random_from_group_ranks` calls `nil[1..3]` when member regex fails

**File:** `app/services/tournament_monitor/ranking_resolver.rb:126-128`
**Issue:** The regex on line 126 spans multiple lines due to a literal newline inside the pattern:
```ruby
g_no, _game_no, rk_no = member.match(/^(?:(?:fg|g)(\d+)|sl|rule|64f|32f|16f|8f|vf|hf|af|qf|fin
|p<\d+(?:\.\.|-)\d+>)(\d+)?\.rk(\d)$/)[1..3]
```
The literal newline (`\n`) inside the regex makes it non-functional for any input (the pattern requires a literal newline character in the subject string). When the match fails, `match(...)` returns `nil`, and `nil[1..3]` raises `NoMethodError`. The outer `rescue StandardError` in `player_id_from_ranking` catches this, but the entire `random_from_group_ranks` path silently returns `nil` for all inputs.
**Fix:**
```ruby
match_result = member.match(/^(?:(?:fg|g)(\d+)|sl|rule|64f|32f|16f|8f|vf|hf|af|qf|fin|p<\d+(?:\.\.|-)\d+>)(\d+)?\.rk(\d)$/)
return nil unless match_result
g_no, _game_no, rk_no = match_result[1..3]
```

---

### WR-04: `rank_from_group_ranks` calls `nil[1..3]` on regex mismatch

**File:** `app/services/tournament_monitor/ranking_resolver.rb:170`
**Issue:** Same pattern as WR-03 — the regex at line 170:
```ruby
g_no, _game_no, rk_no = member.match(/^(?:(?:fg|g)(\d+)|sl|64f|32f|16f|8f|vf|hf|af|qf|rule|fin|p<\d+(?:\.\.|-)\d+>)(\d+)?\.rk(\d)$/)[1..3]
```
If the member string does not match (e.g., an unexpected format), `nil[1..3]` raises `NoMethodError`. Unlike in `random_from_group_ranks`, there is no literal-newline bug here, but the nil-guard is still missing.
**Fix:**
```ruby
match_result = member.match(...)
next unless match_result
g_no, _game_no, rk_no = match_result[1..3]
```

---

### WR-05: `ko_ranking` — `sl` branch chosen incorrectly for `g`/`fg` prefixed strings

**File:** `app/services/tournament_monitor/ranking_resolver.rb:49-73`
**Issue:** The `if g_no.present?` block at line 51 dispatches via `case rule_str`:
```ruby
case rule_str
when /^sl/ ...
when /^fg/ ...
when /^g/  ...
else nil
end
```
However, `g_no` being present means the regex captured a group number — which only happens for `fg\d+` and `g\d+` prefixes, not `sl`. The `when /^sl/` branch inside this `if g_no.present?` block is unreachable: `sl` never sets a capture for `g_no`. This dead branch is confusing and the `else nil` would silently swallow a `g_no`-present rule string that matched neither `fg` nor `g`, returning `nil` without logging.
**Fix:** Remove the unreachable `when /^sl/` inside the `if g_no.present?` block and add a logging `else` clause to surface unexpected patterns.

---

### WR-06: `seedings_ids.delete` called on undeclared variable inside dead `parse_table_td`

**File:** `app/services/tournament/public_cc_scraper.rb:776`, `810`, `828`, `854`, `889`, `912`
**Issue:** `parse_table_td` references `seeding_ids` (line 776 etc.), `records_to_tag` (line 802), and `position` (line 772) — all of which are never defined in the method's local scope or passed as parameters. Ruby would raise `NameError` on any execution path that reaches these. While this is dead code, it indicates the method was extracted incompletely and may have been copied from a context where these variables existed. If someone accidentally calls this method, the crash message will be obscure.

This is currently low-risk because the method is never called, but combined with CR-01 (`Kernel.exit`) it reinforces that `parse_table_td` should be removed entirely.
**Fix:** Delete `parse_table_td` from the file. It is explicitly marked dead at line 733.

---

### WR-07: `define_method` block in `tournament.rb` has inconsistent indentation — `end` at line 269 closes the `each` not the inner `define_method`

**File:** `app/models/tournament.rb:239-269`
**Issue:** The `%i[...].each do |meth|` block at line 239 contains two `define_method` calls. The first `define_method` (getter) at line 242 closes at line 244 with the implicit block end. The second `define_method` (setter) at line 246 ends at line 268. The outer `each` block's `end` at line 269 closes the iterator. The indentation of lines 246–268 (the setter `define_method`) is at the same level as the outer `each` block body, but the `end` at line 268 closes the `define_method` while the `end` at line 269 closes `each`. This is correct but visually misleading — the setter's `define_method` appears to be at the same nesting level as the `each` body, making it easy to misread as a free-standing method definition.

More importantly, `elsif id < Tournament::MIN_ID` at line 249 is evaluated with `id` potentially being `nil` for new records. The `new_record?` check at line 247 gates this for `new_record?` but if `id` is nil and the record is not `new_record?` (which should not happen but could in test fixtures with partial state), it would raise `NoMethodError: undefined method '<' for nil`.
**Fix:** Add an explicit nil guard:
```ruby
elsif id.present? && id < Tournament::MIN_ID
```

---

## Info

### IN-01: Naming convention violation — method name `Variant4` uses PascalCase

**File:** `app/services/tournament/public_cc_scraper.rb:608`
**Issue:** The method is named `Variant4` with a capital V, while all sibling methods use lowercase snake_case (`variant0`, `variant2`, `variant3`, etc.). Ruby treats PascalCase identifiers as constants; calling `Variant4(...)` works because Ruby allows constant-named methods, but it is misleading and inconsistent with the project's naming conventions and Ruby conventions.
**Fix:** Rename to `variant4` and update the call site at line 526.

---

### IN-02: `before_save :set_paper_trail_whodunnit` duplicated in `TournamentMonitor`

**File:** `app/models/tournament_monitor.rb:42`, `51`
**Issue:** `before_save :set_paper_trail_whodunnit` appears twice (lines 42 and 51). This registers the callback twice, causing it to execute twice on every save. While idempotent for PaperTrail's whodunnit, it is a code defect.
**Fix:** Remove the duplicate at line 42 (keep the one at line 51, near the other `before_save :log_state_change`).

---

### IN-03: TODO comment in `TournamentMonitor` state machine left unresolved

**File:** `app/models/tournament_monitor.rb:83`
**Issue:** `# TODO: transitions from: :playing_groups,` inside the `report_game_result` event has been left incomplete. The event has no transitions defined, meaning it currently does nothing (AASM will raise on trigger). This may be intentional placeholder but it is untracked.
**Fix:** Either implement the transition or remove the event and TODO comment.

---

### IN-04: `parse_table_td` and `fix_location_from_location_text` are dead code — should be removed

**File:** `app/services/tournament/public_cc_scraper.rb:734`, `1039`
**Issue:** Both methods are explicitly commented as "DEAD CODE" in their docstrings. They add ~310 lines of complex, broken code (see WR-06) to the file. Their continued presence increases cognitive load and review surface.
**Fix:** Delete both methods. If future need arises, git history preserves them.

---

### IN-05: Test for `g1.1` group rank resolution is weakly asserted

**File:** `test/services/tournament_monitor/ranking_resolver_test.rb:59-65`
**Issue:** The test "player_id_from_ranking resolves g1.1 to first player in group 1" asserts only `result.nil? || result.is_a?(Integer)`. This is essentially `assert true` — it does not verify any specific behavior and will pass even if the resolver silently returns `nil` due to a bug. The comment acknowledges "may be nil if group distribution returns nil" but does not explain why.
**Fix:** Set up test data with a known tournament plan that has `ngroups` defined, then assert a specific non-nil player ID. If the path genuinely cannot be exercised deterministically in tests, the comment should explain why and the test should be removed rather than kept as a vacuous assertion.

---

_Reviewed: 2026-04-10_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
