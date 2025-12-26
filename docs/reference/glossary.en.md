# Carambus Glossary

## Important Terms and Concepts

This glossary explains the most important terms in Carambus and how they relate to each other.

---

## 🏆 Tournaments (Individual Competitions)

### Tournament
A **Tournament** is an individual competition where players compete individually (not in teams).

**Properties:**
- Has a **Discipline** (Freie Partie, Dreiband, etc.)
- Has a **Mode** (K.O., Swiss System, Round Robin)
- Has a **Date** and a **Location**
- Is organized by a **Region** or a **Club**

### Seeding (Tournament Participation)
A **Seeding** is a player's participation in a tournament.

**Relationship:**
- A Tournament has many Seedings
- Each Seeding connects a Player with a Tournament
- Contains position, status, result

**Example:**
- Tournament: "Westfalen Open 2024"
- Seedings: Meyer (Position 1), Schmidt (Position 2), ...

---

## 🏅 Leagues (Team Competitions)

### League
A **League** is a team competition over a season.

**Properties:**
- Has multiple **LeagueTeams** (teams)
- Runs over a **Season**
- Has a **Discipline** (usually Dreiband or Freie Partie)
- Is organized by a **Region**

**Example:** "Bundesliga Nord 2024/2025"

### LeagueTeam (Team)
A **LeagueTeam** is a team within a league.

**Properties:**
- Belongs to a **League**
- Belongs to a **Club**
- Has multiple **Players** (via SeasonParticipations)

**Example:** "BC Hamburg 1" (BC Hamburg's team in Bundesliga Nord)

### Party (Match Day)
A **Party** is a **match day** where **two LeagueTeams** meet.

**Important to understand:**
- A Party is NOT a "celebration" but a **match day**!
- A match day = one meeting of exactly 2 teams
- Multiple **PartyGames** (individual games) are played during a match day

**Structure:**
```
League: Bundesliga Nord
  └── Party 1: BC Hamburg vs. BV Wedel (first leg, 10/15/2024)
  └── Party 2: BV Wedel vs. BC Hamburg (second leg, 03/20/2025)
```

**Typical flow:**
1. **First leg:** Each team plays once against every other (home or away)
2. **Second leg:** Same matches with switched home advantage

### PartyGame (Individual Game within a Match Day)
A **PartyGame** is an **individual game** between two players during a match day (Party).

**Important to understand:**
- A Party (match day) consists of **multiple PartyGames**
- Each PartyGame is one game: Player A vs. Player B
- The order is defined by the **Game Plan**
- Typical: 6-12 PartyGames per Party (match day)

**Hierarchy:**
```
League
  └── LeagueTeam (Team 1 and 2)
        └── Party (Match day between 2 teams)
              └── PartyGame 1: Player A1 vs. Player B1
              └── PartyGame 2: Player A2 vs. Player B2
              └── PartyGame 3: Player A1 vs. Player B3
              └── ... (more PartyGames)
```

**Concrete Example:**
```
League: Verbandsliga Hamburg 2024/2025
Home LeagueTeam: BC Hamburg
Away LeagueTeam: BV Wedel

Party (Match Day): BC Hamburg vs. BV Wedel
  Date: 10/15/2024
  Location: BC Hamburg Club House
  
  PartyGames:
    1. Müller (Hamburg) vs. Schmidt (Wedel) - 40:35
    2. Meyer (Hamburg) vs. Wagner (Wedel) - 30:40
    3. Müller (Hamburg) vs. Wagner (Wedel) - 40:28
    4. Meyer (Hamburg) vs. Schmidt (Wedel) - 35:40
    5. ... (more pairings)
  
  Final result: Hamburg 5:3 Wedel
```

### Game Plan
A **Game Plan** defines the pattern of games within a match day.

**Example:**
- Round 1: A1 vs. B1, A2 vs. B2, A3 vs. B3
- Round 2: A1 vs. B2, A2 vs. B3, A3 vs. B1
- etc.

---

## 👥 Players and Participations

### Player
A **Player** is a person who participates in tournaments or leagues.

**Properties:**
- Belongs to a **Region** (home association)
- Can be active at multiple **Clubs**
- Has **Rankings** in different disciplines

### SeasonParticipation
A **SeasonParticipation** connects a player with a club for a specific season.

**Why important:**
- Players can change clubs
- Per season, a player can be active at different clubs
- Used for league eligibility

**Example:**
- Player: Meyer
- Season: 2024/2025
- Club: BC Hamburg
→ SeasonParticipation: Meyer plays for BC Hamburg in 2024/2025

### GameParticipation
A **GameParticipation** is a player's participation in a single game.

**Difference from Seeding:**
- **Seeding:** Participation in a **Tournament** (entire competition)
- **GameParticipation:** Participation in a **Game** (single game)

---

## 🖥️ Server Architecture

### ClubCloud
**[ClubCloud](https://club-cloud.de/)** is a web-based management software for sports associations and clubs.

**Important:** ClubCloud is **NOT** Carambus!

**What is ClubCloud?**
- External management software for associations
- 14 of 17 German billard associations use it
- Each association has its own ClubCloud instance (e.g., ndbv.de, westfalenbillard.net)
- Manages: Players, Clubs, Tournaments, Leagues, Rankings

**Relationship to Carambus:**
- Carambus **scrapes** data from ClubCloud (daily at 4:00 AM)
- Carambus is **independent** and works without ClubCloud
- Results can be exported back to ClubCloud via CSV

**See:** [ClubCloud Integration](../managers/clubcloud-integration.en.md) for scraping process details

---

### API Server (Central Server)
The **API Server** is the central data source for all Carambus installations.

**Main tasks:**
- **Scraping:** Loads data from ClubCloud and other external sources
- **Central data storage:** Stores **all** data from **all** regions
- **Synchronization:** Distributes data to Local Servers (filtered by region)

**Example:** carambus.de

**Data source:** Scraping from ClubCloud instances (see [ClubCloud Integration](../managers/clubcloud-integration.en.md))

### Local Server (Regional/Club Server)
A **Local Server** is a Carambus installation for a specific location.

**Main tasks:**
- **Local game management:** Tournaments, scoreboards, match days
- **Regional data:** Only data from own region (filtered from API Server)
- **Offline capability:** Can work independently from API Server

**Advantages:**
- ✅ Offline-capable (important for match days!)
- ✅ Fast scoreboards (no internet needed)
- ✅ Smaller database (only own region)

**Example:** Raspberry Pi in BC Hamburg club house

### Local Data (Locally Created Data)
**Local Data** is data created on a Local Server (not from scraping).

**Simply put:** Everything the club creates and manages itself, without being recorded in the supra-regional ClubCloud.

**ID Ranges:**
- IDs **< 50,000,000:** Scraped from API Server (from ClubCloud)
- IDs **≥ 50,000,000:** Local Data (created locally at club)

**Practical examples:**
- 🏆 Club tournament (year-end tournament, not in ClubCloud)
- 🎯 Training games (Tuesday training for performance tracking)
- 👥 Guest players (visitors without club membership)
- 📅 Table reservation (with heating control)
- 🏅 Internal club championship (over multiple weeks)

**Why important:**
- ✅ Offline-capable (no internet needed)
- ✅ No ID conflicts
- ✅ Club has full control
- ✅ Statistics for training
- ✅ LocalProtector prevents accidental overwrites

**Example:**
```
Scraped tournament:  ID 12,345 (ClubCloud, official)
Club tournament:     ID 50,001,234 (club only)
Training game:       ID 50,100,567 (Tuesday training)
```

**See also:** [Server Architecture](../administrators/server-architecture.en.md)

---

## 📍 Locations and Organizations

### Region (State Association)
A **Region** is a billard state association in Germany.

**Examples:**
- NBV (Norddeutscher Billard Verband - Northern German Billard Association)
- BVW (Billard-Verband Westfalen - Westphalia Billard Association)
- BBV (Bayerischer Billardverband - Bavarian Billard Association)

**Don't confuse with cities!**
- Hamburg = City
- NBV = Association (covers Hamburg + Schleswig-Holstein + Bremen)

### Club
A **Club** is a billard club/association.

**Properties:**
- Belongs to a **Region**
- Has **Locations** (venues)
- Has **Players** via SeasonParticipations
- Can organize **Tournaments**
- Provides **LeagueTeams** for leagues

### Location (Venue)
A **Location** is a physical place where games are played.

**Properties:**
- Has **Tables** (billard tables)
- Can belong to a **Club**
- Can be managed by a **Region**
- Used for **Tournaments** and **Parties**

**Difference:**
- **Club:** Organization (BC Hamburg e.V.)
- **Location:** Physical place (club house, address, tables)

---

## 📅 Temporal Structures

### Season
A **Season** is a playing period, typically one year.

**Format:** `2024/2025` (from autumn to spring)

**Important:**
- Used for leagues
- Used for rankings
- SeasonParticipations are season-dependent

---

## 🎮 Disciplines and Modes

### Discipline
A **Discipline** is a type of billard game.

**Main disciplines:**
- **Freie Partie** (Carom without restrictions)
- **Dreiband** (Three-cushion - ball must touch 3 cushions)
- **Einband** (One-cushion - ball must touch 1 cushion)
- **Cadre** (Carom in limited area)
- **Pool** (Pocket billard)
- **Snooker**

### Discipline Phase
A **Discipline Phase** defines game rules within a discipline.

**Example for Freie Partie:**
- Phase 1: 40 points, 60 innings
- Phase 2: 50 points, 75 innings (for stronger players)

---

## 🔄 Common Confusions

### Party vs. PartyGame
❌ **Wrong:** "Party is a single game"  
✅ **Correct:** Party is the **entire match day** with multiple games

❌ **Wrong:** "PartyGame is the match day"  
✅ **Correct:** PartyGame is **one individual game** within the match day

**Remember:** 
- 1 Party = 1 match day = many PartyGames
- 1 PartyGame = 1 game = 2 players

### Seeding vs. GameParticipation
❌ **Wrong:** "Both are the same"  
✅ **Correct:** 
- **Seeding:** Participation in a **Tournament** (entire competition)
- **GameParticipation:** Participation in a **Game** (single game)

### Club vs. Location
❌ **Wrong:** "Club is the venue"  
✅ **Correct:**
- **Club:** Organization (BC Hamburg e.V.)
- **Location:** Physical place (club house with address + tables)

### Region vs. City
❌ **Wrong:** "Hamburg is a Region"  
✅ **Correct:**
- **Hamburg:** City
- **NBV:** Region/Association (Norddeutscher Billard Verband)
- NBV covers Hamburg, Schleswig-Holstein, Bremen

---

## 📊 Entity Relationship Overview

```
Season
  ├── Tournament
  │     └── Seeding (Tournament Participation)
  │           └── Player
  │
  └── League
        ├── LeagueTeam (Team)
        │     └── Player (via SeasonParticipation)
        │
        └── Party (Match Day)
              └── PartyGame (Individual Game)
                    ├── Player A
                    └── Player B

Region (Association)
  ├── Club
  │     ├── Location (Venue)
  │     │     └── Table
  │     └── Player (via SeasonParticipation)
  │
  ├── Tournament (organized by Region)
  └── League (organized by Region)
```

---

## 💡 Practical Examples

### "I want to know how many games Meyer played this season"

**Two types of games:**

1. **Tournament games (in individual tournaments):**
   - Via **Seeding** → **Tournament** → **Games**
   - Meyer's Seedings in Season 2024/2025

2. **League games (in team matches):**
   - Via **PartyGame** → **Party** → **League**
   - Meyer's PartyGames in Season 2024/2025

### "I want to organize a match day"

**Steps:**
1. Create **League** and **LeagueTeams** (if not existing)
2. Create **Party** (match day between 2 teams)
3. Set **Location** and **Tables**
4. Select **Game Plan** (game pattern)
5. Select **Players** from teams
6. Generate **PartyGames**
7. Start **Scoreboards**

---

## 📚 See Also

- [Tournament Management](../managers/tournament-management.en.md) - Individual tournaments
- [League Match Days](../managers/league-management.en.md) - Team competitions
- [Database Design](../developers/database-design.en.md) - ER Diagram
- [Filter & Search](../search.en.md) - Finding data

---

**Version:** 1.0  
**Last Update:** October 2024

