---
---
title: Table Reservation and Heating Control
summary: Automated table reservation via Google Calendar and intelligent heating control based on Scoreboard activities
version:
published_at: !ruby/object:ActiveSupport::TimeWithZone
  utc: 2025-01-27 10:00:00.000000000 Z
  zone: !ruby/object:ActiveSupport::TimeZone
    name: Europe/Berlin
  time: 2025-01-27 11:00:00.000000000 Z
tags: [reservation, heating, automation, google-calendar]
metadata: {}
position: 0
id: 101
---

# Table Reservation and Heating Control

*BC Wedel, Gernot, May 7, 2024*

## 1. Table Reservation

### Access to Google Calendar
Table reservations can now be made by authorized members in the central Google Calendar "BC Wedel".

**Access links can be obtained by sending an informal email to:**
- gernot.ullrich@gmx.de
- wcauel@gmail.com

### Important Formatting for Carambus Evaluation
**The title of the reservation must follow a specific format for Carambus to correctly evaluate the reservation.**

#### Valid Reservation Title Examples:

- **"T6 Gernot + Lothar"** - Single table reservation
- **"T1, T4-T8 Clubabend"** - Multiple tables for club evening
- **"T5, T7 NDM Cadre 35/2 Klasse 5-6"** - Tournament reservation (Cadre is highlighted in red)

### Formatting Rules:
- **Table Numbers:** Use "T" followed by the table number (e.g., T1, T6)
- **Multiple Tables:** Separate with comma (T1, T4) or range (T4-T8)
- **Description:** Add a description after the table numbers
- **Tournaments:** Use special keywords like "Cadre" for automatic recognition

## 2. Heating Control

### Automated Control
Table heaters are automatically switched based on calendar entries and Scoreboard activities.

### Heating ON (AN)

The heating is automatically turned on:

1. **2 hours before a reservation** - Based on Google Calendar entries
2. **At the latest, 5 minutes before** - If a game is detected on the Scoreboard

### Heating OFF (AUS)

The heating is automatically turned off:

1. **After 1 hour without Scoreboard activity** - If the reservation has already begun
2. **After 1 hour without activity** - If no reservation is running and no Scoreboard activity is detected

### Technical Details

- **Scoreboard Integration:** The system continuously monitors activities on the Carambus Scoreboard
- **Calendar Integration:** Google Calendar entries are automatically read and processed
- **Intelligent Logic:** The system considers both planned reservations and spontaneous activities

### Benefits of Automated Control

- **Energy Efficiency:** Heaters are only turned on when needed
- **Comfort:** Automatic pre-heating before reservations
- **Cost Savings:** Avoid unnecessary heating costs for unused tables
- **User-Friendly:** No manual operation of heaters required

---

*This documentation describes the integration of Google Calendar reservations with Carambus Scoreboard technology for fully automated table and heating management at BC Wedel.* 