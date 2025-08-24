---
---
title: Individual Tournament Management
summary: Individual tournament management provides a bridge between tournament planning in ClubCloud, Carambus Scoreboards, and the ClubCloud results service. This document describes the processes in detail.
version:
published_at: !ruby/object:ActiveSupport::TimeWithZone
  utc: 2025-03-05 14:49:55.360649000 Z
  zone: !ruby/object:ActiveSupport::TimeZone
    name: Europe/Berlin
  time: 2025-03-05 15:49:55.360649000 Z
tags: []
metadata: {}
position: 1
id: 3
---

# Tournament Management

## Account
For Carambus tournament management, an account with admin rights on the Carambus location server is required.
This can be set up by the club chairman or [Carambus developer](mailto:gernot.ullrich@gmx.de).
The URL is derivable from the scoreboard URLs, e.g., in Wedel http://192.168.2.143:3131.

## Synchronization with ClubCloud

Tournaments can best be found via `Regional Associations -> Search -> View`.

There, the currently known tournaments of the running season are listed. The tournament can be selected via the title.
If a tournament is not yet listed, this can have several reasons:

* The tournament is not yet entered in ClubCloud
* The central Carambus API server does not yet know the tournament
* The tournament has not yet been transferred to the local location server

### The tournament is not yet entered in ClubCloud
It is the task of the state sports supervisor to enter the tournaments with participant lists in ClubCloud.

### The central Carambus API server does not yet know the tournament
The API server is currently maintained by the Carambus developer (mailto: gernot.ullrich@gmx.de).
Tournament data from Carambus-using regions are automatically updated daily at 20:00 from the associated regional ClubCloud server.

Local servers always request updates from ClubCloud via the central API server (api.carambus.de).
This server retrieves data from the various ClubCloud instances. With the specific updates, all updates that have been made on the API server in the meantime are also always transmitted.

### The tournament has not yet been transferred to the local location server

A locally non-existent tournament that exists on the API server is automatically loaded with every update request to the API server, because with every request to the API server, the entire database is synchronized.
Such an explicit request can be, for example, updating club data:
`Clubs -> Search -> View -> "Data synchronization with ClubCloud with all details"`

### Updating Regional Association, Club, Player, Tournament, Seeding Lists
When explicitly retrieving data, the requested data is compared with the Billiards Area on the API server.

The following explicit data requests are implemented:

* `Club -> Data synchronization with ClubCloud`
* `Club -> Data synchronization with ClubCloud with all details`
* `Regional Association -> Data synchronization with ClubCloud incl. Clubs`
* `Regional Association -> Data synchronization with ClubCloud incl. Clubs and Players`
* `Tournament -> Data synchronization with ClubCloud`

## Tournament Management
A tournament is generally managed in the following phases:

* Synchronization with ClubCloud
* Verification of relevant data
* Sorting of the seeding list according to rankings
* Selection of tournament mode
* Local adjustment of tournament parameters
* Check of local scoreboards
* Start of the tournament
* Synchronization of match results with game protocols
* Email with game results (csv) to the tournament director
* Upload of game results (csv) to ClubCloud
* Final synchronization with ClubCloud for last check.

### Synchronization with ClubCloud
As described above, the tournament can first be loaded, for example, by synchronizing club data

If a tournament is already locally known, an update can be requested again at any time:
`Region -> Tournament -> Data synchronization with ClubCloud`

### Verification of relevant data

For the course of a tournament, the following data are important:

* Organizer (Regional Association or Club)
* Discipline (for table assignments)
* Date
* Season
* Venue (for table assignments)

This data is usually automatically pulled from ClubCloud. A special case is the venue.
Unfortunately, regarding the venue in ClubCloud, free text input is possible.
However, for table assignment in Carambus, the selection of a formally defined venue with table configuration is necessary (table capture, table type)
Furthermore, it must be specified whether it is a handicap tournament.

### Sorting of the seeding list according to rankings

The seeding list is automatically sorted according to the current rankings of the players.
The ranking system used is the one from the Billiards Area.
If a player does not have a ranking, he is placed at the end of the list.

### Selection of tournament mode

Carambus supports various tournament modes:

* **Single Elimination**: Players are eliminated after one loss
* **Double Elimination**: Players are eliminated after two losses
* **Round Robin**: All players play against each other
* **Swiss System**: Players with similar scores play against each other

The tournament mode is automatically determined from ClubCloud, but can be changed locally if necessary.

### Local adjustment of tournament parameters

After loading from ClubCloud, the following parameters can be adjusted locally:

* **Table assignments**: Which tables are used for which matches
* **Match times**: When matches start and how long they last
* **Break times**: How long breaks between matches last
* **Scoring system**: How points are awarded

### Check of local scoreboards

Before starting the tournament, it must be ensured that:

* All scoreboards are operational
* Table assignments are correctly configured
* Players can log in to their assigned tables
* The tournament mode is correctly set

### Start of the tournament

Once all checks are complete, the tournament can be started:

1. **Activate tournament mode** on all scoreboards
2. **Assign players** to their starting positions
3. **Start first round** of matches
4. **Monitor progress** and handle any issues

### Synchronization of match results with game protocols

After each match, the results are automatically:

* **Recorded** on the scoreboard
* **Transmitted** to the local server
* **Stored** in the local database
* **Compared** with the game protocols from ClubCloud

### Email with game results (csv) to the tournament director

At the end of each round, an email is automatically sent to the tournament director containing:

* **Match results** in CSV format
* **Current standings** of all players
* **Next round** schedule
* **Any issues** that need attention

### Upload of game results (csv) to ClubCloud

After the tournament is complete, all results are:

* **Compiled** into a comprehensive CSV file
* **Uploaded** to ClubCloud via the API server
* **Verified** for accuracy and completeness
* **Archived** for future reference

### Final synchronization with ClubCloud

The final step ensures that:

* **All results** are correctly stored in ClubCloud
* **Rankings** are updated based on tournament performance
* **Statistics** are updated for future tournaments
* **Data consistency** is maintained across all systems

## Troubleshooting

### Tournament not loading from ClubCloud
- Check internet connection to ClubCloud
- Verify API server is accessible
- Check if tournament exists in ClubCloud
- Verify user permissions

### Scoreboard issues
- Check table assignments
- Verify player logins
- Check tournament mode settings
- Restart scoreboards if necessary

### Result synchronization problems
- Check local database connectivity
- Verify API server communication
- Check CSV file format
- Verify email delivery

## Best Practices

### Before starting a tournament
1. **Complete all data synchronization** with ClubCloud
2. **Verify all scoreboards** are operational
3. **Test player logins** on all tables
4. **Confirm table assignments** are correct
5. **Review tournament parameters** and adjust if needed

### During the tournament
1. **Monitor all matches** for any issues
2. **Handle player requests** promptly
3. **Keep backup of results** in case of technical issues
4. **Communicate with tournament director** regularly

### After the tournament
1. **Verify all results** are recorded correctly
2. **Complete result upload** to ClubCloud
3. **Archive tournament data** for future reference
4. **Update local statistics** and rankings
5. **Prepare summary report** for organizers 