# Scoreboard Autostart

Das Scoreboard startet am Raspberry Pi über den systemd-Dienst **`scoreboard-kiosk`**. Eingerichtet wird er mit
Rake-Tasks vom Admin-Rechner aus — nicht von Hand. Den ganzen Weg beschreibt die
[Raspberry-Pi-Quickstart](raspberry-pi-quickstart.md); die Referenz der Kiosk-Tasks steht in
[Raspberry Pi Client Integration](raspberry_pi_client_integration.md).

Frühere Fassungen dieser Seite beschrieben einen Autostart über LXDE, eine von Hand gepflegte URL-Datei und
selbst angelegte `scoreboard.service`-Dienste. Unter Raspberry Pi OS 13 („trixie“, Desktop labwc) wirkt dieser
Weg nicht mehr; die Anleitung ist entfallen (Historie in git).

## Den Kiosk einrichten

Aus einem carambus-Checkout, nachdem Server und Anwendung laufen (Quickstart, Schritt 3.2):

```bash
bin/rails "scenario:setup_raspberry_pi_client[<szenario>]"
bin/rails "scenario:deploy_raspberry_pi_client[<szenario>]"
bin/rails "scenario:test_raspberry_pi_client[<szenario>]"
```

- `setup_raspberry_pi_client` installiert Chromium und legt den Dienst `scoreboard-kiosk` an; er läuft unter
  dem `kiosk_user` aus der `config.yml` — dem Autologin-Benutzer der Desktop-Sitzung.
- `deploy_raspberry_pi_client` erzeugt das Start-Script `/usr/local/bin/autostart-scoreboard.sh` und startet
  den Dienst neu. Ansehen lässt sich das Script vorher mit
  `bin/rails "scenario:preview_autostart_script[<szenario>]"`.

Das Script nicht von Hand ändern: Der nächste `deploy_raspberry_pi_client` überschreibt es.

## Woher die Scoreboard-URL kommt

Die URL entsteht aus der Szenario-`config.yml`:

| Teil | Quelle |
|---|---|
| Host | `localhost` bei `raspberry_pi_client.local_server_enabled: true`, sonst `webserver_host` |
| Port | `webserver_port` (z. B. 3131) |
| Location | `md5` der Location `scenario.location_id` aus der Datenbank |
| Zustand | `raspberry_pi_client.sb_state` (Standard `welcome`) |

Beispiel: `http://localhost:3131/locations/<md5>/scoreboard?sb_state=welcome&locale=de`

`deploy_raspberry_pi_client` legt sie unter `/var/www/<basename>/shared/config/scoreboard_url` auf dem Server ab
und überschreibt die Datei dabei jedes Mal. Eine andere URL also in der `config.yml` einstellen und
`deploy_raspberry_pi_client` erneut ausführen.

## Nach dem Einschalten

Bis das Scoreboard steht, dauert es rund **3 Minuten**: Der Desktop kommt nach etwa 1 Minute, danach wartet das
Script, bis der lokale Server antwortet (höchstens 300 s), dann startet Chromium. Der Pi ist in dieser Zeit
nicht defekt.

## Den Kiosk bedienen

```bash
# Neu starten
ssh -p 8910 www-data@<name>.local 'sudo systemctl restart scoreboard-kiosk'
# oder vom Admin-Rechner
bin/rails "scenario:restart_raspberry_pi_client[<szenario>]"

# Anhalten (zum Desktop) und wieder starten
ssh -p 8910 www-data@<name>.local 'sudo systemctl stop scoreboard-kiosk'
ssh -p 8910 www-data@<name>.local 'sudo systemctl start scoreboard-kiosk'
```

- **Raspberry Pi OS 13 („trixie“, labwc):** Chromium läuft im Kiosk-Modus; der Button auf der Welcome-Seite führt
  **nicht** auf den Desktop — dafür den Dienst anhalten. Wird Chromium beendet (Absturz, Alt+F4), startet der
  Kiosk nach wenigen Sekunden von selbst neu.
- **Raspberry Pi OS 12 („bookworm“, wayfire):** Vollbild mit `--start-fullscreen`; der Button auf der
  Welcome-Seite schaltet das Vollbild um.

## Logs und Fehlerbehebung

```bash
ssh -p 8910 www-data@<name>.local 'sudo journalctl -u scoreboard-kiosk -n 30'
ssh -p 8910 www-data@<name>.local 'sudo tail -50 /tmp/chromium-kiosk.log'
bin/rails "scenario:test_raspberry_pi_client[<szenario>]"
```

Das Chromium-Log gehört dem Kiosk-Benutzer und ist als `www-data` nur mit `sudo` lesbar.

- **Scoreboard nicht im Vollbild:** `deploy_raspberry_pi_client` erneut ausführen; die Desktop-Sitzung steht in
  `/etc/lightdm/lightdm.conf` (`user-session=`).
- **Weitere Fälle:** [Raspberry Pi Client Integration, Fehlerbehebung](raspberry_pi_client_integration.md#fehlerbehebung)

## Keinen zweiten Autostart anlegen

`scoreboard-kiosk` ist der einzige Autostart. Ein zusätzlicher, von Hand angelegter `scoreboard.service`, ein
LXDE-Autostart-Eintrag oder die älteren Scripts aus `bin/` (`start-scoreboard.sh`, `autostart-scoreboard.sh`,
`restart-scoreboard.sh`) können einen zweiten Browser neben dem Kiosk starten. Wer so etwas von einer früheren Anleitung
noch auf dem Pi hat, entfernt es. Was die älteren Scripts tun:
[Raspberry Pi Management Scripts, Altlasten](raspberry_pi_scripts.md#altlasten).
