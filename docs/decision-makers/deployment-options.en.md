# Deployment Options

How a club or regional association runs Carambus. One path is proven: the club server on a Raspberry Pi. It was
walked through completely on fresh hardware in September 2026.

## Overview

| Use | Path | Status |
|---|---|---|
| Club | Club server on a Raspberry Pi — server and scoreboard in one device | proven: [Raspberry Pi Quickstart](../administrators/raspberry-pi-quickstart.md) |
| Additional tables at the club | a Raspberry Pi as a pure display device, or a browser | display Pi not yet walked through on fresh hardware ([Raspberry Pi as client](../administrators/raspberry-pi-client.md)) |
| Regional association | Region server (e.g. `nbv.carambus.de`) | run by the Carambus operator |
| Own server or VPS | like the club server, on different hardware | not proven, on request |

## How it fits together

Every Carambus server is part of a network:

```
Authority (api.carambus.de, run by the operator)
    ├─ master data, hourly → club server (Raspberry Pi at the venue)
    └─ master data         → region server (regional association)
```

- The Authority reads players, clubs, tournaments and tournament plans from the DBU ClubCloud. The club servers
  receive them via synchronization and cannot change them.
- Whatever is created at the club — local tournaments, games, training results, table reservations — stays on the
  club server.
- Play at the venue continues without internet. The club server needs internet for the setup, the hourly
  synchronization with the Authority and the result upload to the ClubCloud.

More: [Server architecture](../administrators/server-architecture.md)

## The club server on the Raspberry Pi

A Raspberry Pi is server and scoreboard at the same time: it runs in kiosk mode on a monitor or touch display.
Additional tables each get a display device.

**Hardware** (as in use):

- Raspberry Pi 4 or 5; 4 GB RAM recommended, 2 GB is tight
- microSD card with at least 16 GB (32 GB recommended), official power supply, monitor via HDMI
- Wired network recommended, Wi-Fi works
- Operating system: Raspberry Pi OS (64 bit) **with desktop** — the kiosk needs a graphical session

**Procedure** (measured on fresh hardware):

1. Write the SD card with the Raspberry Pi Imager
2. Set up the system with Ansible in one run: a little over 60 minutes (hardening, Ruby, PostgreSQL, nginx)
3. Deploy the application with Rake tasks from the admin computer: about 15 minutes
4. After that the Pi boots into the scoreboard by itself; after power-on this takes about 3 minutes

Guide: [Raspberry Pi Quickstart](../administrators/raspberry-pi-quickstart.md)

**Tournament app:** the club server delivers the [tournament app](features-overview.md#turnier-app) under `/app/`
if this is switched on in the scenario configuration (`serve_tournament_app`). For this the app's repository sits
next to `carambus_data` on the admin computer; when the deploy is prepared, its delivered part (`public/`) is
copied to the server. The app logs in with a service account of the region that the admin creates on the server.

<a id="voraussetzungen"></a>
## Requirements for running your own server

| What | Why |
|---|---|
| **The Carambus operator** | The initial database load fetches the master data via SSH from the Authority's database; only the operator has this access. The server's access keys (`production.key`) also come from the operator today. How a club can do both itself in the future is still open. |
| **An admin computer (Mac or Linux)** | Ansible and the Rake tasks run from here. You need the Raspberry Pi Imager, a Carambus checkout, the scenario configuration (`carambus_data`), the Ansible repository, a local PostgreSQL and an SSH key, plus the tournament app's repository if you use it. |
| **Linux and SSH skills** | for the setup and for errors that come up along the way |
| **The DBU ClubCloud** | Players and clubs are maintained there; the tournament director does the result upload with their ClubCloud access. |
| **A mail account** | In production Carambus only starts with SMTP credentials — or with mail sending deliberately switched off. |
| **Internet** | for setup, hourly synchronization and ClubCloud upload, not for play |

Details: [Installation overview](../administrators/installation-overview.md)

## Day-to-day operation

- **Operating system updates:** security updates run automatically.
- **Carambus updates** are rolled out from the admin computer (`scenario:deploy`, measured at about 9 minutes).
- **Backup:** a new club server has no automatic backup. It has to be set up, for example to a USB stick
  ([Maintenance checklist](../administrators/index.md#maintenance-checklist)).
- **If the SD card fails:** rebuild following the Quickstart; the club's tournaments and games can only be
  restored from a backup.
- **Access:** on the club network via `http://<name>.local:3131`, without HTTPS; from outside e.g. via a DynDNS
  name (as at BC Wedel).
- **Firewall:** the setup opens only the web and the SSH port.

## For regional associations

A regional association uses a **region server** (example `nbv.carambus.de`). The association's sports officials
work there — with the ClubCloud assistant ([Quickstart](../managers/clubcloud-mcp-cloud-quickstart.md), German)
or, for individual championships, without the ClubCloud
([CC-less tournament management](../administrators/cc-less-tournament-management.md), German). The club servers of
the region connect directly to the Authority, not to the region server. Region servers are currently run by the
Carambus operator.

## Own server or VPS

The operator's servers (Authority, region servers) run on a rented server. As a path for a club this is not
described: nobody has yet set up a Carambus server on hardware other than the Raspberry Pi — mini PC, own server,
rented VPS — from scratch following this guide, and whether the Ansible setup works equally well there has not
been checked. If you are interested: [Contact](index.md#kontakt).

## Costs

- No license fees (MIT license)
- Hardware: Raspberry Pi, power supply, microSD card, monitor or touch display; one display device for each
  additional table
- Running costs only for electricity and optional services (such as the Anthropic key for AI search)
