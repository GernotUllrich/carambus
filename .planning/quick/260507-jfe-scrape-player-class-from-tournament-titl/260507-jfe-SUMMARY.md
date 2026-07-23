---
phase: 260507-jfe
plan: 01
subsystem: scraping / tournament-model
tags: [scraping, tournament, player_class, region, quick-task]
key-files:
  created: []
  modified:
    - app/models/tournament.rb
    - app/models/region.rb
    - test/models/tournament_test.rb
decisions:
  - "Regex iterates PLAYER_CLASS_ORDER in declared order (7 6 5 4 3 2 1 I II III); first match wins. Ambiguous titles return the higher-numbered class that appears earlier in the constant, not the first in title text."
  - "Standalone trailing form requires leading whitespace so '47/2' fraction digits and year suffixes cannot match as class tokens."
  - "Non-PLAYER_CLASS_ORDER classifiers (Damen, U17, Schüler, IV+) intentionally return nil — deferred to JFE-02."
  - "DRY violation accepted at two scrape sites — godObject refactor out of scope per extend-before-build SKILL."
metrics:
  duration: ~25 min
  completed: 2026-05-07
  tasks_completed: 2
  files_modified: 3
  new_tests: 16
---

# Quick 260507-jfe: Scrape player_class from tournament title — Summary

**One-liner:** Regex parser extracts canonical player_class token from German-federation tournament titles at scrape time, wired into both Region scrape paths alongside existing is_handicap derivation.

## What Was Built

### Tournament.parse_player_class_from_title (app/models/tournament.rb:186)

New class method (~20 LOC + comments). Pure/idempotent — no DB queries.

- Iterates `Discipline::PLAYER_CLASS_ORDER` (`%w[7 6 5 4 3 2 1 I II III]`) in declared order.
- Two recognition forms per token:
  - **Marker form:** `\b(?:Klasse|Kl\.?|KK)\s+<token>\b` (case-insensitive) — matches "Klasse 5", "Kl. III", "KK 7".
  - **Standalone trailing form:** `(?:\s)<token>\s*\z` — matches titles ending with the token after whitespace (e.g. "Stadtmeisterschaft Cadre 47/2 I"). Leading whitespace prevents matching digits inside year strings or fractions.
- Returns `nil` for blank/nil titles and titles with no recognised class.

### Region scrape sites (app/models/region.rb)

Two 1-line additions, each mirroring the existing `is_handicap = name =~ /Vorgabe/i` pattern:

| Site | Method | Line (post-edit) |
|------|--------|------------------|
| 1 | `Region#scrape_tournaments_data` | 563 — `parsed_player_class = Tournament.parse_player_class_from_title(name)` + `player_class: parsed_player_class` in `Tournament.create(...)` |
| 2 | `Region#scrape_upcoming_tournaments` | 947 — same shape in `Tournament.create!(...)` |

Grep confirmation: `grep -c "Tournament.parse_player_class_from_title" app/models/region.rb` returns **2**.

## Tests

| Group | Count | Status |
|-------|-------|--------|
| Unit tests — `parse_player_class_from_title` | 14 | GREEN |
| Integration tests — `player_class` persisted via `Tournament.create` | 2 | GREEN |
| **Total new tests** | **16** | **GREEN** |
| Pre-existing tournament tests | 4 (1 skip) | unchanged |

RED → GREEN transition: 14 unit tests all failed with `NoMethodError` in RED phase, then all passed in GREEN phase.

Fixtures used: `regions(:nbv)` (id 50_000_001, "Niedersächsischer Billard-Verband") and `seasons(:current)` (id 50_000_001, "2025/2026") — both present in test fixtures. No substitution needed.

## Sanity Checks

- `grep -c "Tournament.parse_player_class_from_title" app/models/region.rb` → **2** ✓
- `Tournament.parse_player_class_from_title` is `def self.`, one positional arg, returns String or nil ✓
- No DB queries in parser (locked by `assert_no_queries` test) ✓
- LocalProtector: both edits are inside `unless tournament.present?` blocks — fresh creates only, no existing record mutated ✓

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Plan-prescribed test bug] Ambiguous title expected value corrected from "3" to "4"**

- **Found during:** GREEN phase
- **Issue:** Plan said `Tournament.parse_player_class_from_title("Klasse 3 / Klasse 4 Mixed")` → `"3"`. The comment in the test incorrectly stated "'3' comes before '4' in iteration order". In reality, `PLAYER_CLASS_ORDER = %w[7 6 5 4 3 2 1 I II III]` — "4" is at index 3, "3" at index 4. The loop reaches "4" before "3" and finds the `\bKlasse 4\b` match first. Correct return value is `"4"`.
- **Fix:** Updated test assertion from `assert_equal "3"` to `assert_equal "4"` and corrected the explanatory comment.
- **Files modified:** `test/models/tournament_test.rb:126`
- **Commit:** 93d3a203 (included in same Task 1 commit)

### Worktree Configuration (Rule 3 - Blocking issue)

- **Found during:** RED phase setup
- **Issue:** Git worktree at `.claude/worktrees/agent-a21a67bcf568182c7` lacked gitignored config files (`database.yml`, `cable.yml`, `carambus.yml`) that are only present in the parent `carambus_bcw` checkout.
- **Fix:** Symlinked three files from `carambus_bcw/config/` into the worktree's `config/` directory. Symlinks are gitignored and do not appear in `git status`.

## Deferred / Out-of-scope Patterns

Per Open Question 1 in the plan, the following title patterns were observed but are intentionally left as `nil` (not in `Discipline::PLAYER_CLASS_ORDER`):

| Pattern | Example | Reason |
|---------|---------|--------|
| `Damen` | "Pokalturnier Damen 9-Ball" | Different classification system |
| `U17` | Hypothetical youth tournament | Age-based, not class-based |
| `Schüler` | Hypothetical youth category | Age-based, not class-based |
| Roman IV+ | "Klasse IV" | Beyond PLAYER_CLASS_ORDER (max is III) |

These are candidates for JFE-02 if coverage needs to be extended.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The parser is a pure class method operating on the existing `player_class :string` column. Trust boundary (external CC HTML → Region.scrape_*) was pre-existing; this change only adds a whitelist-regex derived attribute alongside the existing `is_handicap` derivation. No new threat surface.

## Commits

| Hash | Message |
|------|---------|
| `93d3a203` | feat(260507-jfe-01): add Tournament.parse_player_class_from_title class method |
| `a2794edb` | feat(260507-jfe-01): wire parse_player_class_from_title into Region scrape sites |

## Self-Check

- [x] `app/models/tournament.rb` contains `def self.parse_player_class_from_title` at line 186
- [x] `app/models/region.rb` contains exactly 2 occurrences of `Tournament.parse_player_class_from_title`
- [x] Commits `93d3a203` and `a2794edb` exist in git log
- [x] 20 tournament tests: 0 failures, 0 errors, 1 pre-existing skip
- [x] `test:critical` pre-existing failures (ChangeDetectionTest, 5 errors) confirmed pre-existing at parent commit — out of scope

## Self-Check: PASSED
