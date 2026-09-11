# Server Management Scripts

This documentation describes the scripts in `bin/` for managing Carambus servers
(Development, Production, API) — what they actually do today and which of them are legacy.

!!! info "Setting up a server"
    A new server is not set up with a script from `bin/` but with Ansible
    (`~/DEV/ansible/RUNBOOK`, section "NEUEN CARAMBUS-PI AUFSETZEN") followed by the rake tasks of the
    [Raspberry Pi quickstart](raspberry-pi-quickstart.md). This page covers operation.

## Overview

The scripts live in `bin/` of every Carambus checkout (`carambus_bcw`, `carambus_api`, …) and run from
any up-to-date checkout; `bin/lib/carambus_env.sh` resolves paths relative to the script. The examples
below use placeholders:

| Placeholder | Meaning | Source |
|---|---|---|
| `<scenario>` | Scenario name, e.g. `carambus_pbv` | `carambus_data/scenarios/<scenario>/` |
| `<basename>` | Name of the deployment on the server (service `puma-<basename>`, `/var/www/<basename>`) | `config.yml`, `scenario.basename` |
| `<server>`, `<ssh_port>` | SSH target of the server (Pis: `<name>.local`, port 8910) | `config.yml`, `environments.production` |

The areas:
- **Development Server**: Start the local development environment
- **Production Server**: Manage the `puma-<basename>` service
- **Rails Console**: Database access and debugging
- **Asset Management**: Rebuild JavaScript/CSS, cleanup
- **Deployment**: Get code onto the server
- **Legacy**: Scripts that are still in `bin/` but no longer fit today's path

---

## Development Server

Start a scenario checkout with the standard Rails tools:

```bash
cd ~/DEV/carambus/<scenario>
bin/rails server -p <port>

# For JavaScript/CSS changes, additionally (as in Procfile.dev):
yarn build --watch
yarn build:css --watch
```

**Requirement**: The development database has been created with `prepare_development` (see
[Start a local development session](#start-a-local-development-session)).

The scripts `start-api-server.sh`, `start-local-server.sh` and `start-both-servers.sh` belong to the
former API/LOCAL mode and take no scenario — see [Legacy](#legacy).

---

## Production Server Management

On the server the application runs as the systemd service `puma-<basename>` (template
`templates/puma/puma.service.erb`, `Restart=always`). The direct way is `systemctl`:

```bash
ssh -p <ssh_port> www-data@<server> 'sudo systemctl status puma-<basename>'
ssh -p <ssh_port> www-data@<server> 'sudo systemctl restart puma-<basename>'
ssh -p <ssh_port> www-data@<server> 'sudo systemctl stop puma-<basename>'
```

### `manage-puma.sh`
**Purpose**: Reload or start Puma — this is how Capistrano calls it during a deploy
(`manage-puma.sh <basename>`, `config/deploy.rb`).

**Usage**:
```bash
# On the server, from the deployment directory (basename is taken from the path):
cd /var/www/<basename>/current && ./bin/manage-puma.sh

# Or with the basename:
/var/www/<basename>/current/bin/manage-puma.sh <basename>
```

**What it does**:
- If `puma-<basename>` is running: `systemctl reload` (sends USR1 to Puma); if the service is not
  running afterwards, a full `restart`
- If the service is not running: `systemctl start`

The first argument is the **basename**, not an action. Calls like `manage-puma.sh restart` or
`manage-puma.sh start` address a service `puma-restart` or `puma-start` and fail.
Use `systemctl` for stop and status (see above).

---

### `manage-puma-api.sh`
**Purpose**: Like `manage-puma.sh`, fixed to the service `puma-carambus_api`

**Usage** (no argument):
```bash
./bin/manage-puma-api.sh
```

If the service is running it is restarted (`restart`), otherwise started.

---

### `puma-wrapper.sh`
**Purpose**: Start script of the `puma-<basename>` service — `ExecStart` in
`templates/puma/puma.service.erb`. Changes to `/var/www/<basename>/current`, initialises rbenv and
starts `bundle exec puma -C /var/www/<basename>/shared/config/puma.rb`.

Do not call it by hand; Puma is controlled through the service.

---

## Rails Console

There is no dedicated console wrapper script. Use the standard Rails console
(`bin/rails console`) in the respective scenario or API directory.

### Local / API Console (Development)

**Usage**:
```bash
# In the API checkout
cd ~/DEV/carambus/carambus_api
bin/rails console

# In a scenario checkout
cd ~/DEV/carambus/<scenario>
bin/rails console
```

**Example Session**:
```ruby
> Player.count
=> 69082

> Version.last.id
=> 12227261

> Setting.key_get_value("last_version_id")
=> 12227261

# Check local data (records with id >= 50_000_000 are local)
> Game.where('id > 50000000').count
=> 28

> TableLocal.count
=> 10
```

### Production Console

**Usage**:
```bash
# SSH into the production server, then open the console in the deployment directory
ssh -p <ssh_port> www-data@<server>
cd /var/www/<basename>/current
RAILS_ENV=production bundle exec rails console
```

**⚠️ WARNING**: Production console! Be careful with changes!

**Example**:
```ruby
> Rails.env
=> "production"

> Game.count
=> 280163
```

**Best Practice**:
- Never perform destructive operations without backup
- Only read operations for debugging
- For changes: Create migration

---

## Asset Management

### `rebuild_js.sh`
**Purpose**: Quickly rebuild JavaScript in the local checkout

**Usage** (in the checkout):
```bash
cd ~/DEV/carambus/<scenario>
./bin/rebuild_js.sh
```

**What it does**:
1. Empties `tmp/cache/`
2. `yarn build` (esbuild)

It does not build CSS. For that, run `yarn build:css` as well; for the Sprockets assets
`bin/rails assets:precompile`.

**Local only.** On the server, Capistrano builds the assets itself during the deploy
(`config/deploy.rb`, `deploy:assets:precompile`) — a local rebuild before deploying is not needed.

---

### `cleanup_rails.sh`
**Purpose**: Stop stuck Rails/Puma processes on the **development machine**

**Usage**:
```bash
./bin/cleanup_rails.sh
```

**What it does**:
- `pkill -f "rails s"` and `pkill -f "puma"`
- Removes `tmp/pids/server.pid` and `tmp/pids/puma.pid`

It does **not** clear any cache. **Do not run it on a server:** as `www-data` it kills the running
production Puma there; systemd starts it again, but the scoreboards lose their connection.
`bin/rails tmp:cache:clear` clears the Rails cache.

---

### `cleanup_versions.sh`
**Purpose**: Copies `region_id` and `global_context` from the records into their entries in the
versions table (wrapper around the `version_cleanup:*` tasks)

**Usage** (in the Rails root):
```bash
./bin/cleanup_versions.sh fast     # SQL-based (fast)
./bin/cleanup_versions.sh safe     # via ActiveRecord (slower)
./bin/cleanup_versions.sh stats    # statistics
./bin/cleanup_versions.sh verify   # verification
```

Without an option it shows the help. It deletes no versions; there is no `--dry-run` option
(`Unknown option`, exit 1).

---

## Debug & Testing

There is no single `debug-production.sh` script. For any server the standard tools are enough —
run on the server:

```bash
sudo systemctl status puma-<basename> nginx
sudo journalctl -u puma-<basename> -n 50 --no-pager
ls -la /var/www/<basename>/shared/sockets/
tail -100 /var/www/<basename>/shared/log/production.log
```

### `check-database-states.sh`
**Purpose**: Check current database states for a scenario

**Usage**:
```bash
./bin/check-database-states.sh <scenario>
```

### Server-bound diagnostic scripts

These scripts are hard-wired to particular servers and only usable elsewhere after editing:

| Script | Hard-wired to |
|---|---|
| `diagnose-puma-carambus.sh` | `/var/www/carambus` (server carambus.de) |
| `check-puma-logs.sh` | `/var/www/carambus` |
| `diagnose-socket-issue.sh` | scenario `carambus_bcw` |
| `diagnose-nginx.sh` | API server (`carambus`/`carambus_api`) |

`check-actioncable-status.sh` (in the Rails root) checks `config/cable.yml` and whether Redis is reachable.

---

## Setup & Installation

### Setting up a server

The path is described by the Ansible RUNBOOK (system) and the
[Raspberry Pi quickstart](raspberry-pi-quickstart.md) (application). The Ansible `host_vars` are generated
from the scenario `config.yml`:

```bash
bin/rails "scenario:generate_host_vars[<scenario>]"
```

`carambus-install.sh` and `setup-local-dev.sh` are no longer part of this path — see [Legacy](#legacy).

---

### `generate-ssl-cert.sh`
**Purpose**: Generate a self-signed SSL certificate for development/testing

**Usage**:
```bash
./bin/generate-ssl-cert.sh -n <domain> [-d <days>]
```

The script only takes options (among them `-n`/`--name` for the common name, `-d`/`--days`); a domain
name without `-n` ends with `Unbekannte Option` (unknown option).

**What it does**:
- Generates self-signed certificate
- Creates private key
- Stores in `ssl/` directory

**Use Cases**:
- Local HTTPS testing
- Development with SSL features
- Scoreboard testing with secure connection

**Example**:
```bash
# Certificate for localhost
./bin/generate-ssl-cert.sh -n localhost

# Certificate for custom domain
./bin/generate-ssl-cert.sh -n carambus.local
```

---

## Deployment

There are two ways to ship code changes. Which one fits depends on whether the target server is currently
reachable over SSH. `deploy-scenario.sh` is **not** an update path but meant for rebuilding a scenario.

### `scenario:deploy` — from the admin machine

**Purpose**: Runs `cap production deploy` in the scenario checkout `~/DEV/carambus/<scenario>`; Capistrano
builds the assets on the server and reloads Puma.

**Usage** (from any carambus checkout):
```bash
bin/rails "scenario:deploy[<scenario>]"
```

**Requirement**: The code has been pushed to `origin/master`, and the target server is reachable over
SSH — for servers on a club or company network that usually means being on the same network.

`bin/rails "scenario:quick_deploy[<scenario>]"` is the variant for iterative work: it checks the scenario
checkout for local changes, runs `git pull origin master` there, builds the frontend assets, deploys via
Capistrano and restarts `puma-<basename>`.

### `bin/deploy.sh` — on the server itself

**Purpose**: Replicates the Capistrano steps for execution **on the server**. The server
fetches the code from GitHub itself instead of having it pushed to it.

**Usage** (on the server, **not** with `bundle exec`):
```bash
/var/www/<basename>/current/bin/deploy.sh            # branch master
/var/www/<basename>/current/bin/deploy.sh master     # explicit branch
/var/www/<basename>/current/bin/deploy.sh master abc123   # branch + revision
```

**When**: When the server is not reachable from outside (no port forwarding, no VPN)
or nobody is on the local network. Then this is the only way.

**Requirement — GitHub access per server**: The script clones or updates via
`git@github.com:GernotUllrich/<application>.git` and checks `ssh -T git@github.com` first.
Without a registered key it aborts with `Permission denied (publickey)`.

Setup (**once per server**, recommended as a **deploy key without write access**):

```bash
# 1. On the server: print the deploy user's public key
ssh -p <ssh_port> www-data@<server> 'cat ~/.ssh/id_rsa.pub'

# 2. Register this key in the repository:
#    Settings -> Deploy keys -> Add deploy key
#    Title e.g. "carambus_phat (Pi 192.168.178.84, www-data)"
#    Do NOT tick "Allow write access" - the script only reads

# 3. Verify on the server
ssh -p <ssh_port> www-data@<server> 'ssh -T git@github.com'
#    Expected: "Hi <owner>/<repo>! You've successfully authenticated, ..."
```

A deploy key applies to exactly one repository and can be revoked per server individually.
Each server needs its **own** key — the same key cannot be registered as a deploy key on
several repositories.

**Verify the result**: `/var/www/<basename>/revisions.log` records the executing user.
A server-side run shows up as `by www-data`, a Capistrano deploy under the name of
whoever triggered it.

### `deploy-scenario.sh` — rebuilding a scenario

**Purpose**: Complete rebuild of a scenario from the development machine (cleanup, preparation,
Capistrano)

**Usage**:
```bash
./bin/deploy-scenario.sh <scenario> [--skip-cleanup | --production-only] [-y]
```

!!! danger "Default mode tears down the server"
    Without `--skip-cleanup` or `--production-only`, step 0 cleans up first — after a single
    confirmation, with `-y` without one:

    - locally the database `<scenario>_development`
    - on the server the service `puma-<scenario>` (stop, disable) and the nginx configuration
    - on the server the entire directory `/var/www/<scenario>` including `shared/`
    - the production database, unless it holds local data or a newer version

    This is only meant for a rebuild. For code changes use `scenario:deploy` or `bin/deploy.sh`.

---

## Legacy

These scripts are still in `bin/` but no longer fit today's path. Do not use them.

| Script | What it actually does | Instead |
|---|---|---|
| `start-api-server.sh` | Kills a process on port 3000 (`kill -9`) and starts `rails server -e development-api` in the neighbouring checkout `carambus_api` | `bin/rails server` in the checkout |
| `start-local-server.sh` | Starts `carambus_api` on port 3001 with `-e development-local`; a scenario argument is not evaluated | `bin/rails server -p <port>` in the scenario checkout |
| `start-both-servers.sh` | Starts the two above (ports 3000/3001), on macOS in two terminal windows; no scenario argument | as above |
| `restart-carambus.sh` | Calls `/etc/init.d/unicorn_carambus_production start` (Unicorn era); nothing installs this init script | `sudo systemctl restart puma-<basename>` |
| `carambus-install.sh` | Docker installation on a Raspberry Pi (`/opt/carambus`, `docker-compose.yml`) — no Ruby, no www-data, no SSL | Ansible RUNBOOK + [quickstart](raspberry-pi-quickstart.md) |
| `setup-local-dev.sh` | For `carambus_local_hetzner`: overwrites `config/database.yml` with `config/database.development.yml` and creates an empty DB with seeds | `bin/rails "scenario:prepare_development[<scenario>,development]"` |

The start scripts use the environments `development-api`/`development-local` from the former mode
system; whether they still start today has not been checked.

No longer present (previously listed here as obsolete): `deploy-to-raspberry-pi.sh` and
`sync-carambus-folders.sh`. A Raspberry Pi is set up with Ansible and the quickstart.

---

## Workflow Examples

### Start a local development session

```bash
# 1. Prepare the development environment (from a carambus checkout)
bin/rails "scenario:prepare_development[<scenario>,development]"

# 2. Start the server
cd ~/DEV/carambus/<scenario>
bin/rails server -p <port>
```

!!! warning "What `prepare_development` requires and changes"
    - It fetches the global data via SSH as `www-data` from the **Authority's production database**
      (`api.carambus.de`). Currently only the Carambus operators have this access.
    - It compares the local `carambus_api_development` with the Authority and **replaces it** if newer
      data is available there (backup first, deleted again afterwards) — this affects every checkout that
      uses the same database, including `carambus_api`. If it is missing, it is created.
    - The log shows many `ERROR: role "www_data" does not exist` and `invalid command \restrict` —
      both are expected, the task still reports ✅.

### Deploy a code change

```bash
# 1. Commit and push the code
git add <files>
git commit -m "Feature: XYZ"
git push origin master

# 2. Deploy (from a carambus checkout)
bin/rails "scenario:deploy[<scenario>]"

# 3. Optional: restart the scoreboard browser on the Pi
bin/rails "scenario:restart_raspberry_pi_client[<scenario>]"
```

### Quick fix without the admin machine

If the server is not reachable or nobody is on the local network, it fetches the code itself:

```bash
# 1. Push the change
git commit -am "Fix: typo"
git push origin master

# 2. Deploy on the server
ssh -p <ssh_port> www-data@<server> '/var/www/<basename>/current/bin/deploy.sh'

# 3. Optional, if the server is also the scoreboard Pi: restart the browser
ssh -p <ssh_port> www-data@<server> 'sudo systemctl restart scoreboard-kiosk'
```

A `git pull` in `/var/www/<basename>/current` does not work: releases are unpacked archives without
`.git`.

### Debugging a production problem

```bash
# 1. Status and logs (on the server)
ssh -p <ssh_port> www-data@<server>
sudo systemctl status puma-<basename> nginx
sudo journalctl -u puma-<basename> -n 100 --no-pager
tail -200 /var/www/<basename>/shared/log/production.log

# 2. Open the console (if needed)
cd /var/www/<basename>/current
RAILS_ENV=production bundle exec rails console

# 3. Apply a quick fix
sudo systemctl restart puma-<basename>
```

---

## Troubleshooting

### Puma won't start

```bash
ssh -p <ssh_port> www-data@<server> 'sudo journalctl -u puma-<basename> -n 40 --no-pager'
ssh -p <ssh_port> www-data@<server> 'sudo systemctl restart puma-<basename>'
```

The most common cause after a deploy is a missing `/etc/<basename>.env` (SMTP credentials) — see
[quickstart, troubleshooting](raspberry-pi-quickstart.md#502-bad-gateway-after-the-deploy). There is no need
to delete PID files: the Puma configuration from `templates/` does not create any.

### Assets missing after deployment

Capistrano builds the assets on the server during the deploy. If they are missing, check the deploy log
and deploy again:

```bash
bin/rails "scenario:deploy[<scenario>]"
```

### Database connection fails

```bash
# Problem: "could not connect to server"
# Solution: Check PostgreSQL service
ssh -p <ssh_port> www-data@<server>
sudo systemctl status postgresql
sudo systemctl start postgresql

# Check config
cat /var/www/<basename>/shared/config/database.yml
```

### Memory problems

```bash
# Problem: "Cannot allocate memory"
ssh -p <ssh_port> www-data@<server> 'free -m'

# Restart Puma
ssh -p <ssh_port> www-data@<server> 'sudo systemctl restart puma-<basename>'
```

On a Raspberry Pi, first check whether ClamAV or SpamAssassin are running — see
[quickstart, troubleshooting](raspberry-pi-quickstart.md#pi-is-very-slow).

---

## Best Practices

### Development
1. ✅ After JavaScript changes run `rebuild_js.sh` or `yarn build --watch`
2. ✅ Use the console for quick database checks
3. ✅ Stop stuck local processes with `cleanup_rails.sh` — on the development machine only

### Production
1. ✅ Control Puma through the service (`systemctl … puma-<basename>`), not through processes
2. ✅ Console only for debugging, not for data changes
3. ✅ When problems occur: first `systemctl status` and `journalctl -u puma-<basename>`
4. ✅ Check logs regularly

### Deployment
1. ✅ Code changes from the admin machine: `scenario:deploy`
2. ✅ Server not reachable or nobody on the local network: `bin/deploy.sh` on the server
3. ✅ `deploy-scenario.sh` only for a rebuild — the default mode tears down the server
4. ✅ Before deployment: Perform local testing

---

## Monitoring & Maintenance

### Daily Checks

```bash
# Service status
ssh -p <ssh_port> www-data@<server> 'systemctl status puma-<basename>'

# Disk space
ssh -p <ssh_port> www-data@<server> 'df -h'

# Logs (errors)
ssh -p <ssh_port> www-data@<server> 'tail -100 /var/www/<basename>/shared/log/production.log | grep ERROR'
```

### Weekly Maintenance

```bash
# Check disk space and log size
ssh -p <ssh_port> www-data@<server> 'df -h; du -sh /var/www/<basename>/shared/log'
```

Log rotation for `production.log` is currently set up neither by Ansible nor by the rake tasks; the log
grows until it is trimmed by hand.

### Monthly Maintenance

```bash
# 1. System updates
ssh -p <ssh_port> www-data@<server>
sudo apt update && sudo apt upgrade -y

# 2. Restart services
sudo systemctl restart puma-<basename>
sudo systemctl restart nginx
```

Gem and Node updates belong in the repository and arrive with a deploy; a `bundle update` in the release
only changes the copy on the server and is overwritten by the next deploy.

---

## See Also

- [Raspberry Pi quickstart](raspberry-pi-quickstart.md) - Setting up a server, management commands
- [Deployment Workflow](../developers/deployment-workflow.md) - Complete deployment process
- [Scenario Management](../developers/scenario-management.md) - Scenario system overview
- [Raspberry Pi Scripts](raspberry_pi_scripts.md) - RasPi client management
- [Database Syncing](../developers/database-partitioning.md) - Database synchronization
