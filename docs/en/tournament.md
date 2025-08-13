---
---
title: Tournament Management
summary:
version:
published_at: !ruby/object:ActiveSupport::TimeWithZone
  utc: 2025-03-07 22:00:25.243335000 Z
  zone: !ruby/object:ActiveSupport::TimeZone
    name: Europe/Berlin
  time: 2025-03-07 23:00:25.243335000 Z
tags: []
metadata: {}
position: 0
id: 50000002
---

# Tournament Management

## Account
For Carambus tournament management, an account with admin rights on the Carambus Location Server is required.
This can be set up by the club chairman or [Carambus developer](mailto:gernot.ullrich@gmx.de).
The URL can be derived from the scoreboard URLs, e.g., in Wedel http://192.168.2.143:3131.

## Synchronization with ClubCloud

Tournaments can be found best via `Regional Associations -> Search -> View`.

There you will find the currently known tournaments of the current season. The tournament can be selected by title.
If a tournament is not yet listed, there can be several reasons:

* The tournament is not yet registered in ClubCloud
* The central Carambus API server does not yet know the tournament
* The tournament has not yet been transferred to the local Location Server

### The tournament is not yet registered in ClubCloud
It is the task of the state sports supervisor to enter the tournaments with the participant lists in ClubCloud.

### The central Carambus API server does not yet know the tournament
The API server is currently maintained by the Carambus developer (mailto: gernot.ullrich@gmx.de).
Tournament data from Carambus-using regions are automatically updated daily at 20:00 from the associated regional ClubCloud server.

Local servers always request updates from ClubCloud via the central API server (api.carambus.de).
This server fetches data from the various ClubCloud instances. With the specific updates, all updates that have been made on the API server in the meantime are also transmitted.

### The tournament has not yet been transferred to the local Location Server

A locally non-existent tournament that exists on the API server is automatically loaded with every update request to the API server, because with every request to the API server the entire data set is synchronized.
Such an explicit request can be, for example, updating the club data:
`Clubs -> Search -> View -> "Data synchronization with ClubCloud with all details"`

### Updating Regional Association, Club, Player, Tournament, Seeding Lists
When explicitly fetching data, the requested data is compared with the Billiards Area on the API server.

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
* Sorting of seeding list according to rankings
* Selection of tournament mode
* Local adjustment of tournament parameters
* Check of local scoreboards
* Start of tournament
* Synchronization of match results with game protocols
* Email with game results (csv) to tournament director
* Upload of game results (csv) to ClubCloud
* Synchronization with ClubCloud for final check

### Synchronization with ClubCloud
As described above, the tournament can first be loaded, for example, by synchronizing club data

If a tournament is already known locally, an update can be requested again at any time:
`Region -> Tournament -> Data synchronization with ClubCloud`

### Verification of relevant data

For the course of a tournament, the following data is important:

* Organizer (Regional Association or Club)
* Discipline (for table assignments)
* Date
* Season
* Venue (for table assignments)

This data is usually automatically pulled from ClubCloud. A special case is the venue.
Unfortunately, regarding the venue on ClubCloud, free text input is possible.
However, for table assignment in Carambus, the selection of a formally defined venue with table configuration is necessary (table name, table type)
Furthermore, it must be specified whether it is a handicap tournament.

This data must be supplemented via
`Tournament -> Edit -> Update Tournament`

### Sorting of seeding list according to rankings

With the BA synchronization, the participant list (seeding list) is transferred.

For handicap tournaments, the handicaps can be entered:
`Tournament -> Update seeding list`
This list can now be sorted locally according to player rankings:
`Tournament -> Sort by ranking or handicap`

The order can now still be changed by swapping places with the up/down arrows.

The order is then finally completed with
`Tournament -> Finalize ranking list (not reversible)`

### Selection of tournament mode
Now jump to tournament mode selection:
`Tournament -> Set tournament mode`

Usually several options are available. The tournament director can select a mode - usually already specified by the state sports supervisor for tournaments of regional associations.

Selection by clicking e.g. `Continue with T07`

### Local adjustment of tournament parameters

The following parameters can now still be adjusted:

* Assignment of tables (mapping internal table name to external name)
* Ball target (possibly already specified for tournament)
* Shot limit (possibly already specified for tournament)
* Timeout in sec (0 or no input if no timeouts)
* Timeouts (n timeout extensions maximum)
* Checkbox "Tournament manager checks results before acceptance"
* Warm-up time
* shortened warm-up time (when switching to an already played table)

Regarding the checkbox: Normally, players can advance the game status, e.g., after `Game ended - OK?`.
If a check by tournament manager is required, this is prevented and the tournament director can release the table after checking with the game protocol.

The new pairings appear automatically on the scoreboards.
Finally:

### Email with game results (csv) to tournament director

After completion of the tournament, the tournament director automatically receives an email with a CSV file containing the results in the format required for upload to ClubCloud.
This file is also saved on the local server ({carambus}/tmp/result-{ba_id}.csv)

### Upload of game results (csv) to ClubCloud
The tournament director can upload the CSV file directly to ClubCloud (he knows how to do that ;-)

### Synchronization with ClubCloud for final check
As a final step, another synchronization with ClubCloud can be performed.
The data downloaded with this is the basis for later calculated rankings. 