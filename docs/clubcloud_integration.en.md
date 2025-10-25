# ClubCloud Integration and Scraping

## What is ClubCloud?

**[ClubCloud](https://club-cloud.de/)** is a web-based management software for sports associations and clubs in Germany.

**Operator:** ClubCloud GmbH  
**Website:** https://club-cloud.de/

### Main Functions of ClubCloud:
- Member management
- Tournament planning and management
- League management (match days, teams)
- Registration system (tournament registrations, transfers)
- Result recording
- Rankings
- Website CMS for associations/clubs

---

## 🌐 Regional ClubCloud Instances

**Important:** There is **NO central** ClubCloud for all of Germany!

Instead, each billard association operates its **own ClubCloud instance**:

### Associations WITH ClubCloud (14 of 17):

| Association | Name | ClubCloud URL |
|------------|------|---------------|
| **DBU** | Deutsche Billard-Union | [billard-union.net](https://billard-union.net/) |
| **BBBV** | Brandenburgischer Billardverband | [billard-brandenburg.net](https://billard-brandenburg.net/) |
| **BLMR** | Billard LV Mittleres Rheinland | [blmr.club-cloud.de](https://blmr.club-cloud.de/) |
| **BLVN** | Billard LV Niedersachsen | [billard-niedersachsen.de](https://billard-niedersachsen.de/) |
| **BVB** | Billard-Verband Berlin | [billardverband-berlin.net](https://billardverband-berlin.net/) |
| **BVBW** | Billard-Verband Baden-Württemberg | [billard-bvbw.de](https://billard-bvbw.de/) |
| **BVNR** | Billard-Verband Niederrhein | [billard-niederrhein.de](https://billard-niederrhein.de/) |
| **BVNRW** | Billard-Verband Nordrhein-Westfalen | [bvnrw.net](https://bvnrw.net/) |
| **BVRP** | Billard Verband Rheinland-Pfalz | [billardverband-rlp.de](https://billardverband-rlp.de/) |
| **BVS** | Billard-Verband-Saar | [billard-ergebnisse.de](https://billard-ergebnisse.de/) |
| **BVW** | Billard-Verband Westfalen | [westfalenbillard.net](https://westfalenbillard.net/) |
| **NBV** | Norddeutscher Billard Verband | [ndbv.de](https://ndbv.de/) |
| **SBV** | Sächsischer Billardverband | [billard-sachsen.de](https://billard-sachsen.de/) |
| **TBV** | Thüringer Billard Verband | [billard-thueringen.de](https://billard-thueringen.de/) |

### Associations WITHOUT ClubCloud (3 of 17):

| Association | Name | Alternative Solution |
|------------|------|---------------------|
| **BBV** | Bayerischer Billardverband | [billardbayern.de](https://billardbayern.de/) (own system) |
| **HBU** | Hessische Billard Union | (status unclear) |
| **BLVSA** | Billard LV Sachsen-Anhalt | [blv-sa.de](https://www.blv-sa.de/) (own system) |

**Problems with this federal structure:**
- ❌ No central control
- ❌ Data integrity only guaranteed regionally
- ❌ Different data quality per region
- ❌ Duplicates possible at inter-regional events (different local names)
- ❌ Inconsistent spelling (players, clubs, locations)

**Advantages:**
- ✅ Regional autonomy
- ✅ Adaptation to local needs
- ✅ Independence of associations

---

## 🔄 How Carambus Synchronizes with ClubCloud

### Scraping Concept

**Important to understand:** Carambus is **NOT** part of ClubCloud!

Carambus is an **independent, standalone application** that **reads** (scrapes/extracts) data from ClubCloud instances.

```
ClubCloud Instances (14 regional servers)
  ndbv.de (NBV)
  billardverband-rlp.de (BVRP)
  westfalenbillard.net (BVW)
  billard-bvbw.de (BVBW)
  ... (10 more)
        ↓ Scraping (automatic + manual)
Carambus API Server (central data collection)
        ↓ Synchronization (regionally filtered)
Carambus Local Servers (Clubs, Raspberry Pi)
        ↓ Local usage
Scoreboards, Tournament management, etc.
```

### What is Scraped?

**Almost everything** from ClubCloud instances:

- ✅ **Players** (name, DBU-ID, club, contact)
- ✅ **Clubs** (name, DBU-ID, region, address, contact)
- ✅ **Tournaments** (title, date, location, discipline, organizer)
- ✅ **Leagues** (name, teams, schedule, season)
- ✅ **Match days** (Parties) with dates
- ✅ **Results** (tournament and league results)
- ✅ **Rankings** (regional and nationwide)
- ✅ **Seeding lists** (tournament participants with positions)
- ✅ **Game Plans** (game patterns for leagues)
- ✅ **LeagueTeams** (teams with players)

**Special note:** Each region has its own **TournamentPlans** (tournament modes).
These are the basis for automated tournament and table management (TournamentMonitor, TableMonitor).

### How Often is Data Scraped?

**Automatically:**
- 🕐 **Daily at 4:00 AM** (night job)
- Updates all regions
- Runs on API Server

**Manually:**
- 🎯 **Before tournaments** - Update seeding lists
- 🔄 **Before match days** - Current team lineups
- 🛠️ **As needed** - Admin can trigger scraping via UI

**Workflow:**
```ruby
# Automatic (Cron job):
rake regions:scrape_all  # All regions at 4:00 AM

# Manual (via UI):
Region.find_by(shortname: 'NBV').reload_from_cc
Tournament.find(123).reload_from_cc  # Only one tournament
League.find(456).reload_from_cc_with_details  # League with details
```

---

## 🆔 Global IDs and DBU Data

The **[Deutsche Billard-Union (DBU)](https://billard-union.net/)** is the umbrella association and manages:

**1. Global IDs (Master Identifiers)**
- **Player IDs (DBU-Nr):** Unique across Germany
- **Club IDs (DBU-Nr):** Unique across Germany

**2. Nationwide Data**
- **Bundesliga** and other DBU tournaments
- **German Championships**
- **Nationwide rankings**
- **Squad data**

**Important:** DBU data is **scraped just like** regional data!
```
DBU (billard-union.net)
        ↓ Scraping
Carambus API Server
```

**Advantages of DBU-IDs:**
- ✅ A player has the same ID nationwide
- ✅ Prevents fundamental duplicates
- ✅ Enables inter-regional evaluations
- ✅ Unique assignment when changing clubs

**In Carambus:**
```ruby
# Find player by DBU-ID
Player.find_by(dbu_nr: 12345)

# Find club by DBU-ID
Club.find_by(dbu_nr: 67890)
```

---

## 🔧 Technical Details

### Scraping Implementation

**Carambus scrapes publicly accessible web pages** - no API integration!

**Technology:**
- Nokogiri (Ruby HTML/XML Parser)
- HTTP requests to ClubCloud pages
- Extraction from HTML structure
- Parsing of tables, lists, detail pages

**Advantages:**
- ✅ No ClubCloud changes needed
- ✅ Works with public data
- ✅ Independent of ClubCloud APIs

**Disadvantages:**
- ⚠️ Vulnerable to HTML structure changes
- ⚠️ Parsing logic must be adjusted for ClubCloud updates

### Authentication

**For Scraping (Reading):**
- ✅ **No authentication needed!**
- Carambus only scrapes **publicly accessible** web pages
- Same data any visitor sees

**For CSV Upload (Writing):**
- 🔐 **Authentication required**
- Login with admin credentials
- Upload via ClubCloud interface
- Manual approval in ClubCloud needed

### Data Integrity Problems and Solutions

#### Problem 1: Duplicates at Inter-Regional Events

**Scenario:** DBU tournament with participants from different regions

```
ClubCloud NBV: "Player Meyer, BC Hamburg"
ClubCloud BVRP: "Player Meier, BC Hamburg"  ← Typo!
ClubCloud BVW: "Player H. Meyer, Hamburg"   ← Abbreviation!

Problem: 3 different entries for the same player!
```

**Carambus Solution:**

**1. Duplicate Detection with Synonyms**
```ruby
# Club model stores synonyms:
club.synonyms = "BC Hamburg, Billard Club Hamburg, BCH"

# During scraping: Synonym matching
# "BC Hamburg" = "Billard Club Hamburg" = same club
```

**2. Manual Merge Functions**
- Index lists have **Merge buttons**
- Admin can merge duplicates
- Player.merge(player1, player2)
- Club.merge(club1, club2)
- Tournament.merge(tournament1, tournament2)

**3. DBU-ID as Master**
```ruby
# In case of conflict: DBU-ID takes precedence
if player1.dbu_nr == player2.dbu_nr
  # Same player → Merge!
end
```

#### Problem 2: Inconsistent Spelling

**Examples:**
- "BC Hamburg" vs. "Billard Club Hamburg"
- "Meyer, Hans" vs. "Hans Meyer"
- "Hamburg" vs. "HH" vs. "Hamburg (City)"

**Carambus Solution:**
- Synonym system (see above)
- Normalization during import
- Manual corrections by admins

#### Problem 3: Erroneous Data in Regional ClubCloud

**Example:** NBV enters wrong tournament date

**Carambus Solution:**
- Local overrides possible (LocalProtector)
- Admin can correct data locally
- Scraping does **NOT** overwrite protected Local Data

---

## 🔄 Synchronization Back to ClubCloud

**Current state:** Only via **CSV upload** possible

### Uploading Results (Manual)

```
1. Run tournament in Carambus
2. Results captured in Carambus (via scoreboards)
3. Export as CSV file
4. Login to ClubCloud (with admin credentials)
5. CSV upload via ClubCloud interface
6. Manual approval/review in ClubCloud
```

**Why CSV and not API?**
- ClubCloud doesn't (yet) offer upload API
- CSV is universally supported
- Manual control by admin desired

**Future possibilities:**
- Direct API integration (when ClubCloud provides it)
- Automatic upload after tournament end
- Real-time synchronization during match day

---

## 💡 Practical Application

### Scenario 1: New Tournament in ClubCloud

```
1. Association enters tournament in ClubCloud (e.g., ndbv.de)
   - "Hamburg Championship 2024"
   - Date: 11/15/2024
   - Location: BC Hamburg
   
2. Carambus scrapes automatically (at night, 4:00 AM)
   - Tournament imported to Carambus DB
   - ID < 50,000,000 (scraped)
   - cc_id references ClubCloud entry

3. Tournament appears in Carambus
   - Under "Tournaments" → Region NBV
   - With all details from ClubCloud
   - Seeding list can be updated (manual scraping)

4. Tournament execution with Carambus
   - TournamentMonitor controls process
   - TableMonitor + Scoreboards capture results
   - Everything stored in Carambus

5. Results back to ClubCloud
   - CSV export from Carambus
   - Upload to ClubCloud (manual)
   - Publication for all associations
```

### Scenario 2: Preparing a Match Day

```
1. League match day upcoming (e.g., BC Hamburg vs. BV Wedel)
   - Party already registered in ClubCloud
   - Teams and schedule available

2. Manual scraping before match day
   - Admin clicks "Reload from CC" in Carambus
   - Current team lineups are loaded
   - Ensures newest players are available

3. Execute match day
   - Carambus Party Monitor controls process
   - Scoreboards capture games live
   - No ClubCloud connection needed (offline!)

4. Upload results
   - After match day: CSV export
   - Upload to ClubCloud
   - Update league table
```

### Scenario 3: Duplicate Handling

```
Problem:
- DBU tournament "German Championship"
- Player "Meyer" from Hamburg listed in NBV as "Hans Meyer"
- Same player in BVRP listed as "H. Meyer"
- Carambus scrapes both → 2 entries!

Solution in Carambus:
1. Duplicate detection (same DBU-ID)
2. Admin uses merge function in Carambus
3. Player.merge(player_nbv, player_bvrp)
4. Synonyms are stored
5. Future scrapes recognize both names as same player
```

---

## ❓ Frequently Asked Questions

**Q: Why doesn't Carambus use ClubCloud directly?**  
A: ClubCloud is optimized for association administration, not for real-time scoreboards and local offline usage. Carambus offers:
- Offline capability for match days
- Fast scoreboards (local LAN)
- Own features (TournamentMonitor, TableMonitor)
- Local Data for internal club tournaments/training

**Q: Can I use Carambus without ClubCloud?**  
A: Yes! With **Local Data** (ID >= 50,000,000) you can work completely independently. Scraping is optional.

**Q: What happens when ClubCloud changes its HTML structure?**  
A: Scraping breaks or delivers faulty data. Carambus developers must then adapt the parsing logic. Regular updates important!

**Q: Can Carambus work with multiple regions simultaneously?**  
A: Yes! The API Server scrapes all 14+ ClubCloud instances. A Local Server can access data from multiple regions (configurable).

**Q: How often should I manually scrape?**  
A: 
- Before **tournaments:** Update seeding lists
- Before **match days:** Check team lineups
- After **changes:** When ClubCloud data was corrected

**Q: Are deleted data in ClubCloud also deleted in Carambus?**  
A: No. Carambus only marks them as "no longer in ClubCloud". Historical data is preserved (important for statistics).

---

## 🚀 Summary

**Carambus-ClubCloud Integration:**

✅ **Scraping** from 14 regional ClubCloud instances  
✅ **Automatic** daily at 4:00 AM  
✅ **Manual** before tournaments/match days  
✅ **No authentication** for reading (public data)  
✅ **CSV upload** for results back to ClubCloud  
✅ **DBU-IDs** as global master identifiers  
✅ **Duplicate handling** with synonyms and merge  
✅ **Offline-capable** through local data storage  

**Most important insight:**
Carambus is **independent** of ClubCloud and works completely **without** it. Scraping is an **optional service** for data integration, not a technical must!

---

## 📚 See Also

- [Server Architecture](server_architektur.en.md) - API vs Local Server
- [Glossary](glossar.en.md) - All terms explained
- [Database Synchronization](datenbank-partitionierung-und-synchronisierung.de.md) - Technical details
- [Region Tagging](region_tagging_cleanup_summary.en.md) - Regional filtering
- [Tournament Duplicate Handling](tournament_duplicate_handling.de.md) - Duplicate management

---

**Version:** 1.0  
**Last Update:** October 2024  
**Status:** Complete

