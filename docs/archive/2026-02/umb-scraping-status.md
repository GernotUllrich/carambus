# UMB Scraping - Current Status & Next Steps

## ✅ Completed (Phase 1)

### Infrastructure
- ✅ Database schema extended (`umb_player_id`, `nationality` fields)
- ✅ International regions created (UMB, CEB, CPB, ACC, ABSC)
- ✅ 34 national clubs created (pseudo-clubs for countries)
- ✅ UMB Source initialized
- ✅ 33 existing tournaments in database (from Future Tournaments page)

### Code
- ✅ `UmbScraper` service with redirect handling
- ✅ Rake tasks (`umb:scrape_future`, `umb:scrape_archive`, `umb:stats`)
- ✅ Background job (`ScrapeUmbArchiveJob`)
- ✅ Seeds for international data

## 🔄 Current Challenge: UMB Archive Page

### Problem
The UMB archive page (`https://www.umb-carom.org/PG342L2/Union-Mondiale-de-Billard.aspx`) is **session-based**:
- Requires JavaScript execution for screen resolution detection
- Uses ASP.NET ViewState for form submissions
- Multiple redirects before reaching actual content
- Form-based filtering (By Events, By Years, Disciplines)

### Solutions

#### Option A: Selenium/Browser Automation (Recommended for Archive)
```ruby
# gem 'selenium-webdriver'
# Use headless Chrome to interact with the form
# Fill "All Tournaments" + "All Years"
# Extract tournament detail links
```

**Pros:** Can handle JavaScript, sessions, forms
**Cons:** Requires browser setup, slower

#### Option B: Manual Tournament List (Pragmatic)
- UMB publishes tournament results on files.umb-carom.org
- We already have 33 tournaments from Future Tournaments page
- We can focus on parsing **tournament detail pages** and **PDFs**

## 📋 Recommended Next Steps

### Priority 1: Tournament Detail Page Parsing
**Focus:** Parse individual tournament pages (when we have the URL)

Example tournament detail page structure:
```
/public/TournamentDetails.aspx?ID=123
├── Tournament Info (name, dates, location)
├── PDF Links:
│   ├── Players List.pdf
│   ├── Groups.pdf
│   ├── Timetable.pdf
│   ├── Results by Round.pdf
│   └── Final Ranking.pdf
```

**Implementation:**
```ruby
def scrape_tournament_details(tournament_id)
  tournament = InternationalTournament.find(tournament_id)
  html = fetch_url(tournament.source_url)
  doc = Nokogiri::HTML(html)
  
  # Find PDF links
  pdf_links = doc.css('a[href$=".pdf"]').map { |a| a['href'] }
  
  # Store in tournament.data
  tournament.data['pdf_links'] = pdf_links
  tournament.save
end
```

### Priority 2: PDF Parsing (Players List & Final Ranking)
**Tools:** `pdf-reader` gem

**Players List PDF** structure (typical):
```
1. SURNAME Firstname (COUNTRY)
2. VAN DER BERG Dick (NED)
3. JASPERS Jean (BEL)
...
```

**Final Ranking PDF** structure:
```
1. SURNAME Firstname (COUNTRY) - Points: 120, Avg: 2.456
2. ...
```

**Implementation:**
```ruby
# Gemfile
gem 'pdf-reader'

def scrape_players_from_pdf(tournament, pdf_url)
  pdf = download_pdf(pdf_url)
  reader = PDF::Reader.new(StringIO.new(pdf))
  text = reader.pages.map(&:text).join("\n")
  
  # Parse players: position. LASTNAME Firstname (COUNTRY)
  players = text.scan(/(\d+)\.\s+([A-Z\s]+)\s+([A-Za-z\s]+)\s*\(([A-Z]{2,3})\)/)
  
  players.each do |pos, lastname, firstname, country|
    create_international_participation(tournament, firstname, lastname, country)
  end
end
```

### Priority 3: Archive Scraping (Later)
Two approaches:

**A) Selenium for Full Archive:**
```ruby
# Use Selenium to fill form and get all tournament links
require 'selenium-webdriver'

driver = Selenium::WebDriver.for :chrome, options: chrome_options
driver.get('https://www.umb-carom.org/...')
# Select "All Tournaments", "All Years"
# driver.find_element(name: 'ByEvents').select('All Tournaments')
# Extract links
```

**B) Known Tournament URLs:**
- Files.umb-carom.org often has predictable patterns
- We can build URLs if we know tournament IDs
- Example: `/public/TournamentDetails.aspx?ID=375`

## 🎯 Recommended Action Plan

1. **Implement Tournament Detail Page parsing** (low complexity, high value)
2. **Implement PDF parsing for Players List** (medium complexity, high value)
3. **Implement PDF parsing for Final Ranking** (medium complexity, high value)
4. **Test with existing 33 tournaments**
5. **Add Selenium for archive scraping** (optional, for completeness)

## 📝 Notes

- **Development environment:** `carambus_api` (debugging mode)
- **No commits** until explicitly requested
- **Database:** `carambus_api_development` with production data
- **Existing tournaments:** 33 from Future Tournaments (2026-2028)

## Next Implementation

Shall we proceed with **Priority 1** (Tournament Detail Page parsing)?
Or would you prefer to tackle **PDF parsing** first?
