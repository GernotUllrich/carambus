# Raspberry Pi as Client/Display

This document describes how to set up a Raspberry Pi as a pure client (display/scoreboard) that connects to an existing Carambus server.

## Difference to All-in-One

- **All-in-One**: Raspberry Pi is server AND display
- **Client**: Raspberry Pi is only display, connects to external server

## Setup

### Hardware

- Raspberry Pi 4 or 5
- Display (HDMI or touch)
- Network connection to server

### Software

1. **Install Raspberry Pi OS Lite**
2. **Chromium in kiosk mode**
3. **Autostart script**

```bash
# Example autostart
chromium-browser --kiosk --noerrdialogs \
  --disable-infobars --disable-session-crashed-bubble \
  https://carambus-server.local/table_monitors/1
```

---

➡️ Details see: [Raspberry Pi Client Integration](raspberry_pi_client_integration.de.md) (German only for now)

_More information will follow in a future version._



