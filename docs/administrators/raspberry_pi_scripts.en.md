# Raspberry Pi Management Scripts

This documentation describes how Raspberry Pi clients in the Carambus system are set up and operated
today — and what the older Raspi scripts in `bin/` actually do.

## Overview

A Raspberry Pi is no longer set up with the scripts from `bin/`:

- **System**: via Ansible — `~/DEV/ansible/RUNBOOK`, section "NEUEN CARAMBUS-PI AUFSETZEN"
- **Application and kiosk**: with the rake tasks of the [Raspberry Pi quickstart](raspberry-pi-quickstart.md)
  (reference of the kiosk tasks: [Raspberry Pi Client Integration](raspberry_pi_client_integration.md))
- **Operation**: through the systemd service `scoreboard-kiosk`

The Raspi scripts live in `bin/` of every Carambus checkout (e.g. `~/DEV/carambus/carambus_bcw/bin/`). They
date from before this path and no longer fit it — see [Legacy](#legacy). The rake tasks run from any
up-to-date checkout; `<scenario>` stands for the scenario name, `<name>` for the Pi's device name.

---

## Today's path

### Setting up a new Raspberry Pi

Fully described in the [quickstart](raspberry-pi-quickstart.md) and walked through on the device:

1. Write the SD card with the Raspberry Pi Imager (Raspberry Pi OS with desktop, user with autologin,
   SSH with key)
2. System via Ansible — one run of `master.yml`; afterwards SSH only as `www-data` on port 8910
3. Application and kiosk via rake tasks (quickstart, step 3)

### Operating the kiosk

```bash
# Restart the browser (from the admin machine)
bin/rails "scenario:restart_raspberry_pi_client[<scenario>]"

# Or directly at the service
ssh -p 8910 www-data@<name>.local 'sudo systemctl restart scoreboard-kiosk'

# To the desktop (stop the kiosk) and back
ssh -p 8910 www-data@<name>.local 'sudo systemctl stop scoreboard-kiosk'
ssh -p 8910 www-data@<name>.local 'sudo systemctl start scoreboard-kiosk'

# Check
bin/rails "scenario:test_raspberry_pi_client[<scenario>]"
```

### Shipping an update to the Pi

```bash
bin/rails "scenario:deploy[<scenario>]"
```

`deploy-scenario.sh` is not meant for this: its default mode tears down the server deployment and possibly
the production database — see [Server Management Scripts](server-scripts.md).

---

## Legacy

These scripts are still in `bin/` but no longer fit today's path. Do not use them.

### Setup & Installation

| Script | What it actually does | Instead |
|---|---|---|
| `setup-raspberry-pi.sh` | Prepares a Raspberry Pi 4 for a Docker installation; only takes options, no scenario (`Unbekannte Option`) | Ansible RUNBOOK + quickstart |
| `install-client-only.sh <scenario_name> <client_ip> [ssh_port] [ssh_user]` | Installs `chromium-browser` via SSH without falling back to `chromium` (the package does not exist on trixie) and its own autostart configuration without a labwc branch | Rake tasks with `local_server_enabled: false`, see [Raspberry Pi as client](raspberry-pi-client.md) |
| `setup-phillips-table-ssh.sh` | Site-specific: fixed IP and user `pi`; checks ports 22/8910 with `nmap` and prints instructions — generates and copies no keys | SSH key in the Imager or `ssh-copy-id <user>@<name>.local` |
| `prepare-sd-card.sh [OPTIONS] SD_CARD_PATH` | Only creates `ssh` and `wpa_supplicant.conf` in the boot partition of an already written card — formats nothing, installs nothing | Raspberry Pi Imager (RUNBOOK) |

### Testing & Debugging

| Script | What it actually does | Instead |
|---|---|---|
| `find-raspberry-pi.sh --network <net> [--ssh-test]` | Scans a network (default `192.168.1.0/24`) for Pis; the SSH test runs as `pi` on port 22 | Address Pis by device name (`<name>.local`) |
| `test-raspberry-pi.sh` | Tests a Docker installation (options `-d`/`-c`/`--cleanup`); takes no scenario | `bin/rails "scenario:test_raspberry_pi_client[<scenario>]"` |
| `test-raspberry-pi-restart.sh <scenario_name>` | Tests the restart command via `sshpass`; it does not test a reboot | `bin/rails "scenario:test_raspberry_pi_client[<scenario>]"` |

### Scoreboard Management

These scripts date from the LXDE/X11 era. Started next to the `scoreboard-kiosk` service, they open a second
browser.

| Script | What it actually does | Instead |
|---|---|---|
| `start-scoreboard.sh` | Starts the fixed `/usr/bin/chromium-browser` (not present on trixie) with the URL from `../config/scoreboard_url`; an argument is ignored | Service `scoreboard-kiosk` |
| `autostart-scoreboard.sh` | Outdated second copy of the kiosk logic with fixed values (`carambus_location_5101`, `chromium-browser`); creates no service | The generated `/usr/local/bin/autostart-scoreboard.sh` — produced by `deploy_raspberry_pi_client`, view it with `bin/rails "scenario:preview_autostart_script[<scenario>]"` |
| `restart-scoreboard.sh` | Kills `pcmanfm` and calls `start-scoreboard.sh`; does not stop Chromium | `sudo systemctl restart scoreboard-kiosk` or `scenario:restart_raspberry_pi_client` |
| `exit-scoreboard.sh` | `pkill chromium-browser` (does not match `chromium` on trixie), shows the LXDE panel, starts `pcmanfm` | `sudo systemctl stop scoreboard-kiosk` (back with `start`) |
| `cleanup-chromium.sh` | Kills `chromium-browser` and deletes `/tmp/chromium*` and `/tmp/.X*` with `sudo` — including the running kiosk's profile and the X11 sockets of the running desktop session | Not needed: the kiosk recreates its profile on every start; if problems occur, `sudo systemctl restart scoreboard-kiosk` |

### No longer present

Previously listed here as obsolete, meanwhile removed from `bin/`: `quick-start-raspberry-pi.sh`,
`auto-setup-raspberry-pi.sh`, `start_scoreboard`, `start_scoreboard_delayed`.

---

## Workflow Examples

### Setting up a new Raspberry Pi completely

See the [quickstart](raspberry-pi-quickstart.md): Imager, then Ansible, then from a carambus checkout:

```bash
bin/rails "scenario:prepare_deploy[<scenario>]"
bin/rails "scenario:prepare_development[<scenario>,development]"
bin/rails "scenario:reset_server_db[<scenario>]"        # DESTRUCTIVE
bin/rails "scenario:deploy[<scenario>]"
bin/rails "scenario:setup_raspberry_pi_client[<scenario>]"
bin/rails "scenario:deploy_raspberry_pi_client[<scenario>]"
bin/rails "scenario:test_raspberry_pi_client[<scenario>]"
```

What these steps require (among others SSH access to the Authority for `prepare_development`) and change
is described in the quickstart under step 3.2.

### Fixing browser problems

```bash
# 1. Restart the kiosk
ssh -p 8910 www-data@<name>.local 'sudo systemctl restart scoreboard-kiosk'

# 2. Look at the logs
ssh -p 8910 www-data@<name>.local 'sudo journalctl -u scoreboard-kiosk -n 30'
ssh -p 8910 www-data@<name>.local 'sudo tail -50 /tmp/chromium-kiosk.log'

# 3. Deliver the kiosk script again (restarts the kiosk with the current script)
bin/rails "scenario:deploy_raspberry_pi_client[<scenario>]"
```

### Deploying a scenario update to the RasPi

```bash
# 1. Deploy from the admin machine
bin/rails "scenario:deploy[<scenario>]"

# 2. Optional: restart the browser
bin/rails "scenario:restart_raspberry_pi_client[<scenario>]"

# 3. Test
bin/rails "scenario:test_raspberry_pi_client[<scenario>]"
```

---

## Troubleshooting

### SSH connection fails
```bash
# After Ansible: only www-data on port 8910
ssh -p 8910 www-data@<name>.local true

# Before Ansible: the user created in the Imager on port 22
ssh <user>@<name>.local true

# Problem: "Permission denied (publickey)" — add the key (before Ansible)
ssh-copy-id <user>@<name>.local
```

"Connection refused" before the first Ansible run usually means: SSH was not ticked in the Imager. The box
has to be ticked again every time the card is written.

### Browser doesn't start
```bash
ssh -p 8910 www-data@<name>.local 'sudo systemctl status scoreboard-kiosk'
ssh -p 8910 www-data@<name>.local 'sudo tail -50 /tmp/chromium-kiosk.log'
bin/rails "scenario:test_raspberry_pi_client[<scenario>]"
```

Further causes and fixes: [Raspberry Pi Client Integration, common issues](raspberry_pi_client_integration.md#common-issues).

### Scoreboard shows old version
```bash
# Restart the kiosk — the browser profile is recreated in the process
ssh -p 8910 www-data@<name>.local 'sudo systemctl restart scoreboard-kiosk'
```

---

## Best Practices

### RasPi Setup
1. ✅ Address Pis by device name (`<name>.local`), not by IP
2. ✅ Add the SSH key in the Imager already
3. ✅ If the scoreboard shows the old version after a deployment: restart the kiosk

### Network
1. ✅ SSH port 8910 and the firewall (only 3131 + 8910) are set by Ansible
2. ✅ Wired network recommended; WLAN works

### Maintenance
1. ✅ Monthly: OS updates via `sudo apt update && sudo apt upgrade`
2. ✅ When problems occur: first restart the kiosk (`scoreboard-kiosk`), then reboot

---

## See Also

- [Raspberry Pi quickstart](raspberry-pi-quickstart.md) - Setup from the SD card to the scoreboard
- [Raspberry Pi Client Integration](raspberry_pi_client_integration.md) - Reference of the kiosk rake tasks
- [Client-Only Installation](raspberry-pi-client.md) - Pi as a pure display
- [Scoreboard Autostart](scoreboard-autostart.md) - How the kiosk starts
- [Server Management Scripts](server-scripts.md) - Scripts for the server
