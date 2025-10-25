---
---
title: League Match Day Management
summary: The handling of league matches runs fundamentally different compared to individual tournaments and is therefore specially supported. The structure of league matches is predetermined for the individual leagues and does not change during a season.
version:
published_at: !ruby/object:ActiveSupport::TimeWithZone
  utc: 2025-03-05 14:34:15.052622000 Z
  zone: !ruby/object:ActiveSupport::TimeZone
    name: Europe/Berlin
  time: 2025-03-05 15:34:15.052622000 Z
tags: []
metadata: {}
position: 1
id: 2
---

# League Match Day Management

### Important Terms and Concepts

#### League
A **League** is a team competition over a season with multiple teams.

#### LeagueTeam (Team)
A **LeagueTeam** is a team within a league. Each team consists of multiple players.

#### Party (Match Day)
A **Party** (match day) is a meeting between **two LeagueTeams** at a specific date and location.

**Important:** In a league, there is typically:
- **First leg:** Each team plays once against every other (home or away)
- **Second leg:** The same matches with switched home advantage

Example: Team A vs. Team B
- First leg: Party 1 (at Team A)
- Second leg: Party 2 (at Team B)

#### PartyGame (Individual Game within a Match Day)
A **PartyGame** is an individual game between two players during a match day (Party).

On a match day, **multiple PartyGames** are played according to a predefined pattern:
- Each player from Team A plays against multiple players from Team B
- The number and order is defined by the **Game Plan**
- Typical: 6-12 individual games per match day

**Summary:**
```
League
  └── LeagueTeam (Teams)
        └── Party (Match day between 2 teams)
              └── PartyGame (Individual games within match day)
                    └── Player A vs. Player B
```

**Example:** Bundesliga Nord, 1st Match Day
- **League:** Bundesliga Nord
- **LeagueTeam:** BC Hamburg, BV Wedel
- **Party:** BC Hamburg vs. BV Wedel (Match day on 10/15/2024)
- **PartyGames:** 
  - Game 1: Player Müller (Hamburg) vs. Schmidt (Wedel)
  - Game 2: Player Meyer (Hamburg) vs. Wagner (Wedel)
  - ... (total of e.g. 8 games)

### Overview

The handling of league matches runs fundamentally different compared to individual tournaments and is therefore specially supported. The structure of league matches is predetermined for the individual leagues and does not change during a season.

The following phases are generally completed:

* Planning of match days and teams
* At the beginning of a match day, determination of players by the captains
* Per round, assignment of game tables to individual games
* Assignment of players to individual games per round
* Start of rounds and transfer of data to scoreboards
* Operation of scoreboards
* Handover of results to the Matchday Monitor and possibly to overview boards
* Automatic completion of a round, start of another round and possibly start of a shootout in case of a tie
* Transfer of results to the ClubCloud

### Planning of Match Days and Teams

The structure of match days for a league is determined at the beginning of the season at DBU or state level and formally entered in the ClubCloud. The scheduling of individual match days is also managed in the ClubCloud. Furthermore, the players eligible to play in the individual teams are determined.

This data forms the basis for Carambus Matchday Management. The game director finds this data most easily through the game location, where all matches are listed.

After opening the match day view, there is a link to the Matchday Monitor. In this view, the entire match day process is controlled.

### Determination of Players for a Match Day

Carambus offers the players of the respective team from the entries in the ClubCloud for selection, plus players from subordinate leagues. After selection, the number of players available for the match day is unchangeably fixed.

### Assignment of Tables

In Carambus, the tables available in a game location can be defined with name and type (Carom large, medium, small, Pool, Snooker). Round by round, tables must be assigned to individual games from this set.

### Assignment of Players to Games

After assigning the tables, the individual game pairings must now be filled. Only when all games of a round are occupied can the round be started.

### Transfer of Data to Scoreboards

With the start of the round, the individual game pairings appear on the scoreboards. After completion of a match, the results remain until the next pairing is called.

### Operation of Scoreboards

The operation of scoreboards is done via touch input. Inputs can be undone at any time via Undo. This also applies after the end of the game, as long as the game has not been finally completed by the game director.

### Control at the Matchday Monitor

The entire monitoring of the match day can be done at the Matchday Monitor. The results are updated live in the monitor view. At the end, the result of the individual pairings must be confirmed.

### Automatic Round Completion and Start

When all games of a round are confirmed, it automatically proceeds to the next round, or possibly to a shootout. The intermediate results and final result can be viewed at any scoreboard if needed (Start -> Tournaments -> Tournament).

### Upload to ClubCloud

For upload to the ClubCloud, the form is offered, exactly as in the admin area of the ClubCloud. For this to work, a login to the ClubCloud with the same browser is necessary. 