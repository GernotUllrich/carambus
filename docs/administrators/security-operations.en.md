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

## Taking over an existing server

Whoever inherits a running club server — because the person who set it up is gone — does not know
what has already been taken care of. The following five questions settle that. Each takes a few
minutes.

| Question | How to find out | If the answer is unfavourable |
|---|---|---|
| **Are we reachable from outside?** | In `carambus_data/scenarios/<scenario>/config.yml`, under `environments.production`, look at `webserver_host`. A local network name (`<name>.local`) means the server is club-network only. A DynDNS name means it is public — then the section [If the server should be reachable from outside](#if-the-server-should-be-reachable-from-outside) applies | Check whether HTTPS and the bot block are in place |
| **Do we have our own keys?** | Not directly visible. If the server was set up before mid-2026 and never rotated since, it may still carry the then-shared, publicly readable key set | When in doubt, simply rotate — that produces its own keys either way ([Rotating credentials](index.md#rotating-credentials)) |
| **Where do the update runs report to?** | On the Pi, in `/etc/apt/apt.conf.d/50unattended-upgrades` under `Unattended-Upgrade::Mail` | If that is the departed person's address, every notification goes nowhere — change it |
| **Who can actually deploy and rotate?** | Neither runs **on the Pi**; both run from an admin computer holding the [three directories](raspberry-pi-quickstart.md#the-three-directories) — two of which are not public | If that machine left with the person, nobody can currently install updates. Contact the operator |
| **When does our certificate expire?** | Only relevant if the server is publicly reachable. Visible in the browser via the padlock | Renew it before it expires — otherwise the browser warns and HTTPS breaks ([troubleshooting](index.md#troubleshooting-guide)) |

**And regardless of the above:** if the person who set up the server has left, one of the
occasions below has already occurred. See
[What recurs](#what-recurs-and-what-triggers-it).

## One-off, during setup

These come up exactly once. Three of them are handled by the Ansible setup.

On an **inherited** server it is not a given that all of them were done — the two the club has to
do itself (its own keys, the backup) are the ones typically missed. The section above explains
how to check.

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

    **How to tell that it is running:**

    ```bash
    ssh -p 8910 www-data@<name>.local 'ls -la /mnt/backup/'
    ```

    There is one timestamped directory per run (`20260921_012000`) holding a `.dump` file per
    database; on Sundays a copy is added under `weekly/`. If the newest directory is more than a
    day old, or the directory is empty, the backup is **not** running — then something is wrong
    with the mounted stick or with the entry in `STANDALONE_BACKUP_SCENARIOS`.

**Why its own keys:** until 2026 all Carambus servers shared one set of keys, and that set was
publicly readable. Since then every server has its own. A scenario created without `NEW_KEY=true`
does not get its own — which is why it is mentioned here.

## What recurs — and what triggers it

Not a calendar, but occasions. When one occurs, the matching step is due.

| Occasion | What to do | Where |
|---|---|---|
| **Someone with server access leaves the club** | **Remove their SSH key first** (see the box below), then rotate the server's keys; review the ClubCloud account and admin users | [Rotating credentials](index.md#rotating-credentials) |
| **A password or key has surfaced** somewhere it does not belong (chat, email, screenshot, repository) | Rotate that value — **everywhere** it is used. Until then it remains fully valid | [Rotating credentials](index.md#rotating-credentials) |
| **Suspicion of unauthorised access** | Rotate first, investigate second — not the other way round | as above |
| **The admin password is lost** | Create a second administrator using a different email address | [Quickstart, step 3.2](raspberry-pi-quickstart.md) |
| **After every deploy** | Nothing extra — the configuration files on the server are rewritten as part of it | [Configuration files](index.md#important-configuration-files) |
| **The backup USB stick is missing or was swapped** | Make sure it is mounted at `/mnt/backup` again — otherwise the backup run aborts, by design | [Maintenance checklist](index.md#maintenance-checklist) |

!!! danger "Rotation does not remove SSH access"
    `scenario:generate_credentials` with `ROTATE=true` renews the Rails key, `secret_key_base`
    and the JWT secret (`lib/tasks/scenarios.rake:94`) — **it does not touch SSH access to the
    server.** Rotating alone does not close the departed person's access.

    SSH keys live on the Pi in `~/.ssh/authorized_keys` of the user `www-data`. To see which ones
    are there:

    ```bash
    ssh -p 8910 www-data@<name>.local 'cat ~/.ssh/authorized_keys'
    ```

    Each line ends with a comment, usually `user@machine`, which tells you whose key it is.
    Remove the departed person's line and then **verify that their access is really gone**. If
    only one key would remain, make sure it is yours first — otherwise you lock yourself out.

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
