# Raspberry Pi als Client/Display

Dieses Dokument beschreibt, wie Sie einen Raspberry Pi als reinen Client (Display/Scoreboard) einrichten, der sich mit einem existierenden Carambus-Server verbindet.

## Unterschied zu All-in-One

- **All-in-One**: Raspberry Pi ist Server UND Display
- **Client**: Raspberry Pi ist nur Display, verbindet sich mit externem Server

## Setup

### Hardware

- Raspberry Pi 4 oder 5
- Display (HDMI oder Touch)
- Netzwerk-Verbindung zum Server

### Software

1. **Raspberry Pi OS (64 bit) mit Desktop** installieren, im Imager einen Benutzer mit Autologin anlegen.
   Der Kiosk braucht eine grafische Sitzung — mit Raspberry Pi OS Lite startet er nicht.
2. **SSH-Zugang für die Rake-Tasks**: Die Tasks arbeiten per SSH und `sudo`. Ein Pi, der wie in der
   [Quickstart, Schritt 1–2](raspberry-pi-quickstart.md) per Ansible aufgesetzt ist, erfüllt das
   (`www-data`, Port 8910). Ansible richtet dabei auch Ruby, PostgreSQL und nginx ein, die ein reiner
   Client nicht braucht.
3. **Kiosk konfigurieren**: In der `config.yml` des Szenarios, dessen Server der Client anzeigt, den
   Abschnitt `raspberry_pi_client` mit `local_server_enabled: false` anlegen. Die Scoreboard-URL zeigt dann
   auf `webserver_host:webserver_port` des Servers.
4. **Kiosk einrichten und ausliefern**:

```bash
bin/rails "scenario:setup_raspberry_pi_client[<szenario>]"
bin/rails "scenario:deploy_raspberry_pi_client[<szenario>]"
bin/rails "scenario:test_raspberry_pi_client[<szenario>]"
```

Ein reiner Client ist bisher nicht auf frischer Hardware durchgegangen worden; gegangen ist der
All-in-One-Weg der Quickstart.

---

➡️ Details siehe: [Raspberry Pi Client Integration](raspberry_pi_client_integration.md)

_Weitere Informationen folgen in einer zukünftigen Version._
