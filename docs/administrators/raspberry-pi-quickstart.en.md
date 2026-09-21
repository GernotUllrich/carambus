# Quick Start: Raspberry Pi Scoreboard Installation

From an empty SD card to a full-screen scoreboard — the way it was actually walked on
2026-09-10/11 on a fresh Raspberry Pi (Pi 5, 2 GB RAM, Raspberry Pi OS 13 "trixie"). Every step
below ran during that walk; where it did not go smoothly, it says so.

## Overview

The setup has two parts:

1. **System** (steps 1–2): Raspberry Pi OS, hardening, Ruby, PostgreSQL, nginx — with **one**
   Ansible run. Measured: just over 60 minutes, mostly package updates.
2. **Application** (steps 3–4): Carambus, database, Redis, Puma and the scoreboard kiosk — with a
   few rake tasks from the admin computer. Measured: about 15 minutes of run time.

Afterwards the Pi boots straight into the scoreboard. From power-on this takes about
**3 minutes** (desktop after about 1 minute) — the Pi is not broken during that time.

!!! note "What a club needs from the operator"
    Only once: the **region dump credentials** for its region (login and password, see 3.1). With them,
    step 3.2 fills the database from the authority's [region dump](region-dumps.md) (`api.carambus.de`),
    without SSH access to it. Everything else, including the credentials, the club does itself.

## Prerequisites

### Hardware
- Raspberry Pi 4 or 5. **2 GB RAM works** but is tight (cold start ~3 min until the
  scoreboard); 4 GB or more is recommended
- MicroSD card (at least 16 GB, 32 GB+ recommended)
- Official power supply, monitor (HDMI), keyboard and mouse for the setup
- Network: cable recommended; Wi-Fi works

### Admin computer (Mac or Linux)

Windows is not enough. You need on that machine:

- [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
- **Ruby 3.2.1** (e.g. via `rbenv`) and **Bundler** — the rake tasks below are `bin/rails` calls
  and run inside the carambus checkout; run `bundle install` there once
- **Ansible** for steps 1–2
- **Local PostgreSQL**
- An **SSH key** (`~/.ssh/id_rsa.pub`), **registered with GitHub** — the scenario tooling clones
  over SSH (`lib/tasks/scenarios.rake:2541`), even though the carambus repository is public

### The three directories

!!! warning "Two of them are not public"
    `carambus_data` and `ansible` are private repositories. Today a club can only get them
    **from the operator**. The installation does not work without them — that is the current
    state, not a formality.

| Directory | Contents | Where from |
|---|---|---|
| `~/DEV/carambus/<scenario>` | Rails root of your own scenario; Capistrano deploys from here and all rake tasks run from it | public: `git clone git@github.com:GernotUllrich/carambus.git ~/DEV/carambus/<scenario>` |
| `~/DEV/carambus/carambus_data` | scenario `config.yml`, `secrets.yml`, credentials of all scenarios | **not public** — ask the operator |
| `~/DEV/ansible` | inventory, playbooks and the `RUNBOOK` for steps 1–2 | **not public** — ask the operator |

No dedicated "master" checkout is needed; the scenario checkout covers everything.
Keep it **up to date**: `git -C ~/DEV/carambus/<scenario> pull --ff-only`

### Tip: speed up SSH to `*.local`
Via mDNS the Pi also announces its public IPv6 addresses; the firewall does not let SSH through
there, so every connection waits ~20 s before falling back to IPv4. Fix in `~/.ssh/config` on the
admin computer:

```
Host *.local
    AddressFamily inet
```

## Steps 1–2: Set up the Pi (system)

This part is documented completely in the Ansible repo: **`~/DEV/ansible/RUNBOOK`, section "NEUEN
CARAMBUS-PI AUFSETZEN"**. In short:

1. Add the section `environments.production.ansible` to
   `carambus_data/scenarios/<scenario>/config.yml`, add the Pi to `~/DEV/ansible/hosts`
   (including group `[carambus_pi]`), run `bin/rails "scenario:generate_host_vars[<scenario>]"`
2. Write the SD card with Raspberry Pi Imager: hostname `<name>`, user with password,
   **tick SSH every time**, public key `~/.ssh/id_rsa.pub`
3. Boot the Pi; if it still shows up as `raspberrypi`, reboot once
4. Pre-check: `ssh -4 <user>@<name>.local true` must succeed without a password
   (otherwise `ssh-copy-id <user>@<name>.local`)
5. One run:
   `cd ~/DEV/ansible && ansible-playbook -i hosts master.yml --limit <name> -K`

Result: SSH only on port 8910 as `www-data`, firewall only 3131 + 8910, Ruby 3.2.1 (rbenv),
Node 20, PostgreSQL, nginx. The group `[carambus_pi]` keeps ClamAV and SpamAssassin from being
installed — on a 2 GB Pi they would otherwise take half the memory.

## Step 3: Deploy the application

### 3.1 Configure the scenario

The configuration lives in `carambus_data/scenarios/<scenario>/config.yml`. There is no template
directory — an existing scenario (e.g. `carambus_pbv`) serves as the pattern. The fields that
matter for the Pi:

!!! tip "Looking up your own IDs"
    `location_id`, `club_id` and `region_id` are the IDs **on the Authority**. They appear in the
    address bar of the corresponding overview page, which is readable without signing in:

    - Region: <https://api.carambus.de/regions> → e.g. `…/regions/1` ⇒ `region_id: 1`
    - Club: <https://api.carambus.de/clubs> → e.g. `…/clubs/3285` ⇒ `club_id: 3285`
    - Location: <https://api.carambus.de/locations> → e.g. `…/locations/2368` ⇒ `location_id: 2368`

    If your club or location is **not** listed there, it must first be created on the Authority —
    one of the three things a club needs the operator for. Otherwise the example values below
    leave your server pointing at someone else's club.

```yaml
scenario:
  name: carambus_pbv
  location_id: 2368          # the club's location at the authority
  region_id: 1
  club_id: 3285
  region_shortname: NBV      # optional; otherwise `context`, otherwise `region_id` (see 3.1 below)

environments:
  production:
    webserver_host: carambus-pbv.local   # device name, not an IP address
    ssh_host: carambus-pbv.local
    webserver_port: 3131
    ssh_port: 8910
    # smtp_enabled: false               # only if the server must not send mail
    raspberry_pi_client:
      enabled: true
      ip_address: carambus-pbv.local     # the device name here too
      ssh_user: www-data
      ssh_port: 8910
      kiosk_user: gullrich               # the user created in the Imager (autologin)
      local_server_enabled: true
      local_server_port: 3131
      autostart_enabled: true
```

The application blocks access by IP address (Rails `config.hosts` only allows the names from the
configuration) — so always use `http://<name>.local:3131` in the browser.

**Tournament app:** if the server is to serve the [tournament app](../managers/tournament-app.md) under `/app/`,
add `serve_tournament_app: true` under `scenario:`. The app files ship with the deploy; no separate repository is
needed. The app's service account: [tournament app, prerequisites](../managers/tournament-app.md#voraussetzungen).

**Mail sender:** in production Puma only starts with SMTP credentials (otherwise
`config/initializers/smtp_guard.rb` aborts the start — nginx then reports *502 Bad Gateway*). The
credentials belong in `carambus_data/secrets.yml` (not versioned):

```yaml
shared:
  smtp:
    username: "...@gmail.com"
    password: "..."          # Gmail: app password, not the account password
```

`prepare_deploy` creates `/etc/<basename>.env` on the Pi from it. A server without mail sets
`smtp_enabled: false` instead (see above).

**Credentials:** every server gets its own key and its own secrets. For a new scenario, once:

```bash
NEW_KEY=true bin/rails "scenario:generate_credentials[carambus_pbv]"              # dry run
WRITE=true NEW_KEY=true bin/rails "scenario:generate_credentials[carambus_pbv]"   # create
```

This creates `production.key` (mode 600) and `production.yml.enc` under
`carambus_data/scenarios/<scenario>/production/credentials/`. The file holds its own `secret_key_base`, its own
JWT secret and its own keys for database encryption. Feature keys (AI, translation, Google service account,
ClubCloud) are only included if they are in the `secrets.yml` of the `carambus_data` the command runs from.
`prepare_deploy` uploads both files and aborts without them.

!!! warning "Back up `production.key`"
    `carambus_data` does not version the key. If it is lost, `production.yml.enc` and every encrypted field in
    the database can no longer be read.

**Region dump access:** the operator issues login and password for the club's region once
([region dumps, access](region-dumps.md#access)). They belong in `carambus_data/secrets.yml`:

```yaml
per_scenario:
  carambus_pbv:
    region_dump:
      login: carambus-pbv
      password: "..."
```

Which region is loaded follows from `config.yml` (`region_shortname`, otherwise `context`, otherwise
`region_id`).

### 3.2 Run the deployment

All commands from a carambus checkout, in **this order**:

```bash
cd ~/DEV/carambus/carambus_bcw

# 1. Configs, directories, Redis, Puma service, nginx, /etc/<basename>.env   (~1 min)
bin/rails "scenario:prepare_deploy[carambus_pbv]"

# 2. Development database on the admin computer from the region dump          (~30 s)
bin/rails "scenario:prepare_development[carambus_pbv,development]"

# 3. Put the production database on the Pi — DESTRUCTIVE                      (~1 min)
bin/rails "scenario:reset_server_db[carambus_pbv]"

# 4. Application via Capistrano                                               (~9 min)
bin/rails "scenario:deploy[carambus_pbv]"

# 5. Set up, deliver and test the kiosk                                        (<1 min each)
bin/rails "scenario:setup_raspberry_pi_client[carambus_pbv]"
bin/rails "scenario:deploy_raspberry_pi_client[carambus_pbv]"
bin/rails "scenario:test_raspberry_pi_client[carambus_pbv]"
```

Then create the first admin on the Pi:

```bash
ssh -p 8910 www-data@carambus-pbv.local
cd /var/www/carambus_pbv/current && RAILS_ENV=production bundle exec rake "users:create_admin[<email>]"
```

The command creates a confirmed `system_admin` and prints the password exactly once. Change it under "Profile"
after the first login. This admin creates further users. The tournament app's service account is described under
[tournament app, prerequisites](../managers/tournament-app.md#voraussetzungen).

!!! warning "Write the password down immediately"
    The command is **not repeatable**: a second run with the same address aborts with
    "Benutzer … gibt es schon — nichts geändert" and prints **no** new password
    (`lib/local_accounts.rb:34`). If the server runs with `smtp_enabled: false`, there is no
    "forgot password" by email either.

    **If the password is lost:** run the same command with a **different** email address. That
    creates a second administrator who can then fix or delete the first one in the user
    administration.

What you need to know:

- **Step 2** downloads the region's dump via HTTPS, checks it against its checksum and loads it as
  `<scenario>_development`. The dump contains no users. The step creates the scoreboard account itself; the
  first admin comes after the deploy (see above). The ~30 s were measured with dependencies already installed;
  on the first run on an admin computer the step installs them first. Without `region_dump` in `secrets.yml`
  it takes the [operator path](installation-overview.md#operator-path) via SSH to the authority.
- If the Pi already has local data (id ≥ 50 million), step 2 backs it up from the Pi first and loads it back
  afterwards.
- **Step 3** is marked DESTRUCTIVE: it drops the production database on the Pi and loads it
  again. A fresh Pi has none yet. Without step 2 it aborts with
  `ActiveRecord::NoDatabaseError … carambus_pbv_development` — then run step 2, not `db:create`.
- **Step 1** may be repeated; an existing `/etc/<basename>.env` is never overwritten.
- `deploy_raspberry_pi_client` restarts the kiosk — kiosk changes take effect immediately.

## Step 4: Verify the installation

### 4.1 Web interface

In the browser on the admin computer: `http://<name>.local:3131`

From the command line (the browser user agent is needed if the nginx bot block is active —
otherwise `curl` gets a 403):

```bash
curl -s -o /dev/null -w "%{http_code}\n" -A "Mozilla/5.0" http://carambus-pbv.local:3131/
```

### 4.2 Scoreboard on the Pi

The monitor shows the scoreboard **full screen**, without the desktop. After power-on this takes
about 3 minutes (Puma preloads the application, then Chromium starts).

### 4.3 Services

```bash
ssh -p 8910 www-data@carambus-pbv.local \
  'systemctl is-active puma-carambus_pbv redis-server nginx scoreboard-kiosk'
ssh -p 8910 www-data@carambus-pbv.local 'sudo journalctl -u scoreboard-kiosk -n 30'
ssh -p 8910 www-data@carambus-pbv.local 'sudo tail -50 /tmp/chromium-kiosk.log'
```

The kiosk log belongs to the kiosk user — as `www-data` it is only readable with `sudo`.

## Operating the kiosk

- **Raspberry Pi OS 13 ("trixie", desktop labwc):** Chromium runs in kiosk mode. The button on the
  welcome page does **not** lead to the desktop there. To work on the desktop, stop the kiosk and
  start it again afterwards:
  ```bash
  ssh -p 8910 www-data@carambus-pbv.local 'sudo systemctl stop scoreboard-kiosk'
  ssh -p 8910 www-data@carambus-pbv.local 'sudo systemctl start scoreboard-kiosk'
  ```
  If Chromium exits (crash, Alt+F4), the kiosk restarts by itself after a few seconds.
- **Raspberry Pi OS 12 ("bookworm", desktop wayfire):** full screen via `--start-fullscreen`; the
  button on the welcome page toggles full screen.

## Troubleshooting

#### 502 Bad Gateway after the deploy
Puma does not start. Most common cause: `/etc/<basename>.env` is missing.
```bash
ssh -p 8910 www-data@carambus-pbv.local 'sudo journalctl -u puma-carambus_pbv -n 40 --no-pager'
```
If it says `FATAL: SMTP-ENV nicht gesetzt`: add the SMTP credentials to `secrets.yml` (see 3.1) and
run `prepare_deploy` again — Puma then starts by itself.

#### Scoreboard not full screen
Run `deploy_raspberry_pi_client` again (restarts the kiosk with the current script). The desktop
session is set in `/etc/lightdm/lightdm.conf` (`user-session=`).

#### Pi is very slow
Check memory: `ssh -p 8910 www-data@<name>.local 'free -m'`. If ClamAV/SpamAssassin are running
(`systemctl is-active clamav-daemon spamd`) because the Pi was not in `[carambus_pi]`:
```bash
ssh -p 8910 www-data@<name>.local \
  'sudo systemctl disable --now clamav-daemon clamav-daemon.socket clamav-freshclam spamd'
```

## Management Commands

**Restart the scoreboard browser:**
```bash
bin/rails "scenario:restart_raspberry_pi_client[carambus_pbv]"
```

**Restart the Rails application:**
```bash
ssh -p 8910 www-data@carambus-pbv.local 'sudo systemctl restart puma-carambus_pbv'
```

**View application logs:**
```bash
ssh -p 8910 www-data@carambus-pbv.local 'tail -f /var/www/carambus_pbv/shared/log/production.log'
```

**Update application code:**
```bash
bin/rails "scenario:deploy[carambus_pbv]"
```

**Reboot the Raspberry Pi:**
```bash
ssh -p 8910 www-data@carambus-pbv.local 'sudo reboot'
```

## Advanced Configuration

*The following sections were not walked during the run on 2026-09-11.*

### Custom Port Configuration

Edit `config.yml` to change ports:
```yaml
environments:
  production:
    webserver_port: 3131  # Change to your preferred port
    ssh_port: 8910        # Change SSH port if needed
```

### Multiple Locations

For multiple tables/locations in one club:
```yaml
scenario:
  location_id: 1  # First table
  
# Create separate scenarios for each table:
# - carambus_bcw_table1
# - carambus_bcw_table2
# - carambus_bcw_table3
```

### Headless Setup (No Monitor)

For remote-only access without kiosk mode:
```yaml
raspberry_pi_client:
  enabled: false  # Disable kiosk mode
```

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│         Raspberry Pi (All-in-One)               │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │   Kiosk (autologin user from Imager)    │   │
│  │   - Chromium, full screen               │   │
│  │   - Systemd service: scoreboard-kiosk   │   │
│  └─────────────────────────────────────────┘   │
│                      ↓ HTTP (localhost:3131)    │
│  ┌─────────────────────────────────────────┐   │
│  │   Web server                            │   │
│  │   - nginx (port 3131)                   │   │
│  │   - Puma: puma-<basename>               │   │
│  │   - Redis (ActionCable)                 │   │
│  └─────────────────────────────────────────┘   │
│                      ↓                          │
│  ┌─────────────────────────────────────────┐   │
│  │   PostgreSQL                            │   │
│  │   - <basename>_production               │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Success Checklist

- [ ] `ssh -p 8910 www-data@<name>.local` works
- [ ] `http://<name>.local:3131` answers in the browser
- [ ] `puma-<basename>`, `redis-server`, `nginx`, `scoreboard-kiosk` are active
- [ ] Scoreboard full screen on the monitor
- [ ] After a reboot the scoreboard comes up by itself (after ~3 min)
- [ ] Touch input works (with a touch display)

## Support

GitHub Issues: https://github.com/GernotUllrich/carambus/issues

---

**Last updated:** 2026-09-11 (walked on fresh hardware, carambus_bcw plan 15-03)
**Tested on:** Raspberry Pi 5 (2 GB), Raspberry Pi OS 13 "trixie" (64-bit, desktop labwc)
**Previous version (October 2025):** listed Pi 4/5 and bookworm/trixie, but was never walked on a
fresh Pi
