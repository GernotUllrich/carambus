---
phase: 02-regioncc-extraction
reviewed: 2026-04-09T00:00:00Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - app/models/region_cc.rb
  - app/services/region_cc/branch_syncer.rb
  - app/services/region_cc/club_cloud_client.rb
  - app/services/region_cc/club_syncer.rb
  - app/services/region_cc/competition_syncer.rb
  - app/services/region_cc/game_plan_syncer.rb
  - app/services/region_cc/league_syncer.rb
  - app/services/region_cc/metadata_syncer.rb
  - app/services/region_cc/party_syncer.rb
  - app/services/region_cc/registration_syncer.rb
  - app/services/region_cc/tournament_syncer.rb
  - test/services/region_cc/branch_syncer_test.rb
  - test/services/region_cc/club_cloud_client_test.rb
  - test/services/region_cc/club_syncer_test.rb
  - test/services/region_cc/competition_syncer_test.rb
  - test/services/region_cc/game_plan_syncer_test.rb
  - test/services/region_cc/league_syncer_test.rb
  - test/services/region_cc/metadata_syncer_test.rb
  - test/services/region_cc/party_syncer_test.rb
  - test/services/region_cc/registration_syncer_test.rb
  - test/services/region_cc/tournament_syncer_test.rb
findings:
  critical: 4
  warning: 9
  info: 5
  total: 18
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-04-09
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

This phase extracts ClubCloud sync logic from the `RegionCc` model (~2700 lines) into 10 focused service classes. The structural extraction is well-executed: the dispatcher pattern is consistent, client injection is clean, and the test suite covers the primary dispatch paths. However, several bugs were directly carried over from the original model code and new ones were introduced during extraction. Four critical issues affect correctness and will silently corrupt data or cause runtime crashes in production paths.

---

## Critical Issues

### CR-01: Undefined method `try` in GamePlanSyncer — runtime crash

**File:** `app/services/region_cc/game_plan_syncer.rb:78`
**Issue:** `try do` is not valid Ruby. `try` is an ActiveRecord/`andand` helper that takes a method name symbol, not a block. This code will raise `NoMethodError: undefined method 'try'` at runtime on any request that enters the nested table parsing loop. The intent is clearly a `begin...rescue` block.
**Fix:**
```ruby
# Replace:
try do
  # ... parse table rows
rescue StandardError => e
  Rails.logger.info "#{e} #{e.backtrace.join("\n")}"
end

# With:
begin
  # ... parse table rows
rescue StandardError => e
  Rails.logger.info "#{e} #{e.backtrace.join("\n")}"
end
```

---

### CR-02: `map(&:@strip)` passes an ivar as a symbol — runtime crash

**File:** `app/services/region_cc/game_plan_syncer.rb:167,171,177`
**Issue:** `map(&:@strip)` attempts to convert the instance variable reference `@strip` to a proc via `to_proc`. This does not invoke `String#strip`; instead it will raise `TypeError: @strip is not a symbol` (or silently pass the symbol `:@strip` to `to_proc` which will crash on first element). All three score-parsing lines are broken. This pattern also appears in `metadata_syncer.rb:121` where `@strip = option.text.strip` stores the result in an instance variable, which is a different bug (leaked state into instance scope).

**Fix for game_plan_syncer.rb (all three occurrences):**
```ruby
# Replace:
.split(":").map(&:@strip).map(&:to_i)

# With:
.split(":").map(&:strip).map(&:to_i)
```

---

### CR-03: `NameError` in `fix_tournament_structure` — undefined local variable

**File:** `app/services/region_cc/tournament_syncer.rb:278`
**Issue:** `raise ArgumentError, "unknown season name #{season_name}", caller` references `season_name` which is not defined in this method. The local variable is `@opts[:season_name]` (accessed via `@opts`). This will raise `NameError: undefined local variable or method 'season_name'` whenever this guard fires — replacing the intended `ArgumentError` with an unintended `NameError`.
**Fix:**
```ruby
# Line 278 — replace:
raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

# With:
raise ArgumentError, "unknown season name #{@opts[:season_name]}", caller if season.blank?
```

---

### CR-04: `pos_hash[]` syntax error — empty key access

**File:** `app/services/region_cc/tournament_syncer.rb:237`
**Issue:** `pos_hash[]` is syntactically valid Ruby but semantically wrong — it calls `Hash#[]` with no arguments, which raises `ArgumentError: wrong number of arguments (given 0, expected 1)`. This is inside the "Mannschaften" branch of `sync_tournament_series_ccs`, so any tournament series with team entries will crash.
**Fix:**
```ruby
# The loop variable `_zeile` is discarded. The intent is likely:
zeilen.each do |zeile|
  # extract position/value from zeile td elements, e.g.:
  pos = zeile.css("td")[0].andand.text.andand.to_i
  val = zeile.css("td")[1].andand.text
  pos_hash[pos] = val if pos.present?
end
```

---

## Warnings

### WR-01: `rescue Exception` swallows signals and OOM — over-broad rescue

**File:** `app/services/region_cc/tournament_syncer.rb:187,311`
**File:** `app/services/region_cc/registration_syncer.rb:108`
**Issue:** `rescue Exception` catches `SignalException` (`SIGTERM`, `SIGINT`), `NoMemoryError`, and `SystemExit`, preventing clean process shutdown and masking fatal errors. `StandardError` is the correct base class for application-level rescue. The instance in `registration_syncer.rb:108` additionally logs nothing on rescue — swallowing the error completely.
**Fix:**
```ruby
# Replace all three:
rescue Exception => e      # tournament_syncer.rb:187
rescue Exception => e      # tournament_syncer.rb:311
rescue Exception           # registration_syncer.rb:108

# With:
rescue StandardError => e
  Rails.logger.error "Error: #{e.message}"
```

---

### WR-02: Hardcoded sentinel `next unless league_cc.id == 177` — test-only filter in production code

**File:** `app/services/region_cc/party_syncer.rb:52`
**Issue:** `next unless league_cc.id == 177` hard-codes a specific database ID, causing `sync_parties` to silently skip all leagues except the one with internal ID 177. This was presumably left in from development/debugging and makes `sync_parties` non-functional for all other leagues in production.
**Fix:** Remove the filter entirely, or gate it behind a `@opts[:debug_league_id]` guard if single-league debugging is needed:
```ruby
# Remove line 52:
next unless league_cc.id == 177
```

---

### WR-03: Hardcoded magic values in `sync_party_games` — dead/stub code in production path

**File:** `app/services/region_cc/party_syncer.rb:138-148`
**Issue:** The `spielberichtCheck` POST call uses hardcoded static params (`fedId: 20`, `branchId: 6`, `leagueId: 34`, `teamId: 185`, `matchId: 571`, `saison: 2010 / 2011`). `2010 / 2011` is also integer division evaluating to `0`. The actual `party_cc` data is fetched (line 133) but then completely ignored. This method is non-functional for any real party lookup.
**Fix:** Replace hardcoded params with values derived from the `party_cc` object that was already loaded. The commented-out block below line 149 shows the intended implementation and should be completed.

---

### WR-04: `doc.present` instead of `doc.present?` — always truthy

**File:** `app/services/region_cc/party_syncer.rb:169`
**Issue:** `doc.present` calls the method without the predicate `?`, returning the doc object itself (always truthy). The intended check `doc.present?` would return false for nil/blank. The condition `err_msg = doc.present && ...` will always evaluate the right side regardless of whether `doc` is nil, bypassing the intended nil guard.
**Fix:**
```ruby
# Replace:
err_msg = doc.present && doc.css('input[name="errMsg"]')[0].andand["value"]

# With:
err_msg = doc.present? && doc.css('input[name="errMsg"]')[0].andand["value"]
```

---

### WR-05: `VERIFY_NONE` disables SSL certificate verification

**File:** `app/models/region_cc.rb:365`
**Issue:** `http.verify_mode = OpenSSL::SSL::VERIFY_NONE` in `discover_admin_url_from_public_site` disables TLS certificate validation, making the connection vulnerable to MITM attacks. Admin credentials are passed over HTTPS connections elsewhere — if this method is used to discover the admin URL that credentials are subsequently sent to, an attacker could intercept credential-bearing requests.
**Fix:**
```ruby
# Remove the VERIFY_NONE line entirely. Net::HTTP defaults to VERIFY_PEER when use_ssl=true.
# If self-signed certs are needed in development, gate on Rails.env.development?
http.verify_mode = OpenSSL::SSL::VERIFY_PEER
```

---

### WR-06: Unsaved result of `sync_league_plan` ignored — silent data loss

**File:** `app/services/region_cc/league_syncer.rb:160`
**Issue:** `Region.find_by_shortname("DBU").id` in `sync_league_teams` fetches the DBU region ID but the result is never assigned to a variable. If `find_by_shortname("DBU")` returns nil, this crashes with `NoMethodError` on `.id`. Similarly at line 297 in `sync_league_teams_new`: `Region.find_by_shortname("portal").id` — the result is discarded AND `"portal"` is not a region shortname used elsewhere (likely a copy-paste error from the original model).
**Fix:**
```ruby
# sync_league_teams line 160 — either assign or remove:
# Remove the orphaned call entirely if the DBU ID is not used downstream.

# sync_league_teams_new line 297 — "portal" appears incorrect:
# Verify intent; if the result is needed, assign it:
portal_region_id = Region.find_by_shortname("portal")&.id
```

---

### WR-07: `@strip` assigned to instance variable instead of local variable

**File:** `app/services/region_cc/metadata_syncer.rb:121`
**Issue:** `@strip = option.text.strip` stores the stripped text in `@strip` (an instance variable) rather than a local variable. This leaks state across loop iterations and the next line immediately reads it back: `name = @strip`. While functionally equivalent within a single call, it pollutes instance state and will confuse readers who expect `@` variables to represent meaningful object state. This is a copy-paste artifact from the original model.
**Fix:**
```ruby
# Replace:
@strip = option.text.strip
name = @strip

# With:
name = option.text.strip
```

---

### WR-08: `frozen_string_literal` magic comment must be first line

**File:** `app/services/region_cc/club_cloud_client.rb:1-2`
**Issue:** `require "net/http/post/multipart"` appears on line 1, before the `# frozen_string_literal: true` comment on line 2. Ruby only honours the frozen string literal magic comment when it is the very first line of the file. All string literals in this file will be mutable, contrary to the project convention and potentially causing thread-safety issues in multi-threaded Puma.
**Fix:**
```ruby
# frozen_string_literal: true

require "net/http/post/multipart"
```

---

### WR-09: Nil-unsafe unguarded `selector.css("option")` in BranchSyncer

**File:** `app/services/region_cc/branch_syncer.rb:24-25`
**Issue:** `selector = doc.css('select[name="branchId"]')[0]` followed immediately by `option_tags = selector.css("option")` will raise `NoMethodError: undefined method 'css' for nil` if the API response does not contain the expected `<select>` element (e.g., on error pages, session timeout, or HTML structure change). The same pattern exists in `competition_syncer.rb:37` and `league_syncer.rb:75`.
**Fix:**
```ruby
selector = doc.css('select[name="branchId"]')[0]
unless selector.present?
  RegionCc.logger.error "[get_branches_from_cc] No branchId select found in response"
  return []
end
option_tags = selector.css("option")
```

---

## Info

### IN-01: Duplicate `mm3btb_map` / `mm3bmb_map` hash literals

**File:** `app/services/region_cc/league_syncer.rb:198-231,364-412`
**Issue:** The `mm3btb_map` hardcoded name-mapping hash is defined identically in both `sync_league_teams` and `sync_league_teams_new`. The `mm3bmb_map` also duplicated. These should be extracted to private constants or a shared helper to eliminate the duplication and make future corrections apply in one place.
**Fix:** Extract to private constants at the class level:
```ruby
MM3BTB_MAP = { "2014/2015" => { ... }, ... }.freeze
MM3BMB_MAP = { "2015/2016" => { ... }, ... }.freeze
```

---

### IN-02: Commented-out code blocks throughout service files

**File:** `app/services/region_cc/party_syncer.rb:149-168`
**File:** `app/services/region_cc/registration_syncer.rb:61-63`
**File:** `app/services/region_cc/game_plan_syncer.rb:115,121,122,125`
**Issue:** Multiple commented-out code blocks (including a `deleteMeldeliste` call and an entire alternative `spielbericht` implementation) remain in the extracted services. These were carried over from the original model code and should be removed or converted to documented TODOs if intentional.

---

### IN-03: `CategoryCc.last` / `ChampionshipTypeCc.last` — pointless query

**File:** `app/services/region_cc/metadata_syncer.rb:68`
**File:** `app/services/region_cc/tournament_syncer.rb:271`
**Issue:** Both files call `CategoryCc.last` / `ChampionshipTypeCc.last` at the end of an `options.each` loop but discard the result. These are database queries that execute on every loop iteration with no effect. They appear to be debugging artifacts from the original model.
**Fix:** Remove both calls.

---

### IN-04: TODO comments referencing test-only branch restrictions in production code

**File:** `app/services/region_cc/tournament_syncer.rb:43,100`
**File:** `app/services/region_cc/game_plan_syncer.rb:115,116`
**Issue:** `# TODO: remove restriction on branch` comments mark `next if branch_cc.name == "Pool" || branch_cc.name == "Snooker"` guards that were apparently added for testing only. These silently exclude Pool and Snooker tournaments from all sync operations in production.

---

### IN-05: `region_cc` redundantly re-fetched from `region` in MetadataSyncer and GamePlanSyncer

**File:** `app/services/region_cc/metadata_syncer.rb:39-40`
**File:** `app/services/region_cc/game_plan_syncer.rb:40-42`
**Issue:** Both services receive `@region_cc` as an injected dependency but then look it up again via `Region.find_by_shortname(...).region_cc`. This adds two unnecessary database queries per sync call and introduces a potential nil crash if `region.region_cc` is nil for the looked-up region (vs. the injected `@region_cc` which is guaranteed non-nil by the caller).
**Fix:** Use `@region_cc.branch_ccs` directly instead of looking up via region:
```ruby
# Replace:
region = Region.find_by_shortname(@opts[:context].upcase)
region_cc = region.region_cc
region_cc.branch_ccs.each do |branch_cc|

# With:
@region_cc.branch_ccs.each do |branch_cc|
```

---

_Reviewed: 2026-04-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
