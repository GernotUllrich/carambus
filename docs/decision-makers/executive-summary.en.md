# Executive Summary

Carambus on one page: what it can do, how it is built, what a club needs and how the project is set up. In
detail: [Features Overview](features-overview.md) and [Deployment Options](deployment-options.md).

## What Carambus can do

- **Tournaments (carom):** tournament plans of the German carom tournament rules (T-plans), round robin for any
  number of participants, knockout and double knockout; group ranking according to the tournament rules,
  tiebreak in knockout games; the tournament monitor shows groups, running games, knockout bracket and ranking
- **Scoreboards** for carom, pool and snooker — on a Raspberry Pi in kiosk mode at the table or in any browser;
  all displays update in real time
- **League:** league match days with the Party Monitor (line-up, table assignment, result confirmation) and league
  tables
- **ClubCloud:** players, clubs, tournaments and leagues come from the DBU ClubCloud; tournament results go back by
  upload
- **At the club:** table reservation via the club's Google Calendar with preheating of the tables, training games
  at the scoreboard, YouTube live streaming with a scoreboard overlay
- **For associations:** individual championships with entry list and results even without the ClubCloud, via the
  region server ([CC-less tournament management](../administrators/cc-less-tournament-management.md), German)

**With conditions:**

- **AI search:** turns a question into a list filter. It needs your own Anthropic API key (running costs); the
  search queries are sent to Anthropic.
- **ClubCloud assistant (MCP)** for sports officials: runs in Claude Code on the official's computer and needs an
  account on the region's Carambus server
  ([Quickstart](../managers/clubcloud-mcp-cloud-quickstart.md), German).

## How Carambus is built

Carambus is a network of several servers:

- The **Authority** `api.carambus.de`, run by the Carambus operator, reads the data from the ClubCloud and holds
  the shared master data: players, clubs, tournaments, tournament plans.
- A **club server** at the venue — usually a Raspberry Pi — fetches this master data from the Authority every hour
  and cannot change it. Whatever is created at the club (local tournaments, games, training results, table
  reservations) stays on the club server.
- For regional associations there is a **region server** (e.g. `nbv.carambus.de`).

Play at the venue continues without internet. Without a connection, new data from the Authority is missing, and
the result upload to the ClubCloud only works again once the connection is back. More:
[Server architecture](../administrators/server-architecture.md).

## What a club needs

- **Hardware:** Raspberry Pi 4 or 5 (4 GB RAM recommended), microSD card, monitor or touch display; one display
  device for each additional table
- **A person with Linux and SSH skills** and a Mac or Linux computer from which they set up the Pi (Ansible, Rake
  tasks). Measured: about 1.5 hours, after which the Pi boots into the scoreboard by itself
- **The Carambus operator:** the initial database load and the server's access keys come from the operator
  today. How a
  club can do both itself in the future is still open.
- **The ClubCloud:** players and clubs must be maintained there; the tournament director does the result upload
  with their ClubCloud access
- **A mail account** for sending mail — or a deliberate decision to run without mail

In detail: [Requirements for running your own server](deployment-options.md#voraussetzungen).

## Technology

- Ruby on Rails 7.2 (7.2.2.2) on Ruby 3.2.1, PostgreSQL, Redis; user interface with Hotwire (Turbo, Stimulus) and
  StimulusReflex/CableReady, real time via WebSockets
- **Maintenance status:** Ruby 3.2 has received no security updates from its maintainers since the end of March
  2026, Rails 7.2 since August 2026. The upgrade to newer versions is still pending.

## Privacy and security

- Contact details of club members (email, consent) stay on the club server; mails to members are only sent with
  consent.
- Player and club data from the ClubCloud is distributed by the Authority to the servers of the region.
- External services only if they are set up: Anthropic (AI search), Google Calendar (table reservation), YouTube
  (streaming).
- Passwords are stored with bcrypt, access credentials (ClubCloud passwords, stream keys) encrypted.
- Publicly reachable servers run over HTTPS; a club server at the venue runs without HTTPS on port 3131.
- The setup via Ansible configures a firewall (web and SSH port only) and automatic security updates of the
  operating system.

## License and costs

- **MIT license:** no license fees, source code freely available, commercial use allowed
- Costs arise for the hardware and for optional external services (such as the Anthropic key for AI search)

## In use

- **Billardclub Wedel 61 e.V.:** club server on a Raspberry Pi with touch display — scoreboards, club tournaments,
  table reservation with heating control
- Further club servers on Raspberry Pis and the NBV region server (`nbv.carambus.de`)

## Project and contact

Carambus is a single-developer project and is actively maintained ([About the project](../about.md)). Help is
available on request.

- **Email:** gernot.ullrich@gmx.de
- **GitHub:** [GernotUllrich/carambus](https://github.com/GernotUllrich/carambus)
