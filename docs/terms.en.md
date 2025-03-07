---
---
title: Terms
summary:
version:
published_at: !ruby/object:ActiveSupport::TimeWithZone
  utc: 2025-03-05 22:15:15.285055000 Z
  zone: !ruby/object:ActiveSupport::TimeZone
    name: Europe/Berlin
  time: 2025-03-05 23:15:15.285055000 Z
tags: []
metadata: {}
position: 0
id: 4
---

This web application essentially has two interfaces:

- Tournament schedules and results from the billardarea.de (BA) website, or since 2022 from the various regional ClubCloud instances.
- the scoreboards at the tables.

Once the tournament data and seeding lists have been retrieved from the ClubCloud, Carambus works independently, matching the selected tournament mode with the scoreboards. Without any further intervention by the tournament manager, the tournament process is controlled by the entries on the scoreboards in accordance with the selected tournament mode.

For security reasons (no waranty here! ;-) ), the tournament management should not rely solely on the entries on the scoreboards.  A parallel recording of the match results on the specified match protocol forms should be carried out manually.

