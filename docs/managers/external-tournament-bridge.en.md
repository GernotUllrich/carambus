# External Tournament Bridge — User Guide

> **Persona:** Tournament director or club admin running their own tournament
> app, who wants to sync seeding and results between the app and Carambus.

## What is this?

If your club uses its own tournament app (e.g., 3BandMannschaftsTurnier for
3-cushion team championships), that app can now talk to Carambus directly —
no more typing results twice.

Three data flows:

1. **Carambus → app**: Seeding list with players and teams (the app pulls
   player data from the Carambus database).
2. **App → Carambus**: Table pairings (the app tells Carambus which player
   plays whom at which table — Carambus activates the scoreboards).
3. **Carambus → app**: Game results (balls, innings, high series) from the
   scoreboard input back into the app.

There are further endpoints under `/api/external_tournament/` (among others local
app tournaments, table locking, result acknowledgement, league match day, player
reconciliation); details in the [developer docs](../developers/external-tournament-bridge.md).

## When do I need this?

Simple regular tournaments keep running through the **Tournament Monitor** of the Carambus web app. The
external app is intended for the case where **several tournaments come together at one location**.

- You have your own tournament software that Carambus does not cover (e.g.,
  a specific 3-cushion team format with custom standings logic).
- On-site setup on iPad or laptop in the clubhouse that must work offline.
- You want to eliminate duplicate data entry between your app and the
  Carambus scoreboards.

If your club tournament runs entirely in Carambus (registration → draw →
scoreboards → final standings), you do **not** need this bridge.

## Setup workflow

### Who does what?

| Role | Activity |
|------|----------|
| Sportwart / admin | Create service account, hand over password securely |
| App developer / tournament director | Configure the app with email + password + base URL |

### Step 1: Create the service account (Sportwart)

On the Carambus server the app is going to work with (the account is a user in
its database), in the deploy directory:

```bash
cd /var/www/<basename>/current
RAILS_ENV=production bundle exec rake "service_accounts:create_carambus_app[NBV]"
```

Output: a one-time password — **communicate securely**, not in plain text
in chat or email. Hand it over in person or via a trusted channel
(e.g., a password manager share).

If the account already exists, the task prints **no** password. A new password is
created by `ROTATE=1 RAILS_ENV=production bundle exec rake "service_accounts:create_carambus_app[NBV]"`;
this invalidates all tokens issued so far.

### Step 2: Configure the app (app developer / tournament director)

The app needs:

- **Base URL** — depends on the deployment topology:
  - Local in the clubhouse Wi-Fi: `http://<IP of the local server>:<webserver_port>` (default
    3131, e.g. `http://192.168.2.210:3131`). If Carambus serves the app itself under `/app/`, no
    base URL is needed (see below).
  - Per-region cloud: `https://nbv.carambus.de`
  - Global cloud: `https://carambus.de`
- **Service-account email**: `carambus-app-nbv-bridge@carambus.de`
  (or the equivalent for other regions)
- **Password**: from step 1
- **Region shortname**: e.g., `NBV`

The app runs one login call per session and receives a bearer token (valid
for 90 days). All subsequent API calls use this token in the `Authorization`
header.

Login: `POST <base URL>/login` with the headers `Content-Type: application/json` **and**
`Accept: application/json`, body `{"user":{"email":"…","password":"…"}}`. The token is in the
`Authorization` header of the response.

### Served by Carambus (`/app/`)

Carambus can serve the tournament app itself under `/app/`. App and Carambus then run on the
same server (same origin): the app derives its API address from the browser address, no base URL
is needed, and the chat offers a deep link `/app/?…` with region and tournament (the password is
never part of the link).

Prerequisites, as the tooling requires them:

- `serve_tournament_app: true` in `carambus_data/scenarios/<scenario>/config.yml`
- the `carambus_app` repository on the admin machine **next to** `carambus_data`, with
  `carambus_app/public/index.html`
- `rake "scenario:prepare_deploy[<scenario>]"` copies `carambus_app/public/` to
  `<deploy_to>/shared/public/app` (step 4.6). If `index.html` is missing, the task warns and the
  deployment continues; `/app/` then returns 404.

How another club gets the `carambus_app` repository is not covered by the docs; that is open.

### Step 3: Smoke test before the tournament

Verify connectivity before the first real tournament:

On the local server, in the deploy directory (the task looks up the tournament in
the database it runs against):

```bash
cd /var/www/<basename>/current
BASE_URL=http://localhost:<webserver_port> SERVICE_ACCOUNT_PASSWORD="<password>" \
  RAILS_ENV=production bundle exec rake "external_tournament:smoke_test[NBV]"
```

Without `BASE_URL` the task uses `http://localhost:3000` and already fails at the login.

A successful run prints six `✓` steps (login → tournament lookup → seeding
→ round start → round result → player reconcile). On failure see "What can
go wrong?" below.

!!! warning "The smoke test writes"
    It takes the first tournament of the region that is linked to ClubCloud,
    creates a test game there and occupies table 1 of the tournament location.
    Do not run it during match play. Clean up afterwards with
    `rake "external_tournament:reset_app_tournament[<tournament_id>]"` (tournament
    back to the start, `DRY_RUN=1` shows what would happen) or
    `rake "external_tournament:end[<tournament_id>]"` (end it and release the tables).

## Deployment topology

The bridge works in three topologies — from the app's perspective the only
thing that changes is the base URL:

| Topology | Example | App base URL |
|----------|---------|--------------|
| **Local at the venue** | carambus_bcw at the clubhouse, app on iPad in the same Wi-Fi | `http://<IP of the local server>:3131`, or none with `/app/` |
| **Per-region cloud** | nbv.carambus.de | `https://nbv.carambus.de` |
| **Global cloud** | carambus.de | `https://carambus.de` |

**Real-world default for club tournaments: local.** No internet required,
all data stays in the clubhouse Wi-Fi. Sync to the upstream per-region or
global instance runs decoupled via the Carambus sync layer — the app is
independent of that.

Technical details:
[Developer docs — External Tournament Bridge](../developers/external-tournament-bridge.md)

## What can go wrong?

### "401 Unauthorized"

Bearer token missing or invalid. Fix: have the app run a new login call and
extract the token from the `Authorization` response header.

### "404 Not Found" on `/seeding` or `/round_result`

`tournament_cc_id` or `region` does not match. Check:

- Correct region shortname (e.g., `NBV` rather than `nbv` — Carambus
  normalizes, but consistent casing helps).
- `tournament_cc_id` actually exists in Carambus (the Sportwart can verify
  via the admin UI or via ClubCloud MCP).

### "422 Region mismatch"

The tournament's region does not match the region parameter. Verify the
tournament is actually assigned to the given region.

### "422 Table not found: N"

On round start: Carambus cannot find a table with this name in the
tournament's location. It searches for `table_name` from the payload (e.g.
`"Tisch 5"`), otherwise for `table_no` as text. The location comes from the
payload (`location.id` or `cc_id`), otherwise from the tournament. Fix: the
Sportwart checks the tables in the Carambus admin UI — either create tables with
the names the app expects or adjust the app's convention.

### "422 TableMonitor not found for N"

The table exists, but no table monitor can be created. This happens when the
server is not a local server.

### "422" on login

The header `Accept: application/json` is missing (see step 2).

### "422 Player not resolved"

On round start: a player match failed. Carambus tries the following
fallback chain:

1. Region + ClubCloud ID
2. DBU membership number
3. First name + last name (optional + club)

Fix: the Sportwart creates the unknown player manually in the CC UI
(first name, last name, club). The new player then first has to arrive on the
Carambus server via sync before a new round start succeeds. There is also the
endpoint `POST /api/external_tournament/player_reconcile` for reconciliation.

## Pilot story

Intended as the first application: BC Wedel 3-cushion team championship
2026-05-17, with the 3BandMannschaftsTurnier app on iPad in the clubhouse Wi-Fi
against the local `carambus_bcw` scenario.

Status: **A practical test in tournament operation is still pending** (operator,
2026-09-12). Technically, a live test of the connection with the app took place in
June 2026 (findings among others on same-origin delivery under `/app/`, commit
`52337e16`); since August there are tools for local app tournaments
(`external_tournament:end`, `reset_app_tournament`, `release_stale_local_tables`).

## Related docs

- [Developer docs — Technical details and mapping tables](../developers/external-tournament-bridge.md)
- [API reference — Full endpoint specification](../reference/api.md)
- [ClubCloud MCP setup service (the Sportwart-side counterpart)](clubcloud-mcp-setup-service.md)
