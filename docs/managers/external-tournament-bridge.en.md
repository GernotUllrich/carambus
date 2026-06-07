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

## When do I need this?

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

In the Carambus scenario's server directory:

```bash
rake service_accounts:create_2band[NBV]
```

Output: a one-time password — **communicate securely**, not in plain text
in chat or email. Hand it over in person or via a trusted channel
(e.g., a password manager share).

### Step 2: Configure the app (app developer / tournament director)

The app needs:

- **Base URL** — depends on the deployment topology:
  - Local in the clubhouse Wi-Fi: `http://carambus.local:3000` or
    `http://192.168.X.X:3000`
  - Per-region cloud: `https://nbv.carambus.de`
  - Global cloud: `https://carambus.de`
- **Service-account email**: `2band-nbv-bridge@carambus.de`
  (or the equivalent for other regions)
- **Password**: from step 1
- **Region shortname**: e.g., `NBV`, `BCW`

The app runs one login call per session and receives a bearer token (valid
for 90 days). All subsequent API calls use this token in the `Authorization`
header.

### Step 3: Smoke test before the tournament

Verify connectivity before the first real tournament:

```bash
SERVICE_ACCOUNT_PASSWORD="<password>" rake external_tournament:smoke_test[NBV]
```

A successful run prints six `✓` steps (login → tournament lookup → seeding
→ round start → round result → player reconcile). On failure see "What can
go wrong?" below.

## Deployment topology

The bridge works in three topologies — from the app's perspective the only
thing that changes is the base URL:

| Topology | Example | App base URL |
|----------|---------|--------------|
| **Local at the venue** | carambus_bcw at the clubhouse, app on iPad in the same Wi-Fi | `http://carambus.local:3000` |
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

### "422 TableMonitor not found for table_no=N"

On round start: Carambus cannot find a table with `Table.name == "N"` in
the tournament's location. Fix: the Sportwart checks the tables in the
Carambus admin UI — either create tables with the names the app expects
(typically `"1"`, `"2"`, …) or adjust the app's convention.

### "422 Player not resolved"

On round start: a player match failed. Carambus tries the following
fallback chain:

1. Region + ClubCloud ID
2. DBU membership number
3. First name + last name (optional + club)

Fix: the Sportwart creates the unknown player manually in the CC UI
(first name, last name, club) and the app retries the round start.

## Pilot story

BC Wedel 3-cushion team championship 2026-05-17 — first application of the
bridge with the 3BandMannschaftsTurnier app on iPad in the clubhouse Wi-Fi
against a local `carambus_bcw` scenario.

Status: live roundtrip validation with the app is pending (depending on the
next tournament opportunity; the technical smoke-test substrate is in
place).

## Related docs

- [Developer docs — Technical details and mapping tables](../developers/external-tournament-bridge.md)
- [API reference — Full endpoint specification](../reference/api.md)
- [ClubCloud MCP setup service (the Sportwart-side counterpart)](clubcloud-mcp-setup-service.md)
