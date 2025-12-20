# Carambus Server Architecture

## Overview

Carambus uses a **distributed architecture** with a central **API Server** and multiple **Local Servers**. This design enables efficient data management and optimal performance for local venues.

---

## 🌐 Two Server Types

### API Server (Central Server)

The **API Server** is the central data source for all Carambus installations.

**Tasks:**
1. **Scraping External Data**
   - Loads data from ClubCloud (regional associations)
   - Loads data from billardarea.de (historical)
   - Imports tournament data, players, clubs, etc.
   - Updates rankings and results

2. **Central Data Storage**
   - Stores **all** data from **all** regions
   - Complete database with all associations
   - Master data source for synchronization

3. **Data Synchronization**
   - Distributes data to Local Servers
   - Filters data by region (see below)
   - Provides APIs for data queries

**Hosting:**
- Typically on dedicated server (VPS/Cloud)
- Runs 24/7
- High bandwidth for scraping
- Large database (all regions)

**Example:** carambus.de (API Server for all of Germany)

---

### Local Server (Regional/Club Server)

A **Local Server** is a Carambus installation for a specific location (club, venue, region).

**Tasks:**
1. **Local Game Management**
   - Manages tournaments at location
   - Controls scoreboards in real-time
   - Local data capture

2. **Regional Data Storage**
   - Stores only data from **own region** (filtered!)
   - Plus: Globally relevant data (DBU tournaments, etc.)
   - Plus: Own Local Data (see below)

3. **Offline Capability**
   - Can work independently from API Server
   - Important for match days (no internet dependency)
   - Synchronizes later with API Server

**Hosting:**
- Typically Raspberry Pi in club house
- Or server at state association
- Runs on local network
- Smaller database (only own region)

**Examples:** 
- BC Hamburg Local Server (only Hamburg data + DBU tournaments)
- BV Westfalen Local Server (only Westphalia data + DBU tournaments)

---

## 🔄 Data Flow

### 1. Scraping (API Server)

```
ClubCloud (NBV) → API Server → scraping → Database (all regions)
ClubCloud (BVW) → API Server → scraping → Database (all regions)
...
```

### 2. Synchronization (API → Local)

```
API Server (all data)
    ↓ Filter: region_id = Hamburg
Local Server Hamburg (only Hamburg data + Global)
    ↓ 
Scoreboards, Tournaments, etc.
```

### 3. Local Data Upload (Local → API)

```
Local Server Hamburg
    ↓ creates Tournament (Local Data, ID > 50,000,000)
    ↓ Upload to API Server
API Server (stores Local Data)
    ↓ Synchronization
Other Local Servers (receive Hamburg's Local Data)
```

---

## 🔢 Local Data - Special ID Range

### What is Local Data?

**Local Data** is data created on a **Local Server** that doesn't come from scraping by the API Server.

**Simply put:** Everything the club **creates and manages itself**, without being recorded in the supra-regional ClubCloud.

### ID Ranges

```
IDs:           1 - 49,999,999    → From API Server (scraped from ClubCloud)
IDs: 50,000,000 - 99,999,999    → Local Data (created locally at club)
```

**Why important?**
- ✅ Local Server can work **offline**
- ✅ No ID conflicts between servers
- ✅ Clear distinction: External vs. Internal
- ✅ Club has full control over own data

---

### 💡 Practical Examples for Local Data

#### 1. Club Tournament without ClubCloud Registration

**Scenario:** BC Hamburg organizes an internal year-end club tournament.

```
Problem:
- Tournament only takes place at club
- Should NOT be registered in ClubCloud (internal)
- Still needs Carambus for scoreboards and management

Solution with Local Data:
- Create tournament locally → ID: 50,012,345
- Full Carambus functionality
- Scoreboards, seeding, results
- Stays local, not in ClubCloud
```

#### 2. Training Games for Performance Tracking

**Scenario:** Players want to track their development, but not enter every training session in ClubCloud.

```
Example BC Hamburg:
- Every Tuesday: Training with 8 players
- Capture via scoreboards
- Statistics: GD development, high series, etc.
- Local ranking for the club

Local Data:
- Training Games: IDs 50,100,001, 50,100,002, ...
- Only visible in club
- Long-term statistics possible
- Motivates players (measurable improvement!)
```

#### 3. Guest Players at Club

**Scenario:** A player from another club visits regularly and participates in training.

```
Problem:
- Player is not a club member
- Not listed in ClubCloud as BC Hamburg player
- Should still be able to play on scoreboards

Solution:
- Create guest player locally → ID: 50,200,123
- Can participate in local games
- Does NOT appear in official lists
- Is NOT synchronized to API Server
```

#### 4. Table Reservation with Heating Control

**Scenario:** The club has an automatic reservation system for billard tables with heating control.

```
Local Data Tables:
- Reservations: IDs 50,300,001, 50,300,002, ...
- Table occupancy
- Heating schedules
- Internal club management

Why local?
- Not relevant for other clubs
- No ClubCloud integration needed
- Faster access (local)
- Privacy (only club members)
```

#### 5. Internal Club Championship over Multiple Weeks

**Scenario:** The club organizes a multi-week internal championship.

```
Setup:
- League (local): "BC Hamburg Winter Championship"
  ID: 50,400,001
- LeagueTeams (local): "The Veterans", "The Young Guns", etc.
  IDs: 50,400,010, 50,400,011, ...
- Parties (Match days): Every Friday
  IDs: 50,400,100, 50,400,101, ...
- PartyGames: Hundreds of games
  IDs: 50,400,500+

Advantage:
- Complete league management in club
- Not in official ClubCloud
- Own rules and modes possible
- Long-term statistics stored locally
```

---

### 🔄 What Happens with Local Data?

#### Created Locally (Local Server):
```
BC Hamburg Local Server
  ↓ Create tournament
  ID: 50,012,345 (Local Data)
  cc_id: NULL (not in ClubCloud)
```

#### Optional: Upload to API Server
```
Local Server
  ↓ rake sync:to_api (if desired)
API Server
  ↓ stores with same ID
  ID: 50,012,345 is preserved!
```

#### Synchronization to Other Local Servers
```
API Server (now has BC Hamburg Local Data)
  ↓ Synchronization (regionally filtered!)
Other NBV servers receive it
  ↓
BV Wedel Local Server sees:
  "BC Hamburg Club Tournament" (read-only)
```

**Important:**
- Local Data remains **protected** (LocalProtector)
- Only the **creating server** can edit
- Other servers: **read-only**
- No accidental overwrites

---

### 🎯 When to Use Local Data?

**Use Local Data for:**
- ✅ Internal club tournaments
- ✅ Training games and statistics
- ✅ Guest players without club membership
- ✅ Reservation systems
- ✅ Internal leagues/championships
- ✅ Everything that should NOT be in ClubCloud

**Use scraped data for:**
- ✅ Official association tournaments
- ✅ Bundesliga match days
- ✅ Ranking tournaments
- ✅ Regional championships
- ✅ Everything that's in ClubCloud

---

## 📊 Comparison: API vs Local Server

| Aspect | API Server | Local Server |
|--------|-----------|--------------|
| **Data Scope** | All regions | Only own region + Global |
| **Database Size** | Large (~GB) | Small (~MB) |
| **Scraping** | Yes, active | No, only receives |
| **Internet Required** | Yes, always | No, offline-capable |
| **Scoreboards** | Rare | Yes, permanent |
| **Hosting** | VPS/Cloud | Raspberry Pi, local |
| **Quantity** | 1 central | Many (per club/region) |
| **Main Purpose** | Collect & distribute data | Run match days |

---

## 🏗️ Typical Setups

### Setup 1: Single Club

```
API Server (carambus.de)
    ↓ Synchronization (filtered)
Local Server (BC Hamburg, Raspberry Pi)
    ↓ LAN
Scoreboards (3 tables in club house)
```

### Setup 2: State Association

```
API Server (carambus.de)
    ↓ Synchronization (NBV data)
Local Server State Association (NBV server)
    ↓ Internet
    ├─ Local Server BC Hamburg (Raspberry Pi)
    ├─ Local Server BV Wedel (Raspberry Pi)
    └─ Local Server SC Pinneberg (Raspberry Pi)
```

### Setup 3: API Server Only (Development/Testing)

```
API Server (localhost:3000)
    ↓ direct
Browser (Developer, no scoreboards needed)
```

---

## 🔐 Security and Isolation

### Data Isolation

**Advantage of regional filtering:**
- Hamburg sees **no** internal Westphalia data
- Smaller database = faster queries
- GDPR compliant (only relevant data)

**Globally visible:**
- DBU tournaments (nationwide)
- Rankings
- Public events

**Not global:**
- Internal club tournaments
- Training parties
- Local player details

---

## 💡 Why This Architecture?

### Problems without distributed system:
❌ Every club needs constant internet connection  
❌ Central overload during many match days  
❌ Single Point of Failure  
❌ Slow scoreboards (remote access)

### Solution with API + Local Servers:
✅ Local Servers work offline  
✅ Scoreboards are lightning-fast (LAN)  
✅ Fail-safe (decentralized)  
✅ Scalable (many Local Servers possible)  
✅ Regional data stays regional  

---

## 🔧 Technical Details

### Regional Filtering

```ruby
# API Server has everything:
Tournament.count # => 5000 (all regions)

# Local Server Hamburg only has:
Tournament.where(region_id: nbv_id)
          .or(Tournament.where(global_context: true))
          .count # => 500 (only Hamburg + Global)
```

### Synchronization

**From API → Local:**
```ruby
# Rake task on Local Server:
rake sync:from_api[region_id]

# Loads:
# - All data with region_id = Hamburg
# - All data with global_context = true
# - All data with region_id = NULL
```

**From Local → API:**
```ruby
# Rake task on Local Server:
rake sync:to_api[local_data]

# Uploads:
# - All data with ID >= 50,000,000 (Local Data)
# - Newly created tournaments, players, etc.
```

---

## 📚 See Also

- [Database Partitioning](datenbank-partitionierung-und-synchronisierung.de.md) - Technical details
- [Scenario Management](scenario_management.en.md) - Development with multiple scenarios
- [Installation](installation_overview.en.md) - Setting up servers
- [Raspberry Pi Setup](quickstart_raspberry_pi.en.md) - Local Server on Raspberry Pi

---

## ❓ Frequently Asked Questions

**Q: Can a club operate without an API Server?**  
A: Yes! Local Server is fully functional without API Server. However, scraped data from ClubCloud will be missing.

**Q: Does every club need a Local Server?**  
A: No. Clubs can also use the API Server directly (via browser). Local Server is only needed for scoreboards and offline operation.

**Q: What happens with ID conflicts?**  
A: No conflicts possible:
- API Server: IDs < 50,000,000
- Local Server: IDs >= 50,000,000
- Different ID ranges guarantee uniqueness

**Q: Can a Local Server have data for multiple regions?**  
A: Yes! A Local Server can filter multiple regions. Configurable via `region_ids` array.

---

**Version:** 1.0  
**Last Update:** October 2024  
**Status:** Production in Use

