# Security in Operation

What a club has to do for the security of its own server — **when it becomes due, who is
responsible and where the actual instructions are**. This page does not repeat those
instructions, it points to them.

## What this page assumes

A club server sits on the club's own network, usually as a Raspberry Pi in the club house. There
it runs **without HTTPS on port 3131** — that is intended, not an oversight: on a private network
there is no meaningful certificate name, and the scoreboards should start without a certificate
warning. The protection comes from the network boundary: from outside, the server is only
reachable if the club deliberately exposes it.

**As soon as that happens the situation changes** — there is a separate section for that below.

## One-off, during setup

These come up exactly once. Three of them are handled by the Ansible setup.

| What | Who | Where the instructions are |
|---|---|---|
| **The server's own keys** (`production.key`, `production.yml.enc`) | club | [Configuration files](index.md#important-configuration-files) — for a new scenario, `NEW_KEY=true` |
| **Firewall** (only ports 3131 and 8910 open, SSH as `www-data`) | Ansible | [Quickstart, steps 1–2](raspberry-pi-quickstart.md) |
| **Automatic operating-system updates** | Ansible | see "What the automation covers" below |
| **Database backup** onto a USB stick | club | [Maintenance checklist](index.md#maintenance-checklist) — without this step there is **no** backup |
| **Keeping the region dump credentials** | operator issues, club keeps | [Region dumps](region-dumps.md) |

!!! warning "The backup step is the most important row in this table"
    An SD card eventually fails — that is the most likely way to lose a club server entirely. For
    a freshly installed Pi **no** automatic backup is configured; it has to be set up once by hand.

**Why its own keys:** until 2026 all Carambus servers shared one set of keys, and that set was
publicly readable. Since then every server has its own. A scenario created without `NEW_KEY=true`
does not get its own — which is why it is mentioned here.

## What recurs — and what triggers it

Not a calendar, but occasions. When one occurs, the matching step is due.

| Occasion | What to do | Where |
|---|---|---|
| **Someone with server access leaves the club** | Rotate the server's keys; review the ClubCloud account and admin users | [Rotating credentials](index.md#rotating-credentials) |
| **A password or key has surfaced** somewhere it does not belong (chat, email, screenshot, repository) | Rotate that value — **everywhere** it is used. Until then it remains fully valid | [Rotating credentials](index.md#rotating-credentials) |
| **Suspicion of unauthorised access** | Rotate first, investigate second — not the other way round | as above |
| **The admin password is lost** | Create a second administrator using a different email address | [Quickstart, step 3.2](raspberry-pi-quickstart.md) |
| **After every deploy** | Nothing extra — the configuration files on the server are rewritten as part of it | [Configuration files](index.md#important-configuration-files) |
| **The backup USB stick is missing or was swapped** | Make sure it is mounted at `/mnt/backup` again — otherwise the backup run aborts, by design | [Maintenance checklist](index.md#maintenance-checklist) |

!!! note "Rotating means the old value stops working"
    A rotation only helps if it replaces the old value. A secret that was once public stays
    public — cleaning it up does not make it secret again.

## What the automation covers — and what it does not

The Ansible setup configures **unattended security updates** for the operating system
(`unattended-upgrades`, origins `security` and `updates`; notifications go to the admin address
given during setup).

**That covers operating-system packages only.** Not included:

- **Ruby and Rails.** Carambus runs on Ruby 3.2 and Rails 7.2; since 2026 neither receives
  security updates from its maintainers. The upgrade is still pending. As long as the server is
  only reachable on the club network the risk is limited — exposing it to the internet makes this
  a deliberate decision.
- **Carambus itself.** New versions arrive with a deploy that somebody triggers.

## If the server should be reachable from outside

A club server can be made reachable from the internet via a DynDNS name (this is how BC Wedel
runs it). That is possible, but it changes three things at once:

1. **HTTPS becomes necessary.** The Scenario Management does **not** issue certificates — the
   certificate has to exist before the deploy, otherwise `nginx -t` fails. See the
   [installation overview](installation-overview.md).
2. **The bot block becomes relevant.** On a private network it is meaningless; on a public address
   it turns away automated traffic: [nginx bot block](nginx-bot-block.md).
3. **The maintenance status of Ruby and Rails now counts.** See above — a footnote on a private
   network, a point to weigh on a public address.

On top of that the club has to set up port forwarding in its router and run a DynDNS service.
Both are the club's own responsibility and not part of the Carambus setup.

## What only the operator can do

For the sake of honesty, so nobody goes looking:

- **The region dump credentials** for the club's own region — requested once.
- **The two non-public repositories** `carambus_data` and `ansible` that the installation
  requires (see
  [The three directories](raspberry-pi-quickstart.md#the-three-directories)).
- **Entries on the Authority** — if the club or its location does not exist there yet, only the
  operator can create them.

## In short

A club has exactly **two** recurring security duties that nobody else takes over: making sure the
**backup runs**, and **rotating credentials** when one of the occasions above occurs. Everything
else is set up once or runs automatically.
