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

!!! warning "Who can walk this path today"
    Step 3.2 fills the database from the **production database of the authority**
    (`api.carambus.de`) and needs SSH access as `www-data` to that server. Currently only the
    Carambus operators have it. A club can do steps 1–2 on its own; for the initial data load it
    (still) needs the operator.

## Prerequisites

### Hardware
- Raspberry Pi 4 or 5. **2 GB RAM works** but is tight (cold start ~3 min until the
  scoreboard); 4 GB or more is recommended
- MicroSD card (at least 16 GB, 32 GB+ recommended)
- Official power supply, monitor (HDMI), keyboard and mouse for the setup
- Network: cable recommended; Wi-Fi works

### Admin computer (Mac or Linux)
- [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
- Any **carambus checkout** (e.g. `~/DEV/carambus/carambus_bcw`) — all rake tasks run from it;
  no dedicated "master" checkout is needed
- The **scenario checkout** `~/DEV/carambus/<scenario>` (Rails root of the scenario, Capistrano
  deploys from here) — keep it **up to date**: `git -C ~/DEV/carambus/<scenario> pull --ff-only`
- `~/DEV/carambus/carambus_data` (scenario `config.yml`, `secrets.yml`)
- `~/DEV/ansible` (inventory and playbooks for steps 1–2)
- `~/DEV/carambus/carambus_app`, if the scenario sets `serve_tournament_app: true`
- Local PostgreSQL with `carambus_api_development`
- SSH key (`~/.ssh/id_rsa.pub`)

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

```yaml
scenario:
  name: carambus_pbv
  location_id: 2368          # the club's location at the authority
  region_id: 1
  club_id: 3285

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

### 3.2 Run the deployment

All commands from a carambus checkout, in **this order**:

```bash
cd ~/DEV/carambus/carambus_bcw

# 1. Configs, directories, Redis, Puma service, nginx, /etc/<basename>.env   (~1 min)
bin/rails "scenario:prepare_deploy[carambus_pbv]"

# 2. Derive the development database on the admin computer from the authority   (~4 min)
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

What you need to know:

- **Step 2** compares the local `carambus_api_development` with the authority's production and
  **replaces it** if newer data exists there (backed up first, the backup is deleted afterwards) —
  this affects every checkout that uses the same database. The log shows many
  `ERROR: role "www_data" does not exist` and `invalid command \restrict` lines — both are
  expected, the task still reports ✅.
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
