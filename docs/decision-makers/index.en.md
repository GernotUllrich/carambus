# For Decision Makers

These pages help the board and sports officials of a billiards club or regional association decide whether
Carambus suits them. They cover what Carambus can do today, how it is operated and what a club needs for it —
including where the Carambus operator still has to help today.

## What Carambus is

Carambus is a web application for running carom billiards play, created at Billardclub Wedel 61 e.V. It runs
tournaments according to the tournament plans of the German carom tournament rules, shows scoreboards at the
tables, supports league match days and exchanges data with the DBU ClubCloud. Carambus is open source (MIT
license).

## Is Carambus right for us?

**Carambus fits if …**

- your club hosts **carom tournaments** (straight rail, balkline, one-cushion, three-cushion, Kegelbillard) —
  according to the T-plans of the tournament rules, as round robin, knockout or double knockout
- you want **scoreboards at the tables** that the players operate themselves
- your players and clubs are maintained in the **DBU ClubCloud** and results should go back there
- someone in the club can set up a Raspberry Pi via SSH — or you do the setup together with the Carambus operator

**Carambus does not fit (yet) if …**

- you want to run **pool or snooker tournaments**: there are scoreboards for free games and league match days,
  but no tournament modes
- you are looking for a system that goes live without the Carambus operator: the initial database load and the
  server's access keys come from the operator today (see
  [Requirements for running your own server](deployment-options.md#voraussetzungen))
- you expect an online booking system, an app with offline mode, or statistics and exports — see
  [What Carambus cannot do](features-overview.md#nicht-enthalten)

## Pages in this section

| Page | answers |
|---|---|
| [Executive Summary](executive-summary.md) | Carambus on one page: features, architecture, requirements, project status |
| [Features Overview](features-overview.md) | What Carambus can do — and what it cannot |
| [Deployment Options](deployment-options.md) | How a club or association runs Carambus and what it needs for that |

For the technical setup: [Administrator overview](../administrators/index.md) and
[Raspberry Pi Quickstart](../administrators/raspberry-pi-quickstart.md).

## Next steps

1. Read the [Executive Summary](executive-summary.md).
2. **Get in touch before you buy hardware:** the initial database load and the access keys currently go through
   the Carambus operator.
3. Set up the club server following the [Raspberry Pi Quickstart](../administrators/raspberry-pi-quickstart.md).

<a id="kontakt"></a>
## Contact

- **Email:** gernot.ullrich@gmx.de
- **GitHub:** [GernotUllrich/carambus](https://github.com/GernotUllrich/carambus)
- **Reference club:** [Billardclub Wedel 61 e.V.](http://www.billardclub-wedel.de/)
