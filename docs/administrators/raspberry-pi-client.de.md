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

1. **Raspberry Pi OS Lite installieren**
2. **Chromium im Kiosk-Modus**
3. **Autostart-Skript**

```bash
# Beispiel Autostart
chromium-browser --kiosk --noerrdialogs \
  --disable-infobars --disable-session-crashed-bubble \
  https://carambus-server.local/table_monitors/1
```

---

➡️ Details siehe: [Raspberry Pi Client Integration](raspberry_pi_client_integration.de.md)

_Weitere Informationen folgen in einer zukünftigen Version._



