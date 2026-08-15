---
phase: 02-regioncc-extraction
fixed_at: 2026-04-09T00:00:00Z
review_path: .planning/phases/02-regioncc-extraction/02-REVIEW.md
iteration: 1
findings_in_scope: 13
fixed: 12
skipped: 1
status: partial
---

# Phase 02: Code Review Fix Report

**Fixed at:** 2026-04-09
**Source review:** .planning/phases/02-regioncc-extraction/02-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 13 (4 Critical + 9 Warning)
- Fixed: 12
- Skipped: 1

## Fixed Issues

### CR-01: Undefined method `try` in GamePlanSyncer — runtime crash

**Files modified:** `app/services/region_cc/game_plan_syncer.rb`
**Commit:** 4a79d587
**Applied fix:** Replaced `try do ... rescue ... end` with `begin ... rescue ... end` block.

---

### CR-02: `map(&:@strip)` passes an ivar as a symbol — runtime crash

**Files modified:** `app/services/region_cc/game_plan_syncer.rb`
**Commit:** c4b50a90
**Applied fix:** Replaced all three occurrences of `.map(&:@strip).map(&:to_i)` with `.map(&:strip).map(&:to_i)` in the score-parsing lines (sc_, in_, br_).

---

### CR-03: `NameError` in `fix_tournament_structure` — undefined local variable

**Files modified:** `app/services/region_cc/tournament_syncer.rb`
**Commit:** a91aa442
**Applied fix:** Replaced `#{season_name}` with `#{@opts[:season_name]}` in the ArgumentError raise inside `fix_tournament_structure`.

---

### CR-04: `pos_hash[]` syntax error — empty key access

**Files modified:** `app/services/region_cc/tournament_syncer.rb`
**Commit:** 0e4aef5f
**Applied fix:** Replaced the `zeilen.each do |_zeile| pos_hash[] end` stub with a proper loop that extracts `pos` and `val` from each `zeile`'s td elements and stores them in `pos_hash`. Requires human verification that the td index assumptions match the actual HTML structure.
**Status:** fixed: requires human verification

---

### WR-01: `rescue Exception` swallows signals and OOM — over-broad rescue

**Files modified:** `app/services/region_cc/tournament_syncer.rb`, `app/services/region_cc/registration_syncer.rb`
**Commit:** dcd223e4
**Applied fix:** Replaced `rescue Exception => e` with `rescue StandardError => e` at both locations in tournament_syncer.rb (lines 187 and 311) and changed `rescue Exception` with no variable in registration_syncer.rb to `rescue StandardError => e` with error message logging.

---

### WR-02: Hardcoded sentinel `next unless league_cc.id == 177` — test-only filter in production code

**Files modified:** `app/services/region_cc/party_syncer.rb`
**Commit:** 5642d97e
**Applied fix:** Removed the `next unless league_cc.id == 177` line from `sync_parties`.

---

### WR-04: `doc.present` instead of `doc.present?` — always truthy

**Files modified:** `app/services/region_cc/party_syncer.rb`
**Commit:** db868ab2
**Applied fix:** Changed `doc.present &&` to `doc.present? &&` in `sync_party_games`.

---

### WR-05: `VERIFY_NONE` disables SSL certificate verification

**Files modified:** `app/models/region_cc.rb`
**Commit:** 4a163426
**Applied fix:** Replaced `http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?` with `http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?` in `discover_admin_url_from_public_site`.

---

### WR-06: Unsaved result of `sync_league_plan` ignored — silent data loss

**Files modified:** `app/services/region_cc/league_syncer.rb`
**Commit:** 1c20eccb
**Applied fix:** Removed both orphaned `Region.find_by_shortname("DBU").id` (line 160) and `Region.find_by_shortname("portal").id` (line 297) calls whose results were discarded. Neither was used downstream.

---

### WR-07: `@strip` assigned to instance variable instead of local variable

**Files modified:** `app/services/region_cc/metadata_syncer.rb`
**Commit:** 95186467
**Applied fix:** Replaced `@strip = option.text.strip; name = @strip` with the single assignment `name = option.text.strip`.

---

### WR-08: `frozen_string_literal` magic comment must be first line

**Files modified:** `app/services/region_cc/club_cloud_client.rb`
**Commit:** 8d499a2e
**Applied fix:** Moved `# frozen_string_literal: true` to line 1 and placed `require "net/http/post/multipart"` after it with a blank line separator.

---

### WR-09: Nil-unsafe unguarded `selector.css("option")` in BranchSyncer

**Files modified:** `app/services/region_cc/branch_syncer.rb`, `app/services/region_cc/competition_syncer.rb`
**Commit:** 86954a40
**Applied fix:** Added `unless selector.present?` guard with error logging and early return/next in BranchSyncer and CompetitionSyncer. LeagueSyncer already had `next unless selector.present?` at the relevant location and required no change.

---

## Skipped Issues

### WR-03: Hardcoded magic values in `sync_party_games` — dead/stub code in production path

**File:** `app/services/region_cc/party_syncer.rb:138-148`
**Reason:** The fix requires replacing the entire hardcoded POST params block with values derived from the `party_cc` object, and completing the commented-out alternative implementation. This is not a mechanical fix — it requires understanding the ClubCloud API contract, the correct field mappings from `party_cc`, and deciding which of the two commented-out approaches is correct. Applying a guess here risks introducing incorrect API calls that silently corrupt data. The method is effectively non-functional already; the safe choice is to leave it for human implementation.
**Original issue:** `spielberichtCheck` POST uses hardcoded static params (`fedId: 20`, `branchId: 6`, `leagueId: 34`, `teamId: 185`, `matchId: 571`, `saison: 2010 / 2011`) rather than values from the loaded `party_cc` object.

---

_Fixed: 2026-04-09_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
