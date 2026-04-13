# ClubCloud Fixtures Collection - Guide

**Created:** 2026-02-14  
**Status**: Documentation complete, ready to collect

---

## What was created?

A **complete system for collecting and using ClubCloud HTML fixtures** has been set up:

### Documentation (4 new documents)

1. **test/FIXTURES_QUICK_START.md**
   - 5-minute quick start
   - Step-by-step with checkboxes
   - Perfect for the first fixture collection

2. **test/FIXTURES_SAMMELN.md**
   - Complete guide (60 pages)
   - All scraping entities (Tournaments, Leagues, Clubs, Players)
   - Browser DevTools method
   - Edge Cases & Troubleshooting

3. **test/fixtures/html/README.md**
   - Fixture management
   - Naming conventions
   - Usage in tests
   - Security best practices

4. **test/FIXTURE_WORKFLOW.md**
   - Visual ASCII-Art workflow
   - Diagrams for all processes
   - Learning path for contributors
   - Quick commands reference

### Rake Tasks (4 new tasks)

```bash
# Show URLs for fixtures
bin/rails test:show_fixture_urls REGION=NBV SEASON=2025/2026

# Collect fixtures interactively (with prompts)
bin/rails test:collect_fixtures

# List collected fixtures
bin/rails test:list_fixtures

# Validate fixtures (check HTML structure)
bin/rails test:validate_fixtures
```

**File:** `lib/tasks/test_fixtures.rake`

### Directory Structure

```
test/fixtures/html/
├── .gitkeep               # Git directory placeholder
└── README.md              # Fixture documentation
```

Ready for fixtures:
```
test/fixtures/html/
├── tournaments/
│   ├── list_nbv_2025_2026.html
│   ├── details_nbv_2971.html
│   └── details_nbv_2971_modified.html
├── leagues/
├── clubs/
└── regions/
```

---

## Next Steps

### Step 1: Read Quick Start (5 min)

```bash
cat test/FIXTURES_QUICK_START.md
```

Or in editor:
```bash
vim test/FIXTURES_QUICK_START.md
```

### Step 2: Collect first fixture (15 min)

```bash
# 1. Show URLs
bin/rails test:show_fixture_urls REGION=NBV SEASON=2025/2026

# 2. Open the URL in browser
# 3. DevTools → Network → Copy Response
# 4. Save:
mkdir -p test/fixtures/html
cd test/fixtures/html
pbpaste > tournament_list_nbv_2025_2026.html

# 5. Verify
head -10 tournament_list_nbv_2025_2026.html
```

### Step 3: Activate test (5 min)

```ruby
# test/scraping/tournament_scraper_test.rb
# → remove skip lines
# → include fixture (see Quick Start)
```

### Step 4: Run tests

```bash
bin/rails test:scraping
```

**Expected:** Tests run (some still `skip`)

---

## Recommended Order

### Phase 1: Minimum (today, 15 min)

**Collect 3 fixtures:**

1. `tournament_list_nbv_2025_2026.html`
2. `tournament_details_nbv_2971.html`
3. `tournament_details_nbv_2971_modified.html`

**Result:**
- 7 Tournament Scraper Tests can be activated
- Change Detection Tests work

### Phase 2: Extended (later, +30 min)

**Collect +3 fixtures:**

4. `league_list_nbv_2025_2026.html`
5. `league_details_oberliga_nbv.html`
6. `club_bcw_players_2025_2026.html`

**Result:**
- All 14 scraping tests fully functional
- Complete coverage

### Phase 3: Optional (as needed)

- Edge cases (empty lists, error pages)
- Additional regions (BBV, WBV, etc.)
- Historical fixtures (Season 2024/2025)

---

## Which Fixtures for Which Tests?

### Concern Tests (already complete)

```bash
bin/rails test:critical
```

**Status:** All 14 tests pass

- `test/concerns/local_protector_test.rb` (8 tests)
- `test/concerns/source_handler_test.rb` (6 tests)

**No fixtures required!**

### Scraping Tests (waiting for fixtures)

```bash
bin/rails test:scraping
```

**Status:** 14 tests, all marked with `skip`

#### Tournament Scraper (7 tests)

**Requires:**
- `tournament_list_nbv_2025_2026.html`
- `tournament_details_nbv_2971.html`

**Tests:**
```ruby
test/scraping/tournament_scraper_test.rb
├─▶ test_scraping_extracts_tournament_details
├─▶ test_scraping_creates_tournament_cc_record
├─▶ test_scraping_handles_missing_fields_gracefully
├─▶ test_scraping_updates_existing_tournament
├─▶ test_scraping_multiple_tournaments
├─▶ test_scraping_respects_abandoned_tournaments
└─▶ test_scraping_with_vcr
```

#### Change Detection (7 tests)

**Requires:**
- `tournament_details_nbv_2971.html` (Original)
- `tournament_details_nbv_2971_modified.html` (Modified)

**Tests:**
```ruby
test/scraping/change_detection_test.rb
├─▶ test_detects_changed_tournament_title
├─▶ test_detects_changed_location
├─▶ test_detects_new_seedings
├─▶ test_sync_date_updates_on_changes
├─▶ test_sync_date_unchanged_when_no_changes
├─▶ test_tracks_changes_across_multiple_scrapes
└─▶ test_change_detection_with_vcr
```

---

## Tips for Efficient Collection

### 1. Batch collection (open multiple tabs)

```bash
# Show URLs
bin/rails test:show_fixture_urls

# In browser:
# - Tab 1: Tournament List
# - Tab 2: Tournament Details (id=2971)
# - Tab 3: Tournament Details (id=3142)

# Open DevTools in all tabs
# Copy and save all at once
```

### 2. Understanding URL patterns

**Tournament List:**
```
https://ndbv.de/sb_meisterschaft.php?
  p=20--2025/2026--0--2-1-100000-
    ^^  ^^^^^^^^
    |   |
    |   └─ Season
    └─ region_cc_id
```

**Tournament Details:**
```
https://ndbv.de/sb_meisterschaft.php?
  p=20--2025/2026-2971----1-100000-
    ^^  ^^^^^^^^  ^^^^
    |   |         |
    |   |         └─ Tournament cc_id
    |   └─ Season
    └─ region_cc_id
```

### 3. Creating a modified fixture

```bash
# Option A: Copy and manually edit
cp tournament_details_nbv_2971.html \
   tournament_details_nbv_2971_modified.html

vim tournament_details_nbv_2971_modified.html
# Change title: "Norddeutsche" → "Norddeutsche 2025"

# Option B: Using sed
cp tournament_details_nbv_2971.html \
   tournament_details_nbv_2971_modified.html

sed -i '' 's/Norddeutsche Meisterschaft/Norddeutsche Meisterschaft 2025/g' \
  tournament_details_nbv_2971_modified.html
```

---

## Current Test Status

### Working Tests (without fixtures)

```bash
bin/rails test:critical

# Output:
Running critical tests...
Running concern tests...
14 runs, 31 assertions, 0 failures, 0 errors, 0 skips ✅

Running scraping tests...
14 runs, 0 assertions, 0 failures, 0 errors, 14 skips ⏸️
```

**Concern Tests:** 14 tests (100% pass)  
**Scraping Tests:** 14 tests (100% skip, waiting for fixtures)

### After Fixture Collection (goal)

```bash
bin/rails test:critical

# Expected Output:
Running critical tests...
Running concern tests...
14 runs, 31 assertions, 0 failures, 0 errors, 0 skips ✅

Running scraping tests...
14 runs, 42 assertions, 0 failures, 0 errors, 0 skips ✅
```

**All Tests:** 28 tests (100% pass)

---

## How to Identify the Right Fixtures

### Method 1: Derived from daily_update Task

```ruby
# lib/tasks/scrape.rake - daily_update shows all scraping operations:

1. Region.scrape_regions
   └─▶ Fixture: region_nbv_home.html

2. Location.scrape_locations
   └─▶ Fixture: location_list_nbv.html

3. Club.scrape_clubs (incl. Players)
   └─▶ Fixture: club_bcw_players_2025_2026.html

4. Tournament.scrape_single_tournaments_public_cc
   └─▶ Fixtures:
       - tournament_list_nbv_2025_2026.html
       - tournament_details_nbv_2971.html

5. League.scrape_leagues_from_cc
   └─▶ Fixtures:
       - league_list_nbv_2025_2026.html
       - league_details_oberliga_nbv.html
```

### Method 2: Derived from test code

```ruby
# test/scraping/tournament_scraper_test.rb

test "scraping extracts tournament details" do
  # This fixture is needed:
  html = File.read(Rails.root.join('test/fixtures/html/tournament_details_nbv_2971.html'))
  #                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  #                                                    Collect this file!
end
```

### Method 3: Observe live system

```bash
# Rails Console
bin/rails console

# Run scraping and log URLs:
season = Season.find_by_name("2025/2026")
region = Region.find_by_shortname("NBV")

# URLs being scraped:
tournament = season.tournaments.first
puts tournament.tournament_cc_url
# → Open this URL in browser and collect HTML
```

---

## For Contributors / Open Source

### Good First Issue: Collect a fixture

**Perfect entry point into the project!**

**Task:**
1. Read `test/FIXTURES_QUICK_START.md` (5 min)
2. Collect 1 fixture (15 min)
3. Activate test (remove skip)
4. Create pull request

**Labels:**
- `good first issue`
- `testing`
- `scraping`
- `documentation`

**Learning outcomes:**
- Rails Testing Framework (Minitest)
- WebMock & HTTP Stubbing
- Nokogiri HTML Parsing
- ClubCloud API structure

### Issue Template

```markdown
## Collect Fixture: [Entity-Name]

**Description:**
Collect ClubCloud HTML fixture for [Tournament List / Details / etc.]

**Fixture:**
- [ ] File: `test/fixtures/html/tournament_list_nbv_2025_2026.html`
- [ ] URL: (see `bin/rails test:show_fixture_urls`)

**Activate test:**
- [ ] Remove skip in `test/scraping/tournament_scraper_test.rb`
- [ ] Include fixture (see Quick Start)

**Documentation:**
- FIXTURES_QUICK_START.md

**Effort:** 15-30 minutes  
**Labels:** `good first issue`, `testing`, `scraping`
```

---

## Security Checklist

**Before every commit:**

```bash
# 1. Search for sensitive data
grep -ri "password" test/fixtures/html/
grep -ri "session" test/fixtures/html/
grep -ri "token" test/fixtures/html/
grep -ri "cookie" test/fixtures/html/

# 2. If found: Replace manually
vim test/fixtures/html/problematic_fixture.html
# password="real123" → password="<CC_PASSWORD>"

# 3. Check git status
git diff test/fixtures/html/

# 4. Commit only when clean
git add test/fixtures/html/
git commit -m "Add: ClubCloud fixtures for tournament scraping"
```

---

## All Documentation Files

| File | Description | Size |
|------|-------------|------|
| `test/FIXTURES_QUICK_START.md` | 5-min Quick Start | ~3 KB |
| `test/FIXTURES_SAMMELN.md` | Complete guide | ~25 KB |
| `test/fixtures/html/README.md` | Fixture management | ~12 KB |
| `test/FIXTURE_WORKFLOW.md` | ASCII-Art Workflow | ~8 KB |
| `test/README.md` | Test Guide (updated) | ~15 KB |
| `lib/tasks/test_fixtures.rake` | Rake Tasks | ~8 KB |
| **TOTAL** | | **~71 KB** |

---

## Summary

### What is complete?

- [x] Complete documentation (4 guides)
- [x] 4 rake tasks for fixture management
- [x] Directory structure prepared
- [x] Test framework ready
- [x] 14 concern tests passing
- [x] 14 scraping tests prepared (with `skip`)

### What is still missing?

- [ ] Collect ClubCloud HTML fixtures (15-30 min)
- [ ] Activate scraping tests (remove `skip`)
- [ ] Run tests and validate

### Recommended next step

```bash
# 1. Read Quick Start (5 min)
cat test/FIXTURES_QUICK_START.md

# 2. Show URLs
bin/rails test:show_fixture_urls REGION=NBV SEASON=2025/2026

# 3. Open in browser, copy HTML, save
mkdir -p test/fixtures/html
# ... DevTools → Copy Response
pbpaste > test/fixtures/html/tournament_list_nbv_2025_2026.html

# 4. Verify
bin/rails test:validate_fixtures

# 5. Activate test
vim test/scraping/tournament_scraper_test.rb
# → remove skip

# 6. Test
bin/rails test:scraping
```

---

## Questions?

**Consult documentation:**
- Quick Start: `test/FIXTURES_QUICK_START.md`
- Complete: `test/FIXTURES_SAMMELN.md`
- Workflow: `test/FIXTURE_WORKFLOW.md`

**GitHub:**
- Issues (Label: `testing`)
- Discussions

---

**Status**: Ready to collect!  
**Next step:** FIXTURES_QUICK_START.md
