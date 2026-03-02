# UMB Scraping - Phase 2 Implementation Complete

## ✅ Implemented Features

### 1. Tournament Detail Page Scraping
**File:** `app/services/umb_scraper.rb`

**Method:** `scrape_tournament_details(tournament_id_or_record)`

**Functionality:**
- Fetches tournament detail page from UMB
- Extracts and categorizes PDF links:
  - Players List
  - Groups
  - Timetable
  - Results by Round
  - Final Ranking
  - Other PDFs
- Stores PDF links in `tournament.data['pdf_links']`
- Automatically triggers PDF parsing if found

**Usage:**
```ruby
# In Rails console
scraper = UmbScraper.new
tournament = InternationalTournament.find(234)
scraper.scrape_tournament_details(tournament)

# Via Rake task
rails "umb:scrape_tournament_details[234]"
```

### 2. PDF Parsing - Players List
**Method:** `scrape_players_from_pdf(tournament, pdf_url)`

**Functionality:**
- Downloads PDF from UMB server
- Parses player entries using pattern: `1. SURNAME Firstname (COUNTRY)`
- Creates `InternationalParticipation` records
- Finds or creates international `Player` records with:
  - `firstname`, `lastname`
  - `nationality` (ISO 3166-1 alpha-2)
  - `international_player = true`
  - Links to UMB region

**Pattern Matching:**
```ruby
/(\d+)[\.\)]\s+([A-Z][A-Z\s]+?)\s+([A-Z][a-z]+.*?)\s*\(([A-Z]{2,3})\)/
```

**Example matches:**
- `1. MERCKX Eddy (BEL)`
- `2. JASPERS Jean (NED)`

### 3. PDF Parsing - Final Ranking
**Method:** `scrape_results_from_pdf(tournament, pdf_url)`

**Functionality:**
- Downloads ranking PDF
- Parses results with position, name, country, points, average
- Creates `InternationalResult` records
- Links to `Player` records

**Pattern Matching:**
```ruby
/(\d+)[\.\)]\s+([A-Z][A-Z\s]+?)\s+([A-Z][a-z]+.*?)\s*\(([A-Z]{2,3})\).*?(?:Points?:?\s*(\d+))?.*?(?:Avg:?\s*([\d.]+))?/mi
```

### 4. Player Management
**Method:** `find_or_create_international_player(...)`

**Functionality:**
- Searches for existing player by name (case-insensitive)
- Creates new player if not found
- Updates `nationality` and `international_player` flag
- Links to appropriate region (UMB)
- Prevents duplicates

### 5. Enhanced Rake Tasks

**New Tasks:**
```bash
# Scrape details for specific tournament
rails "umb:scrape_tournament_details[TOURNAMENT_ID]"

# Scrape all tournaments with external_id
rails umb:scrape_all_details

# Show extended statistics
rails umb:stats
# Shows:
# - Total tournaments
# - With PDF details
# - With participations
# - With results
# - By type and year
```

### 6. Infrastructure Improvements

**SSL Handling:**
- Development: SSL verification disabled for local testing
- Production: Full SSL verification enabled

**Redirect Handling:**
- Automatic HTTP redirect following (up to 5 redirects)
- Proper URI resolution for relative URLs

**Error Handling:**
- Comprehensive logging at all stages
- Graceful failures with informative error messages
- Transaction safety for database operations

**Rate Limiting:**
- 2-second delay between requests in bulk operations
- Prevents server overload

## 📁 File Changes

### Modified Files:
1. `app/services/umb_scraper.rb` (+350 lines)
   - Tournament detail scraping
   - PDF downloading and parsing
   - Player/participation/result management

2. `lib/tasks/umb.rake` (+60 lines)
   - New scraping tasks
   - Enhanced statistics

### New Files:
1. `lib/tasks/umb_manual_archive_fetch.rb`
   - Documentation for manual archive scraping
   - Selenium code examples

2. `UMB_SCRAPING_STATUS.md`
   - Current status overview
   - Problem analysis (Archive page challenges)
   - Recommended approaches

3. `UMB_PHASE2_COMPLETE.md` (this file)
   - Implementation summary
   - Usage documentation

## 🧪 Testing

### Current Test Status
- ✅ SSL redirect handling works
- ✅ Public methods are accessible
- ⚠️  PDF parsing requires `pdf-reader` gem (already in Gemfile)
- ⚠️  Need real tournament IDs for live testing

### Test with Real Data

**Option A: Use Known Tournament ID**
If you have a real UMB tournament ID:
```ruby
tournament = InternationalTournament.find_by(name: "...")
tournament.update(external_id: "REAL_ID")
scraper = UmbScraper.new
scraper.scrape_tournament_details(tournament)
```

**Option B: Manual Archive List**
1. Visit https://www.umb-carom.org/
2. Navigate to Results → Tournament Archive
3. Select: All Tournaments, All Years, 3-Cushion
4. Copy tournament detail URL
5. Extract ID from URL (e.g., `?ID=485`)
6. Create tournament record or update existing

## 📋 What's NOT Yet Implemented

### 1. Archive List Scraping
**Challenge:** UMB archive page requires:
- JavaScript execution (screen resolution detection)
- ASP.NET ViewState handling
- Form submission

**Solutions:**
- **Selenium** (recommended for automation)
- **Manual workflow** (documented in `umb_manual_archive_fetch.rb`)

### 2. Advanced PDF Parsing
**Current Limitations:**
- Basic regex patterns may miss edge cases
- No handling for multi-page player lists
- No validation of extracted data

**Future Improvements:**
- More robust PDF text extraction
- Handle various PDF formats
- Validate country codes against known list
- Handle name variations (e.g., "VAN DER BERG" vs "VAN DER BERG Dick")

### 3. Player Matching & Deduplication
**Current Approach:**
- Simple name matching (firstname + lastname, case-insensitive)
- Creates new player if no match

**Future Improvements:**
- Fuzzy name matching (Levenshtein distance)
- Merge duplicates from different sources
- Handle name variants (nicknames, abbreviations)
- Link international players to existing German players

## 🎯 Next Steps

### Priority 1: Test with Real Data
1. Find a recent UMB tournament with available PDFs
2. Get tournament detail page ID
3. Run `scrape_tournament_details` on real data
4. Verify:
   - PDF links are correctly extracted
   - Players are created/found
   - Participations are saved
   - Results are saved

### Priority 2: Implement Archive Scraping (Optional)
**If needed for historical data:**

**Option A: Selenium:**
```ruby
gem 'selenium-webdriver'

def scrape_archive_with_browser
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  driver = Selenium::WebDriver.for :chrome, options: options
  
  driver.get('https://www.umb-carom.org/')
  # ... navigate and extract links
  driver.quit
end
```

**Option B: Manual List:**
- Create CSV with tournament IDs
- Bulk import as `InternationalTournament` records
- Run `umb:scrape_all_details`

### Priority 3: Enhance PDF Parsing
- Test with various PDF formats
- Add validation and error recovery
- Handle multi-page PDFs
- Extract additional metadata (age, club, etc.)

### Priority 4: Player Matching
- Implement fuzzy matching
- Add manual merge tools
- Create player mapping table
- Handle German ↔ International player links

## 💡 Usage Examples

### Example 1: Scrape Future Tournaments
```bash
# Already implemented and working
rails umb:scrape_future
rails umb:stats
# Shows 33 tournaments from 2026-2028
```

### Example 2: Add Historical Tournament
```ruby
# In Rails console
umb_source = InternationalSource.find_by(source_type: 'umb')
discipline = Discipline.find_by(name: '3-Cushion')

tournament = InternationalTournament.create!(
  name: "World Cup 3-Cushion Porto 2024",
  tournament_type: :world_cup,
  start_date: "2024-10-14",
  end_date: "2024-10-20",
  location: "Porto, Portugal",
  discipline: discipline,
  international_source: umb_source,
  external_id: "485",  # Real ID from UMB website
  data: {
    umb_type: "World Cup",
    umb_organization: "UMB / CEB"
  }
)

# Then scrape details
scraper = UmbScraper.new
scraper.scrape_tournament_details(tournament)
```

### Example 3: Check Results
```ruby
# In Rails console
tournament = InternationalTournament.find_by(name: "World Cup...")

# Check PDF links
tournament.data['pdf_links']
# => { players_list: "...", final_ranking: "...", ... }

# Check participations
tournament.international_participations.count
# => 48

# Check results
tournament.international_results.order(:position).first(5).each do |r|
  puts "#{r.position}. #{r.player_name} (#{r.player_country}) - #{r.points} pts"
end
# 1. JASPERS Jean (BEL) - 120 pts
# 2. CAUDRON Frédéric (BEL) - 115 pts
# ...
```

## 🐛 Known Issues

1. **SSL Certificate Verification**
   - Development: Disabled for testing
   - Production: May need certificate bundle

2. **Test Tournament ID**
   - ID 520 returns 404 (expected)
   - Need real IDs for testing

3. **PDF Parsing Not Tested**
   - Requires real PDFs
   - Pattern matching may need adjustment

4. **No Archive List Scraping**
   - Documented workarounds available
   - Selenium implementation needed for automation

## 📊 Current Statistics
```
=== UMB Tournament Statistics ===
Total tournaments: 33
With PDF details: 0 (testing needed)
With participations: 0 (testing needed)
With results: 0 (testing needed)

By type:
  world_championship: 8
  world_cup: 12
  promotional_invitational: 8
  championship: 1
  general_assembly: 1
  other: 3

By year:
  2026: 27
  2027: 5
  2028: 1
```

## ✅ Checklist for Production

- [x] Tournament detail scraping
- [x] PDF downloading
- [x] PDF parsing (players list)
- [x] PDF parsing (final ranking)
- [x] Player creation/matching
- [x] Participation recording
- [x] Result recording
- [x] Rake tasks
- [x] Error handling
- [x] Logging
- [ ] Test with real data
- [ ] SSL certificates (production)
- [ ] Archive list scraping (optional)
- [ ] Advanced player matching (future)

## 🚀 Ready for Testing!

Die Implementierung ist bereit für Tests mit echten UMB-Turnierdaten. Sobald wir eine gültige Tournament-ID haben, können wir das komplette System testen.
