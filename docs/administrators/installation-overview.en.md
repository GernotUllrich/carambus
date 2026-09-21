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
  `carambus_data/scenarios/<scenario>/production/credentials/`. A new scenario creates them itself:
  `WRITE=true NEW_KEY=true bin/rails "scenario:generate_credentials[<scenario>]"` (own key, own secrets;
  a dry run without `WRITE=true`). `prepare_deploy` uploads them and aborts without them. Details:
  [Raspberry Pi Quickstart](raspberry-pi-quickstart.md), section 3.1.

- **Region dump access**: login and password for your own region, requested once from the operator. They go
  into `secrets.yml`:

    ```yaml
    per_scenario:
      <scenario>:
        region_dump:
          login: <login>
          password: "<password>"
    ```

    With it, `prepare_development` loads the database from the Authority's [region dump](region-dumps.md),
    **without** SSH access to the Authority.

- **Two non-public repositories**: `carambus_data` (scenario configuration, `secrets.yml`) and
  `ansible` (inventory, playbooks, the `RUNBOOK` for step 0) are private. Today a club can only get
  them from the operator, and the installation does not work without them. Details:
  [Raspberry Pi Quickstart](raspberry-pi-quickstart.md#the-three-directories).

!!! info "Where a club needs the operator today"
    In three places: for the **region dump credentials**, for the two **private repositories**
    above, and when its **club or location does not yet exist on the Authority**. Everything else
    — setting up the system, deploying, configuring the kiosk, creating the admin — works without
    them.

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

# 2. Create the development database on the admin machine from the region dump
bin/rails "scenario:prepare_development[<scenario>,development]"

# 3. Bring the production database onto the server: DESTRUCTIVE
bin/rails "scenario:reset_server_db[<scenario>]"

# 4. Application via Capistrano
bin/rails "scenario:deploy[<scenario>]"
```

Then create the first admin on the server:

```bash
cd /var/www/<basename>/current && RAILS_ENV=production bundle exec rake "users:create_admin[<email>]"
```

What you need to know:

- **Step 2** downloads the region dump of your own region, checks it against its checksum and loads it as
  `<scenario>_development`. The step creates the scoreboard account itself, because the dump contains no
  users. Without `region_dump` in `secrets.yml` it takes the [operator path](#operator-path).
- **Step 3** drops the production database on the server and reloads it from `<scenario>_development`.
  `prepare_deploy` does not set up a database; only this step does.
- **`users:create_admin`** creates a confirmed `system_admin` and prints its password exactly once.
- For the scoreboards, `setup_raspberry_pi_client`, `deploy_raspberry_pi_client` and
  `test_raspberry_pi_client` follow; see the [Quickstart](raspberry-pi-quickstart.md), step 3.2.

#### Operator path (without region dump access) {#operator-path}

If `secrets.yml` has no `region_dump` for the scenario, step 2 syncs the local `carambus_api_development`
via SSH as `www-data` with the Authority's production and derives the database from it. Only the Carambus
operators have this access. The local `carambus_api_development` is **replaced** if newer data exists on the
Authority. This affects every checkout using the same database. The messages
`ERROR: role "www_data" does not exist` and `invalid command \restrict` in the log are expected on this path.

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
