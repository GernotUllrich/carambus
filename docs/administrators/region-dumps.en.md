# Region Dumps

A new club server needs an initial data set: clubs, players, venues, tournaments and leagues of its region. After that
it keeps itself up to date through the version sync. The Authority (`api.carambus.de`) builds this initial data set
**every night for every region** as a file. A club downloads it with credentials the operator issues once; it does not
need SSH access to the Authority.

!!! note "Loading"
    `scenario:prepare_development` downloads and checks the dump as soon as the credentials are in the club's
    `secrets.yml`. The whole path up to the running server is described in the
    [Raspberry Pi Quickstart](raspberry-pi-quickstart.md), step 3.

## What the dump contains — and what it does not

**Included** are the global data of the region:

- clubs, venues, tables, players, tournaments with seedings and games, leagues, teams, match days — filtered to the
  region; records without a region or with `global_context` (e.g. international tournaments) are kept
- all other master data in full (regions, disciplines, tournament plans, seasons …)
- `last_version_id`: the point from which the new server's version sync continues

**Not included** (the Authority cleans these before filtering and checks afterwards that nothing is left):

| What | Why |
|---|---|
| user accounts (`users`, `user_tournaments`) | Authority accounts do not belong on a club server; the first admin is created there |
| ClubCloud logins of the regions (`region_ccs.username/userpw`) | credentials |
| API credentials of international sources | credentials |
| MCP audit trail, AI usage | Authority operating data |
| version history (`versions`) | history with user references; the sync only needs `last_version_id` |
| ClubCloud session in `settings` | session data |

If one of these checks fails, the Authority does **not** publish a dump for that region. The other regions continue.

The master data (clubs with address and e-mail, players, results) comes from the federation sources. That is why the
download requires credentials.

## How it runs on the Authority

A cron job builds all regions at 1:00 am (`config/schedule.rb`, `roles: [:api]` only):

```bash
bundle exec rake "region_dump:build[all]"
```

1. A snapshot of the production database — data and `last_version_id` come from the same state, even if new versions are
   written during the run.
2. A cleaned base copy without version data.
3. Per region: a copy of it, the region filter `cleanup:remove_non_region_records`, the checks, `pg_dump`.

Build single regions with `region_dump:build[NBV]`, several separated by spaces: `region_dump:build[NBV BVW]` (rake splits
arguments at commas). Regions with at least one club and an upper-case short name are built, currently 17. Measured
locally, a run over all regions takes about 5 minutes; a dump is 17–32 MB.

Location: `/var/www/carambus_api/shared/region_dumps/<REGION>/`

| File | Content |
|---|---|
| `latest.sql.gz` | link to the newest dump |
| `latest.json` | manifest: `region`, `file`, `created_at`, `last_version_id`, `schema_version`, `size`, `sha256` |
| `carambus_<region>_<timestamp>.sql.gz` | the dumps; the two newest per region are kept |
| `filter.log` | output of the region filter (not served) |

## Granting and revoking access {#access}

Access is per region. On the Authority:

```bash
bundle exec rake "region_dump:grant[NBV,bc-wedel]"    # new password, shown only once
bundle exec rake "region_dump:revoke[NBV,bc-wedel]"   # revoke access
bundle exec rake region_dump:list                      # regions and logins
```

`grant` for an existing login renews the password. Only an apr1 hash is stored in
`shared/region_dumps/.htpasswd/<REGION>` (mode 640). Logins consist of letters, digits, `.`, `_`, `-`.

Download by the club (curl asks for the password):

```bash
curl -fu bc-wedel -O https://api.carambus.de/region_dumps/NBV/latest.json
curl -fu bc-wedel -o carambus_nbv.sql.gz https://api.carambus.de/region_dumps/NBV/latest.sql.gz
shasum -a 256 carambus_nbv.sql.gz     # must match sha256 in latest.json
```

Without credentials the server answers 401; with the credentials of another region the download is refused: with
401 if access has already been granted for that region, otherwise with 403 (nginx finds no access file). This 403 has
nothing to do with the bot block.

## Setup on the Authority (once)

The Authority's nginx configuration is maintained by hand; the dump access is added as a separate snippet:

```bash
sudo cp templates/nginx/carambus_region_dumps.conf /etc/nginx/snippets/
sudo cp templates/nginx/carambus_bot_block.conf /etc/nginx/conf.d/
```

The `server` block for port 443 of `/etc/nginx/sites-available/carambus_api` must contain the line
`include snippets/carambus_region_dumps.conf;`. The template `templates/nginx/nginx_conf.erb` generates it for
scenarios with `cap_role: api`; a hand-maintained config must still contain it — without it, `/region_dumps/`
only returns 404. Then:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

The updated bot-block file exempts `/region_dumps/` from the rejection of `curl` — otherwise the download would get 403.
On club servers the exemption has no effect, there are no dumps there.

!!! warning "Version sync without login"
    `/versions/get_updates` on the Authority is still reachable without login. It only serves the more recent versions,
    not the full data set — the dump remains the only complete state. Securing the sync is a separate item.
