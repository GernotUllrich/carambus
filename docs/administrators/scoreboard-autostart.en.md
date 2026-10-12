# Scoreboard Autostart

On the Raspberry Pi the scoreboard starts through the systemd service **`scoreboard-kiosk`**. It is set up with
rake tasks from the admin machine — not by hand. The complete path is described in the
[Raspberry Pi quickstart](raspberry-pi-quickstart.md); the reference of the kiosk tasks is
[Raspberry Pi Client Integration](raspberry_pi_client_integration.md).

Earlier versions of this page described an autostart via LXDE, a hand-maintained URL file and self-made
`scoreboard.service` units. Under Raspberry Pi OS 13 ("trixie", desktop labwc) that path no longer works; the
instructions have been removed (history in git).

## Setting up the kiosk

From a carambus checkout, once server and application are running (quickstart, step 3.2):

```bash
bin/rails "scenario:setup_raspberry_pi_client[<scenario>]"
bin/rails "scenario:deploy_raspberry_pi_client[<scenario>]"
bin/rails "scenario:test_raspberry_pi_client[<scenario>]"
```

- `setup_raspberry_pi_client` installs Chromium and creates the `scoreboard-kiosk` service; it runs as the
  `kiosk_user` from `config.yml` — the autologin user of the desktop session.
- `deploy_raspberry_pi_client` generates the start script `/usr/local/bin/autostart-scoreboard.sh` and restarts
  the service. You can view the script beforehand with
  `bin/rails "scenario:preview_autostart_script[<scenario>]"`.

Do not edit the script by hand: the next `deploy_raspberry_pi_client` overwrites it.

## Where the scoreboard URL comes from

The URL is built from the scenario `config.yml`:

| Part | Source |
|---|---|
| Host | `localhost` with `raspberry_pi_client.local_server_enabled: true`, otherwise `webserver_host` |
| Port | `webserver_port` (e.g. 3131) |
| Location | `md5` of the location `scenario.location_id` from the database |
| State | `raspberry_pi_client.sb_state` (default `welcome`) |

Example: `http://localhost:3131/locations/<md5>/scoreboard?sb_state=welcome&locale=de`

`deploy_raspberry_pi_client` stores it on the server as `/var/www/<basename>/shared/config/scoreboard_url` and
overwrites the file every time. To use a different URL, set it in `config.yml` and run
`deploy_raspberry_pi_client` again.

## After power-on

It takes about **3 minutes** until the scoreboard is up: the desktop appears after about 1 minute, then the
script waits until the local server answers (at most 300 s), then Chromium starts. The Pi is not broken during
this time.

## Operating the kiosk

```bash
# Restart
ssh -p 8910 www-data@<name>.local 'sudo systemctl restart scoreboard-kiosk'
# or from the admin machine
bin/rails "scenario:restart_raspberry_pi_client[<scenario>]"

# Stop (to the desktop) and start again
ssh -p 8910 www-data@<name>.local 'sudo systemctl stop scoreboard-kiosk'
ssh -p 8910 www-data@<name>.local 'sudo systemctl start scoreboard-kiosk'
```

- **Raspberry Pi OS 13 ("trixie", labwc):** Chromium runs in kiosk mode; the button on the welcome page does
  **not** lead to the desktop — stop the service instead. If Chromium exits (crash, Alt+F4), the kiosk restarts
  by itself after a few seconds.
- **Raspberry Pi OS 12 ("bookworm", wayfire):** Full screen via `--start-fullscreen`; the button on the welcome
  page toggles full screen.

## Logs and troubleshooting

```bash
ssh -p 8910 www-data@<name>.local 'sudo journalctl -u scoreboard-kiosk -n 30'
ssh -p 8910 www-data@<name>.local 'sudo tail -50 /tmp/chromium-kiosk.log'
bin/rails "scenario:test_raspberry_pi_client[<scenario>]"
```

The Chromium log belongs to the kiosk user and can only be read with `sudo` as `www-data`.

- **Scoreboard not full screen:** run `deploy_raspberry_pi_client` again; the desktop session is set in
  `/etc/lightdm/lightdm.conf` (`user-session=`).
- **Other cases:** [Raspberry Pi Client Integration, common issues](raspberry_pi_client_integration.md#common-issues)

## Do not create a second autostart

`scoreboard-kiosk` is the only autostart. An additional hand-made `scoreboard.service`, an LXDE autostart entry
or the older scripts from `bin/` (`start-scoreboard.sh`, `autostart-scoreboard.sh`, `restart-scoreboard.sh`)
can start a second browser next to the kiosk. If such leftovers from an earlier guide are still on the Pi, remove
them. What the older scripts do: [Raspberry Pi Management Scripts, legacy](raspberry_pi_scripts.md#legacy).
