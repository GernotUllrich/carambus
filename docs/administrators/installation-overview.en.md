# 🚀 Installation Overview

## 📋 Available Installation Guides

### 🎯 Raspberry Pi Quickstart (Recommended)
**[Raspberry Pi Quickstart](raspberry-pi-quickstart.md)**: the path walked on fresh hardware on 2026-09-11, from an
empty SD card to a full-screen scoreboard. This page summarises it; the details are there.

### 🧰 Scenario Management
**[Scenario Management](../developers/scenario-management.md)**: the deployment system behind every Carambus
instance. Each instance is a **scenario** with its own `config.yml` under `carambus_data/scenarios/<scenario>/`.

**Examples from the current setup:**
- **carambus_api**: the Authority (`api.carambus.de`)
- **carambus**: the public server `carambus.de`
- **carambus_bcw**, **carambus_pbv**, **carambus_phat**: club servers (Raspberry Pi in the club room)

**What Scenario Management takes care of:**
- ✅ Configs from a single `config.yml` (plus `secrets.yml`)
- ✅ Puma service, nginx, Redis and `/etc/<basename>.env` on the server
- ✅ Deployment via Capistrano
- ✅ Sequence management for local data

## 🏗️ Architecture Overview

### Production Scenarios
1. **Authority** (`carambus_api`)
   - Central data source for all local servers (global records, version sync)
   - Domain: api.carambus.de, path `/var/www/carambus_api`, `cap_role: api`
   - Deployed by the operator

2. **Local Server** (e.g. `carambus_pbv`)
   - Server for a club's tournaments, games and scoreboards
   - Fetches global data from the Authority; local data stays on the server
   - `cap_role: local`, path `/var/www/<basename>`

### Development Mode
- Each scenario has its own Rails root `~/DEV/carambus/<scenario>`
- The rake tasks run from any up-to-date carambus checkout

## 🔑 Important Configurations

### Standard Account
- **User**: `www-data` (uid=33, gid=33)
- **Home Directory**: `/var/www`
- **SSH Port**: 8910
- **Sudo**: Via `wheel` group

### Installation Paths
- **Application**: `/var/www/<basename>` (Capistrano: `releases/`, `shared/`, `current`)
- **Service secrets**: `/etc/<basename>.env` (mode 600, root)

## ✅ Prerequisites

- **System**: The server has been set up with Ansible (see step 0).
- **Scenario configuration**: `carambus_data/scenarios/<scenario>/config.yml`, with `cap_role: local` for
  a club server.
- **`carambus_data/secrets.yml`** (not versioned):
  - `shared.database_password` for the database role
  - `shared.smtp` (`username`, `password`). Without SMTP credentials `prepare_deploy` aborts. A server
    without mail sets `smtp_enabled: false` in `config.yml` instead.
- **Credentials**: `production.key` and `production.yml.enc` under
  `carambus_data/scenarios/<scenario>/production/credentials/`. `prepare_deploy` uploads them and aborts
  without them.

!!! warning "Open questions for a new club"
    - **Initial database load:** `prepare_development` fetches the global data via SSH as `www-data` from
      the Authority's production database (`api.carambus.de`). Currently only the Carambus operators
      have this access.
    - **`production.key`:** No task creates it, and `carambus_data` does not version it. How a new club
      obtains its key is not settled yet.

    A club can set up the system (step 0) on its own; for the application it currently (still) needs the
    operator.

## 🚀 Quick Start

### 0. Set up the system
Raspberry Pi via Ansible: **`~/DEV/ansible/RUNBOOK`, section "NEUEN CARAMBUS-PI AUFSETZEN"**, a single run
of `master.yml`. The `host_vars` are generated from `config.yml` with
`bin/rails "scenario:generate_host_vars[<scenario>]"`. Details: [Raspberry Pi Quickstart](raspberry-pi-quickstart.md),
steps 1–2.

### 1. Create the scenario
There is no template directory. Copy the `config.yml` of an existing scenario (e.g.
`carambus_data/scenarios/carambus_pbv/config.yml`) to `carambus_data/scenarios/<scenario>/` and adapt it:
`name`, `basename` (= scenario name), `location_id`, `club_id`, `region_id`, hosts and `cap_role: local`.
The fields are listed in the [Quickstart](raspberry-pi-quickstart.md), section 3.1.

!!! note "Not recommended: `scenario:create` and `scenario:create_rails_root`"
    `scenario:create` currently writes a `config.yml` whose `basename` does not match the Rails root and
    which lacks `cap_role`. Without `cap_role` the scenario counts as the Authority, and the Authority's
    cron jobs would run on the club server. `create_rails_root` deletes an existing
    `~/DEV/carambus/<scenario>` without asking. `prepare_development` creates the Rails root itself when
    needed.

### 2. Deploy the application
All commands from a carambus checkout, in **this order**:

```bash
# 1. Configs, directories, Redis, Puma service, nginx, /etc/<basename>.env on the server
bin/rails "scenario:prepare_deploy[<scenario>]"

# 2. Derive the development database on the admin machine from the Authority
bin/rails "scenario:prepare_development[<scenario>,development]"

# 3. Bring the production database onto the server: DESTRUCTIVE
bin/rails "scenario:reset_server_db[<scenario>]"

# 4. Application via Capistrano
bin/rails "scenario:deploy[<scenario>]"
```

What you need to know:

- **Step 2** compares the local `carambus_api_development` with the Authority's production and
  **replaces it** if newer data exists there. This affects every checkout using the same database. The
  messages `ERROR: role "www_data" does not exist` and `invalid command \restrict` in the log are
  expected.
- **Step 3** drops the production database on the server and reloads it from `<scenario>_development`.
  `prepare_deploy` does not set up a database; only this step does.
- For the scoreboards, `setup_raspberry_pi_client`, `deploy_raspberry_pi_client` and
  `test_raspberry_pi_client` follow; see the [Quickstart](raspberry-pi-quickstart.md), step 3.2.

### 3. SSL
Scenario Management does not issue certificates. With `ssl_enabled: true` the certificate must already
be on the server before `prepare_deploy` (e.g. via `bin/issue-letsencrypt-cert.sh`), otherwise `nginx -t`
fails. Club servers in the club room run without SSL on port 3131.

## 📖 Further Documentation

- **[Raspberry Pi Quickstart](raspberry-pi-quickstart.md)**: the walked path, step by step
- **[Scenario Management](../developers/scenario-management.md)**: Complete deployment guide
- **[Developer Guide](../developers/developer-guide.md)**: Developer documentation
- **[API Documentation](../reference/api.md)**: API reference

## 🆘 Support

If you have problems (on the server):
1. Application log: `tail -f /var/www/<basename>/shared/log/production.log`
2. Services: `systemctl is-active puma-<basename> redis-server nginx` (on the Pi also `scoreboard-kiosk`)
3. Puma log: `sudo journalctl -u puma-<basename> -n 40 --no-pager`
4. Most common cause of *502 Bad Gateway*: `/etc/<basename>.env` is missing, see
   [Quickstart, Troubleshooting](raspberry-pi-quickstart.md#troubleshooting)

---

**🎯 Goal**: A traceable installation of Carambus via Scenario Management, backed by the walked path of
the Quickstart.
