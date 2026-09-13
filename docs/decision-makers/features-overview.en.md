# Features Overview

What Carambus can do today, grouped by area of use — and at the end, what Carambus cannot do. Every feature on
this page has been verified in the code (as of September 2026).

## Tournaments (carom)

- **Tournament plans:** the T-plans of the German carom tournament rules and a round-robin plan for any number of
  participants; knockout and double-knockout plans; groups followed by a knockout round or placement games,
  depending on the plan
- **Group ranking** by points, general average, head-to-head result, best single average and high run; tiebreak
  for a draw in knockout games
- **Disciplines:** straight rail, balkline, one-cushion, three-cushion and Kegelbillard (BK-2, BK-2plus,
  BK-2kombi, BK50, BK100)
- **Settings per tournament:** point target, innings limit, shot clock, warm-up time, sets, break alternation,
  equalizing inning
- **Procedure:** take the seeding list from the PDF invitation, assign games to tables automatically (optionally
  as soon as a table becomes free), automatic round changes
- **Tournament monitor:** groups, running games, knockout bracket, results and ranking; it also shows which games a
  round is still waiting for
- **Without the ClubCloud:** individual championships with entry list and result list via the association's
  region server ([CC-less tournament management](../administrators/cc-less-tournament-management.md), German)

Manual: [Tournament management](../managers/tournament-management.md)

## Tournament app {#turnier-app}

A browser app for the tournament director that the club server delivers under `/app/`. It runs a tournament
itself, puts the games on the scoreboards at the tables and receives the results from there; results can also be
entered directly in the app.

- **Tournament formats:** knockout system (single and double knockout according to the ClubCloud plans, also in
  pool and snooker), three-cushion team championship (4 teams × 4 players), tournament plans T01–T24 with groups
  and a final round, league match day
- **Tournament state:** if a tournament plan is attached to a tournament created in Carambus, the state lives on
  the server; several devices and tournament directors can then work on it. Otherwise the state lives in the
  browser of the device.
- **Result archive:** final standings and games go to the club server automatically and appear there on the
  tournament page (knockout, team championship, tournament plans).
- **In use:** international ladies' tournament at BC Wedel, August 2026 (three-cushion, tournament plan). No pool or
  snooker tournament has been played with the app yet.
- **Requirements:** delivery is switched on in the server configuration; the app logs in with a service account of
  the region that an admin creates. Creating an app tournament in Carambus currently requires settings you need to
  know about (manual game assignment, end date in the future).

## Scoreboards

- **Carom:** score, innings, general average, high run, remaining points, shot clock
- **Pool:** 8-, 9- and 10-ball as well as 14.1 continuous (with foul counter), sets to win, winner or alternating
  break
- **Snooker:** frames (best of), break, points remaining, colours in play, 6, 10 or 15 reds, foul entry
- Pool and snooker run in free games, on league match days and in knockout tournaments of the
  [tournament app](#turnier-app); the tournament monitor only runs carom tournaments.
- **At the table:** Raspberry Pi with monitor or touch display in kiosk mode, or any browser; an on-screen
  keyboard allows logging in without a keyboard attached
- **Corrections:** undo at the scoreboard and protocol editor before confirmation; game protocol as PDF
- All displays update in real time.

Manual: [Scoreboard guide](../players/scoreboard-guide.md)

## League

- Leagues, teams and match days come from the ClubCloud.
- **Party Monitor** for the match day: line-up from the eligible players, table and player assignment, result
  confirmation, team score
- **League tables** for carom, pool and snooker

Manual: [League management](../managers/league-management.md)

## ClubCloud

- The Authority reads tournaments, players, clubs and leagues from the DBU ClubCloud; players are matched via
  their DBU number.
- The participant list can be finalized with your own ClubCloud access.
- Results go to the ClubCloud automatically after each game or as a CSV file at the end.

Manual: [ClubCloud integration](../managers/clubcloud-integration.md)

## At the club

- **Table reservation** via the club's Google Calendar; after the entry deadline Carambus reserves the tables for
  a tournament automatically ([Table reservation and heating](../managers/table_reservation_heating_control.md))
- **Heating control:** Carambus switches the table heaters via TP-Link Wi-Fi plugs — to preheat before a
  reservation, on with scoreboard activity, off with inactivity
- **Training:** training games at the scoreboard are recorded; when selecting players, those who last trained the
  same way are listed first
- **Streaming:** YouTube live broadcast of the tables with a scoreboard overlay
  ([Streaming setup](../administrators/streaming-setup.md))
- **Scoreboard messages** from the administration to the tables
- **Event calendar** with tournaments and league match days

## Search and assistants

- **Filters** in the lists (players, tournaments, clubs …) with input fields for date, number and selection
  ([Filter popup](../managers/filter_popup_usage.md))
- **AI search:** turns a question in natural language into a list filter. It requires an Anthropic API key
  (running costs); the search query is sent to Anthropic.
- **ClubCloud assistant (MCP):** sports officials handle ClubCloud tasks in natural language in Claude Code. It
  requires Claude Code on their own computer and an account on the region's Carambus server
  ([Quickstart](../managers/clubcloud-mcp-cloud-quickstart.md), German).

## Rankings, players, international data

- Rankings per season and discipline (wins, losses, general average, high run, best single average) and regional
  rankings across several seasons
- Public player profile with rankings and tournament participations
- International tournament data (UMB, Cuesco) and videos (Kozoom, YouTube)

## Interfaces

- **Bridge:** the JSON interface through which the [tournament app](#turnier-app) — and other tournament apps —
  talk to Carambus, with token authentication
  ([External Tournament Bridge](../managers/external-tournament-bridge.md))

## Users and permissions

- Roles: player, club admin, system admin; plus the duties sports official (location) and regional sports
  official (region) and the tournament direction per tournament
- Club members log in with a PIN and maintain their email address and consent themselves; the PIN session ends
  after inactivity, and after repeated failed attempts the login is temporarily locked

## Languages

- User interface and documentation in German and English

<a id="nicht-enthalten"></a>
## What Carambus cannot do

The following does not exist in Carambus, even though earlier versions of this page mentioned it:

- Pool and snooker tournaments with groups and tournament plans (knockout works via the tournament app) and the
  Swiss system
- An online booking system with its own calendar view, booking confirmation and cancellation — reservations go
  through the club's Google Calendar
- An offline mode of the Carambus user interface, home screen installation and push notifications; notifications
  about upcoming games
- Two-factor authentication and login via Google or Facebook
- Data export and anonymization for players; deleting player data that comes from the ClubCloud
- A change history for game results with an undo function
- Statistical analyses (tournament, club and head-to-head statistics), periodic reports, CSV or PDF export of lists
- An open REST API for statistics, webhooks, a plugin system
- Comments, photo upload, sharing on social networks
