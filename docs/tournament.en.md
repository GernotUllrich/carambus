# Tournament Management

## Introduction

Carambus aims to automate all game operations at the regional and club level. It supports the most important billiard disciplines in Germany—carom, pool, snooker, and skittles — in individual tournaments and team competitions.

> **Automation with Carambus means support for all phases of billiards**, from tournament planning, setting the tournament mode, assigning match pairings according to ranking and seed lists, table allocation, real-time recording of games via scoreboards, to evaluating results and transmitting them to the central associations.

## Structure

Technically speaking, Carambus is a hierarchy of web services. At the top is a web server, the so-called Carambus API server, which serves only to store external data as up-to-date and efficiently as possible. Consumers of this data are web servers at the regional level and at the event location or in the clubhouses, which manage local game operations.

The end devices of these web servers are web browsers used by sports officials to plan and manage tournaments, as well as various display and input devices (scoreboards and remote controls) at the event venue.

In training mode, the scoreboards are used to record game results. Player lists from the club's Carambus database are used to set up games. Games are recorded on the local web server, enabling player performance to be evaluated.

As everything is based on standardized HTML protocols, Carambus is largely hardware-independent.

## Carambus API

The data stored in the Carambus API server is synchronised with the local web server. The data area can be restricted to the region and the national tournaments of the DBU and their participants.

The following data is supplied centrally by the API server:

### Regional associations
- ClubCloud-ID, name, short name, logo, e-mail, address, country

### Clubs
- ClubCloud-ID, region, name, short name, address, home page, e-mail, logo

### Venues
- Club[1], region, name, address

### Table equipment
- Table types, number, size, names

### Player data
- ClubCloud-ID, club, surname, first name, title

### Seasonal club affiliations
- Player, season, club, club guests

### Tournaments
- ClubCloud-ID, title, discipline, division, mode, entry restriction, date, accreditation deadline, venue, season, region, closing date, entry limit, points target, organizer (club or region)

### Tournament mode plans
- Name, rule system, number of players, number of tables, description, number of groups, formal procedure

### Tournament/player seeding lists
- Players, list position, tournament, specifications for handicap tournaments if applicable

### Games
- Tournament, game name, PlayerA, PlayerB

### Game results
- Game, balls, innings, highest series, average

### Player rankings
- Player, discipline, best individual average, best tournament average

### Ligen

### Mannschaftskader

### Spieltage

### Spieltagbegegnungen

> **Note:** From 2022, the BillardArea has been replaced by the ClubCloud. Unlike the BA, there are no longer unique identifiers nationwide. The ClubCloud-IDs are only unique within the regional ClubCloud instances.

## Account

For Carambus tournament management, an account with admin rights on the Carambus Location Server is required. This can be set up by the club chairman or [Carambus developer](mailto:gernot.ullrich@gmx.de).

The URL can be derived from the scoreboard URLs, e.g., in Wedel http://192.168.2.143:3131.

## Synchronization with ClubCloud

Tournaments can best be found via `Regional Associations -> Search -> View`. There, the currently known tournaments of the running season are listed. The tournament can be selected via the title.

Btw - with the **[AI Assistent](ai_search.md)** (available from October 2025), you could also simply search for “Tournaments in the NBV in the 2025/2026 season no older than 2 weeks.”

If a tournament is not yet listed, this can have several reasons:

* The tournament is not yet entered in the ClubCloud
* The central Carambus API server does not yet know the tournament
* The tournament has not yet been transferred to the local Location Server

### The tournament is not yet entered in the ClubCloud
It is the task of the state sports supervisor to enter the tournaments with the participant lists in the ClubCloud.

### The central Carambus API server does not yet know the tournament
The API server is currently maintained by the Carambus developer (mailto: gernot.ullrich@gmx.de). Tournament data from regions using Carambus is automatically updated daily at 20:00 from the associated regional ClubCloud server.

Local servers always request updates from the ClubCloud via the central API server (api.carambus.de). This server retrieves data from the various ClubCloud instances. With the specific updates, all updates that were made on the API server in the meantime are also always transmitted.

### The tournament has not yet been transferred to the local Location Server
A locally non-existent tournament that exists on the API server is automatically loaded with every update request to the API server, because with every request to the API server, the entire database is synchronized.

Such an explicit request can be, for example, updating the club data:
`Clubs -> Search -> View -> "Data synchronization with ClubCloud with all details"`

### Updating Regional Association, Club, Player, Tournament, Seeding Lists
When explicitly retrieving data, the requested data is compared with the Billard Area on the API server.

The following explicit data requests are implemented:

* `Club -> Data synchronization with ClubCloud`
* `Club -> Data synchronization with ClubCloud with all details`
* `Regional Association -> Data synchronization with ClubCloud incl. Clubs`
* `Regional Association -> Data synchronization with ClubCloud incl. Clubs and Players`
* `Tournament -> Data synchronization with ClubCloud`

## Regional Tournament Management

Tournament management is carried out in the following steps:

### Updating tournament data
Before the tournament starts, care should be taken to ensure that the tournament is updated with the seeding lists in the Billard-Area. The synchronization with the local Carambus tournament manager can then be initiated.

### Determining the seeding list
With the synchronization, the list of participants is taken over. The seeding list is derived from the players' ranking list positions. The game leader can add additional players to fill in dropouts and make minor changes if necessary.

### Selecting the tournament mode
Once the ordered player list and thus also the number of players is established, the tournament mode is selected. In general, there are several possibilities (group games and main round, possibly with play-offs for places or everyone against everyone, etc.)

## Local Game Management

Once the tournament mode is established, the tournament can begin.

### Determining the tables
From the set of tables available at the venue, tables 1-n are assigned from the tournament mode's game plan.

### Setting some parameters
Before the start, the following parameters can optionally be updated according to the tournament rules:

* Inning limit
* Ball target
* Warm-up time on new table
* Warm-up time when returning to a table
* Thinking time before a shot

### Start and course of the game
From now on, everything runs automatically. The game pairings appear on the scoreboards with indication of the group numbers and game names (e.g., Group 2 Game 2-4, i.e., in group 2 the 2nd player against the 4th player).

First, the invitation to warm up appears on the scoreboards with corresponding timers, e.g., 5 or 3 minutes.

Next, the invitation to break appears. As a result, players can be swapped (White breaks, Yellow breaks after).

Once the breaking player is established, the game starts.

The following inputs are possible on the scoreboards:

* **`+1`** - Increase the ball count of the current inning by one. (On touch displays, this can also be triggered by clicking on the respective number)
* **`-1`** - Decrease the ball count of the current inning by one
* **`nnn`** - Set the ball count of the current inning. Show the number field 0-9. Any positive number can be entered. Complete with Enter or cancel with C
* **`DEL`** - With an Undo button, you can go back to any inning. After correction with +1, -1 or nnn input, you can browse to the current inning through multiple player changes
* **`^v`** - Player change: The current ball count of the completed inning is saved and added to the sum. The other now active player is marked on the scoreboard. (On touch displays, this can also be triggered by clicking on the ball count of the respective other player)

The referee can start **`>`**, end **`o`** or pause **`||`** the timer for thinking time

### 4-Button Remote Control
For tournaments with referees, a special operating mode with 4-button remote controls is supported. These remote controls are those used to remotely control PowerPoint presentations, for example.

The buttons A (pageup), B (pagedown), C (b) and D (F5, ESC) have the following meanings depending on the game status:

#### Warm-up
* A starts the warm-up timer for player A
* B starts the warm-up timer for player B
* With D, continue to the break phase

#### Break
* A or B changes the breaking player (Player A breaks with White)
* With D, the game is started as soon as it is set up and player A has appeared

#### Game phase
* When player A is at bat, a point is counted for him with A
* When player A is at bat, with a missed inning, switch to player B with B
* When player B is at bat, a point is counted for him with B
* When player B is at bat, with a missed inning, switch to player B with A
* When a player has reached the goal (inning limit or point target), it automatically switches to player B for the follow-up shot or ends the game

The buttons should only be pressed when the balls have come to rest and the player is basically ready for the next shot. With the button, the timer for thinking time is started simultaneously.

The extended input options above can also be triggered with the 4-button remote control. To do this, switch from simple input mode (the inning field is selected) to input mode with button D down. In input mode, the individual input fields are controlled by left/right navigation with buttons A and B. The functions are triggered with button D (down) respectively. The respective input field remains selected afterwards, so that the same function can simply be applied multiple times. Return to normal input mode with button C (up)

### Timeout handling
During tournament planning or even first at tournament start, the length of thinking time (timeout) and the number of possible timeout extensions (timeouts) can be specified. With the remote control, the timeout counter can be decreased by one during the running game. The remaining thinking time is then extended once more by the specified timeout.

With the remote control, navigate to the timer symbol with button D down and trigger it with button A (left). Button up (button C) leads back to normal input mode.

The other functions (Stop, Halt, Play) can also be triggered with the remote control. To do this, you can cycle through the respective function with button B (right) in timer mode and trigger it with button A (left).

### The end of the game
is automatically recognized based on the inputs and the inning or ball count.

A final protocol is displayed on the board. The players confirm the result with an input on the scoreboard.

### Switch to next round
As soon as all games of a round are finished, the next round starts automatically. The corresponding new pairings are displayed on the scoreboards.

### End of tournament
As soon as all games of the tournament are completed, a final protocol is sent to the game leader with a CSV file, which can then be used directly for uploading the results to the Billard-Area.

## Training Mode
At the scoreboards, the respective tables can be selected. Depending on the tournament status, free tables can be recognized and used for free training games.

Ad-hoc games can be initialized via a parameter field. Input options are:

* **Discipline** (according to the respective table properties, for both, can be specified separately for the individual player)
* **Target ball count** (for both, can be specified separately for the individual player)
* **Inning limit**
* **Timeout** (optional)
* **Timeouts** (optional number of timeout extensions)
* **Players** (selection from club players or guests)
* **Individual discipline** or target ball count

For a future extension, statistics on training games are planned (per player and per game pairing)

## Tournament Management - Detailed Workflow

A tournament is generally managed in the following phases:

* Synchronization with ClubCloud
* Verification of relevant data
* Sorting of seeding list according to rankings
* Selection of tournament mode
* Local adjustment of tournament parameters
* Check of local scoreboards
* Start of tournament
* Comparison of game results with game protocols
* Email with game results (csv) to tournament leader
* Upload of game results (csv) to ClubCloud
* Synchronization with ClubCloud for final check

### Verification of relevant data

For the course of a tournament, the following data is important:

* Organizer (Regional Association or Club)
* Discipline (for table assignments)
* Date
* Season
* Venue (for table assignments)

This data is usually pulled automatically from the ClubCloud. A special case is the venue. Unfortunately, free text input is possible for the venue on the ClubCloud. However, for table assignment in Carambus, the selection of a formally defined venue with table configuration is necessary (table name, table type). Furthermore, it must be specified whether it is a handicap tournament.

This data must be supplemented via `Tournament -> Edit -> Update Tournament`

### Sorting of seeding list according to rankings

With the BA synchronization, the participant list (seeding list) is transferred.

For handicap tournaments, the handicaps can be entered: `Tournament -> Update Seeding List`

This list can now be sorted locally according to player rankings: `Tournament -> Sort by Ranking or Handicap`

The order can now still be changed by swapping places with the up/down arrows.

The order is then finally completed with `Tournament -> Finalize Ranking List (not reversible)`

### Selection of tournament mode
Now jump to tournament mode selection: `Tournament -> Set Tournament Mode`

In general, several options are available. The tournament leader can select a mode - usually already specified by the state sports supervisor for tournaments of regional associations.

Selection by clicking e.g., `Continue with T07`

### Local adjustment of tournament parameters

The following parameters can now still be adjusted:

* Assignment of tables (mapping internal table name to external names)
* Ball target (possibly already specified for tournament)
* Inning limit (possibly already specified for tournament)
* Timeout in sec (0 or no input if no timeouts)
* Timeouts (n timeout extensions maximum)
* Checkbox "Tournament manager checks results before acceptance"
* Warm-up time
* shortened warm-up time (when switching to an already played table)

**Regarding the checkbox:** Normally, players can advance the game status, e.g., after `Game ended - OK?`. If a check by tournament manager is required, this is prevented and the tournament leader can release the table after comparison with the game protocol.

The new game pairings appear automatically on the scoreboards.

### Email with game results (csv) to tournament leader

After the tournament is completed, the tournament leader automatically receives an email with a CSV file containing the results in the format required for uploading to the ClubCloud. This file is also saved on the local server (`{carambus}/tmp/result-{ba_id}.csv`)

### Upload of game results (csv) to ClubCloud
The tournament leader can upload the CSV file directly to the ClubCloud (he knows how to do it ;-)

### Synchronization with ClubCloud for final check
As a final step, another synchronization with the ClubCloud can take place. The data downloaded with this is the basis for later calculated rankings. 
