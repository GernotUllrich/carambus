# Tournament Manager Documentation

Welcome to the Carambus documentation for tournament managers! Here you'll find the information for running billiards tournaments and league match days with Carambus.

## 🎯 Your Role as Tournament Manager

As a tournament manager, you are responsible for:
- ✅ **Tournament preparation**: Load the tournament from ClubCloud, apply the seeding list, review and close the participant list
- ✅ **Tournament mode**: Choose the matching tournament plan; the pairings follow from it
- ✅ **Tournament execution**: Assign tables, start the tournament, watch the Tournament Monitor
- ✅ **Result control**: Players enter and correct results at the scoreboard; you step in when problems arise
- ✅ **Completion**: Final ranking in the Tournament Monitor, upload results to ClubCloud

## 🚀 Quick Start: Sync and Run a Tournament in 10 Steps

1. **Sync tournament from ClubCloud** → [Step 2](tournament-management.md#step-2-load-clubcloud)
2. **Apply the seeding list** → [Step 3](tournament-management.md#step-3-seeding-list)
3. **Review and add participants** → [Step 4](tournament-management.md#step-4-participants)
4. **Close the participant list** → [Step 5](tournament-management.md#step-5-finish-seeding)
5. **Select tournament mode** → [Step 6](tournament-management.md#step-6-mode-selection)
6. **Fill in start parameters** → [Step 7](tournament-management.md#step-7-start-form)
7. **Assign tables and start the tournament** → [Steps 8–9](tournament-management.md#step-8-tables)
8. **Warmup and match release** → [Steps 10–11](tournament-management.md#step-10-warmup)
9. **Monitor and finalize results** → [Steps 12–13](tournament-management.md#step-12-monitor)
10. **Upload results to ClubCloud** → [Step 14](tournament-management.md#step-14-upload)

➡️ **[Full walkthrough](tournament-management.md#walkthrough)**

## 📚 Main Topics

### 1. Tournament Management

**Organize individual tournaments**:
- Tournament plans from the carom tournament regulations (T plans) and the dynamic round-robin plan `Default{n}`
- Group phases, knockout rounds and placement matches, as the chosen plan provides
- Seeding list from the invitation or from the ranking
- Shoot-out for drawn knockout matches

➡️ **[Tournament Management Manual](tournament-management.md)**  
➡️ **[Single Tournament Management](single-tournament.md)**  
➡️ **[Quick Reference](tournament-quick-reference.md)**

### 2. League Match Days

**Conduct team competitions**:
- Leagues, teams and match days come from ClubCloud (TBV from LigaManager, BBV from NuLiga)
- Run match days in the Party Monitor
- Standings on the league page

➡️ **[League Management Manual](league-management.md)**

### 3. Player Management

**Manage participants**:
- Players are scraped from ClubCloud
- Review and complete the participant list, including late registrations on tournament day
- Merge player duplicates (on the Authority)

➡️ **[Review and add participants](tournament-management.md#step-4-participants)**  
➡️ **[Late registration on tournament day](tournament-management.md#appendix-nachmeldung)**  
➡️ **[Duplicates](clubcloud-integration.md)**

### 4. Result Entry & Control

**Manage results**:
- Players enter results at the scoreboard
- Corrections before confirmation in the protocol editor at the scoreboard (e.g. a forgotten follow-up shot)
- If a scoreboard fails: enter results from paper protocols in the Tournament Monitor
- After the start: "Restart tournament" instead of reset

➡️ **[Monitor and intervene if needed](tournament-management.md#step-12-monitor)**  
➡️ **[Tournament already started — and something goes wrong](tournament-management.md#ts-already-started)**

### 5. Admin Roles & Permissions

**Roles and rights**:
- Roles in Carambus: player, club admin, system admin
- Sportwart and Landessportwart persona as well as tournament direction for write actions in ClubCloud; the persona is set by a system admin

➡️ **[Admin Roles Manual](admin-roles.md)**  
➡️ **[ClubCloud role model](clubcloud-scenarios/cc-roles.md)**

### 6. ClubCloud Integration

**Connect DBU ClubCloud**:
- Take over tournaments, players, clubs and leagues from ClubCloud
- Close the participant list in ClubCloud (with your own CC access)
- Upload results (automatically per game or via CSV)

➡️ **[ClubCloud Integration Guide](clubcloud-integration.md)**  
➡️ **[Your own ClubCloud access](clubcloud-eigener-zugang.md)**

### 7. Search & Filter

**Find data efficiently**:
- Filter popup in the lists, with input fields matching the field type
- AI-powered search

➡️ **[Filter Popup Guide](filter_popup_usage.md)**  
➡️ **[AI Search](../players/ai-search.md)**

### 8. Table Reservation

**Manage club times**:
- Reservations in the club's Google Calendar
- Automatic table reservation for tournaments after the registration deadline
- Pre-heating the tables before the reservation starts

➡️ **[Automatic table reservation](automatische_tischreservierung.md)**  
➡️ **[Table Reservation & Heating Control](table_reservation_heating_control.md)**

## 🎮 Tournament Modes

### Tournament Plans

The **tournament plan** determines how a tournament runs. In step 6 Carambus offers the plans that match the number of participants: the T plans of the carom tournament regulations with a fixed match structure and number of tables, and the dynamically generated round-robin plan `Default{n}`. The plan named in the invitation is usually binding.

➡️ **[Select tournament mode](tournament-management.md#step-6-mode-selection)**

### Groups, Knockout and Placement Matches

Depending on the plan, a group phase (round robin) is followed by a knockout round or by placement matches. The group ranking follows the tournament regulations (§4.4.2: points, general average, head-to-head, best single average, highest run). A drawn knockout match is decided by a shoot-out.

➡️ **[Finalize the tournament](tournament-management.md#step-13-finalize)**

## 🛠️ Important Functions

### Automatic Match Assignment

**Features**:
- The pairings of each round follow from the tournament plan
- Rounds off (bye) also follow from the plan
- Optional: "Assign games as soon as tables become free"

**Table assignment**:
- Before the start you map the plan's tables to the tables in your venue
- After the start this mapping is fixed; a scoreboard can still be switched to another table

➡️ **[Table assignment](tournament-management.md#step-8-tables)**

### Tournament Monitor

**Real-time tournament monitoring**:
- Games of the current round with balls, innings, highest run and general average
- Open table scoreboards in separate browser tabs
- Round change is automatic as soon as the last game of the round is confirmed

**Display options**:
- Tournament Monitor (individual tournaments)
- Party Monitor (league match days)
- Scoreboard (per table)

➡️ **[Monitor and intervene if needed](tournament-management.md#step-12-monitor)**

### Result Correction

**How to correct?**:
- Before confirmation in the protocol editor at the scoreboard

Carambus keeps no change history for game results.

➡️ **[Follow-up shot forgotten at the scoreboard](tournament-management.md#ts-nachstoss-forgotten)**

### Evaluations

**Available**:
- Final ranking in the Tournament Monitor
- Game protocol of a match as PDF
- Result CSV for the ClubCloud upload
- Standings on the league page

➡️ **[Finalize the tournament](tournament-management.md#step-13-finalize)**

## 🎓 Best Practices

### Preparation

**One week before**:
- ✅ Check the tournament in ClubCloud and load it into Carambus
- ✅ Check tables (heating!)

**One day before**:
- ✅ Check participant list
- ✅ Have the tournament plan from the invitation at hand
- ✅ Test displays

**On tournament day**:
- ✅ 1 hour before: Start up system
- ✅ Tournament Monitor on projector
- ✅ Activate scoreboards at tables
- ✅ Conduct test match

### During the Tournament

**Continuous tasks**:
- 🔍 Monitor match progress in the Tournament Monitor
- 🔍 Fix technical problems
- 🔍 Answer player questions
- 🔍 Coordinate breaks

**When problems arise**:
- Stay calm
- Consult rules
- Document changes

### After the Tournament

**Completion tasks**:
- ✅ Upload results to ClubCloud
- ✅ Maintain the final ranking in ClubCloud ([instructions](tournament-management.md#appendix-rangliste-manual))
- ✅ Collect feedback
- ✅ Document insights

## 🆘 Common Problems & Solutions

### Before the Tournament

- **Players missing from the ClubCloud registration list** → [Solution](tournament-management.md#ts-player-not-in-cc)
- **Invitation PDF cannot be uploaded** → [Solution](tournament-management.md#ts-invitation-upload)
- **Wrong tournament mode selected** → [Solution](tournament-management.md#ts-wrong-mode)

### During the Tournament

- **Tournament started, and something goes wrong** → [Solution](tournament-management.md#ts-already-started)
- **Follow-up shot forgotten at the scoreboard** → [Solution](tournament-management.md#ts-nachstoss-forgotten)
- **Player withdraws during the tournament** → [Solution](tournament-management.md#ts-player-withdraws)
- **Player does not show up** → [Solution](tournament-management.md#appendix-missing-player)
- **Shoot-out needed** → [Solution](tournament-management.md#ts-shootout-needed)
- **Scoreboard fails** → switch a free scoreboard at the neighbouring table to the failed table ([Table assignment](tournament-management.md#step-8-tables))

### After the Tournament

- **Final ranking missing in ClubCloud** → [Solution](tournament-management.md#ts-endrangliste-missing)
- **CSV upload to ClubCloud does not work** → [Solution](tournament-management.md#ts-csv-upload)
- **Automatic upload failed** → [ClubCloud upload feedback](clubcloud_upload_feedback.md)

## 📱 Device Recommendations

### For the Tournament Manager

**Desktop/Laptop**:
- Large overview of all matches
- Multiple tabs in parallel (Tournament Monitor and table scoreboards)

**Tablet**:
- Mobile in the club house
- Ideal for smaller tournaments

### For Displays

**Tournament Monitor**:
- TV/projector with HDMI
- Browser in full screen, e.g. on a Raspberry Pi

**Scoreboards**:
- In club operation: Raspberry Pi with touch display in kiosk mode
- Otherwise any browser (table monitor, smartphone, web client)
- Network connection to the Carambus server

➡️ **[Raspberry Pi Quickstart](../administrators/raspberry-pi-quickstart.md)**

## 🔐 Permissions & Delegation

### Role System

**System admin**: full administration, assigns roles and personas  
**Club admin**: club data and tournaments  
**Player**: no management

In addition there are the **personas** Sportwart and Landessportwart and the **tournament direction** of a tournament. They determine who may perform write actions in ClubCloud.

➡️ **[Detailed role description](admin-roles.md)**

### Delegating Tasks

**You can appoint** (as Sportwart within your own scope or as admin):
- **Tournament directors** for a specific tournament. Without their own ClubCloud access they can inherit the access of the Sportwart who appointed them ([Your own ClubCloud access](clubcloud-eigener-zugang.md))

**Best practice**:
- At least 2 people with manager rights
- Clear communication about responsibilities

## 📞 Support & Resources

### Documentation

- **[Tournament Management](tournament-management.md)**: Complete manual
- **[League Management](league-management.md)**: Organize league match days
- **[Admin Roles](admin-roles.md)**: Manage permissions
- **[ClubCloud](clubcloud-integration.md)**: Use integration
- **[Glossary](../reference/glossary.md)**: All technical terms

### Help with Problems

**During tournament**:
- Search documentation
- Ask other managers in club
- Emergency contact: gernot.ullrich@gmx.de

**Non-urgent**:
- GitHub Issues: [https://github.com/GernotUllrich/carambus/issues](https://github.com/GernotUllrich/carambus/issues)
- Email: gernot.ullrich@gmx.de

## 🔗 All Manager Documents

1. **[Tournament Management](tournament-management.md)** - Complete manual for individual tournaments
2. **[Quick Reference](tournament-quick-reference.md)** - Tournament flow at a glance
3. **[Single Tournament Management](single-tournament.md)** - The tournament wizard in detail
4. **[League Management](league-management.md)** - League match days and team competitions
5. **[Automatic table reservation](automatische_tischreservierung.md)** - Reservation and pre-heating for tournaments
6. **[Admin Roles](admin-roles.md)** - Manage users and permissions
7. **[ClubCloud Integration](clubcloud-integration.md)** - Connect DBU ClubCloud
8. **[ClubCloud MCP Cloud Quickstart](clubcloud-mcp-cloud-quickstart.md)** - Tournament work via AI assistant
9. **[External Tournament App (Bridge)](external-tournament-bridge.md)** - Several tournaments at one location
10. **[Filter Popup](filter_popup_usage.md)** - Find data efficiently

---

**Good luck with your tournaments! 🏆**

*Tip: Add this page to your bookmarks. It serves as a central hub for all tournament management tasks.*
