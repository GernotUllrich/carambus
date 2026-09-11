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

1. **Install Raspberry Pi OS (64 bit) with desktop** and create a user with autologin in the Imager.
   The kiosk needs a graphical session — with Raspberry Pi OS Lite it does not start.
2. **SSH access for the rake tasks**: The tasks work via SSH and `sudo`. A Pi set up with Ansible as in
   the [quickstart, steps 1–2](raspberry-pi-quickstart.md) meets this (`www-data`, port 8910). Ansible
   also installs Ruby, PostgreSQL and nginx, which a pure client does not need.
3. **Configure the kiosk**: In the `config.yml` of the scenario whose server the client displays, add the
   `raspberry_pi_client` section with `local_server_enabled: false`. The scoreboard URL then points to
   the server's `webserver_host:webserver_port`.
4. **Set up and deliver the kiosk**:

```bash
bin/rails "scenario:setup_raspberry_pi_client[<scenario>]"
bin/rails "scenario:deploy_raspberry_pi_client[<scenario>]"
bin/rails "scenario:test_raspberry_pi_client[<scenario>]"
```

A pure client has not yet been walked through on fresh hardware; the path that was walked is the
all-in-one path of the quickstart.

---

➡️ Details see: [Raspberry Pi Client Integration](raspberry_pi_client_integration.md)

_More information will follow in a future version._
